-- FS25_Enhanced / UI/FS25E_SettingsController.lua
-- Final dock: Prefer-Path ModSettings.get/set; SettingsAPI.set for side-effects (facade).
-- No engine setters from GUI.

FS25E_SettingsController = {}

local function dbg(msg)
    if FS25E_Debug ~= nil then
        FS25E_Debug.info("SettingsUI", tostring(msg))
    end
end

local function i18n(key, fallback)
    if g_i18n ~= nil and g_i18n.getText ~= nil and key ~= nil then
        local t = g_i18n:getText(key)
        if t ~= nil and t ~= "" and t ~= key then
            return t
        end
    end
    return fallback or key or ""
end

local function hasSettingsAPI()
    return FS25E_SettingsAPI ~= nil and FS25E_SettingsAPI.get ~= nil and FS25E_SettingsAPI.set ~= nil
end

-- Keep Wave-1 GUI id and Expert Soft-Apply id in sync (same cap).
local DUAL_SETTING_KEYS = {
    rainShallowWater = "expertRainShallowWater",
    expertRainShallowWater = "rainShallowWater",
}

local function mirrorDualKey(id, value)
    local other = DUAL_SETTING_KEYS[id]
    if other == nil then
        return
    end
    if FS25E_ModSettings ~= nil and FS25E_ModSettings.set ~= nil then
        pcall(function() FS25E_ModSettings.set(other, value) end)
    end
    if hasSettingsAPI() then
        pcall(function() FS25E_SettingsAPI.set(other, value) end)
    end
end

-- Prefer-Path: ModSettings.get/set (SettingsAPI is facade over the same store).
function FS25E_SettingsController.get(id)
    if FS25E_ModSettings ~= nil and FS25E_ModSettings.get ~= nil then
        return FS25E_ModSettings.get(id)
    end
    if hasSettingsAPI() then
        return FS25E_SettingsAPI.get(id)
    end
    return nil
end

function FS25E_SettingsController.getAll()
    if FS25E_ModSettings ~= nil and FS25E_ModSettings.getAll ~= nil then
        return FS25E_ModSettings.getAll()
    end
    if hasSettingsAPI() and FS25E_SettingsAPI.getAll ~= nil then
        return FS25E_SettingsAPI.getAll()
    end
    return {}
end

local function persist()
    if hasSettingsAPI() and FS25E_SettingsAPI.save ~= nil then
        pcall(FS25E_SettingsAPI.save)
        return
    end
    if FS25E_ModSettings ~= nil then
        if FS25E_ModSettings.save ~= nil then
            pcall(FS25E_ModSettings.save)
        elseif FS25E_ModSettings.saveStub ~= nil then
            pcall(FS25E_ModSettings.saveStub)
        end
    end
end

