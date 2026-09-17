-- Mod configuration exposed through the same live panel; these are not engine hardware settings.
FS25E_RuntimeControls={}
local M=FS25E_RuntimeControls
local controls,originals={},{}
local presets={'Performance','Balanced','Quality','Cinematic'}
local function boolean(v) return v and 1 or 0 end
local function text(key,fallback)
    if FS25E_Localization and FS25E_Localization.t then return FS25E_Localization.t(key) end
    if g_i18n and g_i18n.getText then return g_i18n:getText(key) end
    return fallback or key
end
local function add(id,key,category,min,max,step,kind,read,write,label,tooltip)
    local c={id=id,key=key,category=category,min=min,max=max,step=step,kind=kind,cost='low',applyMode='SESSION',
        labelKey=label,tooltipKey=tooltip,runtimeControl=true,noGlobalRestore=true,noCinematic=true}
    c.available=function() return FS25E_GraphicsGovernor~=nil and FS25E_ModSettings~=nil,'FS25E_status_api_unavailable' end
    c.read=read
    c.write=function(value)
        if originals[id]==nil then originals[id]=read() end
        return write(value)
    end
    c.restore=function()
        if originals[id]==nil then return true end
        local ok=write(originals[id]); if ok then originals[id]=nil end; return ok
    end
    controls[#controls+1]=c; return c
end
function M.init()
    controls={}; originals={}
    local preset=add('enhanced-preset','preset','presets',1,4,1,'enum',function()
        local name=FS25E_ProfileManager and FS25E_ProfileManager.getActiveName()
        for i,v in ipairs(presets) do if v==name then return i end end
        return 2
    end,function(v)
        local name=presets[math.floor(v+.5)]; if not name then return false,'FS25E_status_invalid_value' end
        if FS25E_GraphicsGovernor.getCinematicStatus().active then FS25E_GraphicsGovernor.endCinematic() end
        -- Choosing a profile is an explicit application, including persistent Cinematic.
        return FS25E_GraphicsGovernor.applyPreset(name,name=='Cinematic' and 'allowCinematic' or 'force')
    end,'FS25E_SETTING_PRESET','FS25E_SETTING_PRESET_TOOLTIP')
    preset.format=function(v) local name=presets[math.floor(v+.5)] or 'Balanced'; return text('FS25E_PRESET_'..name:upper(),name) end
    local languages={'auto','de','en'}
    local language=add('uiLanguage','uiLanguage','presets',1,3,1,'enum',function()
        local current=FS25E_Localization and FS25E_Localization.getLanguageSetting and FS25E_Localization.getLanguageSetting() or 'auto'
        for i,v in ipairs(languages) do if v==current then return i end end
        return 1
    end,function(v)
        local code=languages[math.floor(v+.5)]; if not code then return false,'FS25E_status_invalid_value' end
        if not FS25E_Localization or not FS25E_Localization.setLanguage then return false,'FS25E_status_api_unavailable' end
        return FS25E_Localization.setLanguage(code)
    end,'FS25E_setting_uiLanguage','FS25E_tooltip_uiLanguage')
    language.available=function() return FS25E_Localization~=nil and FS25E_ModSettings~=nil,'FS25E_status_api_unavailable' end
    language.format=function(v) return text('FS25E_value_language_'..(languages[math.floor(v+.5)] or 'auto')) end
    add('enhanced-debug-hud','liveTuningEnabled','performance',0,1,1,'bool',function()
        return boolean(FS25E_ModSettings.get('liveTuningEnabled')==true)
    end,function(v) return FS25E_ModSettings.set('liveTuningEnabled',v>=.5) end,'FS25E_setting_debugHud','FS25E_tooltip_debugHud')

end
function M.getControls() if #controls==0 then M.init() end; return controls end
function M.getStatus()
    return {governor=FS25E_GraphicsGovernor and FS25E_GraphicsGovernor.getMode(),
        budget=FS25E_BudgetAllocator and FS25E_BudgetAllocator.getSnapshot(),
        calibration=FS25E_CalibrationManager and FS25E_CalibrationManager.getStatus(),
        cinematic=FS25E_GraphicsGovernor and FS25E_GraphicsGovernor.getCinematicStatus(),
        benchmark=FS25E_BenchmarkManager and FS25E_BenchmarkManager.getStatus()}
end
function M.reset() controls={}; originals={} end
