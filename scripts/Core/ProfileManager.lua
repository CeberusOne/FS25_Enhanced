-- FS25_Enhanced / Core/ProfileManager.lua
-- Explicit presets combine native distance controls with manually chosen light settings.

FS25E_ProfileManager = {}

local presets = {}
local activeName = "Balanced"
local loaded = false
local pendingLights, pendingElapsed = {}, 0
local LIGHT_TARGETS = {
    Performance={localShadows=1,localShadowBudget=4,nearShadowResolution=1,farShadowResolution=0,vehicleShadowRange=60,lightHighRadius=25,relevantLightBudget=12,iesBudget=6,scatteringBudget=3,shadowSoftness=0.9},
    Balanced={localShadows=1,localShadowBudget=6,nearShadowResolution=2,farShadowResolution=1,vehicleShadowRange=90,lightHighRadius=35,relevantLightBudget=20,iesBudget=10,scatteringBudget=6,shadowSoftness=1.1},
    Quality={localShadows=1,localShadowBudget=8,nearShadowResolution=3,farShadowResolution=1,vehicleShadowRange=130,lightHighRadius=45,relevantLightBudget=28,iesBudget=14,scatteringBudget=8,shadowSoftness=1.25},
    Cinematic={localShadows=1,localShadowBudget=12,nearShadowResolution=3,farShadowResolution=2,vehicleShadowRange=160,lightHighRadius=55,relevantLightBudget=40,iesBudget=20,scatteringBudget=12,shadowSoftness=1.4}
}
local LIGHT_ORDER={'localShadows','localShadowBudget','vehicleShadowRange','lightHighRadius','relevantLightBudget','iesBudget','scatteringBudget','shadowSoftness','farShadowResolution','nearShadowResolution'}

local FALLBACK = {
    {
        name = "Performance",
        l10n = "FS25E_PRESET_PERFORMANCE",
        isDefault = false,
        note = "Favor frame-time; lowest visual budget.",
        targets = {
            viewDistanceCoeff = 0.7,
            lodDistanceCoeff = 0.7,
            foliageViewDistanceCoeff = 0.6,
            foliageLodDistanceCoeff = 0.6,
            terrainLodDistanceCoeff = 0.7,
            maxNumShadowLights = 4,
            allowFoliageShadows = false,
        },
    },
    {
        name = "Balanced",
        l10n = "FS25E_PRESET_BALANCED",
        isDefault = true,
        note = "Default compromise between visuals and performance.",
        targets = {
            viewDistanceCoeff = 1.0,
            lodDistanceCoeff = 1.0,
            foliageViewDistanceCoeff = 1.0,
            foliageLodDistanceCoeff = 1.0,
            terrainLodDistanceCoeff = 1.0,
            maxNumShadowLights = 6,
            allowFoliageShadows = true,
        },
    },
    {
        name = "Quality",
        l10n = "FS25E_PRESET_QUALITY",
        isDefault = false,
        note = "Higher visual budget; still respects target FPS when adaptive.",
        targets = {
            viewDistanceCoeff = 1.25,
            lodDistanceCoeff = 1.25,
            foliageViewDistanceCoeff = 1.2,
            foliageLodDistanceCoeff = 1.2,
            terrainLodDistanceCoeff = 1.2,
            maxNumShadowLights = 8,
            allowFoliageShadows = true,
        },
    },
    {
        name = "Cinematic",
        l10n = "FS25E_PRESET_CINEMATIC",
        isDefault = false,
        note = "Max visuals; may allow EXPERIMENTAL caps later. Not for competitive FPS.",
        targets = {
            viewDistanceCoeff = 1.5,
            lodDistanceCoeff = 1.5,
            foliageViewDistanceCoeff = 1.5,
            foliageLodDistanceCoeff = 1.5,
            terrainLodDistanceCoeff = 1.5,
            maxNumShadowLights = 12,
            allowFoliageShadows = true,
        },
    },
}

local function storePreset(entry)
    if entry == nil or entry.name == nil or entry.name == "" then
        return false
    end
    local targets={}
    for key,value in pairs(LIGHT_TARGETS[entry.name] or {}) do targets[key]=value end
    for key,value in pairs(entry.targets or {}) do targets[key]=value end
    presets[entry.name] = {
        name = entry.name,
        l10n = entry.l10n,
        isDefault = entry.isDefault == true,
        note = entry.note,
        targets = targets,
    }
    return true
end

