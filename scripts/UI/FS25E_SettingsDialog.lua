-- FS25_Enhanced / UI/FS25E_SettingsDialog.lua
-- Gen-1 Settings MessageDialog: Simple / Advanced / Expert / Status.
-- Hover-help: Schema tooltip → element.toolTipText + visible helpText footer.
-- Assumptions:
--  * Extends MessageDialog (not DialogElement).
--  * MultiTextOption: setTexts() in Lua; onClick passes 1-based state.
--  * Tab via sectionSelector MultiTextOption (no Slider).
--  * Expert experimental rows visible only when expertMode ON.
--  * Status tab read-only from Diagnostics.getSnapshot() (CapabilityRegistry fallback).

FS25E_SettingsDialog = {}

local FS25E_SettingsDialog_mt = Class(FS25E_SettingsDialog, MessageDialog)

local TAB_SIMPLE = 1
local TAB_ADVANCED = 2
local TAB_EXPERT = 3
local TAB_STATUS = 4

local SIMPLE_IDS = { "enabled", "preset", "targetFps", "adaptive" }
local ADVANCED_IDS = {
    "shadowQuality", "shadowDistance", "maxShadowLights", "foliageShadows", "softShadows",
    "maxLights", "lightScattering", "shadowMerge",
    "viewDistance", "lodDistance", "foliageViewDistance", "foliageLodDistance", "terrainLodDistance",
}
local EXPERT_IDS = { "expertMode", "persistHardware", "expertSoftApply", "shadowFocus", "fastShadowUpdate", "rainShallowWater" }

function FS25E_SettingsDialog.new(target, custom_mt)
    local self = MessageDialog.new(target, custom_mt or FS25E_SettingsDialog_mt)
    self.currentTab = TAB_SIMPLE
    self._suppressCallbacks = false
    self._widgetMap = {}
    return self
end

local function fieldMeta(id)
    if FS25E_SettingsSchema ~= nil and FS25E_SettingsSchema.getField ~= nil then
        return FS25E_SettingsSchema.getField(id)
    end
    return nil
end

function FS25E_SettingsDialog:onCreate()
    if MessageDialog.onCreate ~= nil then
        MessageDialog.onCreate(self)
    elseif FS25E_SettingsDialog:superClass().onCreate ~= nil then
        FS25E_SettingsDialog:superClass().onCreate(self)
    end
    self:_collectWidgets()
    self:_setupTabSelector()
    self:_setupAllOptionWidgets()
end

function FS25E_SettingsDialog:_collectWidgets()
    self._widgetMap = {}
    local ids = {}
    for i = 1, #SIMPLE_IDS do ids[#ids + 1] = SIMPLE_IDS[i] end
    for i = 1, #ADVANCED_IDS do ids[#ids + 1] = ADVANCED_IDS[i] end
    for i = 1, #EXPERT_IDS do ids[#ids + 1] = EXPERT_IDS[i] end
    for i = 1, #ids do
        local id = ids[i]
        local el = self[id .. "Option"]
        if el ~= nil then
            self._widgetMap[id] = el
        end
    end
end

function FS25E_SettingsDialog:_setupTabSelector()
    if self.sectionSelector == nil then
        return
    end
    local t = function(k, f)
        if FS25E_SettingsController ~= nil then
            return FS25E_SettingsController.t(k, f)
        end
        return f
    end
    local texts = {
        t("FS25E_SETTINGS_SIMPLE", "Simple"),
        t("FS25E_SETTINGS_ADVANCED", "Advanced"),
        t("FS25E_SETTINGS_EXPERT", "Expert"),
        t("FS25E_SETTINGS_STATUS", "Status"),
    }
    if self.sectionSelector.setTexts ~= nil then
        self.sectionSelector:setTexts(texts)
    end
    if self.sectionSelector.setState ~= nil then
        self.sectionSelector:setState(self.currentTab, true)
    end
end

function FS25E_SettingsDialog:_setupAllOptionWidgets()
    for id, el in pairs(self._widgetMap) do
        local field = fieldMeta(id)
        if field ~= nil and el.setTexts ~= nil and FS25E_SettingsController ~= nil then
            el:setTexts(FS25E_SettingsController.getOptionTexts(field))
        end
        el._fs25eSettingId = id
        el._fs25eField = field
        self:_applyElementTooltip(el, field, id)
    end
end

