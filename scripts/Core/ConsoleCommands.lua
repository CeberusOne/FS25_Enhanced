-- Manual test helpers. Never auto-apply graphics on load.
FS25E_ConsoleCommands = {}

local registered = false
local commandTargets = {}

local function tryAdd(name, description, callback)
    local fn = FS25E_ConsoleCommands[callback]
    if type(fn) ~= "function" then return false end
    if commandTargets[name] ~= nil then return true end
    local target = { run = function(_, ...) return fn(...) end }
    local ok, result = pcall(addConsoleCommand, name, description, "run", target)
    if not ok or result == false then
        FS25E_Debug.warning("Console", "registration failed " .. name .. ": " .. tostring(result))
        return false
    end
    commandTargets[name] = target
    return true
end

local function say(msg)
    FS25E_Debug.info("Console", tostring(msg))
    if print ~= nil then print("[FS25_Enhanced] " .. tostring(msg)) end
end

function FS25E_ConsoleCommands.forceRestore()
    if FS25E_VisualProfiles then FS25E_VisualProfiles.endCompare() end
    local ok = true
    if FS25E_RestoreManager then ok = FS25E_RestoreManager.restoreAll() and ok end
    if FS25E_VisualControls then ok = FS25E_VisualControls.restoreAll() and ok end
    say("forceRestore ok=" .. tostring(ok))
end

function FS25E_ConsoleCommands.apiDump(pattern)
    pattern = tostring(pattern or "")
    if pattern == "" then say("usage: fs25eApiDump <pattern>"); return end
    local names = {}
    for name, value in pairs(_G) do
        if type(value) == "function" and type(name) == "string" and name:find(pattern) then
            names[#names + 1] = name
        end
    end
    table.sort(names)
    say(string.format("%d global functions match '%s'", #names, pattern))
    for i = 1, math.min(#names, 200) do say("  " .. names[i]) end
    if #names > 200 then say("  ... " .. (#names - 200) .. " more") end
end

function FS25E_ConsoleCommands.apiInventory()
    if not FS25E_ApiInventory then say("ApiInventory unavailable"); return end
    local ok = FS25E_ApiInventory.log(true)
    say(string.format("apiInventory written to log ok=%s", tostring(ok)))
end

function FS25E_ConsoleCommands.openSettings()
    local ok = FS25E_LiveOverlay ~= nil and FS25E_LiveOverlay.show()
    say(string.format("openSettings ok=%s", tostring(ok)))
end

function FS25E_ConsoleCommands.closeSettings()
    if FS25E_LiveOverlay then FS25E_LiveOverlay.hide() end
    say("closeSettings")
end

function FS25E_ConsoleCommands.audit()
    local C = FS25E_VisualControls
    if not C then say('Control catalog unavailable'); return end
    say('Read-only runtime audit; no render settings are changed')
    for _, c in ipairs(C.getControls()) do
        local available, reason = C.available(c)
        local state = C.getState(c.id) or {}
        say(string.format('control=%s available=%s value=%s status=%s reason=%s',
            c.id, tostring(available), tostring(C.read(c)), tostring(state.status or 'UNTOUCHED'),
            tostring(reason or state.error or '')))
    end
end

function FS25E_ConsoleCommands.register()
    if registered then return true end
    if type(addConsoleCommand) ~= "function" then
        FS25E_Debug.info("Console", "addConsoleCommand unavailable")
        return false
    end
    local n = 0
    if tryAdd("fs25eAudit", "FS25_Enhanced: read-only control audit to log.txt", "audit") then n = n + 1 end
    if tryAdd("fs25eRestore", "FS25_Enhanced: restore stock graphics for this session", "forceRestore") then n = n + 1 end
    if tryAdd("fs25eOpenSettings", "FS25_Enhanced: open the live window", "openSettings") then n = n + 1 end
    if tryAdd("fs25eCloseSettings", "FS25_Enhanced: close the live window", "closeSettings") then n = n + 1 end
    if tryAdd("fs25eApiDump", "FS25_Enhanced: list engine global functions matching a pattern", "apiDump") then n = n + 1 end
    if tryAdd("fs25eApiInventory", "FS25_Enhanced: log atmosphere/tone engine names (read-only)", "apiInventory") then n = n + 1 end
    registered = n > 0
    FS25E_Debug.info("Console", string.format("registered %d console commands", n))
    return registered
end

function FS25E_ConsoleCommands.unregister()
    if not registered or removeConsoleCommand == nil then registered = false; return end
    for name in pairs(commandTargets) do pcall(removeConsoleCommand, name) end
    commandTargets = {}
    registered = false
end
