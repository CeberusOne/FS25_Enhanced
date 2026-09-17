-- FS25_Enhanced / Core/ConsoleCommands.lua
-- Optional manual test helpers via addConsoleCommand (GDN documented).
-- NEVER sets autoApply=true. Manual apply goes through Wave-1 Manager / Expert APIs.
-- Expert Soft-Apply default false; requires expertMode.

FS25E_ConsoleCommands = {}

local unpack = rawget(_G, "unpack") or table.unpack

local registered = false
local commandTargets = {}

-- GIANTS invokes callbacks with their target as first argument; these helpers
-- are plain functions, so adapt that argument explicitly.
local function tryAdd(name, description, callback)
    local fn = FS25E_ConsoleCommands[callback]
    if type(fn) ~= "function" then
        FS25E_Debug.warning("Console", "command unavailable: " .. tostring(name))
        return false
    end
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
    if print ~= nil then
        print("[FS25_Enhanced] " .. tostring(msg))
    end
end

function FS25E_ConsoleCommands.dumpCaps()
    if FS25E_CapabilityRegistry == nil then
        say("CapabilityRegistry missing")
        return
    end
    local all = FS25E_CapabilityRegistry.all()
    local n = 0
    for id, entry in pairs(all) do
        n = n + 1
        local lastResult, lastError = "-", ""
        if FS25E_Diagnostics ~= nil and FS25E_Diagnostics.getCapRuntime ~= nil then
            local rt = FS25E_Diagnostics.getCapRuntime(id)
            if rt ~= nil then
                lastResult = tostring(rt.lastResult or "-")
                lastError = tostring(rt.lastError or "")
            end
        end
        say(string.format(
            "cap id=%s status=%s setter=%s applyMode=%s lastResult=%s lastError=%s",
            tostring(id),
            tostring(entry.status),
            tostring(entry.setter),
            tostring(entry.applyMode),
            lastResult,
            lastError
        ))
    end
    say(string.format("dumpCaps done count=%d", n))
end

function FS25E_ConsoleCommands.dumpScene()
    if FS25E_SceneAnalyzer ~= nil then
        local s = FS25E_SceneAnalyzer.getSnapshot()
        say(string.format(
            "scene mission=%s inVehicle=%s hour=%s fog=%s rain=%s loadHint=%d ticks=%d",
            tostring(s.hasMission),
            tostring(s.inVehicle),
            tostring(s.hour),
            tostring(s.fogActive),
            tostring(s.rainActive),
            FS25E_SceneAnalyzer.getLoadHint(),
            FS25E_SceneAnalyzer.getTickCount()
        ))
    else
        say("SceneAnalyzer missing")
    end
    if FS25E_GraphicsGovernor ~= nil then
        say(string.format(
            "governor mode=%s desired=%s preset=%s enabled=%s autoApply=%s ticks=%d",
            tostring(FS25E_GraphicsGovernor.getMode()),
            tostring(FS25E_GraphicsGovernor.getDesiredMode()),
            tostring(FS25E_GraphicsGovernor.getDesiredPreset()),
            tostring(FS25E_GraphicsGovernor.isEnabled()),
            tostring(FS25E_GraphicsGovernor.isAutoApply()),
            FS25E_GraphicsGovernor.getDecisionTicks()
        ))
    end
    if FS25E_PerformanceMonitor ~= nil then
        say(string.format(
            "perf avgMs=%.2f lastMs=%.2f budget=%.2f samples=%d",
            FS25E_PerformanceMonitor.getAverageMs(),
            FS25E_PerformanceMonitor.getLastFrameMs(),
            FS25E_PerformanceMonitor.getTargetBudgetMs(),
            FS25E_PerformanceMonitor.getSampleCount()
        ))
    end
end

