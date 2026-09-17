-- Feature checks and competing-writer diagnostics. Installed mods are not evidence of active mods.
FS25E_CompatibilityManager={}
local M=FS25E_CompatibilityManager
local detected,conflicts,features,watches={}, {}, {}, {}
local elapsed=0
local function equal(a,b)
    if a==b then return true end
    if type(a)=='number' and type(b)=='number' then return math.abs(a-b)<.0001 end
    return false
end
local function callable(name) return type(name)=='string' and name~='NONE' and type(_G[name])=='function' end
function M.init() detected={}; conflicts={}; features={}; watches={}; elapsed=0 end
function M.reset() M.init() end
function M.scan()
    detected={}; features={}
    -- GIANTS TypeManager explicitly uses this mission-loaded table. getModByName only looks up metadata.
    if type(g_modIsLoaded)=='table' then for name,loaded in pairs(g_modIsLoaded) do if loaded==true then detected[name]=true end end end
    if FS25E_CapabilityRegistry and FS25E_CapabilityRegistry.all then
        for id,cap in pairs(FS25E_CapabilityRegistry.all()) do
            features[id]={getterPresent=callable(cap.getter),setterPresent=callable(cap.setter),
                scope=cap.scope,status=cap.status,api=cap.setter or cap.apiName,
                nativeArgumentsVerified=false} -- adapters, not reflection, validate signatures.
        end
    end
    local api=FS25E_VisualControls
    if api and api.getControls then
        for _,control in pairs(api.getControls()) do
            local f=features[control.id] or {}; features[control.id]=f
            if api.available then local ok,available,reason=pcall(api.available,control); f.available=ok and available==true; f.reason=ok and reason or 'FS25E_status_module_error' end
            f.adapterPresent=type(control.read)=='function' and type(control.write)=='function'
            f.assetDependent=control.assetDependent==true
            f.runtimeControl=control.runtimeControl==true
        end
    end
    return features
end
function M.isDetected(name) return detected[name]==true end
function M.getDetected() return detected end
function M.getSoftConflicts() return conflicts end
function M.getFeatures() return features end
function M.getSnapshot()
    return {loadedMods=detected,loadedModsKnown=type(g_modIsLoaded)=='table',features=features,conflicts=conflicts,
        policy='Only an observed writer conflict throttles its affected control; utilities are not blacklisted.'}
end
function M.noteWrite(id,value)
    watches[id]={expected=value,mismatches=0}; conflicts[id]=nil
end
function M.clearConflict(id) conflicts[id]=nil; watches[id]=nil end
function M.inspectOwnedValues()
    local api=FS25E_VisualControls
    if not api or not api.getControls or not api.getState or not api.read then return end
    for _,control in pairs(api.getControls()) do
        local id=control.id; local state=api.getState(id)
        if not control.runtimeControl and state and state.original~=nil and state.current~=nil then
            local expected=state.current; local watch=watches[id]
            if not watch or not equal(watch.expected,expected) then watch={expected=expected,mismatches=0}; watches[id]=watch; conflicts[id]=nil end
            local ok,actual=pcall(api.read,control)
            if ok and actual~=nil and not equal(actual,expected) then
                watch.mismatches=watch.mismatches+1; watch.actual=actual
                if watch.mismatches>=2 then
                    conflicts[id]={reason='external-value-change',reasonKey='FS25E_status_external_change',expected=expected,actual=actual,
                        observations=watch.mismatches,writer='UNKNOWN',action='automatic-control-paused'}
                end
            elseif ok and actual~=nil then watch.mismatches=0; conflicts[id]=nil
            else
                features[id]=features[id] or {}; features[id].available=false; features[id].reason='FS25E_status_unreadable'
            end
        else watches[id]=nil; conflicts[id]=nil end
    end
end
function M.shouldThrottle(id) return conflicts[id]~=nil end
function M.update(dt)
    if type(dt)~='number' or dt~=dt or dt<=0 or dt>1000 then return end
    elapsed=elapsed+dt
    if elapsed>=1000 then elapsed=elapsed%1000; M.inspectOwnedValues() end
end
