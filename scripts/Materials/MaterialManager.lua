-- Opt-in per-material contract. No shared/global shader edits or variation switches.
FS25E_MaterialManager={records={},values={},locks={},vehicle=nil,targets={},elapsed=1000,retryElapsed=10000,
 pending={},pendingIndex={},pendingHead=1,warned={}}
-- Shader writes are spread over frames: a slider step touches up to ~1500
-- material slots, and doing that synchronously is what stuttered the game.
local IMMEDIATE_BUDGET,FRAME_BUDGET,RESCAN_MS,WETNESS_MS=48,96,10000,2000
local M=FS25E_MaterialManager
local defs={
 {id='paintClearcoat',parameter='clearCoatIntensity',index=1,min=0,max=1,step=0.001},
 {id='paintSmoothness',parameter='clearCoatSmoothness',index=1,min=0,max=1,step=0.001},
 {id='paintSSRThreshold',parameter='ssrParameters',index=1,min=0,max=1,step=0.001},
 {id='paintSSRBaseBias',parameter='ssrParameters',index=2,min=-1,max=1,step=0.001},
 {id='paintSSRCoatBias',parameter='ssrParameters',index=3,min=-1,max=1,step=0.001},
 {id='materialDetailSmoothness',parameter='smoothnessScale',index=1,min=0,max=10,step=0.001},
 {id='materialWetResponse',parameter='scratches_dirt_snow_wetness',index=4,min=0,max=2,step=0.001,relative=true,dynamic=true}
}
-- paintReflectivity drives the whole clear-coat/SSR chain at once and is
-- relative to each material's authored gloss, so it needs its own parameter set.
local COMPOSITE={clearCoatIntensity=true,clearCoatSmoothness=true,ssrParameters=true}
local required={'entityExists','getHasClassId','getNumOfChildren','getChildAt','getNumOfMaterials','getMaterial',
 'getMaterialCustomShaderFilename','getMaterialCustomShaderVariation',
 'getMaterialIsAlphaBlended','getMaterialIsAlphaTested','getHasShaderParameter','getShaderParameter','setShaderParameter'}
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function equal(a,b) return finite(a) and finite(b) and math.abs(a-b)<0.00001 end
local function valid(node) return type(entityExists)=='function' and node~=nil and node~=0 and entityExists(node) end
local function read(node,name,slot) return {getShaderParameter(node,name,slot)} end
local function same(a,b) for i=1,4 do if a[i]~=nil or b[i]~=nil then if not equal(a[i],b[i]) then return false end end end; return true end
local function copy(a) return {a[1],a[2],a[3],a[4]} end
-- $data/shared/detailLibrary/materialTemplates.xml: these exact
-- detailDiffuse/detailSpecular pairs are the authored paint and coated-plastic
-- templates. Shader name, colour, metalness or clear-coat values alone do not
-- identify paint, because glass, rubber and chrome share the same vehicleShader.
local paintMaps={
 -- category "calibrated": the vehicle paint templates
 ['calibrated/calibratedpaint_diffuse.png']={['calibrated/calibratedpaint_specular.png']=true,['calibrated/calibratedpaintbumpy_specular.png']=true},
 ['calibrated/metallicpaint_diffuse.png']={['calibrated/metallicpaint_specular.png']=true},
 ['calibrated/grainsmall_diffuse.png']={['calibrated/grainclearsmall_specular.png']=true},
 -- calibratedCastIron shares the clear diffuse map; only the pair is unique
 ['metallic/clear_diffuse.png']={['calibrated/castiron_specular.png']=true},
 -- category "nonMetallic/metal": painted and powder-coated metal
 ['nonmetallic/metal/metalpainted_diffuse.png']={['nonmetallic/metal/metalpainted_specular.png']=true,
  ['nonmetallic/metal/metalpaintedrough_specular.png']=true,['nonmetallic/metal/powdercoatmatte_specular.png']=true},
 ['nonmetallic/metal/metalpaintedgraphite_diffuse.png']={['nonmetallic/metal/metalpaintedgraphite_specular.png']=true},
 ['nonmetallic/metal/metalpaintedold_diffuse.png']={['nonmetallic/metal/metalpaintedold_specular.png']=true},
 -- category "nonMetallic/plastic": painted plastic incl. the shiny variants
 ['nonmetallic/plastic/plasticpainted_diffuse.png']={['nonmetallic/plastic/plasticpainted_specular.png']=true},
 -- category "mixed/carbon": clear-coated carbon
 ['mixed/carbonpattern02_diffuse.png']={['mixed/carbonpattern02_specular.png']=true}
}
-- Wood, fabric, dirt and snow are authored at porosity 1.0 and bare rubber at
-- 0.5. Powder-coated metal is the only coated template carrying porosity (0.1),
-- so the cut sits between them instead of rejecting every non-zero value.
local POROSITY_LIMIT=0.25
local function shaderValue(node,slot,name,index)
 local hasOK,has=pcall(getHasShaderParameter,node,name,slot)
 if not hasOK or not has then return nil end
 local ok,value=pcall(read,node,name,slot)
 if ok and finite(value[index or 1]) then return value[index or 1] end
