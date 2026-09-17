-- Display brightness through SettingsModel and direct sun RGB through the
-- mission Lighting owner. Neither path replaces sun/weather animation curves.
FS25E_GlobalLighting={locks={}}
local M=FS25E_GlobalLighting
local sunDefaults={sunIntensity=1,sunWarmth=0,sunTint=0}
local sunValues={};for id,value in pairs(sunDefaults) do sunValues[id]=value end
local sunRevisions={}
local sunRequests={}
local sunRecord=nil
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function contract()
 local model=g_settingsModel
 local key=SettingsModel and SettingsModel.SETTING and SettingsModel.SETTING.BRIGHTNESS
 local setting=model and key and model.settings and model.settings[key]
 local reader=model and key and model.settingReaders and model.settingReaders[key]
 local writer=model and key and model.settingWriters and model.settingWriters[key]
 local texts=model and model.brightnessTexts
 if not setting or setting.restartRequired or type(reader)~='function' or type(writer)~='function'
  or type(texts)~='table' or #texts<2 or g_dedicatedServer~=nil then return nil end
 return {model=model,key=key,setting=setting,reader=reader,writer=writer,texts=texts}
end
local function read(c)
 if not c then return nil end
 local ok,v=pcall(c.reader,c.key)
 if ok and finite(v) and v==math.floor(v) and v>=1 and v<=#c.texts then return v end
end
local function sync(c,value)
 -- Only brightness is synchronized; do not apply/reset pending vanilla options.
 c.setting.initial=value; c.setting.saved=value; c.setting.changed=value
end
function M.available()
 return read(contract())~=nil,'FS25E_status_brightnessUnavailable'
end
function M.setLocked(id,value) M.locks[id]=value==true end
function M.write(value,automatic)
 if automatic and M.locks.sceneBrightness then return false,'FS25E_status_locked' end
 if FS25E_ModSettings and FS25E_ModSettings.get and FS25E_ModSettings.get('enabled')~=true then return false,'FS25E_status_mod_disabled' end
 local c=contract(); local current=read(c)
 if current==nil then return false,'FS25E_status_brightnessUnavailable' end
 if not finite(value) or value~=math.floor(value) or value<1 or value>#c.texts then return false,'FS25E_status_invalidValue' end
 if M.record and M.record.model~=c.model then M.record=nil end
 if M.record and M.record.last~=current then M.record=nil end
 local record=M.record or {model=c.model,original=current}
 local ok,result=pcall(c.writer,value,c.key)
 local actual=read(c)
 if not ok or result==false or actual~=value then
  pcall(c.writer,current,c.key)
  actual=read(c)
  if actual==current then sync(c,current)
  else record.last=actual; record.pendingRestore=true; M.record=record end
  return false,'FS25E_status_applyFailed'
 end
 record.last=actual; record.pendingRestore=false; M.record=record; sync(c,actual)
 return true
end
function M.restoreBrightness()
 local r=M.record; if not r then return true end
 local c=contract()
 if not c or c.model~=r.model then M.record=nil; return true end
 local current=read(c)
 if current==nil then return false end
 if not r.pendingRestore and current~=r.last then M.record=nil; return true end
 local ok,result=pcall(c.writer,r.original,c.key)
 if not ok or result==false or read(c)~=r.original then r.pendingRestore=true; return false end
 sync(c,r.original); M.record=nil; return true
end
local function sunContext()
 local lighting=g_currentMission and g_currentMission.environment and g_currentMission.environment.lighting
 local node=lighting and lighting.sunLightId
 if g_dedicatedServer~=nil or not FS25E_LightDiscovery or not FS25E_LightDiscovery.isLightSource(node)
  or type(getLightColor)~='function' or type(setLightColor)~='function' then return nil end
 local ok,r,g,b=pcall(getLightColor,node)
 if not ok or not finite(r) or not finite(g) or not finite(b) then return nil end
 return {owner=lighting,node=node,color={r,g,b}}
end
local function sameColor(a,b)
 if not a or not b then return false end
 for i=1,3 do if not finite(a[i]) or not finite(b[i]) or math.abs(a[i]-b[i])>0.0001*math.max(1,math.abs(a[i]),math.abs(b[i])) then return false end end
 return true
end
local function writeSun(c,color)
 local ok,result=pcall(setLightColor,c.node,color[1],color[2],color[3])
 local checked=sunContext()
 return ok and result~=false and checked and checked.owner==c.owner and checked.node==c.node and sameColor(checked.color,color)
end
function M.sunAvailable() return sunContext()~=nil,'FS25E_status_sunUnavailable' end
function M.applySun()
 if next(sunRequests)==nil then return true end
 if FS25E_ModSettings and FS25E_ModSettings.get and FS25E_ModSettings.get('enabled')~=true then return false,'FS25E_status_mod_disabled' end
 local c=sunContext(); if not c then return false,'FS25E_status_sunUnavailable' end
 if sunRecord and (sunRecord.owner~=c.owner or sunRecord.node~=c.node) then sunRecord=nil end
 local r=sunRecord or {owner=c.owner,node=c.node,original=c.color}
 -- Lighting changes RGB with time/weather. Track that native baseline, never
 -- multiply our already applied color again and never rewrite the sky curves.
 if r.last and not sameColor(r.last,c.color) and not r.pendingRestore then r.original=c.color end
 local v=r.original; local warmth,tint=sunValues.sunWarmth,sunValues.sunTint
 local red,green,blue=v[1]*4^warmth*2^tint,v[2]*4^(-tint),v[3]*4^(-warmth)*2^tint
 local before=0.2126*v[1]+0.7152*v[2]+0.0722*v[3]
 local after=0.2126*red+0.7152*green+0.0722*blue
 local multiplier=after>0.00001 and before/after*sunValues.sunIntensity or 0
 local wanted={red*multiplier,green*multiplier,blue*multiplier}
 if not sameColor(c.color,wanted) and not writeSun(c,wanted) then
  r.pendingRestore=not writeSun(c,c.color);r.last=c.color;sunRecord=r
  return false,'FS25E_status_applyFailed'
 end
 r.last=wanted;r.pendingRestore=false;sunRecord=r
 return true,before<=0.00001 and 'FS25E_status_sunInactive' or nil
