-- Independent module boundaries: one adapter failure cannot stop the live window.
FS25E_ModuleRuntime = { failed = {}, pendingRestores = {}, elapsed = 0 }
local R = FS25E_ModuleRuntime
local names = {
    'FS25E_LightTuning', 'FS25E_GlobalLighting', 'FS25E_EnvironmentLighting', 'FS25E_LightingMoods',
    'FS25E_WeatherManager', 'FS25E_MaterialManager', 'FS25E_FoliageManager', 'FS25E_WaterManager',
    'FS25E_WetSurfaceManager', 'FS25E_GameSettingsControls', 'FS25E_QualityLevels'
}
local extraProviders = { 'FS25E_VisualProfiles', 'FS25E_SessionControls' }

local function restore(m)
    local f = m.restoreAll or m.restore
    if f then return f() end
    return true
end
local function warn(message)
    if FS25E_Debug and type(FS25E_Debug.warning) == 'function' then FS25E_Debug.warning('ModuleRuntime', message) end
end
local function restoreOne(name)
    local m = _G[name]
    if not m then R.pendingRestores[name] = nil; return true end
    local ok, result = pcall(restore, m)
    if not ok or result == false then R.pendingRestores[name] = true; return false end
    R.pendingRestores[name] = nil
    return true
end
local function invoke(name, method, ...)
    local m = _G[name]
    if not m or type(m[method]) ~= 'function' then return true end
    local ok, result = pcall(m[method], ...)
    if not ok or result == false then
        local message = not ok and tostring(result) or (method .. ' returned false')
        if R.failed[name] ~= message then warn(name .. '.' .. method .. ': ' .. message) end
        R.failed[name] = message
        restoreOne(name)
        return false
    end
    return ok
end

function R.install()
    if g_dedicatedServer ~= nil then return end
    for _, name in ipairs(names) do invoke(name, 'install') end
end

function R.init()
    R.suspended = false
    if R.mission ~= g_currentMission then R.pendingRestores = {} end
    R.mission = g_currentMission
    R.failed = {}
    R.install()
    FS25E_VisualControls.reset()
    FS25E_VisualControls.build()
    for _, name in ipairs(names) do
        invoke(name, 'init')
        if _G[name] and not R.failed[name] then
            _G[name]._fs25eModuleName = name
            local ok, err = pcall(FS25E_VisualControls.registerProvider, _G[name])
            if not ok then R.failed[name] = tostring(err) end
        end
    end
    for _, name in ipairs(extraProviders) do
        local m = _G[name]
        if m then
            if type(m.init) == 'function' then pcall(m.init) end
            pcall(FS25E_VisualControls.registerProvider, m)
        end
    end
end

function R.update(dt)
    if g_dedicatedServer ~= nil then return end
    R.elapsed = R.elapsed + math.max(0, tonumber(dt) or 0)
    if R.elapsed >= 1000 then
        R.elapsed = 0
        for name in pairs(R.pendingRestores) do restoreOne(name) end
        if FS25E_CapabilityApplier and FS25E_CapabilityApplier.retryPending then
            FS25E_CapabilityApplier.retryPending()
        end
    end
    if R.suspended then return end
    local scene = {}
    for _, name in ipairs(names) do
        if not R.failed[name] then invoke(name, 'update', dt, scene) end
    end
end

function R.setSuspended(value) R.suspended = value == true end

function R.restoreAll()
    local ok = true
    for i = #names, 1, -1 do
        if not restoreOne(names[i]) then ok = false end
    end
    return ok
end

function R.reset()
    R.suspended = false
    R.restoreAll()
    local ok = true
    for _, name in ipairs(names) do if not invoke(name, 'reset') then ok = false end end
    for _, name in ipairs(extraProviders) do invoke(name, 'reset') end
    if next(R.pendingRestores) ~= nil then ok = false end
    if ok then FS25E_VisualControls.reset(); R.failed = {} end
    R.install()
    return ok
end
