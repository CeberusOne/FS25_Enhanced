-- FS25_Enhanced / Core/PerformanceMonitor.lua
-- Sliding frame-time from dt; spike/variance; target budget. NO getFps.

FS25E_PerformanceMonitor = {}

local WINDOW = 60
local samples = {} -- ring buffer of frame times (ms)
local sampleCount = 0
local writeIndex = 0
local sumMs = 0
local sumSqMs = 0
local lastDtMs = 0
local spikeThresholdMs = 33.3 -- ~30 FPS frame
local targetBudgetMs = 16.67 -- ~60 FPS default target
local enabled = true

function FS25E_PerformanceMonitor.init(targetFps)
    samples = {}
    sampleCount = 0
    writeIndex = 0
    sumMs = 0
    sumSqMs = 0
    lastDtMs = 0
    if targetFps ~= nil and targetFps > 0 then
        targetBudgetMs = 1000.0 / targetFps
    end
    FS25E_Debug.info("PerformanceMonitor", string.format("init targetBudgetMs=%.2f", targetBudgetMs))
end

function FS25E_PerformanceMonitor.setEnabled(value)
    enabled = value == true
end

function FS25E_PerformanceMonitor.setTargetFps(fps)
    if fps ~= nil and fps > 0 then
        targetBudgetMs = 1000.0 / fps
    end
end

--- Feed mission update(dt): usually already ms. Use dtToMs (convert only if dt < 1).
function FS25E_PerformanceMonitor.update(dt)
    if not enabled or dt == nil then
        return
    end
    local dtMs = FS25E_Debug ~= nil and FS25E_Debug.dtToMs(dt) or (dt < 1 and dt * 1000.0 or dt)
    lastDtMs = dtMs

    if sampleCount < WINDOW then
        sampleCount = sampleCount + 1
        writeIndex = sampleCount
        samples[writeIndex] = dtMs
        sumMs = sumMs + dtMs
        sumSqMs = sumSqMs + dtMs * dtMs
    else
        writeIndex = writeIndex % WINDOW + 1
        local old = samples[writeIndex] or 0
        samples[writeIndex] = dtMs
        sumMs = sumMs - old + dtMs
        sumSqMs = sumSqMs - old * old + dtMs * dtMs
    end
end

function FS25E_PerformanceMonitor.getLastFrameMs()
    return lastDtMs
end

function FS25E_PerformanceMonitor.getAverageMs()
    if sampleCount <= 0 then
        return 0
    end
    return sumMs / sampleCount
end

function FS25E_PerformanceMonitor.getVariance()
    if sampleCount <= 1 then
        return 0
    end
    local mean = sumMs / sampleCount
    local var = (sumSqMs / sampleCount) - (mean * mean)
    if var < 0 then
        return 0
    end
    return var
end

function FS25E_PerformanceMonitor.isSpike()
    return lastDtMs > spikeThresholdMs
end

function FS25E_PerformanceMonitor.isOverBudget()
    return FS25E_PerformanceMonitor.getAverageMs() > targetBudgetMs
end

function FS25E_PerformanceMonitor.getTargetBudgetMs()
    return targetBudgetMs
end

function FS25E_PerformanceMonitor.getSampleCount()
    return sampleCount
end

function FS25E_PerformanceMonitor.reset()
    samples = {}
    sampleCount = 0
    writeIndex = 0
    sumMs = 0
    sumSqMs = 0
    lastDtMs = 0
end


--- HUD/Telemetry feed: FPS + frametime from dt only (no fake sensors).
function FS25E_PerformanceMonitor.getSnapshot()
    local avg = FS25E_PerformanceMonitor.getAverageMs()
    local last = FS25E_PerformanceMonitor.getLastFrameMs()
    local fpsAvg = nil
    local fpsLast = nil
    if avg ~= nil and avg > 0 then
        fpsAvg = 1000.0 / avg
    end
    if last ~= nil and last > 0 then
        fpsLast = 1000.0 / last
    end
    return {
        source = "dt",
        status = "CONFIRMED",
        frameMsLast = last,
        frameMsAvg = avg,
        fpsLast = fpsLast,
        fpsAvg = fpsAvg,
        variance = FS25E_PerformanceMonitor.getVariance(),
        overBudget = FS25E_PerformanceMonitor.isOverBudget(),
        spike = FS25E_PerformanceMonitor.isSpike(),
        targetBudgetMs = FS25E_PerformanceMonitor.getTargetBudgetMs(),
        samples = FS25E_PerformanceMonitor.getSampleCount(),
    }
end