function FS25E_SettingsDialog:_applyElementTooltip(el, field, id)
    if el == nil or FS25E_SettingsController == nil then
        return
    end
    local tip = FS25E_SettingsController.getTooltipText(field or id)
    if tip == nil or tip == "" then
        return
    end
    if el.setToolTipText ~= nil then
        pcall(function() el:setToolTipText(tip) end)
    elseif el.setTooltipText ~= nil then
        pcall(function() el:setTooltipText(tip) end)
    else
        el.toolTipText = tip
        el.tooltipText = tip
    end
end

function FS25E_SettingsDialog:_setHelpForId(id)
    local tip = ""
    if id ~= nil and FS25E_SettingsController ~= nil then
        tip = FS25E_SettingsController.getTooltipText(id) or ""
    end
    if tip == "" then
        if FS25E_SettingsController ~= nil then
            tip = FS25E_SettingsController.t("FS25E_HELP_HINT", "Select an option to see a short explanation.")
        else
            tip = "Select an option to see a short explanation."
        end
    end
    -- Truncate for footer readability (~160 chars / ~2 lines)
    if #tip > 160 then
        tip = string.sub(tip, 1, 157) .. "…"
    end
    self._helpSettingId = id
    if self.helpText ~= nil and self.helpText.setText ~= nil then
        self.helpText:setText(tip)
    elseif self.tooltipLine ~= nil and self.tooltipLine.setText ~= nil then
        self.tooltipLine:setText(tip)
    end
end

function FS25E_SettingsDialog:_defaultHelpForTab()
    local tab = self.currentTab
    local first = nil
    if tab == TAB_SIMPLE then
        first = SIMPLE_IDS[1]
    elseif tab == TAB_ADVANCED then
        first = ADVANCED_IDS[1]
    elseif tab == TAB_EXPERT then
        first = EXPERT_IDS[1]
    else
        first = nil
    end
    self:_setHelpForId(first)
end

function FS25E_SettingsDialog:onOpen()
    if MessageDialog.onOpen ~= nil then
        MessageDialog.onOpen(self)
    elseif FS25E_SettingsDialog:superClass().onOpen ~= nil then
        FS25E_SettingsDialog:superClass().onOpen(self)
    end
    self:_refreshFromStore()
    self:_applyTabVisibility()
    self:_refreshStatusText()
    self:_defaultHelpForTab()
end

function FS25E_SettingsDialog:onClose()
    if MessageDialog.onClose ~= nil then
        MessageDialog.onClose(self)
    elseif FS25E_SettingsDialog:superClass().onClose ~= nil then
        FS25E_SettingsDialog:superClass().onClose(self)
    end
end

function FS25E_SettingsDialog:_refreshFromStore()
    self._suppressCallbacks = true
    for id, el in pairs(self._widgetMap) do
        local field = fieldMeta(id)
        if field ~= nil and el.setState ~= nil and FS25E_SettingsController ~= nil then
            local value = FS25E_SettingsController.get(id)
            local state = FS25E_SettingsController.valueToState(field, value)
            el:setState(state, true)
        end
    end
    self._suppressCallbacks = false
end

function FS25E_SettingsDialog:_setPanelVisible(panel, visible)
    if panel ~= nil and panel.setVisible ~= nil then
        panel:setVisible(visible == true)
    end
end

function FS25E_SettingsDialog:_applyTabVisibility()
    local tab = self.currentTab
    self:_setPanelVisible(self.simplePanel, tab == TAB_SIMPLE)
    self:_setPanelVisible(self.advancedPanel, tab == TAB_ADVANCED)
    self:_setPanelVisible(self.expertPanel, tab == TAB_EXPERT)
    self:_setPanelVisible(self.statusPanel, tab == TAB_STATUS)

    local expertOn = FS25E_SettingsController ~= nil and FS25E_SettingsController.isExpertMode()
    local experimental = { "shadowFocus", "fastShadowUpdate", "rainShallowWater" }
    for i = 1, #experimental do
        local id = experimental[i]
        local el = self._widgetMap[id]
        local row = self[id .. "Row"]
        local vis = (tab == TAB_EXPERT) and expertOn
        if el ~= nil and el.setVisible ~= nil then
            el:setVisible(vis)
        end
        if row ~= nil and row.setVisible ~= nil then
            row:setVisible(vis)
        end
    end
end

