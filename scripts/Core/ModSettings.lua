-- FS25_Enhanced / Core/ModSettings.lua
-- Client modSettings path + user-value store (GUI docks via get/set).
-- Persist best-effort to settings.xml. Defaults: enabled/autoApply/softApply/expertMode/adaptive = false.

FS25E_ModSettings = {}

local MOD_SETTINGS_FOLDER = "FS25_Enhanced"
local SETTINGS_FILE = "settings.xml"
local relativePath = nil
local absolutePath = nil
local ready = false

local values = {}

--- GUI Gen-1 keys + Core toggles. Governor stays off until user acts.
local DEFAULTS = {
    enabled = false,
    adaptive = false,
    autoApply = false,
    softApply = false,
    targetFps = "60",
    preset = "Balanced",
    expertMode = false,
    persistHardware = false,
    shadowQuality = "med",
    shadowDistance = "med",
    maxShadowLights = "med",
    foliageShadows = true,
    softShadows = "med",
    maxLights = "med",
    lightScattering = "med",
    shadowMerge = true,
    viewDistance = "med",
    lodDistance = "med",
    foliageViewDistance = "med",
    foliageLodDistance = "med",
    terrainLodDistance = "med",
    shadowFocus = false,
    fastShadowUpdate = false,
    rainShallowWater = false,
    liveTuningEnabled = false,
    -- Expert Soft-Apply / ExperimentalCaps toggles (default OFF)
    expertSoftApply = false,
    expertShadowFocusBox = false,
    expertFastShadowUpdate = false,
    expertRainShallowWater = false,
    expertSsrQuality = false,
    expertAtmosphereQuality = false,
    expertDrsQuality = false,
    expertRainSuite = false,
}

-- Aliases for SettingsAPI / older Core names
local ALIASES = {
    governorEnabled = "enabled",
    activePreset = "preset",
}

local function resolveKey(id)
    if id == nil then return nil end
    if ALIASES[id] ~= nil then return ALIASES[id] end
    return id
end

local function coerceStored(value, default)
    if type(default) == "boolean" then
        if type(value) == "boolean" then return value end
        if type(value) == "string" then
            local s = value:lower()
            if s == "true" or s == "1" then return true end
            if s == "false" or s == "0" then return false end
        end
        if type(value) == "number" then return value ~= 0 end
        return default
    end
    if type(default) == "number" then
        return tonumber(value) or default
    end
    if value == nil then return default end
    return tostring(value)
end

local function seedDefaults()
    values = {}
    for k, v in pairs(DEFAULTS) do
        values[k] = v
    end
end

function FS25E_ModSettings.init()
    ready = false
    relativePath = "modSettings/" .. MOD_SETTINGS_FOLDER .. "/"
    absolutePath = nil
    seedDefaults()

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
    local name = filename or SETTINGS_FILE
    if absolutePath ~= nil then
        return absolutePath .. name
    end
    return (relativePath or ("modSettings/" .. MOD_SETTINGS_FOLDER .. "/")) .. name
end

function FS25E_ModSettings.getDefaults()
    return DEFAULTS
end

function FS25E_ModSettings.get(id)
    id = resolveKey(id)
    if id == nil or DEFAULTS[id] == nil then
        return nil
    end
    if values[id] ~= nil then
        return values[id]
    end
    return DEFAULTS[id]
end

function FS25E_ModSettings.set(id, value)
    local rawId = id
    id = resolveKey(id)
    if id == nil or DEFAULTS[id] == nil then
        return false
    end
    values[id] = coerceStored(value, DEFAULTS[id])
    return true
end

function FS25E_ModSettings.getAll()
    local out = {}
    for k, _ in pairs(DEFAULTS) do
        out[k] = FS25E_ModSettings.get(k)
    end
    return out
end

function FS25E_ModSettings.resetToDefaults()
    seedDefaults()
end

