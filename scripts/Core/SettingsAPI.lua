-- FS25_Enhanced / Core/SettingsAPI.lua
-- Facade for GUI / Experimental / Diagnostics. No direct engine setters here.

FS25E_SettingsAPI = {}

function FS25E_SettingsAPI.get(key)
    if FS25E_ModSettings == nil then return nil end
    return FS25E_ModSettings.get(key)
end

function FS25E_SettingsAPI.set(key, value)
    if FS25E_ModSettings == nil then return false end
    local ok = FS25E_ModSettings.set(key, value)
    if not ok then return false end
    -- live-apply toggles
    if key == "governorEnabled" and FS25E_GraphicsGovernor ~= nil then
        FS25E_GraphicsGovernor.setEnabled(value == true)
    elseif key == "autoApply" and FS25E_GraphicsGovernor ~= nil then
        FS25E_GraphicsGovernor.setAutoApply(value == true)
    elseif key == "expertMode" and FS25E_CapabilityRegistry ~= nil then
        FS25E_CapabilityRegistry.setExpertMode(value == true)
    elseif key == "softApply" and FS25E_LightDiscovery ~= nil and FS25E_LightDiscovery.setSoftApplyEnabled ~= nil then
        FS25E_LightDiscovery.setSoftApplyEnabled(value == true)
    elseif key == "activePreset" and FS25E_ProfileManager ~= nil then
        FS25E_ProfileManager.selectPreset(tostring(value))
    end
    return true
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
    return FS25E_ProfileManager.selectPreset(name)
end

function FS25E_SettingsAPI.applySelectedPreset()
    if FS25E_ProfileManager ~= nil and FS25E_ProfileManager.applySelected ~= nil then
        return FS25E_ProfileManager.applySelected()
    end
    return false, "applySelected missing"
end

function FS25E_SettingsAPI.setEnabled(v)
    if FS25E_GraphicsGovernor == nil then return end
    FS25E_GraphicsGovernor.setEnabled(v == true)
    if FS25E_ModSettings ~= nil then FS25E_ModSettings.set("governorEnabled", v == true) end
end

function FS25E_SettingsAPI.getEnabled()
    if FS25E_GraphicsGovernor == nil then return false end
    return FS25E_GraphicsGovernor.isEnabled() == true
end

function FS25E_SettingsAPI.setAutoApply(v)
    if FS25E_GraphicsGovernor == nil then return end
    FS25E_GraphicsGovernor.setAutoApply(v == true)
    if FS25E_ModSettings ~= nil then FS25E_ModSettings.set("autoApply", v == true) end
end

function FS25E_SettingsAPI.getAutoApply()
    if FS25E_GraphicsGovernor == nil then return false end
    return FS25E_GraphicsGovernor.isAutoApply() == true
end

function FS25E_SettingsAPI.setExpertMode(v)
    if FS25E_CapabilityRegistry ~= nil then
        FS25E_CapabilityRegistry.setExpertMode(v == true)
    end
    if FS25E_ModSettings ~= nil then FS25E_ModSettings.set("expertMode", v == true) end
end

function FS25E_SettingsAPI.getExpertMode()
    if FS25E_CapabilityRegistry ~= nil and FS25E_CapabilityRegistry.isExpertMode ~= nil then
        return FS25E_CapabilityRegistry.isExpertMode() == true
    end
    return false
end

function FS25E_SettingsAPI.getActivePreset()
    if FS25E_ProfileManager ~= nil and FS25E_ProfileManager.getActiveName ~= nil then
        return FS25E_ProfileManager.getActiveName()
    end
    return FS25E_SettingsAPI.get("activePreset")
end

function FS25E_SettingsAPI.listPresets()
    if FS25E_ProfileManager ~= nil and FS25E_ProfileManager.listNames ~= nil then
        return FS25E_ProfileManager.listNames()
    end
    return { "Performance", "Balanced", "Quality", "Cinematic" }
end
