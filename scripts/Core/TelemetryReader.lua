-- FS25_Enhanced / Core/TelemetryReader.lua
-- Optional sidecar telemetry.json under modSettings/FS25_Enhanced/
-- Pure Lua runs without sidecar (connected=false). No fake numbers.

FS25E_TelemetryReader = {}

local POLL_INTERVAL_MS = 1000
local STALE_MS = 2000
local FILE_NAME = "telemetry.json"

local accumMs = 0
local lastRaw = nil
local lastOkAtMs = nil
local connected = false
local lastError = nil
local wallMs = 0

local function nowMs()
    return wallMs
end

local function resolvePath()
    if FS25E_ModSettings ~= nil and FS25E_ModSettings.getFilePath ~= nil then
        return FS25E_ModSettings.getFilePath(FILE_NAME)
    end
    return "modSettings/FS25_Enhanced/" .. FILE_NAME
end

--- Minimal JSON number/string extractor (no full parser dependency).
local function extractNumber(json, key)
    if json == nil then return nil end
    local pat = '"' .. key .. '"%s*:%s*([%-%d%.]+)'
    local s = string.match(json, pat)
    if s == nil then return nil end
    return tonumber(s)
end

local function extractString(json, key)
    if json == nil then return nil end
    local pat = '"' .. key .. '"%s*:%s*"([^"]*)"'
    return string.match(json, pat)
end

local function readFile(path)
    if path == nil then return nil, "no path" end
    -- Prefer io if available (desktop); soft-fail otherwise
    if io == nil or io.open == nil then
        return nil, "io unavailable"
    end
    local f, err = io.open(path, "r")
    if f == nil then
        return nil, err or "open failed"
    end
    local content = f:read("*a")
    f:close()
    return content, nil
end

function FS25E_TelemetryReader.init()
    accumMs = 0
    lastRaw = nil
    lastOkAtMs = nil
    connected = false
    lastError = nil
    wallMs = 0
    FS25E_Debug.info("TelemetryReader", "init path=" .. tostring(resolvePath()) .. " (sidecar optional)")
end

function FS25E_TelemetryReader.reset()
    FS25E_TelemetryReader.init()
end

function FS25E_TelemetryReader.update(dt)
    if dt == nil then return end
    -- dt usually ms; defensive convert only if dt < 1 (seconds)
    local dtMs = FS25E_Debug ~= nil and FS25E_Debug.dtToMs(dt) or (dt < 1 and dt * 1000.0 or dt)
    wallMs = wallMs + dtMs
    accumMs = accumMs + dtMs
    if accumMs < POLL_INTERVAL_MS then
        -- still evaluate stale
        if lastOkAtMs ~= nil and (wallMs - lastOkAtMs) > STALE_MS then
            connected = false
        end
        return
    end
    accumMs = 0

    local path = resolvePath()
    local content, err = readFile(path)
    if content == nil or content == "" then
        lastError = err or "missing"
        if lastOkAtMs ~= nil and (wallMs - lastOkAtMs) > STALE_MS then
            connected = false
        elseif lastOkAtMs == nil then
            connected = false
        end
        -- Backoff when sidecar missing (avoid 1Hz io.open spam)
        accumMs = -4000
        return
    end

    local ts = extractNumber(content, "timestamp")
    lastRaw = {
        timestamp = ts,
        cpuLoad = extractNumber(content, "cpuLoad"),
        cpuTempC = extractNumber(content, "cpuTempC"),
        gpuLoad = extractNumber(content, "gpuLoad"),
        gpuTempC = extractNumber(content, "gpuTempC"),
        vramUsedMB = extractNumber(content, "vramUsedMB"),
        vramTotalMB = extractNumber(content, "vramTotalMB"),
        ramUsedMB = extractNumber(content, "ramUsedMB"),
        ramTotalMB = extractNumber(content, "ramTotalMB"),
        backend = extractString(content, "backend"),
    }
    lastOkAtMs = wallMs
    connected = true
    lastError = nil
end

function FS25E_TelemetryReader.isConnected()
    if not connected then return false end
    if lastOkAtMs == nil then return false end
    return (wallMs - lastOkAtMs) <= STALE_MS
end

function FS25E_TelemetryReader.getSnapshot()
    local ok = FS25E_TelemetryReader.isConnected()
    return {
        connected = ok,
        staleMs = lastOkAtMs ~= nil and (wallMs - lastOkAtMs) or nil,
        error = lastError,
        path = resolvePath(),
        data = ok and lastRaw or nil,
        status = ok and "CONNECTED" or "DISCONNECTED",
    }
end
