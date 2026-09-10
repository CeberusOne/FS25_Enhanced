-- FS25_Enhanced / Core/Diagnostics.lua
-- Runtime capability apply/reject/restore diagnostics. Read-only for GUI; never enables autoApply.

FS25E_Diagnostics = {}

FS25E_Diagnostics.RESULT = {
    APPLIED = "APPLIED",
    REJECTED = "REJECTED",
    SKIPPED = "SKIPPED",
}

local DEFAULT_RING_SIZE = 64
local ringSize = DEFAULT_RING_SIZE
local ring = {}
local writeIndex = 0
local ringCount = 0
local runtime = {} -- id -> { lastResult, lastError, lastAt, applyMode, source }
local hooksInstalled = false
local listenersInstalled = false
local fileWriteWarned = false

local function nowStamp()
    if type(g_time) == "number" then
        return string.format("g_time=%.0f", g_time)
    end
    if type(getTime) == "function" then
        local ok, t = pcall(getTime)
        if ok and t ~= nil then
            return string.format("getTime=%s", tostring(t))
        end
    end
    if type(os) == "table" and type(os.time) == "function" then
        return string.format("os=%d", os.time())
    end
    return "t=?"
end

local function pushRing(entry)
    writeIndex = writeIndex + 1
    if writeIndex > ringSize then
        writeIndex = 1
    end
    ring[writeIndex] = entry
    if ringCount < ringSize then
        ringCount = ringCount + 1
    end
end

function FS25E_Diagnostics.appendFile(line)
    if line == nil then
        return false
    end
    local ok = pcall(function()
        if FS25E_ModSettings == nil or FS25E_ModSettings.isReady == nil or not FS25E_ModSettings.isReady() then
            return
        end
        if FS25E_ModSettings.getFilePath == nil then
            return
        end
        local path = FS25E_ModSettings.getFilePath("diagnostics.log")
        if path == nil or path == "" then
            return
        end
        local f = io.open(path, "a")
        if f == nil then
            return
        end
        f:write(tostring(line))
        if not tostring(line):match("\n$") then
            f:write("\n")
        end
        f:close()
    end)
    if not ok and not fileWriteWarned and FS25E_Debug ~= nil then
        fileWriteWarned = true
        FS25E_Debug.warning("Diagnostics", "diagnostics.log append soft-failed (IO unavailable)")
    end
    return ok
end

--- record(capabilityId, result, err, meta)
--- result: APPLIED|REJECTED|SKIPPED; meta optional { applyMode, source, kind, detail }
function FS25E_Diagnostics.record(capabilityId, result, err, meta)
    if capabilityId == nil or capabilityId == "" then
        return
    end
    meta = meta or {}
    local id = tostring(capabilityId)
    local stamp = nowStamp()
    local applyMode = meta.applyMode
    if applyMode == nil and FS25E_CapabilityRegistry ~= nil then
        local cap = FS25E_CapabilityRegistry.get(id)
        if cap ~= nil then
            applyMode = cap.applyMode
        end
    end
    runtime[id] = {
        lastResult = result,
        lastError = err ~= nil and tostring(err) or nil,
        lastAt = stamp,
        applyMode = applyMode,
        source = meta.source,
    }
    local kind = meta.kind
    if kind == nil then
        if result == FS25E_Diagnostics.RESULT.APPLIED then
            kind = "apply"
        elseif result == FS25E_Diagnostics.RESULT.REJECTED then
            kind = "reject"
        elseif result == FS25E_Diagnostics.RESULT.SKIPPED then
            kind = "skip"
        else
            kind = "apply"
        end
    end
    local entry = {
        t = stamp,
        kind = kind,
        capabilityId = id,
        result = result,
        error = err ~= nil and tostring(err) or nil,
        detail = meta.detail,
        applyMode = applyMode,
    }
    pushRing(entry)
    local line = string.format(
        "%s kind=%s id=%s result=%s err=%s detail=%s",
        stamp, tostring(kind), id, tostring(result), tostring(err or ""), tostring(meta.detail or "")
    )
    FS25E_Diagnostics.appendFile(line)
end

function FS25E_Diagnostics.getCapRuntime(id)
    return runtime[tostring(id or "")]
end

function FS25E_Diagnostics.getAllRuntime()
    return runtime
end

