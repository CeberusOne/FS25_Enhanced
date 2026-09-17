-- Offline check of the paint classification and the paintReflectivity chain
-- against a synthetic scene built from the real GIANTS material templates.
local MOD = os.getenv('MOD_DIR') or '.'

g_dedicatedServer = nil
g_time = 0
ClassIds = { SHAPE = 1 }
Logging = { info = function() end, warning = function(m) io.write('WARN ', tostring(m), '\n') end,
    error = function(m) io.write('ERR ', tostring(m), '\n') end }
Utils = { appendedFunction = function(a, b) return function(...) a(...) return b(...) end end }

-- Materials taken from $data/shared/detailLibrary/materialTemplates.xml.
-- params: clearCoatIntensity, clearCoatSmoothness, porosity, ssrParameters, smoothnessScale
local scene = {
    { name = 'calibratedGlossPaint', diffuse = 'calibratedPaint_diffuse.png', diffuseDir = 'calibrated',
      specular = 'calibratedPaint_specular.png', specularDir = 'calibrated',
      cc = 0.5, cs = 0.85, porosity = 0, expect = true },
    { name = 'calibratedPaint', diffuse = 'calibratedPaint_diffuse.png', diffuseDir = 'calibrated',
      specular = 'calibratedPaint_specular.png', specularDir = 'calibrated',
      cc = 0.1, cs = 0.2, porosity = 0, expect = true },
    { name = 'calibratedMatPaint (clear coat 0, template pair)', diffuse = 'grainSmall_diffuse.png', diffuseDir = 'calibrated',
      specular = 'grainClearSmall_specular.png', specularDir = 'calibrated',
      cc = 0, cs = 0, porosity = 0, expect = true },
    { name = 'powderCoatMatte (porosity 0.1)', diffuse = 'metalPainted_diffuse.png', diffuseDir = 'nonMetallic/metal',
      specular = 'powderCoatMatte_specular.png', specularDir = 'nonMetallic/metal',
      cc = 0, cs = 0, porosity = 0.1, expect = true },
    { name = 'rubberBlack', diffuse = 'rubberBlack_diffuse.png', diffuseDir = 'nonMetallic/rubber',
      specular = 'rubber_specular.png', specularDir = 'nonMetallic/rubber',
      cc = 0, cs = 0, porosity = 0.5, expect = false },
    { name = 'lacquered rubber (clear coat authored)', diffuse = 'rubberBlack_diffuse.png', diffuseDir = 'nonMetallic/rubber',
      specular = 'rubber_specular.png', specularDir = 'nonMetallic/rubber',
      cc = 0.6, cs = 0.8, porosity = 0.1, expect = true },
    { name = 'wood1', diffuse = 'wood1_diffuse.png', diffuseDir = 'nonMetallic/wood',
      specular = 'wood1_specular.png', specularDir = 'nonMetallic/wood',
      cc = 0, cs = 0, porosity = 1.0, expect = false },
    { name = 'fabric1', diffuse = 'fabric1_diffuse.png', diffuseDir = 'nonMetallic/fabric',
      specular = 'fabric1_specular.png', specularDir = 'nonMetallic/fabric',
      cc = 0, cs = 0, porosity = 1.0, expect = false },
    { name = 'glassClear01 (alpha blended)', diffuse = 'clear_diffuse.png', diffuseDir = 'metallic',
      specular = 'glassClear01_specular.png', specularDir = 'metallic/glass',
      cc = 0, cs = 0, porosity = 0, blended = true, expect = false },
    { name = 'glassHeadlight (opaque, variation glass)', diffuse = 'clear_diffuse.png', diffuseDir = 'metallic',
      specular = 'glassHeadlight_specular.png', specularDir = 'metallic/glass',
      cc = 0, cs = 0, porosity = 0, variation = 'glassDoubleSided', expect = false },
    { name = 'reflectorRed (clear coat, but retro-reflective)', diffuse = 'reflector_diffuse.png', diffuseDir = 'nonMetallic/reflector',
      specular = 'reflector_specular.png', specularDir = 'nonMetallic/reflector',
      cc = 0.25, cs = 1.0, porosity = 0, variation = 'reflector', expect = false },
    { name = 'chrome (bare metal)', diffuse = 'clear_diffuse.png', diffuseDir = 'metallic',
      specular = 'clear_specular.png', specularDir = 'metallic',
      cc = 0, cs = 0, porosity = 0, expect = false },
    { name = 'silverScratched', diffuse = 'silverScratched_diffuse.png', diffuseDir = 'metallic',
      specular = 'silverScratched_specular.png', specularDir = 'metallic',
      cc = 0, cs = 0, porosity = 0, expect = false },
}

local params = {}
for i, m in ipairs(scene) do
    m.node = 100 + i
    params[m.node] = {
        clearCoatIntensity = { m.cc, 0, 0, 0 },
        clearCoatSmoothness = { m.cs, 0, 0, 0 },
        porosity = { m.porosity, 0, 0, 0 },
        ssrParameters = { 0.25, 0.1, -0.19, 0 },
        smoothnessScale = { 0.85, 0, 0, 0 },
        scratches_dirt_snow_wetness = { 0, 0, 0, 0 },
    }
    m.material = 1000 + i
