-- FS25_Enhanced / Core/ConsoleCommands.lua
-- Optional manual test helpers via addConsoleCommand (GDN documented).
-- NEVER sets autoApply=true. Manual apply goes through Wave-1 Manager / Expert APIs.
-- Expert Soft-Apply default false; requires expertMode.

FS25E_ConsoleCommands = {}

local unpack = rawget(_G, "unpack") or table.unpack

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

function FS25E_ConsoleCommands.openSettings()
    if FS25E_GuiLoader ~= nil and FS25E_GuiLoader.showSettingsDialog ~= nil then
        local ok = FS25E_GuiLoader.showSettingsDialog()
        say(string.format("openSettings ok=%s", tostring(ok)))
    else
        say("GuiLoader/SettingsDialog missing")
    end
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

local function requireDiscoveredLightId(lightId, cmdLabel)
    if FS25E_LightDiscovery == nil or FS25E_LightDiscovery.getEntries == nil then
        return true
    end
    local found = false
    local entries = FS25E_LightDiscovery.getEntries()
    local n = 0
    local want = tostring(lightId)
    for _, e in pairs(entries) do
        n = n + 1
        if e ~= nil and e.node ~= nil and tostring(e.node) == want then
            found = true
            break
        end
    end
    if n > 0 and not found then
        say(string.format(
            "%s rejected: lightId=%s not in LightDiscovery (run fs25eLightsDump; use Dump ids only)",
            tostring(cmdLabel), tostring(lightId)
        ))
        return false
    end
    return true
end

local function tryReadGlobal(getterName, lightId)
    if FS25E_CapabilityApplier == nil or FS25E_CapabilityApplier.resolveGlobal == nil then
        return nil
    end
    local fn = FS25E_CapabilityApplier.resolveGlobal(getterName)
    if type(fn) ~= "function" then
        return nil
    end
    local ok, result = pcall(fn, lightId)
    if ok then
        return result
    end
    return nil
end

function FS25E_ConsoleCommands.applyLightPriority(lightIdStr, priorityStr)
    local lightId = tonumber(lightIdStr)
    local priority = tonumber(priorityStr)
    if lightId == nil or priority == nil then
        say("usage: fs25eApplyLightPriority <lightId> <priority>  (manual; lightId = node from fs25eLightsDump)")
        return
    end
    if FS25E_ShadowManager == nil or FS25E_ShadowManager.setLightShadowPriority == nil then
        say("ShadowManager.setLightShadowPriority missing")
        return
    end
    if not requireDiscoveredLightId(lightId, "applyLightPriority") then
        return
    end
    local ok, err = FS25E_ShadowManager.setLightShadowPriority(lightId, priority)
    say(string.format(
        "applyLightPriority lightId=%s priority=%s ok=%s err=%s (manual; softApply/autoApply untouched)",
        tostring(lightId), tostring(priority), tostring(ok), tostring(err)
    ))
end

