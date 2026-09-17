-- Offline integration run: every source file from modDesc.xml is loaded in
-- order against the stub engine, the mission hooks are fired the way the game
-- fires them, a few frames run, the live window is drawn and operated, a
-- quality level is applied and the mission is torn down. Any Lua error on
-- that path is a real load/runtime error.
local MOD = os.getenv('MOD_DIR') or '.'
dofile(MOD .. '/tools/engineStub.lua')

-- --- game classes the bootstrap hooks -----------------------------------
Mission00 = { loadMission00Finished = function() end }
FSBaseMission = { update = function() end, delete = function() end, draw = function() end,
    mouseEvent = function() end, mouseWheelEvent = function() end, keyEvent = function() end }
TypeManager = { finalizeTypes = function() end }
I3DManager = { loadI3DFile = function() end }
SettingsModel.__index = SettingsModel
SettingsModel.refresh = function() end
GameSettings = GameSettings or {}
GameSettings.save = function() end
setmetatable(g_gameSettings, { __index = GameSettings })
g_currentModName = 'FS25_Enhanced'
g_currentModDirectory = MOD .. '/'
g_currentMission = { environment = { lighting = { sunLightId = 0, update = function() end } },
    vehicleSystem = { vehicles = {} }, addIngameNotification = function() end }
g_gui = { getIsGuiVisible = function() return false end }
g_inputBinding = { registerActionEvent = function() return true, 1 end, removeActionEventsByTarget = function() end,
    setActionEventTextVisibility = function() end, setContext = function() end, revertContext = function() end,
    getShowMouseCursor = function() return false end, setShowMouseCursor = function() end }
InputAction = { FS25E_OPEN_SETTINGS = 'a', FS25E_TOGGLE_LIVE_OVERLAY = 'b', FS25E_LIVE_HINT = 'c', FS25E_TOGGLE_COMPARE = 'd',
    MENU_AXIS_UP_DOWN = 'e', MENU_AXIS_LEFT_RIGHT = 'f', MENU_PAGE_PREV = 'g', MENU_PAGE_NEXT = 'h', MENU_BACK = 'i', MENU_ACCEPT = 'j' }
Input = { KEY_f9 = 290, KEY_e = 101, KEY_esc = 27, KEY_return = 13, KEY_backspace = 8, KEY_lshift = 304, KEY_rshift = 303,
    KEY_lctrl = 306, KEY_rctrl = 305, KEY_lalt = 308, KEY_ralt = 307, isKeyPressed = function() return false end,
    isMouseButtonPressed = function() return false end }
RenderText = { ALIGN_LEFT = 0, VERTICAL_ALIGN_TOP = 1, VERTICAL_ALIGN_BASELINE = 0, DEFAULT_LINE_HEIGHT_SCALE = 1 }
local drawCalls = 0
drawFilledRect = function() drawCalls = drawCalls + 1 end
renderText = function() drawCalls = drawCalls + 1 end
getTextWidth = function(size, text) return size * 0.5 * #tostring(text) end
setTextBold = function() end; setTextAlignment = function() end; setTextColor = function() end
setTextVerticalAlignment = function() end; setTextWrapWidth = function() end; setTextFirstLineIndentation = function() end
setTextLineHeightScale = function() end; setTextClipArea = function() end
g_screenWidth, g_screenHeight = 1920, 1080
getUserProfileAppPath = function() return MOD .. '/tools/' end
createFolder = function() end
fileExists = function(p) local f = io.open(p, 'r'); if f then f:close(); return true end; return false end
addConsoleCommand = function() return true end
entityExists = function() return false end
getRootNode = function() return 0 end
ClassIds = { SHAPE = 1, LIGHT_SOURCE = 2 }

-- --- load everything in modDesc order ---------------------------------
local modDesc = assert(io.open(MOD .. '/modDesc.xml', 'r')):read('*a')
local loaded = 0
for file in modDesc:gmatch('<sourceFile filename="([^"]+)"') do
    local chunk, err = loadfile(MOD .. '/' .. file)
    if not chunk then error('load ' .. file .. ': ' .. tostring(err)) end
    local ok, runErr = pcall(chunk)
    if not ok then error('run ' .. file .. ': ' .. tostring(runErr)) end
    loaded = loaded + 1
end
io.write('loaded ', loaded, ' source files\n')

local failures = 0
local function check(cond, label) io.write(cond and 'ok   ' or 'FAIL ', label, '\n'); if not cond then failures = failures + 1 end end

