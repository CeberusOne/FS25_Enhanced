-- FS25_Enhanced / Core/ExperimentalCaps.lua
-- Expert-path Soft-Apply for EXPERIMENTAL / GATED / ASSET_DEPENDENT (+ CONFIRMED rain suite).
-- Defaults: expertMode=false, softApply=false, all expert toggles OFF.
-- Never auto-applies on load. No Materials. No saveHardwareScalability / setTerrainQuality.

FS25E_ExperimentalCaps = {}

local LOG = "ExperimentalCaps"

local initialized = false
local softApplyEnabled = false -- Soft-Apply default false; user must trigger

-- Per-cap enable toggles (mirror SettingsSchema expert* keys). All default OFF.
local enables = {
    shadowFocusBox = false,
    fastShadowUpdate = false,
    rainShallowWater = false,
    ssrQuality = false,
    atmosphereQuality = false,
    drsQuality = false,
    rainSuite = false, -- CONFIRMED setRain* soft-apply bundle (shallow water excluded)
}

-- Optional values for quality writers / experimental args (session defaults; not auto-applied).
local values = {
    shadowFocusBoxShapeId = 0, -- 0 = reset; apply only when >0 and enable on
    fastShadowUpdate = true,
    rainShallowWater = true,
    ssrQuality = nil,
    atmosphereQuality = nil,
    drsQuality = nil,
    rainAmountMult = nil,
}

local function expertOn()
    if FS25E_SettingsSchema ~= nil and FS25E_SettingsSchema.get ~= nil then
        return FS25E_SettingsSchema.get("expertMode") == true
    end
    return false
end

local function syncEnablesFromSchema()
    if FS25E_SettingsSchema == nil or FS25E_SettingsSchema.get == nil then
        return
    end
    local map = {
        shadowFocusBox = "expertShadowFocusBox",
        fastShadowUpdate = "expertFastShadowUpdate",
        rainShallowWater = "expertRainShallowWater",
        ssrQuality = "expertSsrQuality",
        atmosphereQuality = "expertAtmosphereQuality",
        drsQuality = "expertDrsQuality",
        rainSuite = "expertRainSuite",
    }
    for k, schemaId in pairs(map) do
        local v = FS25E_SettingsSchema.get(schemaId)
        if v ~= nil then
            enables[k] = v == true
        end
    end
    local soft = FS25E_SettingsSchema.get("expertSoftApply")
    if soft ~= nil then
        softApplyEnabled = soft == true
    end
end

function FS25E_ExperimentalCaps.init()
    initialized = true
    softApplyEnabled = false
    for k in pairs(enables) do
        enables[k] = false
    end
    syncEnablesFromSchema()
    FS25E_Debug.info(LOG, "init expertPath registered; expertMode gate; softApply=false; auto-apply off")
end

function FS25E_ExperimentalCaps.reset()
    softApplyEnabled = false
    for k in pairs(enables) do
        enables[k] = false
    end
    initialized = false
end

function FS25E_ExperimentalCaps.isInitialized()
    return initialized
end

function FS25E_ExperimentalCaps.setSoftApplyEnabled(enabled)
    softApplyEnabled = enabled == true
    FS25E_Debug.info(LOG, "setSoftApplyEnabled=" .. tostring(softApplyEnabled))
end

function FS25E_ExperimentalCaps.isSoftApplyEnabled()
    return softApplyEnabled
end

function FS25E_ExperimentalCaps.setEnable(key, value)
    if enables[key] == nil then
        return false
    end
    enables[key] = value == true
    return true
end

function FS25E_ExperimentalCaps.getEnables()
    return enables
end

function FS25E_ExperimentalCaps.setValue(key, value)
    values[key] = value
    return true
end

local function applyOne(capabilityId, opts)
    opts = opts or {}
    opts.expertMode = true
    if FS25E_CapabilityApplier == nil then
        return false, "CapabilityApplier missing"
    end
    return FS25E_CapabilityApplier.apply(capabilityId, opts)
end

-- --- EXPERIMENTAL ---

