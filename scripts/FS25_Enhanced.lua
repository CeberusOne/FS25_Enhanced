-- Client-local graphics lifecycle. Restore before the mission deletes render entities.
-- Only modSettings are persisted; no game.xml hardware writes or binary hooks.

local modName = g_currentModName
local modDirectory = g_currentModDirectory

FS25_Enhanced = {}
FS25_Enhanced.modName = modName
FS25_Enhanced.modDirectory = modDirectory
FS25_Enhanced.VERSION = "0.4.2.7"
FS25_Enhanced.initialized = false
FS25_Enhanced.missionActive = false

local function safeCall(label, fn)
    return FS25E_Debug.pcall("Bootstrap", label, fn)
end

local function onLoadMap(mission)
    if g_dedicatedServer~=nil then return end
    safeCall("onLoadMap", function()
        FS25E_Debug.info("Bootstrap", "loadMap begin mod=" .. tostring(FS25_Enhanced.modName))
        FS25_Enhanced.missionActive = true
        if FS25E_RestoreManager ~= nil then
            FS25E_RestoreManager.resetFlag()
        end

        if FS25E_ModSettings ~= nil then
            FS25E_ModSettings.init()
            FS25E_ModSettings.load(true)
        end
        -- Settings are only known now; a pinned language must win over the game's.
        if FS25E_Localization ~= nil and FS25E_Localization.setLanguage ~= nil then
            FS25E_Localization.setLanguage(FS25E_Localization.getLanguageSetting())
        end
        if FS25E_SettingsSchema ~= nil then
            FS25E_SettingsSchema.init()
        end
        if FS25E_Diagnostics ~= nil and FS25E_Diagnostics.init ~= nil then
            FS25E_Diagnostics.init()
        end
        if FS25E_CostCatalog ~= nil then
            FS25E_CostCatalog.load(FS25_Enhanced.modDirectory)
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
        if FS25E_Diagnostics ~= nil then
            FS25E_Diagnostics.init()
            FS25E_Diagnostics.installHooks()
        end
        if FS25E_ShadowManager ~= nil then
            FS25E_ShadowManager.init()
        end
        if FS25E_ExperimentalCaps ~= nil then
            FS25E_ExperimentalCaps.init() -- expertMode gate; softApply=false
        end
        if FS25E_LodGovernor ~= nil then
            FS25E_LodGovernor.init()
        end
        if FS25E_LightDiscovery ~= nil and FS25E_LightDiscovery.init ~= nil then
            FS25E_LightDiscovery.init() -- softApply=false; profile subscribe; console
        end
        if FS25E_ModuleRuntime then safeCall("ModuleRuntime.init", FS25E_ModuleRuntime.init) end
        if FS25E_ProfileManager ~= nil then
            FS25E_ProfileManager.init(FS25_Enhanced.modDirectory)
        end
        if FS25E_TelemetryReader ~= nil then
            FS25E_TelemetryReader.init()
        end
        if FS25E_PerformanceMonitor ~= nil then
            local target = 60
            if FS25E_ModSettings ~= nil and FS25E_ModSettings.get ~= nil then
                target = tonumber(FS25E_ModSettings.get("targetFps")) or 60
            elseif FS25E_SettingsSchema ~= nil then
                target = tonumber(FS25E_SettingsSchema.get("targetFps")) or 60
            end
            FS25E_PerformanceMonitor.init(target)
        end
        if FS25E_SceneAnalyzer ~= nil then
            FS25E_SceneAnalyzer.init()
        end
        if FS25E_GraphicsGovernor ~= nil then
            FS25E_GraphicsGovernor.init() -- enabled=false; auto-apply off
        end
        -- Re-apply ModSettings after governor/lights exist (load ran earlier for path/values).
        if FS25E_ModSettings ~= nil and FS25E_ModSettings.applyToRuntime ~= nil then
            FS25E_ModSettings.applyToRuntime()
        end
        if FS25E_RuntimeControls then
            safeCall("RuntimeControls.init", function()
                FS25E_RuntimeControls.init()
                FS25E_VisualControls.registerProvider(FS25E_RuntimeControls)
                FS25E_VisualControls.registerProvider(FS25E_VisualProfiles)
                FS25E_VisualControls.registerProvider(FS25E_ProbeSession)
            end)
        end
        if FS25E_CompatibilityManager ~= nil then
            FS25E_CompatibilityManager.init()
            FS25E_CompatibilityManager.scan()
        end
        if FS25E_ConsoleCommands ~= nil then
            safeCall("ConsoleCommands.register", FS25E_ConsoleCommands.register)
        end
        if FS25E_Input ~= nil and FS25E_Input.register ~= nil then
            FS25E_Input.register()
        end
        if FS25E_LiveOverlay ~= nil then
            if FS25E_LiveOverlay.registerHooks ~= nil then
                FS25E_LiveOverlay.registerHooks()
            end
            if FS25E_LiveOverlay.installListeners ~= nil then
                FS25E_LiveOverlay.installListeners()
            end
        end
        if FS25E_HudOverlay ~= nil and FS25E_HudOverlay.registerHooks ~= nil then
            FS25E_HudOverlay.registerHooks()
        end

        FS25_Enhanced.initialized = true
        local capCount = 0
        if FS25E_CapabilityRegistry ~= nil then
            capCount = FS25E_CapabilityRegistry.count()
        end
        FS25E_Debug.info("Bootstrap", string.format(
            "loadMap complete v%s caps=%d menu input registration complete; graphics use current user settings",
            FS25_Enhanced.VERSION,
            capCount
        ))
    end)
