-- F9 toggles the live window. ActionEvents for SYSTEM keys are unreliable, so
-- a keyEvent fallback is the real path. No other open shortcuts.
FS25E_Input = {}

local registered = false
local keyHooked = false
local eventIds = {}
local lastOpenMs = -1000
local lastCompareMs = -1000
local OPEN_COOLDOWN_MS = 250

local function dbg(msg)
    if FS25E_Debug ~= nil then FS25E_Debug.info("Input", tostring(msg)) end
end

local function notify(text)
    dbg(text)
    if g_currentMission ~= nil and g_currentMission.addIngameNotification ~= nil then
        pcall(function()
            g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_INFO, text)
        end)
    end
end

local function t(key, fallback)
    if FS25E_Localization ~= nil and FS25E_Localization.t ~= nil then
        return FS25E_Localization.t(key, fallback)
    end
    return fallback or key
end

local function nowMs()
    if g_time ~= nil then return g_time end
    return 0
end

local function isAltDown(modifier)
    if Input ~= nil and Input.isKeyPressed ~= nil then
        if Input.KEY_lalt and Input.isKeyPressed(Input.KEY_lalt) then return true end
        if Input.KEY_ralt and Input.isKeyPressed(Input.KEY_ralt) then return true end
    end
    if type(modifier) == "number" and (modifier == 4 or modifier == 5 or modifier == 6 or modifier == 7) then
        return true
    end
    return false
end

local function isF9(sym)
    -- Only the real F9 scancode. 120 is the X key; treating it as F9 opened the window.
    local keyF9 = Input and Input.KEY_f9
    return keyF9 ~= nil and sym == keyF9
end

local function toggleWindow(source)
    local tnow = nowMs()
    if tnow >= lastOpenMs and (tnow - lastOpenMs) < OPEN_COOLDOWN_MS then return end
    lastOpenMs = tnow
    dbg("F9 toggle via " .. tostring(source))
    if FS25E_LiveOverlay == nil or FS25E_LiveOverlay.toggle == nil then
        notify(t("FS25E_LIVE_OVERLAY_UNAVAILABLE", "Live Overlay unavailable"))
        return
    end
    local ok, err = pcall(FS25E_LiveOverlay.toggle)
    if not ok then
        dbg("toggle failed: " .. tostring(err))
        notify(t("FS25E_LIVE_OVERLAY_UNAVAILABLE", "Live Overlay unavailable"))
    end
end

local function toggleCompare(source)
    local tnow = nowMs()
    if tnow >= lastCompareMs and (tnow - lastCompareMs) < OPEN_COOLDOWN_MS then return end
    lastCompareMs = tnow
    if FS25E_VisualProfiles == nil or FS25E_VisualProfiles.toggleCompare == nil then return end
    local ok, status = FS25E_VisualProfiles.toggleCompare()
    local comparing = FS25E_VisualProfiles.isComparing()
    dbg(string.format("compare via %s ok=%s comparing=%s status=%s", tostring(source), tostring(ok), tostring(comparing), tostring(status)))
    notify(t(comparing and "FS25E_compare_vanilla_notice" or "FS25E_compare_mod_notice",
        comparing and "FS25 Enhanced: VANILLA" or "FS25 Enhanced: MOD"))
end

function FS25E_Input.onOpenSettings(actionName, inputValue, callbackState, isAnalog)
    if inputValue ~= nil and tonumber(inputValue) == 0 then return end
    toggleWindow("ActionEvent:" .. tostring(actionName))
end

function FS25E_Input.onToggleCompare(actionName, inputValue, callbackState, isAnalog)
    if inputValue ~= nil and tonumber(inputValue) == 0 then return end
    toggleCompare("ActionEvent:" .. tostring(actionName))
end

function FS25E_Input.onKeyEvent(_self, unicode, sym, modifier, isDown)
    if isDown ~= true then return end
    if not isF9(sym) then return end
    if isAltDown(modifier) then
        toggleCompare("keyEvent:Alt+F9")
        return
    end
    toggleWindow("keyEvent:F9")
end

function FS25E_Input.registerKeyFallback()
    if keyHooked then return true end
    if FS25E_HookManager == nil or FSBaseMission == nil or FSBaseMission.keyEvent == nil then
        dbg("keyEvent fallback unavailable")
        return false
    end
    local ok = FS25E_HookManager.register(FSBaseMission, "keyEvent", "appended", function(self, unicode, sym, modifier, isDown)
        FS25E_Input.onKeyEvent(self, unicode, sym, modifier, isDown)
    end, "f9")
    keyHooked = ok == true
    dbg("keyEvent fallback hooked=" .. tostring(keyHooked))
    return keyHooked
end

local function tryRegisterOne(actionName, callback)
    local action = (InputAction ~= nil and InputAction[actionName]) or actionName
    local ok2, err2 = pcall(function()
        local okFlag, eid = g_inputBinding:registerActionEvent(action, FS25E_Input,
            function(_, ...) return callback(...) end, false, true, false, true)
        if type(okFlag) ~= "boolean" then
            eid = okFlag
            okFlag = eid ~= nil
        end
        if eid ~= nil then
            eventIds[#eventIds + 1] = eid
            if g_inputBinding.setActionEventTextVisibility ~= nil then
                pcall(function() g_inputBinding:setActionEventTextVisibility(eid, false) end)
            end
            if g_inputBinding.setActionEventActive ~= nil then
                pcall(function() g_inputBinding:setActionEventActive(eid, true) end)
            end
            dbg(string.format("registered %s eid=%s", tostring(actionName), tostring(eid)))
        end
    end)
    if not ok2 then
        dbg("register failed " .. tostring(actionName) .. ": " .. tostring(err2))
        return false
    end
    return true
end

function FS25E_Input.register()
    FS25E_Input.registerKeyFallback()
    if g_inputBinding == nil or g_inputBinding.registerActionEvent == nil then
        dbg("registerActionEvent unavailable")
        return keyHooked
    end
    if not registered then
        eventIds = {}
        tryRegisterOne("FS25E_OPEN_SETTINGS", FS25E_Input.onOpenSettings)
        registered = true
    end
    return registered or keyHooked
end

function FS25E_Input.unregister()
    if g_inputBinding ~= nil then
        if g_inputBinding.removeActionEventsByTarget ~= nil then
            pcall(function() g_inputBinding:removeActionEventsByTarget(FS25E_Input) end)
        elseif g_inputBinding.removeActionEvent ~= nil then
            for i = 1, #eventIds do
                pcall(g_inputBinding.removeActionEvent, g_inputBinding, eventIds[i])
            end
        end
    end
    eventIds = {}
    lastOpenMs = -1000
    registered = false
    dbg("ActionEvents unregistered (F9 key fallback stays)")
end

function FS25E_Input.isRegistered()
    return registered or keyHooked
end

FS25E_Input.isSettingsDialogVisible = function() return false end
