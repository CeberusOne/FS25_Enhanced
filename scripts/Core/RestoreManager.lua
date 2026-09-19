-- Restore every owned graphics write. Session-only: never saveHardwareScalability.
FS25E_RestoreManager = {}

local restoredOnce = false
local registeredKeys = {}

function FS25E_RestoreManager.registerCapabilityRestore(key)
    if key == nil or key == "" then return end
    registeredKeys[key] = true
end

function FS25E_RestoreManager.clearRegistered()
    registeredKeys = {}
end

function FS25E_RestoreManager.restoreAll()
    local function restore(module, label)
        if not module or type(module.restoreAll) ~= 'function' then return true end
        local ok, result = FS25E_Debug.pcall('RestoreManager', label, module.restoreAll)
        return ok and result ~= false
    end
    local success = restore(FS25E_ModuleRuntime, 'ModuleRuntime.restoreAll')
    success = restore(FS25E_GameSettingsControls, 'GameSettingsControls.restoreAll') and success
    success = restore(FS25E_CapabilityApplier, 'CapabilityApplier.restoreAll') and success
    if success then
        if FS25E_SettingsCache then FS25E_SettingsCache.restoreToOriginal(true) end
        registeredKeys = {}
    end
    restoredOnce = success
    FS25E_Debug.info('RestoreManager', 'restoreAll success=' .. tostring(success))
    return success
end

function FS25E_RestoreManager.unload()
    FS25E_RestoreManager.restoreAll()
    FS25E_Debug.pcall("RestoreManager", "HookManager.uninstallAll", function()
        if FS25E_HookManager ~= nil then FS25E_HookManager.uninstallAll() end
    end)
end

function FS25E_RestoreManager.wasRestored() return restoredOnce end
function FS25E_RestoreManager.resetFlag() restoredOnce = false; registeredKeys = {} end
