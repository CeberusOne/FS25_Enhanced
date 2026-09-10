-- FS25_Enhanced / Core/CapabilityRegistry.lua
-- Load config/capabilityProfiles.xml (Wave 1 CONFIRMED). Lua fallback if XML soft-fails.

FS25E_CapabilityRegistry = {}

FS25E_CapabilityRegistry.STATUS = {
    CONFIRMED = "CONFIRMED",
    GATED = "GATED",
    EXPERIMENTAL = "EXPERIMENTAL",
    ASSET_DEPENDENT = "ASSET_DEPENDENT",
    UNSUPPORTED = "UNSUPPORTED",
    REJECTED = "REJECTED",
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
    FS25E_Debug.info("CapabilityRegistry", string.format("seeded Lua fallback wave1 count=%d", n))
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

--- Load capability profiles from XML; seed Wave-1 Lua fallback if soft-fail / empty.
function FS25E_CapabilityRegistry.load(modDirectory)
    capabilities = {}
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

function FS25E_CapabilityRegistry.setExpertMode(enabled)
    expertMode = enabled == true
    FS25E_Debug.info("CapabilityRegistry", "expertMode=" .. tostring(expertMode))
end

function FS25E_CapabilityRegistry.isExpertMode()
    return expertMode
end

--- CONFIRMED always; with expertMode also EXPERIMENTAL/GATED/ASSET_DEPENDENT.
--- GATED needs getSupports* at apply site; ASSET_DEPENDENT needs lightId/asset.
function FS25E_CapabilityRegistry.allowsApply(id)
    local s = FS25E_CapabilityRegistry.getStatus(id)
    if s == FS25E_CapabilityRegistry.STATUS.REJECTED then
        return false
    end
    if s == FS25E_CapabilityRegistry.STATUS.CONFIRMED then
        return true
    end
    if not expertMode then
        return false
    end
    return s == FS25E_CapabilityRegistry.STATUS.EXPERIMENTAL
        or s == FS25E_CapabilityRegistry.STATUS.GATED
        or s == FS25E_CapabilityRegistry.STATUS.ASSET_DEPENDENT
end

function FS25E_CapabilityRegistry.isUsable(id)
    local s = FS25E_CapabilityRegistry.getStatus(id)
    return s == FS25E_CapabilityRegistry.STATUS.CONFIRMED
        or s == FS25E_CapabilityRegistry.STATUS.GATED
        or s == FS25E_CapabilityRegistry.STATUS.EXPERIMENTAL
        or s == FS25E_CapabilityRegistry.STATUS.ASSET_DEPENDENT
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
    FS25E_Debug.warning("CapabilityRegistry", string.format("REJECTED %s: %s", tostring(id), tostring(reason)))
    emit("reject", id, payload)
end

function FS25E_CapabilityRegistry.markApplied(id, detail)
    local payload = storeResult(id, FS25E_CapabilityRegistry.RESULT.APPLIED, nil, detail)
    FS25E_Debug.info("CapabilityRegistry", string.format("APPLIED %s %s", tostring(id), tostring(detail or "")))
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
