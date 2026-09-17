-- Native, reversible local lighting. See docs/LIGHTS_RESEARCH.md for API sources.
-- Never enumerate the scene graph and never replace a map's lighting setup.
FS25E_LightTuning = {}
local M = FS25E_LightTuning
local unpackValues = table.unpack or unpack
local records, locks, settings, merges, requested = {}, {}, {}, {}, {}
local elapsed, slowElapsed, lastScene, lastResult = 0, 20000, {}, {applied=0, failed=0}
local running, chargeHook = false, false
local definitions = {
    {"localShadows","shadows",0,1,1,1,"high"},
    {"vehicleShadowRange","shadows",10,200,0.25,100,"high"},
    {"localShadowBudget","shadows",1,16,1,6,"high"},
    {"nearShadowResolution","shadows",0,3,1,2,"extreme"},
    {"farShadowResolution","shadows",0,2,1,0,"high"},
    {"shadowSoftness","shadows",0,4,0.005,1,"medium"},
    {"softShadowBias","shadows",0.1,4,0.005,1,"low"},
    {"shadowExtrusion","shadows",0.1,2,0.005,1,"medium"},
    {"shadowMerge","shadows",0,1,1,0,"medium"},
    {"lightIntensity","lighting",0,8,0.005,1,"low"},
    {"lightWarmth","lighting",-1,1,0.005,0,"low"},
    {"lightTint","lighting",-1,1,0.005,0,"low"},
    {"lightRange","lighting",0.25,2,0.005,1,"medium"},
    {"lightFalloff","lighting",0.25,2,0.005,1,"low"},
    {"lightCone","lighting",0.5,1.5,0.005,1,"medium"},
    {"lightHighRadius","lighting",10,150,0.25,35,"medium"},
    {"lightMediumRadius","lighting",20,300,0.25,100,"medium"},
    {"relevantLightBudget","lighting",1,64,1,24,"high"},
    {"behindCameraReduction","lighting",0,1,0.005,0.6,"low"},
    {"iesMode","lighting",0,1,1,1,"medium"},
    {"iesRange","lighting",0.25,2,0.005,1,"medium"},
    {"iesFalloff","lighting",0.25,2,0.005,1,"low"},
    {"iesBudget","lighting",1,32,1,12,"high"},
    {"headlightIES","lighting",0,1,1,1,"medium"},
    {"worklightIES","lighting",0,1,1,1,"medium"},
    {"placeableIES","lighting",0,1,1,1,"medium"},
    {"scatteringIntensity","lighting",0,3,0.005,1,"medium"},
    {"scatteringBudget","lighting",0,32,1,8,"high"},
    {"scatteringDistance","lighting",5,200,0.25,60,"medium"},
    {"headlightScattering","lighting",0,1,1,1,"medium"},
    {"worklightScattering","lighting",0,1,1,1,"medium"},
    {"placeableScattering","lighting",0,1,1,1,"medium"},
    {"scatteringWeatherResponse","lighting",0,1,0.005,0.6,"medium"},
}
local index = {}
for _, d in ipairs(definitions) do
    if d[5]==0.005 then d[5]=0.001 end
    settings[d[1]]=d[6]; index[d[1]]=d
end
local function clamp(v,a,b) return math.max(a,math.min(b,v)) end
local function exists(node)
    if node == nil or node == 0 then return false end
    if type(entityExists) ~= "function" then return true end
    local ok, value=pcall(entityExists,node); return ok and value == true
end
local function equal(a,b)
    if type(a) == "number" and type(b) == "number" then
        return math.abs(a-b) <= 0.0001*math.max(1,math.abs(a),math.abs(b))
    end
    return a == b
end
local function equalTuple(a,b)
    if #a ~= #b then return false end
    for i=1,#a do if not equal(a[i],b[i]) then return false end end
    return true