function FS25E_ConsoleCommands.applyLodCoeff(valueStr)
    local v = tonumber(valueStr)
    if v == nil then
        say("usage: fs25eApplyLodCoeff <float>  (clamped by LodGovernor)")
        return
    end
    if FS25E_LodGovernor == nil then
        say("LodGovernor missing")
        return
    end
    local ok, err = FS25E_LodGovernor.setViewDistanceCoeff(v)
    say(string.format("applyLodCoeff value=%s ok=%s err=%s (manual; autoApply untouched)", tostring(v), tostring(ok), tostring(err)))
end

function FS25E_ConsoleCommands.applyMaxShadowLights(valueStr)
    local v = tonumber(valueStr)
    if v == nil then
        say("usage: fs25eApplyMaxShadowLights <int>")
        return
    end
    if FS25E_ShadowManager == nil then
        say("ShadowManager missing")
        return
    end
    local ok, err = FS25E_ShadowManager.setMaxNumShadowLights(v)
    say(string.format("applyMaxShadowLights value=%s ok=%s err=%s (manual; autoApply untouched)", tostring(v), tostring(ok), tostring(err)))
end

function FS25E_ConsoleCommands.forceRestore()
    if FS25E_VisualProfiles then FS25E_VisualProfiles.endCompare() end
    local ok=FS25E_SettingsAPI and FS25E_SettingsAPI.set('enabled',false)
    say("forceRestore: Enhanced disabled; originals restored; ok="..tostring(ok))
end

function FS25E_ConsoleCommands.selectPreset(name)
    if name == nil or name == "" then
        say("usage: fs25eSelectPreset <Performance|Balanced|Quality|Cinematic>")
        return
    end
    if FS25E_ProfileManager == nil then
        say("ProfileManager missing")
        return
    end
    local ok = FS25E_ProfileManager.selectPreset(name)
    say(string.format("selectPreset %s ok=%s (validated runtime targets)", tostring(name), tostring(ok)))
end

