-- Manually invoked, bounded, read-only runtime evidence. Never call an unknown
-- function merely because its name sounds like a getter. No hooks or writers.
FS25E_RuntimeProbe={}
local M=FS25E_RuntimeProbe
local sequence=0
local LIMIT={entries=700,bytes=90000,depth=3,keys=64,string=160,keyLength=180,globalKeys=4096,apiMatches=200,materialSamples=3}
local categories={all=true,environment=true,lighting=true,weather=true,materials=true,render=true}
local keywords={'exposure','bloom','tone','colorgrading','scattering','fog','sun','cloud','reflection','ambient','lighting','light','shadow','lensflare','atmosphere','postfx','postprocess','saturation','gamma','brightness','precipitation','rain','wetness'}
local privateKeys={'owner','player','user','network','connection','password','token','credential','account','steam','license','savegame','career','farmid','farmname'}
local noArgGetters={
 {name='getRainAmountMultiplier',group='weather',source='Engine10.Rendering'},
 {name='getWetness',group='weather',source='Engine10.Rendering'},
 {name='getAtmosphereQuality',group='render',source='Stock.SettingsModel'},
 {name='getLensFlareQuality',group='render',source='Stock.SettingsModel'},
 {name='getVolumetricFogQuality',group='render',source='Stock.SettingsModel'},
 {name='getScreenSpaceReflectionsQuality',group='render',source='Stock.SettingsModel'}
}
local lightGetters={
 {name='getLightColor',count=3,source='Stock.RealLight'},
 {name='getLightScatteringIntensity',count=1},
 {name='getLightScatteringConeAngle',count=1},
 {name='getLightScatteringDirection',count=3},
 {name='getLightUseLightScattering',count=1},
 {name='getLightSoftShadowSize',count=1},
 {name='getLightSoftShadowDistance',count=1},
 {name='getLightSoftShadowDepthBiasFactor',count=1},
 {name='getLightShadowExtrusionDistance',count=1},
 {name='getLightCastingShadowMap',count=2},
 {name='getLightType',count=1}
}
local documented={setLightScatteringColor='setter',getHasShaderParameter='getter',getShaderParameter='getter',setShaderParameter='setter'}
for _,d in ipairs(noArgGetters) do documented[d.name]='getter' end
for _,d in ipairs(lightGetters) do documented[d.name]='getter' end
for _,name in ipairs({'setLightColor','setLightScatteringIntensity','setLightScatteringConeAngle','setLightScatteringDirection',
 'setLightUseLightScattering','setLightSoftShadowSize','setLightSoftShadowDistance','setLightSoftShadowDepthBiasFactor',
 'setLightShadowExtrusionDistance','setLightShadowMap','setAtmosphereQuality','setLensFlareQuality',
 'setVolumetricFogQuality','setScreenSpaceReflectionsQuality'}) do documented[name]='setter' end
local providers={
 {name='FS25E_GlobalLighting',group='lighting'},
 {name='FS25E_EnvironmentLighting',group='environment'},
 {name='FS25E_LightTuning',group='lighting'},
 {name='FS25E_WeatherManager',group='weather'},
 {name='FS25E_MaterialManager',group='materials'}
}
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function clean(s,max) return (s:gsub('[%c]',' ')):sub(1,max or LIMIT.string) end
local function field(t,k) if type(t)=='table' then return rawget(t,k) end end
local function tableLength(t)
 if type(t)~='table' then return 0 end
 if type(rawlen)=='function' then return rawlen(t) end
 -- FS25 uses Lua 5.1, where table length cannot call __len.
 return #t
end
local function safeKey(k)
 if type(k)=='string' and #k<=80 and k:match('^[%a_][%w_]*$') then return k end
 if finite(k) and k>=0 and k==math.floor(k) and k<1000000 then return '['..string.format('%.0f',k)..']' end
