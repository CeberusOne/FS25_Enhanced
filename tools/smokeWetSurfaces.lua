-- Offline check of FS25E_WetSurfaceManager: global wetness scaling with the
-- drying hold, the world material scan (placeables, buildings, water, trees as
-- split shapes, crop block shapes; vehicles untouched), the vegetation and
-- weathering controls, multi-component writes and full restoration.
local MOD = os.getenv('MOD_DIR') or '.'
dofile(MOD .. '/tools/engineStub.lua')
ClassIds.MESH_SPLIT_SHAPE = 18

-- engine wetness written by the "weather" each frame
local engineWetness = 0.0
setWetness = function(w) engineWetness = w end
getWetness = function() return engineWetness end

-- scene: root(1) -> building(10) placeable(11) road(12) water(13) tree(14, split shape)
--        crop(15) road2(16) road3(17, shares 12's material) billboard(18) rock(19)
--        stale(22, material that is no entity) vehicleRoot(20)->part(21)
local shaders = {
    [10] = 'data/shaders/buildingShader.xml', [11] = 'data/shaders/placeableShader.xml',
    [12] = 'data/shaders/placeableShader.xml', [13] = 'data/shaders/oceanShader.xml',
    [14] = 'data/shaders/treeBranchShader.xml', [21] = 'data/shaders/vehicleShader.xml',
    [15] = 'data/shaders/fruitGrowthFoliageShader.xml', [16] = 'data/shaders/vertexPaintShader.xml',
    [18] = 'data/shaders/treeBillboardShader.xml', [19] = 'data/shaders/placeableShader.xml',
}
local children = { [1] = { 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 22, 20 }, [20] = { 21 } }
local params = {
    [10] = { wetnessScale = 1.0, dirtMossMix = { 1.0, 0.8 } },
    [11] = { wetnessScale = 1.0, wetShininess = 0.2 },
    [12] = { wetnessScale = 1.0, wetShininess = 0.2 },
    [13] = { ssrRoughness = 0.0 },
    [14] = { snowScale = 1.0, aoIntensity = 1.0, backfaceDiffuseScale = { 0.35, 0.0 }, windSnowLeafScale = { 1.0, 1.0, 1.0, 0.0 },
             seasonalTintIntensity = { 0.1, 0.1, 0.2 } },
    [15] = { aoIntensity = 2.0, translucencyAmount = 0.0, windScale = 1.0 },
    [16] = { wetnessScale = 1.0, wetShininess = 0.2, contrastLuminiosity = { 1.0, 0.0 } },
    [18] = { windSnowLeafScale = { 1.0, 1.0, 1.0, 0.0 }, seasonalTintIntensity = { 0.3, 0.3, 0.4 } },
    [19] = { mossLevel = 1.0 },
    [21] = { wetShininess = 0.2 },
    [22] = { wetnessScale = 1.0 },
}
params[17] = params[12] -- second road piece sharing the road material (one record, one shared write)
local splitShapes = { [14] = true }
local materialOf = function(n) if n == 17 then return 1012 end; if n == 22 then return 49367 end; return 1000 + n end
entityExists = function(n)
    if n == 1 or n == 20 or params[n] ~= nil then return true end
    return n >= 1000 and n < 1100 -- live materials; 49367 is the stale id from the log
end
getHasClassId = function(n, id)
    if id == ClassIds.MESH_SPLIT_SHAPE then return splitShapes[n] == true end
    return id == ClassIds.SHAPE and params[n] ~= nil and not splitShapes[n]
end
getNumOfChildren = function(n) return children[n] and #children[n] or 0 end
getChildAt = function(n, i) return children[n][i + 1] end
getNumOfMaterials = function(n) return params[n] and 1 or 0 end
getMaterial = function(n) return materialOf(n) end
local shaderCalls = 0
getMaterialCustomShaderFilename = function(mat)
    shaderCalls = shaderCalls + 1
    if not entityExists(mat) then error('Unknown entity id ' .. tostring(mat)) end
    return shaders[mat - 1000]
end
getHasShaderParameter = function(node, name) return params[node] ~= nil and params[node][name] ~= nil end
local function vec(v) if type(v) == 'table' then return v[1], v[2], v[3], v[4] end; return v, 0, 0, 0 end
getShaderParameter = function(node, name) return vec(params[node][name]) end
setShaderParameter = function(node, name, x, y, z, w)
    local p = params[node][name]
    if type(p) == 'table' then
        if x ~= nil then p[1] = x end; if y ~= nil then p[2] = y end; if z ~= nil then p[3] = z end; if w ~= nil then p[4] = w end
    elseif x ~= nil then params[node][name] = x end
end
getRootNode = function() return 1 end
g_currentMission = { vehicleSystem = { vehicles = { { rootNode = 20 } } } }

for _, f in ipairs({ 'scripts/Core/Localization.lua', 'scripts/Core/Debug.lua', 'scripts/Core/ModSettings.lua',
    'scripts/Water/WetSurfaceManager.lua' }) do
    local chunk = assert(loadfile(MOD .. '/' .. f)); chunk()
end
FS25E_ModSettings.init()
local M = FS25E_WetSurfaceManager
M.install(); M.init()
for _ = 1, 10 do M.update(16) end

local failures = 0
local function check(cond, label) io.write(cond and 'ok   ' or 'FAIL ', label, '\n'); if not cond then failures = failures + 1 end end
local function near(a, b) return math.abs(a - b) < 1e-6 end

local d = M.getDiagnostics()
check(d.placeableMaterials == 3 and d.buildingMaterials == 1 and d.waterMaterials == 1, string.format('scan found placeable=%d building=%d water=%d', d.placeableMaterials, d.buildingMaterials, d.waterMaterials))
check(d.treeMaterials == 1 and d.treeBillboardMaterials == 1 and d.cropMaterials == 1 and d.paintedSurfaces == 1, 'split-shape tree, billboard, crop and painted surface found')
check(d.splitShapes == 1, 'split shape counted (' .. tostring(d.splitShapes) .. ')')
check(d.materials == 9, 'vehicle material ignored, shared road material counted once (' .. d.materials .. ' records)')
check(d.badMaterials == 1, 'stale material id counted once, never asked again (' .. tostring(d.badMaterials) .. ')')
local callsAfterScan = shaderCalls
M.elapsed = 20000; M.update(16); for _ = 1, 10 do M.update(16) end
check(shaderCalls == callsAfterScan, 'rescan re-inspects nothing already classified (' .. (shaderCalls - callsAfterScan) .. ' extra shader lookups)')

-- wet look on world surfaces
assert(M.write('wetSurfaceShininess', 3.0)); M.update(16)
check(near(params[11].wetShininess, 0.6) and near(params[12].wetShininess, 0.6), 'wetShininess scaled 0.2 -> 0.6 on placeables')
check(params[21].wetShininess == 0.2 and params[14].snowScale == 1.0, 'vehicle part and tree untouched by wetness')
check(near(params[16].wetShininess, 0.6), 'vertex-paint road takes the wet reflection too')
-- vegetation
assert(M.write('canopyOcclusion', 1.5)); M.update(16)
check(near(params[14].aoIntensity, 1.5) and params[15].aoIntensity == 2.0, 'canopy AO scaled on the tree only')
assert(M.write('leafBacklight', 2.0)); M.update(16)
check(near(params[14].backfaceDiffuseScale[1], 0.7) and params[14].backfaceDiffuseScale[2] == 0.0, 'leaf backlight 0.35 -> 0.7, floor untouched')
assert(M.write('leafBacklightBase', 0.25)); M.update(16)
check(near(params[14].backfaceDiffuseScale[2], 0.25) and near(params[14].backfaceDiffuseScale[1], 0.7), 'backlight floor set to 0.25, scale kept')
assert(M.write('treeWind', 0.0)); M.update(16)
check(params[14].windSnowLeafScale[1] == 0 and params[18].windSnowLeafScale[1] == 0 and params[14].windSnowLeafScale[3] == 1.0, 'tree wind 0 on crown and billboard, leaves/snow components kept')
assert(M.write('treeTintVariation', 3.0)); M.update(16)
local t = params[14].seasonalTintIntensity
check(near(t[1], 0.3) and near(t[2], 0.3) and near(t[3], 0.6), 'tint variation scales all three seasons (0.1 0.1 0.2 -> 0.3 0.3 0.6)')
local b = params[18].seasonalTintIntensity
check(near(b[1], 0.9) and near(b[2], 0.9) and near(b[3], 1.0), 'billboard tint scaled and clamped to the shader ceiling 1.0')
assert(M.write('cropWind', 2.5)); M.update(16)
check(near(params[15].windScale, 2.5), 'crop wind 1 -> 2.5')
assert(M.write('cropTranslucency', 0.4)); M.update(16)
check(near(params[15].translucencyAmount, 0.4), 'crop translucency set absolutely')
-- weathering / depth
assert(M.write('buildingMoss', 0.5)); M.update(16)
check(near(params[10].dirtMossMix[1], 0.5) and near(params[10].dirtMossMix[2], 0.8), 'building moss halved, dirt kept')
assert(M.write('buildingDirt', 2.0)); M.update(16)
check(near(params[10].dirtMossMix[2], 1.0) and near(params[10].dirtMossMix[1], 0.5), 'building dirt 0.8 -> clamped 1.0, moss kept')
assert(M.write('rockMoss', 0.0)); M.update(16)
check(params[19].mossLevel == 0 and params[11].wetnessScale == 1.0, 'rock moss off on the rock material only')
assert(M.write('surfaceLuminosity', 0.2)); M.update(16)
check(near(params[16].contrastLuminiosity[2], 0.2) and params[16].contrastLuminiosity[1] == 1.0, 'luminosity written to component y, contrast x kept')
assert(M.write('surfaceContrast', 1.5)); M.update(16)
check(near(params[16].contrastLuminiosity[1], 1.5) and near(params[16].contrastLuminiosity[2], 0.2), 'contrast scaled on x, luminosity y kept')
assert(M.write('wetSurfaceIntensity', 2.0)); M.update(16)
check(params[10].wetnessScale == 2.0 and params[11].wetnessScale == 2.0, 'wetnessScale scaled on building + placeable')
assert(M.write('waterReflectionRoughness', 0.3)); M.update(16)
check(near(params[13].ssrRoughness, 0.3), 'ocean ssrRoughness set absolutely')

-- global wetness: weather writes 0.5 through the (hooked) Lua setter
assert(M.write('groundWetnessScale', 1.6))
setWetness(0.5)
check(near(engineWetness, 0.8), 'hooked setWetness scaled 0.5 -> 0.8')
M.update(16)
check(near(getWetness(), 0.8), 'per-frame reconcile keeps 0.8')
-- native write bypassing the hook (simulate C++ side): value read back is fresh
engineWetness = 0.25; M.update(16)
check(near(getWetness(), 0.4), 'native 0.25 re-scaled to 0.4')

-- drying hold: 10 minutes from 1 to 0
assert(M.write('groundWetnessHold', 10)); engineWetness = 1.0; M.update(16)
check(near(getWetness(), 1.0), 'held starts at 1.0')
engineWetness = 0.0; M.update(60000)          -- one minute of drying
check(math.abs(getWetness() - 0.9) < 1e-3, string.format('after 1 min still %.3f (hold)', getWetness()))
engineWetness = 0.0; M.update(9 * 60000 + 1000)
check(getWetness() < 1e-6, 'fully dry after the hold time')

-- restore
check(M.restore(), 'restore ok')
check(params[11].wetShininess == 0.2 and params[10].wetnessScale == 1.0 and params[13].ssrRoughness == 0.0, 'materials back to authored values')
check(params[14].aoIntensity == 1.0 and params[14].backfaceDiffuseScale[1] == 0.35 and params[14].backfaceDiffuseScale[2] == 0.0
    and params[15].translucencyAmount == 0.0 and params[15].windScale == 1.0 and params[14].windSnowLeafScale[1] == 1.0
    and params[16].contrastLuminiosity[1] == 1.0 and params[16].contrastLuminiosity[2] == 0.0, 'vegetation and surface parameters back to authored values')
t = params[14].seasonalTintIntensity; b = params[18].seasonalTintIntensity
check(near(t[1], 0.1) and near(t[3], 0.2) and near(b[1], 0.3) and near(b[3], 0.4), 'tint variation restored on crown and billboard')
check(params[10].dirtMossMix[1] == 1.0 and params[10].dirtMossMix[2] == 0.8 and params[19].mossLevel == 1.0, 'weathering restored')
engineWetness = 0.33; setWetness(0.33); M.update(16)
check(near(getWetness(), 0.33), 'wetness passes through untouched after restore')
check(M.reset(), 'reset ok')

io.write('\nfailures=', failures, '\n')
os.exit(failures == 0 and 0 or 1)
