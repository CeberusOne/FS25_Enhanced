-- FS25_Enhanced / UI/FS25E_HudOverlay.lua
-- Lightweight Pro Live HUD: engine FPS/frametime + optional system sidecar telemetry.
-- Data ONLY via FS25E_SettingsAPI.getHudTelemetry() — never invent sensor numbers.

FS25E_HudOverlay = {}

local LOG = "HudOverlay"
local hooksRegistered = false
local miniForcedOff = false

local MINI = {
    x = 0.012,
    y = 0.88,
    w = 0.22,
    h = 0.10,
    pad = 0.008,
    titleSize = 0.013,
    textSize = 0.012,
}

local function dbg(msg)
    if FS25E_Debug ~= nil then
        FS25E_Debug.info(LOG, tostring(msg))
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

local function settingsGet(key)
    if FS25E_ModSettings ~= nil and FS25E_ModSettings.get ~= nil then
        return FS25E_ModSettings.get(key)
    end
    if FS25E_SettingsAPI ~= nil and FS25E_SettingsAPI.get ~= nil then
        return FS25E_SettingsAPI.get(key)
    end
    return nil
end

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

local function fmtNum(n, digits)
    if n == nil then
        return "—"
    end
    local d = digits or 1
    return string.format("%." .. tostring(d) .. "f", n)
end

local function fmtPct(n)
    if n == nil then
        return "—"
    end
    return string.format("%.0f%%", n * 100)
end

--- Fetch telemetry; never synthesize system metrics.
function FS25E_HudOverlay.getTelemetry()
    if FS25E_SettingsAPI == nil or FS25E_SettingsAPI.getHudTelemetry == nil then
        return { engine = nil, system = { connected = false, status = "DISCONNECTED" } }
    end
    local ok, snap = pcall(FS25E_SettingsAPI.getHudTelemetry)
    if not ok or type(snap) ~= "table" then
        return { engine = nil, system = { connected = false, status = "DISCONNECTED" } }
    end
    return snap
end

--- Build engine + system lines (real numbers only).
--- Returns lines = { {text, r,g,b}, ... }
function FS25E_HudOverlay.formatLines(compact)
    local snap = FS25E_HudOverlay.getTelemetry()
    local eng = snap.engine
    local sys = snap.system
    local lines = {}

    local fpsA, fpsL, msA, msL = "—", "—", "—", "—"
    if type(eng) == "table" then
        if eng.fpsAvg ~= nil then fpsA = fmtNum(eng.fpsAvg, 1) end
        if eng.fpsLast ~= nil then fpsL = fmtNum(eng.fpsLast, 1) end
        if eng.frameMsAvg ~= nil then msA = fmtNum(eng.frameMsAvg, 2) end
        if eng.frameMsLast ~= nil then msL = fmtNum(eng.frameMsLast, 2) end
    end

    if compact then
        lines[#lines + 1] = {
            text = string.format("%s %s/%s  %sms %s/%s",
                t("FS25E_HUD_ENGINE", "ENG"), fpsA, fpsL, t("FS25E_HUD_MS", ""), msA, msL),
            r = 0.85, g = 0.95, b = 1.0,
        }
    else
        lines[#lines + 1] = {
            text = string.format("%s  fpsAvg=%s  fpsLast=%s",
                t("FS25E_HUD_ENGINE", "Engine"), fpsA, fpsL),
            r = 0.85, g = 0.95, b = 1.0,
        }
        lines[#lines + 1] = {
            text = string.format("  frameMsAvg=%s  frameMsLast=%s", msA, msL),
            r = 0.70, g = 0.80, b = 0.90,
        }
    end

    local connected = type(sys) == "table" and sys.connected == true
    if not connected then
        lines[#lines + 1] = {
            text = string.format("%s  %s",
                t("FS25E_HUD_SYSTEM", "System"),
                t("FS25E_HUD_DISCONNECTED", "DISCONNECTED")),
            r = 0.95, g = 0.55, b = 0.35,
        }
    else
        local d = sys.data or {}
        if compact then
            lines[#lines + 1] = {
                text = string.format("%s CPU %s GPU %s  VRAM %s/%s  RAM %s/%s",
                    t("FS25E_HUD_SYSTEM", "SYS"),
                    fmtPct(d.cpuLoad),
                    fmtPct(d.gpuLoad),
                    d.vramUsedMB ~= nil and tostring(math.floor(d.vramUsedMB)) or "—",
                    d.vramTotalMB ~= nil and tostring(math.floor(d.vramTotalMB)) or "—",
                    d.ramUsedMB ~= nil and tostring(math.floor(d.ramUsedMB)) or "—",
                    d.ramTotalMB ~= nil and tostring(math.floor(d.ramTotalMB)) or "—"),
                r = 0.55, g = 0.95, b = 0.65,
            }
        else
            local cpuT = d.cpuTempC ~= nil and string.format(" %.0f°C", d.cpuTempC) or ""
            local gpuT = d.gpuTempC ~= nil and string.format(" %.0f°C", d.gpuTempC) or ""
            lines[#lines + 1] = {
                text = string.format("%s  cpu=%s%s  gpu=%s%s",
                    t("FS25E_HUD_SYSTEM", "System"),
                    fmtPct(d.cpuLoad), cpuT,
                    fmtPct(d.gpuLoad), gpuT),
                r = 0.55, g = 0.95, b = 0.65,
            }
            lines[#lines + 1] = {
                text = string.format("  vram=%s/%s MB  ram=%s/%s MB",
                    d.vramUsedMB ~= nil and tostring(math.floor(d.vramUsedMB)) or "—",
                    d.vramTotalMB ~= nil and tostring(math.floor(d.vramTotalMB)) or "—",
                    d.ramUsedMB ~= nil and tostring(math.floor(d.ramUsedMB)) or "—",
                    d.ramTotalMB ~= nil and tostring(math.floor(d.ramTotalMB)) or "—"),
                r = 0.50, g = 0.85, b = 0.60,
            }
        end
    end

    return lines