function FS25E_SettingsController.applyUserChange(id, value, opts)
    opts = opts or {}
    if id == nil then
        return false
    end

    if hasSettingsAPI() then
        local ok = FS25E_SettingsAPI.set(id, value)
        if not ok then
            dbg("SettingsAPI.set rejected id=" .. tostring(id))
            return false
        end

        -- adaptive is the user-facing toggle; keep autoApply in sync explicitly
        if id == "adaptive" then
            FS25E_SettingsAPI.setAutoApply(value == true)
        elseif id == "preset" then
            FS25E_SettingsController.applyPresetSelection(value, opts.explicit == true)
        elseif id == "targetFps" then
            FS25E_SettingsController.applyTargetFps(value)
        end

        if FS25E_SettingsCache ~= nil and FS25E_SettingsCache.setRequested ~= nil then
            FS25E_SettingsCache.setRequested(id, value)
        end

        mirrorDualKey(id, value)
        persist()
        dbg(string.format("applyUserChange(api) id=%s value=%s", tostring(id), tostring(value)))
        return true
    end

    -- Fallback path (pre-#14 main): ModSettings + Governor wrappers only
    if FS25E_ModSettings == nil or FS25E_ModSettings.set == nil then
        dbg("applyUserChange aborted: ModSettings/SettingsAPI missing")
        return false
    end

    local ok = FS25E_ModSettings.set(id, value)
    if not ok then
        dbg("ModSettings.set rejected id=" .. tostring(id))
        return false
    end

    if FS25E_SettingsCache ~= nil and FS25E_SettingsCache.setRequested ~= nil then
        FS25E_SettingsCache.setRequested(id, value)
    end

    mirrorDualKey(id, value)

    if id == "enabled" then
        if FS25E_GraphicsGovernor ~= nil and FS25E_GraphicsGovernor.setEnabled ~= nil then
            FS25E_GraphicsGovernor.setEnabled(value == true)
        end
    elseif id == "adaptive" then
        if FS25E_GraphicsGovernor ~= nil and FS25E_GraphicsGovernor.setAutoApply ~= nil then
            FS25E_GraphicsGovernor.setAutoApply(value == true)
        end
    elseif id == "preset" then
        FS25E_SettingsController.applyPresetSelection(value, opts.explicit == true)
    elseif id == "targetFps" then
        FS25E_SettingsController.applyTargetFps(value)
    end

    persist()
    dbg(string.format("applyUserChange(fallback) id=%s value=%s", tostring(id), tostring(value)))
    return true
end

function FS25E_SettingsController.applyPresetSelection(presetName, explicit)
    if presetName == nil or presetName == "" or presetName == "Off" then
        dbg("preset Off — store only")
        if explicit then
            if hasSettingsAPI() then
                FS25E_SettingsAPI.setAutoApply(false)
            elseif FS25E_GraphicsGovernor ~= nil and FS25E_GraphicsGovernor.setAutoApply ~= nil then
                FS25E_GraphicsGovernor.setAutoApply(false)
            end
        end
        return true
    end

    if hasSettingsAPI() then
        if FS25E_SettingsAPI.selectPreset ~= nil then
            FS25E_SettingsAPI.selectPreset(presetName)
        end
        if explicit then
            -- Manual preset: turn Adaptive off (one-shot apply, no ongoing auto)
            if FS25E_SettingsAPI.set ~= nil then
                FS25E_SettingsAPI.set("adaptive", false)
            end
            FS25E_SettingsAPI.setAutoApply(false)
            local enabled = FS25E_SettingsAPI.getEnabled ~= nil and FS25E_SettingsAPI.getEnabled()
            if enabled and FS25E_GraphicsGovernor ~= nil and FS25E_GraphicsGovernor.applyPreset ~= nil then
                FS25E_GraphicsGovernor.applyPreset(presetName, true)
            elseif enabled and FS25E_SettingsAPI.applySelectedPreset ~= nil then
                FS25E_SettingsAPI.applySelectedPreset()
            else
                dbg("preset selected; apply skipped (governor disabled)")
            end
        end
        return true
    end

    if FS25E_ProfileManager ~= nil and FS25E_ProfileManager.selectPreset ~= nil then
        FS25E_ProfileManager.selectPreset(presetName)
    end

    if explicit and FS25E_GraphicsGovernor ~= nil then
        if FS25E_ModSettings ~= nil then
            FS25E_ModSettings.set("adaptive", false)
            FS25E_ModSettings.set("autoApply", false)
        end
        if FS25E_GraphicsGovernor.setAutoApply ~= nil then
            FS25E_GraphicsGovernor.setAutoApply(false)
        end
        local enabled = FS25E_GraphicsGovernor.isEnabled ~= nil and FS25E_GraphicsGovernor.isEnabled()
        if enabled and FS25E_GraphicsGovernor.applyPreset ~= nil then
            FS25E_GraphicsGovernor.applyPreset(presetName, true)
        else
            dbg("preset selected into cache; applyPreset skipped (governor disabled)")
        end
    end
    return true
end

function FS25E_SettingsController.applyTargetFps(value)
    if FS25E_PerformanceMonitor == nil then
        return
    end
    local fps = tonumber(value)
    if value == "unlimited" or fps == nil then
        if FS25E_PerformanceMonitor.setTargetFps ~= nil then
            FS25E_PerformanceMonitor.setTargetFps(240)
        end
        return
    end
    if FS25E_PerformanceMonitor.setTargetFps ~= nil then
        FS25E_PerformanceMonitor.setTargetFps(fps)
    elseif FS25E_PerformanceMonitor.init ~= nil then
        FS25E_PerformanceMonitor.init(fps)
    end
end

function FS25E_SettingsController.isExpertMode()
    if hasSettingsAPI() and FS25E_SettingsAPI.getExpertMode ~= nil then
        return FS25E_SettingsAPI.getExpertMode()
    end
    return FS25E_SettingsController.get("expertMode") == true
end

function FS25E_SettingsController.getOptionTexts(field)
    if field == nil then
        return {}
    end
    if field.type == "bool" then
        return { i18n("ui_off", "Off"), i18n("ui_on", "On") }
    end
    local texts = {}
    local opts = field.options or {}
    for i = 1, #opts do
        local opt = opts[i]
        local key = field.optionI18nKeys and field.optionI18nKeys[opt]
        texts[#texts + 1] = i18n(key, tostring(opt))
    end
    return texts
end

function FS25E_SettingsController.valueToState(field, value)
    if field == nil then
        return 1
    end
    if field.type == "bool" then
        return (value == true) and 2 or 1
    end
    local opts = field.options or {}
    for i = 1, #opts do
        if tostring(opts[i]) == tostring(value) then
            return i
        end
    end
    return 1
end

function FS25E_SettingsController.stateToValue(field, state)
    if field == nil then
        return nil
    end
    if field.type == "bool" then
        return state == 2
    end
    local opts = field.options or {}
    local idx = tonumber(state) or 1
    return opts[idx]
end

function FS25E_SettingsController.getStatusRows()
    if FS25E_Diagnostics ~= nil and FS25E_Diagnostics.getSnapshot ~= nil then
        return FS25E_Diagnostics.getSnapshot()
    end
    local rows = {}
    if FS25E_CapabilityRegistry == nil or FS25E_CapabilityRegistry.all == nil then
        return rows
    end
    for id, entry in pairs(FS25E_CapabilityRegistry.all()) do
        local status = entry.status
        local lastResult = "SKIPPED"
        local lastError = nil
        local s = tostring(status or ""):upper()
        if s == "REJECTED" or s == "UNSUPPORTED" then
            lastResult = "REJECTED"
            lastError = entry.notes
        end
        rows[#rows + 1] = {
            id = id,
            status = status,
            lastResult = lastResult,
            lastError = lastError,
        }
    end
    table.sort(rows, function(a, b)
        return tostring(a.id) < tostring(b.id)
    end)
    return rows
end

function FS25E_SettingsController.formatStatusLine(row)
    if row == nil then
        return ""
    end
    local result = tostring(row.lastResult or "SKIPPED")
    local label
    if result == "APPLIED" then
        label = i18n("FS25E_STATUS_APPLIED", "APPLIED")
    elseif result == "REJECTED" then
        label = i18n("FS25E_STATUS_REJECTED", "REJECTED")
    else
        label = i18n("FS25E_STATUS_SKIPPED", "SKIPPED")
    end
    local err = row.lastError and (" — " .. tostring(row.lastError)) or ""
    return string.format("%s [%s] %s%s", tostring(row.id), tostring(row.status), label, err)
end

function FS25E_SettingsController.t(key, fallback)
    return i18n(key, fallback)
end

--- Resolve player-facing tooltip for a schema field table or setting id.
--- Prefer Schema.tooltip i18n key; fall back to l10n.."_TOOLTIP".
function FS25E_SettingsController.getTooltipText(fieldOrId)
    local field = fieldOrId
    if type(fieldOrId) == "string" then
        field = nil
        if FS25E_SettingsSchema ~= nil and FS25E_SettingsSchema.getField ~= nil then
            field = FS25E_SettingsSchema.getField(fieldOrId)
        end
        if field == nil then
            local asKey = i18n(fieldOrId, "")
            if asKey ~= nil and asKey ~= "" and asKey ~= fieldOrId then
                return asKey
            end
            return ""
        end
    end
    if type(field) ~= "table" then
        return ""
    end
    local key = field.tooltip
    if key ~= nil and key ~= "" then
        local tip = i18n(key, nil)
        if tip ~= nil and tip ~= "" and tip ~= key then
            return tip
        end
    end
    if field.l10n ~= nil and field.l10n ~= "" then
        local alt = tostring(field.l10n) .. "_TOOLTIP"
        local tip = i18n(alt, nil)
        if tip ~= nil and tip ~= "" and tip ~= alt then
            return tip
        end
    end
    if field.warningL10n ~= nil and field.warningL10n ~= "" then
        local tip = i18n(field.warningL10n, nil)
        if tip ~= nil and tip ~= "" and tip ~= field.warningL10n then
            return tip
        end
    end
    return ""
end

--- Resolve help by settingId and/or capability id (Schema first, then CostCatalog notes).
function FS25E_SettingsController.getHelpForSettingOrCap(settingId, capId)
    local tip = ""
    if settingId ~= nil and settingId ~= "" then
        tip = FS25E_SettingsController.getTooltipText(settingId)
    end
    if (tip == nil or tip == "") and capId ~= nil and FS25E_SettingsSchema ~= nil and FS25E_SettingsSchema.getSchema ~= nil then
        local schema = FS25E_SettingsSchema.getSchema()
        for i = 1, #schema do
            local f = schema[i]
            if f.capId ~= nil and tostring(f.capId) == tostring(capId) then
                tip = FS25E_SettingsController.getTooltipText(f)
                break
            end
        end
    end
    if tip ~= nil and tip ~= "" then
        return tip
    end
    if capId ~= nil and FS25E_CostCatalog ~= nil and FS25E_CostCatalog.get ~= nil then
        local e = FS25E_CostCatalog.get(capId)
        if e ~= nil then
            if e.helpL10n ~= nil and e.helpL10n ~= "" then
                local h = i18n(e.helpL10n, nil)
                if h ~= nil and h ~= "" and h ~= e.helpL10n then
                    return h
                end
            end
            if e.notes ~= nil and e.notes ~= "" then
                return tostring(e.notes)
            end
        end
    end
    return ""
end

