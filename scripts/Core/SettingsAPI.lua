-- FS25_Enhanced / Core/SettingsAPI.lua
-- Facade for GUI / Experimental / Diagnostics. No direct engine setters.

FS25E_SettingsAPI = {}

function FS25E_SettingsAPI.get(id)
    if FS25E_ModSettings ~= nil then
        return FS25E_ModSettings.get(id)
    end
    return nil
end

function FS25E_SettingsAPI.set(id, value)
    if FS25E_ModSettings == nil then
        return false
    end
    local ok = FS25E_ModSettings.set(id, value)
    if not ok then
        return false
    end
    local key = id
    if key == "governorEnabled" then key = "enabled" end
    if key == "activePreset" then key = "preset" end

    if key == "enabled" and FS25E_GraphicsGovernor ~= nil then
        FS25E_GraphicsGovernor.setEnabled(value == true)
    elseif key == "autoApply" and FS25E_GraphicsGovernor ~= nil then
        FS25E_GraphicsGovernor.setAutoApply(value == true)
    elseif key == "expertMode" and FS25E_CapabilityRegistry ~= nil then
        FS25E_CapabilityRegistry.setExpertMode(value == true)
    elseif key == "softApply" and FS25E_LightDiscovery ~= nil and FS25E_LightDiscovery.setSoftApplyEnabled ~= nil then
        FS25E_LightDiscovery.setSoftApplyEnabled(value == true)
    elseif key == "preset" and FS25E_ProfileManager ~= nil then
        FS25E_ProfileManager.selectPreset(tostring(value))
    end
    return true
end

function FS25E_SettingsAPI.getAll()
    if FS25E_ModSettings ~= nil then return FS25E_ModSettings.getAll() end
    return {}
end

function FS25E_SettingsAPI.getDefaults()
    if FS25E_ModSettings ~= nil then return FS25E_ModSettings.getDefaults() end
    return {}
end

function FS25E_SettingsAPI.load()
    if FS25E_ModSettings ~= nil then return FS25E_ModSettings.load() end
    return false
end

function FS25E_SettingsAPI.save()
    if FS25E_ModSettings ~= nil then return FS25E_ModSettings.save() end
    return false
end

function FS25E_SettingsAPI.selectPreset(name)
    if FS25E_ProfileManager == nil then return false end
    local ok = FS25E_ProfileManager.selectPreset(name)
    if FS25E_ModSettings ~= nil then FS25E_ModSettings.set("preset", name) end
    return ok
end

function FS25E_SettingsAPI.applySelectedPreset()
    if FS25E_ProfileManager ~= nil and FS25E_ProfileManager.applySelected ~= nil then
        return FS25E_ProfileManager.applySelected()
    end
    return false, "applySelected missing"
end

function FS25E_SettingsAPI.applySelected()
    return FS25E_SettingsAPI.applySelectedPreset()
end

function FS25E_SettingsAPI.setEnabled(v)
    return FS25E_SettingsAPI.set("enabled", v == true)
end

function FS25E_SettingsAPI.getEnabled()
    return FS25E_SettingsAPI.get("enabled") == true
end

function FS25E_SettingsAPI.setAutoApply(v)
    return FS25E_SettingsAPI.set("autoApply", v == true)
end

function FS25E_SettingsAPI.getAutoApply()
    return FS25E_SettingsAPI.get("autoApply") == true
end

function FS25E_SettingsAPI.setExpertMode(v)
    return FS25E_SettingsAPI.set("expertMode", v == true)
end

function FS25E_SettingsAPI.getExpertMode()
    return FS25E_SettingsAPI.get("expertMode") == true
end

function FS25E_SettingsAPI.getActivePreset()
    return FS25E_SettingsAPI.get("preset")
end

function FS25E_SettingsAPI.listPresets()
    if FS25E_ProfileManager ~= nil and FS25E_ProfileManager.listNames ~= nil then
        return FS25E_ProfileManager.listNames()
    end
    return { "Performance", "Balanced", "Quality", "Cinematic" }
end


-- =============================================================================
-- Expert Live-Overlay API (no dialog; no engine setters from GUI)
-- Gates: CapabilityRegistry.allowsApply / expertMode / Soft-Apply unchanged.
-- opts = { prefixArgs = { lightId, ... }, keySuffix = "..." }
-- =============================================================================

