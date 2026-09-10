-- FS25_Enhanced / Core/ConsoleCommands.lua
-- Optional manual test helpers via addConsoleCommand (GDN documented).
-- NEVER sets autoApply=true. Manual apply goes through Wave-1 Manager APIs only.

FS25E_ConsoleCommands = {}

local registered = false

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
        say(string.format(
            "cap id=%s status=%s setter=%s applyMode=%s",
            tostring(id),
            tostring(entry.status),
            tostring(entry.setter),
            tostring(entry.applyMode)
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
    if FS25E_RestoreManager ~= nil then
        FS25E_RestoreManager.restoreAll()
        say("forceRestore: RestoreManager.restoreAll invoked")
    else
        say("RestoreManager missing")
    end
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
    say(string.format("selectPreset %s ok=%s (cache only)", tostring(name), tostring(ok)))
end

function FS25E_ConsoleCommands.setGovernorEnabled(flag)
    if FS25E_GraphicsGovernor == nil then
        say("GraphicsGovernor missing")
        return
    end
    local on = flag == "1" or flag == "true" or flag == "on"
    FS25E_GraphicsGovernor.setEnabled(on)
    if FS25E_GraphicsGovernor.setAutoApply ~= nil then
        FS25E_GraphicsGovernor.setAutoApply(false)
    end
    say(string.format("governor enabled=%s autoApply=false", tostring(on)))
end

local function tryAdd(name, description, fnName)
    if addConsoleCommand == nil then
        return false
    end
    local ok, err = pcall(function()
        addConsoleCommand(name, description, fnName, FS25E_ConsoleCommands)
    end)
    if not ok then
        FS25E_Debug.warning("Console", string.format("addConsoleCommand %s failed: %s", name, tostring(err)))
        return false
    end
    return true
end

function FS25E_ConsoleCommands.register()
    if registered then
        return true
    end
    if addConsoleCommand == nil then
        FS25E_Debug.info("Console", "addConsoleCommand unavailable (dev controls / API); stubs ready for later")
        return false
    end
    local n = 0
    if tryAdd("fs25eDumpCaps", "FS25_Enhanced: dump capability registry", "dumpCaps") then n = n + 1 end
    if tryAdd("fs25eDumpScene", "FS25_Enhanced: dump scene/governor/perf snapshot", "dumpScene") then n = n + 1 end
    if tryAdd("fs25eApplyLodCoeff", "FS25_Enhanced: manual setViewDistanceCoeff via LodGovernor", "applyLodCoeff") then n = n + 1 end
    if tryAdd("fs25eApplyMaxShadowLights", "FS25_Enhanced: manual setMaxNumShadowLights via ShadowManager", "applyMaxShadowLights") then n = n + 1 end
    if tryAdd("fs25eRestore", "FS25_Enhanced: force session restore", "forceRestore") then n = n + 1 end
    if tryAdd("fs25eSelectPreset", "FS25_Enhanced: select preset into SettingsCache (no engine apply)", "selectPreset") then n = n + 1 end
    if tryAdd("fs25eGovernor", "FS25_Enhanced: enable governor observe (1/0); never enables autoApply", "setGovernorEnabled") then n = n + 1 end
    registered = n > 0
    FS25E_Debug.info("Console", string.format("registered %d console commands (autoApply never forced on)", n))
    return registered
end

function FS25E_ConsoleCommands.unregister()
    if not registered or removeConsoleCommand == nil then
        registered = false
        return
    end
    local names = {
        "fs25eDumpCaps",
        "fs25eDumpScene",
        "fs25eApplyLodCoeff",
        "fs25eApplyMaxShadowLights",
        "fs25eRestore",
        "fs25eSelectPreset",
        "fs25eGovernor",
    }
    for i = 1, #names do
        pcall(removeConsoleCommand, names[i])
    end
    registered = false
    FS25E_Debug.info("Console", "console commands removed")
end
