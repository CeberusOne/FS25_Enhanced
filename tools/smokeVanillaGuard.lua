-- Offline check of FS25E_VanillaGuard: while the vanilla settings page reads
-- the engine, or the game saves its settings, every mod value must be gone;
-- afterwards it must be back, and a value the page changed meanwhile must be
-- the new baseline the mod restores to.
local MOD = os.getenv('MOD_DIR') or '.'
dofile(MOD .. '/tools/engineStub.lua')

-- a page-like SettingsModel and a persisting GameSettings, both as the game has them
SettingsModel.__index = SettingsModel
function SettingsModel:refresh() self.seen = getShadowDistanceQuality() end
function SettingsModel:refreshChangedValue() self.seenChanged = getShadowDistanceQuality() end
function SettingsModel:applyChanges() self.seenApply = getShadowDistanceQuality(); if self.pageWrite then setShadowDistanceQuality(self.pageWrite) end end
function SettingsModel:applyCustomSettings() end
function SettingsModel:reset() end
GameSettings = { SETTING = { FOV_Y = 'fovY', FOV_Y_PLAYER_FIRST_PERSON = 'fovY1st', FOV_Y_PLAYER_THIRD_PERSON = 'fovY3rd',
    MAX_NUM_MIRRORS = 'maxNumMirrors', LIGHTS_PROFILE = 'lightsProfile' } }
GameSettings.__index = GameSettings
local savedFov
function GameSettings:save() savedFov = self:getValue('fovY') end
setmetatable(g_gameSettings, GameSettings)
local savedShadow
saveHardwareScalability = function() savedShadow = getShadowDistanceQuality() end
I3DManager = { loadI3DFile = function() end }

for _, f in ipairs({ 'scripts/Core/Localization.lua', 'scripts/Core/Debug.lua', 'scripts/Core/HookManager.lua',
    'scripts/Core/CapabilityRegistry.lua', 'scripts/Core/SettingsCache.lua', 'scripts/Core/CapabilityApplier.lua',
    'scripts/Core/RestoreManager.lua', 'scripts/Core/ModSettings.lua', 'scripts/Core/SettingsSchema.lua',
    'scripts/Core/GameSettingsControls.lua', 'scripts/Core/VisualControls.lua', 'scripts/Core/VisualProfiles.lua',
    'scripts/Core/VanillaGuard.lua' }) do
    local chunk = assert(loadfile(MOD .. '/' .. f)); chunk()
end
FS25E_ModSettings.init()
FS25E_CapabilityRegistry.load(MOD .. '/')
FS25E_VisualControls.build()
FS25E_VisualControls.registerProvider(FS25E_GameSettingsControls)
FS25E_VanillaGuard.install()

local failures = 0
local function check(cond, label) io.write(cond and 'ok   ' or 'FAIL ', label, '\n'); if not cond then failures = failures + 1 end end

-- vanilla: shadow distance 1, fov 60. mod: 2 and 75.
check(getShadowDistanceQuality() == 1, 'vanilla shadow distance = 1')
assert(FS25E_VisualControls.apply('shadow-distance-quality', 2))
assert(FS25E_VisualControls.apply('fovVehicle', 75))
check(getShadowDistanceQuality() == 2 and g_gameSettings:getValue('fovY') == 75, 'mod values in the engine')

local page = setmetatable({}, SettingsModel)
page:refresh()
check(page.seen == 1, 'settings page read the vanilla value (' .. tostring(page.seen) .. ')')
check(getShadowDistanceQuality() == 2, 'mod value back after the page read')

saveHardwareScalability()
check(savedShadow == 1, 'saveHardwareScalability persisted vanilla (' .. tostring(savedShadow) .. ')')
check(getShadowDistanceQuality() == 2, 'mod value back after the save')

g_gameSettings:save()
check(savedFov == 60, 'GameSettings:save persisted vanilla fov (' .. tostring(savedFov) .. ')')
check(g_gameSettings:getValue('fovY') == 75, 'mod fov back after the save')

-- the player changes the vanilla value on the page: new baseline, mod value still on top
page.pageWrite = 0
page:applyChanges()
check(page.seenApply == 1, 'page applied on top of vanilla, not on top of the mod')
check(getShadowDistanceQuality() == 2, 'mod value re-applied after the page apply')
FS25E_VisualControls.restore('shadow-distance-quality')
check(getShadowDistanceQuality() == 0, 'restore lands on the value the player set on the page (' .. tostring(getShadowDistanceQuality()) .. ')')

-- an explicit manual VANILLA comparison is left alone by the guard
FS25E_VisualControls.apply('shadow-distance-quality', 2)
FS25E_VisualProfiles.toggleCompare()
page:refresh()
check(FS25E_VisualProfiles.isComparing(), 'manual comparison stays active through a page read')
FS25E_VisualProfiles.toggleCompare()
check(getShadowDistanceQuality() == 2, 'manual comparison off restores the mod value')

io.write('\nfailures=', failures, '\n')
os.exit(failures == 0 and 0 or 1)
