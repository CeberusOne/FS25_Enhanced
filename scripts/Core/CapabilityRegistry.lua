-- FS25_Enhanced / Core/CapabilityRegistry.lua
-- Load config/capabilityProfiles.xml (Wave 1 CONFIRMED + Expert EXPERIMENTAL/GATED/ASSET).
-- Lua fallback if XML soft-fails.

FS25E_CapabilityRegistry = {}

FS25E_CapabilityRegistry.STATUS = {
    CONFIRMED = "CONFIRMED",
    GATED = "GATED",
    EXPERIMENTAL = "EXPERIMENTAL",
    ASSET_DEPENDENT = "ASSET_DEPENDENT",
    UNSUPPORTED = "UNSUPPORTED",
    REJECTED = "REJECTED",
    APPLIED = "APPLIED",
}

FS25E_CapabilityRegistry.APPLY_MODE = {
    LIVE = "LIVE",
    RELOAD = "RELOAD",
    RESTART = "RESTART",
    UNKNOWN = "UNKNOWN",
    SESSION = "SESSION",
}

FS25E_CapabilityRegistry.RESULT = {
    APPLIED = "APPLIED",
    REJECTED = "REJECTED",
    SKIPPED = "SKIPPED",
}

local capabilities = {} -- id -> entry
local expertMode = false
local lastResults = {}
local listeners = { apply = {}, reject = {}, skip = {} }

local function nowTs()
    if getTime ~= nil then
        local ok, t = pcall(getTime)
        if ok then return t end
    end
    return nil
end

local function emit(kind, id, payload)
    local list = listeners[kind]
    if list == nil then return end
    for i = 1, #list do
        pcall(list[i], id, payload)
    end
end

local function storeResult(id, status, err, detail)
    local payload = { status = status, error = err, detail = detail, ts = nowTs() }
    lastResults[id] = payload
    return payload
end

