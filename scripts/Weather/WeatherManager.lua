-- Engine 10 precipitation adapters. Never invent a baseline for setter-only APIs.
FS25E_WeatherManager = {records={}, hooks={}, assetHooks={}, classHooks={}, values={}, locks={}, enabled=true, elapsed=0, diagnostics={}}
local M=FS25E_WeatherManager
local unpackArgs=unpack or table.unpack
local function packArgs(...) return {n=select('#',...),...} end
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function valid(node) return type(entityExists)=='function' and node~=nil and node~=0 and entityExists(node) end
local function diagnose(stage)
 M.diagnostics.last=stage
 M.diagnostics[stage]=(M.diagnostics[stage] or 0)+1
 if M.diagnostics[stage]==1 and FS25E_Debug and FS25E_Debug.info then
  FS25E_Debug.info('WeatherManager',stage)
 end
end
local function nativeEnvironment()
 if M.nativeEnv then return M.nativeEnv end
 -- Mod globals and the environment used by GIANTS Lua methods need not be
 -- identical. Resolve the actual loader environment from shared stock code.
 local owner=I3DManager or g_i3DManager
 local source=owner and owner.loadI3DFile
 if type(source)=='function' and type(getfenv)=='function' then
  local ok,env=pcall(getfenv,source)
  if ok and type(env)=='table' and type(env.loadI3DFile)=='function' then M.nativeEnv=env end
 end
 M.nativeEnv=M.nativeEnv or _G
 return M.nativeEnv
end
local function recordValid(node,r)
 if not valid(node) or r.mission~=g_currentMission then return false end
 if r.shape then
  if not valid(r.shape) or type(getGeometry)~='function' or getGeometry(r.shape)~=node then return false end
  if type(getName)~='function' or getName(r.shape)~=r.shapeName then return false end
 end
 return true
end
local defs={
 {id='rainVelocity',fn='setRainSpawnVelocity',count=3,indices={1,2,3},min=0.25,max=2,step=0.001},
 {id='rainWindInfluence',fn='setRainWindForce',count=2,indices={1,2},min=0,max=2,step=0.001},
 {id='rainTurbulence',fn='setRainTurbulenceParameters',count=4,indices={1},min=0,max=2,step=0.001},
 {id='rainBounceStrength',fn='setRainBounceRestitution',count=1,indices={1},min=0,max=1,step=0.001,absolute=true},
 {id='rainSplashRandomness',fn='setRainBounceRandomFactor',count=1,indices={1},min=0,max=3,step=0.001},
 {id='rainCameraInfluence',fn='setRainCameraVelocityMultiplier',count=1,indices={1},min=0,max=2,step=0.001},
 {id='rainDistribution',fn='setRainDistributionPower',count=1,indices={1},min=1,max=5,step=0.001,absolute=true},
 {id='rainBounceCount',fn='setRainMaxBounces',count=1,indices={1},min=0,max=3,step=1,absolute=true}
}
local profiles={
 {rainVelocity=0.8,rainWindInfluence=0.6},
 {rainVelocity=1,rainWindInfluence=1},
 {rainVelocity=1.15,rainWindInfluence=1.2},
 {rainVelocity=1.3,rainWindInfluence=1.7},
 {rainVelocity=1,rainWindInfluence=2}
}
function M.setProfile(index,automatic)
 if not finite(index) or index~=math.floor(index) or index<0 or index>5 then return false,'FS25E_status_invalidValue' end
 if automatic and M.locks.rainProfile then return false,'FS25E_status_locked' end
 if index==0 then local ok=M.restore(); if ok then M.profile=0 end; return ok end
 local settings=profiles[index]; local previous={}
 for id in pairs(settings) do
  if automatic and M.locks[id] then return false,'FS25E_status_locked' end
  local ok,reason=M.available(id); if not ok then return false,reason end
  previous[id]={value=M.values[id]}
 end
 for id,value in pairs(settings) do
  local ok,reason=M.write(id,value,automatic)
  if not ok then
   for key,old in pairs(previous) do if old.value~=nil then M.write(key,old.value) else M.restore(key) end end
   return false,reason
  end
 end
 M.profile=index; M.profileDirty=false; return true,'FS25E_status_observedOnly'
end
function M.setLocked(id,value) M.locks[id]=value==true end
local function transformed(def,args)
 local out={}; for i=1,def.count do out[i]=args[i] end
 local value=M.enabled and M.values[def.id] or nil
 if value~=nil then for _,index in ipairs(def.indices) do out[index]=def.absolute and value or args[index]*value end end
 return out