--- setShadowFocusBox(shapeId). Restore via setShadowFocusBox(0). Refuse blind shapeId=0 "apply".
function FS25E_ExperimentalCaps.applyShadowFocusBox(shapeId)
    if not expertOn() then
        return false, "expertMode required"
    end
    local id = shapeId
    if id == nil then
        id = values.shadowFocusBoxShapeId
    end
    if id == nil or id == 0 then
        return false, "shadow-focus-box requires non-zero shapeId (use restore for 0)"
    end
    return applyOne("shadow-focus-box", { value = id, values = { id } })
end

function FS25E_ExperimentalCaps.restoreShadowFocusBox()
    local fn = FS25E_CapabilityApplier ~= nil and FS25E_CapabilityApplier.resolveGlobal("setShadowFocusBox") or nil
    if type(fn) ~= "function" then
        return false, "setShadowFocusBox not a function"
    end
    local ok, err = pcall(fn, 0)
    if not ok then
        FS25E_Debug.warning(LOG, "restoreShadowFocusBox failed: " .. tostring(err))
        return false, err
    end
    return true, nil
end

function FS25E_ExperimentalCaps.applyFastShadowUpdate(flag)
    if not expertOn() then
        return false, "expertMode required"
    end
    local v = flag
    if v == nil then
        v = values.fastShadowUpdate
    end
    return applyOne("fast-shadow-update", { value = v == true, values = { v == true } })
end

function FS25E_ExperimentalCaps.applyRainShallowWater(flag)
    if not expertOn() then
        return false, "expertMode required"
    end
    local v = flag
    if v == nil then
        v = values.rainShallowWater
    end
    return applyOne("rain-shallow-water-simulation", { value = v == true, values = { v == true } })
end

-- --- GATED ---

local function applyGated(capabilityId, value)
    if not expertOn() then
        return false, "expertMode required"
    end
    if value == nil then
        return false, "value required for " .. tostring(capabilityId)
    end
    local gateOk, gateErr = FS25E_CapabilityApplier.checkGatedSupport(capabilityId)
    if not gateOk then
        FS25E_Debug.warning(LOG, string.format(
            "GATED reject/skip capabilityId=%s reason=%s",
            tostring(capabilityId), tostring(gateErr)
        ))
        return false, gateErr
    end
    return applyOne(capabilityId, { value = value, values = { value } })
end

function FS25E_ExperimentalCaps.applySsrQuality(value)
    return applyGated("ssr-quality", value ~= nil and value or values.ssrQuality)
end

function FS25E_ExperimentalCaps.applyAtmosphereQuality(value)
    return applyGated("atmosphere-quality", value ~= nil and value or values.atmosphereQuality)
end

function FS25E_ExperimentalCaps.applyDrsQuality(value)
    return applyGated("drs-quality", value ~= nil and value or values.drsQuality)
end

-- --- ASSET_DEPENDENT ---

local function looksLikeIesPath(path)
    if path == nil or type(path) ~= "string" or path == "" then
        return false
    end
    local lower = string.lower(path)
    return string.sub(lower, -4) == ".ies"
end

--- setLightIESProfile(lightId, iesPath). Never blind — requires valid lightId + *.ies path.
function FS25E_ExperimentalCaps.applyLightIesProfile(lightId, iesPath)
    if not expertOn() then
        return false, "expertMode required"
    end
    if lightId == nil then
        return false, "lightId required"
    end
    if not looksLikeIesPath(iesPath) then
        return false, "valid *.ies path required"
    end
    -- Prefer discovered light when LightDiscovery has entries
    if FS25E_LightDiscovery ~= nil and FS25E_LightDiscovery.getEntries ~= nil then
        local entries = FS25E_LightDiscovery.getEntries()
        local n = 0
        local found = false
        local want = tostring(lightId)
        for _, e in pairs(entries) do
            n = n + 1
            if e ~= nil and e.node ~= nil and tostring(e.node) == want then
                found = true
                break
            end
        end
        if n > 0 and not found then
            return false, "lightId not in LightDiscovery"
        end
    end
    return applyOne("light-ies-profile", {
        prefixArgs = { lightId },
        values = { iesPath },
        value = iesPath,
        keySuffix = tostring(lightId),
    })
