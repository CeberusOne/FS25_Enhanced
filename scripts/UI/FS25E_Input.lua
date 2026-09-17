-- FS25_Enhanced / UI/FS25E_Input.lua
-- ActionEvents + F9/Ctrl+E keyEvent fallback (ActionEvents alone often silent for SYSTEM).

FS25E_Input = {}

local registered = false
local keyHooked = false
local eventIds = {}
local lastOpenMs = -1000
local lastLiveMs = -1000
local lastCompareMs = -1000
local OPEN_COOLDOWN_MS = 400

local function dbg(msg)
    if FS25E_Debug ~= nil then
        FS25E_Debug.info("Input", tostring(msg))
    end
end

local function notify(text)
    dbg(text)
    if g_currentMission ~= nil and g_currentMission.addIngameNotification ~= nil then
        pcall(function()
            g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_INFO, text)
        end)
    elseif InfoDialog ~= nil and InfoDialog.show ~= nil then
        pcall(function()
            InfoDialog.show(text)
        end)
    end
end

local function t(key, fallback)
    if FS25E_Localization ~= nil and FS25E_Localization.t ~= nil then
        return FS25E_Localization.t(key, fallback)
    end
    if g_i18n ~= nil and g_i18n.getText ~= nil then
        local ok, text = pcall(function()
            return g_i18n:getText(key)
        end)
        if ok and text ~= nil and text ~= "" and text ~= key then
            return text
        end
    end
    return fallback or key
end

local function nowMs()
    if g_time ~= nil then
        return g_time
    end
    if getTime ~= nil then
        local ok, v = pcall(getTime)
        if ok and type(v) == "number" then
            if v < 1e6 then
                return v * 1000.0
            end
            return v
        end
    end
    return 0
end

-- The separate settings dialog and the page in the game's menu are gone; the
-- live window is the only interface. These keep the older call sites valid.
local function isSettingsDialogVisible() return false end
FS25E_Input.isSettingsDialogVisible = isSettingsDialogVisible

--- F9 / Action: toggle the live window.
local function openSettings(source)
    local tnow = nowMs()
    if tnow >= lastOpenMs and (tnow - lastOpenMs) < OPEN_COOLDOWN_MS then
        return
    end
    lastOpenMs = tnow
    dbg("openSettings via " .. tostring(source) .. " -> live window")
    if FS25E_LiveOverlay ~= nil and FS25E_LiveOverlay.toggle ~= nil then
        FS25E_LiveOverlay.toggle(nil)
        return
    end
    notify(t("FS25E_LIVE_OVERLAY_UNAVAILABLE", "Live Overlay unavailable"))
end

function FS25E_Input.onOpenSettings(actionName, inputValue, callbackState, isAnalog)
    dbg(string.format("onOpenSettings action=%s value=%s", tostring(actionName), tostring(inputValue)))
    if inputValue ~= nil and tonumber(inputValue) == 0 then
        return
    end
    openSettings("ActionEvent:" .. tostring(actionName))
end

function FS25E_Input.onToggleLiveOverlay(actionName, inputValue, callbackState, isAnalog)
    if inputValue ~= nil and tonumber(inputValue) == 0 then
        return
    end
    local now = nowMs()
    if now >= lastLiveMs and now - lastLiveMs < OPEN_COOLDOWN_MS then return end
    lastLiveMs = now
    dbg(string.format("onToggleLiveOverlay action=%s value=%s", tostring(actionName), tostring(inputValue)))
    if FS25E_LiveOverlay ~= nil and FS25E_LiveOverlay.toggle ~= nil then
        FS25E_LiveOverlay.toggle(nil)
        return
    end
    notify(t("FS25E_LIVE_OVERLAY_UNAVAILABLE", "Live Overlay unavailable"))
end

function FS25E_Input.onLiveHint(actionName, inputValue, callbackState, isAnalog)
    FS25E_Input.onToggleLiveOverlay(actionName, inputValue, callbackState, isAnalog)
end

--- One key for a direct modded/vanilla comparison: every value the mod holds
--- is restored, a second press applies all of them again.
function FS25E_Input.onToggleCompare(actionName, inputValue, callbackState, isAnalog)
    if inputValue ~= nil and tonumber(inputValue) == 0 then
        return
    end
    local now = nowMs()
    if now >= lastCompareMs and now - lastCompareMs < OPEN_COOLDOWN_MS then return end
    lastCompareMs = now
    if FS25E_VisualProfiles == nil or FS25E_VisualProfiles.toggleCompare == nil then
        notify(t("FS25E_status_information_unavailable", "unavailable"))
        return
    end
    local ok, status = FS25E_VisualProfiles.toggleCompare()
    local comparing = FS25E_VisualProfiles.isComparing()
    dbg(string.format("toggleCompare ok=%s comparing=%s status=%s", tostring(ok), tostring(comparing), tostring(status)))
    notify(t(comparing and "FS25E_compare_vanilla_notice" or "FS25E_compare_mod_notice",
        comparing and "FS25 Enhanced: VANILLA" or "FS25 Enhanced: MOD"))
end

local function resolveAction(name)
    if InputAction ~= nil and InputAction[name] ~= nil then
        return InputAction[name]
    end
    return name
end

