-- Curated, reversible controls. No guessing a slider from an arbitrary native name.
FS25E_VisualControls = {}
local C = FS25E_VisualControls
local controls, byId, states, providers = {}, {}, {}, {}
local built = false
local function finite(v) return type(v) == 'number' and v == v and math.abs(v) < math.huge end
local function equal(a,b) return a == b or (finite(a) and finite(b) and math.abs(a-b) < 0.0001) end
local function fn(name) return type(_G[name]) == 'function' and _G[name] or nil end
local function readNative(name)
    if not fn(name) then return nil end
    local ok,v=pcall(_G[name]); if ok then return v end
end
local function add(c)
    if byId[c.id] then return end
    c.labelKey=c.labelKey or ('FS25E_setting_'..c.id:gsub('-','_'))
    c.tooltipKey=c.tooltipKey or ('FS25E_tooltip_'..c.id:gsub('-','_'))
    c.cost=c.cost or 'medium'; c.step=c.step or 0.001
    c.min=c.min or 0; c.max=c.max or 1; c.applyMode=c.applyMode or 'LIVE'
    controls[#controls+1]=c; byId[c.id]=c
    states[c.id]=states[c.id] or {locked=false}
end
function C.registerProvider(provider)
    if provider and type(provider.getControls)=='function' then
        for _,p in ipairs(providers) do if p==provider then return end end
        providers[#providers+1]=provider
        for _,c in ipairs(provider.getControls()) do
            c.provider=provider
            c.verification=c.verification or 'configuration'
            if c.kind==nil and c.min==0 and c.max==1 and c.step==1 then c.kind='bool' end
            add(c)
        end
    end
end
local function applyNative(id,value)
    return FS25E_CapabilityApplier.apply(id,{value=value,expertMode=true})
end
local function scalar(id,category,getter,setter,min,max,step,cost,kind)
    local c={id=id,category=category,min=min,max=max,step=step,cost=cost,kind=kind}
    c.read=function()
        local v=readNative(getter)
        if kind=='bool' and type(v)=='boolean' then return v and 1 or 0 end
        return finite(v) and v or nil
    end
    c.available=function()
        return fn(getter)~=nil and fn(setter)~=nil and c.read()~=nil,'FS25E_status_api_unavailable'
    end
    c.write=function(v) return applyNative(id,kind=='bool' and v>=0.5 or (kind~='bool' and v)) end
    c.restore=function() return FS25E_CapabilityApplier.restoreOne(id) end
    add(c)
end
-- Engine quality enums (GIANTS SettingsModel:addEngineQualitySetting).
-- opts.getter/setter/name cover the irregular spellings (MSAA, TEXTURE_FILTERING)
-- and opts.support=false the enums the engine offers no hardware gate for.
local function quality(id,category,enumName,cost,opts)
    opts=opts or {}
    local c={id=id,category=category,min=1,max=1,step=1,cost=cost,kind='enum',enumName=enumName}
    local choices={}
    local getter=opts.getter or ('get'..enumName)
    local setter=opts.setter or ('set'..enumName)
    local nameFn=opts.name or ('get'..enumName..'Name')
    local support=opts.support
    if support==nil then support='getSupports'..enumName end
    local function refresh()
        choices={}
        local enum=_G[enumName]
        if type(enum)~='table' or not fn(getter) or not fn(setter) then return false end
        local gate=support and fn(support) or nil
        if support and not gate then return false end
        local seen={}
        for k,raw in pairs(enum) do
            if finite(raw) and k~='NUM' and raw~=enum.NUM and not seen[raw] then
                local allowed=true
                if gate then local ok,yes=pcall(gate,raw); allowed=ok and yes==true end
                if allowed then seen[raw]=true; choices[#choices+1]=raw end
            end
        end
        table.sort(choices); c.max=math.max(1,#choices)
        return #choices>0
    end
    c.available=function() return refresh(),'FS25E_status_quality_unavailable' end
    c.read=function()
        if #choices==0 then refresh() end
        local raw=readNative(getter)
        for i,v in ipairs(choices) do if v==raw then return i end end
    end
    c.format=function(index)
        local raw=choices[math.floor(index or 0)]
        if raw~=nil and fn(nameFn) then
            local ok,name=pcall(_G[nameFn],raw)
            if ok and type(name)=='string' and name~='' then return name end
        end
        return tostring(raw or '-')
    end
    c.toStored=function(index) return choices[math.floor(index)] end
    c.fromStored=function(raw)
        refresh()
        for index,v in ipairs(choices) do if v==raw then return index end end
        return nil
    end
    c.write=function(index)
        local raw=choices[math.floor(index)]
        if raw==nil then return false,'FS25E_status_quality_unavailable' end
        return applyNative(id,raw)
    end
    c.restore=function() return FS25E_CapabilityApplier.restoreOne(id) end
    add(c)
end
-- SettingsModel maps a display index onto the engine value through its own
-- static helpers. Reuse them instead of guessing the engine's enum numbers.
local function indexed(id,category,cost,getterName,setterName,byIndexName,toIndexName,textsField,count)
    local c={id=id,category=category,min=1,max=count,step=1,cost=cost,kind='enum'}
    local function helpers()
        return SettingsModel~=nil and type(SettingsModel[byIndexName])=='function'
            and type(SettingsModel[toIndexName])=='function'
            and fn(getterName)~=nil and fn(setterName)~=nil
    end
    local function texts()
        local t=g_settingsModel and g_settingsModel[textsField]
        return type(t)=='table' and #t>0 and t or nil
    end
    c.read=function()
        if not helpers() then return nil end
        local raw=readNative(getterName); if raw==nil then return nil end
        local ok,index=pcall(SettingsModel[toIndexName],raw)
        if ok and finite(index) then return index end
    end
    c.available=function()
        if not helpers() then return false,'FS25E_status_api_unavailable' end
        local t=texts(); if t then c.max=#t end
        return c.read()~=nil,'FS25E_status_api_unavailable'
    end
    c.format=function(index)
        local t=texts()
        return (t and t[math.floor(index or 0)]) or tostring(index)
    end
    c.toStored=function(index)
        if not helpers() then return nil end
        local ok,raw=pcall(SettingsModel[byIndexName],math.floor(index)); if ok then return raw end
    end
    c.fromStored=function(raw)
        if not helpers() then return nil end
        local ok,index=pcall(SettingsModel[toIndexName],raw)
        if ok and finite(index) then return index end
    end
    c.write=function(index)
        if not helpers() then return false,'FS25E_status_api_unavailable' end
        local ok,raw=pcall(SettingsModel[byIndexName],math.floor(index))
        if not ok or raw==nil then return false,'FS25E_status_invalid_value' end
        return applyNative(id,raw)
    end
    c.restore=function() return FS25E_CapabilityApplier.restoreOne(id) end
    add(c)
end
-- Every global engine setting this module drives, so the controls keep working
-- when config/capabilityProfiles.xml cannot be read. The XML carries the
-- documented notes and stays authoritative whenever it did load.
local DESCRIPTORS={
    {'volumetric-fog-quality','GATED','VolumetricFogQuality'},
    {'lensflare-quality','GATED','LensFlareQuality'},
    {'screen-space-shadows-quality','GATED','ScreenSpaceShadowsQuality'},
    {'ssao-quality','CONFIRMED',nil,'getSSAOQuality','setSSAOQuality'},
    {'cloud-shadows-quality','CONFIRMED',nil,'getCloudShadowsQuality','setCloudShadowsQuality'},
    {'shadow-map-filter-size','CONFIRMED',nil,'getShadowMapFilterSize','setShadowMapFilterSize'},
    {'volume-mesh-tessellation-coeff','CONFIRMED',nil,'getVolumeMeshTessellationCoeff','setVolumeMeshTessellationCoeff'},
    {'tyre-tracks-segments-coeff','CONFIRMED',nil,'getTyreTracksSegmentsCoeff','setTyreTracksSegmentsCoeff'},
    {'tone-mapping-slope','EXPERIMENTAL',nil,'getToneMappingCurveSlope','setToneMappingCurveSlope'},
    {'tone-mapping-toe','EXPERIMENTAL',nil,'getToneMappingCurveToe','setToneMappingCurveToe'},
    {'tone-mapping-shoulder','EXPERIMENTAL',nil,'getToneMappingCurveShoulder','setToneMappingCurveShoulder'},
    {'tone-mapping-black-clip','EXPERIMENTAL',nil,'getToneMappingCurveBlackClip','setToneMappingCurveBlackClip'},
    {'tone-mapping-white-clip','EXPERIMENTAL',nil,'getToneMappingCurveWhiteClip','setToneMappingCurveWhiteClip'},
    {'spot-shadow-full-resolution-percentage','EXPERIMENTAL',nil,'getSpotShadowFullResolutionPercentage','setSpotShadowFullResolutionPercentage'},
    {'spot-shadow-atlas-slot-factor','EXPERIMENTAL',nil,'getSpotShadowAtlasSlotFactor','setSpotShadowAtlasSlotFactor'},
    {'spot-shadow-distance-frequency-factor','EXPERIMENTAL',nil,'getSpotShadowDistanceFrequencyFactor','setSpotShadowDistanceFrequencyFactor'},
    {'spot-shadow-min-cone-angle-percentage','EXPERIMENTAL',nil,'getSpotShadowMinimumConeAnglePercentage','setSpotShadowMinimumConeAnglePercentage'},
    {'spot-shadow-reduced-cone-angle-factor','EXPERIMENTAL',nil,'getSpotShadowReducedConeAngleFactor','setSpotShadowReducedConeAngleFactor'},
    -- Getters are listed in sdk/scriptBindingChanges.txt; the setters are only
    -- offered when the running build actually has them (fs25eApiDump Fog).
    {'fog-ground-density','EXPERIMENTAL',nil,'getFogGroundLevelDensity','setFogGroundLevelDensity'},
    {'fog-max-height','EXPERIMENTAL',nil,'getFogMaxHeight','setFogMaxHeight'},
    -- Atmosphere phase asymmetry (the map's environment.xml <asymmetryFactor>
    -- curve): getter renamed in sdk/scriptBindingChanges.txt, setter probed.
    {'atmosphere-asymmetry','EXPERIMENTAL',nil,'getAtmosphereCornettShrankAsymmetryFactor','setAtmosphereCornettShrankAsymmetryFactor'},
}
function C.build()
    if built then return end
    built=true
    local registry=FS25E_CapabilityRegistry
    if registry and registry.registerDescriptor then
        for _,entry in ipairs(DESCRIPTORS) do
            local id,status,enumName=entry[1],entry[2],entry[3]
            local getter=entry[4] or ('get'..enumName)
            local setter=entry[5] or ('set'..enumName)
            local known=registry.get and registry.get(id)
            if not known or known.setter~=setter then
                registry.registerDescriptor({id=id,status=status,getter=getter,setter=setter,apiName=setter,
                    applyMode='LIVE',restoreStrategy='YES',scope='global',
                    notes='GIANTS SettingsModel / FS25 script binding; registered by VisualControls'})
            end
        end
    end
    scalar('view-distance-coeff','lod','getViewDistanceCoeff','setViewDistanceCoeff',0.5,2,0.001,'high')
    scalar('lod-distance-coeff','lod','getLODDistanceCoeff','setLODDistanceCoeff',0.5,2,0.001,'high')
    scalar('terrain-lod-distance-coeff','lod','getTerrainLODDistanceCoeff','setTerrainLODDistanceCoeff',0.5,2,0.001,'medium')
    scalar('foliage-view-distance-coeff','foliage','getFoliageViewDistanceCoeff','setFoliageViewDistanceCoeff',0.5,2,0.001,'high')
    scalar('foliage-lod-distance-coeff','foliage','getFoliageLODDistanceCoeff','setFoliageLODDistanceCoeff',0.5,2,0.001,'high')
    scalar('allow-foliage-shadows','foliage','getAllowFoliageShadows','setAllowFoliageShadows',0,1,1,'high','bool')
    scalar('max-num-shadow-lights','shadows','getMaxNumShadowLights','setMaxNumShadowLights',0,16,1,'extreme')
    scalar('shadow-distance-quality','shadows','getShadowDistanceQuality','setShadowDistanceQuality',0,2,1,'high')
    scalar('shadow-filter-quality','shadows','getShadowFilterQuality','setShadowFilterQuality',0,1,1,'high','bool')
    -- Filter is numeric in FS25, even though the native menu labels it on/off.
    local filter=byId['shadow-filter-quality']
    filter.read=function() return readNative('getShadowFilterQuality') end
    filter.write=function(v) return applyNative(filter.id,v) end
    local shadow={id='shadow-quality',category='shadows',min=1,max=4,step=1,cost='extreme',kind='enum'}
    shadow.available=function()
        return SettingsModel~=nil and type(SettingsModel.getShadowQualityByIndex)=='function'
            and type(SettingsModel.getShadowQualityIndex)=='function' and fn('getHasShadowFocusBox')~=nil
            and type(SettingsModel.getHasShadowFocusBoxByIndex)=='function'
            and fn('setShadowQuality')~=nil and fn('getShadowQuality')~=nil,'FS25E_status_api_unavailable'
    end
    shadow.read=function()
        if shadow.available() then return SettingsModel.getShadowQualityIndex(getShadowQuality(),getHasShadowFocusBox()) end
    end
    shadow.write=function(v)
        return FS25E_CapabilityApplier.apply('shadow-quality',{values={SettingsModel.getShadowQualityByIndex(v),SettingsModel.getHasShadowFocusBoxByIndex(v)}})
    end
    shadow.format=function(v) return g_settingsModel and g_settingsModel.shadowQualityTexts and g_settingsModel.shadowQualityTexts[v] or tostring(v) end
    shadow.restore=function() return FS25E_CapabilityApplier.restoreOne('shadow-quality') end
    add(shadow)
    quality('ssr-quality','reflections','ScreenSpaceReflectionsQuality','high')
    quality('atmosphere-quality','atmosphere','AtmosphereQuality','high')
    quality('volumetric-fog-quality','atmosphere','VolumetricFogQuality','high')
    quality('lensflare-quality','atmosphere','LensFlareQuality','low')
    quality('screen-space-shadows-quality','shadows','ScreenSpaceShadowsQuality','high')
    scalar('rain-amount-mult','weather','getRainAmountMultiplier','setRainAmountMultiplier',0.01,2,0.001,'medium')

    -- === Global engine settings GIANTS writes from its own graphics page ===
    -- Every entry mirrors a SettingsModel writer; see docs/ENGINE_SETTINGS.md.
    scalar('ssao-quality','image','getSSAOQuality','setSSAOQuality',1,4,1,'high','enum')
    local ssao=byId['ssao-quality']
    ssao.format=function(v)
        local t=g_settingsModel and g_settingsModel.ssaoQualityTexts
        return (type(t)=='table' and t[math.floor(v or 0)]) or tostring(v)
    end
    scalar('cloud-shadows-quality','shadows','getCloudShadowsQuality','setCloudShadowsQuality',0,1,1,'medium','bool')
    -- getCloudShadowsQuality reports 0/1, not a boolean; write the same shape back.
    local clouds=byId['cloud-shadows-quality']
    clouds.read=function()
        local raw=readNative('getCloudShadowsQuality')
        if type(raw)=='boolean' then return raw and 1 or 0 end
        return finite(raw) and raw or nil
    end
    clouds.write=function(v) return applyNative(clouds.id,v>=0.5 and 1 or 0) end
    indexed('shadow-map-filter-size','shadows','high','getShadowMapFilterSize','setShadowMapFilterSize',
        'getShadowMapFilterByIndex','getShadowMapFilterIndex','lowHighTexts',2)
    scalar('volume-mesh-tessellation-coeff','lod','getVolumeMeshTessellationCoeff','setVolumeMeshTessellationCoeff',0.5,2,0.001,'medium')
    scalar('tyre-tracks-segments-coeff','lod','getTyreTracksSegmentsCoeff','setTyreTracksSegmentsCoeff',0,4,0.5,'medium')

    -- === Filmic tone mapping curve (FS25 1.0 script binding addition) ===
    scalar('tone-mapping-slope','image','getToneMappingCurveSlope','setToneMappingCurveSlope',0.1,4,0.001,'low')
    scalar('tone-mapping-toe','image','getToneMappingCurveToe','setToneMappingCurveToe',0,4,0.001,'low')
    scalar('tone-mapping-shoulder','image','getToneMappingCurveShoulder','setToneMappingCurveShoulder',0,4,0.001,'low')
    scalar('tone-mapping-black-clip','image','getToneMappingCurveBlackClip','setToneMappingCurveBlackClip',-1,1,0.001,'low')
    scalar('tone-mapping-white-clip','image','getToneMappingCurveWhiteClip','setToneMappingCurveWhiteClip',0,2,0.001,'low')

    -- === Height fog (getters documented for FS25 1.0; setters probed at runtime) ===
    scalar('fog-ground-density','atmosphere','getFogGroundLevelDensity','setFogGroundLevelDensity',0,1,0.001,'medium')
    scalar('fog-max-height','atmosphere','getFogMaxHeight','setFogMaxHeight',0,2000,0.5,'medium')
    -- === Atmosphere phase asymmetry (sun halo concentration; getter documented, setter probed) ===
    scalar('atmosphere-asymmetry','atmosphere','getAtmosphereCornettShrankAsymmetryFactor','setAtmosphereCornettShrankAsymmetryFactor',0,0.95,0.001,'low')

    -- === Spot shadow atlas tuning (FS25 1.0 script binding addition) ===
    scalar('spot-shadow-full-resolution-percentage','shadows','getSpotShadowFullResolutionPercentage','setSpotShadowFullResolutionPercentage',0,1,0.001,'high')
    scalar('spot-shadow-atlas-slot-factor','shadows','getSpotShadowAtlasSlotFactor','setSpotShadowAtlasSlotFactor',0.1,4,0.001,'high')
    scalar('spot-shadow-distance-frequency-factor','shadows','getSpotShadowDistanceFrequencyFactor','setSpotShadowDistanceFrequencyFactor',0,4,0.001,'medium')
    scalar('spot-shadow-min-cone-angle-percentage','shadows','getSpotShadowMinimumConeAnglePercentage','setSpotShadowMinimumConeAnglePercentage',0,1,0.001,'medium')
    scalar('spot-shadow-reduced-cone-angle-factor','shadows','getSpotShadowReducedConeAngleFactor','setSpotShadowReducedConeAngleFactor',0,4,0.001,'medium')
end
function C.getControls() C.build(); return controls end
function C.all() return C.getControls() end
-- A single diagnostic contract for every visible setting, including asset gates.
-- Cost classes are estimates. A native readback is not a visual/performance pass.
function C.getMetadata(id)
    local c=C.get(id); if not c then return nil end
    local cap=FS25E_CapabilityRegistry and FS25E_CapabilityRegistry.get and FS25E_CapabilityRegistry.get(id)
    local sources={environment='docs/ENVIRONMENT_LIGHTING_0.5.4.0.md',shadows='docs/LIGHTS_RESEARCH.md',lighting='docs/LIGHTS_RESEARCH.md',
        weather='docs/ENVIRONMENT_RESEARCH.md',particles='docs/ENVIRONMENT_RESEARCH.md',
        materials='docs/ENVIRONMENT_RESEARCH.md',water='docs/ENVIRONMENT_RESEARCH.md',foliage='docs/ENVIRONMENT_RESEARCH.md'}
    return {id=id,labelKey=c.labelKey,tooltipKey=c.tooltipKey,module=c.category,
        getter=cap and cap.getter or 'typed provider: '..tostring(c.provider and c.provider._fs25eModuleName or c.category),
        setter=cap and cap.setter or 'typed provider: '..tostring(c.provider and c.provider._fs25eModuleName or c.category),
        source=c.provider and (sources[c.category] or 'docs/CORE_RESEARCH.md') or 'docs/RESEARCH.md',
        capabilityState=c.capabilityState or (cap and (cap.baseStatus or cap.status)) or (c.runtimeControl and 'MOD_CONTROL' or (c.experimental and 'EXPERIMENTAL' or 'GIANTS_USED')),
        applyMode=c.applyMode,requiresReload=c.applyMode=='RELOAD',requiresRestart=c.applyMode=='RESTART',
        minimum=c.min,maximum=c.max,step=c.step,costEstimate=c.cost,cpuCostMs='UNKNOWN',gpuCostMs='UNKNOWN',vramCostMB='UNKNOWN',
        spatialScope='GLOBAL',
        verification=c.verification or 'native readback',testStatus='MOCK_REGRESSION; INGAME_NOT_TESTED',
        platforms='Windows PC; other platforms NOT_TESTED',engineVersion='FS25 GDN 1.20.0.0 / installed SDK',
        compatibilityRisk=c.experimental and 'asset-specific experimental adapter' or 'runtime feature and ownership checks required',
        sideEffects='See localized tooltip and module research; higher quality can increase frame time',
        automaticAllowed=false,locked=C.isLocked(id)}
end
function C.get(id) C.build(); return byId[id] end
function C.getState(id) C.build(); return states[id] end
function C.isLocked(id)
    return (states[id] and states[id].locked==true) or (FS25E_SettingsCache and FS25E_SettingsCache.isLocked(id)) or false
end
function C.setLocked(id,locked)
    local c=C.get(id); if not c then return false end
    states[id].locked=locked==true
    if FS25E_SettingsCache then FS25E_SettingsCache.ensure(id,nil); FS25E_SettingsCache.setLocked(id,locked) end
    if c.provider and c.provider.setLocked then c.provider.setLocked(id,locked) end
    return true
end
function C.available(c)
    if type(c)=='string' then c=C.get(c) end
    if not c then return false,'FS25E_status_api_unavailable' end
    if c.kind~='action' and FS25E_VisualProfiles and FS25E_VisualProfiles.isComparing() then
        return false,'FS25E_status_compare_original'
    end
    if c.provider and c.provider._fs25eModuleName and FS25E_ModuleRuntime and FS25E_ModuleRuntime.failed[c.provider._fs25eModuleName] then
        return false,'FS25E_status_module_error'
    end
    local registry=FS25E_CapabilityRegistry
    if not c.provider and registry and registry.getStatus and registry.getStatus(c.id)=='REJECTED' then
        return false,'FS25E_status_native_rejected'
    end
    if c.available then
        local ok,available,reason=pcall(c.available)
        if not ok then return false,'FS25E_status_module_error' end
        if not available then return false,reason or 'FS25E_status_api_unavailable' end
    end
    return true
end
function C.read(c)
    if type(c)=='string' then c=C.get(c) end
    if not c or type(c.read)~='function' then return nil end
    local ok,v=pcall(c.read); if ok and finite(v) then return v end
end
function C.apply(id,value,opts)
    opts=opts or {}; local c=C.get(id); local available,reason=C.available(c)
    if not available then return false,reason end
    if opts.automatic then return false,'manual-mode' end
    if not finite(value) then return false,'FS25E_status_invalid_value' end
    value=math.max(c.min,math.min(c.max,value))
    value=c.min+math.floor((value-c.min)/c.step+0.5)*c.step
    local state=states[id]; local before=C.read(c)
    if before==nil then return false,'FS25E_status_unreadable' end
    -- A slider drag delivers one mouse event per rendered frame. Re-writing an
    -- unchanged value would hammer the native setter and flood the log; only a
    -- value the engine no longer holds is worth applying again.
    if state.error==nil and state.requested~=nil and equal(state.requested,value)
        and state.current~=nil and equal(state.current,before) then
        return true
    end
    if not c.runtimeControl then
        if FS25E_ProfileManager and FS25E_ProfileManager.cancelPendingTarget and not opts.preset then FS25E_ProfileManager.cancelPendingTarget(id) end
        if FS25E_ModSettings and FS25E_ModSettings.set then FS25E_ModSettings.set('enabled',true) end
        if FS25E_GraphicsGovernor and FS25E_GraphicsGovernor.setEnabled then FS25E_GraphicsGovernor.setEnabled(true) end
    end
    if state.original==nil then state.original=before end
    -- A user may continue editing a value protected from the governor.
    local cached=FS25E_SettingsCache and FS25E_SettingsCache.get(id)
    local locked=cached and cached.locked
    if cached then cached.locked=false end
    local ok,result,err
    if opts.automatic and c.provider and c.provider.setAuto then ok,result,err=pcall(c.provider.setAuto,id,value)
    else ok,result,err=pcall(c.write,value) end
    if cached then cached.locked=locked end
    local actual=C.read(c)
    if not ok or result~=true or not equal(actual,value) then
        state.status='FS25E_status_not_applied'
        state.diagnosticError=(ok and err) or tostring(result)
        state.error=type(err)=='string' and err:match('^FS25E_') and err or 'FS25E_status_readback_mismatch'
        state.current=actual
        return false,state.error or 'FS25E_status_readback_mismatch'
    end
    state.current=actual; state.requested=value
    state.status=err or (c.verification=='observed' and 'FS25E_status_observedOnly')
        or (c.verification=='configuration' and 'FS25E_status_configured') or 'FS25E_status_applied'
    state.error=nil
    -- Bounded runtime evidence for the next real game session. A cached slider
    -- value alone is not evidence that a light/material object was reached.
    local now=tonumber(g_time) or 0
    if FS25E_Debug and FS25E_Debug.info and (state.lastLogTime==nil or now-state.lastLogTime>=2000) then
        local detail=''
        if c.provider and type(c.provider.getDiagnostics)=='function' then
            local ok,d=pcall(c.provider.getDiagnostics)
            if ok and type(d)=='table' then
                for _,key in ipairs({'active','total','applied','failed','materials','vehicleMaterials','worldMaterials','verifiedPaintMaterials','clearCoatMaterials','worldLinked','targets','pendingNodes','sunNode','brightnessIndex','brightnessApplied','colorObserved','colorApplied',
                    'placeableMaterials','buildingMaterials','waterMaterials','puddleMaterials','treeMaterials','treeBillboardMaterials','cropMaterials','translucentMaterials','paintedSurfaces','splitShapes','splitProbe','badMaterials',
                    'engineWetness','appliedWetness','wetnessHookObserved','wetnessSticks','zones','vehicleZones','playerZones'}) do
                    if d[key]~=nil then detail=detail..' '..key..'='..tostring(d[key]) end
                end
                for _,key in ipairs({'originalRGB','currentRGB'}) do
                    local rgb=d[key]
                    if type(rgb)=='table' and finite(rgb[1]) and finite(rgb[2]) and finite(rgb[3]) then
                        detail=detail..' '..key..'='..string.format('%.5g,%.5g,%.5g',rgb[1],rgb[2],rgb[3])
                    end
                end
            end
        end
        FS25E_Debug.info('LiveApply',id..' requested='..tostring(value)..' readback='..tostring(actual)..' status='..tostring(state.status)..detail)
        state.lastLogTime=now
    end
    if FS25E_CompatibilityManager and FS25E_CompatibilityManager.noteWrite then FS25E_CompatibilityManager.noteWrite(id,actual) end
    if not c.runtimeControl then C.setLocked(id,false) end
    return true
end
function C.restore(id)
    local c=C.get(id); if not c then return false end
    local state=states[id]
    local ok,result=pcall(c.restore)
    if not ok or result==false then state.status='FS25E_status_restore_failed'; return false end
    state.current=C.read(c); state.requested=state.current; state.status='FS25E_status_restored'; state.error=nil
    C.setLocked(id,false)
    return true
end
function C.restoreAll()
    local success=true
    for _,c in ipairs(controls) do
        if not c.noGlobalRestore and states[c.id].original~=nil then success=C.restore(c.id) and success end
    end
    return success
end
function C.reset()
    controls={}; byId={}; states={}; providers={}; built=false
end
