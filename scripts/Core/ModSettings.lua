-- FS25_Enhanced / Core/ModSettings.lua
-- Client persistence under modSettings/FS25_Enhanced/settings.xml
-- Defaults: enabled/autoApply/softApply/expertMode/adaptive = false

FS25E_ModSettings = {}

local MOD_SETTINGS_FOLDER = "FS25_Enhanced"
local FILE_NAME = "settings.xml"

local relativePath = nil
local absolutePath = nil
local ready = false

local values = {
    governorEnabled = false,
    autoApply = false,
    softApply = false,
    expertMode = false,
    adaptive = false,
    activePreset = "Balanced",
    targetFps = 60,
}

local function defaults()
    return {
        governorEnabled = false,
        autoApply = false,
        softApply = false,
        expertMode = false,
        adaptive = false,
        activePreset = "Balanced",
        targetFps = 60,
    }
end

local function copyInto(dst, src)
    for k, v in pairs(src) do
        dst[k] = v
    end
end

function FS25E_ModSettings.init()
    ready = false
    relativePath = "modSettings/" .. MOD_SETTINGS_FOLDER .. "/"
    absolutePath = nil
    copyInto(values, defaults())

    local ok, err = pcall(function()
        if getUserProfileAppPath ~= nil then
            local base = getUserProfileAppPath()
            if base ~= nil and base ~= "" then
                absolutePath = base .. "modSettings/" .. MOD_SETTINGS_FOLDER .. "/"
            end
        end
    end)
    if not ok then
        FS25E_Debug.warning("ModSettings", "getUserProfileAppPath failed: " .. tostring(err))
    end

    if absolutePath ~= nil and createFolder ~= nil then
        pcall(function()
            createFolder(absolutePath)
        end)
    end

    ready = true
    FS25E_Debug.info("ModSettings", string.format(
        "path prepared relative=%s absolute=%s",
        tostring(relativePath),
        tostring(absolutePath or "(deferred)")
    ))
end

function FS25E_ModSettings.isReady()
    return ready
end

function FS25E_ModSettings.getRelativePath()
    return relativePath
end

function FS25E_ModSettings.getAbsolutePath()
    return absolutePath
end

function FS25E_ModSettings.getFilePath(filename)
    local name = filename or FILE_NAME
    if absolutePath ~= nil then
        return absolutePath .. name
    end
    return (relativePath or ("modSettings/" .. MOD_SETTINGS_FOLDER .. "/")) .. name
end

function FS25E_ModSettings.get(key)
    if key == nil then
        return nil
    end
    return values[key]
end

function FS25E_ModSettings.set(key, value)
    if key == nil or values[key] == nil and key ~= "activePreset" and key ~= "targetFps" then
        -- allow known keys only
        if defaults()[key] == nil then
            return false
        end
    end
    if key == "targetFps" then
        local n = tonumber(value)
        if n == nil or n <= 0 then
            return false
        end
        values.targetFps = n
    elseif key == "activePreset" then
        values.activePreset = tostring(value or "Balanced")
    else
        values[key] = value == true
    end
    return true
end

function FS25E_ModSettings.getAll()
    local out = {}
    copyInto(out, values)
    return out
end

--- Apply persisted flags to live modules (defaults stay false if file missing).
function FS25E_ModSettings.applyToRuntime()
    if FS25E_GraphicsGovernor ~= nil then
        if FS25E_GraphicsGovernor.setEnabled ~= nil then
            FS25E_GraphicsGovernor.setEnabled(values.governorEnabled == true)
        end
        if FS25E_GraphicsGovernor.setAutoApply ~= nil then
            FS25E_GraphicsGovernor.setAutoApply(values.autoApply == true)
        end
    end
    if FS25E_CapabilityRegistry ~= nil and FS25E_CapabilityRegistry.setExpertMode ~= nil then
        FS25E_CapabilityRegistry.setExpertMode(values.expertMode == true)
    end
    if FS25E_LightDiscovery ~= nil and FS25E_LightDiscovery.setSoftApplyEnabled ~= nil then
        FS25E_LightDiscovery.setSoftApplyEnabled(values.softApply == true)
    end
    if FS25E_ProfileManager ~= nil and FS25E_ProfileManager.selectPreset ~= nil then
        FS25E_ProfileManager.selectPreset(values.activePreset or "Balanced")
    end
    if FS25E_SettingsSchema ~= nil and FS25E_SettingsSchema.set ~= nil then
        pcall(function()
            FS25E_SettingsSchema.set("targetFps", values.targetFps)
            FS25E_SettingsSchema.set("adaptive", values.adaptive == true)
            FS25E_SettingsSchema.set("governorEnabled", values.governorEnabled == true)
            FS25E_SettingsSchema.set("autoApply", values.autoApply == true)
            FS25E_SettingsSchema.set("expertMode", values.expertMode == true)
        end)
    end
    FS25E_Debug.info("ModSettings", string.format(
        "runtime applied enabled=%s autoApply=%s expert=%s soft=%s preset=%s",
        tostring(values.governorEnabled), tostring(values.autoApply),
        tostring(values.expertMode), tostring(values.softApply), tostring(values.activePreset)
    ))