-- Wave-1 seed (mirrors config/capabilityProfiles.xml). Used outside game / if XML fails.
local WAVE1_FALLBACK = {
    { id = "max-num-shadow-lights", status = "CONFIRMED", apiName = "setMaxNumShadowLights", getter = "getMaxNumShadowLights", setter = "setMaxNumShadowLights", applyMode = "UNKNOWN", restoreStrategy = "YES", scope = "global", notes = "SettingsModel; Wave1 ShadowManager" },
    { id = "shadow-quality", status = "CONFIRMED", apiName = "setShadowQuality", getter = "getShadowQuality", setter = "setShadowQuality", applyMode = "UNKNOWN", restoreStrategy = "YES", scope = "global", notes = "SettingsModel; optional Wave1" },
    { id = "shadow-distance-quality", status = "CONFIRMED", apiName = "setShadowDistanceQuality", getter = "getShadowDistanceQuality", setter = "setShadowDistanceQuality", applyMode = "UNKNOWN", restoreStrategy = "YES", scope = "global", notes = "SettingsModel; optional Wave1" },
    { id = "shadow-filter-quality", status = "CONFIRMED", apiName = "setShadowFilterQuality", getter = "getShadowFilterQuality", setter = "setShadowFilterQuality", applyMode = "UNKNOWN", restoreStrategy = "YES", scope = "global", notes = "SettingsModel; soft-shadows UI" },
    { id = "view-distance-coeff", status = "CONFIRMED", apiName = "setViewDistanceCoeff", getter = "getViewDistanceCoeff", setter = "setViewDistanceCoeff", applyMode = "UNKNOWN", restoreStrategy = "YES", scope = "global", notes = "LodGovernor" },
    { id = "lod-distance-coeff", status = "CONFIRMED", apiName = "setLODDistanceCoeff", getter = "getLODDistanceCoeff", setter = "setLODDistanceCoeff", applyMode = "UNKNOWN", restoreStrategy = "YES", scope = "global", notes = "LodGovernor" },
    { id = "foliage-view-distance-coeff", status = "CONFIRMED", apiName = "setFoliageViewDistanceCoeff", getter = "getFoliageViewDistanceCoeff", setter = "setFoliageViewDistanceCoeff", applyMode = "UNKNOWN", restoreStrategy = "YES", scope = "global", notes = "LodGovernor" },
    { id = "foliage-lod-distance-coeff", status = "CONFIRMED", apiName = "setFoliageLODDistanceCoeff", getter = "getFoliageLODDistanceCoeff", setter = "setFoliageLODDistanceCoeff", applyMode = "UNKNOWN", restoreStrategy = "YES", scope = "global", notes = "LodGovernor" },
    { id = "terrain-lod-distance-coeff", status = "CONFIRMED", apiName = "setTerrainLODDistanceCoeff", getter = "getTerrainLODDistanceCoeff", setter = "setTerrainLODDistanceCoeff", applyMode = "UNKNOWN", restoreStrategy = "YES", scope = "global", notes = "LodGovernor" },
    { id = "allow-foliage-shadows", status = "CONFIRMED", apiName = "setAllowFoliageShadows", getter = "getAllowFoliageShadows", setter = "setAllowFoliageShadows", applyMode = "UNKNOWN", restoreStrategy = "YES", scope = "global", notes = "LodGovernor" },
    { id = "light-shadow-priority", status = "CONFIRMED", apiName = "setLightShadowPriority", getter = "getLightShadowPriority", setter = "setLightShadowPriority", applyMode = "UNKNOWN", restoreStrategy = "YES", scope = "per-light", notes = "Engine Lighting" },
    { id = "light-shadow-map", status = "CONFIRMED", apiName = "setLightShadowMap", getter = "getLightCastingShadowMap", setter = "setLightShadowMap", applyMode = "UNKNOWN", restoreStrategy = "YES", scope = "per-light", notes = "Engine Lighting" },
    { id = "light-soft-shadow-size", status = "CONFIRMED", apiName = "setLightSoftShadowSize", getter = "getLightSoftShadowSize", setter = "setLightSoftShadowSize", applyMode = "UNKNOWN", restoreStrategy = "YES", scope = "per-light", notes = "Engine Lighting" },
    { id = "light-soft-shadow-distance", status = "CONFIRMED", apiName = "setLightSoftShadowDistance", getter = "getLightSoftShadowDistance", setter = "setLightSoftShadowDistance", applyMode = "UNKNOWN", restoreStrategy = "YES", scope = "per-light", notes = "Engine Lighting" },
    { id = "light-soft-shadow-depth-bias", status = "CONFIRMED", apiName = "setLightSoftShadowDepthBiasFactor", getter = "getLightSoftShadowDepthBiasFactor", setter = "setLightSoftShadowDepthBiasFactor", applyMode = "UNKNOWN", restoreStrategy = "YES", scope = "per-light", notes = "Engine Lighting" },
    { id = "merge-light-shadows", status = "CONFIRMED", apiName = "mergeLightShadows", getter = "hasMergedShadow", setter = "mergeLightShadows", applyMode = "UNKNOWN", restoreStrategy = "splitLightShadow", scope = "per-light", notes = "restore via splitLightShadow" },
    { id = "split-light-shadow", status = "CONFIRMED", apiName = "splitLightShadow", getter = "hasMergedShadow", setter = "splitLightShadow", applyMode = "UNKNOWN", restoreStrategy = "YES", scope = "per-light", notes = "restore helper" },
    { id = "has-merged-shadow", status = "CONFIRMED", apiName = "hasMergedShadow", getter = "hasMergedShadow", setter = "NONE", applyMode = "UNKNOWN", restoreStrategy = "NO", scope = "per-light", notes = "query only" },
}

