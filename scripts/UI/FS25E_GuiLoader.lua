-- FS25_Enhanced / UI/FS25E_GuiLoader.lua
-- Lazy g_gui:loadGui once for FS25E_SettingsDialog.

FS25E_GuiLoader = {}

local loaded = false
local loadFailed = false

function FS25E_GuiLoader.isLoaded()
    return loaded
end

function FS25E_GuiLoader.reset()
    loaded = false
    loadFailed = false
end

function FS25E_GuiLoader.ensureSettingsDialog()
    if loaded then
        return true
    end
    if loadFailed then
        return false
    end
    if g_gui == nil or g_gui.loadGui == nil then
        if FS25E_Debug ~= nil then
            FS25E_Debug.warning("GuiLoader", "g_gui.loadGui unavailable")
        end
        loadFailed = true
        return false
    end
    if FS25E_SettingsDialog == nil or FS25E_SettingsDialog.new == nil then
        if FS25E_Debug ~= nil then
            FS25E_Debug.warning("GuiLoader", "FS25E_SettingsDialog class missing")
        end
        loadFailed = true
        return false
    end

    local modDir = (FS25_Enhanced and FS25_Enhanced.modDirectory) or g_currentModDirectory or ""
    local xmlPath = modDir .. "gui/FS25E_SettingsDialog.xml"
    local ok, err = pcall(function()
        local controller = FS25E_SettingsDialog.new()
        g_gui:loadGui(xmlPath, "FS25E_SettingsDialog", controller)
    end)
    if not ok then
        loadFailed = true
        if FS25E_Debug ~= nil then
            FS25E_Debug.warning("GuiLoader", "loadGui failed: " .. tostring(err))
        end
        return false
    end
    loaded = true
    if FS25E_Debug ~= nil then
        FS25E_Debug.info("GuiLoader", "FS25E_SettingsDialog loaded from " .. tostring(xmlPath))
    end
    return true
end

function FS25E_GuiLoader.showSettingsDialog()
    if not FS25E_GuiLoader.ensureSettingsDialog() then
        return false
    end
    if g_gui == nil then
        return false
    end
    local ok, err = pcall(function()
        if g_gui.showDialog ~= nil then
            g_gui:showDialog("FS25E_SettingsDialog")
        elseif g_gui.showGui ~= nil then
            g_gui:showGui("FS25E_SettingsDialog")
        else
            error("no showDialog/showGui")
        end
    end)
    if not ok then
        if FS25E_Debug ~= nil then
            FS25E_Debug.warning("GuiLoader", "showSettingsDialog failed: " .. tostring(err))
        end
        return false
    end
    return true
end