end

--- Query-only companion.
function FS25E_ExperimentalCaps.queryLightIesConeAngle(lightIdOrPath)
    if FS25E_CapabilityRegistry == nil then
        return nil, "registry missing"
    end
    local cap = FS25E_CapabilityRegistry.get("light-ies-cone-angle")
    if cap == nil then
        return nil, "unknown capability"
    end
    local fn = FS25E_CapabilityApplier.resolveGlobal(cap.getter or "getLightConeAngleFromIESProfile")
    if type(fn) ~= "function" then
        return nil, "getter not a function"
    end
    local ok, result = pcall(fn, lightIdOrPath)
    if not ok then
        return nil, result
    end
    return result, nil
end

--- Stub: no scene foliageBendingSystem handle in Gen-1 — return REJECTED with clear reason.
function FS25E_ExperimentalCaps.applyFoliageBendingCreate(...)
    local reason = "foliage-bending-create stub: no scene foliageBendingSystemId / centerTransform handle"
    if FS25E_CapabilityRegistry ~= nil and FS25E_CapabilityRegistry.reject ~= nil then
        FS25E_CapabilityRegistry.reject("foliage-bending-create", reason)
    end
    FS25E_Debug.warning(LOG, "REJECTED capabilityId=foliage-bending-create reason=" .. reason)
    return false, reason
end

-- --- CONFIRMED rain suite (Expert soft-apply only; shallow water excluded) ---

-- Sensible single-arg rain caps only (skip multi-arg spawn/turbulence/forward without documented defaults).
local RAIN_SUITE = {
    { id = "rain-amount-mult", valueKey = "rainAmountMult" },
    { id = "rain-active-drops-mult", valueKey = nil },
    { id = "rain-max-drops-mult", valueKey = nil },
    { id = "rain-camera-velocity-mult", valueKey = nil },
    { id = "rain-bounce-random-factor", valueKey = nil },
    { id = "rain-bounce-restitution", valueKey = nil },
    { id = "rain-max-bounces", valueKey = nil },
    { id = "rain-wind-force", valueKey = nil },
    { id = "rain-distribution-power", valueKey = nil },
    { id = "rain-most-concentrated-distance", valueKey = nil },
    { id = "rain-heightmap-collision-threshold", valueKey = nil },
    { id = "rain-random-offset", valueKey = nil },
    { id = "rain-behind-camera-mirror-buffer", valueKey = nil },
}

--- Apply one CONFIRMED rain setter when value provided (Expert soft-apply path).
function FS25E_ExperimentalCaps.applyRain(capabilityId, value)
    if not expertOn() then
        return false, "expertMode required"
    end
    if capabilityId == "rain-shallow-water-simulation" then
        return FS25E_ExperimentalCaps.applyRainShallowWater(value)
    end
    if value == nil then
        return false, "value required for rain cap " .. tostring(capabilityId)
    end
    -- CONFIRMED rain: allowsApply without expert, but we still require expertMode for this entrypoint
    return FS25E_CapabilityApplier.apply(capabilityId, {
        value = value,
        values = { value },
        expertMode = true,
    })
end

function FS25E_ExperimentalCaps.applyRainSuite(valueMap)
    if not expertOn() then
        return 0, "expertMode required"
    end
    valueMap = valueMap or {}
    local appliedN = 0
    for i = 1, #RAIN_SUITE do
        local spec = RAIN_SUITE[i]
        local v = valueMap[spec.id]
        if v == nil and spec.valueKey ~= nil then
            v = values[spec.valueKey]
        end
        if v == nil and valueMap.default ~= nil then
            v = valueMap.default
        end
        if v ~= nil then
            local ok, err = FS25E_ExperimentalCaps.applyRain(spec.id, v)
            if ok then
                appliedN = appliedN + 1
            else
                FS25E_Debug.warning(LOG, string.format(
                    "rain suite skip capabilityId=%s err=%s",
                    tostring(spec.id), tostring(err)
                ))
            end
        end
    end
    FS25E_Debug.info(LOG, string.format("rain suite applied=%d (shallow-water excluded)", appliedN))
    return appliedN, nil
