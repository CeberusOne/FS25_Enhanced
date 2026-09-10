-- FS25_Enhanced / UI/FS25E_LiveOverlay.lua
-- Expert Live-Overlay: drawn over the world (no fullscreen dialog).
-- Apply path: FS25E_SettingsAPI.live* only (no engine setters / no direct Applier).
-- Status: Diagnostics.getSnapshot on open + Registry onApply/onReject/onSkip per row.
-- Widgets: custom bars / toggles — NEVER GuiSlider / MultiTextOption-Slider.

FS25E_LiveOverlay = {}

local LOG = "LiveOverlay"

local visible = false
local hooksRegistered = false
local listenersInstalled = false
local selectedIndex = 1
local dragRow = nil
local lastNotifyAt = 0

-- Layout (normalized 0..1 screen space)
local PANEL = {
    x = 0.62,
    y = 0.12,
    w = 0.36,
    h = 0.76,
    pad = 0.012,
    rowH = 0.038,
    titleSize = 0.018,
    textSize = 0.014,
    smallSize = 0.012,
}

--- Row defs: Wave-1 always listed when overlay open; Expert rows when soft-apply path allows.
--- kind: "float" | "int" | "bool"
--- applyKind: "wave1" | "expert"
local ROW_DEFS = {
    { id = "viewDistance", settingId = "viewDistance", capabilityId = "view-distance-coeff", labelKey = "FS25E_LIVE_OVERLAY_VIEW_DISTANCE", min = 0.50, max = 1.50, step = 0.01, kind = "float", applyKind = "wave1", default = 1.00 },
    { id = "lodDistance", settingId = "lodDistance", capabilityId = "lod-distance-coeff", labelKey = "FS25E_LIVE_OVERLAY_LOD_DISTANCE", min = 0.50, max = 1.50, step = 0.01, kind = "float", applyKind = "wave1", default = 1.00 },
    { id = "foliageViewDistance", settingId = "foliageViewDistance", capabilityId = "foliage-view-distance-coeff", labelKey = "FS25E_LIVE_OVERLAY_FOLIAGE_VIEW", min = 0.50, max = 1.50, step = 0.01, kind = "float", applyKind = "wave1", default = 1.00 },
    { id = "foliageLodDistance", settingId = "foliageLodDistance", capabilityId = "foliage-lod-distance-coeff", labelKey = "FS25E_LIVE_OVERLAY_FOLIAGE_LOD", min = 0.50, max = 1.50, step = 0.01, kind = "float", applyKind = "wave1", default = 1.00 },
    { id = "terrainLodDistance", settingId = "terrainLodDistance", capabilityId = "terrain-lod-distance-coeff", labelKey = "FS25E_LIVE_OVERLAY_TERRAIN_LOD", min = 0.50, max = 1.50, step = 0.01, kind = "float", applyKind = "wave1", default = 1.00 },
    { id = "maxShadowLights", settingId = "maxShadowLights", capabilityId = "max-num-shadow-lights", labelKey = "FS25E_LIVE_OVERLAY_MAX_SHADOW_LIGHTS", min = 1, max = 8, step = 1, kind = "int", applyKind = "wave1", default = 4 },
    -- Expert (Soft-Apply gated for live apply; values still editable → SKIPPED without soft)
    { id = "rainAmountMult", settingId = "rainAmountMult", capabilityId = "rain-amount-mult", labelKey = "FS25E_LIVE_OVERLAY_RAIN_AMOUNT", min = 0.00, max = 2.00, step = 0.01, kind = "float", applyKind = "expert", default = 1.00 },
    { id = "ssrQuality", settingId = "ssrQuality", capabilityId = "ssr-quality", labelKey = "FS25E_LIVE_OVERLAY_SSR_QUALITY", min = 0, max = 3, step = 1, kind = "int", applyKind = "expert", default = 1 },
    { id = "atmosphereQuality", settingId = "atmosphereQuality", capabilityId = "atmosphere-quality", labelKey = "FS25E_LIVE_OVERLAY_ATMOSPHERE_QUALITY", min = 0, max = 3, step = 1, kind = "int", applyKind = "expert", default = 1 },
    { id = "drsQuality", settingId = "drsQuality", capabilityId = "drs-quality", labelKey = "FS25E_LIVE_OVERLAY_DRS_QUALITY", min = 0, max = 3, step = 1, kind = "int", applyKind = "expert", default = 1 },
    { id = "shadowFocus", settingId = "shadowFocus", capabilityId = "shadow-focus-box", labelKey = "FS25E_LIVE_OVERLAY_SHADOW_FOCUS", min = 0, max = 1, step = 1, kind = "bool", applyKind = "expert", default = 0 },
    { id = "fastShadowUpdate", settingId = "fastShadowUpdate", capabilityId = "fast-shadow-update", labelKey = "FS25E_LIVE_OVERLAY_FAST_SHADOW", min = 0, max = 1, step = 1, kind = "bool", applyKind = "expert", default = 0 },
    { id = "rainShallowWater", settingId = "rainShallowWater", capabilityId = "rain-shallow-water-simulation", labelKey = "FS25E_LIVE_OVERLAY_RAIN_SHALLOW", min = 0, max = 1, step = 1, kind = "bool", applyKind = "expert", default = 0 },
}