-- Expert-path seed (EXPERIMENTAL / GATED / ASSET_DEPENDENT + CONFIRMED rain). Soft-Apply / expertMode gated at apply time.
local EXPERT_FALLBACK = {
    -- EXPERIMENTAL
    { id = "shadow-focus-box", status = "EXPERIMENTAL", apiName = "setShadowFocusBox", getter = "NONE", setter = "setShadowFocusBox", applyMode = "UNKNOWN", restoreStrategy = "shadowFocusBoxReset", scope = "global", notes = "Engine Rendering fn=641; restore setShadowFocusBox(0); expertMode" },
    { id = "fast-shadow-update", status = "EXPERIMENTAL", apiName = "setFastShadowUpdate", getter = "NONE", setter = "setFastShadowUpdate", applyMode = "UNKNOWN", restoreStrategy = "YES", scope = "global", notes = "Engine Rendering fn=633; expertMode" },
    { id = "rain-shallow-water-simulation", status = "EXPERIMENTAL", apiName = "setRainShallowWaterSimulation", getter = "NONE", setter = "setRainShallowWaterSimulation", applyMode = "UNKNOWN", restoreStrategy = "YES", scope = "global", notes = "Engine Precipitation fn=590; expertMode" },
    -- GATED (+ support query companions)
    { id = "ssr-quality", status = "GATED", apiName = "setScreenSpaceReflectionsQuality", getter = "getScreenSpaceReflectionsQuality", setter = "setScreenSpaceReflectionsQuality", applyMode = "UNKNOWN", restoreStrategy = "YES", scope = "global", notes = "gate getSupportsScreenSpaceReflectionsQuality; expertMode" },
    { id = "atmosphere-quality", status = "GATED", apiName = "setAtmosphereQuality", getter = "getAtmosphereQuality", setter = "setAtmosphereQuality", applyMode = "UNKNOWN", restoreStrategy = "YES", scope = "global", notes = "gate getSupportsAtmosphereQuality; expertMode" },
    { id = "drs-quality", status = "GATED", apiName = "setDRSQuality", getter = "getDRSQuality", setter = "setDRSQuality", applyMode = "UNKNOWN", restoreStrategy = "YES", scope = "global", notes = "gate getSupportsDRSQuality; expertMode" },
    { id = "supports-ssr-quality", status = "GATED", apiName = "getSupportsScreenSpaceReflectionsQuality", getter = "getSupportsScreenSpaceReflectionsQuality", setter = "NONE", applyMode = "UNKNOWN", restoreStrategy = "NO", scope = "global", notes = "query-only gate" },
    { id = "supports-atmosphere-quality", status = "GATED", apiName = "getSupportsAtmosphereQuality", getter = "getSupportsAtmosphereQuality", setter = "NONE", applyMode = "UNKNOWN", restoreStrategy = "NO", scope = "global", notes = "query-only gate" },
    { id = "supports-drs-quality", status = "GATED", apiName = "getSupportsDRSQuality", getter = "getSupportsDRSQuality", setter = "NONE", applyMode = "UNKNOWN", restoreStrategy = "NO", scope = "global", notes = "query-only gate" },
    -- ASSET_DEPENDENT
    { id = "light-ies-profile", status = "ASSET_DEPENDENT", apiName = "setLightIESProfile", getter = "getLightIESProfile", setter = "setLightIESProfile", applyMode = "UNKNOWN", restoreStrategy = "YES", scope = "per-light", notes = "needs lightId + *.ies path; expertMode" },
    { id = "light-ies-cone-angle", status = "ASSET_DEPENDENT", apiName = "getLightConeAngleFromIESProfile", getter = "getLightConeAngleFromIESProfile", setter = "NONE", applyMode = "UNKNOWN", restoreStrategy = "NO", scope = "per-light", notes = "query-only IES cone" },
    { id = "foliage-bending-create", status = "ASSET_DEPENDENT", apiName = "createFoliageBendingRectangle", getter = "NONE", setter = "createFoliageBendingRectangle", applyMode = "UNKNOWN", restoreStrategy = "destroyFoliageBendingObject", scope = "scene", notes = "stub without scene foliageBendingSystem handle" },
    -- CONFIRMED rain (Expert soft-apply wiring; Wave1 allowsApply still CONFIRMED-only when expertMode false — these remain CONFIRMED)
    { id = "rain-active-drops-mult", status = "CONFIRMED", apiName = "setRainActiveDropsMultiplier", getter = "NONE", setter = "setRainActiveDropsMultiplier", applyMode = "UNKNOWN", restoreStrategy = "YES", scope = "global", notes = "Engine Precipitation" },
    { id = "rain-amount-mult", status = "CONFIRMED", apiName = "setRainAmountMultiplier", getter = "getRainAmountMultiplier", setter = "setRainAmountMultiplier", applyMode = "UNKNOWN", restoreStrategy = "YES", scope = "global", notes = "Engine Precipitation" },
    { id = "rain-behind-camera-mirror-buffer", status = "CONFIRMED", apiName = "setRainBehindCameraBufferForMirrors", getter = "NONE", setter = "setRainBehindCameraBufferForMirrors", applyMode = "UNKNOWN", restoreStrategy = "YES", scope = "global", notes = "Engine Precipitation" },
    { id = "rain-bounce-random-factor", status = "CONFIRMED", apiName = "setRainBounceRandomFactor", getter = "NONE", setter = "setRainBounceRandomFactor", applyMode = "UNKNOWN", restoreStrategy = "YES", scope = "global", notes = "Engine Precipitation" },
    { id = "rain-bounce-restitution", status = "CONFIRMED", apiName = "setRainBounceRestitution", getter = "NONE", setter = "setRainBounceRestitution", applyMode = "UNKNOWN", restoreStrategy = "YES", scope = "global", notes = "Engine Precipitation" },
    { id = "rain-camera-velocity-mult", status = "CONFIRMED", apiName = "setRainCameraVelocityMultiplier", getter = "NONE", setter = "setRainCameraVelocityMultiplier", applyMode = "UNKNOWN", restoreStrategy = "YES", scope = "global", notes = "Engine Precipitation" },
    { id = "rain-distribution-power", status = "CONFIRMED", apiName = "setRainDistributionPower", getter = "NONE", setter = "setRainDistributionPower", applyMode = "UNKNOWN", restoreStrategy = "YES", scope = "global", notes = "Engine Precipitation" },
    { id = "rain-forward-direction", status = "CONFIRMED", apiName = "setRainForwardDirection", getter = "NONE", setter = "setRainForwardDirection", applyMode = "UNKNOWN", restoreStrategy = "YES", scope = "global", notes = "Engine Precipitation" },
    { id = "rain-heightmap-collision-threshold", status = "CONFIRMED", apiName = "setRainHeightmapCollisionThreshold", getter = "NONE", setter = "setRainHeightmapCollisionThreshold", applyMode = "UNKNOWN", restoreStrategy = "YES", scope = "global", notes = "Engine Precipitation" },
    { id = "rain-max-bounces", status = "CONFIRMED", apiName = "setRainMaxBounces", getter = "NONE", setter = "setRainMaxBounces", applyMode = "UNKNOWN", restoreStrategy = "YES", scope = "global", notes = "Engine Precipitation" },
    { id = "rain-max-drops-mult", status = "CONFIRMED", apiName = "setRainMaxDropsMultiplier", getter = "NONE", setter = "setRainMaxDropsMultiplier", applyMode = "UNKNOWN", restoreStrategy = "YES", scope = "global", notes = "Engine Precipitation" },
    { id = "rain-most-concentrated-distance", status = "CONFIRMED", apiName = "setRainMostConcentratedDistance", getter = "NONE", setter = "setRainMostConcentratedDistance", applyMode = "UNKNOWN", restoreStrategy = "YES", scope = "global", notes = "Engine Precipitation" },
    { id = "rain-random-offset", status = "CONFIRMED", apiName = "setRainRandomOffset", getter = "NONE", setter = "setRainRandomOffset", applyMode = "UNKNOWN", restoreStrategy = "YES", scope = "global", notes = "Engine Precipitation" },
    { id = "rain-spawn-box-parameters", status = "CONFIRMED", apiName = "setRainSpawnBoxParameters", getter = "NONE", setter = "setRainSpawnBoxParameters", applyMode = "UNKNOWN", restoreStrategy = "YES", scope = "global", notes = "Engine Precipitation; multi-arg" },
    { id = "rain-spawn-velocity", status = "CONFIRMED", apiName = "setRainSpawnVelocity", getter = "NONE", setter = "setRainSpawnVelocity", applyMode = "UNKNOWN", restoreStrategy = "YES", scope = "global", notes = "Engine Precipitation" },
    { id = "rain-turbulence-parameters", status = "CONFIRMED", apiName = "setRainTurbulenceParameters", getter = "NONE", setter = "setRainTurbulenceParameters", applyMode = "UNKNOWN", restoreStrategy = "YES", scope = "global", notes = "Engine Precipitation; multi-arg" },
    { id = "rain-weather-type", status = "CONFIRMED", apiName = "setRainWeatherType", getter = "NONE", setter = "setRainWeatherType", applyMode = "UNKNOWN", restoreStrategy = "YES", scope = "global", notes = "Engine Precipitation" },
    { id = "rain-wind-force", status = "CONFIRMED", apiName = "setRainWindForce", getter = "NONE", setter = "setRainWindForce", applyMode = "UNKNOWN", restoreStrategy = "YES", scope = "global", notes = "Engine Precipitation" },
}

