-- FS25_Enhanced / Core/RestoreManager.lua
-- Restore settings/cache (+ future engine writers). Hook uninstall is separate (mod unload).
-- Safe no-op when nothing was applied (Phase 1).

FS25E_RestoreManager = {}

local restoredOnce = false

--- Restore vanilla settings state (cache now; engine writers after Research Freeze).
--- Does NOT uninstall mission hooks — those must survive savegame reload in the same session.
function FS25E_RestoreManager.restoreAll()
    FS25E_Debug.info("RestoreManager", "restoreAll begin (safe no-op path for unset capabilities)")

    local ok1 = FS25E_Debug.pcall("RestoreManager", "SettingsCache.restoreToOriginal", function()
        if FS25E_SettingsCache ~= nil then
            FS25E_SettingsCache.restoreToOriginal()
        end
    end)

    -- Future: walk SettingsCache originals and call CONFIRMED getters/setters only.
    -- Explicitly forbidden in Phase 1: setShadow*, setLight*, set*DistanceCoeff, setRain*, quality writers.

    restoredOnce = true
    FS25E_Debug.info("RestoreManager", string.format("restoreAll done (cache=%s)", tostring(ok1)))
end

--- Full unload: restore settings then remove Utils hooks registered by this mod.
function FS25E_RestoreManager.unload()
    FS25E_RestoreManager.restoreAll()
    FS25E_Debug.pcall("RestoreManager", "HookManager.uninstallAll", function()
        if FS25E_HookManager ~= nil then
            FS25E_HookManager.uninstallAll()
        end
    end)
end

function FS25E_RestoreManager.wasRestored()
    return restoredOnce
end

function FS25E_RestoreManager.resetFlag()
    restoredOnce = false
end
