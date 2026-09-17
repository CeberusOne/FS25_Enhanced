-- Stub engine shared by the offline tools: enough globals for the control
-- stack to build, read, write and restore without the game.

-- ---- stub engine -------------------------------------------------------
g_dedicatedServer = nil
g_currentMission = { environment = {} }
g_time = 0
ClassIds = { SHAPE = 1 }
Logging = { info = function() end, warning = function(m) io.write('WARN ', tostring(m), '\n') end, error = function(m) io.write('ERR ', tostring(m), '\n') end }
Utils = {
    appendedFunction = function(a, b) return function(...) a(...) return b(...) end end,
    prependedFunction = function(a, b) return function(...) b(...) return a(...) end end,
    overwrittenFunction = function(a, b) return function(self, ...) return b(self, a, ...) end end,
}

-- Engine state the stub setters actually write to, so read-back verification
-- behaves like the real thing.
local state = {
    ViewDistanceCoeff = 1.25, LODDistanceCoeff = 1.25, TerrainLODDistanceCoeff = 1,
    FoliageViewDistanceCoeff = 1, FoliageLODDistanceCoeff = 1, AllowFoliageShadows = true,
    MaxNumShadowLights = 5, ShadowDistanceQuality = 1, ShadowFilterQuality = 1,
    SSAOQuality = 3, ShadingRateQuality = 2, CloudShadowsQuality = 1,
    ShadowMapFilterSize = 3, ShaderQuality = 2, TextureResolution = 1,
    VolumeMeshTessellationCoeff = 1, TyreTracksSegmentsCoeff = 1,
    RainAmountMultiplier = 1, ShadowQuality = 2,
    ToneMappingCurveSlope = 0.88, ToneMappingCurveToe = 0.55, ToneMappingCurveShoulder = 0.26,
    ToneMappingCurveBlackClip = 0, ToneMappingCurveWhiteClip = 0.04,
    SpotShadowFullResolutionPercentage = 0.5, SpotShadowAtlasSlotFactor = 1,
    SpotShadowDistanceFrequencyFactor = 1, SpotShadowMinimumConeAnglePercentage = 0.2,
    SpotShadowReducedConeAngleFactor = 1,
}
for name, _ in pairs(state) do
    _G['get' .. name] = function() return state[name] end
    _G['set' .. name] = function(v) state[name] = v end
end
local shadowFocus = false
getHasShadowFocusBox = function() return shadowFocus end
setShadowQuality = function(v, focus) state.ShadowQuality = v; shadowFocus = focus end

-- quality enums
local function enum(t) return t end
AtmosphereQuality = enum{ OFF = 0, LOW = 1, HIGH = 2 }
ScreenSpaceReflectionsQuality = enum{ OFF = 0, LOW = 1, HIGH = 2 }
ScreenSpaceShadowsQuality = enum{ OFF = 0, ON = 1 }
VolumetricFogQuality = enum{ OFF = 0, LOW = 1, HIGH = 2 }
LensFlareQuality = enum{ OFF = 0, ON = 1 }
DRSQuality = enum{ OFF = 0, ON = 1 }
MSAA = enum{ OFF = 0, X2 = 2, X4 = 4 }
PostProcessAntiAliasing = enum{ OFF = 0, TAA = 1, FXAA = 2 }
DLSSQuality = enum{ OFF = 0, QUALITY = 1, BALANCED = 2 }
FidelityFxSRQuality = enum{ OFF = 0, QUALITY = 1 }
FidelityFxSR30Quality = enum{ OFF = 0, QUALITY = 1 }
XeSSQuality = enum{ OFF = 0, QUALITY = 1 }
ValarQuality = enum{ OFF = 0, ON = 1 }
TEXTURE_FILTERING = enum{ X1 = 1, X4 = 4, X16 = 16 }

local qualityState = {}
for _, name in ipairs({ 'AtmosphereQuality', 'ScreenSpaceReflectionsQuality', 'ScreenSpaceShadowsQuality',
    'VolumetricFogQuality', 'LensFlareQuality', 'DRSQuality', 'MSAA', 'PostProcessAntiAliasing',
    'DLSSQuality', 'FidelityFxSRQuality', 'FidelityFxSR30Quality', 'XeSSQuality', 'ValarQuality' }) do
    qualityState[name] = _G[name].OFF or 0
    _G['get' .. name] = function() return qualityState[name] end
    _G['set' .. name] = function(v) qualityState[name] = v end
    _G['getSupports' .. name] = function() return true end
    _G['get' .. name .. 'Name'] = function(v) return name .. ':' .. tostring(v) end
end
local textureFiltering = 4
getTextureFiltering = function() return textureFiltering end
setTextureFiltering = function(v) textureFiltering = v end
getTextureFilteringName = function(v) return 'aniso ' .. tostring(v) end

