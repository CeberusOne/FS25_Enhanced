-- Wet environment: the engine's global wetness that drives terrain, puddle
-- decals and the "wet look" of world objects, plus the wet-response parameters
-- of the placeable/building shaders and the SSR roughness of water planes.
--
-- Wetness only touches ground, buildings/roads (placeableShader,
-- buildingShader, vertexPaintShader), puddles and water (oceanShader).
-- Vehicles are handled by MaterialManager. Trees, crops and grass have no
-- wetness contract, so the world never turns into one uniform mirror.
--
-- The same scan also feeds the Vegetation tab (trees are MESH_SPLIT_SHAPE
-- nodes, crops/grass are the block shapes of the terrain foliage layers,
-- both carrying the authored materials of data/shaders/treeBranchShader.xml,
-- treeBillboardShader.xml, fruitGrowthFoliageShader.xml and
-- translucencyShader.xml) and the depth controls of the Environment tab
-- (buildingShader dirtMossMix, placeableShader mossLevel, vertexPaintShader
-- contrastLuminiosity). Each control is one authored shader parameter,
-- scaled or set, read back and restored like everything else.
--
-- Sources: data/shaders/placeableShader.xml (wetnessScale, wetShininess),
-- data/shaders/buildingShader.xml (wetnessScale), data/shaders/oceanShader.xml
-- (ssrRoughness), scriptBinding.xml Rendering: setWetness/getWetness.
FS25E_WetSurfaceManager={values={},locks={},records={},byMaterial={},skip={},queue={},queueHead=1,queueIndex={},
 elapsed=0,warned={},stats={}}
local M=FS25E_WetSurfaceManager
-- One record per shared material. A forest of one tree type is one record,
-- every silo of one model is one record; writes go to the shared material
-- (shared=true) so no per-node material instances are created.
local FRAME_BUDGET,SCAN_BUDGET,RESCAN_MS,MAX_RECORDS,MAX_NODES_PER_MATERIAL=96,160,15000,4000,4
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function clamp(v,lo,hi) return math.max(lo,math.min(hi,v)) end
local function equal(a,b) return finite(a) and finite(b) and math.abs(a-b)<0.0001 end
local function valid(node) return type(entityExists)=='function' and node~=nil and node~=0 and entityExists(node) end
local function enabled()
 return not FS25E_ModSettings or not FS25E_ModSettings.get or FS25E_ModSettings.get('enabled')==true