-- Runtime row state keyed by id
local rows = {} -- { id -> { def, value, lastResult, lastError, sessionOnly } }

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
        -- avoid float noise for 0.01 steps
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
    if def.kind == "int" or def.step >= 1 then
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
    local width = 16
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

local function ensureRows()
    for i = 1, #ROW_DEFS do
        local def = ROW_DEFS[i]
        if rows[def.id] == nil then
            rows[def.id] = {
                def = def,
                value = def.default,
                lastResult = nil,
                lastError = nil,
                sessionOnly = true,
            }
        end
    end
end

local function refreshRowStatus(capabilityId, payload)
    ensureRows()
    for id, row in pairs(rows) do
        if row.def.capabilityId == capabilityId then
            if type(payload) == "table" then
                row.lastResult = payload.status or row.lastResult
                if payload.error ~= nil then
                    row.lastError = tostring(payload.error)
                end
            end
            -- Prefer Diagnostics helper when available
            if FS25E_Diagnostics ~= nil and FS25E_Diagnostics.getStatusForSetting ~= nil then
                local st = FS25E_Diagnostics.getStatusForSetting(row.def.settingId)
                if st ~= nil then
                    if st.lastResult ~= nil then row.lastResult = st.lastResult end
                    if st.lastError ~= nil then row.lastError = st.lastError end
                end
            elseif FS25E_Diagnostics ~= nil and FS25E_Diagnostics.getCapRuntime ~= nil then
                local rt = FS25E_Diagnostics.getCapRuntime(capabilityId)
                if rt ~= nil then
                    if rt.lastResult ~= nil then row.lastResult = rt.lastResult end
                    if rt.lastError ~= nil then row.lastError = rt.lastError end
                end
            elseif FS25E_CapabilityRegistry ~= nil and FS25E_CapabilityRegistry.getLastResult ~= nil then
                local lr = FS25E_CapabilityRegistry.getLastResult(capabilityId)
                if type(lr) == "table" then
                    row.lastResult = lr.status
                    if lr.error ~= nil then row.lastError = tostring(lr.error) end
                end
            end
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
    for _, row in pairs(rows) do
        refreshRowStatus(row.def.capabilityId, nil)
    end
end