--- fs25eApiDump <pattern>: list the engine's global functions whose name
--- matches a Lua pattern (e.g. "Fog", "^setLight"). The only honest way to
--- find out which setters the installed build really exposes.
function FS25E_ConsoleCommands.apiDump(pattern)
    pattern = tostring(pattern or "")
    if pattern == "" then say("usage: fs25eApiDump <pattern>"); return end
    local names = {}
    for name, value in pairs(_G) do
        if type(value) == "function" and type(name) == "string" and name:find(pattern) then names[#names + 1] = name end
    end
    table.sort(names)
    say(string.format("%d global functions match '%s'", #names, pattern))
    for i = 1, math.min(#names, 200) do say("  " .. names[i]) end
    if #names > 200 then say("  ... " .. (#names - 200) .. " more") end
end

--- fs25eApiInventory: repeat the one-shot keyword inventory (names only).
function FS25E_ConsoleCommands.apiInventory()
    if not FS25E_ApiInventory then say("ApiInventory unavailable"); return end
    local ok = FS25E_ApiInventory.log(true)
    say(string.format("apiInventory written to log ok=%s", tostring(ok)))
end

function FS25E_ConsoleCommands.openSettings()
    local ok = FS25E_LiveOverlay ~= nil and FS25E_LiveOverlay.show()
    say(string.format("openSettings (live window) ok=%s", tostring(ok)))
end

function FS25E_ConsoleCommands.closeSettings()
    if FS25E_LiveOverlay then FS25E_LiveOverlay.hide() end
    say("closeSettings (live window) closed=true")
end

function FS25E_ConsoleCommands.audit()
    local C=FS25E_VisualControls
    if not C then say('Control catalog unavailable'); return end
    say('Read-only runtime audit; no render settings are changed; visual/performance status NOT_TESTED')
    for _,c in ipairs(C.getControls()) do
        local available,reason=C.available(c); local state=C.getState(c.id) or {}; local meta=C.getMetadata(c.id)
        say(string.format('control=%s available=%s value=%s locked=%s status=%s reason=%s source=%s',
            c.id,tostring(available),tostring(C.read(c)),tostring(C.isLocked(c.id)),tostring(state.status or 'UNTOUCHED'),
            tostring(reason or state.error or ''),tostring(meta and meta.source)))
        if state.diagnosticError then say('detail '..c.id..': '..tostring(state.diagnosticError)) end
    end
    FS25E_ConsoleCommands.dumpScene()
end

function FS25E_ConsoleCommands.probe(category)
    if not FS25E_ProbeSession then return 'Runtime probe unavailable' end
    local ok=FS25E_ProbeSession.snapshot(category)
    return ok and 'FS25E_PROBE snapshot written to log.txt' or 'Usage: fs25eProbe [all|environment|lighting|weather|materials|render] (loaded client mission required)'
end
function FS25E_ConsoleCommands.probeWatch(seconds,category)
    if not FS25E_ProbeSession then return 'Runtime probe unavailable' end
    local ok=FS25E_ProbeSession.start(seconds,category)
    return ok and 'FS25E_PROBE change recording started; fs25eProbeStop ends it early' or 'Usage: fs25eProbeWatch [seconds 2..300, default 60] [all|environment|lighting|weather|materials|render]'
end
function FS25E_ConsoleCommands.probeStop()
    if FS25E_ProbeSession then FS25E_ProbeSession.stop('console') end
    return 'FS25E_PROBE change recording stopped'
end

function FS25E_ConsoleCommands.register()
    if registered then
        return true
    end
    if type(addConsoleCommand) ~= "function" then
        FS25E_Debug.info("Console", "addConsoleCommand unavailable (dev controls / API); stubs ready for later")
        return false
    end
    local n = 0
    if tryAdd('fs25eProbe', 'FS25_Enhanced: bounded read-only graphics runtime snapshot', 'probe') then n = n + 1 end
    if tryAdd('fs25eProbeWatch', 'FS25_Enhanced: record graphics changes for 2..300 seconds', 'probeWatch') then n = n + 1 end
    if tryAdd('fs25eProbeStop', 'FS25_Enhanced: stop graphics change recording', 'probeStop') then n = n + 1 end
    if tryAdd("fs25eAudit", "FS25_Enhanced: read-only control and scene audit to log.txt", "audit") then n = n + 1 end
    if tryAdd("fs25eDumpCaps", "FS25_Enhanced: dump capability registry", "dumpCaps") then n = n + 1 end
    if tryAdd("fs25eDumpScene", "FS25_Enhanced: dump scene/governor/perf snapshot", "dumpScene") then n = n + 1 end
    if tryAdd("fs25eApplyLodCoeff", "FS25_Enhanced: manual setViewDistanceCoeff via LodGovernor", "applyLodCoeff") then n = n + 1 end
    if tryAdd("fs25eApplyMaxShadowLights", "FS25_Enhanced: manual setMaxNumShadowLights via ShadowManager", "applyMaxShadowLights") then n = n + 1 end
    if tryAdd("fs25eRestore", "FS25_Enhanced: force session restore", "forceRestore") then n = n + 1 end
    if tryAdd("fs25eSelectPreset", "FS25_Enhanced: select validated runtime preset", "selectPreset") then n = n + 1 end
    if tryAdd("fs25eOpenSettings", "FS25_Enhanced: open the live window", "openSettings") then n = n + 1 end
    if tryAdd("fs25eCloseSettings", "FS25_Enhanced: close the live window", "closeSettings") then n = n + 1 end
    if tryAdd("fs25eApiDump", "FS25_Enhanced: list engine global functions matching a pattern", "apiDump") then n = n + 1 end
    if tryAdd("fs25eApiInventory", "FS25_Enhanced: log atmosphere/tone engine names and the Lighting object (read-only)", "apiInventory") then n = n + 1 end
    registered = n > 0
    FS25E_Debug.info("Console", string.format("registered %d console commands (autoApply never forced on)", n))
    return registered
end

function FS25E_ConsoleCommands.unregister()
    if not registered or removeConsoleCommand == nil then
        registered = false
        return
    end
    for name in pairs(commandTargets) do
        pcall(removeConsoleCommand, name)
    end
    commandTargets = {}
    registered = false
    FS25E_Debug.info("Console", "console commands removed")
end
