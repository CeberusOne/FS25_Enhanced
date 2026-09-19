-- Reversible A/B preview and a local snapshot file. Never writes game.xml.
FS25E_VisualProfiles = {}
local M = FS25E_VisualProfiles
local compare = nil

local function profilePath()
    return FS25E_ModSettings.getFilePath('liveProfile.xml')
end

function M.save()
    if compare then return false, 'FS25E_status_compare_original' end
    if not createXMLFile or not setXMLString or not setXMLBool or not saveXMLFile then return false, 'FS25E_status_profile_unavailable' end
    FS25E_ModSettings.save()
    local xml = createXMLFile('FS25E_liveProfile', profilePath(), 'profile')
    if not xml or xml == 0 then return false, 'FS25E_status_profile_unavailable' end
    local i = 0
    for _, c in ipairs(FS25E_VisualControls.getControls()) do
        local value = FS25E_VisualControls.read(c)
        if not c.runtimeControl and c.kind ~= 'action' and not c.profileSelector and value ~= nil and FS25E_VisualControls.available(c) then
            local key = 'profile.control(' .. i .. ')'
            setXMLString(xml, key .. '#id', c.id)
            if c.toStored then value = c.toStored(value); setXMLBool(xml, key .. '#native', true) end
            setXMLString(xml, key .. '#value', string.format('%.9g', value))
            setXMLBool(xml, key .. '#locked', FS25E_VisualControls.isLocked(c.id))
            i = i + 1
        end
    end
    saveXMLFile(xml)
    if deleteXMLFile then deleteXMLFile(xml) end
    return true, 'FS25E_status_profile_saved'
end

function M.load()
    if compare then return false, 'FS25E_status_compare_original' end
    if not loadXMLFile or not getXMLString or not getXMLBool or (fileExists and not fileExists(profilePath())) then
        return false, 'FS25E_status_profile_missing'
    end
    local xml = loadXMLFile('FS25E_liveProfile', profilePath())
    if not xml or xml == 0 then return false, 'FS25E_status_profile_missing' end
    local i, failed = 0, 0
    while i < 512 do
        local key = 'profile.control(' .. i .. ')'
        local id = getXMLString(xml, key .. '#id')
        if not id then break end
        local c = FS25E_VisualControls.get(id)
        local value = tonumber(getXMLString(xml, key .. '#value'))
        if c and c.fromStored and getXMLBool(xml, key .. '#native') then value = c.fromStored(value) end
        if c and not c.runtimeControl and value then
            if FS25E_VisualControls.apply(id, value) then FS25E_VisualControls.setLocked(id, false)
            else failed = failed + 1 end
        else failed = failed + 1 end
        i = i + 1
    end
    if deleteXMLFile then deleteXMLFile(xml) end
    return failed == 0, failed == 0 and 'FS25E_status_profile_loaded' or 'FS25E_status_profile_partial'
end

function M.toggleCompare()
    if compare then
        local saved = compare
        compare = nil
        local success = true
        for _, item in ipairs(saved) do
            local ok = FS25E_VisualControls.apply(item.id, item.value)
            FS25E_VisualControls.setLocked(item.id, item.locked)
            success = ok and success
        end
        if FS25E_ModuleRuntime then FS25E_ModuleRuntime.setSuspended(false) end
        return success, success and 'FS25E_status_compare_enhanced' or 'FS25E_status_profile_partial'
    end
    compare = {}
    for _, c in ipairs(FS25E_VisualControls.getControls()) do
        local state = FS25E_VisualControls.getState(c.id)
        local value = FS25E_VisualControls.read(c)
        local explicit = c.provider and c.provider.getRequestedValues and c.provider.getRequestedValues()[c.id]
        if not c.runtimeControl and not c.profileSelector and c.kind ~= 'action' and ((state and state.original ~= nil) or explicit ~= nil) and value ~= nil then
            compare[#compare + 1] = { id = c.id, value = value, locked = FS25E_VisualControls.isLocked(c.id) }
        end
    end
    if FS25E_ModuleRuntime then FS25E_ModuleRuntime.setSuspended(true) end
    local ok = true
    if FS25E_ModuleRuntime then ok = FS25E_ModuleRuntime.restoreAll() end
    if FS25E_CapabilityApplier then ok = FS25E_CapabilityApplier.restoreAll() and ok end
    if FS25E_GameSettingsControls and FS25E_GameSettingsControls.restoreAll then
        ok = FS25E_GameSettingsControls.restoreAll() and ok
    end
    for _, item in ipairs(compare) do
        local state = FS25E_VisualControls.getState(item.id)
        if state and state.original ~= nil and not FS25E_VisualControls.restore(item.id) then ok = false end
    end
    return ok, ok and 'FS25E_status_compare_original' or 'FS25E_status_restore_failed'
end

function M.isComparing() return compare ~= nil end
function M.endCompare() if compare then return M.toggleCompare() end; return true end
function M.reset() compare = nil; if FS25E_ModuleRuntime then FS25E_ModuleRuntime.setSuspended(false) end end

function M.getControls()
    local out = {}
    local defs = {
        { 'compareToggle', 'presets', M.toggleCompare },
        { 'saveProfile', 'presets', M.save },
        { 'loadProfile', 'presets', M.load },
        { 'resetAll', 'presets', function()
            if compare then M.endCompare() end
            local ok = true
            if FS25E_ModuleRuntime then ok = FS25E_ModuleRuntime.restoreAll() and ok end
            if FS25E_CapabilityApplier then ok = FS25E_CapabilityApplier.restoreAll() and ok end
            if FS25E_VisualControls then ok = FS25E_VisualControls.restoreAll() and ok end
            if FS25E_GameSettingsControls and FS25E_GameSettingsControls.restoreAll then
                ok = FS25E_GameSettingsControls.restoreAll() and ok
            end
            if FS25E_QualityLevels then FS25E_QualityLevels.index = 0 end
            if FS25E_ModSettings then FS25E_ModSettings.set('qualityLevel', 0); FS25E_ModSettings.set('enabled', true) end
            for _, c in ipairs(FS25E_VisualControls.getControls()) do
                if not c.runtimeControl then FS25E_VisualControls.setLocked(c.id, false) end
            end
            return ok, ok and 'FS25E_status_restored' or 'FS25E_status_restore_failed'
        end },
        { 'resetCategory', 'presets', function()
            if compare then return false, 'FS25E_status_compare_original' end
            local cat = FS25E_LiveOverlay and FS25E_LiveOverlay.currentCategory and FS25E_LiveOverlay.currentCategory()
            if not cat then return false, 'FS25E_status_api_unavailable' end
            local ok = FS25E_VisualControls.restoreCategory(cat)
            return ok, ok and 'FS25E_status_restored' or 'FS25E_status_restore_failed'
        end }
    }
    for _, d in ipairs(defs) do
        out[#out + 1] = {
            id = d[1], category = d[2], kind = 'action', cost = 'low', runtimeControl = true, noGlobalRestore = true,
            labelKey = 'FS25E_setting_' .. d[1], tooltipKey = 'FS25E_tooltip_' .. d[1],
            run = d[3], available = function() return true end
        }
    end
    return out
end
