-- FS25_Enhanced / Core/RestoreManager.lua
-- Restore settings/cache + Wave-1 capability applies. Hook uninstall only on unload.
-- Session-only: never calls saveHardwareScalability / applyPerformanceClass.

FS25E_RestoreManager = {}

local restoredOnce = false
local registeredKeys = {} -- set of capability cache keys pending restore bookkeeping

function FS25E_RestoreManager.registerCapabilityRestore(key)
    if key == nil or key == "" then
        return
    end
    registeredKeys[key] = true
end

function FS25E_RestoreManager.clearRegistered()
    registeredKeys = {}
end

--- Restore vanilla settings state via managers + CapabilityApplier + SettingsCache.
--- Does NOT uninstall mission hooks — those must survive savegame reload in the same session.
--- Does NOT call saveHardwareScalability (no hardware profile write without user opt-in).
function FS25E_RestoreManager.restoreAll()
    FS25E_Debug.info("RestoreManager", "restoreAll begin (session restore; no saveHardwareScalability)")

    FS25E_Debug.pcall("RestoreManager", "ShadowManager.restoreAll", function()
        if FS25E_ShadowManager ~= nil and FS25E_ShadowManager.restoreAll ~= nil then
            FS25E_ShadowManager.restoreAll()
        end
    end)

    -- Expert caps restore via CapabilityApplier (shadow-focus-box → setShadowFocusBox(0))

    FS25E_Debug.pcall("RestoreManager", "LodGovernor.restoreAll", function()
        if FS25E_LodGovernor ~= nil and FS25E_LodGovernor.restoreAll ~= nil then
            FS25E_LodGovernor.restoreAll()
        end
    end)

    FS25E_Debug.pcall("RestoreManager", "CapabilityApplier.restoreAll", function()
        if FS25E_CapabilityApplier ~= nil and FS25E_CapabilityApplier.restoreAll ~= nil then
            FS25E_CapabilityApplier.restoreAll()
        end
    end)

    local ok1 = FS25E_Debug.pcall("RestoreManager", "SettingsCache.restoreToOriginal", function()
        if FS25E_SettingsCache ~= nil then
            FS25E_SettingsCache.restoreToOriginal()
        end
    end)

    registeredKeys = {}
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
    registeredKeys = {}
end