-- The bootstrap warns through FS25E_Debug on pcall failures; capture them.
local warnings = {}
local origWarning = FS25E_Debug.warning
FS25E_Debug.warning = function(sub, msg) warnings[#warnings + 1] = tostring(sub) .. ': ' .. tostring(msg); origWarning(sub, msg) end

-- --- mission lifecycle -------------------------------------------------
Mission00.loadMission00Finished(g_currentMission)
check(FS25_Enhanced.initialized == true, 'loadMap completed (initialized flag)')
check(#FS25E_VisualControls.getControls() > 100, 'controls registered: ' .. #FS25E_VisualControls.getControls())
for i = 1, 30 do FSBaseMission.update(g_currentMission, 16) end
check(true, '30 update frames without error')

-- live window: open, draw, navigate, drag, resize, close
check(FS25E_LiveOverlay.show(), 'live window opens')
FSBaseMission.draw(g_currentMission)
check(drawCalls > 50, 'live window drew ' .. drawCalls .. ' primitives')
for i = 1, 14 do FS25E_LiveOverlay.selectCategory(({ 'presets', 'shadows', 'lighting', 'atmosphere', 'image', 'environment',
    'weather', 'water', 'reflections', 'materials', 'foliage', 'lod', 'camera', 'performance' })[i]); FSBaseMission.draw(g_currentMission) end
check(true, 'all 14 categories drawn')
local P = FS25E_LiveOverlay.getLayout()
local x0, y0 = P.x, P.y
-- press on the title strip, move, release
FSBaseMission.mouseEvent(g_currentMission, (P.x + 300) / 1920, 1 - (P.y + 40) / 1080, true, false, 1)
FSBaseMission.mouseEvent(g_currentMission, (P.x + 200) / 1920, 1 - (P.y + 140) / 1080, false, false, 1)
FSBaseMission.mouseEvent(g_currentMission, (P.x + 200) / 1920, 1 - (P.y + 140) / 1080, false, true, 1)
check(P.x == x0 - 100 and P.y == math.min(y0 + 100, 1080 - P.h), string.format('window dragged to %d,%d (clamped to the screen)', P.x, P.y))
local w0, h0 = P.w, P.h
FSBaseMission.draw(g_currentMission) -- hit boxes are rebuilt each frame
FSBaseMission.mouseEvent(g_currentMission, (P.x + P.w - 8) / 1920, 1 - (P.y + P.h - 8) / 1080, true, false, 1)
FSBaseMission.mouseEvent(g_currentMission, (P.x + P.w - 108) / 1920, 1 - (P.y + P.h - 208) / 1080, false, false, 1)
FSBaseMission.mouseEvent(g_currentMission, (P.x + P.w - 108) / 1920, 1 - (P.y + P.h - 208) / 1080, false, true, 1)
check(P.w == w0 - 100 and P.h == h0 - 200, string.format('window resized to %dx%d', P.w, P.h))
FS25E_LiveOverlay.resetLayout()
check(P.w == w0 and P.h == h0, 'layout reset')
FSBaseMission.keyEvent(g_currentMission, 0, 27, 0, true)
check(not FS25E_LiveOverlay.isVisible(), 'Esc closes the live window')
FSBaseMission.keyEvent(g_currentMission, 0, 290, 0, true)
check(FS25E_LiveOverlay.isVisible(), 'F9 opens the live window')
FS25E_LiveOverlay.hide()

-- quality level ultra, compare toggle, level off
local okUltra = FS25E_VisualControls.apply('enhancedLevel', 5)
check(okUltra, 'quality level Ultra applied')
check(FS25E_VisualControls.read(FS25E_VisualControls.get('max-num-shadow-lights')) == 16, 'ultra: shadow lights at 16')
local okCmp = FS25E_VisualProfiles.toggleCompare()
check(okCmp and FS25E_VisualProfiles.isComparing(), 'VANILLA comparison on')
check(FS25E_VisualControls.read(FS25E_VisualControls.get('max-num-shadow-lights')) == 5, 'vanilla: shadow lights back at 5')
FS25E_VisualProfiles.toggleCompare()
check(FS25E_VisualControls.read(FS25E_VisualControls.get('max-num-shadow-lights')) == 16, 'MOD again: 16')
local page = setmetatable({}, SettingsModel); page:refresh()
check(FS25E_VisualControls.read(FS25E_VisualControls.get('max-num-shadow-lights')) == 16, 'vanilla guard re-applied after page refresh')
check(FS25E_VisualControls.apply('enhancedLevel', 0), 'quality level Off restores')
check(FS25E_VisualControls.read(FS25E_VisualControls.get('max-num-shadow-lights')) == 5, 'shadow lights restored to 5')
check(FS25E_VisualControls.apply('uiLanguage', 2) and FS25E_Localization.language == 'de', 'language pinned to de')
check(FS25E_Localization.t('FS25E_menu_water') == 'Wasser', 'German text active: ' .. FS25E_Localization.t('FS25E_menu_water'))
check(FS25E_VisualControls.apply('uiLanguage', 3) and FS25E_Localization.t('FS25E_menu_water') == 'Water', 'English text active')
FS25E_VisualControls.apply('uiLanguage', 1)

-- teardown
FSBaseMission.delete(g_currentMission)
check(FS25_Enhanced.initialized == false, 'deleteMap completed')
check(FS25E_VisualControls.read(FS25E_VisualControls.get('max-num-shadow-lights')) == 5, 'engine value vanilla after teardown')

local unexpected = {}
for _, w in ipairs(warnings) do
    if not w:find('unavailable at register time') and not w:find('NO%-OP') and not w:find('TypeManager') and not w:find('message center') then unexpected[#unexpected + 1] = w end
end
check(#unexpected == 0, 'no unexpected warnings')
for _, w in ipairs(unexpected) do io.write('   warning: ', w, '\n') end
io.write('\nfailures=', failures, '\n')
os.exit(failures == 0 and 0 or 1)
