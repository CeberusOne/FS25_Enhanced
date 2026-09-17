-- Extra foliage bending footprints. The game already bends grass and crops
-- under every active vehicle (FoliageBending specialization: each entry of
-- spec_foliageBending.bendingNodes carries a live rectangle id while the
-- vehicle is active) and under the player character on foot
-- (HumanGraphicsComponent.foliageBendingNode, a 1 m x 1 m rectangle).
-- This module adds one scaled rectangle per existing footprint through the
-- same foliageBendingSystem:createRectangle, so the bending radius grows or
-- shrinks without inventing equipment sizes. It works on foot, in any
-- vehicle, and (detail 2) around other active vehicles near the camera.
FS25E_FoliageManager={zones={},values={foliageInteractionRadius=1,foliageMaximumZones=8,foliageInteractionDetail=0},locks={},elapsed=0}
local M=FS25E_FoliageManager
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function valid(n) return type(entityExists)=='function' and n~=nil and n~=0 and entityExists(n) end
local function system() return g_currentMission and g_currentMission.foliageBendingSystem end
local function controlledVehicle()
 if g_localPlayer and type(g_localPlayer.getCurrentVehicle)=='function' then local ok,v=pcall(g_localPlayer.getCurrentVehicle,g_localPlayer); if ok and v then return v end end
 return g_currentMission and g_currentMission.controlledVehicle or nil
end
local function rootVehicle(v)
 if type(v)=='table' and type(v.getRootVehicle)=='function' then local ok,r=pcall(v.getRootVehicle,v); if ok and r then return r end end
 return v
end
local function cameraPosition()
 if type(getCamera)~='function' or type(getWorldTranslation)~='function' then return nil end
 local ok,cam=pcall(getCamera); if not ok or not valid(cam) then return nil end
 local got,x,y,z=pcall(getWorldTranslation,cam)
 if got and finite(x) and finite(y) and finite(z) then return x,y,z end
end
local function distanceTo(node,cx,cy,cz)
 if cx==nil or not valid(node) or type(getWorldTranslation)~='function' then return 0 end
 local ok,x,y,z=pcall(getWorldTranslation,node)
 if not ok or not finite(x) then return 0 end
 return math.sqrt((x-cx)^2+(y-cy)^2+(z-cz)^2)
end
--- The player's own bending node while on foot (HumanGraphicsComponent).
local function playerFootprint()
 if controlledVehicle()~=nil then return nil end
 local player=g_localPlayer or (g_currentMission and g_currentMission.player)
 local graphics=type(player)=='table' and player.graphicsComponent
 local node=type(graphics)=='table' and graphics.foliageBendingNode
 if valid(node) then return {node=node,minX=-0.5,maxX=0.5,minZ=-0.5,maxZ=0.5,yOffset=0.4,owner=player,key='player',distance=0} end
end
--- Footprints of active vehicles (bending nodes holding a live rectangle id).
--- Detail 1: the controlled vehicle and its attachments; detail 2: every
--- active vehicle, nearest to the camera first.
local function vehicleFootprints(detail)
 local out={}
 local own=rootVehicle(controlledVehicle())
 local cx,cy,cz=cameraPosition()
 local vehicles=g_currentMission and g_currentMission.vehicleSystem and g_currentMission.vehicleSystem.vehicles or {}
 for _,v in pairs(vehicles) do
  if type(v)=='table' and (detail>=2 or (own~=nil and rootVehicle(v)==own)) then
   local spec=v.spec_foliageBending
   local nodes=type(spec)=='table' and spec.bendingNodes
   if type(nodes)=='table' then
    local distance=distanceTo(v.rootNode,cx,cy,cz)
    for index,b in ipairs(nodes) do
     -- Only active, existing specialization footprints; no invented equipment sizes.
     if b.id~=nil and valid(b.node) and finite(b.minX) and finite(b.maxX) and finite(b.minZ) and finite(b.maxZ) and finite(b.yOffset) then
      out[#out+1]={node=b.node,minX=b.minX,maxX=b.maxX,minZ=b.minZ,maxZ=b.maxZ,yOffset=b.yOffset,owner=v,source=b,
       key=tostring(v.rootNode or v)..':'..index,distance=rootVehicle(v)==own and 0 or distance}
     end
     if #out>=128 then break end
    end
   end
  end
  if #out>=128 then break end
 end
 table.sort(out,function(a,b) if a.distance==b.distance then return a.key<b.key end; return a.distance<b.distance end)
 return out