local function loadInitialValues()
    ensureRows()
    for _, row in pairs(rows) do
        local def = row.def
        local v = nil
        -- Prefer liveGet requested/current
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
    ensureRows()
    local list = {}
    local soft = isExpertSoftApplyOn()
    local expert = settingsGet("expertMode") == true
    for i = 1, #ROW_DEFS do
        local def = ROW_DEFS[i]
        if def.applyKind == "wave1" then
            list[#list + 1] = rows[def.id]
        elseif expert then
            -- show expert rows whenever expertMode; soft-apply gates apply, not visibility
            list[#list + 1] = rows[def.id]
            local _ = soft -- keep local used for clarity / future filter
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
    ensureRows()
    loadInitialValues()
    refreshAllStatusesFromSnapshot()
    FS25E_LiveOverlay.installListeners()
    visible = true
    selectedIndex = 1
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

    fillRect(px, py, pw, ph, 0.05, 0.07, 0.10, 0.72)

    local title = t("FS25E_LIVE_OVERLAY_TITLE", "FS25E Expert Live Overlay")
    drawLabel(px + PANEL.pad, py + ph - PANEL.pad - 0.01, PANEL.titleSize, title, 1, 0.92, 0.55, 1, nil, true)

    local gate = string.format(
        "Gates: expertMode=ON liveTuning=ON softApply=%s",
        soft and "ON" or "OFF"
    )
    drawLabel(px + PANEL.pad, py + ph - PANEL.pad - 0.035, PANEL.smallSize, gate, 0.75, 0.85, 1, 1)

    local hint = t("FS25E_LIVE_OVERLAY_HINT", "Wheel/click bar | +/- | Esc close | Ctrl+Shift+E")
    drawLabel(px + PANEL.pad, py + ph - PANEL.pad - 0.055, PANEL.smallSize, hint, 0.65, 0.65, 0.65, 1)

    local y = py + ph - PANEL.pad - 0.085
    for i = 1, #list do
        local row = list[i]
        local def = row.def
        local selected = (i == selectedIndex)
        if selected then
            fillRect(px + 0.004, y - 0.006, pw - 0.008, PANEL.rowH, 0.20, 0.35, 0.55, 0.35)
        end

        local label = t(def.labelKey, def.id)
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
        local line1 = string.format("%s  %s", label, valStr)
        drawLabel(px + PANEL.pad, y + 0.016, PANEL.textSize, line1, 1, 1, 1, 1)

        if def.kind == "bool" then
            local tog = (tonumber(row.value) or 0) >= 0.5 and "[ ON ]" or "[ OFF ]"
            drawLabel(px + PANEL.pad, y - 0.002, PANEL.textSize, tog, 0.85, 0.9, 1, 1)
        else
            drawLabel(px + PANEL.pad, y - 0.002, PANEL.textSize, barText(def, row.value), 0.7, 0.85, 1, 1)
        end

        drawLabel(px + pw - PANEL.pad, y + 0.016, PANEL.smallSize, badge, badgeColor[1], badgeColor[2], badgeColor[3], badgeColor[4], (RenderText ~= nil and RenderText.ALIGN_RIGHT) or 2)

        if row.lastError ~= nil and row.lastError ~= "" and selected then
            drawLabel(px + PANEL.pad, y - 0.014, PANEL.smallSize, tostring(row.lastError), 0.9, 0.55, 0.4, 1)
        end

        -- store hitbox for mouse
        row._hit = { x = px + PANEL.pad, y = y - 0.006, w = pw - 0.02, h = PANEL.rowH, index = i }

        y = y - PANEL.rowH
        if y < py + PANEL.pad + 0.04 then
            break
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
    -- Left button typically 1 in Giants
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
        -- move while held
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
    nudgeSelected(d > 0 and 1 or -1)
end

function FS25E_LiveOverlay.keyEvent(unicode, sym, modifier, isDown)
    if not visible or not isDown then
        return false
    end
    -- ESC
    if sym == 27 or (Input ~= nil and Input.KEY_esc ~= nil and sym == Input.KEY_esc) then
        FS25E_LiveOverlay.hide()
        return true
    end
    -- +/-
    if sym == 43 or sym == 61 or unicode == 43 then -- + or =
        nudgeSelected(1)
        return true
    end
    if sym == 45 or unicode == 45 then
        nudgeSelected(-1)
        return true
    end
    -- arrows up/down select
    if sym == 273 or sym == 265 then -- up
        selectedIndex = math.max(1, selectedIndex - 1)
        return true
    end
    if sym == 274 or sym == 264 then -- down
        local list = visibleRowList()
        selectedIndex = math.min(#list, selectedIndex + 1)
        return true
    end
    -- left/right nudge
    if sym == 276 or sym == 263 then
        nudgeSelected(-1)
        return true
    end
    if sym == 275 or sym == 262 then
        nudgeSelected(1)
        return true
    end
    return false
end

function FS25E_LiveOverlay.update(dt)
    -- reserved (debounce etc.)
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
        end)
    end

    if FSBaseMission.mouseEvent ~= nil then
        FS25E_HookManager.register(FSBaseMission, "mouseEvent", "appended", function(self, posX, posY, isDown, isUp, button)
            if FS25E_LiveOverlay ~= nil then
                FS25E_LiveOverlay.mouseEvent(posX, posY, isDown, isUp, button)
            end
        end)
    end

    -- Best-effort mouse wheel + key hooks
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
    -- listeners stay (idempotent install); hooks stay for session
end