end
local function hidden(k)
 local name=type(k)=='string' and k:lower() or ''
 if name=='mission' or name=='vehicle' or name=='vehicles' or name=='self' or name=='parent' or name=='_g' then return true end
 for _,part in ipairs(privateKeys) do if name:find(part,1,true) then return true end end
 return false
end
local function describes(v,trusted)
 local t=type(v)
 if t=='number' then return finite(v) and 'number:'..string.format('%.9g',v) or 'number:nonfinite' end
 if t=='boolean' then return v and 'boolean:true' or 'boolean:false' end
 -- Unknown runtime strings can be filenames or private content. Record their
 -- type/length, never their contents, including in error messages.
 if t=='string' then
  if trusted and (v:match('^FS25E_[%w_]+$') or v=='APPLIED' or v=='REJECTED' or v=='QUEUED' or v=='UNAVAILABLE' or v=='PENDING' or v=='READY') then return 'string:'..v end
  return 'string:redacted(length='..#v..')'
 end
 if t=='function' then return 'function:present/unverified/not-called' end
 return t
end
local function wanted(category,group)
 return category=='all' or category==group or (category=='environment' and (group=='lighting' or group=='weather' or group=='render'))
end
local function runtimeEnvironment()
 local weather=FS25E_WeatherManager
 local saved=field(weather,'nativeEnv')
 if type(saved)=='table' and type(rawget(saved,'setRainSpawnVelocity'))=='function' then return saved,'WeatherManager.nativeEnv' end
 local candidates={field(PlaceableSolarPanels,'updateHeadRotation'),field(I3DManager,'loadI3DFile')}
 if type(getfenv)=='function' then for _,f in pairs(candidates) do if type(f)=='function' then
  local ok,env=pcall(getfenv,f)
  if ok and type(env)=='table' then return env,'stock-function-environment' end
 end end end
 return _G,'shared-mod-environment'
