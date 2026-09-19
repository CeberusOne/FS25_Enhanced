-- Client-only settings.xml. No governor, no expert flags, no hardware writes.
FS25E_ModSettings = {}

local FOLDER = "FS25_Enhanced"
local FILE = "settings.xml"
local relativePath, absolutePath, ready = nil, nil, false
local values = {}

local DEFAULTS = {
    enabled = true,
    uiLanguage = "auto",
    liveTuningEnabled = false,
    liveHiddenControls = "",
    liveWindowRect = "",
    hideUnavailable = true,
    qualityLevel = 0,
}

local function coerce(value, default)
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

local function seed()
    values = {}
    for k, v in pairs(DEFAULTS) do values[k] = v end
end

function FS25E_ModSettings.init()
    ready = false
    relativePath = "modSettings/" .. FOLDER .. "/"
    absolutePath = nil
    seed()
    pcall(function()
        if getUserProfileAppPath ~= nil then
            local base = getUserProfileAppPath()
            if base ~= nil and base ~= "" then
                absolutePath = base .. "modSettings/" .. FOLDER .. "/"
            end
        end
    end)
    if absolutePath ~= nil and createFolder ~= nil then pcall(createFolder, absolutePath) end
    ready = true
    FS25E_Debug.info("ModSettings", "path " .. tostring(absolutePath or relativePath))
end

function FS25E_ModSettings.isReady() return ready end
function FS25E_ModSettings.getDefaults() return DEFAULTS end
function FS25E_ModSettings.getRelativePath() return relativePath end
function FS25E_ModSettings.getAbsolutePath() return absolutePath end

function FS25E_ModSettings.getFilePath(filename)
    local name = filename or FILE
    if absolutePath ~= nil then return absolutePath .. name end
    return (relativePath or ("modSettings/" .. FOLDER .. "/")) .. name
end

function FS25E_ModSettings.get(id)
    if id == nil or DEFAULTS[id] == nil then return nil end
    if values[id] ~= nil then return values[id] end
    return DEFAULTS[id]
end

function FS25E_ModSettings.set(id, value)
    if id == nil or DEFAULTS[id] == nil then return false end
    values[id] = coerce(value, DEFAULTS[id])
    return true
end

function FS25E_ModSettings.getAll()
    local out = {}
    for k, _ in pairs(DEFAULTS) do out[k] = FS25E_ModSettings.get(k) end
    return out
end

function FS25E_ModSettings.resetToDefaults() seed() end

function FS25E_ModSettings.applyToRuntime()
    -- Values are read by the live window and adapters. Nothing auto-applies.
    return true
end

function FS25E_ModSettings.load()
    seed()
    local path = FS25E_ModSettings.getFilePath(FILE)
    local ok, err = pcall(function()
        if loadXMLFile == nil then return end
        local xmlId = loadXMLFile("FS25E_modSettings", path)
        if xmlId == nil or xmlId == 0 then return end
        for id, default in pairs(DEFAULTS) do
            local key = "settings#" .. id
            local raw = nil
            if type(default) == "boolean" and getXMLBool ~= nil then
                raw = getXMLBool(xmlId, key)
            elseif getXMLString ~= nil then
                raw = getXMLString(xmlId, key)
            end
            if raw ~= nil then values[id] = coerce(raw, default) end
        end
        if deleteXMLFile ~= nil then deleteXMLFile(xmlId) elseif delete ~= nil then delete(xmlId) end
    end)
    if not ok then
        FS25E_Debug.warning("ModSettings", "load failed: " .. tostring(err))
        seed()
    end
    values.enabled = true
    return true
end

function FS25E_ModSettings.save()
    local path = FS25E_ModSettings.getFilePath(FILE)
    local ok, err = pcall(function()
        if createXMLFile == nil or saveXMLFile == nil then return end
        if absolutePath ~= nil and createFolder ~= nil then pcall(createFolder, absolutePath) end
        local xmlId = createXMLFile("FS25E_modSettings", path, "settings")
        if xmlId == nil or xmlId == 0 then error("createXMLFile failed") end
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
        if deleteXMLFile ~= nil then deleteXMLFile(xmlId) elseif delete ~= nil then delete(xmlId) end
    end)
    if not ok then
        FS25E_Debug.warning("ModSettings", "save failed: " .. tostring(err))
        return false
    end
    return true
end
