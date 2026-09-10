-- FS25_Enhanced / UI/FS25E_LiveOverlay.lua
-- Expert Live-Overlay: drawn over the world (no fullscreen dialog).
-- Caps primary source: FS25E_SettingsAPI.liveListCaps() (+ ROW_META for ranges/labels).
-- Apply path: FS25E_SettingsAPI.live* only (no engine setters / no direct Applier).
-- Status: Diagnostics.getSnapshot on open + Registry onApply/onReject/onSkip per row.
-- Cost/warn: getCapCost / liveListCaps fields. Custom bars — NEVER GuiSlider.
-- Hover-help: Schema tooltip (settingId/capId) under selection; cost notes fallback.
-- HUD: FS25E_HudOverlay telemetry in header via getHudTelemetry().

FS25E_LiveOverlay = {}

local LOG = "LiveOverlay"

local visible = false
local hooksRegistered = false
local listenersInstalled = false
local selectedIndex = 1
local scrollOffset = 0
local dragRow = nil
local lastNotifyAt = 0
local cachedCapList = nil
local cachedCapListAt = 0

-- Layout (normalized 0..1 screen space)
local PANEL = {
    x = 0.58,
    y = 0.08,
    w = 0.40,
    h = 0.84,
    pad = 0.012,
    rowH = 0.036,
    titleSize = 0.017,
    textSize = 0.013,
    smallSize = 0.011,
    headerHudH = 0.072,
}

--- Preferred Wave-1 / Expert ordering + widget metadata (ranges).
--- Primary cap list still comes from liveListCaps(); meta fills min/max/step/kind/label.
local ROW_META = {
    ["view-distance-coeff"] = { id = "viewDistance", settingId = "viewDistance", labelKey = "FS25E_LIVE_OVERLAY_VIEW_DISTANCE", min = 0.50, max = 1.50, step = 0.01, kind = "float", applyKind = "wave1", default = 1.00, order = 10 },
    ["lod-distance-coeff"] = { id = "lodDistance", settingId = "lodDistance", labelKey = "FS25E_LIVE_OVERLAY_LOD_DISTANCE", min = 0.50, max = 1.50, step = 0.01, kind = "float", applyKind = "wave1", default = 1.00, order = 20 },
    ["foliage-view-distance-coeff"] = { id = "foliageViewDistance", settingId = "foliageViewDistance", labelKey = "FS25E_LIVE_OVERLAY_FOLIAGE_VIEW", min = 0.50, max = 1.50, step = 0.01, kind = "float", applyKind = "wave1", default = 1.00, order = 30 },
    ["foliage-lod-distance-coeff"] = { id = "foliageLodDistance", settingId = "foliageLodDistance", labelKey = "FS25E_LIVE_OVERLAY_FOLIAGE_LOD", min = 0.50, max = 1.50, step = 0.01, kind = "float", applyKind = "wave1", default = 1.00, order = 40 },
    ["terrain-lod-distance-coeff"] = { id = "terrainLodDistance", settingId = "terrainLodDistance", labelKey = "FS25E_LIVE_OVERLAY_TERRAIN_LOD", min = 0.50, max = 1.50, step = 0.01, kind = "float", applyKind = "wave1", default = 1.00, order = 50 },
    ["max-num-shadow-lights"] = { id = "maxShadowLights", settingId = "maxShadowLights", labelKey = "FS25E_LIVE_OVERLAY_MAX_SHADOW_LIGHTS", min = 1, max = 8, step = 1, kind = "int", applyKind = "wave1", default = 4, order = 60 },
    ["allow-foliage-shadows"] = { id = "allowFoliageShadows", settingId = "foliageShadows", labelKey = "FS25E_LIVE_OVERLAY_FOLIAGE_SHADOWS", min = 0, max = 1, step = 1, kind = "bool", applyKind = "wave1", default = 1, order = 70 },
    ["shadow-quality"] = { id = "shadowQuality", settingId = "shadowQuality", labelKey = "FS25E_LIVE_OVERLAY_SHADOW_QUALITY", min = 0, max = 3, step = 1, kind = "int", applyKind = "wave1", default = 1, order = 80 },
    ["shadow-distance-quality"] = { id = "shadowDistanceQuality", settingId = "shadowDistance", labelKey = "FS25E_LIVE_OVERLAY_SHADOW_DIST_Q", min = 0, max = 3, step = 1, kind = "int", applyKind = "wave1", default = 1, order = 90 },
    ["shadow-filter-quality"] = { id = "shadowFilterQuality", settingId = "softShadows", labelKey = "FS25E_LIVE_OVERLAY_SHADOW_FILTER", min = 0, max = 3, step = 1, kind = "int", applyKind = "wave1", default = 1, order = 100 },
    -- Expert Soft-Apply path
    ["rain-amount-mult"] = { id = "rainAmountMult", settingId = "rainAmountMult", labelKey = "FS25E_LIVE_OVERLAY_RAIN_AMOUNT", min = 0.00, max = 2.00, step = 0.01, kind = "float", applyKind = "expert", default = 1.00, order = 200 },
    ["ssr-quality"] = { id = "ssrQuality", settingId = "ssrQuality", labelKey = "FS25E_LIVE_OVERLAY_SSR_QUALITY", min = 0, max = 3, step = 1, kind = "int", applyKind = "expert", default = 1, order = 210 },
    ["atmosphere-quality"] = { id = "atmosphereQuality", settingId = "atmosphereQuality", labelKey = "FS25E_LIVE_OVERLAY_ATMOSPHERE_QUALITY", min = 0, max = 3, step = 1, kind = "int", applyKind = "expert", default = 1, order = 220 },
    ["drs-quality"] = { id = "drsQuality", settingId = "drsQuality", labelKey = "FS25E_LIVE_OVERLAY_DRS_QUALITY", min = 0, max = 3, step = 1, kind = "int", applyKind = "expert", default = 1, order = 230 },
    ["shadow-focus-box"] = { id = "shadowFocus", settingId = "shadowFocus", labelKey = "FS25E_LIVE_OVERLAY_SHADOW_FOCUS", min = 0, max = 1, step = 1, kind = "bool", applyKind = "expert", default = 0, order = 240 },
    ["fast-shadow-update"] = { id = "fastShadowUpdate", settingId = "fastShadowUpdate", labelKey = "FS25E_LIVE_OVERLAY_FAST_SHADOW", min = 0, max = 1, step = 1, kind = "bool", applyKind = "expert", default = 0, order = 250 },
    ["rain-shallow-water-simulation"] = { id = "rainShallowWater", settingId = "rainShallowWater", labelKey = "FS25E_LIVE_OVERLAY_RAIN_SHALLOW", min = 0, max = 1, step = 1, kind = "bool", applyKind = "expert", default = 0, order = 260 },
}

