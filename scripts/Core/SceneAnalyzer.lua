-- FS25_Enhanced / Core/SceneAnalyzer.lua
-- Phase 2: read-only scene snapshot from g_currentMission (nil-safe).
-- Update on Medium/Slow cadence only. NO engine writes.

FS25E_SceneAnalyzer = {}

local INTERVAL_MEDIUM_MS = 250
local INTERVAL_SLOW_MS = 1000
local accumMediumMs = 0
local accumSlowMs = 0
local enabled = true
local debugLog = false
local tickCount = 0

local snapshot = {
    hasMission = false,
    cameraId = nil,
    playerPresent = false,
    inVehicle = false,
    vehicleName = nil,
    hour = nil,
    minute = nil,
    isDay = nil,
    sunHeightAngle = nil,
    weatherType = nil,
    fogActive = nil,
    rainActive = nil,
    rainAmount = nil,
    updatedAtMedium = 0,
    updatedAtSlow = 0,
}

local function safeGet(tbl, key)
    if tbl == nil then
        return nil
    end
    local ok, value = pcall(function()
        return tbl[key]
    end)
    if ok then
        return value
    end
    return nil
end

local function resolveMission()
    if g_currentMission ~= nil then
        return g_currentMission
    end
    return nil
end

local function readCameraId(mission)
    if getCamera ~= nil then
        local ok, cam = pcall(getCamera)
        if ok and cam ~= nil then
            return cam
        end
    end
    local cam = safeGet(mission, "camera")
    if cam ~= nil then
        return cam
    end
    return safeGet(mission, "activeCamera")
end

local function readEnvironment(mission)
    local env = safeGet(mission, "environment")
    if env == nil then
        return
    end
    snapshot.hour = safeGet(env, "currentHour") or safeGet(env, "dayTime")
    snapshot.minute = safeGet(env, "currentMinute")
    local lighting = safeGet(env, "lighting") or safeGet(env, "lightSystem")
    if lighting ~= nil then
        snapshot.sunHeightAngle = safeGet(lighting, "sunHeightAngle") or safeGet(lighting, "sunDirY")
    end
    if type(snapshot.hour) == "number" then
        local h = snapshot.hour
        if h > 24 then
            h = (h / 3600000) % 24
            snapshot.hour = h
        end
        snapshot.isDay = h >= 6 and h < 20
    end

    local weather = safeGet(env, "weather")
    if weather ~= nil then
        snapshot.weatherType = safeGet(weather, "currentWeatherType")
            or safeGet(weather, "weatherType")
            or safeGet(weather, "type")
        local fog = safeGet(weather, "fog") or safeGet(env, "fog")
        if type(fog) == "boolean" then
            snapshot.fogActive = fog
        elseif fog ~= nil then
            snapshot.fogActive = safeGet(fog, "isActive") or safeGet(fog, "active")
            if snapshot.fogActive == nil and safeGet(fog, "density") ~= nil then
                local d = safeGet(fog, "density")
                snapshot.fogActive = type(d) == "number" and d > 0.01
            end
        end
        local rain = safeGet(weather, "rain") or safeGet(weather, "precipitation")
        if type(rain) == "boolean" then
            snapshot.rainActive = rain
        elseif rain ~= nil then
            snapshot.rainActive = safeGet(rain, "isActive") or safeGet(rain, "active")
            snapshot.rainAmount = safeGet(rain, "amount") or safeGet(rain, "rainAmount") or safeGet(rain, "value")
        end
        if snapshot.rainActive == nil then
            local amt = safeGet(weather, "rainAmount") or safeGet(weather, "precipitationAmount")
            if type(amt) == "number" then
                snapshot.rainAmount = amt
                snapshot.rainActive = amt > 0.01
            end
        end
    end
end

local function readPlayerVehicle(mission)
    local player = safeGet(mission, "player")
    snapshot.playerPresent = player ~= nil
    local vehicle = safeGet(mission, "controlledVehicle")
        or safeGet(mission, "currentVehicle")
    if vehicle == nil and player ~= nil then
        vehicle = safeGet(player, "controlledVehicle") or safeGet(player, "vehicle")
    end
    snapshot.inVehicle = vehicle ~= nil
    if vehicle ~= nil then
        snapshot.vehicleName = safeGet(vehicle, "name")
            or safeGet(vehicle, "typeName")
            or safeGet(vehicle, "configFileName")
    else
        snapshot.vehicleName = nil
    end
