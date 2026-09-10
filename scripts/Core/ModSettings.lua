-- FS25_Enhanced / Core/ModSettings.lua
-- Client modSettings path + user-value store (GUI docks here via get/set).
-- Persist best-effort to settings.xml; session table always works.

FS25E_ModSettings = {}

local MOD_SETTINGS_FOLDER = "FS25_Enhanced"
local SETTINGS_FILE = "settings.xml"
local relativePath = nil
local absolutePath = nil
local ready = false

--- In-memory user values (authoritative for GUI R/W).
local values = {}

--- Defaults for user-facing settings (GUI Gen-1). Governor stays off until user acts.
local DEFAULTS = {
    enabled = false,
    adaptive = false,
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
}

local function copyDefaults()
    local t = {}
    for k, v in pairs(DEFAULTS) do
        t[k] = v
    end
    return t
end

local function coerceStored(raw, default)
    if raw == nil then
        return default
    end
    local dt = type(default)
    if dt == "boolean" then
        if type(raw) == "boolean" then
            return raw
        end
        local s = tostring(raw):lower()
        if s == "true" or s == "1" then
            return true
        end
        if s == "false" or s == "0" then
            return false
        end
        return default
    end
    if dt == "number" then
        return tonumber(raw) or default
    end
    return tostring(raw)
end

function FS25E_ModSettings.init()
    ready = false
    relativePath = "modSettings/" .. MOD_SETTINGS_FOLDER .. "/"
    absolutePath = nil
    values = copyDefaults()

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
        tostring(absolutePath or "(deferred until profile path available)")
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
    if id == nil then
        return nil
    end
    if values[id] ~= nil then
        return values[id]
    end
    return DEFAULTS[id]
end

function FS25E_ModSettings.set(id, value)
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
    values = copyDefaults()
end

function FS25E_ModSettings.loadStub()
    local path = FS25E_ModSettings.getFilePath(SETTINGS_FILE)
    if loadXMLFile == nil or getXMLString == nil then
        FS25E_Debug.info("ModSettings", "loadStub session-only (XML APIs unavailable)")
        return true
    end
    local xmlId = loadXMLFile("FS25E_modSettings", path)
    if xmlId == nil or xmlId == 0 then
        FS25E_Debug.info("ModSettings", "loadStub no file yet path=" .. tostring(path))
        return true
    end
    local loaded = 0
    local ok, err = pcall(function()
        for id, default in pairs(DEFAULTS) do
            local raw = getXMLString(xmlId, "settings." .. id)
            if raw ~= nil and raw ~= "" then
                values[id] = coerceStored(raw, default)
                loaded = loaded + 1
            end
        end
    end)
    if deleteXMLFile ~= nil then
        pcall(deleteXMLFile, xmlId)
    end
    if not ok then
        FS25E_Debug.warning("ModSettings", "loadStub parse failed: " .. tostring(err))
        return false
    end
    FS25E_Debug.info("ModSettings", string.format("loadStub ok keys=%d path=%s", loaded, tostring(path)))
    return true
end

function FS25E_ModSettings.saveStub()
    local path = FS25E_ModSettings.getFilePath(SETTINGS_FILE)
    if createXMLFile == nil or setXMLString == nil or saveXMLFile == nil then
        FS25E_Debug.info("ModSettings", "saveStub deferred (XML write APIs unavailable); session values kept")
        return false
    end
    local ok, err = pcall(function()
        local xmlId = createXMLFile("FS25E_modSettings", path, "settings")
        if xmlId == nil or xmlId == 0 then
            error("createXMLFile failed")
        end
        setXMLString(xmlId, "settings#version", "1")
        for id, _ in pairs(DEFAULTS) do
            local v = FS25E_ModSettings.get(id)
            if type(v) == "boolean" then
                setXMLString(xmlId, "settings." .. id, v and "true" or "false")
            else
                setXMLString(xmlId, "settings." .. id, tostring(v))
            end
        end
        saveXMLFile(xmlId)
        if deleteXMLFile ~= nil then
            deleteXMLFile(xmlId)
        end
    end)
    if not ok then
        FS25E_Debug.warning("ModSettings", "saveStub failed: " .. tostring(err) .. " — TODO persist when profile path/XML ready")
        return false
    end
    FS25E_Debug.info("ModSettings", "saveStub ok path=" .. tostring(path))
    return true
end

function FS25E_ModSettings.load()
    return FS25E_ModSettings.loadStub()
end

function FS25E_ModSettings.save()
    return FS25E_ModSettings.saveStub()
end
