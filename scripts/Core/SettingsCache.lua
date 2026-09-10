-- FS25_Enhanced / Core/SettingsCache.lua
-- original / current / requested / auto / locked structure. Wave 1: cache originals for session apply/restore (no saveHardwareScalability).

FS25E_SettingsCache = {}

local entries = {} -- key -> { original, current, requested, auto, locked, applyMode }

FS25E_SettingsCache.APPLY_MODE = {
    LIVE = "LIVE",
    RESTART = "RESTART",
    SESSION = "SESSION",
}

function FS25E_SettingsCache.reset()
    entries = {}
end

--- Ensure an entry exists with defaults.
function FS25E_SettingsCache.ensure(key, originalValue)
    if entries[key] == nil then
        entries[key] = {
            original = originalValue,
            current = originalValue,
            requested = originalValue,
            auto = true,
            locked = false,
            applyMode = FS25E_SettingsCache.APPLY_MODE.SESSION,
            needsCalibration = true,
            capabilityId = nil,
        }
    end
    return entries[key]
end

function FS25E_SettingsCache.captureOriginal(key, value)
    local e = FS25E_SettingsCache.ensure(key, value)
    if e.original == nil then
        e.original = value
    end
    e.current = value
    return e
end

function FS25E_SettingsCache.setRequested(key, value)
    local e = entries[key]
    if e == nil then
        e = FS25E_SettingsCache.ensure(key, value)
    end
    if e.locked then
        return false
    end
    e.requested = value
    return true
end

function FS25E_SettingsCache.setLocked(key, locked)
    local e = entries[key]
    if e == nil then
        return false
    end
    e.locked = locked == true
    return true
end

function FS25E_SettingsCache.setAuto(key, auto)
    local e = entries[key]
    if e == nil then
        return false
    end
    e.auto = auto == true
    return true
end

function FS25E_SettingsCache.get(key)
    return entries[key]
end

function FS25E_SettingsCache.getOriginal(key)
    local e = entries[key]
    return e and e.original or nil
end

function FS25E_SettingsCache.all()
    return entries
end

--- Mark current = requested for keys that are not locked (still no engine write).
function FS25E_SettingsCache.applyRequestedSoft()
    for _, e in pairs(entries) do
        if not e.locked and e.requested ~= nil then
            e.current = e.requested
        end
    end
end

--- Restore current toward original (cache only; RestoreManager coordinates engine).
function FS25E_SettingsCache.restoreToOriginal()
    for _, e in pairs(entries) do
        e.current = e.original
        e.requested = e.original
    end
end