function FS25E_SettingsDialog:_refreshStatusText()
    if self.statusText == nil then
        return
    end
    local rows = {}
    if FS25E_SettingsController ~= nil then
        rows = FS25E_SettingsController.getStatusRows()
    end
    local t = function(k, f)
        if FS25E_SettingsController ~= nil then
            return FS25E_SettingsController.t(k, f)
        end
        return f
    end
    local lines = {}
    lines[#lines + 1] = t("FS25E_STATUS_HEADER", "Capability status (read-only)")
    if #rows == 0 then
        lines[#lines + 1] = t("FS25E_STATUS_EMPTY", "No capability data (Diagnostics/Registry unavailable).")
    else
        local maxLines = 24
        for i = 1, math.min(#rows, maxLines) do
            lines[#lines + 1] = FS25E_SettingsController.formatStatusLine(rows[i])
        end
        if #rows > maxLines then
            lines[#lines + 1] = string.format("… (+%d)", #rows - maxLines)
        end
    end
    local text = table.concat(lines, "\n")
    if self.statusText.setText ~= nil then
        self.statusText:setText(text)
    end
end

function FS25E_SettingsDialog:onClickSection(state)
    if self._suppressCallbacks then
        return
    end
    self.currentTab = tonumber(state) or TAB_SIMPLE
    self:_applyTabVisibility()
    if self.currentTab == TAB_STATUS then
        self:_refreshStatusText()
        self:_setHelpForId(nil)
    else
        self:_defaultHelpForTab()
    end
end

function FS25E_SettingsDialog:_onOptionChanged(id, state)
    if self._suppressCallbacks then
        return
    end
    local field = fieldMeta(id)
    if field == nil or FS25E_SettingsController == nil then
        return
    end
    local value = FS25E_SettingsController.stateToValue(field, state)
    FS25E_SettingsController.applyUserChange(id, value, { explicit = true })
    self:_setHelpForId(id)
    if id == "expertMode" then
        self:_applyTabVisibility()
    end
end

function FS25E_SettingsDialog:onClickEnabled(state) self:_onOptionChanged("enabled", state) end
function FS25E_SettingsDialog:onClickPreset(state) self:_onOptionChanged("preset", state) end
function FS25E_SettingsDialog:onClickTargetFps(state) self:_onOptionChanged("targetFps", state) end
function FS25E_SettingsDialog:onClickAdaptive(state) self:_onOptionChanged("adaptive", state) end
function FS25E_SettingsDialog:onClickShadowQuality(state) self:_onOptionChanged("shadowQuality", state) end
function FS25E_SettingsDialog:onClickShadowDistance(state) self:_onOptionChanged("shadowDistance", state) end
function FS25E_SettingsDialog:onClickMaxShadowLights(state) self:_onOptionChanged("maxShadowLights", state) end
function FS25E_SettingsDialog:onClickFoliageShadows(state) self:_onOptionChanged("foliageShadows", state) end
function FS25E_SettingsDialog:onClickSoftShadows(state) self:_onOptionChanged("softShadows", state) end
function FS25E_SettingsDialog:onClickMaxLights(state) self:_onOptionChanged("maxLights", state) end
function FS25E_SettingsDialog:onClickLightScattering(state) self:_onOptionChanged("lightScattering", state) end
function FS25E_SettingsDialog:onClickShadowMerge(state) self:_onOptionChanged("shadowMerge", state) end
function FS25E_SettingsDialog:onClickViewDistance(state) self:_onOptionChanged("viewDistance", state) end
function FS25E_SettingsDialog:onClickLodDistance(state) self:_onOptionChanged("lodDistance", state) end
function FS25E_SettingsDialog:onClickFoliageViewDistance(state) self:_onOptionChanged("foliageViewDistance", state) end
function FS25E_SettingsDialog:onClickFoliageLodDistance(state) self:_onOptionChanged("foliageLodDistance", state) end
function FS25E_SettingsDialog:onClickTerrainLodDistance(state) self:_onOptionChanged("terrainLodDistance", state) end
function FS25E_SettingsDialog:onClickExpertMode(state) self:_onOptionChanged("expertMode", state) end
function FS25E_SettingsDialog:onClickShadowFocus(state) self:_onOptionChanged("shadowFocus", state) end
function FS25E_SettingsDialog:onClickFastShadowUpdate(state) self:_onOptionChanged("fastShadowUpdate", state) end
function FS25E_SettingsDialog:onClickRainShallowWater(state) self:_onOptionChanged("rainShallowWater", state) end


function FS25E_SettingsDialog:onHighlightSection()
    self:_defaultHelpForTab()
end

function FS25E_SettingsDialog:onHighlightOption(element)
    local id = nil
    if type(element) == "table" and element._fs25eSettingId ~= nil then
        id = element._fs25eSettingId
    elseif type(element) == "string" then
        id = element
    end
    if id == nil and type(element) == "table" and element.name ~= nil then
        local n = tostring(element.name)
        if string.sub(n, -6) == "Option" then
            id = string.sub(n, 1, #n - 6)
        end
    end
    if id ~= nil then
        self:_setHelpForId(id)
    end
end

function FS25E_SettingsDialog:onHighlightEnabled() self:_setHelpForId("enabled") end
function FS25E_SettingsDialog:onHighlightPreset() self:_setHelpForId("preset") end
function FS25E_SettingsDialog:onHighlightTargetFps() self:_setHelpForId("targetFps") end
function FS25E_SettingsDialog:onHighlightAdaptive() self:_setHelpForId("adaptive") end
function FS25E_SettingsDialog:onHighlightShadowQuality() self:_setHelpForId("shadowQuality") end
function FS25E_SettingsDialog:onHighlightShadowDistance() self:_setHelpForId("shadowDistance") end
function FS25E_SettingsDialog:onHighlightMaxShadowLights() self:_setHelpForId("maxShadowLights") end
function FS25E_SettingsDialog:onHighlightFoliageShadows() self:_setHelpForId("foliageShadows") end
function FS25E_SettingsDialog:onHighlightSoftShadows() self:_setHelpForId("softShadows") end
function FS25E_SettingsDialog:onHighlightMaxLights() self:_setHelpForId("maxLights") end
function FS25E_SettingsDialog:onHighlightLightScattering() self:_setHelpForId("lightScattering") end
function FS25E_SettingsDialog:onHighlightShadowMerge() self:_setHelpForId("shadowMerge") end
function FS25E_SettingsDialog:onHighlightViewDistance() self:_setHelpForId("viewDistance") end
function FS25E_SettingsDialog:onHighlightLodDistance() self:_setHelpForId("lodDistance") end
function FS25E_SettingsDialog:onHighlightFoliageViewDistance() self:_setHelpForId("foliageViewDistance") end
function FS25E_SettingsDialog:onHighlightFoliageLodDistance() self:_setHelpForId("foliageLodDistance") end
function FS25E_SettingsDialog:onHighlightTerrainLodDistance() self:_setHelpForId("terrainLodDistance") end
function FS25E_SettingsDialog:onHighlightExpertMode() self:_setHelpForId("expertMode") end
function FS25E_SettingsDialog:onHighlightPersistHardware() self:_setHelpForId("persistHardware") end
function FS25E_SettingsDialog:onHighlightExpertSoftApply() self:_setHelpForId("expertSoftApply") end
function FS25E_SettingsDialog:onHighlightShadowFocus() self:_setHelpForId("shadowFocus") end
function FS25E_SettingsDialog:onHighlightFastShadowUpdate() self:_setHelpForId("fastShadowUpdate") end
function FS25E_SettingsDialog:onHighlightRainShallowWater() self:_setHelpForId("rainShallowWater") end

function FS25E_SettingsDialog:onClickPersistHardware(state) self:_onOptionChanged("persistHardware", state) end
function FS25E_SettingsDialog:onClickExpertSoftApply(state) self:_onOptionChanged("expertSoftApply", state) end

--- Expert-tab: enable liveTuning + open overlay (gates still checked inside overlay).
function FS25E_SettingsDialog:onClickLiveOverlay()
    if FS25E_SettingsAPI ~= nil and FS25E_SettingsAPI.set ~= nil then
        FS25E_SettingsAPI.set("liveTuningEnabled", true)
    elseif FS25E_ModSettings ~= nil and FS25E_ModSettings.set ~= nil then
        FS25E_ModSettings.set("liveTuningEnabled", true)
    end
    -- Ensure expertMode remains as-is; overlay.canShow requires both.
    if FS25E_LiveOverlay ~= nil and FS25E_LiveOverlay.toggle ~= nil then
        -- Close settings so overlay draws over world
        self:close()
        FS25E_LiveOverlay.toggle(true)
    end
end

function FS25E_SettingsDialog:onClickOk()
    self:close()
end

function FS25E_SettingsDialog:onClickBack()
    self:close()
end

function FS25E_SettingsDialog:close()
    if g_gui ~= nil then
        if g_gui.closeDialog ~= nil then
            pcall(function() g_gui:closeDialog(self) end)
        elseif self.changeScreen ~= nil then
            pcall(function() self:changeScreen(nil) end)
        elseif g_gui.showGui ~= nil then
            pcall(function() g_gui:showGui("") end)
        end
    end
end