end
local function readNative(name,node)
    local fn=_G[name]
    if type(fn) ~= "function" or not FS25E_LightDiscovery or type(FS25E_LightDiscovery.isLightSource)~="function" or not FS25E_LightDiscovery.isLightSource(node) then return nil end
    local out={pcall(fn,node)}
    if not table.remove(out,1) or out[1] == nil then return nil end
    return out
end
local function writeNative(name,node,values)
    if type(_G[name]) ~= "function" or not FS25E_LightDiscovery or not FS25E_LightDiscovery.isLightSource(node) then return false end
    local ok,result=pcall(_G[name],node,unpackValues(values))
    return ok and result ~= false
end
local function shadowTuple(v)
    if v and type(v[1]) == "boolean" then
        -- GIANTS omits the resolution when casting is off. It is irrelevant to
        -- that disabled state, but the setter still requires an integer.
        return {v[1],v[2] or 512}
    end
end
local function tuplesMatch(property,a,b)
    if property == "shadowMap" and a and b and not a[1] and not b[1] then return true end
    return a ~= nil and b ~= nil and equalTuple(a,b)
end

-- Capture immediately before the first mutation. If the game updates a property
-- (e.g. lamp charge/profile), that new native state replaces our restore baseline.
function M.applyProperty(entry,property,getter,setter,transform)
    local node=entry.node
    local current=readNative(getter,node)
    if property == "shadowMap" then current=shadowTuple(current) end
    if current == nil or type(_G[setter]) ~= "function" then return false,"FS25E_warning_lightApiUnavailable" end
    local key=tostring(node)..":"..property
    local record=records[key]
    if record == nil then
        record={node=node,owner=entry.owner,property=property,getter=getter,setter=setter,original=current}
    elseif not record.pendingRestore and record.last ~= nil and not tuplesMatch(property,current,record.last) then
        record.original=current
    end
    local wanted=transform(record.original)
    if wanted == nil then return true end
    if tuplesMatch(property,current,wanted) then return true end
    records[key]=record
    if not writeNative(setter,node,wanted) then return false,"FS25E_warning_lightWriteRejected" end
    local actual=readNative(getter,node)
    if property == "shadowMap" then actual=shadowTuple(actual) end
    if not tuplesMatch(property,actual,wanted) then
        writeNative(setter,node,current)
        local rolledBack=readNative(getter,node)
        if property=="shadowMap" then rolledBack=shadowTuple(rolledBack) end
        record.pendingRestore=not tuplesMatch(property,rolledBack,current)
        record.last=rolledBack or actual
        return false,"FS25E_warning_lightWriteRejected"
    end
    record.last=actual
    record.pendingRestore=false
    return true
end

local function restoreRecord(key,r)
    if not FS25E_LightDiscovery.isLightSource(r.node) then records[key]=nil; return true end
    local current=readNative(r.getter,r.node)
    if r.property == "shadowMap" then current=shadowTuple(current) end
    -- An external owner has changed this node since our last write. Keep its
    -- newer value; overwriting it with a stale original would itself be a bug.
    if not r.pendingRestore and r.last and current and not tuplesMatch(r.property,current,r.last) then records[key]=nil; return true end
    if writeNative(r.setter,r.node,r.original) then
        local actual=readNative(r.getter,r.node)
        if r.property == "shadowMap" then actual=shadowTuple(actual) end
        if tuplesMatch(r.property,actual,r.original) then records[key]=nil; return true end
    end
    r.pendingRestore=true
    return false
end
local function splitOwned(node)
    if not FS25E_LightDiscovery.isLightSource(node) then merges[node]=nil; return true end
    if type(splitLightShadow)~="function" or type(hasMergedShadow)~="function" then return false end
    local ok=pcall(splitLightShadow,node)
    local readOk,merged=pcall(hasMergedShadow,node)
    if ok and readOk and not merged then merges[node]=nil; return true end
    return false
