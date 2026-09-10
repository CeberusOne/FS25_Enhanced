-- FS25_Enhanced / scripts/Shadows/ShadowManager.lua
-- Wave 1: global shadow caps + per-light APIs (lightId required). Auto-apply OFF.
-- No EXPERIMENTAL setters. No blind world-node scan.

FS25E_ShadowManager = {}

local unpack = rawget(_G, "unpack") or table.unpack

local initialized = false
local discoveredLights = {} -- soft discovery stub: empty until Lights Spec
local mergedLights = {} -- lightId -> true (tracked merges; restore MUST split)

local GLOBAL_CAPS = {
    "max-num-shadow-lights",
    "shadow-quality",
    "shadow-distance-quality",
    "shadow-filter-quality",
}

function FS25E_ShadowManager.init()
    initialized = true
    discoveredLights = {}
    mergedLights = {}
    FS25E_Debug.info("ShadowManager", "init (wave1 registered; lights via LightDiscovery when present; auto-apply off)")
end

function FS25E_ShadowManager.reset()
    discoveredLights = {}
    mergedLights = {}
    initialized = false
end

--- Discovered light ids: prefer LightDiscovery registry when present; else local stub.
function FS25E_ShadowManager.getDiscoveredLights()
    if FS25E_LightDiscovery ~= nil and FS25E_LightDiscovery.getEntries ~= nil then
        local out = {}
        local seen = {}
        local entries = FS25E_LightDiscovery.getEntries()
        for _, e in pairs(entries) do
            if e ~= nil and e.node ~= nil and not seen[e.node] then
                seen[e.node] = true
                out[#out + 1] = e.node
            end
        end
        return out
    end
    return discoveredLights
end

function FS25E_ShadowManager.registerLightId(lightId)
    if lightId == nil then
        return false
    end
    discoveredLights[#discoveredLights + 1] = lightId
    return true
end

local function applyCap(capabilityId, value, prefixArgs, keySuffix)
    if FS25E_CapabilityApplier == nil then
        return false, "CapabilityApplier missing"
    end
    return FS25E_CapabilityApplier.apply(capabilityId, {
        value = value,
        values = { value },
        prefixArgs = prefixArgs,
        keySuffix = keySuffix,
    })
end

-- --- Global shadow APIs ---

function FS25E_ShadowManager.setMaxNumShadowLights(value)
    return applyCap("max-num-shadow-lights", value)
end

function FS25E_ShadowManager.setShadowQuality(value)
    return applyCap("shadow-quality", value)
end

function FS25E_ShadowManager.setShadowDistanceQuality(value)
    return applyCap("shadow-distance-quality", value)
end

function FS25E_ShadowManager.setShadowFilterQuality(value)
    return applyCap("shadow-filter-quality", value)
end

-- --- Per-light APIs (require lightId; do not scan world) ---

function FS25E_ShadowManager.setLightShadowPriority(lightId, priority)
    if lightId == nil then
        return false, "lightId required"
    end
    return applyCap("light-shadow-priority", priority, { lightId }, tostring(lightId))
end

function FS25E_ShadowManager.setLightShadowMap(lightId, mapValue)
    if lightId == nil then
        return false, "lightId required"
    end
    return applyCap("light-shadow-map", mapValue, { lightId }, tostring(lightId))
end

function FS25E_ShadowManager.setLightSoftShadowSize(lightId, size)
    if lightId == nil then
        return false, "lightId required"
    end
    return applyCap("light-soft-shadow-size", size, { lightId }, tostring(lightId))
end

function FS25E_ShadowManager.setLightSoftShadowDistance(lightId, distance)
    if lightId == nil then
        return false, "lightId required"
    end
    return applyCap("light-soft-shadow-distance", distance, { lightId }, tostring(lightId))
end

function FS25E_ShadowManager.setLightSoftShadowDepthBiasFactor(lightId, factor)
    if lightId == nil then
        return false, "lightId required"
    end
    return applyCap("light-soft-shadow-depth-bias", factor, { lightId }, tostring(lightId))
end

function FS25E_ShadowManager.hasMergedShadow(lightId)
    local fn = FS25E_CapabilityApplier ~= nil and FS25E_CapabilityApplier.resolveGlobal("hasMergedShadow") or nil
    if type(fn) ~= "function" or lightId == nil then
        return false
    end
    local ok, result = pcall(fn, lightId)
    return ok and result == true
end

--- Explicit merge only. Tracks membership for restore via splitLightShadow.
--- Extra light ids passed as varargs after primary lightId.
function FS25E_ShadowManager.mergeLightShadows(lightId, ...)
    if lightId == nil then
        return false, "lightId required"
    end
    if FS25E_CapabilityRegistry == nil or not FS25E_CapabilityRegistry.allowsApply("merge-light-shadows") then
        return false, "merge not allowed"
    end
    local mergeFn = FS25E_CapabilityApplier.resolveGlobal("mergeLightShadows")
    if type(mergeFn) ~= "function" then
        FS25E_CapabilityRegistry.reject("merge-light-shadows", "mergeLightShadows not a function")
        return false, "mergeLightShadows not a function"
    end

    local others = { ... }
    local ok, err = pcall(function()
        if #others == 0 then
            mergeFn(lightId)
        else
            mergeFn(lightId, unpack(others))
        end
    end)
    if not ok then
        FS25E_CapabilityRegistry.reject("merge-light-shadows", "merge pcall failed: " .. tostring(err))
        return false, err
    end

    mergedLights[lightId] = true
    for i = 1, #others do
        mergedLights[others[i]] = true
    end

    if FS25E_SettingsCache ~= nil then
        local key = "merge-light-shadows|" .. tostring(lightId)
        FS25E_SettingsCache.captureOriginal(key, false)
        local e = FS25E_SettingsCache.get(key)
        if e ~= nil then
            e.needsCalibration = true
            e.applyMode = FS25E_SettingsCache.APPLY_MODE.SESSION
            e.current = true
        end
    end
    if FS25E_RestoreManager ~= nil and FS25E_RestoreManager.registerCapabilityRestore ~= nil then
        FS25E_RestoreManager.registerCapabilityRestore("merge-light-shadows|" .. tostring(lightId))
    end
    -- Also record in applier applied table for generic restoreAll path
    if FS25E_CapabilityApplier ~= nil and FS25E_CapabilityApplier.getApplied ~= nil then
        local applied = FS25E_CapabilityApplier.getApplied()
        applied["merge-light-shadows|" .. tostring(lightId)] = {
            capabilityId = "merge-light-shadows",
            setterName = "mergeLightShadows",
            getterName = "hasMergedShadow",
            prefixArgs = { lightId },
            original = false,
            hadGetter = true,
            appliedValue = true,
            restoreStrategy = "splitLightShadow",
        }
    end

    FS25E_Debug.info("ShadowManager", string.format("merged shadows primary=%s (tracked for split restore)", tostring(lightId)))
    return true, nil
end

function FS25E_ShadowManager.splitLightShadow(lightId)
    if lightId == nil then
        return false, "lightId required"
    end
    local splitFn = FS25E_CapabilityApplier.resolveGlobal("splitLightShadow")
    if type(splitFn) ~= "function" then
        return false, "splitLightShadow not a function"
    end
    local ok, err = pcall(splitFn, lightId)
    if not ok then
        FS25E_Debug.warning("ShadowManager", "splitLightShadow failed: " .. tostring(err))
        return false, err
    end
    mergedLights[lightId] = nil
    return true, nil
end

--- Restore tracked merges (split) then global shadow caps via CapabilityApplier.
function FS25E_ShadowManager.restoreAll()
    FS25E_Debug.info("ShadowManager", "restoreAll begin")
    local ids = {}
    for lightId in pairs(mergedLights) do
        ids[#ids + 1] = lightId
    end
    for i = 1, #ids do
        FS25E_ShadowManager.splitLightShadow(ids[i])
    end
    mergedLights = {}
    -- Global / per-light setter restores handled by CapabilityApplier.restoreAll
    FS25E_Debug.info("ShadowManager", "restoreAll done (splits + defer to CapabilityApplier)")
end

function FS25E_ShadowManager.getMergedLights()
    return mergedLights
end

function FS25E_ShadowManager.isInitialized()
    return initialized
end

--- Optional preset stub — only runs when GraphicsGovernor enables apply.
function FS25E_ShadowManager.applyPresetStub(preset)
    FS25E_Debug.info("ShadowManager", "applyPresetStub name=" .. tostring(preset) .. " (no-op unless explicitly invoked)")
    return true
end