SettingsModel = {
    getShadowQualityByIndex = function(i) return i - 1 end,
    getShadowQualityIndex = function(v) return v + 1 end,
    getHasShadowFocusBoxByIndex = function(i) return i > 2 end,
    getShaderQualityByIndex = function(i) return i - 1 end,
    getShaderQualityIndex = function(v) return v + 1 end,
    getTextureResolutionByIndex = function(i) return i - 1 end,
    getTextureResolutionIndex = function(v) return v + 1 end,
    getShadowMapFilterByIndex = function(i) return i == 1 and 3 or 5 end,
    getShadowMapFilterIndex = function(v) return v <= 3 and 1 or 2 end,
}
g_settingsModel = {
    shadowQualityTexts = { 'off', 'medium', 'high', 'veryHigh' },
    fourStateTexts = { 'low', 'medium', 'high', 'veryHigh' },
    lowHighTexts = { 'low', 'high' },
    ssaoQualityTexts = { 'low', 'medium', 'high', 'veryHigh' },
    fiveStateTexts = { 'low', 'medium', 'high', 'veryHigh', 'ultra' },
    maxMirrorsTexts = { '0', '1', '2', '3', '4', '5', '6', '7' },
}
GameSettings = { SETTING = { FOV_Y = 'fovY', FOV_Y_PLAYER_FIRST_PERSON = 'fovY1st',
    FOV_Y_PLAYER_THIRD_PERSON = 'fovY3rd', MAX_NUM_MIRRORS = 'maxNumMirrors', LIGHTS_PROFILE = 'lightsProfile' } }
local gameSettingValues = { fovY = 60, fovY1st = 70, fovY3rd = 50, maxNumMirrors = 7, lightsProfile = 5 }
g_gameSettings = {
    getValue = function(self, key) return gameSettingValues[key] end,
    setValue = function(self, key, value) gameSettingValues[key] = value end,
}

-- Minimal XML reader with GIANTS path syntax ("a.b(2)#attr", "a.b(0).c"):
-- attributes and nesting only, no text nodes. Enough for capability profiles,
-- presets, l10n files and modSettings.
local xmlDocs, xmlNext = {}, 1
local function parseXml(body)
    body = body:gsub('<!%-%-.-%-%->', ''):gsub('<%?.-%?>', ''):gsub('<!%[CDATA%[.-%]%]>', '')
    local root = { children = {}, attrs = {} }
    local stack = { root }
    for closing, name, attrText, selfClose in body:gmatch('<(/?)([%w_:%-]+)([^>]-)(/?)>') do
        if closing == '/' then
            table.remove(stack)
        else
            local node = { name = name, attrs = {}, children = {} }
            for k, v in attrText:gmatch('([%w_:%-]+)%s*=%s*"([^"]*)"') do
                node.attrs[k] = v:gsub('&amp;', '&'):gsub('&lt;', '<'):gsub('&gt;', '>'):gsub('&quot;', '"'):gsub('&apos;', "'")
            end
            local parent = stack[#stack]
            parent.children[#parent.children + 1] = node
            if selfClose ~= '/' then stack[#stack + 1] = node end
        end
    end
    return root
end
local function resolve(doc, path)
    local attr = path:match('#([%w_:%-]+)$')
    path = path:gsub('#[%w_:%-]+$', '')
    local node = doc
    for segment in path:gmatch('[^.]+') do
        local name, index = segment:match('^([%w_:%-]+)%((%d+)%)$')
        if not name then name, index = segment, 0 end
        local found, n = nil, -1
        for _, child in ipairs(node.children) do
            if child.name == name then n = n + 1; if n == tonumber(index) then found = child; break end end
        end
        if not found then return nil end
        node = found
    end
    return node, attr
end
loadXMLFile = function(_, path)
    local f = io.open(path, 'r'); if not f then return 0 end
    local body = f:read('*a'); f:close()
    xmlDocs[xmlNext] = parseXml(body); xmlNext = xmlNext + 1
    return xmlNext - 1
end
getXMLString = function(id, path)
    local node, attr = resolve(xmlDocs[id], path)
    if not node then return nil end
    if attr then return node.attrs[attr] end
    return nil
end
getXMLBool = function(id, path)
    local v = getXMLString(id, path)
    if v == nil then return nil end
    return v == 'true' or v == '1'
end
getXMLFloat = function(id, path) return tonumber(getXMLString(id, path)) end
getXMLInt = getXMLFloat
hasXMLProperty = function(id, path) return resolve(xmlDocs[id], path) ~= nil end
deleteXMLFile = function(id) xmlDocs[id] = nil end
delete = function() end
