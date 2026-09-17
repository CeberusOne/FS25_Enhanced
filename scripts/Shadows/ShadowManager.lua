-- Per-light operations use typed native adapters with readback and restore.
FS25E_ShadowManager = {}
local M = FS25E_ShadowManager
local initialized, discoveredLights, mergedLights = false, {}, {}
local unpackValues = table.unpack or unpack
function M.init() initialized=true; discoveredLights={}; mergedLights={} end
function M.isInitialized() return initialized end
function M.reset() M.restoreAll(); initialized=false; discoveredLights={} end
function M.registerLightId(node)
    if not FS25E_LightDiscovery or not FS25E_LightDiscovery.isLightSource(node) then return false end
    discoveredLights[node]=true; return true
end
function M.getDiscoveredLights()
    local out,seen={},{}
    local entries=FS25E_LightDiscovery and FS25E_LightDiscovery.getRuntimeEntries and FS25E_LightDiscovery.getRuntimeEntries() or {}
    for _,e in ipairs(entries) do if not seen[e.node] then out[#out+1]=e.node; seen[e.node]=true end end
    if #out==0 then for node in pairs(discoveredLights) do if FS25E_LightDiscovery.isLightSource(node) then out[#out+1]=node end end end
    return out
end
local function entry(node)
    if FS25E_LightDiscovery and FS25E_LightDiscovery.getRuntimeEntries then
        for _,e in ipairs(FS25E_LightDiscovery.getRuntimeEntries()) do if e.node==node then return e end end
    end
end
local function cap(id,value)
    if not FS25E_CapabilityApplier then return false,"FS25E_warning_lightApiUnavailable" end
    return FS25E_CapabilityApplier.apply(id,{value=value,values={value}})
end
function M.setMaxNumShadowLights(v) return cap("max-num-shadow-lights",v) end
function M.setShadowQuality(v) return cap("shadow-quality",v) end
function M.setShadowDistanceQuality(v) return cap("shadow-distance-quality",v) end
function M.setShadowFilterQuality(v) return cap("shadow-filter-quality",v) end
local function apply(node,p,getter,setter,values)
    local e=entry(node)
    if not e then return false,"FS25E_status_noLocalLights" end
    if not FS25E_LightTuning then return false,"FS25E_warning_lightApiUnavailable" end
    return FS25E_LightTuning.applyProperty(e,p,getter,setter,function() return values end)
end
function M.setLightShadowPriority(node,v)
    if type(v)~="number" or v~=v then return false,"FS25E_warning_lightInvalidValue" end
    return apply(node,"priority","getLightShadowPriority","setLightShadowPriority",{v})
end
function M.setLightShadowMap(node,cast,resolution)
    if type(cast)~="boolean" or type(resolution)~="number" or resolution%1~=0 or resolution<128 or resolution>4096 then
        return false,"FS25E_warning_lightInvalidValue"
    end
    return apply(node,"shadowMap","getLightCastingShadowMap","setLightShadowMap",{cast,resolution})
end
function M.setLightSoftShadowSize(node,v)
    if type(v)~="number" or v<0 or v~=v then return false,"FS25E_warning_lightInvalidValue" end
    return apply(node,"softness","getLightSoftShadowSize","setLightSoftShadowSize",{v})
end
function M.setLightSoftShadowDistance(node,v)
    if type(v)~="number" or v<=0 or v~=v then return false,"FS25E_warning_lightInvalidValue" end
    -- This native property has no effect on spotlights (GDN). Do not offer a
    -- working-looking slider for a spotlight parameter ignored by the engine.
    if not entry(node) or type(getLightType)~="function" or LightType==nil then return false,"FS25E_warning_lightApiUnavailable" end
    local ok,kind=pcall(getLightType,node)
    if not ok or kind~=LightType.DIRECTIONAL then return false,"FS25E_warning_directionalLightRequired" end
    return apply(node,"softDistance","getLightSoftShadowDistance","setLightSoftShadowDistance",{v})
end
function M.setLightSoftShadowDepthBiasFactor(node,v)
    if type(v)~="number" or v<=0 or v~=v then return false,"FS25E_warning_lightInvalidValue" end
    return apply(node,"bias","getLightSoftShadowDepthBiasFactor","setLightSoftShadowDepthBiasFactor",{v})
end
function M.hasMergedShadow(node)
    if not FS25E_LightDiscovery.isLightSource(node) or type(hasMergedShadow)~="function" then return false end
    local ok,value=pcall(hasMergedShadow,node); return ok and value==true
end
function M.mergeLightShadows(node,...)
    local nodes={node,...}
    if #nodes<2 or #nodes>10 then return false,"FS25E_warning_lightInvalidValue" end
    if type(mergeLightShadows)~="function" or type(splitLightShadow)~="function" or type(hasMergedShadow)~="function"
        or not RealLight or type(RealLight.getAreShadowsMergable)~="function" then return false,"FS25E_warning_lightApiUnavailable" end
    local first,seen=entry(node),{}
    if not first then return false,"FS25E_status_noLocalLights" end
    for _,id in ipairs(nodes) do
        local e=entry(id)
        if seen[id] or not e or e.owner~=first.owner or e.profile~=first.profile or e.bucket~=first.bucket then
            return false,"FS25E_warning_lightMergeIncompatible"
        end
        seen[id]=true
        local ok,merged=pcall(hasMergedShadow,id)
        -- Never split or take ownership of a vanilla/other-mod group.
        if not ok or merged then return false,"FS25E_warning_lightMergeOwned" end
    end
    local ok,compatible=pcall(RealLight.getAreShadowsMergable,nodes)
    if not ok or not compatible then return false,"FS25E_warning_lightMergeIncompatible" end
    if not pcall(mergeLightShadows,unpackValues(nodes)) then return false,"FS25E_warning_lightWriteRejected" end
    local verified=true
    for _,id in ipairs(nodes) do
        local success,merged=pcall(hasMergedShadow,id)
        if success and merged then mergedLights[id]=true else verified=false end
    end
    if not verified then
        for _,id in ipairs(nodes) do if mergedLights[id] then M.splitLightShadow(id) end end
        return false,"FS25E_warning_lightWriteRejected"
    end
    return true
end
function M.splitLightShadow(node)
    if not mergedLights[node] then return false,"FS25E_warning_lightMergeOwned" end
    if not FS25E_LightDiscovery.isLightSource(node) then mergedLights[node]=nil; return true end
    if type(splitLightShadow)~="function" or not pcall(splitLightShadow,node) then return false,"FS25E_warning_lightWriteRejected" end
    if M.hasMergedShadow(node) then return false,"FS25E_warning_lightWriteRejected" end
    mergedLights[node]=nil; return true
end
function M.restoreAll()
    local ok=true
    for node in pairs(mergedLights) do ok=M.splitLightShadow(node) and ok end
    if FS25E_LightTuning and FS25E_LightTuning.restoreAll then ok=FS25E_LightTuning.restoreAll() and ok end
    return ok
end
function M.getMergedLights() return mergedLights end
function M.getTrackedMerges() return mergedLights end
function M.applyPresetStub() return false,"FS25E_warning_lightApiUnavailable" end