--- Manual Soft-Shadow apply for one Dump lightId. Does NOT toggle Soft-Apply / autoApply.
--- size required; optional distance + bias.
function FS25E_ConsoleCommands.applyLightSoft(lightIdStr, sizeStr, distanceStr, biasStr)
    local lightId = tonumber(lightIdStr)
    local size = tonumber(sizeStr)
    if lightId == nil or size == nil then
        say("usage: fs25eApplyLightSoft <lightId> <size> [distance] [bias]  (manual; lightId from fs25eLightsDump; Soft-Apply/autoApply untouched)")
        return
    end
    if FS25E_ShadowManager == nil then
        say("ShadowManager missing")
        return
    end
    if not requireDiscoveredLightId(lightId, "applyLightSoft") then
        return
    end

    local beforeSize = tryReadGlobal("getLightSoftShadowSize", lightId)
    local beforeDist = tryReadGlobal("getLightSoftShadowDistance", lightId)
    local beforeBias = tryReadGlobal("getLightSoftShadowDepthBiasFactor", lightId)
    say(string.format(
        "applyLightSoft BEFORE lightId=%s size=%s distance=%s bias=%s",
        tostring(lightId), tostring(beforeSize), tostring(beforeDist), tostring(beforeBias)
    ))

    local okSize, errSize = FS25E_ShadowManager.setLightSoftShadowSize(lightId, size)
    say(string.format("applyLightSoft setSize value=%s ok=%s err=%s", tostring(size), tostring(okSize), tostring(errSize)))

    local distance = tonumber(distanceStr)
    local bias = tonumber(biasStr)
    local okDist, errDist, okBias, errBias = true, nil, true, nil
    if distanceStr ~= nil and distanceStr ~= "" then
        if distance == nil then
            say("applyLightSoft: optional distance must be a number")
            return
        end
        okDist, errDist = FS25E_ShadowManager.setLightSoftShadowDistance(lightId, distance)
        say(string.format("applyLightSoft setDistance value=%s ok=%s err=%s", tostring(distance), tostring(okDist), tostring(errDist)))
    end
    if biasStr ~= nil and biasStr ~= "" then
        if bias == nil then
            say("applyLightSoft: optional bias must be a number")
            return
        end
        okBias, errBias = FS25E_ShadowManager.setLightSoftShadowDepthBiasFactor(lightId, bias)
        say(string.format("applyLightSoft setBias value=%s ok=%s err=%s", tostring(bias), tostring(okBias), tostring(errBias)))
    end

    local afterSize = tryReadGlobal("getLightSoftShadowSize", lightId)
    local afterDist = tryReadGlobal("getLightSoftShadowDistance", lightId)
    local afterBias = tryReadGlobal("getLightSoftShadowDepthBiasFactor", lightId)
    say(string.format(
        "applyLightSoft AFTER/readback lightId=%s size=%s distance=%s bias=%s (expect size=%s; Soft-Apply/autoApply untouched; use fs25eRestore)",
        tostring(lightId), tostring(afterSize), tostring(afterDist), tostring(afterBias), tostring(size)
    ))
end

