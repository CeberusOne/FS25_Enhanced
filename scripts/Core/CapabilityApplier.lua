-- Reversible scalar capability adapter. Typed asset/light APIs have dedicated managers.
FS25E_CapabilityApplier = {}
local M=FS25E_CapabilityApplier
local unpackValues=table.unpack or unpack
local applied={}
local GATED_SUPPORT={
    ["volumetric-fog-quality"]="getSupportsVolumetricFogQuality",
    ["lensflare-quality"]="getSupportsLensFlareQuality",
    ["screen-space-shadows-quality"]="getSupportsScreenSpaceShadowsQuality",
    ["ssr-quality"]="getSupportsScreenSpaceReflectionsQuality",
    ["atmosphere-quality"]="getSupportsAtmosphereQuality",
}
local function resolveGlobal(name)
    return name~=nil and type(_G[name])=="function" and _G[name] or nil
end
local function equal(a,b)
    if a==b then return true end
    return type(a)=="number" and type(b)=="number" and math.abs(a-b)<1e-4
end
local function read(getterName,prefix,withFocus)
    local getter=resolveGlobal(getterName)
    if not getter then return nil end
    local ok,value=pcall(getter,unpackValues(prefix or {}))
    if not ok or value==nil then return nil end
    if type(value)=="number" and (value~=value or math.abs(value)==math.huge) then return nil end
    local out={value}
    if withFocus then
        local fn=resolveGlobal("getHasShadowFocusBox")
        if not fn then return nil end
        local focusOk,focus=pcall(fn)
        if not focusOk or type(focus)~="boolean" then return nil end
        out[2]=focus
    end
    return out
end
local function same(a,b)
    if a==nil or b==nil or #a~=#b then return false end
    for i=1,#a do if not equal(a[i],b[i]) then return false end end
    return true