end

function FS25E_SceneAnalyzer.refresh()
    local mission = resolveMission()
    snapshot.hasMission = mission ~= nil
    if mission == nil then
        snapshot.cameraId = nil
        snapshot.playerPresent = false
        snapshot.inVehicle = false
        snapshot.vehicleName = nil
        snapshot.hour = nil
        snapshot.minute = nil
        snapshot.isDay = nil
        snapshot.sunHeightAngle = nil
        snapshot.weatherType = nil
        snapshot.fogActive = nil
        snapshot.rainActive = nil
        snapshot.rainAmount = nil
        return snapshot
    end

    FS25E_Debug.pcall("SceneAnalyzer", "refresh", function()
        snapshot.cameraId = readCameraId(mission)
        readPlayerVehicle(mission)
        readEnvironment(mission)
    end)
    return snapshot
end

function FS25E_SceneAnalyzer.init()
    accumMediumMs = 0
    accumSlowMs = 0
    tickCount = 0
    enabled = true
    debugLog = false
    FS25E_SceneAnalyzer.refresh()
    FS25E_Debug.info("SceneAnalyzer", "init (read-only; Medium/Slow cadence; no engine writes)")
end

function FS25E_SceneAnalyzer.setEnabled(value)
    enabled = value == true
end

function FS25E_SceneAnalyzer.setDebugLog(value)
    debugLog = value == true
end

function FS25E_SceneAnalyzer.isEnabled()
    return enabled
end

function FS25E_SceneAnalyzer.getSnapshot()
    return snapshot
end

function FS25E_SceneAnalyzer.getLoadHint()
    local score = 0
    if snapshot.inVehicle then
        score = score + 1
    end
    if snapshot.fogActive == true then
        score = score + 1
    end
    if snapshot.rainActive == true then
        score = score + 1
    end
    if snapshot.isDay == false then
        score = score + 1
    end
    if score >= 3 then
        return 2
    elseif score >= 1 then
        return 1
    end
    return 0
end

function FS25E_SceneAnalyzer.getTickCount()
    return tickCount
end

function FS25E_SceneAnalyzer.update(dt)
    if not enabled or dt == nil then
        return
    end
    local dtMs = dt * 1000.0
    accumMediumMs = accumMediumMs + dtMs
    accumSlowMs = accumSlowMs + dtMs

    if accumMediumMs >= INTERVAL_MEDIUM_MS then
        accumMediumMs = 0
        tickCount = tickCount + 1
        snapshot.updatedAtMedium = tickCount
        FS25E_SceneAnalyzer.refresh()
    end

    if accumSlowMs >= INTERVAL_SLOW_MS then
        accumSlowMs = 0
        snapshot.updatedAtSlow = tickCount
        local shouldLog = debugLog or (tickCount <= 1) or (tickCount % 10 == 0)
        if shouldLog then
            FS25E_Debug.info("SceneAnalyzer", string.format(
                "slow tick#%d mission=%s inVehicle=%s hour=%s fog=%s rain=%s loadHint=%d",
                tickCount,
                tostring(snapshot.hasMission),
                tostring(snapshot.inVehicle),
                tostring(snapshot.hour),
                tostring(snapshot.fogActive),
                tostring(snapshot.rainActive),
                FS25E_SceneAnalyzer.getLoadHint()
            ))
        end
    end
end

function FS25E_SceneAnalyzer.reset()
    accumMediumMs = 0
    accumSlowMs = 0
    tickCount = 0
    snapshot.hasMission = false
    snapshot.cameraId = nil
    snapshot.playerPresent = false
    snapshot.inVehicle = false
    snapshot.vehicleName = nil
    snapshot.hour = nil
    snapshot.minute = nil
    snapshot.isDay = nil
    snapshot.sunHeightAngle = nil
    snapshot.weatherType = nil
    snapshot.fogActive = nil
    snapshot.rainActive = nil
    snapshot.rainAmount = nil
    snapshot.updatedAtMedium = 0
    snapshot.updatedAtSlow = 0
end
