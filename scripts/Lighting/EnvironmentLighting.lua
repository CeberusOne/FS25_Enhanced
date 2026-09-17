-- GIANTS Engine 10 environment-light controls. Deliberately no invented
-- post-processing uniforms: only documented sun-light properties are exposed.
FS25E_EnvironmentLighting={values={},locks={},records={},sunRevisions={}}
local M=FS25E_EnvironmentLighting
-- Sun colour is intensity, warmth and tint only. Per-channel RGB controls
-- were removed. The sun light's scattering (setLightUseLightScattering /
-- setLightScatteringIntensity) lights the sky as well as the volumetric
-- shafts, so it is never switched off and never written as 0: god rays are a
-- factor on the sun's own scattering intensity, floored at 0.1.
local defs={
 {id='environmentSunIntensity',sun='sunIntensity',min=0.05,max=8,step=0.001},
 {id='environmentSunWarmth',sun='sunWarmth',min=-1,max=1,step=0.001},
 {id='environmentSunTint',sun='sunTint',min=-1,max=1,step=0.001},
 -- Sun light shafts: relative to the value the game's Lighting itself sets
 -- (re-captured whenever the game changes it), so day/weather dynamics stay.
 {id='environmentGodRays',getter='getLightScatteringIntensity',setter='setLightScatteringIntensity',min=0.1,max=4,step=0.001,relative=true,floor=0.1,default=1},
 {id='environmentShadowSoftness',getter='getLightSoftShadowSize',setter='setLightSoftShadowSize',min=0,max=20,step=0.001},
 {id='environmentShadowDistance',getter='getLightSoftShadowDistance',setter='setLightSoftShadowDistance',min=0.1,max=5000,step=0.1},
 {id='environmentShadowBias',getter='getLightSoftShadowDepthBiasFactor',setter='setLightSoftShadowDepthBiasFactor',min=0,max=10,step=0.001},
 {id='environmentShadowExtrusion',getter='getLightShadowExtrusionDistance',setter='setLightShadowExtrusionDistance',min=0,max=2000,step=0.1},
 -- Sun shadow map size: setLightShadowMap(sun, cast, depthMapResolution) with
 -- getLightCastingShadowMap read-back. The control value is an index into
 -- RESOLUTIONS; the record keeps the raw size, so restore is exact even when
 -- the game's own value is not one of the four.
 {id='environmentShadowResolution',shadowMap=true,min=0,max=3,step=1},
 {id='environmentScatteringWarmth',color=true,min=-1,max=1,step=0.001,default=0},
 {id='environmentScatteringTint',color=true,min=-1,max=1,step=0.001,default=0}
}
local RESOLUTIONS={1024,2048,4096,8192}
local function nearestIndex(res)
 local best,bestDelta=0,math.huge
 for i,r in ipairs(RESOLUTIONS) do local delta=math.abs(r-(res or 0)); if delta<=bestDelta then best,bestDelta=i-1,delta end end
 return best
end
local byId={};for _,d in ipairs(defs) do byId[d.id]=d end
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function same(a,b) return a==b or (finite(a) and finite(b) and math.abs(a-b)<0.0001*math.max(1,math.abs(a),math.abs(b))) end
local function enabled() return not FS25E_ModSettings or not FS25E_ModSettings.get or FS25E_ModSettings.get('enabled')==true end
local function context()
 local mission=g_currentMission;local owner=mission and mission.environment and mission.environment.lighting
 local node=owner and owner.sunLightId
 if g_dedicatedServer~=nil or not FS25E_LightDiscovery or not FS25E_LightDiscovery.isLightSource(node) then return nil end
 return {owner=owner,node=node,mission=mission}
end
local function owns(r,c) return r and c and r.owner==c.owner and r.node==c.node and r.mission==c.mission end
local function nativeEnvironment()
 -- Use an unmodified public stock method's function environment. Hooks on a
 -- private mod _G would never see the stock renderer's calls.
 local candidates={PlaceableSolarPanels and PlaceableSolarPanels.updateHeadRotation,
  I3DManager and I3DManager.loadI3DFile,Lighting and Lighting.update}
 if type(getfenv)=='function' then for _,f in pairs(candidates) do if type(f)=='function' then
  local ok,env=pcall(getfenv,f)
  if ok and type(env)=='table' and type(env.setLightScatteringColor)=='function' then return env end
 end end end
 return _G
end
local function read(d,c)
 if not c then return nil end
 if d.shadowMap then
  if type(getLightCastingShadowMap)~='function' or type(setLightShadowMap)~='function' then return nil end
  local ok,cast,resolution=pcall(getLightCastingShadowMap,c.node)
  if ok and cast==true and finite(resolution) and resolution>0 then return resolution end
  return nil
 end
 if type(_G[d.getter])~='function' or type(_G[d.setter])~='function' then return nil end
 local ok,v=pcall(_G[d.getter],c.node)
 if ok and ((d.boolean and type(v)=='boolean') or (not d.boolean and finite(v))) then return v end
end
local function writeNative(d,c,v)
 local ok,result
 if d.shadowMap then ok,result=pcall(setLightShadowMap,c.node,true,v) else ok,result=pcall(_G[d.setter],c.node,v) end
 return ok and result~=false and same(read(d,c),v)
