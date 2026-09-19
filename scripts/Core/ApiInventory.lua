-- One-shot, read-only inventory of engine names, written to the log once per
-- mission. Only names and value types are recorded; nothing is called. It is
-- the evidence base for further atmosphere/tone controls (exposure, bloom,
-- colour grading, fog) whose runtime names the public script binding does not
-- list, and it shows which of the guarded controls (fog, atmosphere
-- asymmetry) the installed build really has.
FS25E_ApiInventory={done=false}
local M=FS25E_ApiInventory
function M.reset() M.done=false end
local KEYWORDS={'exposure','bloom','tonemap','colorgrad','colourgrad','fog','atmosphere','scatter','sky','cloud',
 'ambient','godray','volumetric','haze','postprocess','postfx','saturation','gamma','vignette','sharpen','lensflare',
 'envmap','irradiance','lightcull','shadowfocus','sunlight','moon','daynight','daylight'}
local LIMIT_NAMES,LIMIT_KEYS,LINE=400,160,18
local function log(msg) if FS25E_Debug and FS25E_Debug.info then FS25E_Debug.info('ApiInventory',msg) elseif print then print('[FS25_Enhanced][ApiInventory] '..msg) end end
--- The environment GIANTS' own scripts run in; a mod's _G is a sandbox that
--- only falls back to it through a metatable, so pairs() would miss the engine.
local function nativeEnvironment()
 if type(getfenv)~='function' then return nil end
 local candidates={I3DManager and I3DManager.loadI3DFile,Lighting and Lighting.update,Utils and Utils.appendedFunction}
 for _,f in ipairs(candidates) do
  if type(f)=='function' then
   local ok,env=pcall(getfenv,f)
   if ok and type(env)=='table' and env~=_G then return env end
  end
 end
end
local function matches(name)
 local lower=name:lower()
 for _,w in ipairs(KEYWORDS) do if lower:find(w,1,true) then return w end end
end
local function scan(t,names,count)
 if type(t)~='table' then return count end
 local n=0
 for k,v in pairs(t) do
  n=n+1; if n>60000 then break end
  if type(k)=='string' and type(v)=='function' and not names[k] then
   local w=matches(k)
   if w then names[k]=w; count=count+1 end
  end
 end
 return count
end
--- Functions (engine + stock classes) whose name carries one of the keywords.
function M.collect()
 local names,count={},0
 count=scan(nativeEnvironment(),names,count)
 count=scan(_G,names,count)
 local list={}
 for k in pairs(names) do list[#list+1]=k end
 table.sort(list)
 return list,names
end
local function chunks(prefix,list)
 for i=1,math.min(#list,LIMIT_NAMES),LINE do
  local part={}
  for j=i,math.min(i+LINE-1,#list,LIMIT_NAMES) do part[#part+1]=list[j] end
  log(prefix..' '..table.concat(part,' '))
 end
 if #list>LIMIT_NAMES then log(prefix..' ... '..(#list-LIMIT_NAMES)..' more') end
end
--- Fields and methods of the mission's Lighting object (the class that reads
--- environment.xml: exposure, bloom, tone mapping, colour grading curves).
local function describeLighting()
 local lighting=g_currentMission and g_currentMission.environment and g_currentMission.environment.lighting
 if type(lighting)~='table' then log('lighting object: not available'); return end
 local fields,methods={},{}
 local n=0
 for k,v in pairs(lighting) do
  n=n+1; if n>2000 then break end
  if type(k)=='string' then
   local t=type(v)
   if t=='function' then methods[#methods+1]=k
   elseif t=='number' then fields[#fields+1]=string.format('%s=%.4g',k,v)
   elseif t=='boolean' then fields[#fields+1]=k..'='..tostring(v)
   elseif t=='table' then fields[#fields+1]=k..'{}'
   else fields[#fields+1]=k..':'..t end
  end
 end
 local class=getmetatable(lighting); class=type(class)=='table' and class.__index or nil
 if type(class)=='table' then
  n=0
  for k,v in pairs(class) do n=n+1; if n>2000 then break end; if type(k)=='string' and type(v)=='function' then methods[#methods+1]=k end end
 end
 table.sort(fields); table.sort(methods)
 for i=#fields,LIMIT_KEYS+1,-1 do fields[i]=nil end
 for i=#methods,LIMIT_KEYS+1,-1 do methods[i]=nil end
 chunks('lighting fields:',fields)
 chunks('lighting methods:',methods)
end
function M.log(force)
 if M.done and not force then return true end
 if not g_currentMission or g_dedicatedServer~=nil then return false end
 M.done=true
 local ok,err=pcall(function()
  local list,names=M.collect()
  log(string.format('%d engine/stock functions match the atmosphere/tone keywords (names only, nothing called)',#list))
  local byWord={}
  for _,k in ipairs(list) do local w=names[k]; byWord[w]=byWord[w] or {}; table.insert(byWord[w],k) end
  local words={}
  for w in pairs(byWord) do words[#words+1]=w end
  table.sort(words)
  for _,w in ipairs(words) do chunks(w..':',byWord[w]) end
  local probes={'getAtmosphereCornettShrankAsymmetryFactor','setAtmosphereCornettShrankAsymmetryFactor','getFogGroundLevelDensity',
   'setFogGroundLevelDensity','getFogMaxHeight','setFogMaxHeight','getScreenSpaceShadowsParameters','setScreenSpaceShadowsParameters',
   'getToneMappingCurveSlope','setToneMappingCurveSlope','setLightScatteringDirection','getLightScatteringDirection'}
  local env=nativeEnvironment() or {}
  local present={}
  for _,name in ipairs(probes) do present[#present+1]=name..'='..tostring(type(env[name])=='function' or type(_G[name])=='function') end
  chunks('guarded controls:',present)
  describeLighting()
 end)
 if not ok then log('inventory failed: '..tostring(err)) end
 return ok
end
function M.reset() M.done=false end