local function tryRegisterOne(actionName, callback)
    local action = resolveAction(actionName)
    local ok2, err2 = pcall(function()
        -- Prefer NO context modification for SYSTEM category actions.
        -- PlayerActionEvents context often registers but never fires for SYSTEM binds.
        local okFlag, eid = g_inputBinding:registerActionEvent(action, FS25E_Input,
            function(_, ...) return callback(...) end, false, true, false, true)
        if type(okFlag) ~= "boolean" then
            eid = okFlag
            okFlag = eid ~= nil
        end
        if eid ~= nil then
            eventIds[#eventIds + 1] = eid
            if g_inputBinding.setActionEventTextVisibility ~= nil then
                pcall(function()
                    g_inputBinding:setActionEventTextVisibility(eid, false)
                end)
            end
            if g_inputBinding.setActionEventActive ~= nil then
                pcall(function()
                    g_inputBinding:setActionEventActive(eid, true)
                end)
            end
            dbg(string.format("registered %s eid=%s", tostring(actionName), tostring(eid)))
        else
            dbg(string.format("registered %s but eid=nil okFlag=%s", tostring(actionName), tostring(okFlag)))
        end
    end)
    if not ok2 then
        dbg("register failed " .. tostring(actionName) .. ": " .. tostring(err2))
        return false
    end
    return true
end

--- Direct key fallback: F9 opens settings; Shift+F9 toggles overlay.
function FS25E_Input.onKeyEvent(_self, unicode, sym, modifier, isDown)
    if isDown ~= true then
        return
    end
    local keyF9 = (Input ~= nil and Input.KEY_f9) or nil
    local keyE = (Input ~= nil and Input.KEY_e) or nil
    local isF9 = (keyF9 ~= nil and sym == keyF9) or (keyF9 == nil and (sym == 290 or sym == 120))
    local isE = (keyE ~= nil and sym == keyE)

    local shift = false
    local ctrl = false
    local alt = false
    if Input ~= nil then
        if Input.isKeyPressed ~= nil then
            if Input.KEY_lalt ~= nil then
                alt = alt or Input.isKeyPressed(Input.KEY_lalt)
            end
            if Input.KEY_ralt ~= nil then
                alt = alt or Input.isKeyPressed(Input.KEY_ralt)
            end
            if Input.KEY_lshift ~= nil then
                shift = shift or Input.isKeyPressed(Input.KEY_lshift)
            end
            if Input.KEY_rshift ~= nil then
                shift = shift or Input.isKeyPressed(Input.KEY_rshift)
            end
            if Input.KEY_lctrl ~= nil then
                ctrl = ctrl or Input.isKeyPressed(Input.KEY_lctrl)
            end
            if Input.KEY_rctrl ~= nil then
                ctrl = ctrl or Input.isKeyPressed(Input.KEY_rctrl)
            end
        end
    end
    -- modifier bitfield fallback (Giants often: shift=1, ctrl=2, alt=4 — vary by build)
    if type(modifier) == "number" then
        if modifier == 1 or modifier == 3 or modifier == 5 or modifier == 7 then
            shift = true
        end
        if modifier == 2 or modifier == 3 or modifier == 6 or modifier == 7 then
            ctrl = true
        end
    end

    if isF9 then
        if alt then
            dbg("keyEvent Alt+F9 -> compare")
            FS25E_Input.onToggleCompare("KEY_f9", 1, nil, false)
            return
        end
        if ctrl or shift then
            -- User binding: Ctrl+F9 (and Shift+F9) toggle Live Overlay — not settings
            dbg(string.format("keyEvent %sF9 -> overlay", ctrl and "Ctrl+" or "Shift+"))
            FS25E_Input.onToggleLiveOverlay("KEY_f9", 1, nil, false)
        else
            dbg("keyEvent F9 -> settings")
            openSettings("keyEvent:F9")
        end
        return
    end
    if isE and ctrl and not shift then
        dbg("keyEvent Ctrl+E -> settings")
        openSettings("keyEvent:Ctrl+E")
    end
end

function FS25E_Input.registerKeyFallback()
    if keyHooked then
        return true
    end
    if FS25E_HookManager == nil or FSBaseMission == nil or FSBaseMission.keyEvent == nil then
        dbg("keyEvent fallback unavailable")
        return false
    end
    local ok = FS25E_HookManager.register(FSBaseMission, "keyEvent", "appended", function(self, unicode, sym, modifier, isDown)
        FS25E_Input.onKeyEvent(self, unicode, sym, modifier, isDown)
    end)
    keyHooked = ok == true
    dbg("keyEvent fallback hooked=" .. tostring(keyHooked))
    return keyHooked
end

function FS25E_Input.register()
    if g_inputBinding == nil or g_inputBinding.registerActionEvent == nil then
        dbg("registerActionEvent unavailable")
    else
        if not registered then
            eventIds = {}
            local n = 0
            if tryRegisterOne("FS25E_OPEN_SETTINGS", FS25E_Input.onOpenSettings) then n = n + 1 end
            if tryRegisterOne("FS25E_TOGGLE_LIVE_OVERLAY", FS25E_Input.onToggleLiveOverlay) then n = n + 1 end
            if tryRegisterOne("FS25E_LIVE_HINT", FS25E_Input.onLiveHint) then n = n + 1 end
            if tryRegisterOne("FS25E_TOGGLE_COMPARE", FS25E_Input.onToggleCompare) then n = n + 1 end
            registered = n > 0
            dbg(string.format("ActionEvents registered count=%d", n))
        end
    end
    FS25E_Input.registerKeyFallback()
    return registered or keyHooked
end

function FS25E_Input.unregister()
    if g_inputBinding ~= nil then
        if g_inputBinding.removeActionEventsByTarget ~= nil then
            pcall(function()
                g_inputBinding:removeActionEventsByTarget(FS25E_Input)
            end)
        elseif g_inputBinding.removeActionEvent ~= nil then
            for i = 1, #eventIds do
                pcall(g_inputBinding.removeActionEvent, g_inputBinding, eventIds[i])
            end
        end
    end
    eventIds = {}
    lastOpenMs = -1000
    lastLiveMs = -1000
    registered = false
    dbg("ActionEvents unregistered (key fallback stays for session)")
end

function FS25E_Input.isRegistered()
    return registered or keyHooked
end