end
--- Decide whether a material may take part in the gloss/reflection controls.
--- Returns eligible, className. A material qualifies either because it uses an
--- authored paint template, or because it carries a real clear-coat layer of
--- its own. That second path is what picks up a lacquered rubber or plastic
--- part automatically, without ever touching bare rubber, glass or unknown assets.
local function paintClassification(node,slot,material,variation)
 local blendOK,blended=pcall(getMaterialIsAlphaBlended,material)
 local testOK,tested=pcall(getMaterialIsAlphaTested,material)
 if not blendOK or not testOK or blended or tested then return false,'transparent' end
 variation=type(variation)=='string' and variation:lower() or ''
 if variation:find('glass',1,true) or variation:find('window',1,true) then return false,'glass' end
 -- Retro-reflectors are clear-coated by design but must keep their authored
 -- response; a mirror finish would destroy the retro-reflective look.
 if variation:find('reflector',1,true) then return false,'reflector' end
 local porosity=shaderValue(node,slot,'porosity')
 if porosity~=nil and porosity>POROSITY_LIMIT then return false,'porous' end
 -- Path 1: an authored clear coat means the surface is lacquered, whatever the
 -- base material underneath it happens to be.
 local clearCoat=shaderValue(node,slot,'clearCoatIntensity')
 if clearCoat~=nil and clearCoat>0.001 then return true,'coated' end
 -- Path 2: the GIANTS paint templates, matched on their exact map pair.
 if type(getMaterialCustomMapFilename)~='function' then return false,'unverified' end
 local function detail(name)
  local ok,path=pcall(getMaterialCustomMapFilename,material,name)
  if not ok or type(path)~='string' then return nil end
  -- XML templates name PNG sources; the renderer may report the compiled DDS.
  -- Only the extension is normalized, preserving the exact path-pair allowlist.
  return path:gsub('\\','/'):lower():gsub('%.dds$','.png'):match('/shared/detaillibrary/(.+)$')
 end
 local diffuse,specular=detail('detailDiffuse'),detail('detailSpecular')
 if diffuse and specular and paintMaps[diffuse] and paintMaps[diffuse][specular] then return true,'paint' end
 return false,'unverified'
end
local function eligible(r,def)
 -- Wetness is independent. Every gloss control/profile requires verified
 -- paint, so rubber, transparent glass and unknown custom assets stay authored.
 return not def or def.dynamic or r.paintEligible==true
end
local function targetVehicle()
 if g_localPlayer and type(g_localPlayer.getCurrentVehicle)=='function' then
  local ok,v=pcall(g_localPlayer.getCurrentVehicle,g_localPlayer); if ok and v then return v end
 end
 return g_currentMission and g_currentMission.controlledVehicle or nil