-- Caps that need multi-arg / lightId / path — not fine-tunable as single float in Gen-1 overlay
local SKIP_IDS = {
    ["rain-spawn-box-parameters"] = true,
    ["rain-turbulence-parameters"] = true,
    ["rain-forward-direction"] = true,
    ["has-merged-shadow"] = true,
    ["split-light-shadow"] = true,
    ["merge-light-shadows"] = true,
    ["supports-ssr-quality"] = true,
    ["supports-atmosphere-quality"] = true,
    ["supports-drs-quality"] = true,
    ["light-ies-profile"] = true,
    ["light-ies-cone-angle"] = true,
    ["foliage-bending-create"] = true,
}

-- Runtime row state keyed by capabilityId
local rows = {} -- { capabilityId -> { def, value, lastResult, lastError, sessionOnly, cost, warn, notes } }

local function dbg(msg)
    if FS25E_Debug ~= nil then
        FS25E_Debug.info(LOG, tostring(msg))
    end
end

local function dbgWarn(msg)
    if FS25E_Debug ~= nil then
        FS25E_Debug.warning(LOG, tostring(msg))
    end
end

local function t(key, fallback)
    if g_i18n ~= nil and g_i18n.getText ~= nil then
        local ok, text = pcall(function()
            return g_i18n:getText(key)
        end)
        if ok and text ~= nil and text ~= "" and text ~= key then
            return text
        end
    end
    if FS25E_SettingsController ~= nil and FS25E_SettingsController.t ~= nil then
        return FS25E_SettingsController.t(key, fallback)
    end
    return fallback or key
end

local function notify(text)
    local now = (g_time ~= nil and g_time) or (os.clock() * 1000)
    if now - lastNotifyAt < 400 then
        return
    end
    lastNotifyAt = now
    dbg(text)
    if g_currentMission ~= nil and g_currentMission.addIngameNotification ~= nil then
        pcall(function()
            g_currentMission:addIngameNotification(FSBaseMission.INGAME_NOTIFICATION_INFO, text)
        end)
    end
end

local function settingsGet(key)
    if FS25E_ModSettings ~= nil and FS25E_ModSettings.get ~= nil then
        return FS25E_ModSettings.get(key)
    end
    if FS25E_SettingsAPI ~= nil and FS25E_SettingsAPI.get ~= nil then
        return FS25E_SettingsAPI.get(key)
    end
    return nil
end

local function settingsSet(key, value)
    if FS25E_SettingsAPI ~= nil and FS25E_SettingsAPI.set ~= nil then
        return FS25E_SettingsAPI.set(key, value)
    end
    if FS25E_ModSettings ~= nil and FS25E_ModSettings.set ~= nil then
        return FS25E_ModSettings.set(key, value)
    end
    return false
end

function FS25E_LiveOverlay.canShow()
    return settingsGet("expertMode") == true and settingsGet("liveTuningEnabled") == true
end

local function isExpertSoftApplyOn()
    if FS25E_ExperimentalCaps ~= nil and FS25E_ExperimentalCaps.isSoftApplyEnabled ~= nil then
        if FS25E_ExperimentalCaps.isSoftApplyEnabled() == true then
            return true
        end
    end
    return settingsGet("expertSoftApply") == true
end

local function clamp(v, minV, maxV, step)
    local n = tonumber(v)
    if n == nil then
        return minV
    end
    if n < minV then n = minV end
    if n > maxV then n = maxV end
    if step ~= nil and step > 0 then
        local steps = math.floor((n - minV) / step + 0.5)
        n = minV + steps * step
        if n < minV then n = minV end
        if n > maxV then n = maxV end
        if step < 1 then
            n = math.floor(n * 100 + 0.5) / 100
        else
            n = math.floor(n + 0.5)
        end
    end
    return n