local function parseStatus(raw)
    local s = tostring(raw or ""):upper()
    if FS25E_CapabilityRegistry.STATUS[s] ~= nil then
        return s
    end
    return FS25E_CapabilityRegistry.STATUS.UNSUPPORTED
end

local function parseApplyMode(raw)
    local s = tostring(raw or "UNKNOWN"):upper()
    if FS25E_CapabilityRegistry.APPLY_MODE[s] ~= nil then
        return s
    end
    return FS25E_CapabilityRegistry.APPLY_MODE.UNKNOWN
end

local function storeEntry(entry)
    if entry == nil or entry.id == nil or entry.id == "" then
        return false
    end
    capabilities[entry.id] = {
        id = entry.id,
        status = parseStatus(entry.status),
        apiName = entry.apiName,
        getter = entry.getter,
        setter = entry.setter,
        applyMode = parseApplyMode(entry.applyMode),
        restoreStrategy = entry.restoreStrategy,
        scope = entry.scope,
        notes = entry.notes,
        needsCalibration = true,
        baseStatus = parseStatus(entry.status), -- preserve matrix status across APPLIED/REJECTED churn
    }
    return true
end

local function seedFallback()
    local n = 0
    for i = 1, #WAVE1_FALLBACK do
        if storeEntry(WAVE1_FALLBACK[i]) then
            n = n + 1
        end
    end
    for i = 1, #EXPERT_FALLBACK do
        if storeEntry(EXPERT_FALLBACK[i]) then
            n = n + 1
        end
    end
    FS25E_Debug.info("CapabilityRegistry", string.format("seeded Lua fallback wave1+expert count=%d", n))
    return n
