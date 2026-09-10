-- FS25_Enhanced / Core/GraphicsGovernor.lua
-- Phase 2: Fast/Medium/Slow timers + hysteresis bands + SceneAnalyzer integration.
-- Default: enabled=false, autoApply=false. Phase-2 decision path does NOT call setters.
-- Wave-1 manager applyPreset only if enabled AND autoApply (never default).

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

local BAND_FAST_RATIO = 1.10
local BAND_SLOW_RATIO = 0.80

local INTERVAL_MEDIUM_MS = 250
local INTERVAL_SLOW_MS = 1000
local accumMediumMs = 0
local accumSlowMs = 0

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
    if FS25E_ProfileManager ~= nil and FS25E_ProfileManager.getActiveName ~= nil then
        desiredPreset = FS25E_ProfileManager.getActiveName() or "Balanced"
    end
    FS25E_Debug.info("GraphicsGovernor", "phase2 registered; enabled=false autoApply=false (no automatic setters)")
end

function FS25E_GraphicsGovernor.setEnabled(value)
    enabled = value == true
    FS25E_Debug.info("GraphicsGovernor", "setEnabled=" .. tostring(enabled))
end

function FS25E_GraphicsGovernor.isEnabled()
    return enabled
end

function FS25E_GraphicsGovernor.setAutoApply(value)
    autoApply = value == true
    FS25E_Debug.info("GraphicsGovernor", "setAutoApply=" .. tostring(autoApply))
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

    if FS25E_PerformanceMonitor.isSpike() then
        return FS25E_GraphicsGovernor.MODE.FAST
    end
    if avg > budget * BAND_FAST_RATIO or FS25E_PerformanceMonitor.isOverBudget() then
        return FS25E_GraphicsGovernor.MODE.FAST
    end
    if avg < budget * BAND_SLOW_RATIO then
        if FS25E_SceneAnalyzer ~= nil then
            local loadHint = FS25E_SceneAnalyzer.getLoadHint()
            if loadHint >= 2 then
                return FS25E_GraphicsGovernor.MODE.MEDIUM
            end
        end
        return FS25E_GraphicsGovernor.MODE.SLOW
    end
    return FS25E_GraphicsGovernor.MODE.MEDIUM
end

local function mapDesiredPreset(suggested)
    if FS25E_ProfileManager ~= nil and FS25E_ProfileManager.presetForMode ~= nil then
        return FS25E_ProfileManager.presetForMode(suggested)
    end
    if suggested == FS25E_GraphicsGovernor.MODE.FAST then
        return "Performance"
    elseif suggested == FS25E_GraphicsGovernor.MODE.SLOW then
        return "Quality"
    end
    return desiredPreset or "Balanced"
end

function FS25E_GraphicsGovernor.applyPreset(presetName, force)
    if not force and (not enabled or not autoApply) then
        FS25E_Debug.info("GraphicsGovernor", "applyPreset skipped (enabled=" .. tostring(enabled) .. " autoApply=" .. tostring(autoApply) .. ")")
        return false
    end
    FS25E_Debug.info("GraphicsGovernor", "applyPreset " .. tostring(presetName) .. " (via ProfileManager.applySelected; session-only)")
    if FS25E_ProfileManager ~= nil then
        FS25E_ProfileManager.selectPreset(presetName)
        if FS25E_ProfileManager.applySelected ~= nil then
            return FS25E_ProfileManager.applySelected(true)
        end
    end
    if FS25E_ShadowManager ~= nil and FS25E_ShadowManager.applyPresetStub ~= nil then
        FS25E_ShadowManager.applyPresetStub(presetName)
    end
    if FS25E_LodGovernor ~= nil and FS25E_LodGovernor.applyPresetStub ~= nil then
        FS25E_LodGovernor.applyPresetStub(presetName)
    end
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
                "slow tick#%d mode=%s desired=%s preset=%s avgMs=%.2f budget=%.2f loadHint=%d enabled=%s autoApply=%s",
                decisionTicks,
                tostring(mode),
                tostring(desiredMode),
                tostring(desiredPreset),
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
