-- FS25_Enhanced / UI/FS25E_Input.lua
-- ActionEvents + F9/Ctrl+E keyEvent fallback (ActionEvents alone often silent for SYSTEM).

FS25E_Input = {}

local registered = false
local keyHooked = false
local eventIds = {}
local lastOpenMs = 0
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
    if FS25E_SettingsController ~= nil and FS25E_SettingsController.t ~= nil then
        return FS25E_SettingsController.t(key, fallback)
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

local function isSettingsDialogVisible()
    if g_gui == nil then
        return false
    end
    if g_gui.currentGuiName == "FS25E_SettingsDialog" or g_gui.currentDialogName == "FS25E_SettingsDialog" then
        return true
    end
    if g_gui.guis ~= nil and g_gui.guis["FS25E_SettingsDialog"] ~= nil then
        local dlg = g_gui.guis["FS25E_SettingsDialog"]
        local target = dlg.target or dlg
        if target ~= nil and target.getIsVisible ~= nil then
            local ok, vis = pcall(function() return target:getIsVisible() end)
            if ok and vis == true then
                return true
            end
        end
        if target ~= nil and target.isOpen == true then
            return true
        end
    end
    return false
end

local function closeSettings(source)
    dbg("closeSettings via " .. tostring(source))
    local usedDialogClose = false
    if g_gui ~= nil and g_gui.guis ~= nil and g_gui.guis["FS25E_SettingsDialog"] ~= nil then
        local dlg = g_gui.guis["FS25E_SettingsDialog"]
        local target = dlg.target or dlg
        if target ~= nil and target.close ~= nil then
            pcall(function() target:close() end)
            usedDialogClose = true
        end
    end
    if g_gui ~= nil and g_gui.closeDialogByName ~= nil then
        pcall(function() g_gui:closeDialogByName("FS25E_SettingsDialog") end)
    end
    if not usedDialogClose and FS25E_ConsoleCommands ~= nil and FS25E_ConsoleCommands.closeSettings ~= nil then
        pcall(FS25E_ConsoleCommands.closeSettings)
    end
    if g_inputBinding ~= nil and g_inputBinding.setShowMouseCursor ~= nil then
        pcall(function() g_inputBinding:setShowMouseCursor(false) end)
    end
    dbg("closeSettings done")
end

--- F9 / Action: open if closed, close if already visible (toggle).
local function openSettings(source)
    local tnow = nowMs()
    if lastOpenMs > 0 and (tnow - lastOpenMs) < OPEN_COOLDOWN_MS then
        return
    end
    lastOpenMs = tnow
    if isSettingsDialogVisible() then
        closeSettings(source .. ":toggleClose")
        return
    end
    dbg("openSettings via " .. tostring(source))
    if FS25E_GuiLoader ~= nil and FS25E_GuiLoader.showSettingsDialog ~= nil then
        local ok = FS25E_GuiLoader.showSettingsDialog()
        dbg("showSettingsDialog ok=" .. tostring(ok))
        if not ok then
            notify(t("FS25E_SETTINGS_TITLE", "FS25 Enhanced") .. ": GUI open failed (see log)")
        end
    else
        dbg("open settings: GuiLoader missing")
        notify("FS25 Enhanced: GuiLoader missing")
    end
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
        local okFlag, eid = g_inputBinding:registerActionEvent(action, FS25E_Input, callback, false, true, false, true)
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
    -- Esc closes Settings Dialog when it is the current GUI (not Live Overlay).
    local isEsc = (sym == 27) or (Input ~= nil and Input.KEY_esc ~= nil and sym == Input.KEY_esc)
    if isEsc and isSettingsDialogVisible() then
        closeSettings("keyEvent:Esc")
        return
    end

    local keyF9 = (Input ~= nil and Input.KEY_f9) or nil
    local keyE = (Input ~= nil and Input.KEY_e) or nil
    local isF9 = (keyF9 ~= nil and sym == keyF9) or sym == 290 or sym == 120 -- F9 common codes
    local isE = (keyE ~= nil and sym == keyE)

    local shift = false
    local ctrl = false
    if Input ~= nil then
        if Input.isKeyPressed ~= nil then
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
    registered = false
    dbg("ActionEvents unregistered (key fallback stays for session)")
end

function FS25E_Input.isRegistered()
    return registered or keyHooked
end