end

--- Parse capabilityProfiles.xml. Returns ok, countOrErr.
local function tryParseXml(path)
    if loadXMLFile == nil then
        return false, "loadXMLFile unavailable"
    end
    if getXMLString == nil then
        return false, "getXMLString unavailable"
    end

    local xmlId = loadXMLFile("FS25E_capabilityProfiles", path)
    if xmlId == nil or xmlId == 0 then
        return false, "XML not loaded"
    end

    local count = 0
    local ok, err = pcall(function()
        local i = 0
        while i <= 256 do
            local base = string.format("capabilityProfiles.capability(%d)", i)
            local id = getXMLString(xmlId, base .. "#id")
            if id == nil or id == "" then
                break
            end
            storeEntry({
                id = id,
                status = getXMLString(xmlId, base .. "#status"),
                apiName = getXMLString(xmlId, base .. "#apiName"),
                getter = getXMLString(xmlId, base .. "#getter"),
                setter = getXMLString(xmlId, base .. "#setter"),
                applyMode = getXMLString(xmlId, base .. "#applyMode"),
                restoreStrategy = getXMLString(xmlId, base .. "#restoreStrategy"),
                scope = getXMLString(xmlId, base .. "#scope"),
                notes = getXMLString(xmlId, base .. "#notes"),
            })
            count = count + 1
            i = i + 1
        end
    end)

    if deleteXMLFile ~= nil then
        pcall(deleteXMLFile, xmlId)
    end

    if not ok then
        return false, err
    end
    if count == 0 then
        return false, "no capability nodes"
    end
    return true, count
end

