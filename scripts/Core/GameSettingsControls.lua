-- Client graphics options the engine exposes through GameSettings rather than a
-- free function: field of view, mirror budget and the vehicle lights profile.
-- Values are written with g_gameSettings:setValue, which is what the vanilla
-- settings page uses, so cameras and Lights specializations pick them up live
-- through MessageType.SETTING_CHANGED. Every write is recorded and reverted on
-- mission end; the game only persists whatever is set when it saves settings.
FS25E_GameSettingsControls={}
local M=FS25E_GameSettingsControls
local records,locks={},{}
-- FOV in GameSettings is radians (~1.05 = 60°). The sliders speak degrees.
local defs={
    {id='fovVehicle',key='FOV_Y',category='camera',min=50,max=80,step=1,cost='low',degrees=true},
    {id='fovFirstPerson',key='FOV_Y_PLAYER_FIRST_PERSON',category='camera',min=55,max=85,step=1,cost='low',degrees=true},
    {id='fovThirdPerson',key='FOV_Y_PLAYER_THIRD_PERSON',category='camera',min=50,max=80,step=1,cost='low',degrees=true},
    {id='maxMirrors',key='MAX_NUM_MIRRORS',category='camera',min=0,max=7,step=1,cost='high',
        kind='enum',texts='maxMirrorsTexts'},
    {id='lightsProfile',key='LIGHTS_PROFILE',category='lighting',min=1,max=5,step=1,cost='high',
        kind='enum',texts='fiveStateTexts'},
}
local byId={};for _,d in ipairs(defs) do byId[d.id]=d end
local function finite(v) return type(v)=='number' and v==v and math.abs(v)<math.huge end
local function same(a,b) return finite(a) and finite(b) and math.abs(a-b)<0.0001*math.max(1,math.abs(a),math.abs(b)) end
local function enabled()
    return not FS25E_ModSettings or not FS25E_ModSettings.get or FS25E_ModSettings.get('enabled')==true
end
local function setting(d)
    if g_dedicatedServer~=nil or g_gameSettings==nil or GameSettings==nil or GameSettings.SETTING==nil then return nil end
    if type(g_gameSettings.getValue)~='function' or type(g_gameSettings.setValue)~='function' then return nil end
    local key=GameSettings.SETTING[d.key]
    if key==nil then return nil end
    return key
end
local function nativeRead(d)
    local key=setting(d); if key==nil then return nil end
    local ok,value=pcall(g_gameSettings.getValue,g_gameSettings,key)
    if ok and type(value)=='boolean' then return value and 1 or 0 end
    if ok and finite(value) then return value end
end
local function toUi(d,value)
    if value==nil or not d.degrees then return value end
    -- Radians are always a small number; a leaked degree write is > 5.
    if value>0 and value<5 then return value*180/math.pi end
    return value
end
local function toNative(d,value)
    if not d.degrees then return value end
    return value*math.pi/180
end
-- A previous build wrote slider degrees (30–120) into the radian field.
-- That value is not a valid FOV; treat 70° as the stock original.
local function saneNative(d,native)
    if not d.degrees or native==nil then return native end
    if native>0 and native<5 then return native end
    if native>=50 and native<=80 then return native*math.pi/180 end
    return 70*math.pi/180
end
local function read(d)
    return toUi(d,nativeRead(d))
end
local function writeNative(d,value)
    local key=setting(d); if key==nil then return false end
    local ok=pcall(g_gameSettings.setValue,g_gameSettings,key,value)
    return ok and same(nativeRead(d),value)
end
--- Display texts come from the vanilla settings model, so the mod never invents
--- its own wording for a value the game already labels.
local function texts(d)
    local t=d.texts and g_settingsModel and g_settingsModel[d.texts]
    return type(t)=='table' and #t>0 and t or nil
end
function M.available(id)
    local d=byId[id]
    if not d then return false,'FS25E_status_api_unavailable' end
    return read(d)~=nil,'FS25E_status_api_unavailable'
end
function M.write(id,value,automatic)
    local d=byId[id]
    if not d or not finite(value) then return false,'FS25E_status_invalid_value' end
    if not enabled() then return false,'FS25E_status_mod_disabled' end
    if automatic and locks[id] then return false,'FS25E_status_locked' end
    local currentNative=nativeRead(d); if currentNative==nil then return false,'FS25E_status_api_unavailable' end
    value=math.max(d.min,math.min(d.max,value))
    if d.step>=1 then value=math.floor(value+0.5) end
    local native=toNative(d,value)
    local r=records[id]
    -- The game or another mod may have moved the value in the meantime; adopt
    -- that as the new baseline instead of resurrecting a stale original.
    if r and not r.pendingRestore and not same(r.last,currentNative) then r=nil end
    r=r or {original=saneNative(d,currentNative)}
    if same(currentNative,native) then r.last=currentNative;records[id]=r;return true end
    if not writeNative(d,native) then
        r.pendingRestore=not writeNative(d,currentNative)
        r.last=nativeRead(d);records[id]=r
        return false,'FS25E_status_applyFailed'
    end
    r.last=native;r.pendingRestore=false;records[id]=r
    return true
end
function M.restore(id)
    if not id then
        local ok=true
        for _,d in ipairs(defs) do if not M.restore(d.id) then ok=false end end
        return ok
    end
    local d,r=byId[id],records[id]
    if not d or not r then return true end
    local current=nativeRead(d)
    if current==nil then return false end
    if r.pendingRestore or same(current,r.last) then
        if not writeNative(d,r.original) then r.pendingRestore=true;return false end
    end
    records[id]=nil
    return true
end
function M.restoreAll() return M.restore() end
function M.setLocked(id,value) locks[id]=value==true end
function M.init() return true end
function M.reset()
    local ok=M.restore()
    if ok then locks={} end
    return ok
end
function M.getRequestedValues()
    local values={}
    for id,r in pairs(records) do if not r.pendingRestore then values[id]=r.last end end
    return values
end
function M.getDiagnostics()
    local total,applied,failed=0,0,0
    for _,d in ipairs(defs) do
        if read(d)~=nil then total=total+1 end
        local r=records[d.id]
        if r then if r.pendingRestore then failed=failed+1 else applied=applied+1 end end
    end
    return {total=total,active=total,applied=applied,failed=failed}
end
function M.getControls()
    local controls={}
    for _,def in ipairs(defs) do
        local d=def
        controls[#controls+1]={id=d.id,category=d.category,min=d.min,max=d.max,step=d.step,
            kind=d.kind,cost=d.cost,scope='global',verification='native readback',
            labelKey='FS25E_setting_'..d.id,tooltipKey='FS25E_tooltip_'..d.id,
            format=d.degrees and function(value) return string.format('%.0f°',value) end
                or d.texts and function(value)
                local t=texts(d)
                -- maxMirrors starts at zero, so the text list is offset by one.
                local index=d.id=='maxMirrors' and math.floor(value)+1 or math.floor(value)
                return (t and t[index]) or tostring(value)
            end or nil,
            read=function() return read(d) end,
            available=function() return M.available(d.id) end,
            write=function(value) return M.write(d.id,value) end,
            restore=function() return M.restore(d.id) end}
    end
    return controls
end
