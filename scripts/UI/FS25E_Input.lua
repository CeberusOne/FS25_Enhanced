-- FS25_Enhanced / UI/FS25E_Input.lua
-- ActionEvents: open settings + live-hint (no full live-tuning UI).

FS25E_Input = {}

local registered = false
local eventIds = {}

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

function FS25E_Input.onOpenSettings(actionName, inputValue, callbackState, isAnalog)
    if FS25E_GuiLoader ~= nil and FS25E_GuiLoader.showSettingsDialog ~= nil then
        FS25E_GuiLoader.showSettingsDialog()
    else
        dbg("open settings: GuiLoader missing")
    end
end

function FS25E_Input.onLiveHint(actionName, inputValue, callbackState, isAnalog)
    local msg = "Live Tuning später"
    if FS25E_SettingsController ~= nil and FS25E_SettingsController.t ~= nil then
        msg = FS25E_SettingsController.t("FS25E_LIVE_HINT_LATER", msg)
    end
    notify(msg)
end

local function resolveAction(name)
    if InputAction ~= nil and InputAction[name] ~= nil then
        return InputAction[name]
    end
    return name
end

function FS25E_Input.register()
    if registered then
        return true
    end
    if g_inputBinding == nil or g_inputBinding.registerActionEvent == nil then
        dbg("registerActionEvent unavailable")
        return false
    end

    local function tryRegister(actionName, callback)
        local action = resolveAction(actionName)
        local ok2, err2 = pcall(function()
            if g_inputBinding.beginActionEventsModification ~= nil then
                g_inputBinding:beginActionEventsModification(action)
            end
            local okFlag, eid = g_inputBinding:registerActionEvent(action, FS25E_Input, callback, false, true, false, true)
            if type(okFlag) ~= "boolean" then
                eid = okFlag
            end
            if eid ~= nil then
                eventIds[#eventIds + 1] = eid
                if g_inputBinding.setActionEventTextVisibility ~= nil then
                    g_inputBinding:setActionEventTextVisibility(eid, true)
                end
            end
            if g_inputBinding.endActionEventsModification ~= nil then
                g_inputBinding:endActionEventsModification()
            end
        end)
        if not ok2 then
            dbg("register failed " .. tostring(actionName) .. ": " .. tostring(err2))
            return false
        end
        return true
    end

    local n = 0
    if tryRegister("FS25E_OPEN_SETTINGS", FS25E_Input.onOpenSettings) then n = n + 1 end
    if tryRegister("FS25E_LIVE_HINT", FS25E_Input.onLiveHint) then n = n + 1 end
    registered = n > 0
    dbg(string.format("ActionEvents registered count=%d", n))
    return registered
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
    dbg("ActionEvents unregistered")
end

function FS25E_Input.isRegistered()
    return registered
end
