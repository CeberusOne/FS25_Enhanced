-- Window-only options: language, hide dead sliders, FPS HUD. Not engine settings.
FS25E_SessionControls = {}
local M = FS25E_SessionControls
local controls = {}

local function bool(v) return v and 1 or 0 end
local function text(key, fallback)
    if FS25E_Localization and FS25E_Localization.t then return FS25E_Localization.t(key, fallback) end
    return fallback or key
end

function M.init()
    controls = {}
    local languages = { 'auto', 'de', 'en' }
    local language = {
        id = 'uiLanguage', category = 'presets', min = 1, max = 3, step = 1, kind = 'enum', cost = 'low',
        applyMode = 'SESSION', runtimeControl = true, noGlobalRestore = true,
        labelKey = 'FS25E_setting_uiLanguage', tooltipKey = 'FS25E_tooltip_uiLanguage',
        available = function() return FS25E_Localization ~= nil and FS25E_ModSettings ~= nil, 'FS25E_status_api_unavailable' end,
        read = function()
            local current = FS25E_Localization and FS25E_Localization.getLanguageSetting and FS25E_Localization.getLanguageSetting() or 'auto'
            for i, v in ipairs(languages) do if v == current then return i end end
            return 1
        end,
        write = function(v)
            local code = languages[math.floor(v + .5)]
            if not code or not FS25E_Localization or not FS25E_Localization.setLanguage then return false, 'FS25E_status_api_unavailable' end
            return FS25E_Localization.setLanguage(code)
        end,
        restore = function() return true end,
        format = function(v) return text('FS25E_value_language_' .. (languages[math.floor(v + .5)] or 'auto')) end
    }
    controls[#controls + 1] = language

    controls[#controls + 1] = {
        id = 'hideUnavailable', category = 'presets', min = 0, max = 1, step = 1, kind = 'bool', cost = 'low',
        applyMode = 'SESSION', runtimeControl = true, noGlobalRestore = true,
        labelKey = 'FS25E_setting_hideUnavailable', tooltipKey = 'FS25E_tooltip_hideUnavailable',
        available = function() return FS25E_ModSettings ~= nil, 'FS25E_status_api_unavailable' end,
        read = function() return bool(FS25E_ModSettings.get('hideUnavailable') ~= false) end,
        write = function(v)
            local ok = FS25E_ModSettings.set('hideUnavailable', v >= .5)
            if ok and FS25E_ModSettings.save then pcall(FS25E_ModSettings.save) end
            return ok
        end,
        restore = function() return true end
    }

    controls[#controls + 1] = {
        id = 'enhanced-debug-hud', category = 'performance', min = 0, max = 1, step = 1, kind = 'bool', cost = 'low',
        applyMode = 'SESSION', runtimeControl = true, noGlobalRestore = true,
        labelKey = 'FS25E_setting_debugHud', tooltipKey = 'FS25E_tooltip_debugHud',
        available = function() return FS25E_ModSettings ~= nil, 'FS25E_status_api_unavailable' end,
        read = function() return bool(FS25E_ModSettings.get('liveTuningEnabled') == true) end,
        write = function(v) return FS25E_ModSettings.set('liveTuningEnabled', v >= .5) end,
        restore = function() return true end
    }
end

function M.getControls()
    if #controls == 0 then M.init() end
    return controls
end

function M.reset() controls = {} end