end
function M.restoreOwner(owner)
    local ok=true
    for key,r in pairs(records) do if r.owner == owner then ok=restoreRecord(key,r) and ok end end
    for node,entry in pairs(merges) do
        if entry.owner == owner then
            ok=splitOwned(node) and ok
        end
    end
    return ok
end
function M.restoreAll()
    running=false
    local ok=true
    for key,r in pairs(records) do ok=restoreRecord(key,r) and ok end
    for node in pairs(merges) do
        ok=splitOwned(node) and ok
    end
    -- A global reset clears requested overrides as well as native mutations.
    -- Otherwise enabling one slider later silently reapplies earlier sliders.
    for _,d in ipairs(definitions) do settings[d[1]]=d[6] end
    requested={}
    return ok
end
function M.reset()
    M.restoreAll()
    locks={}; elapsed=0; slowElapsed=20000; lastScene={}
    for _,d in ipairs(definitions) do settings[d[1]]=d[6] end
end
function M.init()
    M.reset()
    running=true
    if not chargeHook and FS25E_HookManager and RealLight and type(RealLight.setCharge)=="function" then
        chargeHook=FS25E_HookManager.register(RealLight,"setCharge","appended",function(light)
            if not running then return end
            for _,node in ipairs(light.lightSources or {}) do
                local key=tostring(node)..":color"
                local record=records[key]
                if record then
                    -- This callback runs immediately after vanilla setCharge;
                    -- even an accidentally equal color is a fresh game value.
                    local native=readNative("getLightColor",node)
                    if native then record.original=native; record.last=nil end
                    M.applyColor({node=node,owner=record.owner})
                end
            end
        end)==true
    end
end
function M.setLocked(id,value) locks[id]=value == true end
function M.isLocked(id) return locks[id] == true end
function M.getSettings() return settings end
function M.getRequestedValues()
    local values={}; for id in pairs(requested) do values[id]=settings[id] end; return values
end
function M.getDiagnostics() return lastResult end
function M.getRecords() return records end

local function entries()
    if FS25E_LightDiscovery and FS25E_LightDiscovery.getRuntimeEntries then return FS25E_LightDiscovery.getRuntimeEntries() end
    return {}
end
local function position(node)
    if not exists(node) or type(getWorldTranslation) ~= "function" then return nil end
    local ok,x,y,z=pcall(getWorldTranslation,node)
    if ok and type(x)=="number" and type(y)=="number" and type(z)=="number" then return {x,y,z} end
end
local function cameraContext(scene)
    local cameraNode=scene.cameraNode or scene.cameraId
    if cameraNode == nil and type(getCamera) == "function" then local ok,n=pcall(getCamera); if ok then cameraNode=n end end
    local pos=position(cameraNode)
    local dir=nil
    if exists(cameraNode) and type(localDirectionToWorld)=="function" then
        local ok,x,y,z=pcall(localDirectionToWorld,cameraNode,0,0,-1)
        if ok and type(x)=="number" then dir={x,y,z} end
    end
    return pos,dir
end
local function lightKind(e)
    if e.kind == "placeable" then return "placeable" end
    if e.realLight and Lights then
        for _,v in pairs(e.realLight.lightTypes or {}) do
            if v == Lights.LIGHT_TYPE_WORK_FRONT or v == Lights.LIGHT_TYPE_WORK_BACK then return "worklight" end
        end
    end
    return "headlight"
end
function M.score(entry,scene,camPos,camDir)
    local pos=position(entry.node)
    local distance,facing=math.huge,1
    if pos and camPos then
        local x,y,z=pos[1]-camPos[1],pos[2]-camPos[2],pos[3]-camPos[3]
        distance=math.sqrt(x*x+y*y+z*z)
        if camDir and distance>0.1 then facing=(x*camDir[1]+y*camDir[2]+z*camDir[3])/distance end
    end
    local currentVehicle=g_currentMission and g_currentMission.controlledVehicle
    local own=entry.owner ~= nil and (entry.owner == currentVehicle or entry.owner == scene.vehicle)
    local importance=own and 100 or (entry.kind=="vehicle" and 80 or 65)
    if not own then importance=importance/(1+(distance/55)^2) end
    if facing<0 then importance=importance*(1-settings.behindCameraReduction) end
    local fog=tonumber(scene.fog or scene.fogFactor) or 0
    if distance>60 then importance=importance*(1-clamp(fog,0,1)*0.9) end
    if not entry.active then importance=0 end
    entry.distance,entry.facing,entry.importance,entry.lightKind=distance,facing,importance,lightKind(entry)
    return importance