--- Load capability profiles from XML; seed Wave-1+Expert Lua fallback if soft-fail / empty.
function FS25E_CapabilityRegistry.load(modDirectory)
    capabilities = {}
    lastResults = {}
    local path = (modDirectory or "") .. "config/capabilityProfiles.xml"
    FS25E_Debug.info("CapabilityRegistry", "load from " .. path)

    local success, info = tryParseXml(path)
    local loadedXml = false
    if success then
        loadedXml = true
        FS25E_Debug.info("CapabilityRegistry", string.format("XML loaded count=%s", tostring(info)))
    else
        FS25E_Debug.warning("CapabilityRegistry", "XML soft-fail: " .. tostring(info) .. "; using Lua fallback")
        seedFallback()
    end

    local n = FS25E_CapabilityRegistry.count()
    if n == 0 then
        seedFallback()
        n = FS25E_CapabilityRegistry.count()
    end
    FS25E_Debug.info("CapabilityRegistry", string.format("registry ready count=%d loadedXml=%s", n, tostring(loadedXml)))
end

function FS25E_CapabilityRegistry.register(id, status, apiName, notes)
    return storeEntry({
        id = id,
        status = status,
        apiName = apiName,
        notes = notes,
        applyMode = "UNKNOWN",
        restoreStrategy = "YES",
    })
end

function FS25E_CapabilityRegistry.get(id)
    return capabilities[id]
end

function FS25E_CapabilityRegistry.getStatus(id)
    local c = capabilities[id]
    if c == nil then
        return FS25E_CapabilityRegistry.STATUS.UNSUPPORTED
    end
    return c.status
end

function FS25E_CapabilityRegistry.isConfirmed(id)
    return FS25E_CapabilityRegistry.getStatus(id) == FS25E_CapabilityRegistry.STATUS.CONFIRMED
end

local function resolveExpertMode(explicit)
    if explicit ~= nil then
        return explicit == true
    end
    if expertMode then
        return true
    end
    if FS25E_SettingsAPI ~= nil and FS25E_SettingsAPI.getExpertMode ~= nil then
        if FS25E_SettingsAPI.getExpertMode() == true then
            return true
        end
    end
    if FS25E_SettingsSchema ~= nil and FS25E_SettingsSchema.get ~= nil then
        return FS25E_SettingsSchema.get("expertMode") == true
    end
    return false
end

function FS25E_CapabilityRegistry.setExpertMode(enabled)
    expertMode = enabled == true
    FS25E_Debug.info("CapabilityRegistry", "expertMode=" .. tostring(expertMode))
end

function FS25E_CapabilityRegistry.isExpertMode()
    return expertMode == true or resolveExpertMode(nil)
end

--- Apply gate.
--- expertMode=false → CONFIRMED only (Wave1 unchanged). APPLIED of a CONFIRMED base also allowed.
--- expertMode=true  → also EXPERIMENTAL | GATED | ASSET_DEPENDENT (and their APPLIED).
--- REJECTED / UNSUPPORTED never allowed.
--- Optional 2nd arg: expertMode bool. If omitted, reads SettingsSchema.expertMode (default false).
function FS25E_CapabilityRegistry.allowsApply(id, expertMode)
    local c = capabilities[id]
    if c == nil then
        return false
    end
    local s = c.status
    if s == FS25E_CapabilityRegistry.STATUS.REJECTED
        or s == FS25E_CapabilityRegistry.STATUS.UNSUPPORTED then
        return false
    end

    local expert = resolveExpertMode(expertMode)
    local base = c.baseStatus or s

    -- CONFIRMED always (Wave1). APPLIED that originated as CONFIRMED stays Wave1-safe.
    if s == FS25E_CapabilityRegistry.STATUS.CONFIRMED then
        return true
    end
    if s == FS25E_CapabilityRegistry.STATUS.APPLIED then
        if base == FS25E_CapabilityRegistry.STATUS.CONFIRMED then
            return true
        end
        -- Expert-origin APPLIED only when expertMode still on
        return expert
            and (base == FS25E_CapabilityRegistry.STATUS.EXPERIMENTAL
                or base == FS25E_CapabilityRegistry.STATUS.GATED
                or base == FS25E_CapabilityRegistry.STATUS.ASSET_DEPENDENT)
    end

    if not expert then
        return false
    end

    return s == FS25E_CapabilityRegistry.STATUS.EXPERIMENTAL
        or s == FS25E_CapabilityRegistry.STATUS.GATED
        or s == FS25E_CapabilityRegistry.STATUS.ASSET_DEPENDENT