end
local function write(setterName,prefix,values)
    -- This hardware buffer multiplier is not the current weather intensity.
    -- A zero-sized rain buffer crashes the game; also guard rollback/restore.
    -- Natural setRainActiveDropsMultiplier(..., 0) transitions are unrelated.
    if setterName=="setRainAmountMultiplier" and
        (type(values[1])~="number" or values[1]<=0 or values[1]~=values[1]) then
        return false,"rain amount hardware multiplier must be positive"
    end
    local setter=resolveGlobal(setterName)
    if not setter then return false,"setter unavailable" end
    local args={}
    for _,v in ipairs(prefix or {}) do args[#args+1]=v end
    for _,v in ipairs(values or {}) do args[#args+1]=v end
    local ok,result=pcall(setter,unpackValues(args))
    if not ok then return false,tostring(result) end
    if result==false then return false,"setter returned false" end
    return true
end
local function noteRejected(id,reason,fatal)
    if FS25E_CapabilityRegistry then
        if fatal and FS25E_CapabilityRegistry.reject then FS25E_CapabilityRegistry.reject(id,reason)
        elseif FS25E_CapabilityRegistry.markSkipped then FS25E_CapabilityRegistry.markSkipped(id,reason) end
    end
    if FS25E_Debug then FS25E_Debug.warning("CapabilityApplier",tostring(id)..": "..tostring(reason)) end
end
local function cacheUpdate(key,id,original,current,requested)
    if not FS25E_SettingsCache then return end
    FS25E_SettingsCache.captureOriginal(key,original[1])
    FS25E_SettingsCache.setRequested(key,requested[1])
    local e=FS25E_SettingsCache.get(key)
    if e then
        e.original=original[1]; e.current=current[1]; e.requested=requested[1]
        e.capabilityId=id; e.needsCalibration=true
        if FS25E_SettingsCache.APPLY_MODE then e.applyMode=FS25E_SettingsCache.APPLY_MODE.SESSION end
    end
end
function M.checkGatedSupport(id,value)
    local name=GATED_SUPPORT[id]
    if not name then return true end
    local fn=resolveGlobal(name)
    if not fn then return false,"support gate unavailable: "..name end
    local ok,supported=pcall(fn,value)
    if not ok or supported~=true then return false,"requested quality unsupported: "..name end
    return true
end
function M.apply(id,opts)
    opts=opts or {}
    local registry=FS25E_CapabilityRegistry
    local cap=registry and registry.get and registry.get(id)
    if not cap then return false,"unknown capability" end
    if id=="fast-shadow-update" or id=="shadow-focus-box" or id=="rain-shallow-water-simulation" then
        return false,"requires a camera/shape/simulation asset; not a global boolean"
    end
    if id=="drs-quality" or id=="save-hardware-scalability" or id=="apply-performance-class" or id=="terrain-quality" or cap.applyMode=="RESTART" then
        return false,"not a live session setting"
    end
    local prefix=opts.prefixArgs or {}
    if cap.scope=="per-light" or #prefix>0 or id=="light-shadow-map" or id=="merge-light-shadows" then
        return false,"use the typed, owned light/asset adapter"
    end
    local expert=opts.expertMode
    if expert==nil and FS25E_SettingsSchema and FS25E_SettingsSchema.get then expert=FS25E_SettingsSchema.get("expertMode") end
    if not registry.allowsApply or not registry.allowsApply(id,expert==true) then return false,"capability is not allowed" end
    if not resolveGlobal(cap.setter) then return false,"setter unavailable" end
    local values={}
    for i,v in ipairs(opts.values or {}) do values[i]=v end
    if #values==0 and opts.value~=nil then values[1]=opts.value end
    if #values==0 or (#values~=1 and id~="shadow-quality") or #values>2 then return false,"invalid scalar argument count" end
    if type(values[1])~="number" and type(values[1])~="boolean" then return false,"invalid scalar value" end
    if type(values[1])=="number" and (values[1]~=values[1] or math.abs(values[1])==math.huge) then return false,"non-finite value" end
    if id=="rain-amount-mult" or cap.setter=="setRainAmountMultiplier" then
        if type(values[1])~="number" then return false,"rain amount must be numeric" end
        values[1]=math.max(0.01,values[1])
    end
    if not opts.skipGateCheck and (GATED_SUPPORT[id] or cap.status=="GATED" or cap.baseStatus=="GATED") then
        local ok,reason=M.checkGatedSupport(id,values[1]); if not ok then return false,reason end
    end
    local focus=id=="shadow-quality"
    local before=read(cap.getter,prefix,focus)
    if not before then return false,"native original value unavailable; write blocked" end
    if cap.setter=="setRainAmountMultiplier" and (type(before[1])~="number" or before[1]<=0) then
        return false,"rain amount original is not safely restorable; write blocked"
    end
    if focus then
        if values[2]==nil then values[2]=before[2] end
        if type(values[2])~="boolean" then return false,"shadow focus must be boolean" end
    end
    local suffix=opts.keySuffix
    local key=tostring(id)..((suffix~=nil and suffix~="") and ("|"..tostring(suffix)) or "")
    local previous=applied[key]
    local original=before
    if previous and same(before,previous.appliedValues) then
        original=previous.originalValues or {previous.original}
        if focus and original[2]==nil then original[2]=previous.originalFocus end
    end
    if same(before,values) then
        cacheUpdate(key,id,original,before,values)
        return true
    end
    local entry={capabilityId=id,setterName=cap.setter,getterName=cap.getter,prefixArgs=prefix,
        original=original[1],originalValues=original,originalFocus=focus and original[2] or nil,
        hadGetter=true,appliedValue=values[1],appliedValues=values,restoreStrategy="YES",withFocus=focus}
    -- Preserve false in the second member; Lua's and/or shorthand loses it.
    if focus then entry.originalFocus=original[2] end
    local setOk,setReason=write(cap.setter,prefix,values)
    local actual=read(cap.getter,prefix,focus)
    if not setOk or not same(actual,values) then
        local rollbackOk=write(cap.setter,prefix,before)
        local rolledBack=read(cap.getter,prefix,focus)
        if not rollbackOk or not same(rolledBack,before) then
            -- A partially accepted native setter must remain restorable even
            -- though this request was rejected and never marked APPLIED.
            entry.appliedValues=actual or values; entry.appliedValue=entry.appliedValues[1]
            entry.pendingRestore=true; applied[key]=entry
            if FS25E_RestoreManager and FS25E_RestoreManager.registerCapabilityRestore then FS25E_RestoreManager.registerCapabilityRestore(key) end
        elseif previous then
            applied[key]=previous
        end
        local reason=setReason or "engine did not accept requested value (read-back mismatch)"
        -- A rejected value with a verified rollback does not mean the entire
        -- interface is broken. Keep lower/supported values available to retry.
        noteRejected(id,reason,not rollbackOk or not same(rolledBack,before))
        return false,reason
    end
    applied[key]=entry
    cacheUpdate(key,id,original,actual,values)
    if not opts.skipRestoreRegister and FS25E_RestoreManager and FS25E_RestoreManager.registerCapabilityRestore then
        FS25E_RestoreManager.registerCapabilityRestore(key)
    end
    if registry.markApplied then registry.markApplied(id,key) end
    return true
end
function M.restoreOne(key)
    local entry=applied[key]
    if not entry then return true end
    local original=entry.originalValues
    if not original and entry.hadGetter and entry.original~=nil then
        original={entry.original}; if entry.originalFocus~=nil then original[2]=entry.originalFocus end
    end
    if not original then entry.pendingRestore=true; return false,"restore original unavailable" end
    local before=read(entry.getterName,entry.prefixArgs,entry.withFocus or entry.originalFocus~=nil)
    if not before then entry.pendingRestore=true; return false,"restore getter unavailable" end
    if not entry.pendingRestore and entry.appliedValues and not same(before,entry.appliedValues) then
        -- The game or another mod owns the newer value. Never resurrect a stale
        -- original after graphics/profile changes outside this mod.
        cacheUpdate(key,entry.capabilityId,before,before,before)
        applied[key]=nil
        return true
    end
    local ok,reason=write(entry.setterName,entry.prefixArgs,original)
    local actual=read(entry.getterName,entry.prefixArgs,entry.withFocus or entry.originalFocus~=nil)
    if not ok or not same(actual,original) then
        entry.pendingRestore=true
        if actual then entry.appliedValues=actual; entry.appliedValue=actual[1] end
        return false,reason or "restore read-back mismatch"
    end
    cacheUpdate(key,entry.capabilityId,original,actual,original)
    applied[key]=nil
    return true
end
function M.restoreAll()
    local keys={}; for key in pairs(applied) do keys[#keys+1]=key end
    table.sort(keys)
    local success=true
    for i=#keys,1,-1 do
        local ok,reason=M.restoreOne(keys[i])
        if not ok then
            success=false
            if FS25E_Debug then FS25E_Debug.warning("CapabilityApplier","restore pending "..keys[i]..": "..tostring(reason)) end
        end
    end
    return success
end
function M.getApplied() return applied end
function M.retryPending()
    local success=true
    for key,entry in pairs(applied) do
        if entry.pendingRestore then success=M.restoreOne(key) and success end
    end
    return success
end
function M.reset()
    -- Never silently discard a failed native restore record.
    return M.restoreAll()
end
function M.resolveGlobal(name) return resolveGlobal(name) end
function M.getGatedSupportMap() return GATED_SUPPORT end
