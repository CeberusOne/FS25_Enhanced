-- FS25_Enhanced / Core/SettingsSchema.lua
-- Metadata / labels / option lists for GUI (Gen-1).
-- User VALUES live in FS25E_ModSettings.get/set — schema is not the value store.
-- Expert Soft-Apply / expert* toggles (default OFF; expertOnly) for ExperimentalCaps.

FS25E_SettingsSchema = {}

local QUALITY = { "low", "med", "high", "ultra" }
local QUALITY_I18N = {
    low = "FS25E_OPT_LOW",
    med = "FS25E_OPT_MED",
    high = "FS25E_OPT_HIGH",
    ultra = "FS25E_OPT_ULTRA",
}

local schema = {
    { id = "enabled", type = "bool", l10n = "FS25E_SETTING_ENABLED", tooltip = "FS25E_SETTING_ENABLED_TOOLTIP", default = false, section = "simple", expertOnly = false, applyMode = "SESSION", gui = "binary" },
    { id = "preset", type = "enum", l10n = "FS25E_SETTING_PRESET", tooltip = "FS25E_SETTING_PRESET_TOOLTIP", default = "Balanced",
      options = { "Off", "Performance", "Balanced", "Quality", "Cinematic" },
      optionI18nKeys = { Off = "FS25E_PRESET_OFF", Performance = "FS25E_PRESET_PERFORMANCE", Balanced = "FS25E_PRESET_BALANCED", Quality = "FS25E_PRESET_QUALITY", Cinematic = "FS25E_PRESET_CINEMATIC" },
      section = "simple", expertOnly = false, applyMode = "SLOW", gui = "multiText" },
    { id = "targetFps", type = "enum", l10n = "FS25E_SETTING_TARGET_FPS", tooltip = "FS25E_SETTING_TARGET_FPS_TOOLTIP", default = "60",
      options = { "30", "40", "50", "60", "unlimited" },
      optionI18nKeys = { ["30"] = "FS25E_FPS_30", ["40"] = "FS25E_FPS_40", ["50"] = "FS25E_FPS_50", ["60"] = "FS25E_FPS_60", unlimited = "FS25E_FPS_UNLIMITED" },
      section = "simple", expertOnly = false, applyMode = "MED", gui = "multiText" },
    { id = "adaptive", type = "bool", l10n = "FS25E_SETTING_ADAPTIVE", tooltip = "FS25E_SETTING_ADAPTIVE_TOOLTIP", default = false, section = "simple", expertOnly = false, applyMode = "MED", gui = "binary" },

    { id = "shadowQuality", type = "enum", l10n = "FS25E_SETTING_SHADOW_QUALITY", tooltip = "FS25E_SETTING_SHADOW_QUALITY_TOOLTIP", default = "med", options = QUALITY, optionI18nKeys = QUALITY_I18N, section = "advanced", group = "shadows", expertOnly = false, applyMode = "SLOW", capId = "shadow-quality", gui = "multiText" },
    { id = "shadowDistance", type = "enum", l10n = "FS25E_SETTING_SHADOW_DISTANCE", tooltip = "FS25E_SETTING_SHADOW_DISTANCE_TOOLTIP", default = "med", options = QUALITY, optionI18nKeys = QUALITY_I18N, section = "advanced", group = "shadows", expertOnly = false, applyMode = "SLOW", capId = "shadow-distance-quality", gui = "multiText" },
    { id = "maxShadowLights", type = "enum", l10n = "FS25E_SETTING_MAX_SHADOW_LIGHTS", tooltip = "FS25E_SETTING_MAX_SHADOW_LIGHTS_TOOLTIP", default = "med", options = QUALITY, optionI18nKeys = QUALITY_I18N, section = "advanced", group = "shadows", expertOnly = false, applyMode = "MED", capId = "max-num-shadow-lights", gui = "multiText" },
    { id = "foliageShadows", type = "bool", l10n = "FS25E_SETTING_FOLIAGE_SHADOWS", tooltip = "FS25E_SETTING_FOLIAGE_SHADOWS_TOOLTIP", default = true, section = "advanced", group = "shadows", expertOnly = false, applyMode = "MED", capId = "allow-foliage-shadows", gui = "binary" },
    { id = "softShadows", type = "enum", l10n = "FS25E_SETTING_SOFT_SHADOWS", tooltip = "FS25E_SETTING_SOFT_SHADOWS_TOOLTIP", default = "med", options = QUALITY, optionI18nKeys = QUALITY_I18N, section = "advanced", group = "shadows", expertOnly = false, applyMode = "MED", capId = "shadow-filter-quality", gui = "multiText" },

    { id = "maxLights", type = "enum", l10n = "FS25E_SETTING_MAX_LIGHTS", tooltip = "FS25E_SETTING_MAX_LIGHTS_TOOLTIP", default = "med", options = QUALITY, optionI18nKeys = QUALITY_I18N, section = "advanced", group = "lighting", expertOnly = false, applyMode = "MED", gui = "multiText" },
    { id = "lightScattering", type = "enum", l10n = "FS25E_SETTING_LIGHT_SCATTERING", tooltip = "FS25E_SETTING_LIGHT_SCATTERING_TOOLTIP", default = "med", options = { "off", "low", "med", "high" }, optionI18nKeys = { off = "FS25E_OPT_OFF", low = "FS25E_OPT_LOW", med = "FS25E_OPT_MED", high = "FS25E_OPT_HIGH" }, section = "advanced", group = "lighting", expertOnly = false, applyMode = "MED", gui = "multiText" },
    { id = "shadowMerge", type = "bool", l10n = "FS25E_SETTING_SHADOW_MERGE", tooltip = "FS25E_SETTING_SHADOW_MERGE_TOOLTIP", default = true, section = "advanced", group = "lighting", expertOnly = false, applyMode = "SLOW", capId = "merge-light-shadows", gui = "binary" },

    { id = "viewDistance", type = "enum", l10n = "FS25E_SETTING_VIEW_DISTANCE", tooltip = "FS25E_SETTING_VIEW_DISTANCE_TOOLTIP", default = "med", options = QUALITY, optionI18nKeys = QUALITY_I18N, section = "advanced", group = "lod", expertOnly = false, applyMode = "MED", capId = "view-distance-coeff", gui = "multiText" },
    { id = "lodDistance", type = "enum", l10n = "FS25E_SETTING_LOD_DISTANCE", tooltip = "FS25E_SETTING_LOD_DISTANCE_TOOLTIP", default = "med", options = QUALITY, optionI18nKeys = QUALITY_I18N, section = "advanced", group = "lod", expertOnly = false, applyMode = "MED", capId = "lod-distance-coeff", gui = "multiText" },
    { id = "foliageViewDistance", type = "enum", l10n = "FS25E_SETTING_FOLIAGE_VIEW", tooltip = "FS25E_SETTING_FOLIAGE_VIEW_TOOLTIP", default = "med", options = QUALITY, optionI18nKeys = QUALITY_I18N, section = "advanced", group = "lod", expertOnly = false, applyMode = "MED", capId = "foliage-view-distance-coeff", gui = "multiText" },
    { id = "foliageLodDistance", type = "enum", l10n = "FS25E_SETTING_FOLIAGE_LOD", tooltip = "FS25E_SETTING_FOLIAGE_LOD_TOOLTIP", default = "med", options = QUALITY, optionI18nKeys = QUALITY_I18N, section = "advanced", group = "lod", expertOnly = false, applyMode = "MED", capId = "foliage-lod-distance-coeff", gui = "multiText" },
    { id = "terrainLodDistance", type = "enum", l10n = "FS25E_SETTING_TERRAIN_LOD", tooltip = "FS25E_SETTING_TERRAIN_LOD_TOOLTIP", default = "med", options = QUALITY, optionI18nKeys = QUALITY_I18N, section = "advanced", group = "lod", expertOnly = false, applyMode = "MED", capId = "terrain-lod-distance-coeff", gui = "multiText" },

    { id = "expertMode", type = "bool", l10n = "FS25E_EXPERT_MODE", tooltip = "FS25E_EXPERT_MODE_TOOLTIP", default = false, section = "expert", expertOnly = false, applyMode = "LIVE", gui = "binary" },
    { id = "shadowFocus", type = "bool", l10n = "FS25E_SETTING_SHADOW_FOCUS", tooltip = "FS25E_SETTING_SHADOW_FOCUS_TOOLTIP", default = false, section = "expert", expertOnly = true, applyMode = "LIVE", capId = "shadow-focus-box", gui = "binary" },
    { id = "fastShadowUpdate", type = "bool", l10n = "FS25E_SETTING_FAST_SHADOW_UPDATE", tooltip = "FS25E_SETTING_FAST_SHADOW_UPDATE_TOOLTIP", default = false, section = "expert", expertOnly = true, applyMode = "LIVE", capId = "fast-shadow-update", gui = "binary" },
    { id = "rainShallowWater", type = "bool", l10n = "FS25E_SETTING_RAIN_SHALLOW_WATER", tooltip = "FS25E_SETTING_RAIN_SHALLOW_WATER_TOOLTIP", default = false, section = "expert", expertOnly = true, applyMode = "MED", capId = "rain-shallow-water-simulation", gui = "binary" },
    { id = "liveTuningEnabled", type = "bool", l10n = "FS25E_SETTING_LIVE_TUNING", tooltip = "FS25E_SETTING_LIVE_TUNING_TOOLTIP", default = false, section = "live", expertOnly = false, applyMode = "LIVE", gui = "binary" },

    -- Expert Soft-Apply / per-cap toggles (ExperimentalCaps; all OFF; expertOnly)
    { id = "persistHardware", type = "bool", l10n = "FS25E_SETTING_PERSIST_HW", tooltip = "FS25E_WARN_PERSIST_HW", default = false, section = "expert", expertOnly = false, applyMode = "RESTART", gui = "binary", warningL10n = "FS25E_WARN_PERSIST_HW" },
    { id = "expertSoftApply", type = "bool", l10n = "FS25E_SETTING_EXPERT_SOFT_APPLY", tooltip = "FS25E_SETTING_EXPERT_SOFT_APPLY", default = false, section = "expert", expertOnly = true, applyMode = "SESSION", gui = "binary" },
    { id = "expertShadowFocusBox", type = "bool", l10n = "FS25E_SETTING_EXPERT_SHADOW_FOCUS_BOX", tooltip = "FS25E_SETTING_EXPERT_SHADOW_FOCUS_BOX", default = false, section = "expert", expertOnly = true, applyMode = "SESSION", gui = "binary", capId = "shadow-focus-box" },
    { id = "expertFastShadowUpdate", type = "bool", l10n = "FS25E_SETTING_EXPERT_FAST_SHADOW_UPDATE", tooltip = "FS25E_SETTING_EXPERT_FAST_SHADOW_UPDATE", default = false, section = "expert", expertOnly = true, applyMode = "SESSION", gui = "binary", capId = "fast-shadow-update" },
    { id = "expertRainShallowWater", type = "bool", l10n = "FS25E_SETTING_EXPERT_RAIN_SHALLOW", tooltip = "FS25E_SETTING_EXPERT_RAIN_SHALLOW", default = false, section = "expert", expertOnly = true, applyMode = "SESSION", gui = "binary", capId = "rain-shallow-water-simulation" },
    { id = "expertSsrQuality", type = "bool", l10n = "FS25E_SETTING_EXPERT_SSR", tooltip = "FS25E_SETTING_EXPERT_SSR", default = false, section = "expert", expertOnly = true, applyMode = "SESSION", gui = "binary" },
    { id = "expertAtmosphereQuality", type = "bool", l10n = "FS25E_SETTING_EXPERT_ATMOSPHERE", tooltip = "FS25E_SETTING_EXPERT_ATMOSPHERE", default = false, section = "expert", expertOnly = true, applyMode = "SESSION", gui = "binary" },
    { id = "expertDrsQuality", type = "bool", l10n = "FS25E_SETTING_EXPERT_DRS", tooltip = "FS25E_SETTING_EXPERT_DRS", default = false, section = "expert", expertOnly = true, applyMode = "SESSION", gui = "binary" },
    { id = "expertRainSuite", type = "bool", l10n = "FS25E_SETTING_EXPERT_RAIN_SUITE", tooltip = "FS25E_SETTING_EXPERT_RAIN_SUITE", default = false, section = "expert", expertOnly = true, applyMode = "SESSION", gui = "binary" },
}