end
local function anyColor()
 for _,d in ipairs(defs) do if d.color and M.values[d.id]~=nil then return true end end
 return false
end
local function colorOutput(rgb)
 local v=M.values;local w=v.environmentScatteringWarmth or 0;local t=v.environmentScatteringTint or 0
 local r=rgb[1]*4^w*2^t;local g=rgb[2]*4^(-t);local b=rgb[3]*4^(-w)*2^t
 local before=0.2126*rgb[1]+0.7152*rgb[2]+0.0722*rgb[3];local after=0.2126*r+0.7152*g+0.0722*b
 local balance=after>0.00001 and before/after or 0
 return {r*balance,g*balance,b*balance}
end
local function rawColor(c,rgb)
 local hook=M.colorHook
 if not hook or not owns(M.colorRecord,c) then return false end
 local ok,result=pcall(hook.original,c.node,rgb[1],rgb[2],rgb[3])
 return ok and result~=false
end
function M.install()
 if g_dedicatedServer~=nil or M.colorHook then return true end
 local env=nativeEnvironment();local original=env.setLightScatteringColor
 if type(original)~='function' then return true end
 local hook
 local wrapper=function(node,r,g,b)
  if M.colorHook~=hook then return original(node,r,g,b) end
  local c=context()
  if not c or node~=c.node or not finite(r) or not finite(g) or not finite(b) then return original(node,r,g,b) end
  local rgb={r,g,b};local requested=enabled() and anyColor()
  local out=requested and colorOutput(rgb) or rgb
  local result=original(node,out[1],out[2],out[3])
  if result~=false then
   M.colorRecord={owner=c.owner,node=node,mission=c.mission,original=rgb,last=out,applied=requested}
   M.colorFailure=nil
  elseif requested then M.colorFailure=true end
  return result
 end
 hook={env=env,original=original,wrapper=wrapper};M.colorHook=hook;env.setLightScatteringColor=wrapper
 return true
end
function M.available(id)
 local d=byId[id];local c=context()
 if not d or not c then return false,'FS25E_status_sunUnavailable' end
 if d.sun then
  local sun=FS25E_GlobalLighting
  if not sun or not sun.getSunValue or not sun.getSunRevision then return false,'FS25E_status_missingApi' end
  return sun.sunAvailable()
 end
 if d.color then
  if not M.colorHook then return false,'FS25E_status_missingApi' end
  return owns(M.colorRecord,c),owns(M.colorRecord,c) and 'FS25E_status_observedOnly' or 'FS25E_status_waitEnvironmentColor'
 end
 return read(d,c)~=nil,'FS25E_status_missingApi'
end
local function applyScalar(d,c)
 local current=read(d,c);if current==nil then return false,'FS25E_status_missingApi' end
 local r=M.records[d.id]
 if not owns(r,c) then r={owner=c.owner,node=c.node,mission=c.mission,original=current} end
 -- A value we did not write is the game's own: it becomes the new baseline
 -- (for a relative control that is the number the factor multiplies).
 if r.last~=nil and not r.pendingRestore and not same(current,r.last) then r.original=current end
 local wanted=d.boolean and M.values[d.id]==1 or M.values[d.id]
 -- Lua's and/or expression cannot represent false; handle boolean explicitly.
 if d.boolean then wanted=M.values[d.id]==1 end
 if d.relative then wanted=math.max(d.floor or 0,r.original*M.values[d.id]) end
 if d.shadowMap then wanted=RESOLUTIONS[M.values[d.id]+1] end
 if not same(current,wanted) and not writeNative(d,c,wanted) then
  r.pendingRestore=not writeNative(d,c,current);r.last=read(d,c);M.records[d.id]=r
  return false,'FS25E_status_applyFailed'
 end
 r.last=wanted;r.pendingRestore=false;M.records[d.id]=r
 return true
end
function M.write(id,value,automatic)
 local d=byId[id]
 if not d or not finite(value) then return false,'FS25E_status_invalidValue' end
 if not enabled() then return false,'FS25E_status_mod_disabled' end
 if automatic and M.locks[id] then return false,'FS25E_status_locked' end
 local ok,reason=M.available(id);if not ok then return false,reason end
 value=math.max(d.min,math.min(d.max,value));if d.boolean or d.shadowMap then value=math.floor(value+0.5) end
 if d.sun then
  local sun=FS25E_GlobalLighting
  local applied,status=sun.writeSun(d.sun,value,automatic)
  if applied then M.values[id]=value;M.sunRevisions[id]=sun.getSunRevision(d.sun) end
  return applied,status
 end
 local previous=M.values[id];M.values[id]=value
 if d.color then
  local c=context();local out=colorOutput(M.colorRecord.original)
  if not rawColor(c,out) then
   M.values[id]=previous;M.colorRecord.pendingRestore=not rawColor(c,M.colorRecord.last)
   return false,'FS25E_status_applyFailed'
  end
  M.colorRecord.last=out;M.colorRecord.applied=true
  return true,'FS25E_status_observedOnly'
 end
 local applied,status=applyScalar(d,context())
 if not applied then M.values[id]=previous end
 return applied,status
