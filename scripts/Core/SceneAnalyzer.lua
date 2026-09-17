-- Read-only FS25 scene information. Missing sensors remain nil, never guessed engine values.
FS25E_SceneAnalyzer = {}
local M=FS25E_SceneAnalyzer
local snapshot, clockMs, accumulator, tickCount, enabled, debugLog = {},0,0,0,true,false
local function call(object,name,...)
    if object and type(object[name])=='function' then local ok,a,b,c=pcall(object[name],object,...); if ok then return a,b,c end end
end
local function native(name,...)
    local fn=_G[name]; if type(fn)=='function' then local ok,a,b,c=pcall(fn,...); if ok then return a,b,c end end
end
local function valid(node) return type(node)=='number' and node~=0 and (entityExists==nil or native('entityExists',node)==true) end
local function position(node)
    if not valid(node) then return nil end
    local x,y,z=native('getWorldTranslation',node)
    if type(x)=='number' and type(y)=='number' and type(z)=='number' then return {x=x,y=y,z=z} end
end
local function distance(a,b) if not a or not b then return nil end return math.sqrt((a.x-b.x)^2+(a.y-b.y)^2+(a.z-b.z)^2) end
local function sceneClasses(s)
    local tags={}
    if s.indoorCab then tags[#tags+1]='Indoor Cab' elseif s.indoor then tags[#tags+1]='Indoor Building' end
    if s.vehicleSpeedKph and s.vehicleSpeedKph>30 then tags[#tags+1]='Road Travel' end
    if s.rainAmount and s.rainAmount>.65 then tags[#tags+1]='Heavy Rain' elseif s.rainActive then tags[#tags+1]='Rain' end
    if s.fogActive then tags[#tags+1]='Fog' end
    if s.nearbyPlaceableLights and s.nearbyPlaceableLights>=3 then tags[#tags+1]=s.isDay==false and 'Farmyard Night' or 'Farmyard Day' end
    if s.isDay==false and not s.rainActive and not s.fogActive then tags[#tags+1]='Clear Night' end
    if s.isDay==true and #tags==0 then tags[#tags+1]='Open Field Day' end
    if #tags==0 then tags[1]='Unclassified' end
    s.classes=tags; s.sceneKey=table.concat(tags,'+')
end
function M.refresh()
    local old=snapshot
    local s={hasMission=g_currentMission~=nil,updatedAtMedium=tickCount,updatedAtSlow=tickCount,source='FS25 read-only',observedAtMs=clockMs}
    snapshot=s
    local mission=g_currentMission; if not mission then s.inVehicle=false; s.playerPresent=false; sceneClasses(s); return s end
    local player=g_localPlayer or mission.player
    local vehicle=call(player,'getCurrentVehicle') or mission.controlledVehicle or mission.currentVehicle
    s.playerPresent=player~=nil; s.inVehicle=vehicle~=nil; s.vehicle=vehicle
    if vehicle then
        s.vehicleName=call(vehicle,'getName') or vehicle.name or vehicle.typeName
        s.vehiclePosition=position(vehicle.rootNode); s.vehicleSpeedKph=call(vehicle,'getLastSpeed')
        local active=call(vehicle,'getActiveCamera'); if active then s.indoorCab=active.isInside==true end
    end
    local px,py,pz=call(player,'getPosition'); if type(px)=='number' and type(py)=='number' and type(pz)=='number' then s.playerPosition={x=px,y=py,z=pz} end
    s.cameraId=native('getCamera'); if not valid(s.cameraId) then s.cameraId=nil end
    s.cameraPosition=position(s.cameraId)
    if s.cameraId then
        s.fovY=native('getFovY',s.cameraId)
        local x,y,z=native('localDirectionToWorld',s.cameraId,0,0,-1)
        if type(x)=='number' then s.cameraDirection={x=x,y=y,z=z} end
    end
    local moved=distance(old.cameraPosition,s.cameraPosition)
    if moved and old.observedAtMs and clockMs>old.observedAtMs then s.cameraSpeedMps=moved*1000/(clockMs-old.observedAtMs) end
    if old.cameraDirection and s.cameraDirection then
        local a,b=old.cameraDirection,s.cameraDirection
        s.cameraTurnRadians=math.acos(math.max(-1,math.min(1,a.x*b.x+a.y*b.y+a.z*b.z)))
    end
    local p=s.cameraPosition or s.playerPosition or s.vehiclePosition
    if p then s.indoor=call(mission.indoorMask,'getIsIndoorAtWorldPosition',p.x,p.z) end
    local env=mission.environment
    if env then
        if type(env.currentHour)=='number' then s.hour=env.currentHour
        elseif type(env.dayTime)=='number' then s.hour=(env.dayTime/3600000)%24 end
        s.minute=env.currentMinute
        if type(env.isSunOn)=='boolean' then s.isDay=env.isSunOn elseif s.hour then s.isDay=s.hour>=6 and s.hour<20 end
        local weather=env.weather
        s.rainAmount=call(weather,'getRainFallScale'); s.rainActive=call(weather,'getIsRaining')
        if s.rainActive==nil and type(s.rainAmount)=='number' then s.rainActive=s.rainAmount>.01 end
        s.groundWetness=call(weather,'getGroundWetness')
        -- Fog range is read only if the engine explicitly provides its native getter.
        -- No raw weather internals are interpreted as a density sensor.
    end
    local count=0; local vehicles=mission.vehicleSystem and mission.vehicleSystem.vehicles
    if vehicles then for _ in pairs(vehicles) do count=count+1 end; s.vehicleCount=count end
    local lights=FS25E_LightDiscovery and FS25E_LightDiscovery.getEntries and FS25E_LightDiscovery.getEntries()
    if lights then
        local nearby=0; s.relevantLightSources=0
        for _,e in pairs(lights) do
            if e.active~=false then
                local d=distance(p,position(e.node or e.handle))
                if d and d<100 then s.relevantLightSources=s.relevantLightSources+1; if e.kind=='placeable' then nearby=nearby+1 end end
            end
        end
        s.nearbyPlaceableLights=nearby
    end
    s.renderWidth=g_screenWidth; s.renderHeight=g_screenHeight
    s.resolutionSource='display size; internal render resolution unknown'
    -- These read-only settings are used by stock SettingsModel. They describe
    -- a graphics profile/upscaler configuration, not GPU identity or timings.
    local profile,custom=native('getPerformanceClass')
    if type(profile)=='number' then s.graphicsProfile=tostring(profile)..(custom==true and ':custom' or '') end
    local upscalers,known={},0
    for _,enumName in ipairs({'DLSSQuality','FidelityFxSRQuality','FidelityFxSR30Quality','XeSSQuality'}) do
        local enum=_G[enumName]; local value=native('get'..enumName)
        if type(enum)=='table' and enum.OFF~=nil and type(value)=='number' then
            known=known+1
            if value~=enum.OFF and value~=enum.NUM then upscalers[#upscalers+1]=enumName..':'..tostring(value) end
        end
    end
    if #upscalers>0 then s.upscaler=table.concat(upscalers,'+') elseif known==4 then s.upscaler='OFF' end
    s.mapId=mission.missionInfo and (mission.missionInfo.mapId or mission.missionInfo.mapTitle)
    sceneClasses(s)
    s.changed=old.sceneKey~=s.sceneKey
    return s
end
function M.init() clockMs=0; accumulator=0; tickCount=0; snapshot={}; enabled=true; M.refresh() end
function M.reset() snapshot={hasMission=false,inVehicle=false,classes={'Unclassified'},sceneKey='Unclassified'}; clockMs=0; accumulator=0; tickCount=0 end
function M.setEnabled(v) enabled=v==true end
function M.isEnabled() return enabled end
function M.setDebugLog(v) debugLog=v==true end
function M.getSnapshot() return snapshot end
function M.getTickCount() return tickCount end
function M.getLoadHint()
    local n=(snapshot.inVehicle and 1 or 0)+(snapshot.rainActive and 1 or 0)+(snapshot.fogActive and 1 or 0)+(snapshot.isDay==false and 1 or 0)
    return n>=3 and 2 or n>=1 and 1 or 0
end
function M.update(dt)
    if not enabled or type(dt)~='number' or dt<=0 or dt>1000 then return end
    clockMs=clockMs+dt; accumulator=accumulator+dt
    if accumulator>=500 then accumulator=accumulator%500; tickCount=tickCount+1; M.refresh()
        if debugLog and tickCount%20==0 and FS25E_Debug then FS25E_Debug.info('SceneAnalyzer',snapshot.sceneKey) end
    end
end
-- Importance is a heuristic, not an occlusion query. Callers can supply verified visibility/fog.
function M.scoreImportance(object,scene)
    object=object or {}; scene=scene or snapshot
    if object.active==false then return 0 end
    if object.owner~=nil and object.owner==scene.vehicle then return object.kind=='light' and 95 or 100 end
    local p=object.position or position(object.node or object.handle)
    local d=object.distance or distance(p,scene.cameraPosition or scene.playerPosition) or 1000
    local score=100/(1+d/45)
    local direction=scene.cameraDirection; local camera=scene.cameraPosition
    if camera and direction and p and d>.001 then
        local dot=((p.x-camera.x)*direction.x+(p.y-camera.y)*direction.y+(p.z-camera.z)*direction.z)/d
        if dot<0 then score=math.min(score,10) else score=score*(.65+.35*dot) end
    end
    if object.visible==false then score=math.min(score,10) end
    if object.fogOccluded==true then score=math.min(score,5) end
    if object.interacting then score=math.max(score,95) end
    if object.kind=='workLight' and d<25 then score=math.max(score,90) end
    return math.max(0,math.min(100,score))
end