end
local byMaterial = {}
for _, m in ipairs(scene) do byMaterial[m.material] = m end

entityExists = function(n) return n == 1 or params[n] ~= nil or byMaterial[n] ~= nil end -- nodes and live materials
getHasClassId = function(n, id) return id == ClassIds.SHAPE and params[n] ~= nil end
getNumOfChildren = function(n) return n == 1 and #scene or 0 end
getChildAt = function(n, i) return scene[i + 1].node end
getNumOfMaterials = function(n) return params[n] and 1 or 0 end
getMaterial = function(n, slot) for _, m in ipairs(scene) do if m.node == n then return m.material end end end
getMaterialCustomShaderFilename = function() return 'data/shaders/vehicleShader.xml' end
getMaterialCustomShaderVariation = function(mat) return byMaterial[mat].variation or 'vmaskUV2' end
getMaterialIsAlphaBlended = function(mat) return byMaterial[mat].blended == true end
getMaterialIsAlphaTested = function() return false end
getMaterialCustomMapFilename = function(mat, which)
    local m = byMaterial[mat]
    local dir = which == 'detailDiffuse' and m.diffuseDir or m.specularDir
    local file = which == 'detailDiffuse' and m.diffuse or m.specular
    return 'data/shared/detailLibrary/' .. dir .. '/' .. file:gsub('%.png$', '.dds')
end
getHasShaderParameter = function(node, name) return params[node] ~= nil and params[node][name] ~= nil end
getShaderParameter = function(node, name)
    local v = params[node][name]; return v[1], v[2], v[3], v[4]
end
setShaderParameter = function(node, name, x, y, z, w, _, _)
    params[node][name] = { x, y, z, w }
end
getRootNode = function() return 1 end
getParent = function(n) return n == 1 and 0 or 1 end
ScreenSpaceReflectionsQuality = { OFF = 0, LOW = 1, HIGH = 2 }
getScreenSpaceReflectionsQuality = function() return 2 end
g_currentMission = { vehicleSystem = { vehicles = { { rootNode = 1, components = { { node = 1 } } } } } }
g_localPlayer = nil

for _, f in ipairs({ 'scripts/Core/Localization.lua', 'scripts/Core/Debug.lua', 'scripts/Core/HookManager.lua',
    'scripts/Core/ModSettings.lua', 'scripts/Materials/MaterialManager.lua' }) do
    local chunk, err = loadfile(MOD .. '/' .. f)
    if not chunk then error(tostring(err)) end
    chunk()
end
FS25E_ModSettings.init()

local M = FS25E_MaterialManager
for _ = 1, 20 do M.refresh(); M.update(1000) end

-- ---- classification ----------------------------------------------------
local byNode = {}
for _, r in ipairs(M.records) do byNode[r.node] = r end
local failures = 0
io.write('classification:\n')
for _, m in ipairs(scene) do
    local r = byNode[m.node]
    local got = r ~= nil and r.paintEligible == true
    local class = r and r.materialClass or 'not-discovered'
    local mark = got == m.expect and 'ok  ' or 'FAIL'
    if got ~= m.expect then failures = failures + 1 end
    io.write(string.format('  %s %-46s eligible=%-5s (%s)\n', mark, m.name, tostring(got), class))
end

-- ---- reflection chain --------------------------------------------------
io.write('\npaintReflectivity 2.0:\n')
local before = {}
for _, m in ipairs(scene) do
    before[m.node] = { cc = params[m.node].clearCoatIntensity[1], ssrY = params[m.node].ssrParameters[2] }
end
local ok, reason = M.setReflectivity(2.0)
io.write('  apply -> ', tostring(ok), ' ', tostring(reason or ''), '\n')
for _, m in ipairs(scene) do
    local p = params[m.node]
    local changed = p.clearCoatIntensity[1] ~= before[m.node].cc or p.ssrParameters[2] ~= before[m.node].ssrY
    if changed ~= (m.expect and (m.cc > 0)) then
        -- A template pair match with clear coat 0 stays visually untouched by
        -- design: nothing to scale, so no change is the correct outcome.
        if not (m.expect and m.cc == 0 and not changed) then
            failures = failures + 1
            io.write('  FAIL unexpected change state for ', m.name, '\n')
        end
    end
    io.write(string.format('  %-46s coat %.3f -> %.3f   ssrBias %.3f -> %.3f\n',
        m.name, before[m.node].cc, p.clearCoatIntensity[1], before[m.node].ssrY, p.ssrParameters[2]))
end

io.write('\nrestore:\n')
local restored = M.restore('paintReflectivity')
io.write('  restore -> ', tostring(restored), '\n')
for _, m in ipairs(scene) do
    local p = params[m.node]
    if math.abs(p.clearCoatIntensity[1] - m.cc) > 1e-6 or math.abs(p.ssrParameters[2] - 0.1) > 1e-6 then
        failures = failures + 1
        io.write('  FAIL not restored: ', m.name, '\n')
    end
end
if failures == 0 then io.write('  all materials back to their authored values\n') end

io.write('\nfailures=', failures, '\n')
os.exit(failures == 0 and 0 or 1)
