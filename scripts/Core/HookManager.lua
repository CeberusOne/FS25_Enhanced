-- FS25_Enhanced / Core/HookManager.lua
-- Register/unregister Utils.*Function hooks; uninstallAll restores vanilla chains.

FS25E_HookManager = {}

local hooks = {} -- { { target=table, key=string, original=function, kind=string } }

local VALID_KINDS = {
    prepended = true,
    appended = true,
    overwritten = true,
}

--- Register a Utils hook. kind = "prepended" | "appended" | "overwritten"
--- Always uses Utils.prependedFunction / appendedFunction / overwrittenFunction (never raw assignment).
function FS25E_HookManager.register(target, key, kind, wrapper)
    if target == nil or key == nil or wrapper == nil then
        FS25E_Debug.warning("HookManager", "register: missing target/key/wrapper")
        return false
    end
    if not VALID_KINDS[kind] then
        FS25E_Debug.warning("HookManager", "register: invalid kind " .. tostring(kind))
        return false
    end
    if Utils == nil then
        FS25E_Debug.warning("HookManager", "Utils not available")
        return false
    end

    local original = target[key]
    if original == nil then
        FS25E_Debug.warning("HookManager", string.format("target.%s is nil; skip hook", tostring(key)))
        return false
    end

    local ok, err = pcall(function()
        if kind == "prepended" then
            target[key] = Utils.prependedFunction(original, wrapper)
        elseif kind == "appended" then
            target[key] = Utils.appendedFunction(original, wrapper)
        else
            target[key] = Utils.overwrittenFunction(original, wrapper)
        end
    end)

    if not ok then
        FS25E_Debug.warning("HookManager", "register failed: " .. tostring(err))
        return false
    end

    table.insert(hooks, {
        target = target,
        key = key,
        original = original,
        kind = kind,
    })
    FS25E_Debug.info("HookManager", string.format("registered %s on %s", kind, tostring(key)))
    return true
end

--- Restore a single registered hook entry by index (internal).
local function restoreOne(entry)
    if entry == nil or entry.target == nil or entry.key == nil then
        return
    end
    -- Best-effort: replace with captured original. Note: if other mods chained after us,
    -- full chain restoration is imperfect; we still unregister our bookkeeping.
    if entry.original ~= nil then
        entry.target[entry.key] = entry.original
    end
end

--- Uninstall all hooks registered by this mod (LIFO).
function FS25E_HookManager.uninstallAll()
    for i = #hooks, 1, -1 do
        local ok, err = pcall(restoreOne, hooks[i])
        if not ok then
            FS25E_Debug.warning("HookManager", "uninstall entry failed: " .. tostring(err))
        end
        hooks[i] = nil
    end
    hooks = {}
    FS25E_Debug.info("HookManager", "uninstallAll complete")
end

function FS25E_HookManager.count()
    return #hooks
end