local function liveCacheKey(capabilityId, opts)
    opts = opts or {}
    if opts.keySuffix ~= nil and opts.keySuffix ~= "" then
        return tostring(capabilityId) .. "|" .. tostring(opts.keySuffix)
    end
    local prefix = opts.prefixArgs
    if prefix ~= nil and prefix[1] ~= nil then
        return tostring(capabilityId) .. "|" .. tostring(prefix[1])
    end
    return tostring(capabilityId)
end

function FS25E_SettingsAPI.liveGet(capabilityId, opts)
    local key = liveCacheKey(capabilityId, opts)
    local e = nil
    if FS25E_SettingsCache ~= nil then
        e = FS25E_SettingsCache.get(key)
    end
    local status = nil
    if FS25E_CapabilityRegistry ~= nil then
        status = FS25E_CapabilityRegistry.getStatus(capabilityId)
    end
    local last = nil
    if FS25E_CapabilityRegistry ~= nil and FS25E_CapabilityRegistry.getLastResult ~= nil then
        last = FS25E_CapabilityRegistry.getLastResult(capabilityId)
    end
    return {
        key = key,
        capabilityId = capabilityId,
        requested = e ~= nil and e.requested or nil,
        current = e ~= nil and e.current or nil,
        original = e ~= nil and e.original or nil,
        locked = e ~= nil and e.locked == true or false,
        status = status,
        lastResult = last,
    }
end

function FS25E_SettingsAPI.liveSetRequested(capabilityId, number, opts)
    if FS25E_SettingsCache == nil then
        return false
    end
    local key = liveCacheKey(capabilityId, opts)
    local ok = FS25E_SettingsCache.setRequestedNumber(key, number)
    if ok and FS25E_SettingsCache.get ~= nil then
        local e = FS25E_SettingsCache.get(key)
        if e ~= nil then
            e.capabilityId = capabilityId
        end
    end
    return ok
end

local function liveApplyViaManagers(capabilityId, n, opts)
    opts = opts or {}
    local prefix = opts.prefixArgs or {}
    local lightId = prefix[1]

    -- Global Wave-1 managers when available
    if FS25E_LodGovernor ~= nil then
        if capabilityId == "view-distance-coeff" and FS25E_LodGovernor.setViewDistanceCoeff ~= nil then
            return FS25E_LodGovernor.setViewDistanceCoeff(n)
        elseif capabilityId == "lod-distance-coeff" and FS25E_LodGovernor.setLODDistanceCoeff ~= nil then
            return FS25E_LodGovernor.setLODDistanceCoeff(n)
        elseif capabilityId == "foliage-view-distance-coeff" and FS25E_LodGovernor.setFoliageViewDistanceCoeff ~= nil then
            return FS25E_LodGovernor.setFoliageViewDistanceCoeff(n)
        elseif capabilityId == "foliage-lod-distance-coeff" and FS25E_LodGovernor.setFoliageLODDistanceCoeff ~= nil then
            return FS25E_LodGovernor.setFoliageLODDistanceCoeff(n)
        elseif capabilityId == "terrain-lod-distance-coeff" and FS25E_LodGovernor.setTerrainLODDistanceCoeff ~= nil then
            return FS25E_LodGovernor.setTerrainLODDistanceCoeff(n)
        end
    end
    if FS25E_ShadowManager ~= nil then
        if capabilityId == "max-num-shadow-lights" and FS25E_ShadowManager.setMaxNumShadowLights ~= nil then
            return FS25E_ShadowManager.setMaxNumShadowLights(n)
        elseif lightId ~= nil then
            if capabilityId == "light-shadow-priority" and FS25E_ShadowManager.setLightShadowPriority ~= nil then
                return FS25E_ShadowManager.setLightShadowPriority(lightId, n)
            elseif capabilityId == "light-soft-shadow-size" and FS25E_ShadowManager.setLightSoftShadowSize ~= nil then
                return FS25E_ShadowManager.setLightSoftShadowSize(lightId, n)
            elseif capabilityId == "light-soft-shadow-distance" and FS25E_ShadowManager.setLightSoftShadowDistance ~= nil then
                return FS25E_ShadowManager.setLightSoftShadowDistance(lightId, n)
            elseif capabilityId == "light-soft-shadow-depth-bias" and FS25E_ShadowManager.setLightSoftShadowDepthBiasFactor ~= nil then
                return FS25E_ShadowManager.setLightSoftShadowDepthBiasFactor(lightId, n)
            end
        end
    end
    return nil -- fall through to CapabilityApplier