local byId = {}

function FS25E_SettingsSchema.init()
    byId = {}
    for i = 1, #schema do
        byId[schema[i].id] = schema[i]
    end
    FS25E_Debug.info("SettingsSchema", string.format("metadata ready fields=%d (values via ModSettings; expert toggles OFF)", #schema))
end

function FS25E_SettingsSchema.getDefaults()
    if FS25E_ModSettings ~= nil and FS25E_ModSettings.getDefaults ~= nil then
        return FS25E_ModSettings.getDefaults()
    end
    local d = {}
    for i = 1, #schema do
        d[schema[i].id] = schema[i].default
    end
    return d
end

function FS25E_SettingsSchema.getSchema()
    return schema
end

function FS25E_SettingsSchema.getField(id)
    return byId[id]
end

function FS25E_SettingsSchema.getBySection(section)
    local list = {}
    for i = 1, #schema do
        if schema[i].section == section then
            list[#list + 1] = schema[i]
        end
    end
    return list
end

function FS25E_SettingsSchema.get(id)
    if FS25E_ModSettings ~= nil and FS25E_ModSettings.get ~= nil then
        return FS25E_ModSettings.get(id)
    end
    local f = byId[id]
    return f and f.default or nil
end

function FS25E_SettingsSchema.set(id, value)
    local prev = nil
    if FS25E_ModSettings ~= nil and FS25E_ModSettings.get ~= nil then
        prev = FS25E_ModSettings.get(id)
    end
    local ok = false
    if FS25E_ModSettings ~= nil and FS25E_ModSettings.set ~= nil then
        ok = FS25E_ModSettings.set(id, value)
    end
    if not ok then
        return false
    end
    -- Soft-Apply trigger only when a value changes and Soft-Apply is armed (never on init path)
    if prev ~= value and FS25E_ExperimentalCaps ~= nil and FS25E_ExperimentalCaps.onSettingsChanged ~= nil then
        if id == "expertMode" or id == "expertSoftApply" or string.sub(tostring(id), 1, 6) == "expert" then
            local expertMode = FS25E_ModSettings.get("expertMode") == true
            local expertSoft = FS25E_ModSettings.get("expertSoftApply") == true
            if expertMode and expertSoft then
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
    if FS25E_ModSettings ~= nil and FS25E_ModSettings.getAll ~= nil then
        return FS25E_ModSettings.getAll()
    end
    return {}
end

function FS25E_SettingsSchema.resetToDefaults()
    if FS25E_ModSettings ~= nil and FS25E_ModSettings.resetToDefaults ~= nil then
        FS25E_ModSettings.resetToDefaults()
    end
end

function FS25E_SettingsSchema.seedCache()
    if FS25E_SettingsCache == nil then
        return
    end
    for i = 1, #schema do
        local field = schema[i]
        local v = field.default
        if FS25E_ModSettings ~= nil and FS25E_ModSettings.get ~= nil then
            local mv = FS25E_ModSettings.get(field.id)
            if mv ~= nil then
                v = mv
            end
        end
        FS25E_SettingsCache.ensure(field.id, v)
        local e = FS25E_SettingsCache.get(field.id)
        if e ~= nil then
            e.applyMode = field.applyMode
            if field.capId ~= nil then
                e.capabilityId = field.capId
            end
        end
    end
end
