-- FS25_Enhanced / UI/FS25E_HudOverlay.lua
-- Compact live status: FPS and frame time only. Slider controls live separately.
-- Data ONLY via FS25E_SettingsAPI.getHudTelemetry() — never invent sensor numbers.

FS25E_HudOverlay = {}

local LOG = "HudOverlay"
local hooksRegistered = false
local miniForcedOff = false

local MINI = {
    x = 0.012,
    y = 0.88,
    w = 0.17,
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
    if FS25E_Localization then return FS25E_Localization.t(key, fallback) end
    if g_i18n ~= nil and g_i18n.getText ~= nil then
        local ok, text = pcall(function()
            return g_i18n:getText(key)
        end)
        if ok and text ~= nil and text ~= "" and text ~= key then
            return text
        end
    end
    if FS25E_Localization ~= nil and FS25E_Localization.t ~= nil then
        return FS25E_Localization.t(key, fallback)
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

--- Two live status values; do not mix diagnostics or slider settings into the HUD.
function FS25E_HudOverlay.formatLines(compact)
    local telemetry=FS25E_HudOverlay.getTelemetry()
    local perf=telemetry.engine or {}
    return {
        {text=t('FS25E_debug_fps', 'FPS')..': '..fmtNum(perf.fpsAvg,1),r=.82,g=.88,b=.9},
        {text=t('FS25E_debug_frameTime', 'Frametime')..': '..fmtNum(perf.frameMsAvg,2)..' ms',r=.82,g=.88,b=.9},
    }
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
        -- Keep the status HUD out of the slider interface.
        return false
    end
    -- Always-on mini when liveTuningEnabled (expert live path active)
    return settingsGet("liveTuningEnabled") == true
end

function FS25E_HudOverlay.drawMini()
    if not FS25E_HudOverlay.shouldDrawMini() then
        return
    end
    FS25E_HudOverlay.drawAt(MINI.x, MINI.y + MINI.h, MINI.w, {
        compact = true,
        background = true,
        alpha = 0.62,
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
