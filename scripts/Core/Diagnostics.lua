-- FS25_Enhanced / Core/Diagnostics.lua
-- Read-only capability status snapshot for Settings GUI Status tab.
-- No setters. Falls back to CapabilityRegistry when apply history missing.

FS25E_Diagnostics = {}

local LAST_RESULT = {
    APPLIED = "APPLIED",
    REJECTED = "REJECTED",
    SKIPPED = "SKIPPED",
}

local history = {} -- id -> { lastResult, lastError, updatedAt }

function FS25E_Diagnostics.init()
    history = {}
    FS25E_Debug.info("Diagnostics", "init (read-only snapshot for GUI Status)")
end

function FS25E_Diagnostics.reset()
    history = {}
end

function FS25E_Diagnostics.record(id, lastResult, lastError)
    if id == nil or id == "" then
        return
    end
    local r = tostring(lastResult or LAST_RESULT.SKIPPED):upper()
    if r ~= LAST_RESULT.APPLIED and r ~= LAST_RESULT.REJECTED and r ~= LAST_RESULT.SKIPPED then
        r = LAST_RESULT.SKIPPED
    end
    history[id] = {
        lastResult = r,
        lastError = lastError,
        updatedAt = (g_currentMission ~= nil and g_currentMission.time) or 0,
    }
end

local function inferLastResult(entry)
    if entry == nil then
        return LAST_RESULT.SKIPPED, nil
    end
    local h = history[entry.id]
    if h ~= nil then
        return h.lastResult, h.lastError
    end
    local s = tostring(entry.status or ""):upper()
    if s == "REJECTED" or s == "UNSUPPORTED" then
        return LAST_RESULT.REJECTED, entry.notes
    end
    if s == "CONFIRMED" or s == "GATED" or s == "EXPERIMENTAL" or s == "ASSET_DEPENDENT" then
        return LAST_RESULT.SKIPPED, nil
    end
    return LAST_RESULT.SKIPPED, entry.notes
end

--- Snapshot rows: { id, status, lastResult, lastError [, apiName, notes] }
function FS25E_Diagnostics.getSnapshot()
    local rows = {}
    if FS25E_CapabilityRegistry == nil or FS25E_CapabilityRegistry.all == nil then
        return rows
    end
    local all = FS25E_CapabilityRegistry.all()
    for id, entry in pairs(all) do
        local lastResult, lastError = inferLastResult(entry)
        rows[#rows + 1] = {
            id = id,
            status = entry.status,
            lastResult = lastResult,
            lastError = lastError,
            apiName = entry.apiName,
            notes = entry.notes,
        }
    end
    table.sort(rows, function(a, b)
        return tostring(a.id) < tostring(b.id)
    end)
    return rows
end

function FS25E_Diagnostics.LAST_RESULT()
    return LAST_RESULT
end