end

--- Draw telemetry block at absolute position (for LiveOverlay header).
--- Returns height consumed (normalized).
function FS25E_HudOverlay.drawAt(x, yTop, w, opts)
    opts = opts or {}
    local compact = opts.compact == true
    local bg = opts.background ~= false
    local lines = FS25E_HudOverlay.formatLines(compact)
    local lineH = compact and 0.016 or 0.015
    local pad = opts.pad or 0.006
    local h = pad * 2 + (#lines) * lineH + (opts.title and 0.016 or 0)

    if bg then
        fillRect(x, yTop - h, w, h, 0.04, 0.06, 0.09, opts.alpha or 0.55)
    end

    local y = yTop - pad - 0.002
    if opts.title then
        drawLabel(x + pad, y - 0.012, 0.013, opts.title, 1, 0.9, 0.5, 1, nil, true)
        y = y - 0.016
    end
    for i = 1, #lines do
        local L = lines[i]
        drawLabel(x + pad, y - lineH + 0.002, 0.012, L.text, L.r, L.g, L.b, 1)
        y = y - lineH
    end
    return h
end

function FS25E_HudOverlay.shouldDrawMini()
    if miniForcedOff then
        return false
    end
    if FS25E_LiveOverlay ~= nil and FS25E_LiveOverlay.isVisible ~= nil and FS25E_LiveOverlay.isVisible() then
        -- Full HUD lives in overlay header; skip duplicate mini
        return false
    end
    -- Always-on mini when liveTuningEnabled (expert live path active)
    return settingsGet("liveTuningEnabled") == true
end

function FS25E_HudOverlay.drawMini()
    if not FS25E_HudOverlay.shouldDrawMini() then
        return
    end
    local title = t("FS25E_HUD_TITLE_MINI", "FS25E HUD")
    FS25E_HudOverlay.drawAt(MINI.x, MINI.y + MINI.h, MINI.w, {
        compact = true,
        background = true,
        alpha = 0.62,
        title = title,
        pad = MINI.pad,
    })
end

function FS25E_HudOverlay.draw()
    FS25E_HudOverlay.drawMini()
end

function FS25E_HudOverlay.setMiniForcedOff(off)
    miniForcedOff = off == true
end

function FS25E_HudOverlay.registerHooks()
    if hooksRegistered then
        return true
    end
    -- Prefer sharing LiveOverlay's draw hook; if LiveOverlay registers first it calls us.
    -- Also register independently so mini HUD works if overlay hooks fail.
    if FS25E_HookManager == nil or FSBaseMission == nil or FSBaseMission.draw == nil then
        dbg("HookManager/FSBaseMission.draw missing")
        return false
    end
    FS25E_HookManager.register(FSBaseMission, "draw", "appended", function(self)
        if FS25E_HudOverlay ~= nil then
            FS25E_HudOverlay.draw()
        end
    end)
    hooksRegistered = true
    dbg("mini HUD draw hook registered")
    return true
end

function FS25E_HudOverlay.reset()
    miniForcedOff = false
end
