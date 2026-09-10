-- FS25_Enhanced / Core/GraphicsGovernor.lua
-- Fast / Medium / Slow + hysteresis stubs. NO engine writes in Phase 1.

FS25E_GraphicsGovernor = {}

FS25E_GraphicsGovernor.MODE = {
    FAST = "FAST",
    MEDIUM = "MEDIUM",
    SLOW = "SLOW",
}

local mode = FS25E_GraphicsGovernor.MODE.MEDIUM
local enabled = false -- Phase 1: governor present but not applying
local hysteresisMs = 500 -- dwell before mode change
local modeTimerMs = 0
local pendingMode = nil

-- Intervals (ms) for controller tiers — stubs for later SceneAnalyzer/Budget work
local INTERVAL_FAST_MS = 0
local INTERVAL_MEDIUM_MS = 250
local INTERVAL_SLOW_MS = 1000
local accumMediumMs = 0
local accumSlowMs = 0

function FS25E_GraphicsGovernor.init()
    mode = FS25E_GraphicsGovernor.MODE.MEDIUM
    enabled = false
    modeTimerMs = 0
    pendingMode = nil
    accumMediumMs = 0
    accumSlowMs = 0
    FS25E_Debug.info("GraphicsGovernor", "init (empty; no engine writers)")
end

function FS25E_GraphicsGovernor.setEnabled(value)
    enabled = value == true
end

function FS25E_GraphicsGovernor.isEnabled()
    return enabled
end

function FS25E_GraphicsGovernor.getMode()
    return mode
end

--- Suggest a mode from performance signals (no writes).
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

local function applyModeChange(newMode)
    mode = newMode
    -- Intentionally empty: no setShadow*/setLight*/set*DistanceCoeff/setRain*/quality writers.
    FS25E_Debug.info("GraphicsGovernor", "mode -> " .. tostring(newMode) .. " (stub, no engine write)")
end

--- Mission update tick. dt in seconds.
function FS25E_GraphicsGovernor.update(dt)
    if not enabled or dt == nil then
        return
    end
    local dtMs = dt * 1000.0
    accumMediumMs = accumMediumMs + dtMs
    accumSlowMs = accumSlowMs + dtMs

    -- Fast path every frame: only read monitor (already updated by bootstrap)
    -- Medium / Slow stubs reserved for future analyzers (no-op now)
    if accumMediumMs >= INTERVAL_MEDIUM_MS then
        accumMediumMs = 0
        -- future: medium-cost scene / budget soft decisions
    end
    if accumSlowMs >= INTERVAL_SLOW_MS then
        accumSlowMs = 0
        -- future: slow recalibration / cost model
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
