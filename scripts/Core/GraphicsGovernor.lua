-- Manual graphics session; compatibility facade for previous saves and console commands.
FS25E_GraphicsGovernor={MODE={FAST='FAST',MEDIUM='MEDIUM',SLOW='SLOW'}}
local M=FS25E_GraphicsGovernor
local enabled,lastAppliedPreset=false,nil
local desiredPreset='Balanced'
function M.init()
    enabled=false; lastAppliedPreset=nil
    desiredPreset=FS25E_ProfileManager and FS25E_ProfileManager.getActiveName() or 'Balanced'
end
function M.setEnabled(value)
    local was=enabled; enabled=value==true
    if was and not enabled then
        if FS25E_ProfileManager and FS25E_ProfileManager.cancelPending then FS25E_ProfileManager.cancelPending() end
        lastAppliedPreset=nil
        if FS25E_RestoreManager and FS25E_RestoreManager.restoreAll then return FS25E_RestoreManager.restoreAll() end
    end
    return true
end
function M.isEnabled() return enabled end
function M.setAutoApply() return false,'manual-mode' end
function M.isAutoApply() return false end
function M.setDebugLog() end
function M.setObserveAlways() end
function M.isObserveAlways() return false end
function M.getMode() return 'MANUAL' end
function M.getDesiredMode() return 'MANUAL' end
function M.getDesiredPreset() return desiredPreset end
function M.getDecisionTicks() return 0 end
function M.getLastAppliedPreset() return lastAppliedPreset end
function M.getLastDecision() return nil end
function M.suggestMode() return 'MANUAL' end
function M.applyPreset(name)
    if FS25E_VisualProfiles and FS25E_VisualProfiles.isComparing and FS25E_VisualProfiles.isComparing() then return false,'comparison-active' end
    local profiles=FS25E_ProfileManager
    if not profiles or not profiles.selectPreset or not profiles.applySelected then return false,'profile-manager-unavailable' end
    if not profiles.selectPreset(name) then return false,'unknown-preset' end
    if FS25E_ModSettings then FS25E_ModSettings.set('enabled',true); FS25E_ModSettings.set('preset',name) end
    M.setEnabled(true)
    -- An explicit choice always reapplies, including after an edit to the same preset.
    local ok,err=profiles.applySelected(true)
    desiredPreset=name
    if ok then lastAppliedPreset=name end
    return ok,err=='partial-apply' and 'FS25E_status_profile_partial' or err
end
function M.startCalibration() return false,'manual-mode' end
function M.beginCinematic() return M.applyPreset('Cinematic') end
function M.endCinematic() return true end
function M.getCinematicStatus() return {active=false,remainingMs=0} end
function M.update(dt)
    if type(dt)~='number' or dt~=dt or dt<=0 or dt>1000 then return end
    if FS25E_CompatibilityManager and FS25E_CompatibilityManager.update then FS25E_CompatibilityManager.update(dt) end
    if enabled and FS25E_ProfileManager and FS25E_ProfileManager.update then FS25E_ProfileManager.update(dt) end
end
function M.reset() enabled=false; lastAppliedPreset=nil end