end

--- Soft-Apply entry: applies enabled expert caps when expertMode ON and softApply enabled.
--- Never runs on load by itself — caller must trigger after user opt-in.
--- Returns summary table { attempted, applied, skipped, errors }.
function FS25E_ExperimentalCaps.softApplyEnabledCaps()
    syncEnablesFromSchema()
    local summary = { attempted = 0, applied = 0, skipped = 0, errors = {} }

    if not expertOn() then
        FS25E_Debug.info(LOG, "softApply skipped: expertMode=false")
        return summary
    end
    if not softApplyEnabled then
        FS25E_Debug.info(LOG, "softApply skipped: expertSoftApply/softApply=false (user must trigger)")
        return summary
    end

    local function try(label, fn)
        summary.attempted = summary.attempted + 1
        local ok, err = fn()
        if ok then
            summary.applied = summary.applied + 1
        else
            summary.skipped = summary.skipped + 1
            summary.errors[#summary.errors + 1] = { id = label, err = err }
            FS25E_Debug.warning(LOG, string.format(
                "softApply fail capabilityId=%s err=%s",
                tostring(label), tostring(err)
            ))
        end
    end

    -- Priority 1: EXPERIMENTAL
    if enables.shadowFocusBox then
        try("shadow-focus-box", function()
            return FS25E_ExperimentalCaps.applyShadowFocusBox(values.shadowFocusBoxShapeId)
        end)
    end
    if enables.fastShadowUpdate then
        try("fast-shadow-update", function()
            return FS25E_ExperimentalCaps.applyFastShadowUpdate(values.fastShadowUpdate)
        end)
    end
    if enables.rainShallowWater then
        try("rain-shallow-water-simulation", function()
            return FS25E_ExperimentalCaps.applyRainShallowWater(values.rainShallowWater)
        end)
    end

    -- Priority 2: GATED
    if enables.ssrQuality and values.ssrQuality ~= nil then
        try("ssr-quality", function()
            return FS25E_ExperimentalCaps.applySsrQuality(values.ssrQuality)
        end)
    end
    if enables.atmosphereQuality and values.atmosphereQuality ~= nil then
        try("atmosphere-quality", function()
            return FS25E_ExperimentalCaps.applyAtmosphereQuality(values.atmosphereQuality)
        end)
    end
    if enables.drsQuality and values.drsQuality ~= nil then
        try("drs-quality", function()
            return FS25E_ExperimentalCaps.applyDrsQuality(values.drsQuality)
        end)
    end

    -- Priority 1b: CONFIRMED rain suite (if enabled + default value present)
    if enables.rainSuite then
        summary.attempted = summary.attempted + 1
        local n, err = FS25E_ExperimentalCaps.applyRainSuite({ default = values.rainAmountMult })
        if n > 0 then
            summary.applied = summary.applied + n
        else
            summary.skipped = summary.skipped + 1
            if err ~= nil then
                summary.errors[#summary.errors + 1] = { id = "rain-suite", err = err }
            end
        end
    end

    -- ASSET_DEPENDENT: IES / foliage never blind soft-applied (need explicit lightId+path / scene handle)
    FS25E_Debug.info(LOG, string.format(
        "softApply done attempted=%d applied=%d skipped=%d (IES/foliage require explicit args)",
        summary.attempted, summary.applied, summary.skipped
    ))
    return summary
end

--- Called from settings change when expertMode / expertSoftApply flip on.
function FS25E_ExperimentalCaps.onSettingsChanged()
    syncEnablesFromSchema()
    if expertOn() and softApplyEnabled then
        return FS25E_ExperimentalCaps.softApplyEnabledCaps()
    end
    return nil
end

function FS25E_ExperimentalCaps.getRainSuiteSpec()
    return RAIN_SUITE
end
