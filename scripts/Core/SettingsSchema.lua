-- FS25_Enhanced / Core/SettingsSchema.lua
-- Settings defaults table / schema stubs for later GUI (FS25 GUI Agent).
-- Not applied to engine in Phase 1. Expert toggles default OFF + expertOnly.

FS25E_SettingsSchema = {}

--- Default values mirrored conceptually by config/defaults.xml
local defaults = {
    enabled = false,
    adaptive = true,
    targetFps = 60,
    preset = "Balanced",
    expertMode = false,
    persistHardware = false, -- never silently overwrite vanilla scalability
    -- Expert Soft-Apply / per-cap toggles (all OFF; expertOnly)
    expertSoftApply = false,
    expertShadowFocusBox = false,
    expertFastShadowUpdate = false,
    expertRainShallowWater = false,
    expertSsrQuality = false,
    expertAtmosphereQuality = false,
    expertDrsQuality = false,
    expertRainSuite = false,
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
        expertOnly = false,
    },
    {
        id = "adaptive",
        type = "bool",
        l10n = "FS25E_SETTING_ADAPTIVE",
        default = true,
        applyMode = "SESSION",
        gui = "binary",
        expertOnly = false,
    },
    {
        id = "targetFps",
        type = "enum",
        l10n = "FS25E_SETTING_TARGET_FPS",
        default = 60,
        values = { 30, 45, 60, 75, 90, 120 },
        applyMode = "SESSION",
        gui = "multiText",
        expertOnly = false,
    },
    {
        id = "preset",
        type = "enum",
        l10n = "FS25E_SETTING_PRESET",
        default = "Balanced",
        values = { "Performance", "Balanced", "Quality", "Cinematic" },
        applyMode = "SESSION",
        gui = "multiText",
        expertOnly = false,
    },
    {
        id = "expertMode",
        type = "bool",
        l10n = "FS25E_SETTING_EXPERT",
        default = false,
        applyMode = "SESSION",
        gui = "binary",
        expertOnly = false,
    },
    {
        id = "persistHardware",
        type = "bool",
        l10n = "FS25E_SETTING_PERSIST_HW",
        default = false,
        applyMode = "RESTART",
        gui = "binary",
        warningL10n = "FS25E_WARN_PERSIST_HW",
        expertOnly = false,
    },
    {
        id = "expertSoftApply",
        type = "bool",
        l10n = "FS25E_SETTING_EXPERT_SOFT_APPLY",
        default = false,
        applyMode = "SESSION",
        gui = "binary",
        expertOnly = true,
    },
    {
        id = "expertShadowFocusBox",
        type = "bool",
        l10n = "FS25E_SETTING_EXPERT_SHADOW_FOCUS_BOX",
        default = false,
        applyMode = "SESSION",
        gui = "binary",
        expertOnly = true,
    },
    {
        id = "expertFastShadowUpdate",
        type = "bool",
        l10n = "FS25E_SETTING_EXPERT_FAST_SHADOW_UPDATE",
        default = false,
        applyMode = "SESSION",
        gui = "binary",
        expertOnly = true,
    },
    {
        id = "expertRainShallowWater",
        type = "bool",
        l10n = "FS25E_SETTING_EXPERT_RAIN_SHALLOW",
        default = false,
        applyMode = "SESSION",
        gui = "binary",
        expertOnly = true,
    },
    {
        id = "expertSsrQuality",
        type = "bool",
        l10n = "FS25E_SETTING_EXPERT_SSR",
        default = false,
        applyMode = "SESSION",
        gui = "binary",
        expertOnly = true,
    },
    {
        id = "expertAtmosphereQuality",
        type = "bool",
        l10n = "FS25E_SETTING_EXPERT_ATMOSPHERE",
        default = false,
        applyMode = "SESSION",
        gui = "binary",
        expertOnly = true,
    },
    {
        id = "expertDrsQuality",
        type = "bool",
        l10n = "FS25E_SETTING_EXPERT_DRS",
        default = false,
        applyMode = "SESSION",
        gui = "binary",
        expertOnly = true,
    },
    {
        id = "expertRainSuite",
        type = "bool",
        l10n = "FS25E_SETTING_EXPERT_RAIN_SUITE",
        default = false,
        applyMode = "SESSION",
        gui = "binary",
        expertOnly = true,
    },
}

local current = {}

function FS25E_SettingsSchema.init()
    current = {}
    for k, v in pairs(defaults) do
        current[k] = v
    end
    FS25E_Debug.info("SettingsSchema", "defaults table ready (expert toggles OFF; not applied to engine)")
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
    local prev = current[id]
    current[id] = value
    -- Soft-Apply trigger only when a value changes and Soft-Apply is armed (never on init path)
    if prev ~= value and FS25E_ExperimentalCaps ~= nil and FS25E_ExperimentalCaps.onSettingsChanged ~= nil then
        if id == "expertMode" or id == "expertSoftApply" or string.sub(tostring(id), 1, 6) == "expert" then
            if current.expertMode == true and current.expertSoftApply == true then
                if FS25E_ExperimentalCaps.setSoftApplyEnabled ~= nil then
                    FS25E_ExperimentalCaps.setSoftApplyEnabled(true)
                end
                FS25E_ExperimentalCaps.onSettingsChanged()
            end
        end
    end
    return true, prev
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
