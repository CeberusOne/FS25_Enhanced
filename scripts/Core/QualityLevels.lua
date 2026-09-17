-- One selector for every quality-type control: Low / Medium / High / Very high
-- / Ultra. Ultra sets each member to its maximum. Off hands everything back.
-- Purely aesthetic controls (colour, field of view, tone curve, moods) are not
-- members: a quality level must not change the look, only the effort.
FS25E_QualityLevels={locks={},index=0}
local M=FS25E_QualityLevels
-- id -> five values; 'max' means "the control's own maximum at that level".
local LEVELS={
 -- draw distance / LOD
 -- Object draw distance: anything above ~1.05 pushes the vehicle view too far out.
 {'view-distance-coeff',           {0.7,1.0,1.05,1.05,'max'}},
 {'lod-distance-coeff',            {0.7,1.0,1.25,1.5,'max'}},
 {'terrain-lod-distance-coeff',    {0.7,1.0,1.25,1.5,'max'}},
 {'foliage-view-distance-coeff',   {0.7,1.0,1.25,1.5,'max'}},
 {'foliage-lod-distance-coeff',    {0.7,1.0,1.25,1.5,'max'}},
 {'volume-mesh-tessellation-coeff',{0.6,1.0,1.25,1.5,'max'}},
 {'tyre-tracks-segments-coeff',    {0.5,1.0,2.0,3.0,'max'}},
 -- shadows
 {'allow-foliage-shadows',         {0,1,1,1,'max'}},
 {'max-num-shadow-lights',         {2,4,6,10,'max'}},
 {'shadow-distance-quality',       {0,1,2,2,'max'}},
 {'shadow-filter-quality',         {0,0,1,1,'max'}},
 {'shadow-quality',                {1,2,3,4,'max'}},
 {'shadow-map-filter-size',        {1,1,2,2,'max'}},
 {'cloud-shadows-quality',         {0,1,1,1,'max'}},
 {'screen-space-shadows-quality',  {'min','mid','max','max','max'}},
 {'spot-shadow-full-resolution-percentage',{0.1,0.3,0.5,0.8,'max'}},
 {'localShadows',                  {0,1,1,1,'max'}},
 {'localShadowBudget',             {2,4,6,10,'max'}},
 {'vehicleShadowRange',            {40,80,120,160,'max'}},
 {'nearShadowResolution',          {0,1,2,3,'max'}},
 {'farShadowResolution',           {0,0,1,2,'max'}},
 -- lamps
 {'relevantLightBudget',           {8,16,24,40,'max'}},
 {'iesBudget',                     {4,8,12,20,'max'}},
 {'scatteringBudget',              {0,4,8,16,'max'}},
 {'scatteringDistance',            {20,40,60,120,'max'}},
 {'lightHighRadius',               {20,35,45,80,'max'}},
 {'lightMediumRadius',             {50,100,150,200,'max'}},
 {'lightsProfile',                 {1,3,4,5,'max'}},
 {'maxMirrors',                    {1,3,5,7,'max'}},
 -- image / atmosphere / reflections
 {'ssao-quality',                  {1,2,3,4,'max'}},
 {'ssr-quality',                   {'min','mid','max','max','max'}},
 {'atmosphere-quality',            {'min','mid','max','max','max'}},
 {'volumetric-fog-quality',        {'min','mid','max','max','max'}},
 {'lensflare-quality',             {'min','max','max','max','max'}},
 -- materials / wet world / rain
 {'paintReflectivity',             {0.8,1.0,1.3,1.8,2.5}},
 {'wetSurfaceShininess',           {1.0,1.0,1.5,2.0,3.0}},
 {'wetSurfaceIntensity',           {1.0,1.0,1.2,1.5,2.0}},
 {'groundWetnessScale',            {1.0,1.0,1.1,1.25,1.5}},
 {'rain-amount-mult',              {0.5,1.0,1.25,1.5,'max'}},
}
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function resolve(c,spec)
 if spec=='max' then return c.max end
 if spec=='min' then return c.min end
 if spec=='mid' then return c.min+math.floor(((c.max-c.min)/2)/c.step+0.5)*c.step end
 return spec
end
function M.setLocked(id,value) M.locks[id]=value==true end
function M.available()
 return FS25E_VisualControls~=nil and FS25E_VisualControls.apply~=nil,'FS25E_status_missingApi'
end
--- Apply a level. Members that are unavailable right now are skipped and the
--- result is reported as partial; nothing else is held back by them.
function M.set(index,automatic)
 if automatic and M.locks.enhancedLevel then return false,'FS25E_status_locked' end
 if not finite(index) or index~=math.floor(index) or index<0 or index>5 then return false,'FS25E_status_invalidValue' end
 local api=FS25E_VisualControls
 if not api then return false,'FS25E_status_missingApi' end
 if index==0 then
  local ok=true
  for _,row in ipairs(LEVELS) do
   local c=api.get(row[1])
   if c and (api.getState(row[1]) or {}).original~=nil and not api.restore(row[1]) then ok=false end
  end
  if ok then M.index=0 end
  return ok
 end
 local applied,skipped,failed=0,0,0
 for _,row in ipairs(LEVELS) do
  local id,c=row[1],api.get(row[1])
  if c then
   if api.available(c) then
    local value=resolve(c,row[2][index])
    if finite(value) then
     if api.apply(id,value,{preset=true}) then applied=applied+1 else failed=failed+1 end
    end
   else skipped=skipped+1 end
  end
 end
 M.index=index
 M.lastResult={applied=applied,skipped=skipped,failed=failed}
 if FS25E_Debug then FS25E_Debug.info('QualityLevels',string.format('level %d applied=%d skipped=%d failed=%d',index,applied,skipped,failed)) end
 if failed>0 or skipped>0 then return true,'FS25E_status_profile_partial' end
 return true
end
function M.restore() return M.set(0) end
function M.restoreAll() return M.set(0) end
function M.init() M.index=0; return true end
function M.reset() M.index=0; M.locks={}; return true end
function M.getRequestedValues() return M.index>0 and {enhancedLevel=M.index} or {} end
function M.getDiagnostics() return M.lastResult or {} end
function M.getControls()
 return {{id='enhancedLevel',category='presets',min=0,max=5,step=1,kind='enum',cost='high',
  compositeProfile=true,profileSelector=true,
  labelKey='FS25E_setting_enhancedLevel',tooltipKey='FS25E_tooltip_enhancedLevel',
  format=function(v)
   local key='FS25E_value_level'..tostring(math.floor(v or 0))
   return FS25E_Localization and FS25E_Localization.t and FS25E_Localization.t(key) or tostring(v)
  end,
  read=function() return M.index end,
  write=function(v) return M.set(v) end,
  restore=function() return M.set(0) end,
  available=function() return M.available() end}}
end