end

local function formatValue(def, value)
    if def.kind == "bool" then
        return (tonumber(value) or 0) >= 0.5 and "ON" or "OFF"
    end
    if def.kind == "int" or (def.step ~= nil and def.step >= 1) then
        return string.format("%d", math.floor((tonumber(value) or 0) + 0.5))
    end
    return string.format("%.2f", tonumber(value) or 0)
end

local function barText(def, value)
    local n = tonumber(value) or def.min
    local t01 = 0
    if def.max > def.min then
        t01 = (n - def.min) / (def.max - def.min)
    end
    if t01 < 0 then t01 = 0 end
    if t01 > 1 then t01 = 1 end
    local width = 14
    local filled = math.floor(t01 * width + 0.5)
    local s = "["
    for i = 1, width do
        if i <= filled then
            s = s .. "█"
        else
            s = s .. "░"
        end
    end
    return s .. "]"
end

local function inferKind(capId, status)
    local id = tostring(capId)
    if id:find("quality", 1, true) or id:find("max%-num") or id:find("max%-bounces") then
        return "int", 0, 3, 1, 1
    end
    if id:find("shadow%-focus") or id:find("fast%-shadow") or id:find("shallow%-water")
        or id:find("allow%-") or id:find("behind%-camera") then
        return "bool", 0, 1, 1, 0
    end
    if id:find("coeff", 1, true) or id:find("mult", 1, true) or id:find("multiplier", 1, true) then
        return "float", 0.00, 2.00, 0.01, 1.00
    end
    -- default float fine-tune
    local _ = status
    return "float", 0.00, 2.00, 0.01, 1.00
end

local function classifyApplyKind(capId, status, meta)
    if meta ~= nil and meta.applyKind ~= nil then
        return meta.applyKind
    end
    local st = tostring(status or "")
    if st == "EXPERIMENTAL" or st == "GATED" or st == "ASSET_DEPENDENT" then
        return "expert"
    end
    if tostring(capId):find("^rain%-") then
        return "expert"
    end
    return "wave1"
end

local function idToLabel(capId)
    return tostring(capId):gsub("%-", " ")
end

