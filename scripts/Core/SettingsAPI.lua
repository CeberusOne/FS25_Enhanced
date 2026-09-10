-- FS25_Enhanced / Core/SettingsAPI.lua
-- Facade for GUI / Experimental / Diagnostics. No direct engine setters.

FS25E_SettingsAPI = {}

function FS25E_SettingsAPI.get(id)
    if FS25E_ModSettings ~= nil then
        return FS25E_ModSettings.get(id)
    end
    return nil
end

function FS25E_SettingsAPI.set(id, value)
    if FS25E_ModSettings == nil then
        return false
    end
    local ok = FS25E_ModSettings.set(id, value)
    if not ok then
        return false
    end
    local key = id
    if key == "governorEnabled" then key = "enabled" end
    if key == "activePreset" then key = "preset" end

    if key == "enabled" and FS25E_GraphicsGovernor ~= nil then
        FS25E_GraphicsGovernor.setEnabled(value == true)
    elseif key == "autoApply" and FS25E_GraphicsGovernor ~= nil then
        FS25E_GraphicsGovernor.setAutoApply(value == true)
    elseif key == "expertMode" and FS25E_CapabilityRegistry ~= nil then
        FS25E_CapabilityRegistry.setExpertMode(value == true)
    elseif key == "softApply" and FS25E_LightDiscovery ~= nil and FS25E_LightDiscovery.setSoftApplyEnabled ~= nil then
        FS25E_LightDiscovery.setSoftApplyEnabled(value == true)
    elseif key == "preset" and FS25E_ProfileManager ~= nil then
        FS25E_ProfileManager.selectPreset(tostring(value))
    end
    return true
end

function FS25E_SettingsAPI.getAll()
    if FS25E_ModSettings ~= nil then return FS25E_ModSettings.getAll() end
    return {}
end

function FS25E_SettingsAPI.getDefaults()
    if FS25E_ModSettings ~= nil then return FS25E_ModSettings.getDefaults() end
    return {}
end

function FS25E_SettingsAPI.load()
    if FS25E_ModSettings ~= nil then return FS25E_ModSettings.load() end
    return false
end

function FS25E_SettingsAPI.save()
    if FS25E_ModSettings ~= nil then return FS25E_ModSettings.save() end
    return false
end

function FS25E_SettingsAPI.selectPreset(name)
    if FS25E_ProfileManager == nil then return false end
    local ok = FS25E_ProfileManager.selectPreset(name)
    if FS25E_ModSettings ~= nil then FS25E_ModSettings.set("preset", name) end
    return ok
end

function FS25E_SettingsAPI.applySelectedPreset()
    if FS25E_ProfileManager ~= nil and FS25E_ProfileManager.applySelected ~= nil then
        return FS25E_ProfileManager.applySelected()
    end
    return false, "applySelected missing"
end

function FS25E_SettingsAPI.setEnabled(v)
    return FS25E_SettingsAPI.set("enabled", v == true)
end

function FS25E_SettingsAPI.getEnabled()
    return FS25E_SettingsAPI.get("enabled") == true
end

function FS25E_SettingsAPI.setAutoApply(v)
    return FS25E_SettingsAPI.set("autoApply", v == true)
end

function FS25E_SettingsAPI.getAutoApply()
    return FS25E_SettingsAPI.get("autoApply") == true
end

function FS25E_SettingsAPI.setExpertMode(v)
    return FS25E_SettingsAPI.set("expertMode", v == true)
end

function FS25E_SettingsAPI.getExpertMode()
    return FS25E_SettingsAPI.get("expertMode") == true
end

function FS25E_SettingsAPI.getActivePreset()
    return FS25E_SettingsAPI.get("preset")
end

function FS25E_SettingsAPI.listPresets()
    if FS25E_ProfileManager ~= nil and FS25E_ProfileManager.listNames ~= nil then
        return FS25E_ProfileManager.listNames()
    end
    return { "Performance", "Balanced", "Quality", "Cinematic" }
end
