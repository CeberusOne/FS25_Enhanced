-- FS25_Enhanced.lua — Bootstrap (Phase 1 / v0.1 PoC Core)
-- Mission-level service only. Client-local graphics governor skeleton.
-- NO live engine graphics setters in this phase.

local modName = g_currentModName
local modDirectory = g_currentModDirectory

FS25_Enhanced = {}
FS25_Enhanced.modName = modName
FS25_Enhanced.modDirectory = modDirectory
FS25_Enhanced.VERSION = "0.1.0.0"
FS25_Enhanced.initialized = false
FS25_Enhanced.missionActive = false

local function safeCall(label, fn)
    return FS25E_Debug.pcall("Bootstrap", label, fn)
end

--- Mission load — NO-OP-safe if managers/APIs missing.
local function onLoadMap(mission)
    safeCall("onLoadMap", function()
        FS25E_Debug.info("Bootstrap", "loadMap begin mod=" .. tostring(FS25_Enhanced.modName))
        FS25_Enhanced.missionActive = true
        if FS25E_RestoreManager ~= nil then
            FS25E_RestoreManager.resetFlag()
        end

        if FS25E_ModSettings ~= nil then
            FS25E_ModSettings.init()
            FS25E_ModSettings.loadStub()
        end
        if FS25E_SettingsSchema ~= nil then
            FS25E_SettingsSchema.init()
        end
        if FS25E_CapabilityRegistry ~= nil then
            FS25E_CapabilityRegistry.load(FS25_Enhanced.modDirectory)
        end
        if FS25E_SettingsCache ~= nil then
            FS25E_SettingsCache.reset()
        end
        if FS25E_SettingsSchema ~= nil then
            FS25E_SettingsSchema.seedCache()
        end
        if FS25E_PerformanceMonitor ~= nil then
            local target = 60
            if FS25E_SettingsSchema ~= nil then
                target = FS25E_SettingsSchema.get("targetFps") or 60
            end
            FS25E_PerformanceMonitor.init(target)
        end
        if FS25E_GraphicsGovernor ~= nil then
            FS25E_GraphicsGovernor.init() -- enabled=false; no engine writers
        end
        if FS25E_CompatibilityManager ~= nil then
            FS25E_CompatibilityManager.init()
            FS25E_CompatibilityManager.scan()
        end

        FS25_Enhanced.initialized = true
        FS25E_Debug.info("Bootstrap", "loadMap complete (PoC core; governor disabled, no engine writers)")
    end)
end

--- Mission delete — NO-OP-safe restore path; keeps Utils hooks for next mission in-session.
local function onDeleteMap()
    safeCall("onDeleteMap", function()
        FS25E_Debug.info("Bootstrap", "deleteMap begin — restore path")
        FS25_Enhanced.missionActive = false

        if FS25E_GraphicsGovernor ~= nil then
            FS25E_GraphicsGovernor.setEnabled(false)
            FS25E_GraphicsGovernor.reset()
        end
        if FS25E_PerformanceMonitor ~= nil then
            FS25E_PerformanceMonitor.reset()
        end

        if FS25E_RestoreManager ~= nil then
            FS25E_RestoreManager.restoreAll()
        end

        FS25_Enhanced.initialized = false
        FS25E_Debug.info("Bootstrap", "deleteMap complete (hooks retained for session reload)")
    end)
end

--- Mission update — early-out NO-OP when inactive.
local function onUpdate(mission, dt)
    if not FS25_Enhanced.initialized or not FS25_Enhanced.missionActive then
        return
    end
    if dt == nil then
        return
    end

    safeCall("PerformanceMonitor.update", function()
        if FS25E_PerformanceMonitor ~= nil then
            FS25E_PerformanceMonitor.update(dt)
        end
    end)

    safeCall("GraphicsGovernor.update", function()
        if FS25E_GraphicsGovernor ~= nil then
            FS25E_GraphicsGovernor.update(dt)
        end
    end)
end

local function registerMissionHooks()
    if FS25E_HookManager == nil then
        FS25E_Debug.warning("Bootstrap", "HookManager missing; cannot register hooks")
        return
    end

    local loadHooked = false
    if Mission00 ~= nil and Mission00.loadMission00Finished ~= nil then
        loadHooked = FS25E_HookManager.register(Mission00, "loadMission00Finished", "appended", function(mission, ...)
            onLoadMap(mission)
        end)
    end
    if not loadHooked and FSBaseMission ~= nil and FSBaseMission.loadMapFinished ~= nil then
        loadHooked = FS25E_HookManager.register(FSBaseMission, "loadMapFinished", "appended", function(self, ...)
            onLoadMap(self)
        end)
    end
    if not loadHooked and Mission00 ~= nil and Mission00.load ~= nil then
        loadHooked = FS25E_HookManager.register(Mission00, "load", "appended", function(mission, ...)
            onLoadMap(mission)
        end)
    end
    if not loadHooked then
        FS25E_Debug.warning("Bootstrap", "Mission load hook target not available (NO-OP until classes exist)")
    end

    if FSBaseMission ~= nil then
        if FSBaseMission.update ~= nil then
            FS25E_HookManager.register(FSBaseMission, "update", "appended", function(self, dt)
                onUpdate(self, dt)
            end)
        end
        if FSBaseMission.delete ~= nil then
            FS25E_HookManager.register(FSBaseMission, "delete", "appended", function(self)
                onDeleteMap()
            end)
        end
    else
        FS25E_Debug.warning("Bootstrap", "FSBaseMission not available at register time (NO-OP until reload)")
    end
end

-- Capture mod identity at file load (extraSourceFiles); register hooks once.
safeCall("bootstrap", function()
    FS25E_Debug.info("Bootstrap", string.format(
        "FS25_Enhanced %s loading as %s dir=%s",
        FS25_Enhanced.VERSION,
        tostring(modName),
        tostring(modDirectory)
    ))
    registerMissionHooks()
    local count = 0
    if FS25E_HookManager ~= nil then
        count = FS25E_HookManager.count()
    end
    FS25E_Debug.info("Bootstrap", string.format("hooks registered count=%d", count))
end)
