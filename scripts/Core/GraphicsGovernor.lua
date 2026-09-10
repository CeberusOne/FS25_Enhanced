-- FS25_Enhanced / Core/GraphicsGovernor.lua
-- Casual-Automatik (Wave-1 only): when enabled+adaptive/autoApply, apply Performance/
-- Balanced/Quality targets via ProfileManager → LodGovernor/ShadowManager.
-- Optional fine nudge between presets from FPS pressure + SceneAnalyzer loadHint.
-- Defaults: enabled=false, autoApply=false. Never Expert/Experimental auto. No fake sensors.

FS25E_GraphicsGovernor = {}

FS25E_GraphicsGovernor.MODE = {
    FAST = "FAST",
    MEDIUM = "MEDIUM",
    SLOW = "SLOW",
}

local mode = FS25E_GraphicsGovernor.MODE.MEDIUM
local desiredMode = FS25E_GraphicsGovernor.MODE.MEDIUM
local desiredPreset = "Balanced"
local enabled = false
local autoApply = false
local observeAlways = true
local debugLog = false
local hysteresisMs = 500
local modeTimerMs = 0
local pendingMode = nil
local decisionTicks = 0
local lastAppliedPreset = nil
local fineAccumMs = 0
local FINE_INTERVAL_MS = 2000

local BAND_FAST_RATIO = 1.10
local BAND_SLOW_RATIO = 0.80
local BAND_SEVERE_RATIO = 1.25

local INTERVAL_MEDIUM_MS = 250
local INTERVAL_SLOW_MS = 1000
local accumMediumMs = 0
local accumSlowMs = 0

-- Wave-1 only floors/ceilings for fine nudge (CONFIRMED distance + shadow light budget).
local WAVE1_FLOOR = {
    viewDistanceCoeff = 0.55,
    lodDistanceCoeff = 0.55,
    foliageViewDistanceCoeff = 0.5,
    foliageLodDistanceCoeff = 0.5,
    terrainLodDistanceCoeff = 0.55,
    maxNumShadowLights = 1,
}
local WAVE1_CEIL = {
    viewDistanceCoeff = 1.35,
    lodDistanceCoeff = 1.35,
    foliageViewDistanceCoeff = 1.3,
    foliageLodDistanceCoeff = 1.3,
    terrainLodDistanceCoeff = 1.3,
    maxNumShadowLights = 6,
}

function FS25E_GraphicsGovernor.init()
    mode = FS25E_GraphicsGovernor.MODE.MEDIUM
    desiredMode = mode
    desiredPreset = "Balanced"
    enabled = false
    autoApply = false
    observeAlways = true
    debugLog = false
    modeTimerMs = 0
    pendingMode = nil
    decisionTicks = 0
    accumMediumMs = 0
    accumSlowMs = 0
    fineAccumMs = 0
    lastAppliedPreset = nil
    if FS25E_ProfileManager ~= nil and FS25E_ProfileManager.getActiveName ~= nil then
        desiredPreset = FS25E_ProfileManager.getActiveName() or "Balanced"
    end
    FS25E_Debug.info("GraphicsGovernor", "casual-auto Wave-1; enabled=false autoApply=false (no Expert auto)")
end

function FS25E_GraphicsGovernor.setEnabled(value)
    enabled = value == true
    FS25E_Debug.info("GraphicsGovernor", "setEnabled=" .. tostring(enabled))
    if enabled and autoApply then
        FS25E_GraphicsGovernor.applyPreset(desiredPreset or "Balanced", true)
    end
end

function FS25E_GraphicsGovernor.isEnabled()
    return enabled
end

function FS25E_GraphicsGovernor.setAutoApply(value)
    autoApply = value == true
    FS25E_Debug.info("GraphicsGovernor", "setAutoApply=" .. tostring(autoApply))
    if enabled and autoApply then
        FS25E_GraphicsGovernor.applyPreset(desiredPreset or "Balanced", true)
    end
end

function FS25E_GraphicsGovernor.isAutoApply()
    return autoApply
end

function FS25E_GraphicsGovernor.setDebugLog(value)
    debugLog = value == true
end

function FS25E_GraphicsGovernor.getMode()
    return mode
end

function FS25E_GraphicsGovernor.getDesiredMode()
    return desiredMode
end

function FS25E_GraphicsGovernor.getDesiredPreset()
    return desiredPreset
end

function FS25E_GraphicsGovernor.getDecisionTicks()
    return decisionTicks
end

function FS25E_GraphicsGovernor.getLastAppliedPreset()
    return lastAppliedPreset
end