end

function FS25E_ModSettings.load()
    copyInto(values, defaults())
    local path = FS25E_ModSettings.getFilePath(FILE_NAME)
    FS25E_Debug.info("ModSettings", "load " .. tostring(path))

    local ok, err = pcall(function()
        if loadXMLFile == nil then
            return
        end
        local xmlId = loadXMLFile("FS25E_modSettings", path)
        if xmlId == nil or xmlId == 0 then
            FS25E_Debug.info("ModSettings", "no settings file; using defaults (all toggles false)")
            return
        end
        local function boolKey(key, xmlKey)
            if getXMLBool ~= nil then
                local v = getXMLBool(xmlId, xmlKey)
                if v ~= nil then
                    values[key] = v == true
                end
            end
        end
        boolKey("governorEnabled", "settings#governorEnabled")
        boolKey("autoApply", "settings#autoApply")
        boolKey("softApply", "settings#softApply")
        boolKey("expertMode", "settings#expertMode")
        boolKey("adaptive", "settings#adaptive")
        if getXMLString ~= nil then
            local p = getXMLString(xmlId, "settings#activePreset")
            if p ~= nil and p ~= "" then
                values.activePreset = p
            end
        end
        if getXMLInt ~= nil then
            local fps = getXMLInt(xmlId, "settings#targetFps")
            if fps ~= nil and fps > 0 then
                values.targetFps = fps
            end
        elseif getXMLFloat ~= nil then
            local fps = getXMLFloat(xmlId, "settings#targetFps")
            if fps ~= nil and fps > 0 then
                values.targetFps = math.floor(fps + 0.5)
            end
        end
        if deleteXMLFile ~= nil then
            deleteXMLFile(xmlId)
        end
    end)
    if not ok then
        FS25E_Debug.warning("ModSettings", "load soft-failed: " .. tostring(err))
        copyInto(values, defaults())
    end

    FS25E_ModSettings.applyToRuntime()
    return true
end

function FS25E_ModSettings.save()
    -- sync from runtime if available
    if FS25E_GraphicsGovernor ~= nil then
        if FS25E_GraphicsGovernor.isEnabled ~= nil then
            values.governorEnabled = FS25E_GraphicsGovernor.isEnabled() == true
        end
        if FS25E_GraphicsGovernor.isAutoApply ~= nil then
            values.autoApply = FS25E_GraphicsGovernor.isAutoApply() == true
        end
    end
    if FS25E_CapabilityRegistry ~= nil and FS25E_CapabilityRegistry.isExpertMode ~= nil then
        values.expertMode = FS25E_CapabilityRegistry.isExpertMode() == true
    end
    if FS25E_LightDiscovery ~= nil and FS25E_LightDiscovery.isSoftApplyEnabled ~= nil then
        values.softApply = FS25E_LightDiscovery.isSoftApplyEnabled() == true
    end
    if FS25E_ProfileManager ~= nil and FS25E_ProfileManager.getActiveName ~= nil then
        values.activePreset = FS25E_ProfileManager.getActiveName() or values.activePreset
    end

    local path = FS25E_ModSettings.getFilePath(FILE_NAME)
    local ok, err = pcall(function()
        if createXMLFile == nil or saveXMLFile == nil then
            FS25E_Debug.info("ModSettings", "XML save APIs unavailable; skip persist")
            return
        end
        if absolutePath ~= nil and createFolder ~= nil then
            pcall(createFolder, absolutePath)
        end
        local xmlId = createXMLFile("FS25E_modSettings", path, "settings")
        if xmlId == nil or xmlId == 0 then
            error("createXMLFile failed")
        end
        if setXMLBool ~= nil then
            setXMLBool(xmlId, "settings#governorEnabled", values.governorEnabled == true)
            setXMLBool(xmlId, "settings#autoApply", values.autoApply == true)
            setXMLBool(xmlId, "settings#softApply", values.softApply == true)
            setXMLBool(xmlId, "settings#expertMode", values.expertMode == true)
            setXMLBool(xmlId, "settings#adaptive", values.adaptive == true)
        end
        if setXMLString ~= nil then
            setXMLString(xmlId, "settings#activePreset", tostring(values.activePreset or "Balanced"))
        end
        if setXMLInt ~= nil then
            setXMLInt(xmlId, "settings#targetFps", tonumber(values.targetFps) or 60)
        elseif setXMLFloat ~= nil then
            setXMLFloat(xmlId, "settings#targetFps", tonumber(values.targetFps) or 60)
        end
        saveXMLFile(xmlId)
        if deleteXMLFile ~= nil then
            deleteXMLFile(xmlId)
        end
    end)
    if not ok then
        FS25E_Debug.warning("ModSettings", "save soft-failed: " .. tostring(err))
        return false
    end
    FS25E_Debug.info("ModSettings", "saved " .. tostring(path))
    return true
end

-- Back-compat stubs
function FS25E_ModSettings.loadStub()
    return FS25E_ModSettings.load()
end

function FS25E_ModSettings.saveStub()
    return FS25E_ModSettings.save()
end
