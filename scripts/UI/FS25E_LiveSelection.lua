-- Visibility preferences only: hiding a control never writes/restores an engine value.
-- Stored alongside client settings, independently of runtime capability availability.
FS25E_LiveSelection = {}
local S = FS25E_LiveSelection
local KEY = 'liveHiddenControls'
local cachedRaw, cachedHidden = nil, {}
local function valid(id) return type(id)=='string' and id:match('^[%w_%-]+$')~=nil end
local function hidden()
    local value=FS25E_ModSettings and FS25E_ModSettings.get(KEY)
    if value==cachedRaw then return cachedHidden end
    local out={}
    if type(value)=='string' then
        for id in value:gmatch('[^,]+') do if valid(id) then out[id]=true end end
    end
    cachedRaw=value; cachedHidden=out
    return out
end
local function copyHidden()
    local out={};for id in pairs(hidden()) do out[id]=true end;return out
end
local function save(values)
    local ids={}; for id in pairs(values) do ids[#ids+1]=id end; table.sort(ids)
    if not FS25E_ModSettings or not FS25E_ModSettings.set(KEY,table.concat(ids,',')) then return false end
    if FS25E_ModSettings.save then return FS25E_ModSettings.save()~=false end
    return true
end
function S.isVisible(control)
    local id=type(control)=='table' and control.id or control
    return valid(id) and not hidden()[id]
end
function S.setVisible(control,visible)
    local id=type(control)=='table' and control.id or control
    if not valid(id) then return false end
    local values=copyHidden(); values[id]=visible~=true and true or nil
    return save(values)
end
function S.setCategoryVisible(category,visible)
    local api=FS25E_VisualControls
    if not api or not api.getControls then return false end
    local values=copyHidden()
    for _,c in ipairs(api.getControls()) do
        if c.category==category and valid(c.id) then values[c.id]=visible~=true and true or nil end
    end
    return save(values)
end
function S.count(category)
    local visible,total=0,0
    local api=FS25E_VisualControls
    local values=hidden()
    if api and api.getControls then
        for _,c in ipairs(api.getControls()) do
            if category==nil or c.category==category then
                total=total+1; if not values[c.id] then visible=visible+1 end
            end
        end
    end
    return visible,total
end