local function hasRelevantLocks()
    if FS25E_SettingsCache == nil then
        return false
    end
    local keys = {
        "viewDistanceCoeff",
        "lodDistanceCoeff",
        "foliageViewDistanceCoeff",
        "foliageLodDistanceCoeff",
        "terrainLodDistanceCoeff",
        "maxNumShadowLights",
        "allowFoliageShadows",
        "preset",
        "adaptive",
    }
    for i = 1, #keys do
        local e = FS25E_SettingsCache.get(keys[i])
        if e ~= nil and e.locked then
            return true
        end
    end
    return false
end

local function fpsPressure()
    -- >0 = over budget (need lower visuals), <0 = under budget (room to raise)
    if FS25E_PerformanceMonitor == nil then
        return 0
    end
    local avg = FS25E_PerformanceMonitor.getAverageMs()
    local budget = FS25E_PerformanceMonitor.getTargetBudgetMs()
    if budget == nil or budget <= 0 then
        budget = 16.67
    end
    if avg == nil or avg <= 0 then
        return 0
    end
    return (avg / budget) - 1.0
end

function FS25E_GraphicsGovernor.suggestMode()
    if FS25E_SettingsCache ~= nil then
        local adaptive = FS25E_SettingsCache.get("adaptive")
        if adaptive ~= nil and adaptive.locked and adaptive.requested == false then
            return FS25E_GraphicsGovernor.MODE.MEDIUM
        end
        if adaptive ~= nil and adaptive.current == false and adaptive.locked then
            return FS25E_GraphicsGovernor.MODE.MEDIUM
        end
    end

    if FS25E_PerformanceMonitor == nil then
        return FS25E_GraphicsGovernor.MODE.MEDIUM
    end

    local avg = FS25E_PerformanceMonitor.getAverageMs()
    local budget = FS25E_PerformanceMonitor.getTargetBudgetMs()
    if budget == nil or budget <= 0 then
        budget = 16.67
    end

    local loadHint = 0
    if FS25E_SceneAnalyzer ~= nil then
        loadHint = FS25E_SceneAnalyzer.getLoadHint() or 0
    end

    if FS25E_PerformanceMonitor.isSpike() then
        return FS25E_GraphicsGovernor.MODE.FAST
    end
    if avg > budget * BAND_FAST_RATIO or FS25E_PerformanceMonitor.isOverBudget() then
        return FS25E_GraphicsGovernor.MODE.FAST
    end
    -- Heavy scene: prefer not climbing to Quality even if FPS looks good briefly
    if avg < budget * BAND_SLOW_RATIO then
        if loadHint >= 2 then
            return FS25E_GraphicsGovernor.MODE.MEDIUM
        end
        return FS25E_GraphicsGovernor.MODE.SLOW
    end
    if loadHint >= 2 and avg > budget * 0.95 then
        return FS25E_GraphicsGovernor.MODE.FAST
    end
    return FS25E_GraphicsGovernor.MODE.MEDIUM
end

local function mapDesiredPreset(suggested)
    -- Adaptive never selects Cinematic (Wave-1 casual only).
    if FS25E_ProfileManager ~= nil and FS25E_ProfileManager.presetForMode ~= nil then
        local name = FS25E_ProfileManager.presetForMode(suggested)
        if name == "Cinematic" then
            return "Quality"
        end
        return name
    end
    if suggested == FS25E_GraphicsGovernor.MODE.FAST then
        return "Performance"
    elseif suggested == FS25E_GraphicsGovernor.MODE.SLOW then
        return "Quality"
    end
    return desiredPreset or "Balanced"
end

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

