-- FS25_Enhanced / Core/TelemetryReader.lua
-- Optional sidecar telemetry.json under modSettings/FS25_Enhanced/
-- Pure Lua runs without sidecar (connected=false). No fake numbers.
-- Giants sandbox: io.open("r") may sharing-violate or lack f:read — after first fail, readDisabled (no more r polls).

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
local readDisabled = false
local disableLogged = false

local function resolvePath()
    if FS25E_ModSettings ~= nil and FS25E_ModSettings.getFilePath ~= nil then
        return FS25E_ModSettings.getFilePath(FILE_NAME)
    end
    return "modSettings/FS25_Enhanced/" .. FILE_NAME
end

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

local function disableReads(reason)
    readDisabled = true
    connected = false
    lastError = reason
    if not disableLogged then
        disableLogged = true
        if FS25E_Debug ~= nil and FS25E_Debug.warning ~= nil then
            FS25E_Debug.warning("TelemetryReader", "readDisabled: " .. tostring(reason) .. " — no further io.open('r') this session")
        end
    end
end

local function readFile(path)
    if readDisabled then
        return nil, "readDisabled"
    end
    if path == nil then
        disableReads("no path")
        return nil, "no path"
    end
    if io == nil or type(io.open) ~= "function" then
        disableReads("io unavailable")
        return nil, "io unavailable"
    end

    local f, err
    local okOpen, openRes = pcall(function()
        return { io.open(path, "r") }
    end)
    if not okOpen then
        disableReads("io.open pcall failed: " .. tostring(openRes))
        return nil, tostring(openRes)
    end
    f = openRes[1]
    err = openRes[2]
    if f == nil then
        -- Missing file OR sandbox denial. Permanent disable avoids 1Hz sharing-violation spam.
        disableReads(err or "open failed")
        return nil, err or "open failed"
    end

    if type(f.read) ~= "function" then
        pcall(function() f:close() end)
        disableReads("f:read missing")
        return nil, "f:read missing"
    end

    local okRead, content = pcall(function()
        return f:read("*a")
    end)
    pcall(function() f:close() end)
    if not okRead then
        disableReads("read failed: " .. tostring(content))
        return nil, tostring(content)
    end
    if content == nil or content == "" then
        -- Empty / missing body: treat as disconnected but do not keep polling sandbox
        disableReads("empty telemetry file")
        return nil, "empty"
    end
    return content, nil
end

function FS25E_TelemetryReader.init()
    accumMs = 0
    lastRaw = nil
    lastOkAtMs = nil
    connected = false
    lastError = nil
    wallMs = 0
    readDisabled = false
    disableLogged = false
    FS25E_Debug.info("TelemetryReader", "init path=" .. tostring(resolvePath()) .. " (sidecar optional; r-poll stops after first fail)")
end

function FS25E_TelemetryReader.reset()
    FS25E_TelemetryReader.init()
end

function FS25E_TelemetryReader.isReadDisabled()
    return readDisabled == true
end

function FS25E_TelemetryReader.update(dt)
    if dt == nil then return end
    if readDisabled then
        connected = false
        return
    end

    -- Mission dt is usually already ms; dtToMs only converts if dt < 1
    local dtMs = FS25E_Debug ~= nil and FS25E_Debug.dtToMs(dt) or (dt < 1 and dt * 1000.0 or dt)
    wallMs = wallMs + dtMs
    accumMs = accumMs + dtMs
    if accumMs < POLL_INTERVAL_MS then
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
        connected = false
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
    if readDisabled or not connected then return false end
    if lastOkAtMs == nil then return false end
    return (wallMs - lastOkAtMs) <= STALE_MS
end

function FS25E_TelemetryReader.getSnapshot()
    local ok = FS25E_TelemetryReader.isConnected()
    local status = "DISCONNECTED"
    if readDisabled then
        status = "READ_DISABLED"
    elseif ok then
        status = "CONNECTED"
    end
    return {
        connected = ok,
        readDisabled = readDisabled == true,
        staleMs = lastOkAtMs ~= nil and (wallMs - lastOkAtMs) or nil,
        error = lastError,
        path = resolvePath(),
        data = ok and lastRaw or nil,
        status = status,
    }
end
