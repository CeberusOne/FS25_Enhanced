-- Curated environment light looks. A mood is nothing but a set of values for
-- the verified sun/scattering controls, applied through the same reversible
-- path as a manual slider, so "off" hands every member back to the game.
FS25E_LightingMoods={locks={},index=0}
local M=FS25E_LightingMoods
local MEMBERS={'environmentSunIntensity','environmentSunWarmth','environmentSunTint','environmentScatteringWarmth'}
local moods={
 {environmentSunIntensity=1.10,environmentSunWarmth=-0.05,environmentSunTint=0.00,environmentScatteringWarmth=0.00},
 {environmentSunIntensity=1.00,environmentSunWarmth=0.35,environmentSunTint=0.05,environmentScatteringWarmth=0.30},
 {environmentSunIntensity=0.85,environmentSunWarmth=-0.30,environmentSunTint=-0.05,environmentScatteringWarmth=-0.20},
 {environmentSunIntensity=1.15,environmentSunWarmth=0.55,environmentSunTint=0.10,environmentScatteringWarmth=0.50},
 {environmentSunIntensity=0.95,environmentSunWarmth=0.10,environmentSunTint=0.00,environmentScatteringWarmth=0.00},
}
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
function M.setLocked(id,value) M.locks[id]=value==true end
function M.available()
 local api=FS25E_VisualControls
 if not api or not api.available then return false,'FS25E_status_missingApi' end
 -- The mood is usable as soon as the sun itself is; scattering colour is an
 -- observed extra and must not block the selector.
 return api.available('environmentSunIntensity')
end
function M.set(index,automatic)
 if automatic and M.locks.environmentMood then return false,'FS25E_status_locked' end
 if not finite(index) or index~=math.floor(index) or index<0 or index>#moods then return false,'FS25E_status_invalidValue' end
 local api=FS25E_VisualControls
 if not api then return false,'FS25E_status_missingApi' end
 if index==0 then
  local ok=true
  for _,id in ipairs(MEMBERS) do if api.get(id) and not api.restore(id) then ok=false end end
  if ok then M.index=0 end
  return ok
 end
 local ready,reason=M.available(); if not ready then return false,reason end
 local ok,partial=true,false
 for id,value in pairs(moods[index]) do
  if api.get(id) then
   local available=api.available(id)
   if available then
    local applied=api.apply(id,value,{preset=true})
    if not applied and id~='environmentScatteringWarmth' then ok=false end
   elseif id~='environmentScatteringWarmth' then partial=true end
  end
 end
 if ok then M.index=index end
 return ok,(partial and 'FS25E_status_profile_partial') or nil
end
function M.restore() return M.set(0) end
function M.restoreAll() return M.set(0) end
function M.init() M.index=0; return true end
function M.reset() M.index=0; M.locks={}; return true end
function M.getRequestedValues() return M.index>0 and {environmentMood=M.index} or {} end
function M.getControls()
 return {{id='environmentMood',category='environment',min=0,max=#moods,step=1,kind='enum',cost='low',
  compositeProfile=true,profileSelector=true,
  labelKey='FS25E_setting_environmentMood',tooltipKey='FS25E_tooltip_environmentMood',
  format=function(v)
   local key='FS25E_value_mood'..tostring(math.floor(v or 0))
   return FS25E_Localization and FS25E_Localization.t and FS25E_Localization.t(key) or tostring(v)
  end,
  read=function() return M.index end,
  write=function(v) return M.set(v) end,
  restore=function() return M.set(0) end,
  available=function() return M.available() end}}
end