end
-- GIANTS loads the starting values directly from <Precipitation> in an I3D;
-- observing Lua setters alone never sees those values. Read the exact loaded
-- stock weather asset, and only its single, matching Scene shape. No scene scan.
local function stockAsset(filename)
 if type(filename)~='string' then return false end
 local path=filename:gsub('\\','/'):lower()
 if not path:match('/sky/rain%.i3d$') and not path:match('/sky/hail%.i3d$') and not path:match('/sky/snow%.i3d$') then return false end
 for _,name in ipairs({'rain','hail','snow'}) do
  local relative='data/sky/'..name..'.i3d'
  -- GIANTS may pass a resolved absolute path or a ./data path. The baseline
  -- still comes from this exact file, never from a guessed replacement path.
  if path==relative or path=='$'..relative or path:sub(-#relative-1)=='/'..relative then return true end
  if Utils and type(Utils.getFilename)=='function' then
   local ok,resolved=pcall(Utils.getFilename,'$'..relative,nil)
   if ok and type(resolved)=='string' and path==resolved:gsub('\\','/'):lower() then return true end
  end
 end
 return false
end
function M.captureAsset(filename,root)
 if not M.enabled or not stockAsset(filename) or not valid(root) then return false end
 diagnose('asset load observed')
 -- Engine 10 exposes delete(xmlId); deleteXMLFile is not in its public binding.
 local closeXML=type(deleteXMLFile)=='function' and deleteXMLFile or delete
 local required={loadXMLFile=loadXMLFile,getXMLFloat=getXMLFloat,getXMLString=getXMLString,
  getNumOfChildren=getNumOfChildren,getChildAt=getChildAt,getName=getName,getGeometry=getGeometry}
 for _,name in ipairs({'loadXMLFile','getXMLFloat','getXMLString','getNumOfChildren','getChildAt','getName','getGeometry'}) do
  if type(required[name])~='function' then diagnose('asset capture missing API: '..name); return false end
 end
 if type(closeXML)~='function' then diagnose('asset capture missing API: delete (XML cleanup)'); return false end
 local loaded,xml=pcall(loadXMLFile,'FS25E_weatherAsset',filename)
 if not loaded or xml==nil or xml==0 then diagnose('asset XML unavailable'); return false end
 local ok,result=pcall(function()
  local path='i3D.Shapes.Precipitation(0)'
  local shapeId=getXMLString(xml,path..'#shapeId')
  local sceneId=getXMLString(xml,'i3D.Scene.Shape(0)#shapeId')
  local name=getXMLString(xml,'i3D.Scene.Shape(0)#name')
  if shapeId==nil or shapeId~=sceneId or name==nil then diagnose('asset XML shape mapping unavailable'); return false end
  -- I3DManager callbacks may expose an extra root wrapper. Walk only this
  -- freshly loaded asset, bounded to 64 nodes, and require an unambiguous name.
  local shape,queue,visited=nil,{root},{}
  local position=1
  while position<=#queue and position<=64 do
   local node=queue[position];position=position+1
   if valid(node) and not visited[node] then
    visited[node]=true
    if getName(node)==name then
     local isShape=not (ClassIds and ClassIds.SHAPE and type(getHasClassId)=='function') or getHasClassId(node,ClassIds.SHAPE)
     if isShape then if shape then diagnose('asset shape ambiguous'); return false end; shape=node end
    end
    for i=0,math.min(getNumOfChildren(node),64-#queue)-1 do queue[#queue+1]=getChildAt(node,i) end
   end
  end
  if not shape then diagnose('asset scene shape unavailable'); return false end
  -- The Scene shape owns the precipitation geometry. Native precipitation
  -- parameters act on that geometry entity, not on its transform wrapper.
  local node=getGeometry(shape)
  if not valid(node) then diagnose('asset precipitation geometry unavailable'); return false end
  local function number(attr) local v=getXMLFloat(xml,path..'#'..attr); return finite(v) and v or nil end
  local authored={}
  local velocity=number('spawnVelocity')
  if velocity then authored.rainVelocity={0,velocity,0} end
  local x,z=number('windForceX'),number('windForceY')
  if x and z then authored.rainWindInfluence={x,z} end
  local camera=number('cameraVelocityMultiplier')
  if camera then authored.rainCameraInfluence={camera} end
  local power=number('rainDistributionPower')
  if power then authored.rainDistribution={power} end
  -- Defaults for these two fields are explicitly documented by Engine 10.
  authored.rainBounceStrength={number('bounceRestitution') or 0.25}
  authored.rainSplashRandomness={number('bounceRandomFactor') or 1}
  local bounces=number('maxBounces')
  if bounces then authored.rainBounceCount={bounces} end
  -- No frequency appears in the official I3D 1.6 schema or stock assets.
  -- setRainTurbulenceParameters requires it: wait for an actual setter call.
  for id,args in pairs(authored) do
   local hook=M.hooks[id]
   if hook then
    M.records[id]=M.records[id] or {}
    local record=M.records[id][node]
    if not record or record.mission~=g_currentMission then
     local count=0
     for key,old in pairs(M.records[id]) do
      if recordValid(key,old) then count=count+1 else M.records[id][key]=nil end
     end
     if count>=16 then return false end
     M.records[id][node]={args=args,mission=g_currentMission,source=filename,shape=shape,shapeName=name}
     if M.values[id]~=nil then hook.original(node,unpackArgs(transformed(hook.def,args),1,hook.def.count)) end
    end
   end
  end
  diagnose('asset precipitation registered')
  return true
 end)
 local closed,closeError=pcall(closeXML,xml)
 if not closed then diagnose('asset XML cleanup exception: '..tostring(closeError)) end
 if not ok then diagnose('asset capture exception: '..tostring(result)) end
 return ok and result==true
end
local function installAssetHooks()
 local env=nativeEnvironment()
 for _,name in ipairs({'loadI3DFile','loadSharedI3DFile'}) do
  if not M.assetHooks[name] and type(env[name])=='function' then
   local original=env[name]
   local wrapper=function(filename,...)
    local result=packArgs(original(filename,...))
    if M.enabled and stockAsset(filename) then pcall(M.captureAsset,filename,result[1]) end
    return unpackArgs(result,1,result.n)
   end
   M.assetHooks[name]={original=original,wrapper=wrapper,env=env}; env[name]=wrapper
  end
 end
 for _,name in ipairs({'streamI3DFile','streamSharedI3DFile'}) do
  if not M.assetHooks[name] and type(env[name])=='function' then
   local original=env[name]
   local wrapper=function(filename,callback,target,arguments,...)
    local fn=type(callback)=='string' and (target and target[callback] or env[callback]) or nil
    if not M.enabled or not stockAsset(filename) or type(fn)~='function' then
     return original(filename,callback,target,arguments,...)
    end
    local proxy={}
    proxy.finished=function(_,node,failedReason,args)
     pcall(M.captureAsset,filename,node)
     if target then return fn(target,node,failedReason,args) end
     return fn(node,failedReason,args)
    end
    return original(filename,'finished',proxy,arguments,...)
   end
   M.assetHooks[name]={original=original,wrapper=wrapper,env=env}; env[name]=wrapper
  end
 end
end
local function installClassHooks()
 local owner=I3DManager or g_i3DManager
 if not owner then return end
 for _,name in ipairs({'loadI3DFile','loadSharedI3DFile'}) do
  if not M.classHooks[name] and type(owner[name])=='function' then
   local original=owner[name]
   local wrapper=function(self,filename,...)
    local result=packArgs(original(self,filename,...))
    if stockAsset(filename) then pcall(M.captureAsset,filename,result[1]) end
    return unpackArgs(result,1,result.n)
   end
   M.classHooks[name]={owner=owner,original=original,wrapper=wrapper}; owner[name]=wrapper
  end
 end
 for _,name in ipairs({'loadI3DFileAsync','loadSharedI3DFileAsync'}) do
  if not M.classHooks[name] and type(owner[name])=='function' then
   local original=owner[name]
   local wrapper=function(self,filename,onCreate,physics,callback,target,args)
    if not stockAsset(filename) or type(callback)~='function' then return original(self,filename,onCreate,physics,callback,target,args) end
    local captured=function(object,node,reason,arguments)
     pcall(M.captureAsset,filename,node)
     return callback(object,node,reason,arguments)
    end
    return original(self,filename,onCreate,physics,captured,target,args)
   end
   M.classHooks[name]={owner=owner,original=original,wrapper=wrapper}; owner[name]=wrapper
  end
 end
end
function M.install()
 if g_dedicatedServer~=nil then return false end
 M.enabled=true
 local env=nativeEnvironment()
 for _,def in ipairs(defs) do
  if not M.hooks[def.id] and type(env[def.fn])=='function' then
   local original=env[def.fn]
   local wrapper=function(node,...)
    if not M.enabled then return original(node,...) end
    local args={...}; local good=select('#',...)==def.count and valid(node)
    for i=1,def.count do good=good and finite(args[i]) end
    if not good then return original(node,...) end
    M.records[def.id]=M.records[def.id] or {}
    if not M.records[def.id][node] then
     local count=0; for key,r in pairs(M.records[def.id]) do if recordValid(key,r) then count=count+1 else M.records[def.id][key]=nil end end
     if count>=16 then return original(node,...) end
    end
    -- New engine values replace the baseline, so weather transitions never compound.
    local previous=M.records[def.id][node]
    M.records[def.id][node]={args=args,mission=g_currentMission,shape=previous and previous.shape,shapeName=previous and previous.shapeName}
    return original(node,unpackArgs(transformed(def,args),1,def.count))
   end
   M.hooks[def.id]={original=original,wrapper=wrapper,def=def,env=env}; env[def.fn]=wrapper
  end
 end
 installAssetHooks()
 installClassHooks()
 diagnose(env~=_G and 'native hooks installed in GIANTS environment' or 'native hooks installed in shared environment')
 return true
end
function M.init()
 -- Assets can finish before the mission is published in the mod environment.
 -- Only adopt this load cycle's still-owned shape/geometry pair, never a stale
 -- record from another mission (reset removes those records).
 if g_currentMission then
  for _,records in pairs(M.records) do for node,r in pairs(records) do
   if r.mission==nil and r.shape and valid(r.shape) and valid(node) and getGeometry(r.shape)==node then r.mission=g_currentMission end
  end end
 end
end
function M.available(id)
 if not M.hooks[id] then return false,'FS25E_status_missingApi' end
 for node,r in pairs(M.records[id] or {}) do if recordValid(node,r) then return true,'FS25E_status_observedOnly' end end
 return false,'FS25E_status_waitWeatherBaseline'
end
function M.write(id,value,automatic)
 local hook=M.hooks[id]; if not hook or not finite(value) then return false,'FS25E_status_invalidValue' end
 if automatic and M.locks[id] then return false,'FS25E_status_locked' end
 local ok,reason=M.available(id); if not ok then return false,reason end
 local def=hook.def; value=math.max(def.min,math.min(def.max,value))
 if def.step==1 then value=math.floor(value+0.5) end
 local before=M.values[id]; M.values[id]=value
 for node,record in pairs(M.records[id]) do
  if recordValid(node,record) then
   local applied,result=pcall(hook.original,node,unpackArgs(transformed(def,record.args),1,def.count))
   if not applied or result==false then M.values[id]=before; M.restore(id); return false,'FS25E_status_applyFailed' end
  else M.records[id][node]=nil end
 end
 M.profile=0; M.profileDirty=true; return true,'FS25E_status_observedOnly'
end
function M.restore(id)
 if not id then local ok=true; for _,d in ipairs(defs) do if not M.restore(d.id) then ok=false end end; return ok end
 local hook=M.hooks[id]; local ok=true
 if hook then for node,r in pairs(M.records[id] or {}) do if recordValid(node,r) then
  local applied,result=pcall(hook.original,node,unpackArgs(r.args,1,hook.def.count))
  if not applied or result==false then ok=false end
 end end end
 -- Retain original records for a failed restore retry, but never retain an
 -- active request that could reapply when a different manual slider is used.
 M.values[id]=nil; M.profile=0; M.profileDirty=next(M.values)~=nil
 return ok
end
function M.reset()
 M.enabled=false; local ok=M.restore()
 if not ok then M.values={}; M.profile=0; M.profileDirty=false; return false end
 for _,hook in pairs(M.hooks) do if hook.env[hook.def.fn]==hook.wrapper then hook.env[hook.def.fn]=hook.original end end
 for name,hook in pairs(M.assetHooks) do if hook.env[name]==hook.wrapper then hook.env[name]=hook.original end end
 for name,hook in pairs(M.classHooks) do if hook.owner[name]==hook.wrapper then hook.owner[name]=hook.original end end
 M.hooks={}; M.assetHooks={}; M.classHooks={}; M.records={}; M.values={}; M.locks={}; M.profile=0; M.elapsed=0; return ok
end
function M.getControls()
 local controls={{id='rainProfile',category='weather',labelKey='FS25E_setting_rainProfile',tooltipKey='FS25E_tooltip_rainProfile',
  min=0,max=5,step=1,cost='medium',experimental=true,verification='observed',scope='global',compositeProfile=true,profileSelector=true,
  format=function(index)
   local key=index==0 and M.profileDirty and 'FS25E_value_custom' or ('FS25E_value_rainProfile'..tostring(index))
   return FS25E_Localization and FS25E_Localization.t and FS25E_Localization.t(key) or tostring(index)
  end,
  read=function() return M.profile or 0 end,write=M.setProfile,restore=function() return M.setProfile(0) end,
  available=function() for id in pairs(profiles[1]) do local ok,reason=M.available(id); if not ok then return false,reason end end; return true end}}
 for _,def in ipairs(defs) do local d=def; controls[#controls+1]={id=d.id,category='weather',labelKey='FS25E_setting_'..d.id,
  tooltipKey='FS25E_tooltip_'..d.id,min=d.min,max=d.max,step=d.step,cost='medium',experimental=true,verification='observed',scope='global',
  read=function() if M.values[d.id]~=nil then return M.values[d.id] end; if not d.absolute then return 1 end
   for node,r in pairs(M.records[d.id] or {}) do if recordValid(node,r) then return r.args[1] end end end,
  write=function(v) return M.write(d.id,v) end,restore=function() return M.restore(d.id) end,
  available=function() return M.available(d.id) end}
 end
 return controls
end
function M.getRequestedValues()
 local values={}; for id,value in pairs(M.values) do values[id]=value end; return values
end