end
-- id -> {parameter, component index, shader classes, absolute?, ceiling, category}
-- Relative controls multiply the authored value and are clamped to `ceiling`.
local defs={
 -- wet world (category water)
 {id='wetSurfaceShininess',parameter='wetShininess',shaders={placeable=true,vertexPaint=true},min=0.25,max=4,step=0.001,default=1,ceiling=1},
 {id='wetSurfaceIntensity',parameter='wetnessScale',shaders={placeable=true,building=true,vertexPaint=true},min=0,max=3,step=0.001,default=1,ceiling=4},
 {id='waterReflectionRoughness',parameter='ssrRoughness',shaders={ocean=true},min=0,max=1,step=0.001,default=0,absolute=true},
 -- Map puddle decals (puddleShader.xml). Their opacity already follows the
 -- global wetness through the surfaceWetnessOpacity variation; this scales it.
 {id='puddleOpacity',parameter='waterOpacity',shaders={puddle=true},min=0,max=3,step=0.001,default=1,ceiling=1},
 -- vegetation (category foliage), data/shaders/*.xml:
 -- treeBranchShader windSnowLeafScale 1 1 1 0 (x = wind), seasonalTintIntensity
 --   0.30 0.30 0.40 (spring/summer/autumn tint per tree, SEASONAL variation),
 --   backfaceDiffuseScale 0.35 0.0 (x scales, y adds back light), aoIntensity 1.0
 --   (exponent on the SSAO term), treeBillboardShader windSnowLeafScale /
 --   seasonalTintIntensity, backgroundTreesShader seasonalTintIntensity,
 -- fruitGrowthFoliageShader windScale 1 / aoIntensity 2.0 0.5 (x = baked AO
 --   exponent) / translucencyAmount 0.0, translucencyShader translucencyAmount 0.35.
 {id='treeWind',parameter='windSnowLeafScale',shaders={treeBranch=true,treeBillboard=true},min=0,max=3,step=0.001,default=1,ceiling=4,category='foliage'},
 {id='treeTintVariation',parameter='seasonalTintIntensity',components=3,shaders={treeBranch=true,treeBillboard=true,backgroundTrees=true},min=0,max=4,step=0.001,default=1,ceiling=1,category='foliage'},
 {id='canopyOcclusion',parameter='aoIntensity',shaders={treeBranch=true},min=0,max=3,step=0.001,default=1,ceiling=4,category='foliage'},
 {id='leafBacklight',parameter='backfaceDiffuseScale',shaders={treeBranch=true},min=0,max=4,step=0.001,default=1,ceiling=2,category='foliage'},
 {id='leafBacklightBase',parameter='backfaceDiffuseScale',index=2,shaders={treeBranch=true},min=0,max=1,step=0.001,default=0,absolute=true,category='foliage'},
 {id='cropWind',parameter='windScale',shaders={cropFoliage=true},min=0,max=3,step=0.001,default=1,ceiling=10,category='foliage'},
 {id='cropOcclusion',parameter='aoIntensity',shaders={cropFoliage=true},min=0,max=3,step=0.001,default=1,ceiling=6,category='foliage'},
 {id='cropTranslucency',parameter='translucencyAmount',shaders={cropFoliage=true},min=0,max=1,step=0.001,default=0,absolute=true,category='foliage'},
 {id='foliageTranslucency',parameter='translucencyAmount',shaders={translucency=true},min=0,max=3,step=0.001,default=1,ceiling=1,category='foliage'},
 -- depth of world surfaces (category environment), data/shaders/*.xml:
 -- buildingShader dirtMossMix 1.0 1.0 (x moss, y dirt mask intensity),
 -- placeableShader mossLevel 1.0 (rockDetail variation),
 -- vertexPaintShader contrastLuminiosity 1.0 0.0.
 {id='buildingMoss',parameter='dirtMossMix',shaders={building=true},min=0,max=2,step=0.001,default=1,ceiling=1,category='environment'},
 {id='buildingDirt',parameter='dirtMossMix',index=2,shaders={building=true},min=0,max=2,step=0.001,default=1,ceiling=1,category='environment'},
 {id='rockMoss',parameter='mossLevel',shaders={placeable=true},min=0,max=2,step=0.001,default=1,ceiling=1,category='environment'},
 {id='surfaceContrast',parameter='contrastLuminiosity',shaders={vertexPaint=true},min=0.5,max=2,step=0.001,default=1,ceiling=3,category='environment'},
 {id='surfaceLuminosity',parameter='contrastLuminiosity',index=2,shaders={vertexPaint=true},min=-0.5,max=0.5,step=0.001,default=0,absolute=true,category='environment'},
}
local byId={};for _,d in ipairs(defs) do byId[d.id]=d end
local SHADERS={['placeableshader.xml']='placeable',['buildingshader.xml']='building',['oceanshader.xml']='ocean',['puddleshader.xml']='puddle',
 ['treebranchshader.xml']='treeBranch',['treebillboardshader.xml']='treeBillboard',['backgroundtreesshader.xml']='backgroundTrees',
 ['fruitgrowthfoliageshader.xml']='cropFoliage',['translucencyshader.xml']='translucency',['vertexpaintshader.xml']='vertexPaint'}
--- Component indices a control writes (float3 tints scale all three).
local function indices(d)
 if d.components then local t={}; for i=1,d.components do t[i]=i end; return t end
 return {d.index or 1}
end
local required={'entityExists','getHasClassId','getNumOfChildren','getChildAt','getNumOfMaterials','getMaterial',
 'getMaterialCustomShaderFilename','getHasShaderParameter','getShaderParameter','setShaderParameter','getRootNode'}

-- ---------------------------------------------------------------- wetness --
-- Resolve the environment GIANTS' own scripts run in, so a hook on setWetness
-- sees the stock weather code and not just this mod.
local function nativeEnvironment()
 if M.nativeEnv then return M.nativeEnv end
 local owner=I3DManager or g_i3DManager
 local source=owner and owner.loadI3DFile
 if type(source)=='function' and type(getfenv)=='function' then
  local ok,env=pcall(getfenv,source)
  if ok and type(env)=='table' and type(env.setWetness)=='function' then M.nativeEnv=env end
 end
 M.nativeEnv=M.nativeEnv or _G
 return M.nativeEnv
end
local function wetnessRequested()
 return (M.values.groundWetnessScale~=nil and not equal(M.values.groundWetnessScale,1))
  or (M.values.groundWetnessHold~=nil and M.values.groundWetnessHold>0)
end
--- Map the engine's own wetness onto the requested look. The hold only slows
--- the way down, so surfaces stay damp after the rain has stopped.
local function transform(raw,dt)
 local scale=M.values.groundWetnessScale or 1
 local target=clamp(raw*scale,0,1)
 local hold=M.values.groundWetnessHold or 0
 if hold>0 and M.held~=nil and target<M.held then
  target=math.max(target,M.held-(dt or 0)/(hold*60000))
 end
 M.held=target
 return target
end
local function rawSetter()
 local h=M.wetnessHook
 return h and h.original or (type(setWetness)=='function' and setWetness) or nil
end
local function readWetness()
 if type(getWetness)~='function' then return nil end
 local ok,v=pcall(getWetness); if ok and finite(v) then return v end
end
function M.install()
 if g_dedicatedServer~=nil or M.wetnessHook then return true end
 local env=nativeEnvironment(); local original=env.setWetness
 if type(original)~='function' then return true end
 local hook
 local wrapper=function(w,...)
  if M.wetnessHook~=hook or not finite(w) then return original(w,...) end
  M.raw=w; M.observed=true
  if not enabled() or not wetnessRequested() then M.ours=nil; return original(w,...) end
  local out=transform(w,0); M.ours=out
  return original(out,...)
 end
 hook={env=env,original=original,wrapper=wrapper}; M.wetnessHook=hook; env.setWetness=wrapper
 -- If the weather writes wetness natively after the Lua update, the update
 -- hook alone is too early. The draw pass is the last Lua moment before the
 -- frame renders, so the override is repeated there as well.
 if FS25E_HookManager and FSBaseMission and type(FSBaseMission.draw)=='function' then
  FS25E_HookManager.register(FSBaseMission,'draw','appended',function()
   if wetnessRequested() and g_currentMission then M.applyWetness(0) end
  end,'fs25e.wetness.draw')
 end
 return true
end
local function wetnessAvailable()
 if g_dedicatedServer~=nil or type(getWetness)~='function' or type(setWetness)~='function' then return false,'FS25E_status_missingApi' end
 return readWetness()~=nil,'FS25E_status_missingApi'
end
local function writeWetness(id,value)
 local ok,reason=wetnessAvailable(); if not ok then return false,reason end
 local d=id=='groundWetnessScale' and {min=0,max=3} or {min=0,max=60}
 M.values[id]=clamp(value,d.min,d.max)
 if M.raw==nil then M.raw=readWetness() end
 M.held=nil
 M.applyWetness(0)
 return true,M.observed and nil or 'FS25E_status_observedOnly'
end
--- Per-frame reconciliation. When the weather writes wetness natively (not
--- through the Lua setter) the hook never fires; then the value read back is
--- the engine's own unless it is exactly what this module wrote last.
function M.applyWetness(dt)
 if not enabled() or not wetnessRequested() then
  if M.ours~=nil and M.raw~=nil then local set=rawSetter(); if set then pcall(set,M.raw) end; M.ours=nil end
  return true
 end
 local current=readWetness(); if current==nil then return true,'FS25E_status_missingApi' end
 -- Evidence for the log: after a write, does the next frame still read our
 -- value (override sticks) or the engine's own again (rewritten natively)?
 if M.ours~=nil then
  if equal(current,M.ours) then M.stickCount=(M.stickCount or 0)+1 else M.overwriteCount=(M.overwriteCount or 0)+1 end
 end
 if M.ours==nil or not equal(current,M.ours) then M.raw=current end
 local target=transform(M.raw or current,dt)
 if not equal(target,current) then
  local set=rawSetter(); if not set then return false,'FS25E_status_missingApi' end
  local ok=pcall(set,target); if not ok then return false,'FS25E_status_applyFailed' end
 end
 M.ours=target
 return true
end
local function restoreWetness(id)
 if id then M.values[id]=nil else M.values.groundWetnessScale=nil; M.values.groundWetnessHold=nil end
 M.held=nil
 if not wetnessRequested() and M.ours~=nil and M.raw~=nil then
  local set=rawSetter(); if set then pcall(set,M.raw) end
  M.ours=nil
 end
 return true
end

-- -------------------------------------------------------------- materials --
function M.apiAvailable()
 if g_dedicatedServer~=nil or not ClassIds or not ClassIds.SHAPE then return false end
 for _,fn in ipairs(required) do if type(_G[fn])~='function' then return false end end
 return true
end
local function read(node,name,slot) return {getShaderParameter(node,name,slot)} end
--- Stale material ids (no entity any more) must not reach the engine: every
--- query on them prints a script error. entityExists is calibrated once: if
--- the engine still answers for an id it calls dead, the check is dropped.
local function materialAlive(material)
 if material==nil or material==0 then return false end
 if M.stats.materialGuard==false then return true end
 local alive=valid(material)
 if alive then M.stats.materialGuard=true; return true end
 if M.stats.materialGuard==nil then
  local ok=pcall(getMaterialCustomShaderFilename,material)
  if ok then M.stats.materialGuard=false; return true end
 end
 return false
end
local function inspect(node,slot)
 local material=getMaterial(node,slot)
 if not materialAlive(material) then M.stats.badMaterials=(M.stats.badMaterials or 0)+1; return nil end
 local okShader,shader=pcall(getMaterialCustomShaderFilename,material)
 if not okShader then M.stats.badMaterials=(M.stats.badMaterials or 0)+1; return nil end
 shader=type(shader)=='string' and shader:gsub('\\','/'):lower() or ''
 local class=SHADERS[shader:match('([^/]+)$') or '']
 if not class then return nil end
 local params={}
 for _,d in ipairs(defs) do
  if d.shaders[class] then
   local ok,has=pcall(getHasShaderParameter,node,d.parameter,slot)
   if ok and has then
    local got,v=pcall(read,node,d.parameter,slot)
    local complete=got
    for _,i in ipairs(indices(d)) do if not finite(v[i]) then complete=false end end
    if complete then params[d.parameter]=true end
   end
  end
 end
 if next(params)==nil then return nil end
 return {material=material,node=node,slot=slot,nodes={{node=node,slot=slot}},class=class,params=params,original={},applied={},mission=g_currentMission}
end
local function enqueue(r,id)
 local key=tostring(r.material)..':'..id
 if M.queueIndex[key] then return end
 M.queueIndex[key]=true; M.queue[#M.queue+1]={r=r,id=id,key=key}
end
local function enqueueRecord(r)
 for id in pairs(M.values) do local d=byId[id]; if d and d.shaders[r.class] and r.params[d.parameter] then enqueue(r,id) end end
end
local function isVehicleRoot(node)
 local vehicles=g_currentMission and g_currentMission.vehicleSystem and g_currentMission.vehicleSystem.vehicles or {}
 for _,v in pairs(vehicles) do if type(v)=='table' and v.rootNode==node then return true end end
 return false
end
--- Shapes carry materials; map trees are MESH_SPLIT_SHAPE nodes, which the
--- engine reports as their own class (TreePlantManager tests both).
local function shapeClass(node)
 local ok,shape=pcall(getHasClassId,node,ClassIds.SHAPE)
 if ok and shape then return 'shape' end
 if ClassIds.MESH_SPLIT_SHAPE then
  local ok2,split=pcall(getHasClassId,node,ClassIds.MESH_SPLIT_SHAPE)
  if ok2 and split then return 'split' end
 end
end
--- Budgeted depth-first walk of the whole scene. Vehicle subtrees are skipped
--- (MaterialManager owns them); the walk is resumed across frames.
local function processScan()
 local stack=M.scanQueue; if not stack or #stack==0 then return end
 local seen=M.scanSeen
 local nodes=0
 while #stack>0 and nodes<SCAN_BUDGET do
  local node=table.remove(stack); nodes=nodes+1
  if valid(node) and not seen[node] and not isVehicleRoot(node) then
   seen[node]=true
   local class=shapeClass(node)
   if class=='split' then
    M.stats.splitShapes=(M.stats.splitShapes or 0)+1
    -- Probe the material API once on the first split shape: a native call
    -- that rejects the class prints a script error per call, so an
    -- unsupported build is detected on one node and never asked again.
    if M.stats.splitProbe==nil then
     local a=pcall(getNumOfMaterials,node); local b=pcall(getMaterial,node,0); local c=pcall(getHasShaderParameter,node,'windSnowLeafScale',0)
     M.stats.splitProbe=(a and b and c) and 'ok' or 'unsupported'
     if M.stats.splitProbe~='ok' and FS25E_Debug then FS25E_Debug.warning('WetSurfaceManager','split shapes (trees) do not accept the material API on this build; tree controls stay on plain shapes') end
    end
    if M.stats.splitProbe~='ok' then class=nil end
   end
   if class then
    local counted,count=pcall(getNumOfMaterials,node)
    if counted and finite(count) then for slot=0,count-1 do
     local got,material=pcall(getMaterial,node,slot)
     local r=got and material and M.byMaterial[material] or nil
     if r then
      -- Another node using a material we already track: keep it as a spare
      -- access path in case the first node gets deleted.
      if #r.nodes<MAX_NODES_PER_MATERIAL then r.nodes[#r.nodes+1]={node=node,slot=slot} end
     elseif got and material and not M.skip[material] and #M.records<MAX_RECORDS then
      local good,rec=pcall(inspect,node,slot)
      if good and rec then M.byMaterial[material]=rec; M.records[#M.records+1]=rec; enqueueRecord(rec)
      else M.skip[material]=true end
     end
    end end
   end
   local counted,count=pcall(getNumOfChildren,node)
   if counted and finite(count) then for i=0,count-1 do local ok2,child=pcall(getChildAt,node,i); if ok2 then stack[#stack+1]=child end end end
  end
 end
end
local function startScan()
 if not M.apiAvailable() then return end
 local ok,root=pcall(getRootNode)
 if not ok or not valid(root) then return end
 if M.scanMission~=g_currentMission then M.skip={}; M.stats={} end
 M.stats.splitShapes=0
 M.scanQueue={root}; M.scanSeen={}; M.scanMission=g_currentMission
end
--- Pick a live node that still carries the record's material.
local function own(r)
 if r.mission~=g_currentMission then return false end
 for i=1,#r.nodes do
  local n=r.nodes[i]
  if valid(n.node) then
   local got,material=pcall(getMaterial,n.node,n.slot)
   if got and material==r.material then r.node=n.node; r.slot=n.slot; return true end
  end
 end
 return false
end
--- Write the given components of a shader vector on the SHARED material
--- (shared=true): every node using it changes at once and no material
--- instance is cloned. nil keeps a component, the way Washable writes a
--- single channel. `expected` (index -> value) is verified by read-back.
local function writeParams(r,name,args,expected)
 local ok,result=pcall(setShaderParameter,r.node,name,args[1],args[2],args[3],args[4],true,r.slot)
 if not ok or result==false then return false end
 if not expected then return true end
 local got,current=pcall(read,r.node,name,r.slot); if not got then return false end
 for i,v in pairs(expected) do if not equal(current[i],v) then return false end end
 return true
end
local function slotKey(d,i) return d.parameter..'#'..tostring(i) end
local function applyRecord(r,id)
 local d=byId[id]; local value=M.values[id]
 if not d or value==nil or not own(r) or not d.shaders[r.class] or not r.params[d.parameter] then return nil end
 local got,current=pcall(read,r.node,d.parameter,r.slot)
 if not got then return nil end
 local args,desired,changed={nil,nil,nil,nil},{},false
 for _,i in ipairs(indices(d)) do
  if not finite(current[i]) then return nil end
  local key=slotKey(d,i); local previous=r.applied[key]
  if previous~=nil and not equal(current[i],previous) then
   -- Someone else moved this component; adopt that as the new baseline.
   r.original[key]=current[i]
  elseif r.original[key]==nil then r.original[key]=current[i] end
  local v=d.absolute and value or clamp(r.original[key]*value,0,d.ceiling or 4)
  desired[i]=v; args[i]=v
  if not equal(v,current[i]) then changed=true end
 end
 if changed and not writeParams(r,d.parameter,args,desired) then
  local back={nil,nil,nil,nil}; for i in pairs(desired) do back[i]=current[i] end
  writeParams(r,d.parameter,back,nil); return false
 end
 for i,v in pairs(desired) do r.applied[slotKey(d,i)]=v end
 return true
end
local function drain(budget)
 local done=0
 while M.queueHead<=#M.queue and done<budget do
  local item=M.queue[M.queueHead]; M.queueHead=M.queueHead+1
  M.queueIndex[item.key]=nil
  if enabled() then
   local ok=applyRecord(item.r,item.id)
   if ok==false and FS25E_Debug and not M.warned[item.id] then
    M.warned[item.id]=true
    FS25E_Debug.warning('WetSurfaceManager','native write rejected for '..item.id)
   end
  end
  done=done+1
 end
 if M.queueHead>#M.queue then M.queue={}; M.queueIndex={}; M.queueHead=1 end
end
local function materialAvailable(id)
 local d=byId[id]
 if not d or not M.apiAvailable() then return false,'FS25E_status_missingApi' end
 if M.scanMission~=g_currentMission then startScan() end
 for _,r in ipairs(M.records) do if own(r) and d.shaders[r.class] and r.params[d.parameter] then return true end end
 if M.scanQueue and #M.scanQueue>0 then return false,'FS25E_status_waitScan' end
 return false,'FS25E_status_noWetSurfaces'
end
local function writeMaterial(id,value)
 local d=byId[id]
 local ok,reason=materialAvailable(id); if not ok then return false,reason end
 M.values[id]=clamp(value,d.min,d.max)
 local count=0
 for _,r in ipairs(M.records) do if own(r) and d.shaders[r.class] and r.params[d.parameter] then enqueue(r,id); count=count+1 end end
 drain(48)
 M.lastApply={id=id,value=M.values[id],materials=count}
 return true
end
local function restoreMaterial(id)
 local d=byId[id]; local ok=true
 for _,r in ipairs(M.records) do
  local args,any={nil,nil,nil,nil},false
  local alive=own(r)
  local got,current=false,nil
  if alive then got,current=pcall(read,r.node,d.parameter,r.slot) end
  for _,i in ipairs(indices(d)) do
   local key=slotKey(d,i); local original=r.original[key]
   -- Only a component that still holds our value is put back; anything
   -- another mod or the game moved meanwhile is left alone.
   if original~=nil and alive and got and r.applied[key]~=nil and equal(current[i],r.applied[key]) then args[i]=original; any=true end
   r.original[key]=nil; r.applied[key]=nil
  end
  if any and not writeParams(r,d.parameter,args,nil) then ok=false end
 end
 if ok then M.values[id]=nil end
 return ok
end

-- --------------------------------------------------------------- contract --
function M.setLocked(id,value) M.locks[id]=value==true end
function M.available(id)
 if id=='groundWetnessScale' or id=='groundWetnessHold' then return wetnessAvailable() end
 return materialAvailable(id)
end
function M.write(id,value,automatic)
 if not enabled() then return false,'FS25E_status_mod_disabled' end
 if automatic and M.locks[id] then return false,'FS25E_status_locked' end
 if not finite(value) then return false,'FS25E_status_invalidValue' end
 if id=='groundWetnessScale' or id=='groundWetnessHold' then return writeWetness(id,value) end
 if byId[id] then return writeMaterial(id,value) end
 return false,'FS25E_status_invalidValue'
end
function M.restore(id)
 if not id then
  local ok=restoreWetness()
  for _,d in ipairs(defs) do if not restoreMaterial(d.id) then ok=false end end
  return ok
 end
 if id=='groundWetnessScale' or id=='groundWetnessHold' then return restoreWetness(id) end
 if byId[id] then return restoreMaterial(id) end
 return true
end
function M.restoreAll() return M.restore() end
function M.init()
 M.records={}; M.byMaterial={}; M.queue={}; M.queueIndex={}; M.queueHead=1; M.raw=nil; M.ours=nil; M.held=nil
 startScan()
 return true
end
function M.update(dt)
 local delta=math.max(0,tonumber(dt) or 0)
 M.elapsed=M.elapsed+delta
 if M.scanMission~=g_currentMission then startScan() end
 processScan()
 if M.elapsed>=RESCAN_MS then
  M.elapsed=0
  -- Drop records whose node is gone; new placeables get picked up by a rescan.
  local live={}
  for _,r in ipairs(M.records) do if own(r) then live[#live+1]=r else M.byMaterial[r.material]=nil end end
  M.records=live
  if not M.scanQueue or #M.scanQueue==0 then startScan() end
 end
 drain(FRAME_BUDGET)
 return M.applyWetness(delta)
end
function M.reset()
 local ok=M.restore()
 local h=M.wetnessHook
 if h and h.env.setWetness==h.wrapper then h.env.setWetness=h.original end
 M.wetnessHook=nil; M.records={}; M.byMaterial={}; M.skip={}; M.stats={}; M.queue={}; M.queueIndex={}; M.queueHead=1
 M.scanQueue=nil; M.scanSeen=nil; M.scanMission=nil; M.locks={}; M.warned={}; M.raw=nil; M.ours=nil; M.held=nil; M.observed=nil
 return ok
end
function M.getRequestedValues()
 local out={}; for id,v in pairs(M.values) do out[id]=v end; return out
end
function M.getDiagnostics()
 local byClass={placeable=0,building=0,ocean=0,puddle=0,treeBranch=0,treeBillboard=0,backgroundTrees=0,cropFoliage=0,translucency=0,vertexPaint=0}
 for _,r in ipairs(M.records) do byClass[r.class]=(byClass[r.class] or 0)+1 end
 local sticks=(M.stickCount or 0)+(M.overwriteCount or 0)>0 and string.format('%d/%d',M.stickCount or 0,(M.stickCount or 0)+(M.overwriteCount or 0)) or 'n/a'
 return {materials=#M.records,placeableMaterials=byClass.placeable,buildingMaterials=byClass.building,waterMaterials=byClass.ocean,puddleMaterials=byClass.puddle,
  wetnessSticks=sticks,
  treeMaterials=byClass.treeBranch,treeBillboardMaterials=byClass.treeBillboard+byClass.backgroundTrees,cropMaterials=byClass.cropFoliage,
  translucentMaterials=byClass.translucency,paintedSurfaces=byClass.vertexPaint,splitShapes=M.stats.splitShapes or 0,splitProbe=M.stats.splitProbe or 'none',badMaterials=M.stats.badMaterials or 0,
  pendingNodes=M.scanQueue and #M.scanQueue or 0,engineWetness=readWetness(),appliedWetness=M.ours,wetnessHookObserved=M.observed==true}
end
function M.getControls()
 local out={}
 out[#out+1]={id='groundWetnessScale',category='water',min=0,max=3,step=0.001,cost='low',
  labelKey='FS25E_setting_groundWetnessScale',tooltipKey='FS25E_tooltip_groundWetnessScale',verification='native readback',
  read=function() return M.values.groundWetnessScale or 1 end,
  write=function(v) return M.write('groundWetnessScale',v) end,
  restore=function() return M.restore('groundWetnessScale') end,
  available=function() return M.available('groundWetnessScale') end}
 out[#out+1]={id='groundWetnessHold',category='water',min=0,max=60,step=0.5,cost='low',
  labelKey='FS25E_setting_groundWetnessHold',tooltipKey='FS25E_tooltip_groundWetnessHold',verification='configuration',
  format=function(v) return string.format('%.1f min',v) end,
  read=function() return M.values.groundWetnessHold or 0 end,
  write=function(v) return M.write('groundWetnessHold',v) end,
  restore=function() return M.restore('groundWetnessHold') end,
  available=function() return M.available('groundWetnessHold') end}
 for _,def in ipairs(defs) do local d=def
  out[#out+1]={id=d.id,category=d.category or 'water',min=d.min,max=d.max,step=d.step,cost='medium',verification='configuration',
   labelKey='FS25E_setting_'..d.id,tooltipKey='FS25E_tooltip_'..d.id,
   read=function() return M.values[d.id] or d.default end,
   write=function(v) return M.write(d.id,v) end,
   restore=function() return M.restore(d.id) end,
   available=function() return M.available(d.id) end}
 end
 return out
end