--- Push toggles into live modules (no engine quality setters here).
function FS25E_ModSettings.applyToRuntime()
    local enabled = FS25E_ModSettings.get("enabled") == true
    local adaptive = FS25E_ModSettings.get("adaptive") == true
    local autoApply = FS25E_ModSettings.get("autoApply") == true
    -- Simple UX: Adaptive is the user-facing auto toggle; keep autoApply in sync
    if adaptive ~= autoApply then
        autoApply = adaptive
        FS25E_ModSettings.set("autoApply", autoApply)
    end
    local softApply = FS25E_ModSettings.get("softApply") == true
    local expert = FS25E_ModSettings.get("expertMode") == true
    local preset = FS25E_ModSettings.get("preset") or "Balanced"

    if FS25E_GraphicsGovernor ~= nil then
        if FS25E_GraphicsGovernor.setEnabled ~= nil then
            FS25E_GraphicsGovernor.setEnabled(enabled)
        end
        if FS25E_GraphicsGovernor.setAutoApply ~= nil then
            FS25E_GraphicsGovernor.setAutoApply(autoApply)
        end
    end
    if FS25E_CapabilityRegistry ~= nil and FS25E_CapabilityRegistry.setExpertMode ~= nil then
        FS25E_CapabilityRegistry.setExpertMode(expert)
    end
    if FS25E_LightDiscovery ~= nil and FS25E_LightDiscovery.setSoftApplyEnabled ~= nil then
        FS25E_LightDiscovery.setSoftApplyEnabled(softApply)
    end
    if FS25E_ProfileManager ~= nil and FS25E_ProfileManager.selectPreset ~= nil then
        FS25E_ProfileManager.selectPreset(tostring(preset))
    end
    FS25E_Debug.info("ModSettings", string.format(
        "runtime applied enabled=%s adaptive=%s autoApply=%s soft=%s expert=%s preset=%s",
        tostring(enabled), tostring(adaptive), tostring(autoApply), tostring(softApply), tostring(expert), tostring(preset)
    ))
end

function FS25E_ModSettings.load()
    seedDefaults()
    local path = FS25E_ModSettings.getFilePath(SETTINGS_FILE)
    FS25E_Debug.info("ModSettings", "load " .. tostring(path))

    local ok, err = pcall(function()
        if loadXMLFile == nil then
            return
        end
        local xmlId = loadXMLFile("FS25E_modSettings", path)
        if xmlId == nil or xmlId == 0 then
            FS25E_Debug.info("ModSettings", "no settings file; defaults (toggles false)")
            return
        end
        for id, default in pairs(DEFAULTS) do
            local key = "settings#" .. id
            local raw = nil
            if type(default) == "boolean" and getXMLBool ~= nil then
                raw = getXMLBool(xmlId, key)
            elseif getXMLString ~= nil then
                raw = getXMLString(xmlId, key)
            end
            if raw ~= nil then
                values[id] = coerceStored(raw, default)
            end
        end
        if deleteXMLFile ~= nil then
            deleteXMLFile(xmlId)
        end
    end)
    if not ok then
        FS25E_Debug.warning("ModSettings", "load soft-failed: " .. tostring(err))
        seedDefaults()
    end

    FS25E_ModSettings.applyToRuntime()
    return true
end

function FS25E_ModSettings.save()
    -- sync toggles from runtime
    if FS25E_GraphicsGovernor ~= nil then
        if FS25E_GraphicsGovernor.isEnabled ~= nil then
            values.enabled = FS25E_GraphicsGovernor.isEnabled() == true
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
        values.preset = FS25E_ProfileManager.getActiveName() or values.preset
    end

    local path = FS25E_ModSettings.getFilePath(SETTINGS_FILE)
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
        for id, default in pairs(DEFAULTS) do
            local key = "settings#" .. id
            local v = values[id]
            if v == nil then v = default end
            if type(default) == "boolean" and setXMLBool ~= nil then
                setXMLBool(xmlId, key, v == true)
            elseif setXMLString ~= nil then
                setXMLString(xmlId, key, tostring(v))
            end
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

function FS25E_ModSettings.loadStub()
    return FS25E_ModSettings.load()
end

function FS25E_ModSettings.saveStub()
    return FS25E_ModSettings.save()
end