end
local function footprints()
 local detail=M.values.foliageInteractionDetail
 local out={}
 if detail<=0 then return out end
 local player=playerFootprint(); if player then out[1]=player end
 for _,f in ipairs(vehicleFootprints(detail)) do out[#out+1]=f end
 return out
end
local function signature(list)
 local parts={}
 for i,f in ipairs(list) do if i>M.values.foliageMaximumZones then break end; parts[#parts+1]=f.key..'@'..tostring(f.node) end
 return table.concat(parts,'|')
end
function M.setLocked(id,value) M.locks[id]=value==true end
function M.available()
 local s=system()
 if g_dedicatedServer~=nil or not s or type(s.createRectangle)~='function' or type(s.destroyObject)~='function' then return false,'FS25E_status_missingApi' end
 if not g_currentMission then return false,'FS25E_status_missingApi' end
 return true
end
function M.clearZones()
 local ok=true
 for i=#M.zones,1,-1 do local z=M.zones[i]
  local deleted,result=true,nil
  if z.mission==g_currentMission then deleted,result=pcall(z.system.destroyObject,z.system,z.id) end
  if deleted and result~=false then table.remove(M.zones,i) else ok=false end
 end
 return ok
end
function M.rebuild()
 if not M.clearZones() then return false,'FS25E_status_restoreFailed' end
 M.lastSignature=nil
 if M.values.foliageInteractionDetail==0 then return true end
 local ok,reason=M.available(); if not ok then return false,reason end
 local s=system(); local list=footprints()
 local scale=M.values.foliageInteractionRadius
 for _,f in ipairs(list) do
  if #M.zones>=M.values.foliageMaximumZones then break end
  local cx=(f.minX+f.maxX)*0.5; local cz=(f.minZ+f.maxZ)*0.5
  local hx=math.min(8,(f.maxX-f.minX)*0.5*scale); local hz=math.min(12,(f.maxZ-f.minZ)*0.5*scale)
  if hx>0 and hz>0 then
   local created,id=pcall(s.createRectangle,s,cx-hx,cx+hx,cz-hz,cz+hz,f.yOffset,f.node)
   if created and type(id)=='number' and id>=0 then M.zones[#M.zones+1]={id=id,system=s,node=f.node,source=f.source,mission=g_currentMission} end
  end
 end
 M.lastSignature=signature(list)
 if #M.zones==0 then return false,'FS25E_status_noBendingFootprints' end
 return true
end
local defs={{id='foliageInteractionDetail',min=0,max=2,step=1},{id='foliageInteractionRadius',min=0.5,max=1.5,step=0.001},{id='foliageMaximumZones',min=1,max=16,step=1}}
function M.write(id,value,automatic)
 if automatic and M.locks[id] then return false,'FS25E_status_locked' end
 local def; for _,d in ipairs(defs) do if d.id==id then def=d end end
 if not def or not finite(value) then return false,'FS25E_status_invalidValue' end
 local old=M.values[id]; value=math.max(def.min,math.min(def.max,value)); if def.step==1 then value=math.floor(value+0.5) end
 M.values[id]=value; local ok,reason=M.rebuild()
 if not ok then M.values[id]=old; M.rebuild() end
 return ok,reason
end
function M.update(dt)
 M.elapsed=M.elapsed+(tonumber(dt) or 0); if M.elapsed<500 then return end; M.elapsed=0
 if M.values.foliageInteractionDetail==0 then return end
 local dirty=false
 for _,z in ipairs(M.zones) do if not valid(z.node) or (z.source and z.source.id==nil) then dirty=true end end
 -- Entering or leaving a vehicle, helpers driving by, implements attached:
 -- the footprint set changes, so the zones follow.
 if not dirty and signature(footprints())~=M.lastSignature then dirty=true end
 if dirty then M.rebuild() end
end
function M.restore()
 local ok=M.clearZones()
 M.values={foliageInteractionRadius=1,foliageMaximumZones=8,foliageInteractionDetail=0}; M.lastSignature=nil
 return ok -- Retain failed zone removals for retry without recreating old requested zones.
end
function M.reset() local ok=M.restore(); M.locks={}; return ok end
function M.getDiagnostics()
 local vehicles,player=0,0
 for _,z in ipairs(M.zones) do if z.source then vehicles=vehicles+1 else player=player+1 end end
 return {zones=#M.zones,vehicleZones=vehicles,playerZones=player}
end
function M.getControls()
 local out={}; for _,def in ipairs(defs) do local d=def; out[#out+1]={id=d.id,category='foliage',labelKey='FS25E_setting_'..d.id,
 tooltipKey='FS25E_tooltip_'..d.id,min=d.min,max=d.max,step=d.step,cost='medium',experimental=true,
 read=function() return M.values[d.id] end,write=function(v) return M.write(d.id,v) end,restore=M.restore,available=M.available} end; return out
end