function FS25E_Diagnostics.getRing()
    local out = {}
    if ringCount == 0 then
        return out
    end
    local start = writeIndex - ringCount + 1
    if start < 1 then
        start = start + ringSize
    end
    for i = 0, ringCount - 1 do
        local idx = start + i
        if idx > ringSize then
            idx = idx - ringSize
        end
        out[#out + 1] = ring[idx]
    end
    return out
end

function FS25E_Diagnostics.getSnapshot()
    local caps = {}
    local countsByStatus = {}
    local countsByLastResult = {}
    local recentErrors = {}
    local all = {}
    if FS25E_CapabilityRegistry ~= nil and FS25E_CapabilityRegistry.all ~= nil then
        all = FS25E_CapabilityRegistry.all() or {}
    end
    for id, entry in pairs(all) do
        local status = entry.status or "UNSUPPORTED"
        countsByStatus[status] = (countsByStatus[status] or 0) + 1
        local rt = runtime[id]
        local lastResult = rt and rt.lastResult or nil
        -- Fallback: session applied table implies APPLIED if no runtime yet
        if lastResult == nil and FS25E_CapabilityApplier ~= nil and FS25E_CapabilityApplier.getApplied ~= nil then
            local applied = FS25E_CapabilityApplier.getApplied()
            if applied ~= nil then
                for key, a in pairs(applied) do
                    if a ~= nil and tostring(a.capabilityId) == tostring(id) then
                        lastResult = FS25E_Diagnostics.RESULT.APPLIED
                        break
                    end
                    if tostring(key) == tostring(id) or tostring(key):match("^" .. tostring(id) .. "|") then
                        lastResult = FS25E_Diagnostics.RESULT.APPLIED
                        break
                    end
                end
            end
        end
        if lastResult ~= nil then
            countsByLastResult[lastResult] = (countsByLastResult[lastResult] or 0) + 1
        end
        local lastError = rt and rt.lastError or nil
        if entry.status == "REJECTED" and (lastError == nil or lastError == "") and entry.notes ~= nil then
            lastError = tostring(entry.notes)
        end
        caps[#caps + 1] = {
            id = id,
            status = status,
            lastResult = lastResult,
            lastError = lastError,
            applyMode = (rt and rt.applyMode) or entry.applyMode,
        }
    end
    table.sort(caps, function(a, b)
        return tostring(a.id) < tostring(b.id)
    end)
    local ringEntries = FS25E_Diagnostics.getRing()
    for i = #ringEntries, 1, -1 do
        local e = ringEntries[i]
        if e ~= nil and e.error ~= nil and e.error ~= "" then
            recentErrors[#recentErrors + 1] = {
                capabilityId = e.capabilityId,
                error = e.error,
                t = e.t,
                result = e.result,
            }
            if #recentErrors >= 20 then
                break
            end
        end
    end
    return {
        version = (FS25_Enhanced ~= nil and FS25_Enhanced.VERSION) or nil,
        capCount = #caps,
        countsByStatus = countsByStatus,
        countsByLastResult = countsByLastResult,
        caps = caps,
        recentErrors = recentErrors,
    }
end

function FS25E_Diagnostics.dumpCapStatus(sayFn)
    local say = sayFn or function(msg)
        if FS25E_Debug ~= nil then
            FS25E_Debug.info("Diagnostics", tostring(msg))
        end
        if print ~= nil then
            print("[FS25_Enhanced] " .. tostring(msg))
        end
    end
    local snap = FS25E_Diagnostics.getSnapshot()
    say(string.format("capStatus count=%d", snap.capCount or 0))
    for status, n in pairs(snap.countsByStatus or {}) do
        say(string.format("statusCount %s=%d", tostring(status), n))
    end
    for result, n in pairs(snap.countsByLastResult or {}) do
        say(string.format("lastResultCount %s=%d", tostring(result), n))
    end
    for i = 1, #(snap.caps or {}) do
        local c = snap.caps[i]
        say(string.format(
            "cap id=%s status=%s lastResult=%s lastError=%s applyMode=%s",
            tostring(c.id),
            tostring(c.status),
            tostring(c.lastResult or "-"),
            tostring(c.lastError or ""),
            tostring(c.applyMode or "-")
        ))
    end
    say(string.format("capStatus done errors=%d", #(snap.recentErrors or {})))
end

function FS25E_Diagnostics.dumpRing(sayFn)
    local say = sayFn or function(msg)
        if print ~= nil then
            print("[FS25_Enhanced] " .. tostring(msg))
        end
    end
    local entries = FS25E_Diagnostics.getRing()
    say(string.format("diagLog count=%d", #entries))
    for i = 1, #entries do
        local e = entries[i]
        say(string.format(
            "diag %s kind=%s id=%s result=%s err=%s",
            tostring(e.t), tostring(e.kind), tostring(e.capabilityId), tostring(e.result), tostring(e.error or "")
        ))
    end
    say("diagLog done")
end

function FS25E_Diagnostics.init()
    runtime = {}
    ring = {}
    writeIndex = 0
    ringCount = 0
    fileWriteWarned = false
    if FS25E_Debug ~= nil then
        FS25E_Debug.info("Diagnostics", string.format("init ringSize=%d", ringSize))
    end
end

function FS25E_Diagnostics.reset()
    FS25E_Diagnostics.init()
    -- keep hooksInstalled; re-wrapping would nest
end

local function wrapOnce(tbl, fnName, wrapperFactory)
    if tbl == nil or type(tbl[fnName]) ~= "function" then
        return false
    end
    if tbl["_fs25eDiagWrapped_" .. fnName] then
        return true
    end
    local original = tbl[fnName]
    tbl[fnName] = wrapperFactory(original)
    tbl["_fs25eDiagWrapped_" .. fnName] = true
    return true
end

--- Soft-subscribe Core listener APIs when present (future Settings-API PR).
function FS25E_Diagnostics.trySubscribeListeners()
    if listenersInstalled or FS25E_CapabilityRegistry == nil then
        return listenersInstalled
    end
    local n = 0
    if type(FS25E_CapabilityRegistry.onApply) == "function" then
        pcall(function()
            FS25E_CapabilityRegistry.onApply(function(id, detail)
                FS25E_Diagnostics.record(id, FS25E_Diagnostics.RESULT.APPLIED, nil, { source = "listener", detail = detail })
            end)
            n = n + 1
        end)
    end
    if type(FS25E_CapabilityRegistry.onReject) == "function" then
        pcall(function()
            FS25E_CapabilityRegistry.onReject(function(id, reason)
                FS25E_Diagnostics.record(id, FS25E_Diagnostics.RESULT.REJECTED, reason, { source = "listener" })
            end)
            n = n + 1
        end)
    end
    if type(FS25E_CapabilityRegistry.onSkip) == "function" then
        pcall(function()
            FS25E_CapabilityRegistry.onSkip(function(id, reason)
                FS25E_Diagnostics.record(id, FS25E_Diagnostics.RESULT.SKIPPED, reason, { source = "listener" })
            end)
            n = n + 1
        end)
    end
    if n > 0 then
        listenersInstalled = true
        if FS25E_Debug ~= nil then
            FS25E_Debug.info("Diagnostics", string.format("subscribed %d Core listeners", n))
        end
    end
    return listenersInstalled
end

function FS25E_Diagnostics.installHooks()
    if hooksInstalled then
        FS25E_Diagnostics.trySubscribeListeners()
        return true
    end
    local n = 0
    if wrapOnce(FS25E_CapabilityApplier, "apply", function(original)
        return function(capabilityId, opts)
            local ok, err = original(capabilityId, opts)
            if ok then
                FS25E_Diagnostics.record(capabilityId, FS25E_Diagnostics.RESULT.APPLIED, nil, { source = "applier" })
            else
                FS25E_Diagnostics.record(capabilityId, FS25E_Diagnostics.RESULT.REJECTED, err, { source = "applier" })
            end
            return ok, err
        end
    end) then n = n + 1 end

    if wrapOnce(FS25E_CapabilityRegistry, "reject", function(original)
        return function(id, reason)
            original(id, reason)
            FS25E_Diagnostics.record(id, FS25E_Diagnostics.RESULT.REJECTED, reason, { source = "registry.reject" })
        end
    end) then n = n + 1 end

    if wrapOnce(FS25E_CapabilityApplier, "restoreOne", function(original)
        return function(key)
            local ok = original(key)
            FS25E_Diagnostics.record(tostring(key), ok and FS25E_Diagnostics.RESULT.APPLIED or FS25E_Diagnostics.RESULT.REJECTED, ok and nil or "restoreOne failed", { kind = "restore", source = "applier.restoreOne", detail = tostring(key) })
            return ok
        end
    end) then n = n + 1 end

    if wrapOnce(FS25E_CapabilityApplier, "restoreAll", function(original)
        return function()
            FS25E_Diagnostics.record("*", FS25E_Diagnostics.RESULT.APPLIED, nil, { kind = "restore", source = "applier.restoreAll", detail = "begin" })
            original()
            FS25E_Diagnostics.record("*", FS25E_Diagnostics.RESULT.APPLIED, nil, { kind = "restore", source = "applier.restoreAll", detail = "done" })
        end
    end) then n = n + 1 end

    if wrapOnce(FS25E_RestoreManager, "restoreAll", function(original)
        return function()
            FS25E_Diagnostics.record("*", FS25E_Diagnostics.RESULT.APPLIED, nil, { kind = "restore", source = "RestoreManager.restoreAll", detail = "begin" })
            original()
            FS25E_Diagnostics.record("*", FS25E_Diagnostics.RESULT.APPLIED, nil, { kind = "restore", source = "RestoreManager.restoreAll", detail = "done" })
        end
    end) then n = n + 1 end

    hooksInstalled = true
    if FS25E_Debug ~= nil then
        FS25E_Debug.info("Diagnostics", string.format("hooks installed count=%d", n))
    end
    FS25E_Diagnostics.trySubscribeListeners()
    return true
end