--- Fine Wave-1 nudge: scale distance coeffs / shadow lights toward floor/ceil from FPS pressure.
--- Only CONFIRMED Wave-1 keys. No Expert caps.
local function applyFineNudge()
    if not enabled or not autoApply then
        return false
    end
    if hasRelevantLocks() then
        return false
    end
    if FS25E_ProfileManager == nil or FS25E_ProfileManager.getPreset == nil then
        return false
    end
    local preset = FS25E_ProfileManager.getPreset(desiredPreset or "Balanced")
    if preset == nil or preset.targets == nil then
        return false
    end

    local pressure = fpsPressure()
    local loadHint = 0
    if FS25E_SceneAnalyzer ~= nil then
        loadHint = FS25E_SceneAnalyzer.getLoadHint() or 0
    end
    -- Bias pressure upward (more conservative) when scene is heavy
    pressure = pressure + (loadHint * 0.05)

    -- Dead zone: small error → leave preset targets alone
    if pressure > -0.04 and pressure < 0.04 then
        return false
    end

    local factor = 1.0 - clamp(pressure, -0.25, 0.35) * 0.5
    -- pressure +0.2 → factor 0.9; pressure -0.2 → factor 1.1
    local t = preset.targets
    local nudged = {}
    local keys = {
        "viewDistanceCoeff",
        "lodDistanceCoeff",
        "foliageViewDistanceCoeff",
        "foliageLodDistanceCoeff",
        "terrainLodDistanceCoeff",
    }
    for i = 1, #keys do
        local k = keys[i]
        local base = t[k]
        if type(base) == "number" then
            local v = base * factor
            nudged[k] = clamp(v, WAVE1_FLOOR[k], WAVE1_CEIL[k])
        end
    end
    if type(t.maxNumShadowLights) == "number" then
        local lights = t.maxNumShadowLights
        if pressure > 0.12 then
            lights = lights - 1
        elseif pressure < -0.12 then
            lights = lights + 1
        end
        nudged.maxNumShadowLights = clamp(lights, WAVE1_FLOOR.maxNumShadowLights, WAVE1_CEIL.maxNumShadowLights)
    end
    if t.allowFoliageShadows ~= nil then
        -- Only force foliage shadows off under severe overload
        if pressure > (BAND_SEVERE_RATIO - 1.0) then
            nudged.allowFoliageShadows = false
        else
            nudged.allowFoliageShadows = t.allowFoliageShadows
        end
    end

    -- Use named Wave-1 setters (applyValues expects short keys view/lod/…).
    local okAny = false
    if FS25E_LodGovernor ~= nil then
        if nudged.viewDistanceCoeff ~= nil and FS25E_LodGovernor.setViewDistanceCoeff ~= nil then
            okAny = FS25E_LodGovernor.setViewDistanceCoeff(nudged.viewDistanceCoeff) or okAny
        end
        if nudged.lodDistanceCoeff ~= nil and FS25E_LodGovernor.setLODDistanceCoeff ~= nil then
            okAny = FS25E_LodGovernor.setLODDistanceCoeff(nudged.lodDistanceCoeff) or okAny
        end
        if nudged.foliageViewDistanceCoeff ~= nil and FS25E_LodGovernor.setFoliageViewDistanceCoeff ~= nil then
            okAny = FS25E_LodGovernor.setFoliageViewDistanceCoeff(nudged.foliageViewDistanceCoeff) or okAny
        end
        if nudged.foliageLodDistanceCoeff ~= nil and FS25E_LodGovernor.setFoliageLODDistanceCoeff ~= nil then
            okAny = FS25E_LodGovernor.setFoliageLODDistanceCoeff(nudged.foliageLodDistanceCoeff) or okAny
        end
        if nudged.terrainLodDistanceCoeff ~= nil and FS25E_LodGovernor.setTerrainLODDistanceCoeff ~= nil then
            okAny = FS25E_LodGovernor.setTerrainLODDistanceCoeff(nudged.terrainLodDistanceCoeff) or okAny
        end
        if nudged.allowFoliageShadows ~= nil and FS25E_LodGovernor.setAllowFoliageShadows ~= nil then
            okAny = FS25E_LodGovernor.setAllowFoliageShadows(nudged.allowFoliageShadows) or okAny
        end
    end
    if nudged.maxNumShadowLights ~= nil and FS25E_ShadowManager ~= nil and FS25E_ShadowManager.setMaxNumShadowLights ~= nil then
        okAny = FS25E_ShadowManager.setMaxNumShadowLights(nudged.maxNumShadowLights) or okAny
    end

    if okAny and debugLog then
        FS25E_Debug.info("GraphicsGovernor", string.format(
            "fineNudge preset=%s pressure=%.3f factor=%.3f loadHint=%d",
            tostring(desiredPreset), pressure, factor, loadHint
        ))
    end
    return okAny
end

function FS25E_GraphicsGovernor.applyPreset(presetName, force)
    if not force and (not enabled or not autoApply) then
        FS25E_Debug.info("GraphicsGovernor", "applyPreset skipped (enabled=" .. tostring(enabled) .. " autoApply=" .. tostring(autoApply) .. ")")
        return false
    end
    if presetName == "Cinematic" and force ~= "allowCinematic" then
        -- Casual adaptive path never applies Cinematic
        presetName = "Quality"
    end
    FS25E_Debug.info("GraphicsGovernor", "applyPreset " .. tostring(presetName) .. " (Wave-1 via ProfileManager.applySelected; session-only)")
    if FS25E_ProfileManager ~= nil then
        FS25E_ProfileManager.selectPreset(presetName)
        if FS25E_ProfileManager.applySelected ~= nil then
            local ok = FS25E_ProfileManager.applySelected(true)
            if ok then
                lastAppliedPreset = presetName
                desiredPreset = presetName
            end
            return ok
        end
    end
    if FS25E_ShadowManager ~= nil and FS25E_ShadowManager.applyPresetStub ~= nil then
        FS25E_ShadowManager.applyPresetStub(presetName)
    end
    if FS25E_LodGovernor ~= nil and FS25E_LodGovernor.applyPresetStub ~= nil then
        FS25E_LodGovernor.applyPresetStub(presetName)
    end
    lastAppliedPreset = presetName
    return true
