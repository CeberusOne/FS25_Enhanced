-- Regenerates docs/CONTROL_CATALOG.json from the live control definitions:
-- every source file from modDesc.xml is loaded against the stub engine, all
-- providers are registered and VisualControls.getMetadata is dumped per id.
--   MOD_DIR="$PWD" lua tools/exportCatalog.lua
local MOD = os.getenv('MOD_DIR') or '.'
dofile(MOD .. '/tools/engineStub.lua')
g_currentModName = 'FS25_Enhanced'
g_currentModDirectory = MOD .. '/'

local modDesc = assert(io.open(MOD .. '/modDesc.xml', 'r')):read('*a')
for file in modDesc:gmatch('<sourceFile filename="([^"]+)"') do
    local chunk, err = loadfile(MOD .. '/' .. file)
    if not chunk then error('load ' .. file .. ': ' .. tostring(err)) end
    local ok, runErr = pcall(chunk)
    if not ok then error('run ' .. file .. ': ' .. tostring(runErr)) end
end

FS25E_ModSettings.init()
FS25E_CapabilityRegistry.load(MOD .. '/')
FS25E_VisualControls.reset()
FS25E_VisualControls.build()
for _, name in ipairs({ 'FS25E_LightTuning', 'FS25E_GlobalLighting', 'FS25E_EnvironmentLighting', 'FS25E_LightingMoods',
    'FS25E_WeatherManager', 'FS25E_MaterialManager', 'FS25E_FoliageManager',
    'FS25E_WaterManager', 'FS25E_WetSurfaceManager', 'FS25E_GameSettingsControls', 'FS25E_QualityLevels',
    'FS25E_RuntimeControls', 'FS25E_VisualProfiles', 'FS25E_ProbeSession' }) do
    local m = _G[name]
    if m then
        m._fs25eModuleName = name
        local ok, err = pcall(FS25E_VisualControls.registerProvider, m)
        if not ok then io.stderr:write('provider ' .. name .. ': ' .. tostring(err) .. '\n') end
    end
end

local function jsonString(s)
    return '"' .. tostring(s):gsub('[%c"\\]', function(c)
        if c == '"' then return '\\"' elseif c == '\\' then return '\\\\' elseif c == '\n' then return '\\n' end
        return string.format('\\u%04x', c:byte())
    end) .. '"'
end
local function jsonValue(v)
    local t = type(v)
    if t == 'number' then
        if v ~= v or math.abs(v) == math.huge then return 'null' end
        if v == math.floor(v) then return string.format('%d', v) end
        return string.format('%.6g', v)
    elseif t == 'boolean' then return tostring(v)
    elseif t == 'string' then return jsonString(v)
    else return 'null' end
end

local entries = {}
for _, c in ipairs(FS25E_VisualControls.getControls()) do
    local meta = FS25E_VisualControls.getMetadata(c.id)
    if meta then
        meta.kind = c.kind or 'number'
        meta.runtimeControl = c.runtimeControl == true
        local keys = {}
        for k in pairs(meta) do keys[#keys + 1] = k end
        table.sort(keys)
        local fields = {}
        for _, k in ipairs(keys) do fields[#fields + 1] = jsonString(k) .. ': ' .. jsonValue(meta[k]) end
        entries[#entries + 1] = '  {' .. table.concat(fields, ', ') .. '}'
    end
end
local out = assert(io.open(MOD .. '/docs/CONTROL_CATALOG.json', 'w'))
out:write('[\n' .. table.concat(entries, ',\n') .. '\n]\n')
out:close()
io.write('catalog entries: ', #entries, '\n')
