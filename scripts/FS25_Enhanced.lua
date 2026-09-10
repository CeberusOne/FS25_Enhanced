-- FS25_Enhanced.lua — Bootstrap (Phase 2 + Lights Spec Probe + Gen-1 Settings GUI)
-- Mission-level service only. Client-local. Auto-apply OFF by default.
-- Phase 2: SceneAnalyzer + hysteresis + preset stubs; no new automatic engine setters.
-- Lights: Spec-based RealLight discovery (no global scan); Soft-Apply off by default.
-- GUI Gen-1: MessageDialog settings; values via ModSettings; Expert+Status tabs.
-- Session-only apply + restore (no saveHardwareScalability / applyPerformanceClass).

local modName = g_currentModName
local modDirectory = g_currentModDirectory

FS25_Enhanced = {}
FS25_Enhanced.modName = modName
FS25_Enhanced.modDirectory = modDirectory
FS25_Enhanced.VERSION = "0.3.2.0"
FS25_Enhanced.initialized = false
FS25_Enhanced.missionActive = false

local function safeCall(label, fn)
    return FS25E_Debug.pcall("Bootstrap", label, fn)
end

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
        if FS25E_Diagnostics ~= nil and FS25E_Diagnostics.init ~= nil then
            FS25E_Diagnostics.init()
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
        if FS25E_CapabilityApplier ~= nil and FS25E_CapabilityApplier.reset ~= nil then
            FS25E_CapabilityApplier.reset()
        end
        if FS25E_ShadowManager ~= nil then
            FS25E_ShadowManager.init()
        end
        if FS25E_LodGovernor ~= nil then
            FS25E_LodGovernor.init()
        end
        if FS25E_LightDiscovery ~= nil and FS25E_LightDiscovery.init ~= nil then
            FS25E_LightDiscovery.init() -- softApply=false; profile subscribe; console
        end
        if FS25E_ProfileManager ~= nil then
            FS25E_ProfileManager.init(FS25_Enhanced.modDirectory)
        end
        if FS25E_PerformanceMonitor ~= nil then
            local target = 60
            if FS25E_SettingsSchema ~= nil then
                target = FS25E_SettingsSchema.get("targetFps") or 60
            end
            FS25E_PerformanceMonitor.init(target)
        end
        if FS25E_SceneAnalyzer ~= nil then
            FS25E_SceneAnalyzer.init()
        end
        if FS25E_GraphicsGovernor ~= nil then
            FS25E_GraphicsGovernor.init() -- enabled=false; auto-apply off
        end
        if FS25E_CompatibilityManager ~= nil then
            FS25E_CompatibilityManager.init()
            FS25E_CompatibilityManager.scan()
        end
        if FS25E_ConsoleCommands ~= nil then
            FS25E_ConsoleCommands.register()
        end
        if FS25E_Input ~= nil and FS25E_Input.register ~= nil then
            FS25E_Input.register()
        end
        -- Lazy GUI: do not force loadGui here; hotkey/console triggers ensureSettingsDialog.

        FS25_Enhanced.initialized = true
        local capCount = 0
        if FS25E_CapabilityRegistry ~= nil then
            capCount = FS25E_CapabilityRegistry.count()
        end
        FS25E_Debug.info("Bootstrap", string.format(
            "loadMap complete v%s caps=%d lightsProbe=on softApply=off auto-apply off gui=gen1 (phase2+lights+settings; no global scan)",
            FS25_Enhanced.VERSION,
            capCount
        ))
    end)
end

local function onDeleteMap()
    safeCall("onDeleteMap", function()
        FS25E_Debug.info("Bootstrap", "deleteMap begin — restore path")
        FS25_Enhanced.missionActive = false

        if FS25E_Input ~= nil and FS25E_Input.unregister ~= nil then
            FS25E_Input.unregister()
        end
        if FS25E_GuiLoader ~= nil and FS25E_GuiLoader.reset ~= nil then
            FS25E_GuiLoader.reset()
        end
        if FS25E_Diagnostics ~= nil and FS25E_Diagnostics.reset ~= nil then
            FS25E_Diagnostics.reset()
        end
        if FS25E_GraphicsGovernor ~= nil then
            FS25E_GraphicsGovernor.setEnabled(false)
            FS25E_GraphicsGovernor.reset()
        end
        if FS25E_SceneAnalyzer ~= nil then
            FS25E_SceneAnalyzer.reset()
        end
        if FS25E_PerformanceMonitor ~= nil then
            FS25E_PerformanceMonitor.reset()
        end
        if FS25E_ProfileManager ~= nil and FS25E_ProfileManager.reset ~= nil then
            FS25E_ProfileManager.reset()
        end

        if FS25E_LightDiscovery ~= nil then
            if FS25E_LightDiscovery.unsubscribeProfileChanges ~= nil then
                FS25E_LightDiscovery.unsubscribeProfileChanges()
            end
            if FS25E_LightDiscovery.reset ~= nil then
                FS25E_LightDiscovery.reset()
            end
        end

        if FS25E_RestoreManager ~= nil then
            FS25E_RestoreManager.restoreAll()
        end

        if FS25E_ShadowManager ~= nil and FS25E_ShadowManager.reset ~= nil then
            FS25E_ShadowManager.reset()
        end
        if FS25E_LodGovernor ~= nil and FS25E_LodGovernor.reset ~= nil then
            FS25E_LodGovernor.reset()
        end
        if FS25E_CapabilityApplier ~= nil and FS25E_CapabilityApplier.reset ~= nil then
            FS25E_CapabilityApplier.reset()
        end

        FS25_Enhanced.initialized = false
        FS25E_Debug.info("Bootstrap", "deleteMap complete (hooks retained for session reload)")
    end)
end

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

    safeCall("SceneAnalyzer.update", function()
        if FS25E_SceneAnalyzer ~= nil then
            FS25E_SceneAnalyzer.update(dt)
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

safeCall("bootstrap", function()
    FS25E_Debug.info("Bootstrap", string.format(
        "FS25_Enhanced %s loading as %s dir=%s",
        FS25_Enhanced.VERSION,
        tostring(modName),
        tostring(modDirectory)
    ))
    registerMissionHooks()
    -- Mileage-pattern: inject Lights probe specs during TypeManager.finalizeTypes (early).
    if FS25E_LightDiscovery ~= nil and FS25E_LightDiscovery.registerTypeInjection ~= nil then
        FS25E_LightDiscovery.registerTypeInjection()
    end
    local count = 0
    if FS25E_HookManager ~= nil then
        count = FS25E_HookManager.count()
    end
    FS25E_Debug.info("Bootstrap", string.format("hooks registered count=%d", count))
end)
