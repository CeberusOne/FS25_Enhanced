-- FS25_Enhanced / Core/GraphicsGovernor.lua
-- Fast / Medium / Slow + hysteresis. Wave 1: managers ready; auto-apply OFF (enabled=false).

FS25E_GraphicsGovernor = {}

FS25E_GraphicsGovernor.MODE = {
    FAST = "FAST",
    MEDIUM = "MEDIUM",
    SLOW = "SLOW",
}

local mode = FS25E_GraphicsGovernor.MODE.MEDIUM
local enabled = false -- Wave 1: safe load; do not auto-apply
local autoApply = false -- explicit: even if enabled, presets only when autoApply true
local hysteresisMs = 500
local modeTimerMs = 0
local pendingMode = nil

local INTERVAL_FAST_MS = 0
local INTERVAL_MEDIUM_MS = 250
local INTERVAL_SLOW_MS = 1000
local accumMediumMs = 0
local accumSlowMs = 0

function FS25E_GraphicsGovernor.init()
    mode = FS25E_GraphicsGovernor.MODE.MEDIUM
    enabled = false
    autoApply = false
    modeTimerMs = 0
    pendingMode = nil
    accumMediumMs = 0
    accumSlowMs = 0
    FS25E_Debug.info("GraphicsGovernor", "wave1 registered, auto-apply off")
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

function FS25E_GraphicsGovernor.getMode()
    return mode
end

function FS25E_GraphicsGovernor.suggestMode()
    if FS25E_PerformanceMonitor == nil then
        return FS25E_GraphicsGovernor.MODE.MEDIUM
    end
    if FS25E_PerformanceMonitor.isSpike() or FS25E_PerformanceMonitor.isOverBudget() then
        return FS25E_GraphicsGovernor.MODE.FAST
    end
    local avg = FS25E_PerformanceMonitor.getAverageMs()
    local budget = FS25E_PerformanceMonitor.getTargetBudgetMs()
    if avg < budget * 0.75 then
        return FS25E_GraphicsGovernor.MODE.SLOW
    end
    return FS25E_GraphicsGovernor.MODE.MEDIUM
end

--- Explicit preset apply when turned on. Wave 1: no RESTART caps; no EXPERIMENTAL.
--- Does nothing unless enabled AND autoApply (or force=true).
function FS25E_GraphicsGovernor.applyPreset(presetName, force)
    if not force and (not enabled or not autoApply) then
        FS25E_Debug.info("GraphicsGovernor", "applyPreset skipped (enabled=" .. tostring(enabled) .. " autoApply=" .. tostring(autoApply) .. ")")
        return false
    end
    FS25E_Debug.info("GraphicsGovernor", "applyPreset " .. tostring(presetName) .. " (wave1 managers)")
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
    -- Wave 1: mode tracking only unless autoApply explicitly enabled.
    -- Never call setTerrainQuality (RESTART), saveHardwareScalability, or EXPERIMENTAL setters.
    if enabled and autoApply then
        FS25E_Debug.info("GraphicsGovernor", "mode -> " .. tostring(newMode) .. " (autoApply on; invoke manager stubs)")
        if newMode == FS25E_GraphicsGovernor.MODE.FAST then
            -- Fast path: LOD/shadow session adjusts only — no setTerrainQuality
            FS25E_GraphicsGovernor.applyPreset("FAST", true)
        elseif newMode == FS25E_GraphicsGovernor.MODE.SLOW then
            FS25E_GraphicsGovernor.applyPreset("SLOW", true)
        else
            FS25E_GraphicsGovernor.applyPreset("MEDIUM", true)
        end
    else
        FS25E_Debug.info("GraphicsGovernor", "mode -> " .. tostring(newMode) .. " (stub; auto-apply off)")
    end
end

function FS25E_GraphicsGovernor.update(dt)
    if not enabled or dt == nil then
        return
    end
    local dtMs = dt * 1000.0
    accumMediumMs = accumMediumMs + dtMs
    accumSlowMs = accumSlowMs + dtMs

    if accumMediumMs >= INTERVAL_MEDIUM_MS then
        accumMediumMs = 0
    end
    if accumSlowMs >= INTERVAL_SLOW_MS then
        accumSlowMs = 0
    end

    local suggested = FS25E_GraphicsGovernor.suggestMode()
    if suggested ~= mode then
        if pendingMode ~= suggested then
            pendingMode = suggested
            modeTimerMs = 0
        else
            modeTimerMs = modeTimerMs + dtMs
            if modeTimerMs >= hysteresisMs then
                applyModeChange(suggested)
                pendingMode = nil
                modeTimerMs = 0
            end
        end
    else
        pendingMode = nil
        modeTimerMs = 0
    end
end

function FS25E_GraphicsGovernor.reset()
    FS25E_GraphicsGovernor.init()
end