end
local function targets(explicit)
 if explicit then return {explicit} end
 local active=targetVehicle(); local out,seen={},{}
 if active then out[1]=active; seen[active]=true end
 local vehicles=g_currentMission and g_currentMission.vehicleSystem and g_currentMission.vehicleSystem.vehicles or {}
 for _,v in pairs(vehicles) do
  if type(v)=='table' and not seen[v] then out[#out+1]=v; seen[v]=true end
 end
 -- Stable identity order avoids restarting discovery when pairs() order changes.
 table.sort(out,function(a,b) if a==active then return b~=active elseif b==active then return false end; return tostring(a.rootNode or a)<tostring(b.rootNode or b) end)
 return out
end
local function enabled()
 return not FS25E_ModSettings or not FS25E_ModSettings.get or FS25E_ModSettings.get('enabled')==true
end
local function vehicleNode(node)
 if M.vehicleNodes and M.vehicleNodes[node] then return true end
 -- World discovery can reach a loaded vehicle before its incremental vehicle
 -- traversal. Component roots and the real scene ancestry still identify it.
 local current=node
 for depth=1,256 do
  if M.vehicleRoots and M.vehicleRoots[current] then return true end
  if type(getParent)~='function' then break end
  local ok,parent=pcall(getParent,current)
  if not ok or not parent or parent==0 or parent==current then break end
  current=parent
 end
 return false
end
function M.setLocked(id,value) M.locks[id]=value==true end
function M.apiAvailable()
 if g_dedicatedServer~=nil or not ClassIds or not ClassIds.SHAPE then return false end
 for _,fn in ipairs(required) do if type(_G[fn])~='function' then return false end end
 return true
end
--- Stale material ids (no entity any more) must not reach the engine: every
--- query on them prints a script error. entityExists is calibrated once: if
--- the engine still answers for an id it calls dead, the check is dropped.
local function materialAlive(material)
 if material==nil or material==0 then return false end
 if M.materialGuard==false then return true end
 local alive=valid(material)
 if alive then M.materialGuard=true; return true end
 if M.materialGuard==nil then
  local ok=pcall(getMaterialCustomShaderFilename,material)
  if ok then M.materialGuard=false; return true end
 end
 return false
end
local function inspect(node,slot)
 local material=getMaterial(node,slot)
 if not materialAlive(material) then return nil end
 local shader=getMaterialCustomShaderFilename(material)
 shader=type(shader)=='string' and shader:gsub('\\','/'):lower() or ''
 -- Recognize a shader contract by basename; no map/install/vehicle path assumptions.
 if shader~='vehicleshader.xml' and not shader:match('/vehicleshader%.xml$') then return nil end
 local variation=getMaterialCustomShaderVariation(material)
 -- Discover individual parameter contracts first. Eligibility for gloss is
 -- checked separately so wetness remains independent of paint classification.
 local compatible=false
 for _,d in ipairs(defs) do
  if getHasShaderParameter(node,d.parameter,slot) then
   local ok,value=pcall(read,node,d.parameter,slot)
   if ok and finite(value[d.index]) then compatible=true; break end
  end
 end
 if not compatible then return nil end
 local paintEligible,materialClass=paintClassification(node,slot,material,variation)
 return {node=node,slot=slot,material=material,shader=shader,variation=variation,paintEligible=paintEligible,materialClass=materialClass,
  original={},applied={},mission=g_currentMission}
end
local function processDiscovery()
 local stack,seen=M.scanQueue or {},M.scanSeen or {}
 local added,nodes=0,0
 while #stack>0 and nodes<128 do
  local node=table.remove(stack); nodes=nodes+1
  if valid(node) and not seen[node] then
   seen[node]=true
   M.vehicleNodes=M.vehicleNodes or {}; M.vehicleNodes[node]=true
   local ok,shape=pcall(getHasClassId,node,ClassIds.SHAPE)
   if ok and shape then
    local counted,count=pcall(getNumOfMaterials,node)
    if counted and finite(count) then for slot=0,count-1 do
     local compatible,r=pcall(inspect,node,slot)
     if compatible and r then
      local key=tostring(node)..':'..slot
     local old=M.bySlot[key]
      if old then old.source='vehicle' end
      if not old or old.mission~=g_currentMission then
       r.source='vehicle'
       M.bySlot[key]=r; M.records[#M.records+1]=r; added=added+1
       M.enqueueRecord(r)
      end
     end
    end end
   end
   local counted,count=pcall(getNumOfChildren,node)
   if counted and finite(count) then for i=0,count-1 do local ok,child=pcall(getChildAt,node,i); if ok then stack[#stack+1]=child end end end
  end
 end
 return added
end
function M.refresh(vehicle)
 if M.refreshing then return #M.records>0 end
 if not M.apiAvailable() then return false end
 -- available()/read() call this from every drawn material row every frame.
 -- The vehicle-set check and the live sweep over ~1500 slots only need to run
 -- once a second; the periodic update() drives that cadence.
 local now=tonumber(g_time) or 0
 if not vehicle and M.refreshedAt and now-M.refreshedAt<1000 and now>=M.refreshedAt then return #M.records>0 end
 M.refreshedAt=now
 M.bySlot=M.bySlot or {}
 local selected=targets(vehicle); local unchanged=#selected==#M.targets
 for i,v in ipairs(selected) do if M.targets[i]~=v then unchanged=false end end
 M.vehicleRoots={}
 for _,v in ipairs(selected) do
  if v.rootNode then M.vehicleRoots[v.rootNode]=true end
  for _,c in ipairs(v.components or {}) do if c.node then M.vehicleRoots[c.node]=true end end
 end
 if not unchanged then M.vehicleNodes={} end
 local live={};local changed=false
 for _,r in ipairs(M.records) do
  local ok,material=false,nil
  if r.mission==g_currentMission and valid(r.node) then ok,material=pcall(getMaterial,r.node,r.slot) end
  if ok and material~=nil then
   -- Washable/Wearable write with shared=false too, which hands the node a
   -- fresh material instance. The slot is still ours; only the id moved.
   r.material=material
   if vehicleNode(r.node) then r.source='vehicle' end
   live[#live+1]=r
  else M.bySlot[tostring(r.node)..':'..r.slot]=nil;changed=true end
 end
 M.records=live
 if unchanged and not changed and ((M.scanQueue and #M.scanQueue>0) or M.retryElapsed<RESCAN_MS) then return #M.records>0 end
 M.retryElapsed=0;M.vehicle=selected[1];M.targets=selected;M.scanQueue={};M.scanSeen={}
 for vi=#selected,1,-1 do local v=selected[vi];local added=false
  for _,c in ipairs(v.components or {}) do if c.node then M.scanQueue[#M.scanQueue+1]=c.node;added=true end end
  if not added and v.rootNode then M.scanQueue[#M.scanQueue+1]=v.rootNode end
 end
 -- Keep existing private-slot originals and requests when entering/leaving a
 -- vehicle or a shop preview loads. Late children/material replacements are
 -- rediscovered even when another material was already found successfully.
 processDiscovery()
 return #M.records>0
end
local function own(r)
 return r.mission==g_currentMission and valid(r.node)
end
local function writeVector(r,name,value)
 local ok,result=pcall(setShaderParameter,r.node,name,value[1],value[2],value[3],value[4],false,r.slot)
 local got,material=pcall(getMaterial,r.node,r.slot); if got then r.material=material end
 local checked,current=pcall(read,r.node,name,r.slot)
 return ok and result~=false and checked and same(value,current)
end
function M.available(id)
 if not M.apiAvailable() then return false,'FS25E_status_missingApi' end
 M.refresh()
 if id=='paintSSRThreshold' or id=='paintSSRBaseBias' or id=='paintSSRCoatBias' or id=='paintReflectivity' then
  local enum=ScreenSpaceReflectionsQuality
  if not enum or enum.OFF==nil or type(getScreenSpaceReflectionsQuality)~='function' then return false,'FS25E_status_quality_unavailable' end
  local readOK,quality=pcall(getScreenSpaceReflectionsQuality)
  if not readOK or quality==enum.OFF then return false,'FS25E_status_ssrDisabled' end
 end
 if id=='paintReflectivity' then
  for _,r in ipairs(M.records) do if own(r) and r.paintEligible then return true end end
  return false,'FS25E_status_noVerifiedPaint'
 end
 local def; if id then for _,d in ipairs(defs) do if d.id==id then def=d end end end
 for _,r in ipairs(M.records) do if own(r) and eligible(r,def) then
  if not def then return true end
  local ok,has=pcall(getHasShaderParameter,r.node,def.parameter,r.slot)
  if ok and has then local got,value=pcall(read,r.node,def.parameter,r.slot); if got and finite(value[def.index]) then return true end end
 end end
 return false,def and not def.dynamic and 'FS25E_status_noVerifiedPaint' or 'FS25E_status_noCompatiblePaint'
end
local function clamp(v,lo,hi) return math.max(lo,math.min(hi,v)) end
--- Claim one shader parameter for this record and set it from its own authored
--- original. Returns nil when the parameter does not exist, false when the
--- native write was rejected (the slot is put back before returning).
local function requestVector(r,name,build)
 local supports,has=pcall(getHasShaderParameter,r.node,name,r.slot)
 if not supports or not has then return nil end
 local got,current=pcall(read,r.node,name,r.slot)
 if not got or not finite(current[1]) then return nil end
 local previous=r.applied[name]
 if previous and not same(current,previous) then
  -- Another mod owns this parameter now: drop our claim instead of fighting.
  r.original[name]=nil; r.applied[name]=nil
  return nil
 end
 if not r.original[name] then r.original[name]=copy(current) end
 local desired=build(copy(r.original[name]))
 if same(desired,current) then r.applied[name]=desired; return true end
 if not writeVector(r,name,desired) then
  local checked,actual=pcall(read,r.node,name,r.slot)
  if checked then r.applied[name]=actual end
  if writeVector(r,name,current) then r.applied[name]=current end
  return false
 end
 r.applied[name]=desired
 return true
end
--- Apply the paint reflection chain to one record, always relative to what
--- the material was authored with. A matte powder coat (clear coat 0) keeps
--- its look, gloss and metallic paint turn into a real mirror, and materials
--- without a clear coat contract are never touched at all.
local function applyReflectivity(r,value)
 if not r.paintEligible then return nil end
 local delta=value-1
 local coatOK=requestVector(r,'clearCoatIntensity',function(o) o[1]=clamp(o[1]*value,0,1); return o end)
 local smoothOK=requestVector(r,'clearCoatSmoothness',function(o) o[1]=clamp(o[1]*value,0,1); return o end)
 local authored=r.original.clearCoatIntensity and r.original.clearCoatIntensity[1] or 0
 -- How much of the reflection change this surface may take: fully coated
 -- paint gets all of it, a clear-coat-free matte surface gets none.
 local weight=clamp(authored*2,0,1)
 local ssrOK=requestVector(r,'ssrParameters',function(o)
  local coat=clamp(authored*value,0,1)
  -- X is the clear-coat threshold: below it SSR samples the hazy base layer.
  -- Pull it under the new coat intensity so polished paint reflects through
  -- the coat instead of through the diffuse base.
  if delta>0 then o[1]=math.min(o[1],math.max(0,coat*0.9)) end
  -- Y/Z bias the roughness handed to screen space reflections. Negative is a
  -- sharper mirror, positive the veiled look the base layer ships with.
  o[2]=clamp(o[2]-delta*0.35*weight,-1,1)
  o[3]=clamp(o[3]-delta*0.35*weight,-1,1)
  return o end)
 if coatOK==false or smoothOK==false or ssrOK==false then return false end
 if coatOK or smoothOK or ssrOK then return true end
 return nil
end
function M.setReflectivity(value,automatic)
 if not enabled() then return false,'FS25E_status_mod_disabled' end
 if automatic and M.locks.paintReflectivity then return false,'FS25E_status_locked' end
 if not finite(value) then return false,'FS25E_status_invalidValue' end
 local ok,reason=M.available('paintReflectivity'); if not ok then return false,reason end
 M.values.paintReflectivity=clamp(value,0,3)
 local count=M.enqueueAll('paintReflectivity')
 if count==0 then M.values.paintReflectivity=nil; return false,'FS25E_status_noVerifiedPaint' end
 M.drain(IMMEDIATE_BUDGET)
 M.lastApply={id='paintReflectivity',value=M.values.paintReflectivity,materials=count}
 M.profile=0; M.profileDirty=true
 return true
end
--- Put every parameter of the composite back to its authored vector.
function M.restoreReflectivity(source)
 local ok=true
 for _,r in ipairs(M.records) do if (source==nil or r.source==source) and own(r) then
  for name in pairs(COMPOSITE) do
   local original=r.original[name]
   if original then
    local got,current=pcall(read,r.node,name,r.slot)
    if not got then ok=false
    elseif r.applied[name] and same(current,r.applied[name]) then
     if writeVector(r,name,original) then r.original[name]=nil; r.applied[name]=nil
     else
      local checked,actual=pcall(read,r.node,name,r.slot)
      if checked then r.applied[name]=actual end
      ok=false
     end
    else r.original[name]=nil; r.applied[name]=nil end
   end
  end
 end end
 if ok and source==nil then M.values.paintReflectivity=nil; M.profile=0; M.profileDirty=next(M.values)~=nil end
 return ok
end
--- Apply one single-parameter request to one record. Returns true (written or
--- already correct), false (native write rejected) or nil (not applicable).
local function applyDef(r,def,value)
 if not eligible(r,def) then return nil end
 local supports,has=pcall(getHasShaderParameter,r.node,def.parameter,r.slot)
 if not supports or not has then return nil end
 local good,current=pcall(read,r.node,def.parameter,r.slot)
 if not good or not finite(current[def.index]) then return nil end
 local previous=r.applied[def.parameter]
 local desired
 if def.dynamic then
  if not r.original[def.parameter] then r.original[def.parameter]=copy(current) end
  -- Washable keeps writing the gameplay wetness into W; follow that baseline.
  if previous and not equal(current[def.index],previous[def.index]) then r.original[def.parameter][def.index]=current[def.index] end
  desired=copy(current); desired[def.index]=math.max(0,math.min(1,r.original[def.parameter][def.index]*value))
 elseif previous and not same(current,previous) then
  -- A different mod owns this parameter now: leave it alone.
  r.original[def.parameter]=nil; r.applied[def.parameter]=nil
  return nil
 else
  if not r.original[def.parameter] then r.original[def.parameter]=copy(current) end
  desired=copy(current); desired[def.index]=value
 end
 if same(desired,current) then r.applied[def.parameter]=desired; return true end
 if not writeVector(r,def.parameter,desired) then
  -- A native setter may log an error without throwing. Put this exact slot
  -- back immediately; the other slots keep their values.
  local got,actual=pcall(read,r.node,def.parameter,r.slot)
  if got then r.applied[def.parameter]=actual end
  if writeVector(r,def.parameter,current) then r.applied[def.parameter]=current end
  return false
 end
 r.applied[def.parameter]=desired
 return true
end
local defById={}; for _,d in ipairs(defs) do defById[d.id]=d end
--- Apply the current request of one id to one record.
local function applyRecord(r,id)
 if not own(r) then return nil end
 local value=M.values[id]; if value==nil then return nil end
 if id=='paintReflectivity' then return applyReflectivity(r,value) end
 return applyDef(r,defById[id],value)
end
--- Queue a record/id pair; duplicates collapse onto the pending entry.
local function enqueue(r,id)
 local key=tostring(r.node)..':'..r.slot..':'..id
 if M.pendingIndex[key] then return end
 M.pendingIndex[key]=true
 M.pending[#M.pending+1]={r=r,id=id,key=key}
end
function M.enqueueRecord(r)
 for id in pairs(M.values) do enqueue(r,id) end
end
function M.enqueueAll(id)
 local count=0
 local def=defById[id]
 for _,r in ipairs(M.records) do
  if own(r) and ((id=='paintReflectivity' and r.paintEligible) or (def and eligible(r,def))) then enqueue(r,id); count=count+1 end
 end
 return count
end
--- Drain up to `budget` queued writes. A rejected write is logged once per id
--- and that slot is left alone; it no longer cancels the whole request.
function M.drain(budget)
 local done=0
 while M.pendingHead<=#M.pending and done<budget do
  -- Consumed slots stay in place until the queue is empty: a nil hole at the
  -- front would make the length operator lie about what is still pending.
  local item=M.pending[M.pendingHead]; M.pendingHead=M.pendingHead+1
  M.pendingIndex[item.key]=nil
  if enabled() then
   local ok=applyRecord(item.r,item.id)
   if ok==false and FS25E_Debug and not M.warned[item.id] then
    M.warned[item.id]=true
    FS25E_Debug.warning('MaterialManager','native write rejected for '..item.id..'; slot left at its authored value')
   end
  end
  done=done+1
 end
 if M.pendingHead>#M.pending then M.pending={}; M.pendingIndex={}; M.pendingHead=1 end
 return done
end
function M.write(id,value,automatic)
 if id=='paintReflectivity' then return M.setReflectivity(value,automatic) end
 if not enabled() then return false,'FS25E_status_mod_disabled' end
 if automatic and M.locks[id] then return false,'FS25E_status_locked' end
 local def=defById[id]
 if not def or not finite(value) then return false,'FS25E_status_invalidValue' end
 local ok,reason=M.available(id); if not ok then return false,reason end
 local previous=M.values[id]
 M.values[id]=math.max(def.min,math.min(def.max,value))
 local count=M.enqueueAll(id)
 if count==0 then M.values[id]=previous; return false,'FS25E_status_noCompatiblePaint' end
 -- The first slots are written right away so the change shows on the vehicle
 -- in front of the camera; the rest follows over the next frames.
 M.drain(IMMEDIATE_BUDGET)
 M.lastApply={id=id,value=M.values[id],materials=count}; M.profile=0; M.profileDirty=true; return true
end
function M.restore(id,source)
 if id=='paintReflectivity' then return M.restoreReflectivity(source) end
 local def; if id then for _,d in ipairs(defs) do if d.id==id then def=d end end end
 local ok=true
 for _,r in ipairs(M.records) do if (source==nil or r.source==source) and own(r) then for name,original in pairs(r.original) do
  if not def or def.parameter==name then
   local got,current=pcall(read,r.node,name,r.slot)
   local dynamic=name=='scratches_dirt_snow_wetness'
   local owned=got and r.applied[name] and (dynamic and equal(current[4],r.applied[name][4]) or same(current,r.applied[name]))
   if not got then ok=false
   elseif owned then
    local desired=copy(current)
    if dynamic then desired[4]=original[4] elseif def then desired[def.index]=original[def.index] else desired=copy(original) end
    if writeVector(r,name,desired) then
     r.applied[name]=desired
     if not def then r.original[name]=nil; r.applied[name]=nil end
    else
     local checked,actual=pcall(read,r.node,name,r.slot)
     if checked then r.applied[name]=actual end
     ok=false
    end
   end
  end
 end end end
 if ok and source==nil then if id then M.values[id]=nil; M.profile=0; M.profileDirty=next(M.values)~=nil else M.values={}; M.profile=0; M.profileDirty=false end end
 return ok
end
function M.update(dt)
 local delta=math.max(0,tonumber(dt) or 0)
 M.elapsed=M.elapsed+delta; M.retryElapsed=M.retryElapsed+delta; M.wetElapsed=(M.wetElapsed or 0)+delta
 if M.elapsed>=1000 then M.elapsed=0; M.refresh() end
 -- Gameplay wetness moves slowly; following it every two seconds is plenty
 -- and keeps the old per-second full material sweep off the frame budget.
 if M.wetElapsed>=WETNESS_MS then
  M.wetElapsed=0
  if M.values.materialWetResponse~=nil then M.enqueueAll('materialWetResponse') end
 end
 if M.scanQueue and #M.scanQueue>0 then processDiscovery() end
 M.drain(FRAME_BUDGET)
end
function M.reset()
 local ok=M.restore(); if ok then M.records={}; M.values={}; M.vehicle=nil; M.targets={}; M.locks={}; M.scanQueue={}; M.scanSeen={}; M.bySlot={};M.vehicleRoots={};M.vehicleNodes={};M.refreshedAt=nil;M.pending={};M.pendingIndex={};M.pendingHead=1;M.warned={} end; return ok
end
function M.setProfile(index,automatic)
 if automatic and M.locks.materialSurfaceProfile then return false,'FS25E_status_locked' end
 if not finite(index) or index~=math.floor(index) or index<0 or index>3 then return false,'FS25E_status_invalidValue' end
 if index==0 then local ok=M.restore(); if ok then M.profile=0 end; return ok end
 -- Relative to each material's authored finish, so a matte powder coat is not
 -- turned into a mirror and a gloss paint is not flattened.
 local profiles={
  {paintReflectivity=1.5,materialDetailSmoothness=1},
  {paintReflectivity=2.5,materialDetailSmoothness=1.3},
  {paintReflectivity=0.25,materialDetailSmoothness=0.6}
 }
 local previous={}; for id,value in pairs(M.values) do previous[id]=value end
 for id in pairs(profiles[index]) do
  if automatic and M.locks[id] then return false,'FS25E_status_locked' end
  local ok,reason=M.available(id); if not ok then return false,reason end
 end
 for id,value in pairs(profiles[index]) do
  local ok,reason=M.write(id,value,automatic)
  if not ok then M.restore(); for key,old in pairs(previous) do M.write(key,old) end; return false,reason end
 end
 M.profile=index; M.profileDirty=false; return true
end
function M.getRequestedValues()
 local values={}; for id,value in pairs(M.values) do values[id]=value end; return values
end
function M.getControls()
 local out={{id='materialSurfaceProfile',category='materials',labelKey='FS25E_setting_materialSurfaceProfile',tooltipKey='FS25E_tooltip_materialSurfaceProfile',
 min=0,max=3,step=1,cost='low',experimental=true,compositeProfile=true,profileSelector=true,read=function() return M.profile or 0 end,write=M.setProfile,
 format=function(index)
  local key=index==0 and M.profileDirty and 'FS25E_value_custom' or ('FS25E_value_surfaceProfile'..tostring(index))
  return FS25E_Localization and FS25E_Localization.t and FS25E_Localization.t(key) or tostring(index)
 end,
 restore=function() return M.setProfile(0) end,available=function() return M.available('materialDetailSmoothness') end}}
 out[#out+1]={id='paintReflectivity',category='materials',labelKey='FS25E_setting_paintReflectivity',
  tooltipKey='FS25E_tooltip_paintReflectivity',min=0,max=3,step=0.001,cost='medium',
  read=function() return M.values.paintReflectivity or 1 end,
  write=function(v) return M.setReflectivity(v) end,
  restore=function() return M.restore('paintReflectivity') end,
  available=function() return M.available('paintReflectivity') end}
 for _,def in ipairs(defs) do local d=def; out[#out+1]={id=d.id,category='materials',labelKey='FS25E_setting_'..d.id,
 tooltipKey='FS25E_tooltip_'..d.id,min=d.min,max=d.max,step=d.step,cost='low',experimental=true,
 read=function() if d.relative then return M.values[d.id] or 1 end; M.refresh(); for _,r in ipairs(M.records) do if own(r) and eligible(r,d) then
  local ok,v=pcall(read,r.node,d.parameter,r.slot); if ok and finite(v[d.index]) then return v[d.index] end end end end,
 write=function(v) return M.write(d.id,v) end,restore=function() return M.restore(d.id) end,available=function() return M.available(d.id) end} end
 for _,id in ipairs({'materialMicrodetailStrength','materialNormalDetailScale'}) do
  out[#out+1]={id=id,category='materials',labelKey='FS25E_setting_'..id,tooltipKey='FS25E_tooltip_materialDetailAssets',cost='medium',experimental=true,
   read=function() return nil end,write=function() return false,'FS25E_status_detailAssetsRequired' end,
   available=function() return false,'FS25E_status_detailAssetsRequired' end,restore=function() return true end}
 end
 return out
end

function M.getDiagnostics()
 local vehicles,world,paint,coated=0,0,0,0
 for _,r in ipairs(M.records) do
  if r.source=='world' then world=world+1 else vehicles=vehicles+1 end
  if r.paintEligible then paint=paint+1 end
  if r.materialClass=='coated' then coated=coated+1 end
 end
 return {targets=#M.targets,materials=#M.records,vehicleMaterials=vehicles,
  verifiedPaintMaterials=paint,clearCoatMaterials=coated,
  pendingNodes=M.scanQueue and #M.scanQueue or 0,lastApply=M.lastApply}
end