end
function M.setLocked(id,value) M.locks[id]=value==true end
function M.restore(id)
 if not id then
  -- Clear the complete request mask before restoring any property family.
  M.values={};local ok=true
  for _,d in ipairs(defs) do if not d.color and not M.restore(d.id) then ok=false end end
  if not M.restore('environmentScatteringWarmth') then ok=false end
  return ok
 end
 local d=byId[id];if not d then return true end
 M.values[id]=nil;local c=context()
 if d.sun then
  local sun=FS25E_GlobalLighting;local revision=M.sunRevisions[id];M.sunRevisions[id]=nil
  if sun and revision and revision==sun.getSunRevision(d.sun) then return sun.restoreSun(d.sun) end
  return true
 end
 if d.color then
  local r=M.colorRecord
  if owns(r,c) and (r.applied or r.pendingRestore) then
   local out=anyColor() and colorOutput(r.original) or r.original
   if not rawColor(c,out) then r.pendingRestore=true;return false end
   r.last=out;r.applied=anyColor();r.pendingRestore=false
  end
  M.colorFailure=nil;return true
 end
 local r=M.records[id]
 if owns(r,c) then
  local current=read(d,c);if current==nil then return false end
  if r.pendingRestore or same(current,r.last) then
   if not writeNative(d,c,r.original) then r.pendingRestore=true;return false end
  end
 end
 M.records[id]=nil;return true
end
function M.update()
 if not enabled() or next(M.values)==nil then return true end
 local c=context();if not c then return true,'FS25E_status_sunUnavailable' end
 if M.colorFailure then return false,'FS25E_status_applyFailed' end
 -- Shared with the sun colour path: one appended hook per lighting owner.
 if FS25E_GlobalLighting and FS25E_GlobalLighting.ensureOwnerHook then
  FS25E_GlobalLighting.ensureOwnerHook(c.owner)
 end
 return M.applyRequested()
end
function M.applyRequested()
 if not enabled() then return true end
 local c=context();if not c then return true end
 for _,d in ipairs(defs) do if not d.color and not d.sun and M.values[d.id]~=nil then
  -- A transient missing getter is a waiting lifecycle state, never a successful
  -- manual application and never grounds to discard the user's request.
  if read(d,c)~=nil then local ok,reason=applyScalar(d,c);if not ok then return false,reason end end
 end end
 return true
end
function M.getRequestedValues()
 local v={};for id,value in pairs(M.values) do local d=byId[id]
  if not d.sun or (FS25E_GlobalLighting and M.sunRevisions[id]==FS25E_GlobalLighting.getSunRevision(d.sun)) then v[id]=value end
 end;return v
end
function M.getDiagnostics()
 local c=context();local applied=0
 for _,r in pairs(M.records) do if owns(r,c) and not r.pendingRestore then applied=applied+1 end end
 local color=owns(M.colorRecord,c) and M.colorRecord.applied
 local sun=FS25E_GlobalLighting and FS25E_GlobalLighting.getDiagnostics and FS25E_GlobalLighting.getDiagnostics()
 return {sunNode=c and c.node,total=c and 1 or 0,active=c and 1 or 0,applied=applied,
  originalRGB=sun and sun.originalRGB,currentRGB=sun and sun.currentRGB,
  colorObserved=owns(M.colorRecord,c),colorApplied=color==true,failed=M.colorFailure and 1 or 0}
end
function M.reset()
 local ok=M.restore();if not ok then return false end
 local hook=M.colorHook
 if hook and hook.env.setLightScatteringColor==hook.wrapper then hook.env.setLightScatteringColor=hook.original end
 M.colorHook=nil;M.colorRecord=nil;M.colorFailure=nil;M.records={};M.locks={};M.sunRevisions={}
 return true
end
function M.getControls()
 local controls={}
 for _,def in ipairs(defs) do local d=def
  controls[#controls+1]={id=d.id,category='environment',min=d.min,max=d.max,step=d.step,
   kind=(d.boolean and 'bool') or (d.shadowMap and 'enum') or nil,cost=d.shadowMap and 'high' or 'medium',scope='global',experimental=d.color or nil,
   verification=d.color and 'observed' or 'native readback',
   labelKey='FS25E_setting_'..d.id,tooltipKey='FS25E_tooltip_'..d.id,
   format=d.shadowMap and function(v) return tostring(RESOLUTIONS[math.floor((v or 0)+0.5)+1] or v)..' px' end or nil,
   read=function()
    if d.sun then return FS25E_GlobalLighting and FS25E_GlobalLighting.getSunValue(d.sun) end
    if d.color or d.relative then return M.values[d.id]~=nil and M.values[d.id] or d.default end
    if d.shadowMap then return M.values[d.id] or nearestIndex(read(d,context())) end
    local v=read(d,context());if d.boolean and v~=nil then return v and 1 or 0 end;return v
   end,
   available=function() return M.available(d.id) end,
   write=function(v) return M.write(d.id,v) end,restore=function() return M.restore(d.id) end}
 end
 return controls
end
