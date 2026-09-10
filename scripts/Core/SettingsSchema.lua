-- FS25_Enhanced / Core/SettingsSchema.lua
-- Settings defaults table / schema stubs for later GUI (FS25 GUI Agent).
-- Not applied to engine in Phase 1.

FS25E_SettingsSchema = {}

--- Default values mirrored conceptually by config/defaults.xml
local defaults = {
    enabled = false,
    adaptive = true,
    targetFps = 60,
    preset = "Balanced",
    expertMode = false,
    persistHardware = false, -- never silently overwrite vanilla scalability
}

--- Schema descriptors for future GUI binding (MultiTextOption etc., no sliders).
--- applyMode: SESSION | LIVE | RESTART — engine writers only after Research Freeze.
local schema = {
    {
        id = "enabled",
        type = "bool",
        l10n = "FS25E_SETTING_ENABLED",
        default = false,
        applyMode = "SESSION",
        gui = "binary",
    },
    {
        id = "adaptive",
        type = "bool",
        l10n = "FS25E_SETTING_ADAPTIVE",
        default = true,
        applyMode = "SESSION",
        gui = "binary",
    },
    {
        id = "targetFps",
        type = "enum",
        l10n = "FS25E_SETTING_TARGET_FPS",
        default = 60,
        values = { 30, 45, 60, 75, 90, 120 },
        applyMode = "SESSION",
        gui = "multiText",
    },
    {
        id = "preset",
        type = "enum",
        l10n = "FS25E_SETTING_PRESET",
        default = "Balanced",
        values = { "Performance", "Balanced", "Quality", "Cinematic" },
        applyMode = "SESSION",
        gui = "multiText",
    },
    {
        id = "expertMode",
        type = "bool",
        l10n = "FS25E_SETTING_EXPERT",
        default = false,
        applyMode = "SESSION",
        gui = "binary",
    },
    {
        id = "persistHardware",
        type = "bool",
        l10n = "FS25E_SETTING_PERSIST_HW",
        default = false,
        applyMode = "RESTART",
        gui = "binary",
        warningL10n = "FS25E_WARN_PERSIST_HW",
    },
}

local current = {}

function FS25E_SettingsSchema.init()
    current = {}
    for k, v in pairs(defaults) do
        current[k] = v
    end
    FS25E_Debug.info("SettingsSchema", "defaults table ready (not applied to engine)")
end

function FS25E_SettingsSchema.getDefaults()
    return defaults
end

function FS25E_SettingsSchema.getSchema()
    return schema
end

function FS25E_SettingsSchema.get(id)
    return current[id]
end

function FS25E_SettingsSchema.set(id, value)
    if defaults[id] == nil then
        return false
    end
    current[id] = value
    return true
end

function FS25E_SettingsSchema.getAll()
    return current
end

function FS25E_SettingsSchema.resetToDefaults()
    for k, v in pairs(defaults) do
        current[k] = v
    end
end

--- Seed SettingsCache soft entries from schema defaults (cache only).
function FS25E_SettingsSchema.seedCache()
    if FS25E_SettingsCache == nil then
        return
    end
    for _, field in ipairs(schema) do
        FS25E_SettingsCache.ensure(field.id, field.default)
        local e = FS25E_SettingsCache.get(field.id)
        if e ~= nil then
            e.applyMode = field.applyMode
        end
    end
end