local function camelFromCap(capId)
    local parts = {}
    for part in string.gmatch(tostring(capId), "[^%-]+") do
        if #parts == 0 then
            parts[#parts + 1] = part
        else
            parts[#parts + 1] = part:sub(1, 1):upper() .. part:sub(2)
        end
    end
    return table.concat(parts)
end

--- Build def from liveListCaps entry + ROW_META.
local function buildDefFromCap(cap)
    local capId = cap.id
    local meta = ROW_META[capId]
    local kind, minV, maxV, step, default
    local labelKey, settingId, rowId, order
    if meta ~= nil then
        kind, minV, maxV, step, default = meta.kind, meta.min, meta.max, meta.step, meta.default
        labelKey, settingId, rowId, order = meta.labelKey, meta.settingId, meta.id, meta.order
    else
        kind, minV, maxV, step, default = inferKind(capId, cap.status)
        rowId = camelFromCap(capId)
        settingId = rowId
        labelKey = nil
        order = 500
    end
    local applyKind = classifyApplyKind(capId, cap.status, meta)
    return {
        id = rowId,
        settingId = settingId,
        capabilityId = capId,
        labelKey = labelKey,
        labelFallback = idToLabel(capId),
        min = minV,
        max = maxV,
        step = step,
        kind = kind,
        applyKind = applyKind,
        default = default,
        order = order or 500,
        status = cap.status,
        allowsApply = cap.allowsApply == true,
        cost = cap.cost,
        warn = cap.warn == true,
        scope = cap.scope,
        setter = cap.setter,
    }
end

local function shouldIncludeCap(cap, expertMode)
    if cap == nil or cap.id == nil then
        return false
    end
    if SKIP_IDS[cap.id] then
        return false
    end
    local setter = tostring(cap.setter or "")
    if setter == "" or setter == "NONE" or setter == "nil" then
        return false
    end
    local scope = tostring(cap.scope or "global")
    if scope ~= "global" then
        return false -- Gen-1: no per-light / scene fine-tune without lightId UI
    end
    local st = tostring(cap.status or "")
    if st == "REJECTED" or st == "UNSUPPORTED" then
        return false
    end
    -- Filter by allowsApply / expertMode
    if cap.allowsApply == true then
        return true
    end
    -- Expert mode: still list EXPERIMENTAL/GATED even if allowsApply momentarily false
    if expertMode then
        if st == "EXPERIMENTAL" or st == "GATED" or st == "ASSET_DEPENDENT" or st == "CONFIRMED" or st == "APPLIED" then
            return true
        end
    end
    return false
end

local function fetchLiveListCaps()
    local now = (g_time ~= nil and g_time) or (os.clock() * 1000)
    if cachedCapList ~= nil and (now - cachedCapListAt) < 1500 then
        return cachedCapList
    end
    local list = {}
    if FS25E_SettingsAPI ~= nil and FS25E_SettingsAPI.liveListCaps ~= nil then
        local ok, caps = pcall(FS25E_SettingsAPI.liveListCaps)
        if ok and type(caps) == "table" then
            list = caps
        end
    end
    -- Fallback: hardcoded Wave-1/Expert meta only if API empty
    if #list == 0 then
        for capId, meta in pairs(ROW_META) do
            list[#list + 1] = {
                id = capId,
                status = meta.applyKind == "expert" and "EXPERIMENTAL" or "CONFIRMED",
                cost = "med",
                warn = false,
                allowsApply = true,
                scope = "global",
                setter = "fallback",
            }
        end
    end
    cachedCapList = list
    cachedCapListAt = now
    return list
end

local function truncateHelp(s, maxLen)
    s = tostring(s or "")
    maxLen = maxLen or 120
    if #s <= maxLen then
        return s
    end
    return string.sub(s, 1, maxLen - 1) .. "…"
end

--- Prefer Schema tooltip (settingId / capId); else cost notes / lastError.
local function resolveRowHelp(row)
    if row == nil or row.def == nil then
        return ""
    end
    local def = row.def
    local tip = ""
    if FS25E_SettingsController ~= nil and FS25E_SettingsController.getHelpForSettingOrCap ~= nil then
        tip = FS25E_SettingsController.getHelpForSettingOrCap(def.settingId, def.capabilityId) or ""
    elseif FS25E_SettingsController ~= nil and FS25E_SettingsController.getTooltipText ~= nil and def.settingId ~= nil then
        tip = FS25E_SettingsController.getTooltipText(def.settingId) or ""
    end
    if tip == nil or tip == "" then
        tip = def.notes or ""
    end
    if (tip == nil or tip == "") and row.lastError ~= nil and row.lastError ~= "" then
        tip = tostring(row.lastError)
    end
    return tip or ""
end

local function enrichCost(def)
    if FS25E_SettingsAPI ~= nil and FS25E_SettingsAPI.getCapCost ~= nil then
        local ok, c = pcall(FS25E_SettingsAPI.getCapCost, def.capabilityId)
        if ok and type(c) == "table" then
            if c.cost ~= nil then def.cost = c.cost end
            if c.warn ~= nil then def.warn = c.warn == true end
            if c.notes ~= nil then def.notes = c.notes end
        end
    end
end

local function rebuildDefs()
    local expert = settingsGet("expertMode") == true
    local caps = fetchLiveListCaps()
    local defs = {}
    local seen = {}
    for i = 1, #caps do
        local cap = caps[i]
        if shouldIncludeCap(cap, expert) and not seen[cap.id] then
            seen[cap.id] = true
            local def = buildDefFromCap(cap)
            enrichCost(def)
            defs[#defs + 1] = def
        end
    end
    table.sort(defs, function(a, b)
        if a.order ~= b.order then
            return a.order < b.order
        end
        return tostring(a.capabilityId) < tostring(b.capabilityId)
    end)
    return defs
end

local function ensureRows()
    local defs = rebuildDefs()
    local keep = {}
    for i = 1, #defs do
        local def = defs[i]
        keep[def.capabilityId] = true
        local row = rows[def.capabilityId]
        if row == nil then
            rows[def.capabilityId] = {
                def = def,
                value = def.default,
                lastResult = nil,
                lastError = nil,
                sessionOnly = true,
            }
        else
            -- refresh def (cost/warn/allowsApply may change)
            local prev = row.value
            row.def = def
            if prev == nil then
                row.value = def.default
            end
        end
    end
    -- drop stale
    for id in pairs(rows) do
        if not keep[id] then
            rows[id] = nil
        end
    end
    return defs
end

local function refreshRowStatus(capabilityId, payload)
    ensureRows()
    local row = rows[capabilityId]
    if row == nil then
        return
    end
    if type(payload) == "table" then
        row.lastResult = payload.status or row.lastResult
        if payload.error ~= nil then
            row.lastError = tostring(payload.error)
        end
    end
    if FS25E_Diagnostics ~= nil and FS25E_Diagnostics.getStatusForSetting ~= nil and row.def.settingId ~= nil then
        local st = FS25E_Diagnostics.getStatusForSetting(row.def.settingId)
        if st ~= nil then
            if st.lastResult ~= nil then row.lastResult = st.lastResult end
            if st.lastError ~= nil then row.lastError = st.lastError end
        end
    end
    if (row.lastResult == nil) and FS25E_Diagnostics ~= nil and FS25E_Diagnostics.getCapRuntime ~= nil then
        local rt = FS25E_Diagnostics.getCapRuntime(capabilityId)
        if rt ~= nil then
            if rt.lastResult ~= nil then row.lastResult = rt.lastResult end
            if rt.lastError ~= nil then row.lastError = rt.lastError end
        end
    end
    if row.lastResult == nil and FS25E_CapabilityRegistry ~= nil and FS25E_CapabilityRegistry.getLastResult ~= nil then
        local lr = FS25E_CapabilityRegistry.getLastResult(capabilityId)
        if type(lr) == "table" then
            row.lastResult = lr.status
            if lr.error ~= nil then row.lastError = tostring(lr.error) end
        end
    end
end

local function refreshAllStatusesFromSnapshot()
    ensureRows()
    if FS25E_Diagnostics ~= nil and FS25E_Diagnostics.getSnapshot ~= nil then
        pcall(function()
            FS25E_Diagnostics.getSnapshot()
        end)
    end
    for id, _ in pairs(rows) do
        refreshRowStatus(id, nil)
    end
end

local function loadInitialValues()
    ensureRows()
    for _, row in pairs(rows) do
        local def = row.def
        local v = nil
        if FS25E_SettingsAPI ~= nil and FS25E_SettingsAPI.liveGet ~= nil then
            local ok, snap = pcall(FS25E_SettingsAPI.liveGet, def.capabilityId, nil)
            if ok and type(snap) == "table" then
                v = tonumber(snap.requested) or tonumber(snap.current)
            end
        end
        if v == nil and def.kind == "bool" then
            local raw = settingsGet(def.settingId)
            if raw == true then
                v = 1
            elseif raw == false then
                v = 0
            end
        end
        if v == nil then
            v = def.default
        end
        row.value = clamp(v, def.min, def.max, def.step)
        row.sessionOnly = true
    end
end

local function visibleRowList()
    local defs = ensureRows()
    local list = {}
    for i = 1, #defs do
        local def = defs[i]
        local row = rows[def.capabilityId]
        if row ~= nil then
            list[#list + 1] = row
        end
    end
    return list
end

--- Apply one row via SettingsAPI.live* (hard dock). Expert soft-apply gate for expert rows.
local function applyRow(row, newValue)
    if row == nil or row.def == nil then
        return false
    end
    local def = row.def
    local n = clamp(newValue, def.min, def.max, def.step)
    if def.kind == "bool" then
        n = (n >= 0.5) and 1 or 0
    end
    row.value = n

    if FS25E_SettingsAPI == nil or FS25E_SettingsAPI.liveApply == nil then
        dbgWarn("liveApply missing — session value only (Core live API required)")
        row.lastResult = "SKIPPED"
        row.lastError = "liveApply missing"
        return false
    end

    -- Expert Soft-Apply gate: without soft-apply, cache only + SKIPPED
    if def.applyKind == "expert" and not isExpertSoftApplyOn() then
        if FS25E_SettingsAPI.liveSetRequested ~= nil then
            pcall(FS25E_SettingsAPI.liveSetRequested, def.capabilityId, n, nil)
        end
        if def.kind == "bool" then
            pcall(settingsSet, def.settingId, n >= 0.5)
        end
        row.lastResult = "SKIPPED"
        row.lastError = "expertSoftApply off — value stored, not applied"
        row.sessionOnly = true
        dbg(string.format("SKIPPED %s (softApply off) value=%.2f", def.capabilityId, n))
        return false
    end

    local applied, applyErr
    local callOk, retOk, retErr = pcall(function()
        return FS25E_SettingsAPI.liveApply(def.capabilityId, n, nil)
    end)
    if not callOk then
        applyErr = tostring(retOk)
        row.lastResult = "REJECTED"
        row.lastError = applyErr
        dbgWarn("liveApply error " .. def.capabilityId .. ": " .. applyErr)
        return false
    end
    applied = retOk == true
    applyErr = retErr
    if applied then
        row.lastResult = "APPLIED"
        row.lastError = nil
        row.sessionOnly = true
        if def.kind == "bool" then
            pcall(settingsSet, def.settingId, n >= 0.5)
        end
    else
        row.lastResult = "REJECTED"
        row.lastError = applyErr ~= nil and tostring(applyErr) or "liveApply failed"
    end
    refreshRowStatus(def.capabilityId, nil)
    return applied
end

local function nudgeSelected(dir)
    local list = visibleRowList()
    if #list == 0 then
        return
    end
    if selectedIndex < 1 then selectedIndex = 1 end
    if selectedIndex > #list then selectedIndex = #list end
    local row = list[selectedIndex]
    local def = row.def
    local step = def.step or 0.01
    local nextV = (tonumber(row.value) or def.default) + dir * step
    applyRow(row, nextV)
end

local function restoreSelected()
    local list = visibleRowList()
    if #list == 0 or selectedIndex < 1 or selectedIndex > #list then
        return
    end
    local row = list[selectedIndex]
    if FS25E_SettingsAPI == nil or FS25E_SettingsAPI.liveRestore == nil then
        return
    end
    local ok, err = pcall(function()
        return FS25E_SettingsAPI.liveRestore(row.def.capabilityId, nil)
    end)
    if ok then
        row.lastResult = "APPLIED"
        row.lastError = nil
        loadInitialValues()
        refreshRowStatus(row.def.capabilityId, nil)
        dbg("liveRestore " .. row.def.capabilityId)
    else
        row.lastResult = "REJECTED"
        row.lastError = tostring(err)
    end
end

local function clampScroll(listLen, maxVisible)
    local maxOff = math.max(0, listLen - maxVisible)
    if scrollOffset < 0 then scrollOffset = 0 end
    if scrollOffset > maxOff then scrollOffset = maxOff end
end

function FS25E_LiveOverlay.isVisible()
    return visible == true
end

function FS25E_LiveOverlay.toggle(force)
    if force == true then
        if not FS25E_LiveOverlay.canShow() then
            notify(t("FS25E_LIVE_OVERLAY_GATE_REQUIRED", "Expert Mode + Live Tuning required"))
            return false
        end
        FS25E_LiveOverlay.show()
        return true
    elseif force == false then
        FS25E_LiveOverlay.hide()
        return true
    end

    if visible then
        FS25E_LiveOverlay.hide()
        return true
    end
    if not FS25E_LiveOverlay.canShow() then
        notify(t("FS25E_LIVE_OVERLAY_GATE_REQUIRED", "Expert Mode + Live Tuning required"))
        return false
    end
    FS25E_LiveOverlay.show()
    return true
end

function FS25E_LiveOverlay.show()
    if not FS25E_LiveOverlay.canShow() then
        notify(t("FS25E_LIVE_OVERLAY_GATE_REQUIRED", "Expert Mode + Live Tuning required"))
        return false
    end
    cachedCapList = nil
    ensureRows()
    loadInitialValues()
    refreshAllStatusesFromSnapshot()
    FS25E_LiveOverlay.installListeners()
    visible = true
    selectedIndex = 1
    scrollOffset = 0
    dbg("overlay shown")
    return true
end

function FS25E_LiveOverlay.hide()
    visible = false
    dragRow = nil
    dbg("overlay hidden")
end

function FS25E_LiveOverlay.installListeners()
    if listenersInstalled then
        return
    end
    if FS25E_CapabilityRegistry == nil then
        return
    end
    local function onEvt(id, payload)
        if not visible then
            return
        end
        refreshRowStatus(id, payload)
    end
    if type(FS25E_CapabilityRegistry.onApply) == "function" then
        pcall(FS25E_CapabilityRegistry.onApply, onEvt)
    end
    if type(FS25E_CapabilityRegistry.onReject) == "function" then
        pcall(FS25E_CapabilityRegistry.onReject, onEvt)
    end
    if type(FS25E_CapabilityRegistry.onSkip) == "function" then
        pcall(FS25E_CapabilityRegistry.onSkip, onEvt)
    end
    listenersInstalled = true
    dbg("Diagnostics hybrid listeners installed (Registry onApply/onReject/onSkip)")
end

-- ---------- Drawing ----------

local function hasDrawFilledRect()
    return type(drawFilledRect) == "function"
end

local function fillRect(x, y, w, h, r, g, b, a)
    if hasDrawFilledRect() then
        pcall(drawFilledRect, x, y, w, h, r, g, b, a)
    end
end

local function drawLabel(x, y, size, text, r, g, b, a, align, bold)
    if setTextBold ~= nil then
        setTextBold(bold == true)
    end
    if setTextAlignment ~= nil then
        setTextAlignment(align or (RenderText ~= nil and RenderText.ALIGN_LEFT) or 0)
    end
    if setTextColor ~= nil then
        setTextColor(r or 1, g or 1, b or 1, a or 1)
    end
    if renderText ~= nil then
        renderText(x, y, size, tostring(text or ""))
    end
    if setTextBold ~= nil then
        setTextBold(false)
    end
end

local function costColor(cost, warn)
    if warn then
        return 1.0, 0.45, 0.25, 1
    end
    local c = tostring(cost or "med"):lower()
    if c == "extreme" then
        return 0.95, 0.35, 0.35, 1
    elseif c == "high" then
        return 0.95, 0.7, 0.3, 1
    elseif c == "low" then
        return 0.45, 0.85, 0.55, 1
    end
    return 0.75, 0.8, 0.9, 1
end

function FS25E_LiveOverlay.draw()
    if not visible or not FS25E_LiveOverlay.canShow() then
        if visible and not FS25E_LiveOverlay.canShow() then
            visible = false
        end
        return
    end

    local list = visibleRowList()
    local soft = isExpertSoftApplyOn()
    local px, py, pw, ph = PANEL.x, PANEL.y, PANEL.w, PANEL.h

    fillRect(px, py, pw, ph, 0.05, 0.07, 0.10, 0.78)

    local title = t("FS25E_LIVE_OVERLAY_TITLE", "FS25E Expert Live Overlay")
    drawLabel(px + PANEL.pad, py + ph - PANEL.pad - 0.008, PANEL.titleSize, title, 1, 0.92, 0.55, 1, nil, true)

    -- HUD telemetry in header (engine + system DISCONNECTED or real sidecar)
    local hudTop = py + ph - PANEL.pad - 0.028
    local hudH = 0.055
    if FS25E_HudOverlay ~= nil and FS25E_HudOverlay.drawAt ~= nil then
        hudH = FS25E_HudOverlay.drawAt(px + PANEL.pad * 0.5, hudTop, pw - PANEL.pad, {
            compact = false,
            background = true,
            alpha = 0.45,
            pad = 0.005,
        })
    end

    local gateY = hudTop - hudH - 0.006
    local gate = string.format(
        "Gates: expertMode=ON liveTuning=ON softApply=%s  caps=%d",
        soft and "ON" or "OFF",
        #list
    )
    drawLabel(px + PANEL.pad, gateY, PANEL.smallSize, gate, 0.75, 0.85, 1, 1)

    local hint = t("FS25E_LIVE_OVERLAY_HINT", "Wheel/click bar | +/- | R restore | Esc | Ctrl+Shift+E")
    drawLabel(px + PANEL.pad, gateY - 0.016, PANEL.smallSize, hint, 0.65, 0.65, 0.65, 1)

    local listTop = gateY - 0.032
    local listBottom = py + PANEL.pad + 0.058
    local avail = listTop - listBottom
    local maxVisible = math.max(1, math.floor(avail / PANEL.rowH))
    clampScroll(#list, maxVisible)

    -- ensure selection visible
    if selectedIndex < scrollOffset + 1 then
        scrollOffset = math.max(0, selectedIndex - 1)
    elseif selectedIndex > scrollOffset + maxVisible then
        scrollOffset = selectedIndex - maxVisible
    end
    clampScroll(#list, maxVisible)

    local y = listTop
    local endIdx = math.min(#list, scrollOffset + maxVisible)
    for i = scrollOffset + 1, endIdx do
        local row = list[i]
        local def = row.def
        local selected = (i == selectedIndex)
        local warn = def.warn == true
        if selected then
            fillRect(px + 0.004, y - 0.006, pw - 0.008, PANEL.rowH, 0.20, 0.35, 0.55, 0.40)
        elseif warn then
            fillRect(px + 0.004, y - 0.006, pw - 0.008, PANEL.rowH, 0.35, 0.18, 0.08, 0.28)
        end

        local label = def.labelKey ~= nil and t(def.labelKey, def.labelFallback or def.id) or (def.labelFallback or def.id)
        local badge = row.lastResult or "—"
        local badgeColor = { 0.7, 0.7, 0.7, 1 }
        if badge == "APPLIED" then
            badgeColor = { 0.35, 0.9, 0.45, 1 }
        elseif badge == "REJECTED" then
            badgeColor = { 0.95, 0.35, 0.35, 1 }
        elseif badge == "SKIPPED" then
            badgeColor = { 0.95, 0.8, 0.3, 1 }
        end

        local valStr = formatValue(def, row.value)
        local costStr = string.upper(tostring(def.cost or "med"))
        if warn then
            costStr = costStr .. "!"
        end
        local cr, cg, cb = costColor(def.cost, warn)
        local line1 = string.format("%s  %s", label, valStr)
        drawLabel(px + PANEL.pad, y + 0.014, PANEL.textSize, line1, warn and 1 or 1, warn and 0.85 or 1, warn and 0.7 or 1, 1)

        if def.kind == "bool" then
            local tog = (tonumber(row.value) or 0) >= 0.5 and "[ ON ]" or "[ OFF ]"
            drawLabel(px + PANEL.pad, y - 0.002, PANEL.textSize, tog, 0.85, 0.9, 1, 1)
        else
            drawLabel(px + PANEL.pad, y - 0.002, PANEL.textSize, barText(def, row.value), 0.7, 0.85, 1, 1)
        end

        -- cost beside row (right of bar area)
        drawLabel(px + pw - PANEL.pad - 0.08, y + 0.014, PANEL.smallSize, costStr, cr, cg, cb, 1, (RenderText ~= nil and RenderText.ALIGN_RIGHT) or 2)
        drawLabel(px + pw - PANEL.pad, y + 0.014, PANEL.smallSize, badge, badgeColor[1], badgeColor[2], badgeColor[3], badgeColor[4], (RenderText ~= nil and RenderText.ALIGN_RIGHT) or 2)

        row._hit = { x = px + PANEL.pad, y = y - 0.006, w = pw - 0.02, h = PANEL.rowH, index = i }

        y = y - PANEL.rowH
    end

    if #list > maxVisible then
        local scrollHint = string.format("[%d-%d / %d]", scrollOffset + 1, endIdx, #list)
        drawLabel(px + pw - PANEL.pad, listBottom + 0.012, PANEL.smallSize, scrollHint, 0.6, 0.6, 0.6, 1, (RenderText ~= nil and RenderText.ALIGN_RIGHT) or 2)
    end

    -- Help under selection (Schema tooltip preferred; 1–2 lines truncated)
    local helpY = py + PANEL.pad + 0.022
    if #list > 0 and selectedIndex >= 1 and selectedIndex <= #list then
        local sel = list[selectedIndex]
        local help = truncateHelp(resolveRowHelp(sel), 118)
        if help ~= nil and help ~= "" then
            local wr = sel.def ~= nil and sel.def.warn == true
            drawLabel(px + PANEL.pad, helpY + 0.014, PANEL.smallSize, help, wr and 1 or 0.85, wr and 0.7 or 0.85, wr and 0.45 or 0.55, 1)
        end
    end

    local foot = t("FS25E_LIVE_OVERLAY_SESSION", "Values: session via SettingsCache (persist optional)")
    drawLabel(px + PANEL.pad, py + PANEL.pad, PANEL.smallSize, foot, 0.55, 0.55, 0.55, 1)
end

-- ---------- Input / mouse ----------

local function hitTest(posX, posY)
    local list = visibleRowList()
    for i = 1, #list do
        local row = list[i]
        local h = row._hit
        if h ~= nil and posX >= h.x and posX <= h.x + h.w and posY >= h.y and posY <= h.y + h.h then
            return row, h
        end
    end
    return nil, nil
end

local function valueFromBarClick(row, hit, posX)
    local def = row.def
    if def.kind == "bool" then
        local cur = tonumber(row.value) or 0
        return cur >= 0.5 and 0 or 1
    end
    local t01 = 0
    if hit.w > 0 then
        t01 = (posX - hit.x) / hit.w
    end
    if t01 < 0 then t01 = 0 end
    if t01 > 1 then t01 = 1 end
    return def.min + t01 * (def.max - def.min)
end

function FS25E_LiveOverlay.mouseEvent(posX, posY, isDown, isUp, button)
    if not visible or not FS25E_LiveOverlay.canShow() then
        return
    end
    local left = (button == 1 or button == nil)
    if not left then
        return
    end

    if isDown then
        local row, hit = hitTest(posX, posY)
        if row ~= nil then
            selectedIndex = hit.index
            dragRow = row
            local v = valueFromBarClick(row, hit, posX)
            applyRow(row, v)
        end
    elseif isUp then
        dragRow = nil
    else
        if dragRow ~= nil and dragRow._hit ~= nil then
            local v = valueFromBarClick(dragRow, dragRow._hit, posX)
            applyRow(dragRow, v)
        end
    end
end

function FS25E_LiveOverlay.mouseWheel(delta)
    if not visible or not FS25E_LiveOverlay.canShow() then
        return
    end
    local d = tonumber(delta) or 0
    if d == 0 then
        return
    end
    -- With Shift: scroll list; else nudge selected
    -- Giants may not expose modifier here — nudge by default; PgUp/Dn scroll via keys
    nudgeSelected(d > 0 and 1 or -1)
end

function FS25E_LiveOverlay.keyEvent(unicode, sym, modifier, isDown)
    if not visible or not isDown then
        return false
    end
    if sym == 27 or (Input ~= nil and Input.KEY_esc ~= nil and sym == Input.KEY_esc) then
        FS25E_LiveOverlay.hide()
        return true
    end
    if sym == 43 or sym == 61 or unicode == 43 then
        nudgeSelected(1)
        return true
    end
    if sym == 45 or unicode == 45 then
        nudgeSelected(-1)
        return true
    end
    -- R = restore selected
    if sym == 114 or sym == 82 or unicode == 114 or unicode == 82 then
        restoreSelected()
        return true
    end
    if sym == 273 or sym == 265 then
        selectedIndex = math.max(1, selectedIndex - 1)
        return true
    end
    if sym == 274 or sym == 264 then
        local list = visibleRowList()
        selectedIndex = math.min(#list, selectedIndex + 1)
        return true
    end
    if sym == 276 or sym == 263 then
        nudgeSelected(-1)
        return true
    end
    if sym == 275 or sym == 262 then
        nudgeSelected(1)
        return true
    end
    -- Page up / down scroll
    if sym == 280 or sym == 266 then
        scrollOffset = scrollOffset - 5
        return true
    end
    if sym == 281 or sym == 267 then
        scrollOffset = scrollOffset + 5
        return true
    end
    return false
end

function FS25E_LiveOverlay.update(dt)
    -- reserved
end

function FS25E_LiveOverlay.registerHooks()
    if hooksRegistered then
        return true
    end
    if FS25E_HookManager == nil or FSBaseMission == nil then
        dbgWarn("HookManager/FSBaseMission missing — cannot register draw/mouse")
        return false
    end

    if FSBaseMission.draw ~= nil then
        FS25E_HookManager.register(FSBaseMission, "draw", "appended", function(self)
            if FS25E_LiveOverlay ~= nil then
                FS25E_LiveOverlay.draw()
            end
            -- Mini HUD when overlay closed is handled by FS25E_HudOverlay.registerHooks
        end)
    end

    if FSBaseMission.mouseEvent ~= nil then
        FS25E_HookManager.register(FSBaseMission, "mouseEvent", "appended", function(self, posX, posY, isDown, isUp, button)
            if FS25E_LiveOverlay ~= nil then
                FS25E_LiveOverlay.mouseEvent(posX, posY, isDown, isUp, button)
            end
        end)
    end

    if FSBaseMission.mouseWheelEvent ~= nil then
        FS25E_HookManager.register(FSBaseMission, "mouseWheelEvent", "appended", function(self, ...)
            local args = { ... }
            local delta = args[1]
            if type(delta) ~= "number" and type(args[3]) == "number" then
                delta = args[3]
            end
            if FS25E_LiveOverlay ~= nil then
                FS25E_LiveOverlay.mouseWheel(delta)
            end
        end)
    end

    if FSBaseMission.keyEvent ~= nil then
        FS25E_HookManager.register(FSBaseMission, "keyEvent", "appended", function(self, unicode, sym, modifier, isDown)
            if FS25E_LiveOverlay ~= nil then
                FS25E_LiveOverlay.keyEvent(unicode, sym, modifier, isDown)
            end
        end)
    end

    hooksRegistered = true
    dbg("draw/mouse/key hooks registered")
    return true
end

function FS25E_LiveOverlay.reset()
    visible = false
    dragRow = nil
    rows = {}
    cachedCapList = nil
    scrollOffset = 0
end