end

--- Live apply: optional number updates requested, then applies through managers/Applier.
--- Returns ok, err
function FS25E_SettingsAPI.liveApply(capabilityId, number, opts)
    opts = opts or {}
    local n = number
    if n ~= nil then
        if not FS25E_SettingsAPI.liveSetRequested(capabilityId, n, opts) then
            return false, "invalid number"
        end
        n = tonumber(n)
    else
        local snap = FS25E_SettingsAPI.liveGet(capabilityId, opts)
        n = tonumber(snap.requested)
        if n == nil then
            return false, "no requested value"
        end
    end

    local via = liveApplyViaManagers(capabilityId, n, opts)
    if via ~= nil then
        if via == true then
            return true, nil
        end
        return false, "manager apply failed"
    end

    if FS25E_CapabilityApplier == nil or FS25E_CapabilityApplier.apply == nil then
        return false, "CapabilityApplier missing"
    end
    return FS25E_CapabilityApplier.apply(capabilityId, {
        prefixArgs = opts.prefixArgs,
        values = { n },
        keySuffix = opts.keySuffix,
    })
end

function FS25E_SettingsAPI.liveApplyRequested(capabilityId, opts)
    return FS25E_SettingsAPI.liveApply(capabilityId, nil, opts)
end

function FS25E_SettingsAPI.liveRestore(capabilityId, opts)
    if FS25E_CapabilityApplier == nil then
        return false, "CapabilityApplier missing"
    end
    local key = liveCacheKey(capabilityId, opts)
    if FS25E_CapabilityApplier.restoreOne ~= nil then
        return FS25E_CapabilityApplier.restoreOne(key)
    end
    if FS25E_RestoreManager ~= nil and FS25E_RestoreManager.restoreAll ~= nil then
        FS25E_RestoreManager.restoreAll()
        return true
    end
    return false, "no restore path"
end


--- List all registry caps for Expert Live-Overlay (fine tune 0.01).
--- GUI filters by expertMode / allowsApply as needed.
function FS25E_SettingsAPI.liveListCaps()
    local out = {}
    if FS25E_CapabilityRegistry == nil or FS25E_CapabilityRegistry.all == nil then
        return out
    end
    for id, entry in pairs(FS25E_CapabilityRegistry.all()) do
        local cost = nil
        local warn = false
        if FS25E_CostCatalog ~= nil then
            cost = FS25E_CostCatalog.getCost(id)
            warn = FS25E_CostCatalog.shouldWarn(id)
        end
        out[#out + 1] = {
            id = id,
            status = entry.status,
            apiName = entry.apiName or entry.setter,
            setter = entry.setter,
            getter = entry.getter,
            applyMode = entry.applyMode,
            scope = entry.scope,
            cost = cost,
            warn = warn,
            allowsApply = FS25E_CapabilityRegistry.allowsApply ~= nil and FS25E_CapabilityRegistry.allowsApply(id) or false,
        }
    end
    table.sort(out, function(a, b) return tostring(a.id) < tostring(b.id) end)
    return out
end

function FS25E_SettingsAPI.getCapCost(capabilityId)
    if FS25E_CostCatalog == nil then
        return { cost = "med", warn = false }
    end
    local e = FS25E_CostCatalog.get(capabilityId)
    if e == nil then
        return { cost = "med", warn = false }
    end
    return { cost = e.cost, warn = e.warn == true, notes = e.notes }
end

--- Combined HUD snapshot: engine dt metrics + optional sidecar telemetry.
function FS25E_SettingsAPI.getHudTelemetry()
    local perf = nil
    if FS25E_PerformanceMonitor ~= nil and FS25E_PerformanceMonitor.getSnapshot ~= nil then
        perf = FS25E_PerformanceMonitor.getSnapshot()
    end
    local sys = nil
    if FS25E_TelemetryReader ~= nil and FS25E_TelemetryReader.getSnapshot ~= nil then
        sys = FS25E_TelemetryReader.getSnapshot()
    end
    return {
        engine = perf,
        system = sys,
    }
end