end
local function newCollector(category)
 local map={};local stats={category=category,entries=0,bytes=0,errors=0,truncated=false,schema=1,sequence=sequence}
 local exhausted=false;local sectionWrites=0;local sectionLimit=LIMIT.entries
 local function room() return not exhausted and sectionWrites<sectionLimit end
 local function section(limit) sectionWrites=0;sectionLimit=limit end
 local function put(path,value)
  if not room() then stats.truncated=true;return false end
  sectionWrites=sectionWrites+1
  if stats.entries>=LIMIT.entries then stats.truncated=true;exhausted=true;return false end
  -- Never collapse distinct long runtime paths onto the same truncated key.
  if #path>LIMIT.keyLength then stats.truncated=true;return false end
  path=clean(path,LIMIT.keyLength);value=clean(value,LIMIT.string)
  if stats.bytes+#path+#value+4>LIMIT.bytes then stats.truncated=true;exhausted=true;return false end
  if map[path]==nil then stats.entries=stats.entries+1 end
  stats.bytes=stats.bytes+#path+#value+4;map[path]=value;return true
 end
 local function failure(path,kind) stats.errors=stats.errors+1;put(path,'error:'..kind) end
 local function keys(t,budget)
  local out,k={},nil
  for i=1,budget do
   local ok,nextKey=pcall(next,t,k)
   if not ok then stats.errors=stats.errors+1;return out,true end
   if nextKey==nil then return out,false end
   k=nextKey;local key=safeKey(k)
   if key and not hidden(k) then out[#out+1]={key=k,label=key} end
  end
  local ok,more=pcall(next,t,k)
  if not ok then stats.errors=stats.errors+1;return out,true end
  return out,more~=nil
 end
 local seen={}
 local function methods(t,path)
  local ok,mt=pcall(getmetatable,t)
  if not ok then failure(path..'.meta','metatable-access');return end
  if mt==nil then return end
  if type(mt)~='table' then put(path..'.meta','protected');return end
  local index=rawget(mt,'__index')
  if type(index)=='function' then put(path..'.meta.__index','function:not-invoked');return end
  if type(index)~='table' then return end
  local chainSeen={}
  for depth=1,2 do
   if chainSeen[index] then break end;chainSeen[index]=true
   local list,cut=keys(index,LIMIT.keys)
   table.sort(list,function(a,b)return a.label<b.label end)
   for _,item in ipairs(list) do if type(rawget(index,item.key))=='function' then
    if not put(path..'.meta.methods.'..item.label,'function:present/unverified/not-called') then return end
   end end
   if cut then stats.truncated=true;put(path..'.meta.methodsLimit','boolean:true') end
   local nextMeta=getmetatable(index);index=type(nextMeta)=='table' and rawget(nextMeta,'__index') or nil
   if type(index)~='table' then break end
  end
 end
 local function walk(t,path,depth,trusted)
  if not room() then stats.truncated=true;return end
  if type(t)~='table' then put(path,describes(t,trusted));return end
  if seen[t] then put(path,'table:reference('..seen[t]..')');return end
  seen[t]=path;if not put(path,'table') then return end;methods(t,path)
  if depth>=LIMIT.depth then put(path..'.depthLimit','boolean:true');stats.truncated=true;return end
  local list,cut=keys(t,LIMIT.keys);table.sort(list,function(a,b)return a.label<b.label end)
  for _,item in ipairs(list) do
   if not room() then stats.truncated=true;break end
   walk(rawget(t,item.key),path..'.'..item.label,depth+1,trusted)
  end
  if cut then stats.truncated=true;put(path..'.entryLimit','boolean:true') end
 end
 local function getter(env,name,path,count,...)
  local fn=type(env)=='table' and rawget(env,name)
  if type(fn)~='function' then put(path,'unavailable:missing-api');return end
  local out={pcall(fn,...)}
  if not out[1] then failure(path,'getter-call');return end
  for i=1,count do put(path..'.'..i,describes(out[i+1])) end
 end
 local function inventory(env,path)
  if type(env)~='table' then put(path,'unavailable');return end
  local list,cut=keys(env,LIMIT.globalKeys);local matches={}
  for _,item in ipairs(list) do if type(item.key)=='string' then
   local lower=item.key:lower();local match=false
   for _,part in ipairs(keywords) do if lower:find(part,1,true) then match=true;break end end
   if match then matches[#matches+1]=item end
  end end
  local function rank(item)
   if documented[item.key] then return 2 end
   local lower=item.label:lower()
   for _,word in ipairs({'exposure','bloom','tone','colorgrading','fog','ambient','postfx','postprocess'}) do
    if lower:find(word,1,true) then return 0 end
   end
   return 1
  end
  table.sort(matches,function(a,b)local ra,rb=rank(a),rank(b);if ra~=rb then return ra<rb end;return a.label<b.label end)
  for i=1,math.min(#matches,LIMIT.apiMatches) do local item=matches[i];local v=rawget(env,item.key)
   local status=describes(v)
   if type(v)=='function' and documented[item.key] then status='function:documented-'..documented[item.key]..'/presence-only' end
   if not put(path..'.'..item.label,status) then break end
  end
  if cut or #matches>LIMIT.apiMatches then stats.truncated=true;put(path..'.inventoryLimit','boolean:true') end
 end
 return {map=map,stats=stats,put=put,failure=failure,walk=walk,getter=getter,inventory=inventory,section=section}
end
local function validClass(env,node,className)
 if not finite(node) or node<=0 or node~=math.floor(node) then return false end
 local classes=ClassIds;local class=field(classes,className)
 local exists=rawget(env,'entityExists') or entityExists;local has=rawget(env,'getHasClassId') or getHasClassId
 if class==nil or type(exists)~='function' or type(has)~='function' then return false end
 local ok,present=pcall(exists,node);if not ok or not present then return false end
 local good,result=pcall(has,node,class);return good and result==true
end
function M.collect(category)
 category=category or 'all'
 if type(category)~='string' or not categories[category] then return nil,{ok=false,error='invalid-category'} end
 sequence=sequence+1
 local c=newCollector(category);local env,origin=runtimeEnvironment()
 c.stats.nativeEnvironment=origin
 c.stats.version=type(FS25_Enhanced)=='table' and field(FS25_Enhanced,'VERSION') or 'unknown'
 if type(c.stats.version)~='string' then c.stats.version='unknown' end
 c.stats.version=clean(c.stats.version,32)
 local mission=g_currentMission;local environment=field(mission,'environment');local lighting=field(environment,'lighting')
 local time=field(mission,'time');c.stats.gameTime=finite(time) and time or (finite(g_time) and g_time or 0)
 c.section(60)
 -- Confirmed getters come first so large unknown runtime tables cannot consume
 -- their budget. Presence-only entries never turn into speculative calls.
 for _,d in ipairs(noArgGetters) do if wanted(category,d.group) then c.getter(env,d.name,'native.'..d.name,1) end end
 if wanted(category,'lighting') then
  local sun=field(lighting,'sunLightId')
  c.put('native.sun.validLightSource',validClass(env,sun,'LIGHT_SOURCE') and 'boolean:true' or 'boolean:false')
  if validClass(env,sun,'LIGHT_SOURCE') then
   c.put('native.sun.node',describes(sun))
   for _,d in ipairs(lightGetters) do c.getter(env,d.name,'native.sun.'..d.name,d.count,sun) end
  end
 end
 c.section(70)
 for _,def in ipairs(providers) do if wanted(category,def.group) then
  local provider=rawget(_G,def.name)
  if type(provider)=='table' then
   for _,method in ipairs({'getDiagnostics','getRequestedValues'}) do
    local fn=rawget(provider,method)
    if def.name=='FS25E_MaterialManager' and method=='getDiagnostics' then
     -- Its normal diagnostics loops over all material records. Use bounded raw
     -- summaries here; probing a large map must not rescan its material list.
     c.walk({materials=tableLength(field(provider,'records')),targets=tableLength(field(provider,'targets')),
      pendingNodes=tableLength(field(provider,'scanQueue')),pendingWorldNodes=tableLength(field(provider,'worldQueue')),
      lastApply=field(provider,'lastApply')},'provider.'..def.name..'.getDiagnostics',1,true)
    elseif type(fn)=='function' then
     local ok,result=pcall(fn)
     if ok then c.walk(result,'provider.'..def.name..'.'..method,1,true)
     else c.failure('provider.'..def.name..'.'..method,'known-provider-read') end
    end
   end
   if def.name=='FS25E_WeatherManager' then c.walk(field(provider,'diagnostics'),'provider.weather.diagnostics',1,true) end
  end
 end end
 c.section(60)
 local controls=FS25E_VisualControls
 if type(controls)=='table' and type(rawget(controls,'getControls'))=='function' and type(rawget(controls,'getState'))=='function' then
  local ok,list=pcall(rawget(controls,'getControls'))
  if not ok then c.failure('controls','cached-list-read')
  elseif type(list)=='table' then
   local captured=0
   for index=1,512 do
    local control=rawget(list,index);if control==nil then break end
    local id,group=field(control,'id'),field(control,'category')
    local matches=wanted(category,group) or (category=='render' and (group=='atmosphere' or group=='reflections' or group=='shadows'))
    if matches and type(id)=='string' and #id<=64 and id:match('^[%w_-]+$') then
     local readOK,state=pcall(rawget(controls,'getState'),id)
     if not readOK then c.failure('controls.'..id,'cached-state-read')
     elseif type(state)=='table' then
      local touched=false
      for _,name in ipairs({'status','error','diagnosticError','requested','current','actual'}) do if rawget(state,name)~=nil then touched=true end end
      if touched then
       captured=captured+1
       for _,name in ipairs({'status','error','diagnosticError','requested','current','actual'}) do
        local value=rawget(state,name);if value~=nil then c.put('controls.'..id..'.'..name,describes(value,true)) end
       end
       if captured>=16 then break end
      end
     end
    end
   end
  end
 end
 c.section(75)
 if wanted(category,'materials') then
  -- Only already-discovered sample shapes; no vehicle methods, scenegraph
  -- discovery, cloning, setters, owner IDs or material/asset filename dumps.
  local records=field(FS25E_MaterialManager,'records')
  for index=1,LIMIT.materialSamples do local r=field(records,index)
   if type(r)=='table' then
    local node,slot=field(r,'node'),field(r,'slot');local path='native.materialSample.'..index
    if validClass(env,node,'SHAPE') and finite(slot) and slot>=0 and slot==math.floor(slot)
     and type(rawget(env,'getNumOfMaterials'))=='function' then
     local ok,count=pcall(rawget(env,'getNumOfMaterials'),node)
     if ok and finite(count) and slot<count then
      c.put(path..'.node',describes(node));c.put(path..'.slot',describes(slot))
      c.put(path..'.paintEligible',describes(field(r,'paintEligible')))
      local class=field(r,'materialClass') or field(r,'paintClassification')
      if class=='paint' or class=='porous' or class=='transparent' or class=='glass' or class=='unverified' then c.put(path..'.materialClass','string:'..class) end
      local has=rawget(env,'getHasShaderParameter')
      if type(has)=='function' then for _,parameter in ipairs({'clearCoatIntensity','clearCoatSmoothness','smoothnessScale','ssrParameters','scratches_dirt_snow_wetness'}) do
       local exists,present=pcall(has,node,parameter,slot)
       if exists and present==true then c.getter(env,'getShaderParameter',path..'.'..parameter,4,node,parameter,slot) end
      end end
     end
    end
   end
  end
 end
 -- Separate quotas preserve the native results, weather and lighting method
 -- roots, and candidate APIs even with huge tables in another section.
 c.section(95);if wanted(category,'lighting') then c.walk(lighting,'runtime.lighting',0) end
 c.section(95);if wanted(category,'weather') then c.walk(field(environment,'weather'),'runtime.weather',0) end
 c.section(30);if wanted(category,'environment') then c.walk(environment,'runtime.environment',2) end
 c.section(25)
 if wanted(category,'render') then
  for _,name in ipairs({'AtmosphereQuality','VolumetricFogQuality','LensFlareQuality','ScreenSpaceReflectionsQuality'}) do
   c.walk(rawget(env,name) or rawget(_G,name),'runtime.enums.'..name,1)
  end
  c.walk(field(g_settingsModel,'brightnessTexts'),'runtime.brightnessTexts',1)
 end
 c.section(95);c.inventory(env,'api.giants')
 if env~=_G then c.section(95);c.inventory(_G,'api.mod') end
 c.stats.ok=true
 return c.map,c.stats
end
M.takeSnapshot=M.collect
function M.emitSnapshot(category)
 local map,summary=M.collect(category)
 if not map then return summary end
 if type(Logging)~='table' or type(Logging.info)~='function' then summary.ok=false;summary.error='logging-unavailable';return summary end
 local function emit(line) local ok=pcall(Logging.info,'%s',line);return ok end
 local header=string.format('FS25E_PROBE BEGIN schema=1 version=%s seq=%d time=%.0f category=%s origin=%s',summary.version,summary.sequence,summary.gameTime,summary.category,summary.nativeEnvironment)
 if not emit(header) then summary.ok=false;summary.error='logging-failed';return summary end
 local keys={};for key in pairs(map) do keys[#keys+1]=key end;table.sort(keys)
 for _,key in ipairs(keys) do
  if not emit('FS25E_PROBE '..key..' = '..map[key]) then summary.ok=false;summary.error='logging-failed';break end
 end
 if not emit(string.format('FS25E_PROBE END seq=%d entries=%d bytes=%d truncated=%s errors=%d',summary.sequence,summary.entries,summary.bytes,tostring(summary.truncated),summary.errors)) then
  summary.ok=false;summary.error='logging-failed'
 end
 return summary
end
function M.getLimits() local limits={};for k,v in pairs(LIMIT) do limits[k]=v end;return limits end