local function seedFallback()
    presets = {}
    for i = 1, #FALLBACK do
        storePreset(FALLBACK[i])
    end
    activeName = "Balanced"
    FS25E_Debug.info("ProfileManager", string.format("seeded Lua fallback presets count=%d", #FALLBACK))
end

local function parseTargetsFromXml(xmlId, basePath)
    local targets = {}
    if getXMLString == nil then
        return targets
    end
    local i = 0
    while true do
        local keyPath = string.format("%s.target(%d)#key", basePath, i)
        local key = getXMLString(xmlId, keyPath)
        if key == nil or key == "" then
            break
        end
        local valPath = string.format("%s.target(%d)#value", basePath, i)
        local raw = getXMLString(xmlId, valPath)
        local num = tonumber(raw)
        if num ~= nil then
            targets[key] = num
        elseif raw == "true" or raw == "false" then
            targets[key] = (raw == "true")
        else
            targets[key] = raw
        end
        i = i + 1
    end
    return targets
end

local function tryParseXml(path)
    if loadXMLFile == nil or getXMLString == nil then
        return false, "XML APIs unavailable"
    end
    local xmlId = loadXMLFile("FS25E_presets", path)
    if xmlId == nil or xmlId == 0 then
        return false, "loadXMLFile failed"
    end
    local count = 0
    local ok, err = pcall(function()
        local i = 0
        while true do
            local base = string.format("presets.preset(%d)", i)
            local name = getXMLString(xmlId, base .. "#name")
            if name == nil or name == "" then
                break
            end
            local defaultAttr = getXMLString(xmlId, base .. "#default")
            local note = getXMLString(xmlId, base .. ".note")
            local targets = parseTargetsFromXml(xmlId, base)
            if next(targets) == nil then
                for _, fb in ipairs(FALLBACK) do
                    if fb.name == name then
                        targets = fb.targets
                        break
                    end
                end
            end
            if storePreset({
                name = name,
                l10n = getXMLString(xmlId, base .. "#l10n"),
                isDefault = defaultAttr == "true",
                note = note,
                targets = targets,
            }) then
                count = count + 1
                if defaultAttr == "true" then
                    activeName = name
                end
            end
            i = i + 1
        end
    end)
    if deleteXMLFile ~= nil then
        pcall(deleteXMLFile, xmlId)
    end
    if not ok then
        return false, err
    end
    if count == 0 then
        return false, "no preset nodes"
    end
    return true, count
end

function FS25E_ProfileManager.load(modDirectory)
    presets = {}
    loaded = false
    local path = (modDirectory or "") .. "config/presets.xml"
    FS25E_Debug.info("ProfileManager", "load from " .. path)
    local success, info = tryParseXml(path)
    if success then
        loaded = true
        FS25E_Debug.info("ProfileManager", string.format("XML loaded count=%s active=%s", tostring(info), tostring(activeName)))
    else
        FS25E_Debug.warning("ProfileManager", "XML soft-fail: " .. tostring(info) .. "; using Lua fallback")
        seedFallback()
        loaded = true
    end
    if next(presets) == nil then
        seedFallback()
        loaded = true
    end
    if presets[activeName] == nil then
        activeName = "Balanced"
    end
end

function FS25E_ProfileManager.init(modDirectory)
    FS25E_ProfileManager.load(modDirectory)
    FS25E_Debug.info("ProfileManager", "init (stubs only; no engine apply)")
end

function FS25E_ProfileManager.getActiveName()
    return activeName
end

function FS25E_ProfileManager.getPreset(name)
    return presets[name]
end

function FS25E_ProfileManager.listNames()
    local names = {}
    for name, _ in pairs(presets) do
        names[#names + 1] = name
    end
    table.sort(names)
    return names
end

function FS25E_ProfileManager.all()
    return presets
end

function FS25E_ProfileManager.selectPreset(name)
    if name == nil or name == "" or name == "Off" then
        return false
    end
    if next(presets) == nil then
        -- Not loaded yet (bootstrap race); silent skip — caller retries after init
        return false
    end
    local p = presets[name]
    if p == nil then
        FS25E_Debug.warning("ProfileManager", "unknown preset " .. tostring(name))
        return false
    end
    activeName = name
    if FS25E_SettingsSchema ~= nil then
        FS25E_SettingsSchema.set("preset", name)
    end
    if FS25E_SettingsCache ~= nil and p.targets ~= nil then
        for key, value in pairs(p.targets) do
            local e = FS25E_SettingsCache.get(key)
            if e == nil then
                FS25E_SettingsCache.ensure(key, nil)
                e = FS25E_SettingsCache.get(key)
            end
            if e ~= nil then
                local wasLocked=e.locked; e.locked=false
                FS25E_SettingsCache.setRequested(key, value)
                e.locked=wasLocked
            else
                FS25E_Debug.info("ProfileManager", "missing key=" .. tostring(key))
            end
        end
    end
    FS25E_Debug.info("ProfileManager", "selectPreset " .. tostring(name) .. " (cache requested only; no engine apply)")
    return true
end

function FS25E_ProfileManager.presetForMode(mode)
    if mode == "FAST" then
        return "Performance"
    elseif mode == "SLOW" then
        return "Quality"
    end
    return activeName ~= nil and activeName or "Balanced"
end

function FS25E_ProfileManager.reset()
    activeName = "Balanced"
    pendingLights={}; pendingElapsed=0
end


-- Apply local settings only through verified, available adapters. Missing targets are retried without native writes.
local function applyLightTarget(id,value)
    local light=FS25E_LightTuning
    local api=FS25E_VisualControls
    local control=api and api.get and api.get(id)
    if control and control.available then
        local ok,available,reason=pcall(control.available)
        if not ok then return false,"module-error" end
        if not available then return false,reason end
    end
    if control and api.apply then return api.apply(id,value,{preset=true}) end
    if control and type(control.write)=='function' then return control.write(value) end
    if light and type(light.set)=='function' then return light.set(id,value,false) end
    return false,'module-unavailable'
end
local function queueLightProfile(targets)
    pendingLights={}; pendingElapsed=0
    local applied,failed,skipped,policySkipped=0,0,0,0
    for _,id in ipairs(LIGHT_ORDER) do
        local value=targets[id]
        if value~=nil then
            local ok,result,reason=pcall(applyLightTarget,id,value)
            if ok and result then applied=applied+1
            elseif ok and (reason=="FS25E_status_noLocalLights" or reason=="module-unavailable") then pendingLights[id]={value=value,attempts=0}
            else failed=failed+1 end
        end
    end
    return applied,failed,skipped,policySkipped
end
function FS25E_ProfileManager.update(dt)
    if next(pendingLights)==nil then return end
    if FS25E_ModSettings and FS25E_ModSettings.get and FS25E_ModSettings.get('enabled')~=true then return end
    pendingElapsed=pendingElapsed+(tonumber(dt) or 0); if pendingElapsed<1000 then return end; pendingElapsed=0
    for _,id in ipairs(LIGHT_ORDER) do
        local pending=pendingLights[id]
        if pending then
            pending.attempts=pending.attempts+1
            local ok,result,reason=pcall(applyLightTarget,id,pending.value)
            if not ok or result or (reason~="FS25E_status_noLocalLights" and reason~="module-unavailable") or pending.attempts>=300 then pendingLights[id]=nil end
        end
    end
end
function FS25E_ProfileManager.cancelPending() pendingLights={}; pendingElapsed=0 end
function FS25E_ProfileManager.cancelPendingTarget(id)
    if id==nil then return false end
    local existed=pendingLights[id]~=nil
    pendingLights[id]=nil
    return existed
end
function FS25E_ProfileManager.getPendingLightTargets() return pendingLights end

--- Apply the selected preset explicitly every time; no adaptive governor gate.
function FS25E_ProfileManager.applySelected(force)
    local name=activeName or "Balanced"
    local preset=presets[name]
    if not preset then return false,"unknown preset" end
    local bindings={
        {"viewDistanceCoeff","view-distance-coeff","FS25E_LodGovernor","setViewDistanceCoeff"},
        {"lodDistanceCoeff","lod-distance-coeff","FS25E_LodGovernor","setLODDistanceCoeff"},
        {"foliageViewDistanceCoeff","foliage-view-distance-coeff","FS25E_LodGovernor","setFoliageViewDistanceCoeff"},
        {"foliageLodDistanceCoeff","foliage-lod-distance-coeff","FS25E_LodGovernor","setFoliageLODDistanceCoeff"},
        {"terrainLodDistanceCoeff","terrain-lod-distance-coeff","FS25E_LodGovernor","setTerrainLODDistanceCoeff"},
        {"allowFoliageShadows","allow-foliage-shadows","FS25E_LodGovernor","setAllowFoliageShadows"},
        {"maxNumShadowLights","max-num-shadow-lights","FS25E_ShadowManager","setMaxNumShadowLights"}
    }
    local applied,failed,skipped,policySkipped=0,0,0,0
    for _,b in ipairs(bindings) do
        local value=preset.targets[b[1]]
        local api=FS25E_VisualControls
        if value~=nil then
            local ok,result,reason
            if api and api.get and api.get(b[2]) and api.apply then
                local control=api.get(b[2])
                local requested=type(value)=="boolean" and (value and 1 or 0) or value
                ok,result,reason=pcall(api.apply,b[2],requested,{preset=true})
            else
                local manager=_G[b[3]]; local fn=manager and manager[b[4]]
                if type(fn)=="function" then ok,result=pcall(fn,value) end
            end
            if ok and result==true then applied=applied+1
            else failed=failed+1 end
        else skipped=skipped+1 end
    end
    local localApplied,localFailed,localSkipped,localPolicySkipped=queueLightProfile(preset.targets)
    applied=applied+localApplied; failed=failed+localFailed; skipped=skipped+localSkipped
    policySkipped=policySkipped+localPolicySkipped
    if FS25E_ModSettings then FS25E_ModSettings.set("activePreset",name) end
    local pending=0;for _ in pairs(pendingLights) do pending=pending+1 end
    FS25E_ProfileManager.lastApplyResult={applied=applied,failed=failed,skipped=skipped,policySkipped=policySkipped,pending=pending,preset=name}
    -- Partial profiles are reported explicitly; unavailable optional adapters do not conceal working ones.
    return applied>0 or (failed==0 and (policySkipped>0 or pending>0)),failed>0 and "partial-apply" or nil
end