end

local function applyModeChange(newMode)
    mode = newMode
    desiredMode = newMode
    desiredPreset = mapDesiredPreset(newMode)
    -- Never call setTerrainQuality, saveHardwareScalability, or EXPERIMENTAL setters.
    if enabled and autoApply then
        FS25E_Debug.info("GraphicsGovernor", "mode -> " .. tostring(newMode) .. " preset=" .. tostring(desiredPreset) .. " (autoApply on)")
        FS25E_GraphicsGovernor.applyPreset(desiredPreset, true)
    else
        FS25E_Debug.info("GraphicsGovernor", string.format(
            "mode -> %s desiredPreset=%s (decision only; auto-apply off)",
            tostring(newMode),
            tostring(desiredPreset)
        ))
    end
end

local function runDecisionStub()
    decisionTicks = decisionTicks + 1
    local suggested = FS25E_GraphicsGovernor.suggestMode()
    desiredMode = suggested
    desiredPreset = mapDesiredPreset(suggested)

    if not enabled then
        return
    end

    if suggested ~= mode then
        if pendingMode ~= suggested then
            pendingMode = suggested
            modeTimerMs = 0
        end
    else
        pendingMode = nil
        modeTimerMs = 0
    end
end

function FS25E_GraphicsGovernor.update(dt)
    if dt == nil then
        return
    end
    if not observeAlways and not enabled then
        return
    end

    local dtMs = dt * 1000.0
    accumMediumMs = accumMediumMs + dtMs
    accumSlowMs = accumSlowMs + dtMs
    fineAccumMs = fineAccumMs + dtMs

    if enabled and pendingMode ~= nil and pendingMode ~= mode then
        modeTimerMs = modeTimerMs + dtMs
        if modeTimerMs >= hysteresisMs then
            applyModeChange(pendingMode)
            if not hasRelevantLocks() and FS25E_ProfileManager ~= nil then
                FS25E_ProfileManager.selectPreset(desiredPreset)
            end
            pendingMode = nil
            modeTimerMs = 0
        end
    end

    if accumMediumMs >= INTERVAL_MEDIUM_MS then
        accumMediumMs = 0
        runDecisionStub()
        if enabled and pendingMode == nil then
            local suggested = desiredMode
            if suggested ~= mode then
                pendingMode = suggested
                modeTimerMs = 0
            end
        elseif enabled and pendingMode ~= nil and pendingMode ~= desiredMode then
            pendingMode = desiredMode
            modeTimerMs = 0
        end
    end

    -- Fine Wave-1 nudge while settled on a mode (adaptive on)
    if enabled and autoApply and pendingMode == nil and fineAccumMs >= FINE_INTERVAL_MS then
        fineAccumMs = 0
        applyFineNudge()
    end

    if accumSlowMs >= INTERVAL_SLOW_MS then
        accumSlowMs = 0
        local shouldLog = debugLog or (decisionTicks <= 1) or (decisionTicks % 10 == 0)
        if shouldLog then
            local avg = 0
            local budget = 0
            if FS25E_PerformanceMonitor ~= nil then
                avg = FS25E_PerformanceMonitor.getAverageMs()
                budget = FS25E_PerformanceMonitor.getTargetBudgetMs()
            end
            local loadHint = 0
            if FS25E_SceneAnalyzer ~= nil then
                loadHint = FS25E_SceneAnalyzer.getLoadHint()
            end
            FS25E_Debug.info("GraphicsGovernor", string.format(
                "slow tick#%d mode=%s desired=%s preset=%s lastApplied=%s avgMs=%.2f budget=%.2f loadHint=%d enabled=%s autoApply=%s",
                decisionTicks,
                tostring(mode),
                tostring(desiredMode),
                tostring(desiredPreset),
                tostring(lastAppliedPreset),
                avg,
                budget,
                loadHint,
                tostring(enabled),
                tostring(autoApply)
            ))
        end
    end
end

function FS25E_GraphicsGovernor.reset()
    FS25E_GraphicsGovernor.init()
end