end
local function scalar(e,p,g,s,f)
    return M.applyProperty(e,p,g,s,function(v)
        if type(v[1]) ~= "number" then return nil end
        return {f(v[1])}
    end)
end
function M.applyColor(e)
    return M.applyProperty(e,"color","getLightColor","setLightColor",function(v)
        if #v~=3 then return nil end
        local w,t=settings.lightWarmth,settings.lightTint
        -- Wide creative range with a neutral centre and conserved luminance.
        -- At the endpoints warm/cool changes red-to-blue balance by 16:1.
        local r,g,b=v[1]*4^w*2^t,v[2]*4^(-t),v[3]*4^(-w)*2^t
        local before=0.2126*v[1]+0.7152*v[2]+0.0722*v[3]
        local after=0.2126*r+0.7152*g+0.0722*b
        local factor=after>0.00001 and before/after*settings.lightIntensity or 0
        return {r*factor,g*factor,b*factor}
    end)
end
local function anyRequested(...)
    for _,id in ipairs({...}) do if requested[id] then return true end end
    return false
end
local function controlDependencies(id)
    local exact={
        shadowSoftness={"getLightSoftShadowSize","setLightSoftShadowSize"},
        softShadowBias={"getLightSoftShadowDepthBiasFactor","setLightSoftShadowDepthBiasFactor"},
        shadowExtrusion={"getLightShadowExtrusionDistance","setLightShadowExtrusionDistance"},
        lightFalloff={"getLightDropOff","setLightDropOff"},
        lightCone={"getLightConeAngle","setLightConeAngle"},
        shadowMerge={"hasMergedShadow","mergeLightShadows"},
    }
    if exact[id] then return exact[id][1],exact[id][2] end
    if id:find("Shadow") or id:find("shadow") or id=="localShadows" then return "getLightCastingShadowMap","setLightShadowMap" end
    if id:find("scattering") or id:find("Scattering") then return "getLightScatteringIntensity","setLightScatteringIntensity" end
    if id:find("ies") or id:find("IES") then return "getLightIESProfile","setLightIESProfile" end
    if id=="lightIntensity" or id=="lightWarmth" or id=="lightTint" then return "getLightColor","setLightColor" end
    return "getLightRange","setLightRange"
end
local function available(id)
    local getter,setter=controlDependencies(id)
    if type(_G[getter]) ~= "function" or type(_G[setter]) ~= "function" then return false,"FS25E_warning_lightApiUnavailable" end
    if #entries()==0 then return false,"FS25E_status_noLocalLights" end
    return true