end

--- Convenience: same as allowsApply(id, true) semantics when expertMode setting is on.
function FS25E_CapabilityRegistry.allowsExpertApply(id)
    return FS25E_CapabilityRegistry.allowsApply(id, true)
end

function FS25E_CapabilityRegistry.isUsable(id)
    local s = FS25E_CapabilityRegistry.getStatus(id)
    return s == FS25E_CapabilityRegistry.STATUS.CONFIRMED
        or s == FS25E_CapabilityRegistry.STATUS.GATED
        or s == FS25E_CapabilityRegistry.STATUS.EXPERIMENTAL
        or s == FS25E_CapabilityRegistry.STATUS.ASSET_DEPENDENT
        or s == FS25E_CapabilityRegistry.STATUS.APPLIED
end

function FS25E_CapabilityRegistry.reject(id, reason)
    local c = capabilities[id]
    if c == nil then
        FS25E_CapabilityRegistry.register(id, "REJECTED", nil, reason)
    else
        c.status = FS25E_CapabilityRegistry.STATUS.REJECTED
        c.notes = reason
    end
    local payload = storeResult(id, FS25E_CapabilityRegistry.RESULT.REJECTED, reason, nil)
    FS25E_Debug.warning("CapabilityRegistry", string.format(
        "rejected capabilityId=%s reason=%s",
        tostring(id), tostring(reason)
    ))
    emit("reject", id, payload)
end

--- Mark successful apply as APPLIED (keeps baseStatus for gate logic) + emit hooks.
function FS25E_CapabilityRegistry.markApplied(id, detail)
    local c = capabilities[id]
    if c ~= nil and c.status ~= FS25E_CapabilityRegistry.STATUS.REJECTED then
        if c.baseStatus == nil then
            c.baseStatus = c.status
        end
        c.status = FS25E_CapabilityRegistry.STATUS.APPLIED
    end
    local payload = storeResult(id, FS25E_CapabilityRegistry.RESULT.APPLIED, nil, detail)
    FS25E_Debug.info("CapabilityRegistry", string.format(
        "APPLIED capabilityId=%s baseStatus=%s detail=%s",
        tostring(id), tostring(c and c.baseStatus), tostring(detail or "")
    ))
    emit("apply", id, payload)
    return payload
end

function FS25E_CapabilityRegistry.markSkipped(id, reason)
    local payload = storeResult(id, FS25E_CapabilityRegistry.RESULT.SKIPPED, reason, nil)
    FS25E_Debug.info("CapabilityRegistry", string.format("SKIPPED %s: %s", tostring(id), tostring(reason)))
    emit("skip", id, payload)
    return payload
end

function FS25E_CapabilityRegistry.getLastResult(id)
    return lastResults[id]
end

function FS25E_CapabilityRegistry.getAllLastResults()
    return lastResults
end

function FS25E_CapabilityRegistry.onApply(fn)
    if type(fn) == "function" then listeners.apply[#listeners.apply + 1] = fn end
end

function FS25E_CapabilityRegistry.onReject(fn)
    if type(fn) == "function" then listeners.reject[#listeners.reject + 1] = fn end
end

function FS25E_CapabilityRegistry.onSkip(fn)
    if type(fn) == "function" then listeners.skip[#listeners.skip + 1] = fn end
end

function FS25E_CapabilityRegistry.all()
    return capabilities
end

function FS25E_CapabilityRegistry.count()
    local n = 0
    for _ in pairs(capabilities) do
        n = n + 1
    end
    return n
end

function FS25E_CapabilityRegistry.getWave1Fallback()
    return WAVE1_FALLBACK
end

function FS25E_CapabilityRegistry.getExpertFallback()
    return EXPERT_FALLBACK
end
