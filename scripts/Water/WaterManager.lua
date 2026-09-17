-- Existing native water surfaces only; no guessed mission fields or water-level edits.
FS25E_WaterManager={locks={},records={},hooks={},value=nil}
local M=FS25E_WaterManager
local getter='getShallowWaterSimulationFoamAccumulationRate'
local setter='setShallowWaterSimulationFoamAccumulationRate'
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function equal(a,b) return finite(a) and finite(b) and math.abs(a-b)<=0.0001*math.max(1,math.abs(a),math.abs(b)) end
local function valid(n) return type(entityExists)=='function' and n~=nil and n~=0 and entityExists(n) end
local function own(id,r) return r.mission==g_currentMission and valid(id) end
local function hasSurface(r) for plane in pairs(r.planes) do if valid(plane) then return true end end; return false end
local function sample(id) if type(_G[getter])~='function' then return nil end; local ok,v=pcall(_G[getter],id); if ok and finite(v) and v>=0 then return v end end
local function set(id,value)
 if type(_G[setter])~='function' then return false end
 local ok,result=pcall(_G[setter],id,value); return ok and result~=false and equal(sample(id),value)
end
function M.setLocked(id,value) M.locks[id]=value==true end
function M.install()
 if g_dedicatedServer~=nil then return true end
 local registrations={shallowWaterSimulationAddWaterPlaneGeometry=true,shallowWaterSimulationRemoveWaterPlaneGeometry=false}
 for name,adding in pairs(registrations) do if not M.hooks[name] and type(_G[name])=='function' then
  local original=_G[name]
  local wrapper=function(id,plane,...)
   local result=original(id,plane,...)
   if result~=false and valid(id) and valid(plane) and g_currentMission then
    local r=M.records[id]
    if r and r.mission~=g_currentMission then M.records[id]=nil; r=nil end
    if adding and sample(id)~=nil then
     if not r then
      local count=0; for key,record in pairs(M.records) do if own(key,record) then count=count+1 else M.records[key]=nil end end
      if count<16 then r={mission=g_currentMission,planes={}}; M.records[id]=r end
     end
     if r then r.planes[plane]=true end
    elseif r then r.planes[plane]=nil end
   end
   return result
  end
  M.hooks[name]={original=original,wrapper=wrapper}; _G[name]=wrapper
 end end
 -- Re-created native ids must never inherit the previous simulation's baseline.
 local name='createShallowWaterSimulation'
 if not M.hooks[name] and type(_G[name])=='function' then
  local original=_G[name]; local wrapper=function(...) local id=original(...); if id~=nil then M.records[id]=nil end; return id end
  M.hooks[name]={original=original,wrapper=wrapper}; _G[name]=wrapper
 end
 return true
end
function M.available(id)
 if id~='waterFoam' or g_dedicatedServer~=nil then return false,'FS25E_status_waterAssetsRequired' end
 if type(_G[getter])~='function' or type(_G[setter])~='function' then return false,'FS25E_status_missingApi' end
 for sim,r in pairs(M.records) do if own(sim,r) and hasSurface(r) and sample(sim)~=nil then return true end end
 return false,'FS25E_status_waterAssetsRequired'
end
function M.restore()
 local ok=true
 for sim,r in pairs(M.records) do
  if not own(sim,r) then M.records[sim]=nil
  elseif r.baseline~=nil then
   local current=sample(sim)
   if current==nil then ok=false
   elseif equal(current,r.applied) then
    if set(sim,r.baseline) then r.baseline=nil; r.applied=nil
    else r.applied=sample(sim) or r.applied; ok=false end
   else r.baseline=nil; r.applied=nil end -- newer foreign setting wins
  end
 end
 M.value=nil -- Keep failed restore records, never a request to reapply old foam settings.
 return ok
end
function M.write(value,automatic)
 if FS25E_ModSettings and FS25E_ModSettings.get and FS25E_ModSettings.get('enabled')~=true then return false,'FS25E_status_mod_disabled' end
 if automatic and M.locks.waterFoam then return false,'FS25E_status_locked' end
 if not finite(value) then return false,'FS25E_status_invalidValue' end
 local ok,reason=M.available('waterFoam'); if not ok then return false,reason end
 value=math.max(0,math.min(2,value))
 for sim,r in pairs(M.records) do if own(sim,r) and hasSurface(r) then
  local current=sample(sim)
  if current~=nil then
   if r.baseline==nil or not equal(current,r.applied) then r.baseline=current end
   local desired=r.baseline*value
   if not set(sim,desired) then
    r.applied=sample(sim) or desired
    M.restore(); return false,'FS25E_status_applyFailed'
   end
   r.applied=desired
  end
 end end
 M.value=value; return true
end
function M.reset()
 local ok=M.restore(); if not ok then M.value=nil; return false end
 for name,h in pairs(M.hooks) do if _G[name]==h.wrapper then _G[name]=h.original end end
 M.hooks={}; M.records={}; M.value=nil; M.locks={}; return true
end
function M.getRequestedValues() return M.value~=nil and {waterFoam=M.value} or {} end
function M.getControls()
 local out={}
 -- The wet-environment controls live in FS25E_WetSurfaceManager; this module
 -- keeps the one shallow-water control that works on the stock simulation.
 out[#out+1]={id='waterFoam',category='water',labelKey='FS25E_setting_waterFoam',tooltipKey='FS25E_tooltip_waterFoam',
  min=0,max=2,step=0.001,cost='medium',experimental=true,read=function() return M.value or 1 end,
  write=M.write,restore=M.restore,available=function() return M.available('waterFoam') end}
 return out
end