end
local function mergeEligible(ranked)
    if settings.shadowMerge==0 or type(mergeLightShadows)~="function" or type(splitLightShadow)~="function"
        or type(hasMergedShadow)~="function" or RealLight==nil or type(RealLight.getAreShadowsMergable)~="function" then return end
    local groups={}
    for _,e in ipairs(ranked) do
        if e.active and e.distance<=settings.lightHighRadius and e.kind=="vehicle" and e.importance>40 then
            local ok,merged=pcall(hasMergedShadow,e.node)
            if ok and not merged then
                local key=tostring(e.owner)..":"..tostring(e.bucket)..":"..e.lightKind
                groups[key]=groups[key] or {}; table.insert(groups[key],e)
            end
        end
    end
    for _,group in pairs(groups) do
        if #group>=2 then
            local nodes={}; for i=1,math.min(4,#group) do nodes[i]=group[i].node end
            local ok,compatible=pcall(RealLight.getAreShadowsMergable,nodes)
            if ok and compatible and pcall(mergeLightShadows,unpackValues(nodes)) then
                for i,node in ipairs(nodes) do
                    local verified,merged=pcall(hasMergedShadow,node)
                    if verified and merged then merges[node]=group[i] end
                end
            end
        end
    end
end

function M.refresh(scene,allowResolution)
    scene=scene or lastScene or {}; lastScene=scene
    if next(requested)==nil and next(records)==nil and next(merges)==nil then
        lastResult={applied=0,failed=0,active=0,total=0}
        return true
    end
    local ranked=entries(); local pos,dir=cameraContext(scene)
    for _,e in ipairs(ranked) do M.score(e,scene,pos,dir) end
    table.sort(ranked,function(a,b) if a.importance==b.importance then return tostring(a.node)<tostring(b.node) end return a.importance>b.importance end)
    local result={applied=0,failed=0,active=0,total=#ranked}
    local function track(ok,reason)
        if reason=="FS25E_warning_lightApiUnavailable" then return end
        if ok then result.applied=result.applied+1 else result.failed=result.failed+1 end
    end
    local rain=clamp(tonumber(scene.rain or scene.rainFactor or scene.rainAmount) or 0,0,1)
    local fog=clamp(tonumber(scene.fog or scene.fogFactor) or 0,0,1)
    local shadowCount,iesCount,scatterCount=0,0,0
    local touched={}
    for _,e in ipairs(ranked) do
        if e.active then
            touched[e.node]=true
            result.active=result.active+1
            local relevant=(not requested.relevantLightBudget or result.active<=settings.relevantLightBudget)
                and (not anyRequested('lightHighRadius','lightMediumRadius') or e.distance<=math.max(settings.lightHighRadius,settings.lightMediumRadius))
            local near=e.distance<=settings.lightHighRadius
            local ies=readNative("getLightIESProfile",e.node)
            local iesRec=records[tostring(e.node)..":ies"]
            local profile=iesRec and iesRec.original[1] or (ies and ies[1])
            local hasIES=type(profile)=="string" and profile~=""
            local kind=e.lightKind
            if hasIES and anyRequested('iesMode','iesBudget','headlightIES','worklightIES','placeableIES','relevantLightBudget') then
                local enabled=settings.iesMode==1 and settings[kind.."IES"]==1 and relevant and (not requested.iesBudget or iesCount<settings.iesBudget)
                if enabled then iesCount=iesCount+1 end
                track(M.applyProperty(e,"ies","getLightIESProfile","setLightIESProfile",function(v) return {enabled and v[1] or ""} end))
            end
            local rangeScale=settings.lightRange*(hasIES and settings.iesRange or 1)
            if anyRequested('lightRange','iesRange') then track(scalar(e,"range","getLightRange","setLightRange",function(v) return math.max(0.01,v*rangeScale) end)) end
            if anyRequested('lightFalloff','iesFalloff') then track(scalar(e,"dropoff","getLightDropOff","setLightDropOff",function(v) return math.max(0.01,v*settings.lightFalloff*(hasIES and settings.iesFalloff or 1)) end)) end
            if requested.lightCone then track(scalar(e,"cone","getLightConeAngle","setLightConeAngle",function(v) return clamp(v*settings.lightCone,0.01,math.pi-0.01) end)) end
            if anyRequested('lightIntensity','lightWarmth','lightTint') then track(M.applyColor(e)) end
            local scattering=relevant and (not requested.scatteringBudget or scatterCount<settings.scatteringBudget)
                and (not requested.scatteringDistance or e.distance<=settings.scatteringDistance) and settings[kind.."Scattering"]==1
                and not (requested.scatteringIntensity and settings.scatteringIntensity<=0)
            if scattering then scatterCount=scatterCount+1 end
            -- Most authored lamps ship with scattering switched off. Asking for an
            -- intensity is asking for the effect, so the switch follows along.
            if anyRequested('scatteringBudget','scatteringDistance','headlightScattering','worklightScattering','placeableScattering','relevantLightBudget','scatteringIntensity') then
                track(M.applyProperty(e,"scatterEnabled","getLightUseLightScattering","setLightUseLightScattering",function() return {scattering} end))
            end
            local weather=1+(requested.scatteringWeatherResponse and settings.scatteringWeatherResponse or 0)*(fog*1.25+rain*0.35)
            if anyRequested('scatteringIntensity','scatteringWeatherResponse') then
                -- An authored intensity of 0 would stay 0 under any multiplier; treat
                -- it as 1 so the slider has something to scale.
                track(scalar(e,"scatter","getLightScatteringIntensity","setLightScatteringIntensity",function(v)
                    local base=(v and v>0.001) and v or 1
                    return base*settings.scatteringIntensity*weather end))
            end
            if settings.localShadows==1 then
                if anyRequested('localShadowBudget','behindCameraReduction') then
                    track(scalar(e,"priority","getLightShadowPriority","setLightShadowPriority",function() return e.importance/100 end))
                end
                if anyRequested('localShadows','localShadowBudget','vehicleShadowRange','nearShadowResolution','farShadowResolution') then
                    local current=shadowTuple(readNative("getLightCastingShadowMap",e.node))
                    if current then
                        local record=records[tostring(e.node)..':shadowMap']
                        local original=record and record.original or current
                        local cast=original[1]
                        if anyRequested('localShadows','localShadowBudget','vehicleShadowRange') then
                            cast=(not requested.localShadowBudget or shadowCount<settings.localShadowBudget)
                                and (not requested.vehicleShadowRange or e.distance<=settings.vehicleShadowRange)
                        end
                        if cast then shadowCount=shadowCount+1 end
                        local resolution=current[2]
                        local resolutionId=near and 'nearShadowResolution' or 'farShadowResolution'
                        if allowResolution and requested[resolutionId] then resolution=({256,512,1024,2048})[settings[resolutionId]+1] end
                        track(M.applyProperty(e,"shadowMap","getLightCastingShadowMap","setLightShadowMap",function() return {cast,resolution} end))
                    end
                end
                if requested.shadowSoftness then track(scalar(e,"softness","getLightSoftShadowSize","setLightSoftShadowSize",function(v) return v*settings.shadowSoftness end)) end
                if requested.softShadowBias then track(scalar(e,"bias","getLightSoftShadowDepthBiasFactor","setLightSoftShadowDepthBiasFactor",function(v) return v*settings.softShadowBias end)) end
                if requested.shadowExtrusion then track(scalar(e,"extrusion","getLightShadowExtrusionDistance","setLightShadowExtrusionDistance",function(v) return v*settings.shadowExtrusion end)) end
            end
        end
    end
    -- Keep mutation and GPU work bounded; lights leaving the local candidate
    -- set regain their native state. No map-wide rendering grid is overwritten.
    for key,r in pairs(records) do if not touched[r.node] then restoreRecord(key,r) end end
    for node in pairs(merges) do if not touched[node] then splitOwned(node) end end
    if allowResolution and requested.shadowMerge then mergeEligible(ranked) end
    result.shadows,result.ies,result.scattering=shadowCount,iesCount,scatterCount
    lastResult=result
    return result.failed==0, result.failed>0 and "FS25E_warning_lightWriteRejected" or (result.active==0 and "FS25E_status_lightValuesQueued" or nil)
end
function M.update(dt,scene)
    running=true
    elapsed=elapsed+(tonumber(dt) or 0); slowElapsed=slowElapsed+(tonumber(dt) or 0)
    if elapsed<250 then return end
    elapsed=0
    local slow=slowElapsed>=15000
    if slow then slowElapsed=0 end
    M.refresh(scene,slow)
end
function M.set(id,value,fromAuto)
    local d=index[id]
    if not d or type(value)~="number" or value~=value then return false,"FS25E_warning_lightInvalidValue" end
    local ready,reason=available(id)
    if not ready then return false,reason end
    settings[id]=clamp(math.floor((value-d[3])/d[5]+0.5)*d[5]+d[3],d[3],d[4])
    requested[id]=true
    if id=="localShadows" and settings[id]==0 then
        for key,r in pairs(records) do
            if r.property=="shadowMap" or r.property=="priority" or r.property=="softness" or r.property=="bias" or r.property=="extrusion" then restoreRecord(key,r) end
        end
    end
    if id=="shadowMerge" and settings[id]==0 then
        for node in pairs(merges) do splitOwned(node) end
    end
    return M.refresh(lastScene,not fromAuto or id=="nearShadowResolution" or id=="farShadowResolution")
end
-- Governors may adjust requested configuration; user locks are honored here.
function M.setAuto(id,value)
    if locks[id] then return false,"FS25E_status_locked" end
    return M.set(id,value,true)
end
local propertyRequests={
    color={'lightIntensity','lightWarmth','lightTint'},
    range={'lightRange','iesRange'},
    dropoff={'lightFalloff','iesFalloff'},
    cone={'lightCone'},
    ies={'iesMode','iesBudget','headlightIES','worklightIES','placeableIES','relevantLightBudget','lightHighRadius','lightMediumRadius','behindCameraReduction'},
    scatterEnabled={'scatteringBudget','scatteringDistance','headlightScattering','worklightScattering','placeableScattering','relevantLightBudget','lightHighRadius','lightMediumRadius','behindCameraReduction'},
    scatter={'scatteringIntensity','scatteringWeatherResponse'},
    shadowMap={'localShadows','localShadowBudget','vehicleShadowRange','nearShadowResolution','farShadowResolution','lightHighRadius','behindCameraReduction'},
    priority={'localShadows','localShadowBudget','behindCameraReduction'},
    softness={'localShadows','shadowSoftness'},
    bias={'localShadows','softShadowBias'},
    extrusion={'localShadows','shadowExtrusion'},
}
function M.restoreControl(id)
    local d=index[id]
    if not d then return false,'FS25E_warning_lightInvalidValue' end
    requested[id]=nil; settings[id]=d[6]
    local affected={}
    for property,ids in pairs(propertyRequests) do
        for _,candidate in ipairs(ids) do if candidate==id then affected[property]=true; break end end
    end
    local ok=true
    -- First recover the real engine baseline for shared tuples, then reapply
    -- only remaining requests. Resetting warmth must preserve requested intensity.
    for key,r in pairs(records) do if affected[r.property] then ok=restoreRecord(key,r) and ok end end
    if id=='shadowMerge' then for node in pairs(merges) do ok=splitOwned(node) and ok end end
    if not ok then return false,'FS25E_warning_lightWriteRejected' end
    return M.refresh(lastScene,true)
end
function M.getControls()
    local out={}
    for _,d in ipairs(definitions) do
        local id=d[1]
        local binary=d[3]==0 and d[4]==1 and d[5]==1
        local resolution=id=="nearShadowResolution" or id=="farShadowResolution"
        out[#out+1]={id=id,category=d[2],labelKey="FS25E_setting_"..id,tooltipKey="FS25E_tooltip_"..id,
            min=d[3],max=d[4],step=d[5],cost=d[7],experimental=id=="shadowMerge",
            kind=binary and "bool" or "number",verification="configuration",
            format=resolution and function(value) return tostring(({256,512,1024,2048})[math.floor(value)+1] or value) end or nil,
            read=function() return settings[id] end,
            write=function(value) return M.set(id,value) end,
            restore=function() return M.restoreControl(id) end,
            available=function() return available(id) end}
    end
    return out
end