--- Manual merge of Dump lightIds (primary first). Does NOT enable Soft-Apply / autoApply.
function FS25E_ConsoleCommands.mergeLights(idAStr, idBStr, ...)
    if idAStr == nil or idBStr == nil or idAStr == "" or idBStr == "" then
        say("usage: fs25eMergeLights <lightIdA> <lightIdB> [more…]  (primary first; ids from fs25eLightsDump)")
        return
    end
    if FS25E_ShadowManager == nil or FS25E_ShadowManager.mergeLightShadows == nil then
        say("ShadowManager.mergeLightShadows missing")
        return
    end

    local ids = {}
    local raw = { idAStr, idBStr, ... }
    for i = 1, #raw do
        local s = raw[i]
        if s ~= nil and s ~= "" then
            local id = tonumber(s)
            if id == nil then
                say(string.format("mergeLights: invalid lightId arg[%d]=%s", i, tostring(s)))
                return
            end
            ids[#ids + 1] = id
        end
    end
    if #ids < 2 then
        say("usage: fs25eMergeLights <lightIdA> <lightIdB> [more…]")
        return
    end
    for i = 1, #ids do
        if not requireDiscoveredLightId(ids[i], "mergeLights") then
            return
        end
    end

    for i = 1, #ids do
        local merged = FS25E_ShadowManager.hasMergedShadow(ids[i])
        say(string.format("mergeLights BEFORE lightId=%s hasMergedShadow=%s", tostring(ids[i]), tostring(merged)))
    end

    local primary = ids[1]
    local others = {}
    for i = 2, #ids do
        others[#others + 1] = ids[i]
    end
    local ok, err = FS25E_ShadowManager.mergeLightShadows(primary, unpack(others))
    say(string.format(
        "mergeLights primary=%s others=%d ok=%s err=%s (manual; Soft-Apply/autoApply untouched)",
        tostring(primary), #others, tostring(ok), tostring(err)
    ))

    for i = 1, #ids do
        local merged = FS25E_ShadowManager.hasMergedShadow(ids[i])
        say(string.format(
            "mergeLights AFTER lightId=%s hasMergedShadow=%s (expect true when engine merge succeeded)",
            tostring(ids[i]), tostring(merged)
        ))
    end
end

function FS25E_ConsoleCommands.splitLight(lightIdStr)
    local lightId = tonumber(lightIdStr)
    if lightId == nil then
        say("usage: fs25eSplitLight <lightId>  (manual split; lightId from dump/merge)")
        return
    end
    if FS25E_ShadowManager == nil or FS25E_ShadowManager.splitLightShadow == nil then
        say("ShadowManager.splitLightShadow missing")
        return
    end
    local before = FS25E_ShadowManager.hasMergedShadow(lightId)
    say(string.format("splitLight BEFORE lightId=%s hasMergedShadow=%s", tostring(lightId), tostring(before)))
    local ok, err = FS25E_ShadowManager.splitLightShadow(lightId)
    local after = FS25E_ShadowManager.hasMergedShadow(lightId)
    say(string.format(
        "splitLight lightId=%s ok=%s err=%s AFTER hasMergedShadow=%s (expect false / pre-merge; Soft-Apply/autoApply untouched)",
        tostring(lightId), tostring(ok), tostring(err), tostring(after)
    ))
end

function FS25E_ConsoleCommands.dumpMerges()
    if FS25E_ShadowManager == nil then
        say("ShadowManager missing")
        return
    end
    local tracked = nil
    if FS25E_ShadowManager.getTrackedMerges ~= nil then
        tracked = FS25E_ShadowManager.getTrackedMerges()
    elseif FS25E_ShadowManager.getMergedLights ~= nil then
        tracked = FS25E_ShadowManager.getMergedLights()
    end
    if tracked == nil then
        say("dumpMerges: no tracked merge table")
        return
    end
    local n = 0
    local ids = {}
    for lightId in pairs(tracked) do
        n = n + 1
        ids[#ids + 1] = lightId
    end
    table.sort(ids, function(a, b)
        return tostring(a) < tostring(b)
    end)
    for i = 1, #ids do
        local lightId = ids[i]
        local engineMerged = FS25E_ShadowManager.hasMergedShadow(lightId)
        say(string.format(
            "dumpMerges tracked lightId=%s hasMergedShadow=%s",
            tostring(lightId), tostring(engineMerged)
        ))
    end
    say(string.format("dumpMerges done count=%d (Soft-Apply/autoApply untouched)", n))
end

--- DANGER: enables Soft-Apply (CONFIRMED ShadowManager per-light APIs). Default OFF.
--- Does NOT enable GraphicsGovernor.autoApply.
function FS25E_ConsoleCommands.setSoftApply(flag)
    if FS25E_LightDiscovery == nil or FS25E_LightDiscovery.setSoftApplyEnabled == nil then
        say("LightDiscovery missing")
        return
    end
    if flag ~= "0" and flag ~= "1" then
        say("usage: fs25eSoftApply 0|1  (DANGER: 1 enables Soft-Apply of CONFIRMED per-light APIs; default 0; does NOT enable autoApply)")
        return
    end
    local on = flag == "1"
    FS25E_LightDiscovery.setSoftApplyEnabled(on)
    say(string.format(
        "softApply=%s (DANGER when on: may mutate per-light shadow caps; autoApply stays false; use fs25eRestore / owner delete to restore)",
        tostring(on)
    ))
end


--- Expert mode master gate (does NOT enable Soft-Apply / autoApply).
function FS25E_ConsoleCommands.setExpertMode(flag)
    if FS25E_SettingsSchema == nil then
        say("SettingsSchema missing")
        return
    end
    if flag ~= "0" and flag ~= "1" then
        say("usage: fs25eExpertMode 0|1  (master gate for EXPERIMENTAL/GATED/ASSET; Soft-Apply stays separate; autoApply untouched)")
        return
    end
    local on = flag == "1"
    FS25E_SettingsSchema.set("expertMode", on)
    say(string.format("expertMode=%s (EXPERIMENTAL/GATED/ASSET require this; Soft-Apply/autoApply untouched)", tostring(on)))
end

--- Expert Soft-Apply flag. When 1 AND expertMode on, runs softApplyEnabledCaps once.
function FS25E_ConsoleCommands.setExpertSoftApply(flag)
    if FS25E_ExperimentalCaps == nil then
        say("ExperimentalCaps missing")
        return
    end
    if flag ~= "0" and flag ~= "1" then
        say("usage: fs25eExpertSoftApply 0|1  (DANGER when 1+expertMode: applies enabled expert caps; default 0; never enables autoApply)")
        return
    end
    local on = flag == "1"
    FS25E_ExperimentalCaps.setSoftApplyEnabled(on)
    if FS25E_SettingsSchema ~= nil then
        -- Schema set triggers softApply once when expertMode already on
        FS25E_SettingsSchema.set("expertSoftApply", on)
    elseif on then
        local summary = FS25E_ExperimentalCaps.softApplyEnabledCaps()
        say(string.format(
            "expertSoftApply=true attempted=%s applied=%s skipped=%s",
            tostring(summary and summary.attempted),
            tostring(summary and summary.applied),
            tostring(summary and summary.skipped)
        ))
        return
    end
    say(string.format("expertSoftApply=%s (requires expertMode=true and enabled expert toggles; autoApply untouched)", tostring(on)))
end

function FS25E_ConsoleCommands.applyFastShadowUpdate(flag)
    if FS25E_ExperimentalCaps == nil then
        say("ExperimentalCaps missing")
        return
    end
    local on = flag == nil or flag == "" or flag == "1" or flag == "true"
    local ok, err = FS25E_ExperimentalCaps.applyFastShadowUpdate(on)
    say(string.format("applyFastShadowUpdate value=%s ok=%s err=%s", tostring(on), tostring(ok), tostring(err)))
end

function FS25E_ConsoleCommands.applyRainShallow(flag)
    if FS25E_ExperimentalCaps == nil then
        say("ExperimentalCaps missing")
        return
    end
    local on = flag == nil or flag == "" or flag == "1" or flag == "true"
    local ok, err = FS25E_ExperimentalCaps.applyRainShallowWater(on)
    say(string.format("applyRainShallow value=%s ok=%s err=%s", tostring(on), tostring(ok), tostring(err)))
end

function FS25E_ConsoleCommands.applyGated(capId, valueStr)
    if FS25E_ExperimentalCaps == nil then
        say("ExperimentalCaps missing")
        return
    end
    if capId == nil or capId == "" or valueStr == nil then
        say("usage: fs25eApplyGated <ssr-quality|atmosphere-quality|drs-quality> <value>")
        return
    end
    local v = tonumber(valueStr)
    if v == nil then
        say("gated value must be number")
        return
    end
    local ok, err
    if capId == "ssr-quality" then
        ok, err = FS25E_ExperimentalCaps.applySsrQuality(v)
    elseif capId == "atmosphere-quality" then
        ok, err = FS25E_ExperimentalCaps.applyAtmosphereQuality(v)
    elseif capId == "drs-quality" then
        ok, err = FS25E_ExperimentalCaps.applyDrsQuality(v)
    else
        say("unknown gated id (ssr-quality|atmosphere-quality|drs-quality)")
        return
    end
    say(string.format("applyGated id=%s value=%s ok=%s err=%s", tostring(capId), tostring(v), tostring(ok), tostring(err)))
end

function FS25E_ConsoleCommands.applyIes(lightIdStr, iesPath)
    if FS25E_ExperimentalCaps == nil then
        say("ExperimentalCaps missing")
        return
    end
    local lightId = tonumber(lightIdStr)
    if lightId == nil or iesPath == nil or iesPath == "" then
        say("usage: fs25eApplyIes <lightId> <path.ies>  (requires expertMode; never blind)")
        return
    end
    local ok, err = FS25E_ExperimentalCaps.applyLightIesProfile(lightId, iesPath)
    say(string.format("applyIes lightId=%s path=%s ok=%s err=%s", tostring(lightId), tostring(iesPath), tostring(ok), tostring(err)))
end

function FS25E_ConsoleCommands.capStatus()
    if FS25E_Diagnostics ~= nil and FS25E_Diagnostics.dumpCapStatus ~= nil then
        FS25E_Diagnostics.dumpCapStatus(say)
    else
        say("Diagnostics missing")
    end
end

function FS25E_ConsoleCommands.dumpDiagLog()
    if FS25E_Diagnostics ~= nil and FS25E_Diagnostics.dumpRing ~= nil then
        FS25E_Diagnostics.dumpRing(say)
    else
        say("Diagnostics missing")
    end
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


function FS25E_ConsoleCommands.setAutoApplyFlag(flag)
    local on = tostring(flag or "") == "1" or tostring(flag or ""):lower() == "true"
    if FS25E_SettingsAPI ~= nil then
        FS25E_SettingsAPI.setAutoApply(on)
    elseif FS25E_GraphicsGovernor ~= nil then
        FS25E_GraphicsGovernor.setAutoApply(on)
    end
    say("autoApply=" .. tostring(on) .. " (DANGER when on; Soft-Apply untouched; defaults false on load)")
end

function FS25E_ConsoleCommands.setExpertFlag(flag)
    local on = tostring(flag or "") == "1" or tostring(flag or ""):lower() == "true"
    if FS25E_SettingsAPI ~= nil then
        FS25E_SettingsAPI.setExpertMode(on)
    elseif FS25E_CapabilityRegistry ~= nil then
        FS25E_CapabilityRegistry.setExpertMode(on)
    end
    say("expertMode=" .. tostring(on) .. " (EXPERIMENTAL/GATED only when true; default false)")
end


function FS25E_ConsoleCommands.liveOverlay(flag)
    if FS25E_LiveOverlay == nil then
        say("LiveOverlay module missing")
        return
    end
    if flag == nil or flag == "" then
        FS25E_LiveOverlay.toggle(nil)
        say("liveOverlay toggled visible=" .. tostring(FS25E_LiveOverlay.isVisible and FS25E_LiveOverlay.isVisible()))
        return
    end
    local on = tostring(flag) == "1" or tostring(flag):lower() == "on" or tostring(flag):lower() == "true"
    if on then
        if FS25E_SettingsAPI ~= nil and FS25E_SettingsAPI.set ~= nil then
            FS25E_SettingsAPI.set("liveTuningEnabled", true)
        end
        FS25E_LiveOverlay.toggle(true)
    else
        FS25E_LiveOverlay.toggle(false)
    end
    say("liveOverlay visible=" .. tostring(FS25E_LiveOverlay.isVisible and FS25E_LiveOverlay.isVisible()))
end

function FS25E_ConsoleCommands.closeSettings()
    local closed = false
    if g_gui ~= nil then
        if g_gui.closeDialogByName ~= nil then
            local ok = pcall(function()
                g_gui:closeDialogByName("FS25E_SettingsDialog")
            end)
            closed = closed or ok
        end
        -- Fallback: blank GUI / changeScreen via controller instance if exposed
        if g_gui.guis ~= nil and g_gui.guis["FS25E_SettingsDialog"] ~= nil then
            local dlg = g_gui.guis["FS25E_SettingsDialog"]
            if dlg ~= nil and dlg.target ~= nil and dlg.target.close ~= nil then
                local ok = pcall(function() dlg.target:close() end)
                closed = closed or ok
            elseif dlg ~= nil and dlg.close ~= nil then
                local ok = pcall(function() dlg:close() end)
                closed = closed or ok
            end
        end
        if not closed and g_gui.showGui ~= nil then
            pcall(function() g_gui:showGui("") end)
            closed = true
        end
    end
    if g_inputBinding ~= nil and g_inputBinding.setShowMouseCursor ~= nil then
        pcall(function() g_inputBinding:setShowMouseCursor(false) end)
    end
    say(string.format("closeSettings closed=%s", tostring(closed)))
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
    if tryAdd("fs25eOpenSettings", "FS25_Enhanced: open Gen-1 settings dialog", "openSettings") then n = n + 1 end
    if tryAdd("fs25eCloseSettings", "FS25_Enhanced: close settings dialog (unstick)", "closeSettings") then n = n + 1 end
    if tryAdd("fs25eApplyLightPriority", "FS25_Enhanced: manual setLightShadowPriority (lightId from fs25eLightsDump)", "applyLightPriority") then n = n + 1 end
    if tryAdd("fs25eSoftApply", "FS25_Enhanced: Soft-Apply 0|1 (DANGER; default 0; never enables autoApply)", "setSoftApply") then n = n + 1 end
    if tryAdd("fs25eAutoApply", "FS25_Enhanced: autoApply 0|1 (DANGER; default 0)", "setAutoApplyFlag") then n = n + 1 end
    if tryAdd("fs25eExpert", "FS25_Enhanced: expertMode 0|1 via SettingsAPI (default 0)", "setExpertFlag") then n = n + 1 end
    if tryAdd("fs25eApplyLightSoft", "FS25_Enhanced: manual Soft-Shadow size/[distance]/[bias] (lightId from Dump; Soft-Apply untouched)", "applyLightSoft") then n = n + 1 end
    if tryAdd("fs25eMergeLights", "FS25_Enhanced: manual mergeLightShadows (primary first; Dump lightIds)", "mergeLights") then n = n + 1 end
    if tryAdd("fs25eSplitLight", "FS25_Enhanced: manual splitLightShadow", "splitLight") then n = n + 1 end
    if tryAdd("fs25eDumpMerges", "FS25_Enhanced: dump ShadowManager tracked merges", "dumpMerges") then n = n + 1 end
    if tryAdd("fs25eCapStatus", "FS25_Enhanced: dump capability status + lastResult/lastError", "capStatus") then n = n + 1 end
    if tryAdd("fs25eDumpDiagLog", "FS25_Enhanced: dump diagnostics ring log", "dumpDiagLog") then n = n + 1 end
    if tryAdd("fs25eExpertMode", "FS25_Enhanced: expertMode 0|1 (gate EXPERIMENTAL/GATED/ASSET; Soft-Apply separate)", "setExpertMode") then n = n + 1 end
    if tryAdd("fs25eExpertSoftApply", "FS25_Enhanced: expert Soft-Apply 0|1 (DANGER; requires expertMode; never autoApply)", "setExpertSoftApply") then n = n + 1 end
    if tryAdd("fs25eApplyFastShadow", "FS25_Enhanced: manual applyFastShadowUpdate (requires expertMode)", "applyFastShadowUpdate") then n = n + 1 end
    if tryAdd("fs25eApplyRainShallow", "FS25_Enhanced: manual applyRainShallowWater (requires expertMode)", "applyRainShallow") then n = n + 1 end
    if tryAdd("fs25eApplyGated", "FS25_Enhanced: manual gated quality apply (ssr|atmosphere|drs)", "applyGated") then n = n + 1 end
    if tryAdd("fs25eApplyIes", "FS25_Enhanced: manual IES profile apply (requires expertMode)", "applyIes") then n = n + 1 end
    if tryAdd("fs25eLiveOverlay", "FS25_Enhanced: toggle Expert Live-Overlay (1/0; requires expertMode+liveTuning)", "liveOverlay") then n = n + 1 end
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
        "fs25eApplyLightPriority",
        "fs25eAutoApply",
        "fs25eExpert",
        "fs25eSoftApply",
        "fs25eApplyLightSoft",
        "fs25eMergeLights",
        "fs25eSplitLight",
        "fs25eDumpMerges",
        "fs25eOpenSettings",
        "fs25eCloseSettings",
        "fs25eLiveOverlay",
        "fs25eCapStatus",
        "fs25eDumpDiagLog",
        "fs25eExpertMode",
        "fs25eExpertSoftApply",
        "fs25eApplyFastShadow",
        "fs25eApplyRainShallow",
        "fs25eApplyGated",
        "fs25eApplyIes",
    }
    for i = 1, #names do
        pcall(removeConsoleCommand, names[i])
    end
    registered = false
    FS25E_Debug.info("Console", "console commands removed")
end
