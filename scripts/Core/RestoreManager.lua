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
    local function restore(module,label)
        if not module or type(module.restoreAll)~='function' then return true end
        local ok,result=FS25E_Debug.pcall('RestoreManager',label,module.restoreAll)
        return ok and result~=false
    end
    local success=restore(FS25E_ShadowManager,'ShadowManager.restoreAll')
    success=restore(FS25E_ModuleRuntime,'ModuleRuntime.restoreAll') and success
    success=restore(FS25E_LodGovernor,'LodGovernor.restoreAll') and success
    success=restore(FS25E_CapabilityApplier,'CapabilityApplier.restoreAll') and success
    if success then
        -- The native applier already updated readback caches, including newer
        -- external baselines. Never replace those with older cached originals.
        if FS25E_SettingsCache then FS25E_SettingsCache.restoreToOriginal(true) end
        registeredKeys={}
    end
    restoredOnce=success
    FS25E_Debug.info('RestoreManager','restoreAll success='..tostring(success)..'; failed native records remain pending')
    return success
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