end
function M.writeSun(id,value,automatic)
 if sunValues[id]==nil or not finite(value) then return false,'FS25E_status_invalidValue' end
 if automatic and M.locks[id] then return false,'FS25E_status_locked' end
 if FS25E_ModSettings and FS25E_ModSettings.get and FS25E_ModSettings.get('enabled')~=true then return false,'FS25E_status_mod_disabled' end
 local ready,reason=M.sunAvailable();if not ready then return false,reason end
 -- The sun never goes fully dark through this path; the sky curves stay alive.
 local lo,hi=id=='sunIntensity' and 0.05 or -1,id=='sunIntensity' and 8 or 1
 local previous,wasRequested=sunValues[id],sunRequests[id]
 sunValues[id]=math.max(lo,math.min(hi,value));sunRequests[id]=true
 local applied,status=M.applySun()
 if not applied then sunValues[id]=previous;sunRequests[id]=wasRequested
 else sunRevisions[id]=(sunRevisions[id] or 0)+1 end
 return applied,status
end
function M.getSunValue(id) return sunValues[id] end
function M.getSunRevision(id) return sunRevisions[id] or 0 end
function M.restoreSun(id)
 if id then
  if sunDefaults[id]==nil then return false end
  sunRequests[id]=nil;sunValues[id]=sunDefaults[id];sunRevisions[id]=(sunRevisions[id] or 0)+1
 else
  sunRequests={};for key,value in pairs(sunDefaults) do sunValues[key]=value;sunRevisions[key]=(sunRevisions[key] or 0)+1 end
 end
 local r=sunRecord
 if r then
  local c=sunContext()
  if c and c.owner==r.owner and c.node==r.node then
   if r.pendingRestore or sameColor(c.color,r.last) then
    if not writeSun(c,r.original) then r.pendingRestore=true;return false end
   end
  end
  sunRecord=nil
 end
 if id and next(sunRequests)~=nil then return M.applySun() end
 return true
end
-- The engine's Lighting:update rewrites the sun colour and the sun light's
-- shadow properties from the day/weather curves. One appended hook per owner
-- re-applies every environment request straight after that pass. A second hook
-- on the same function would only repeat the identical work.
function M.ensureOwnerHook(owner)
 if owner==nil or type(owner.update)~='function' or not FS25E_HookManager then return false end
 return FS25E_HookManager.register(owner,'update','appended',function(target)
  local env=g_currentMission and g_currentMission.environment
  if not env or env.lighting~=target then return end
  if next(sunRequests)~=nil then M.applySun() end
  local environment=FS25E_EnvironmentLighting
  if environment and environment.applyRequested then environment.applyRequested() end
 end,'fs25e.lightingOwnerUpdate')
end
function M.update()
 if next(sunRequests)==nil then return end
 local c=sunContext()
 -- Lighting can be temporarily absent during an environment reload. Retain the
 -- user's requests and wait; only an actual rejected native write is a failure.
 if not c then return true,'FS25E_status_sunUnavailable' end
 M.ensureOwnerHook(c.owner)
 return M.applySun()
end
function M.getDiagnostics()
 local c=sunContext();local r=sunRecord
 local owns=c and r and c.owner==r.owner and c.node==r.node
 local applied=owns and not r.pendingRestore and next(sunRequests)~=nil and sameColor(c.color,r.last)
 local active=c and (c.color[1]>0 or c.color[2]>0 or c.color[3]>0)
 local original=owns and r.original or (c and c.color)
 local function copy(v) return v and {v[1],v[2],v[3]} or nil end
 return {total=c and 1 or 0,active=active and 1 or 0,applied=applied and 1 or 0,
  failed=r and r.pendingRestore and 1 or 0,sunNode=c and c.node or nil,
  originalRGB=copy(original),currentRGB=c and copy(c.color) or nil,
  brightnessIndex=read(contract()),brightnessApplied=M.record~=nil}
end
function M.getRequestedValues()
 local values={};for id in pairs(sunRequests) do values[id]=sunValues[id] end
 if M.record then values.sceneBrightness=M.record.last end
 return values
end
function M.restore()
 local brightness=M.restoreBrightness();local sun=M.restoreSun()
 return brightness and sun
end
function M.reset()
 local ok=M.restore()
 if ok then M.locks={} end
 return ok
end
function M.getControls()
 local control={id='sceneBrightness',category='lighting',min=1,max=16,step=1,kind='enum',cost='low',
  labelKey='FS25E_setting_sceneBrightness',tooltipKey='FS25E_tooltip_sceneBrightness',verification='native readback',
  read=function() return read(contract()) end,write=M.write,restore=M.restoreBrightness}
 control.available=function()
  local c=contract(); if c then control.max=#c.texts end
  return M.available()
 end
 control.format=function(value)
  local c=contract(); return c and c.texts[value] or '-'
 end
 -- Persist the physical brightness, since the option list can vary by platform.
 control.toStored=function(value) local c=contract(); return c and tonumber(c.texts[value]) end
 control.fromStored=function(value)
  local c=contract(); if c then for i,text in ipairs(c.texts) do if tonumber(text)==value then return i end end end
 end
 -- Sun intensity/warmth/tint are exposed once, under Environment
 -- (FS25E_EnvironmentLighting); a second copy here only confused the menu.
 return {control}
end