end

local function onDeleteMap()
    if FS25E_ProbeSession then FS25E_ProbeSession.reset() end
    if FS25E_ApiInventory then FS25E_ApiInventory.reset() end
    safeCall("onDeleteMap", function()
        FS25E_Debug.info("Bootstrap", "deleteMap begin — restore path")
        if FS25E_CalibrationManager and FS25E_CalibrationManager.cancel then
            safeCall("Calibration.cancelBeforeRestore", function() FS25E_CalibrationManager.cancel('mission end') end)
        end
        if FS25E_VisualProfiles then safeCall("Compare.endBeforeSave", FS25E_VisualProfiles.endCompare) end
        if FS25E_GraphicsGovernor and FS25E_GraphicsGovernor.endCinematic then
            safeCall("Cinematic.endBeforeSave", FS25E_GraphicsGovernor.endCinematic)
        end
        if FS25E_ModSettings ~= nil and FS25E_ModSettings.save ~= nil then
            safeCall("ModSettings.save", function()
                FS25E_ModSettings.save()
            end)
        end
        FS25_Enhanced.missionActive = false
        if FS25E_RestoreManager then safeCall("RestoreManager.earlyRestore", FS25E_RestoreManager.restoreAll) end

        if FS25E_Input ~= nil and FS25E_Input.unregister ~= nil then
            FS25E_Input.unregister()
        end
        if FS25E_LiveOverlay ~= nil and FS25E_LiveOverlay.reset ~= nil then
            FS25E_LiveOverlay.reset()
        end
        if FS25E_HudOverlay ~= nil and FS25E_HudOverlay.reset ~= nil then
            FS25E_HudOverlay.reset()
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
        if FS25E_TelemetryReader ~= nil and FS25E_TelemetryReader.reset ~= nil then
            FS25E_TelemetryReader.reset()
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

        if FS25E_ExperimentalCaps ~= nil and FS25E_ExperimentalCaps.reset ~= nil then
            FS25E_ExperimentalCaps.reset()
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
        if FS25E_Diagnostics ~= nil and FS25E_Diagnostics.reset ~= nil then
            FS25E_Diagnostics.reset()
        end

        if FS25E_RuntimeControls then FS25E_RuntimeControls.reset() end
        if FS25E_VisualProfiles then FS25E_VisualProfiles.reset() end
        if FS25E_CompatibilityManager and FS25E_CompatibilityManager.reset then FS25E_CompatibilityManager.reset() end
        if FS25E_ModuleRuntime then safeCall("ModuleRuntime.reset", FS25E_ModuleRuntime.reset) end
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
    if FS25E_ProbeSession then safeCall("ProbeSession.update", function() FS25E_ProbeSession.update(dt) end) end
    -- Menu rendering is not a representative sample of scene performance.
    -- The custom live overlay is drawn in the scene and does not set this flag.
    if g_gui and type(g_gui.getIsGuiVisible)=='function' then
        local ok,menuVisible=pcall(g_gui.getIsGuiVisible,g_gui)
        if ok and menuVisible then
            if FS25E_CalibrationManager and FS25E_CalibrationManager.isRunning() then
                FS25E_CalibrationManager.cancel('menu opened')
            end
            return
        end
    end

    safeCall("TelemetryReader.update", function()
        if FS25E_TelemetryReader ~= nil then
            FS25E_TelemetryReader.update(dt)
        end
    end)

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

    safeCall("ModuleRuntime.update", function() FS25E_ModuleRuntime.update(dt) end)
    -- Once per mission: which atmosphere/tone names the installed build has.
    if FS25E_ApiInventory and not FS25E_ApiInventory.done then
        safeCall("ApiInventory.log", function() FS25E_ApiInventory.log() end)
    end
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
            FS25E_HookManager.register(FSBaseMission, "delete", "prepended", function(self)
                onDeleteMap()
            end)
        end
    else
        FS25E_Debug.warning("Bootstrap", "FSBaseMission not available at register time (NO-OP until reload)")
    end
end

safeCall("bootstrap", function()
    if g_dedicatedServer~=nil then return end
    FS25E_Debug.info("Bootstrap", string.format(
        "FS25_Enhanced %s loading as %s dir=%s",
        FS25_Enhanced.VERSION,
        tostring(modName),
        tostring(modDirectory)
    ))
    if FS25E_Localization then FS25E_Localization.init(modDirectory) end
    if FS25E_ModuleRuntime then FS25E_ModuleRuntime.install() end
    -- The vanilla settings page and the game's saves must never see mod values.
    if FS25E_VanillaGuard then safeCall("VanillaGuard.install", FS25E_VanillaGuard.install) end
    registerMissionHooks()
    if FS25E_LiveOverlay ~= nil and FS25E_LiveOverlay.registerHooks ~= nil then
        FS25E_LiveOverlay.registerHooks()
    end
    if FS25E_HudOverlay ~= nil and FS25E_HudOverlay.registerHooks ~= nil then
        FS25E_HudOverlay.registerHooks()
    end
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
