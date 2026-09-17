-- Offline check of the round-6 behaviour:
--  * FS25E_FoliageManager works on foot (player footprint), follows the
--    player into a vehicle, covers helpers at detail 2, scales with the
--    radius, and destroys everything it created;
--  * FS25E_EnvironmentLighting god rays are a factor on the sun's own
--    scattering intensity: never off, never 0, re-based when the game moves
--    the value, restored to the game's value.
local MOD = os.getenv('MOD_DIR') or '.'
dofile(MOD .. '/tools/engineStub.lua')
ClassIds.LIGHT_SOURCE = 14

local failures = 0
local function check(cond, label) io.write(cond and 'ok   ' or 'FAIL ', label, '\n'); if not cond then failures = failures + 1 end end
local function near(a, b) return type(a) == 'number' and math.abs(a - b) < 1e-6 end

-- ---------------------------------------------------------------- foliage --
local positions = { [500] = { 0, 0, 0 }, [600] = { 10, 0, 0 }, [601] = { 12, 0, 0 }, [700] = { 40, 0, 0 }, [800] = { 300, 0, 0 }, [900] = { 5, 0, 0 } }
entityExists = function(n) return positions[n] ~= nil or n == 1 end
getCamera = function() return 900 end
getWorldTranslation = function(n) local p = positions[n]; return p[1], p[2], p[3] end
local rectangles, nextId = {}, 1
local bending = {
    createRectangle = function(self, minX, maxX, minZ, maxZ, yOffset, node)
        local id = nextId; nextId = nextId + 1
        rectangles[id] = { minX = minX, maxX = maxX, minZ = minZ, maxZ = maxZ, yOffset = yOffset, node = node }
        return id
    end,
    destroyObject = function(self, id) rectangles[id] = nil; return true end,
}
local function vehicle(root, active, parent)
    local v = { rootNode = root, spec_foliageBending = { bendingNodes = {
        { id = active and 1 or nil, node = root, minX = -1.5, maxX = 1.5, minZ = -2, maxZ = 2, yOffset = 0.5 } } } }
    v.getRootVehicle = function(self) return parent or self end
    return v
end
local tractor = vehicle(600, true)
local plough = vehicle(601, true, tractor)
local helper = vehicle(700, true)
local parked = vehicle(800, false)
g_currentMission = { environment = {}, foliageBendingSystem = bending,
    vehicleSystem = { vehicles = { tractor, plough, helper, parked } } }
g_localPlayer = { graphicsComponent = { foliageBendingNode = 500 }, getCurrentVehicle = function() return nil end }

for _, f in ipairs({ 'scripts/Core/Localization.lua', 'scripts/Core/Debug.lua', 'scripts/Core/ModSettings.lua',
    'scripts/World/FoliageManager.lua' }) do local chunk = assert(loadfile(MOD .. '/' .. f)); chunk() end
FS25E_ModSettings.init()
local F = FS25E_FoliageManager
local function count() local n = 0; for _ in pairs(rectangles) do n = n + 1 end; return n end

check(F.available(), 'foliage bending available on foot (no vehicle needed)')
assert(F.write('foliageInteractionDetail', 1))
check(count() == 1 and F.getDiagnostics().playerZones == 1, 'detail 1 on foot: one player footprint zone')
assert(F.write('foliageInteractionRadius', 1.5))
local r; for _, rect in pairs(rectangles) do r = rect end
check(r and near(r.maxX, 0.75) and near(r.minZ, -0.75) and r.node == 500, 'player zone scaled 1 m -> 1.5 m around the player node')

-- enter the tractor: player zone gone, tractor + attached plough covered
g_localPlayer.getCurrentVehicle = function() return tractor end
F.update(600)
local d = F.getDiagnostics()
check(count() == 2 and d.vehicleZones == 2 and d.playerZones == 0, 'in the tractor: tractor and plough zones, no player zone (' .. count() .. ')')
-- detail 2: helpers too, the parked (inactive) vehicle never
assert(F.write('foliageInteractionDetail', 2))
check(count() == 3, 'detail 2 adds the active helper, skips the inactive vehicle (' .. count() .. ')')
assert(F.write('foliageMaximumZones', 2))
check(count() == 2, 'zone limit keeps the nearest footprints (' .. count() .. ')')
local nodes = {}; for _, rect in pairs(rectangles) do nodes[rect.node] = true end
check(nodes[600] and nodes[601] and not nodes[700], 'own vehicle before the helper')
-- back on foot
g_localPlayer.getCurrentVehicle = function() return nil end
F.update(600)
d = F.getDiagnostics()
check(d.playerZones == 1 and d.vehicleZones == 1, 'on foot again: player zone back, nearest helper kept')
check(F.restore() and count() == 0, 'restore destroys every created rectangle')

-- ------------------------------------------------------------- god rays --
positions[42] = { 0, 100, 0 }
getHasClassId = function(n, id) return id == ClassIds.LIGHT_SOURCE and n == 42 end
local scattering, useScattering = 1.0, true
getLightScatteringIntensity = function(n) return scattering end
setLightScatteringIntensity = function(n, v) scattering = v end
getLightUseLightScattering = function(n) return useScattering end
setLightUseLightScattering = function(n, v) useScattering = v end
g_currentMission.environment.lighting = { sunLightId = 42 }
for _, f in ipairs({ 'scripts/Lighting/LightDiscovery.lua', 'scripts/Lighting/GlobalLighting.lua', 'scripts/Lighting/EnvironmentLighting.lua' }) do
    local chunk = assert(loadfile(MOD .. '/' .. f)); chunk()
end
local E = FS25E_EnvironmentLighting
local hasSwitch = false
for _, c in ipairs(E.getControls()) do if c.id == 'environmentScatteringIntensity' or (c.id == 'environmentGodRays' and c.kind == 'bool') then hasSwitch = true end end
check(not hasSwitch, 'no scattering on/off switch and no absolute duplicate any more')
check(E.available('environmentGodRays'), 'god rays available with the sun light')
assert(E.write('environmentGodRays', 3.0))
check(near(scattering, 3.0) and useScattering == true, 'factor 3 -> intensity 3.0, scattering stays on')
-- the game's Lighting moves its own value: the factor follows the new base
scattering = 0.5
E.applyRequested()
check(near(scattering, 1.5), 'game value 0.5 re-based -> 1.5')
assert(E.write('environmentGodRays', 0.1))
check(near(scattering, 0.1), 'factor 0.1 on base 0.5 is floored at 0.1, never 0')
E.applyRequested()
check(near(scattering, 0.1) and useScattering == true, 'stays floored and on across updates')
check(E.restore('environmentGodRays') and near(scattering, 0.5), 'restore hands the game\'s own 0.5 back')

-- sun shadow map size: index control, raw resolution kept for an exact restore
local shadowRes = 1536
getLightCastingShadowMap = function(n) return true, shadowRes end
setLightShadowMap = function(n, cast, res) if cast then shadowRes = res end end
local control; for _, c in ipairs(E.getControls()) do if c.id == 'environmentShadowResolution' then control = c end end
check(control and control.kind == 'enum' and control.read() == 1 and control.format(1) == '2048 px', 'sun shadow size reads the nearest step (1536 -> 2048 px)')
assert(E.write('environmentShadowResolution', 3))
check(shadowRes == 8192 and control.read() == 3, 'index 3 writes 8192 px to the sun light')
check(E.restore('environmentShadowResolution') and shadowRes == 1536, 'restore puts the exact game size 1536 back')

io.write('\nfailures=', failures, '\n')
os.exit(failures == 0 and 0 or 1)
