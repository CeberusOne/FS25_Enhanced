-- FS25_Enhanced / Core/CapabilityApplier.lua
-- Generic apply/restore for CONFIRMED (+ Expert EXPERIMENTAL/GATED/ASSET when allowed).
-- Session-only (no saveHardwareScalability). Every setter: type(fn)==function + pcall;
-- fail → REJECTED + restore + log capabilityId.

FS25E_CapabilityApplier = {}

local unpack = rawget(_G, "unpack") or table.unpack

local applied = {} -- cacheKey -> { capabilityId, setterName, getterName, argsPrefix, original, appliedValue }

-- GATED setters must pass paired getSupports* before set (capability-matrix / wave2).
local GATED_SUPPORT = {
    ["ssr-quality"] = "getSupportsScreenSpaceReflectionsQuality",
    ["atmosphere-quality"] = "getSupportsAtmosphereQuality",
    ["drs-quality"] = "getSupportsDRSQuality",
}

local function resolveGlobal(name)
    if name == nil or name == "" or name == "NONE" then
        return nil
    end
    local fn = _G[name]
    if type(fn) == "function" then
        return fn
    end
    return nil
end

local function cacheKey(capabilityId, argsPrefix)
    if argsPrefix == nil or argsPrefix == "" then
        return tostring(capabilityId)
    end
    return tostring(capabilityId) .. "|" .. tostring(argsPrefix)
end

local function callGetter(getterName, prefixArgs)
    local getter = resolveGlobal(getterName)
    if getter == nil then
        return nil, false
    end
    local ok, result
    if prefixArgs ~= nil and #prefixArgs > 0 then
        ok, result = pcall(getter, unpack(prefixArgs))
    else
        ok, result = pcall(getter)
    end
    if not ok then
        return nil, false
    end
    return result, true
end

local function callSetter(setterName, prefixArgs, valueArgs)
    local setter = resolveGlobal(setterName)
    if type(setter) ~= "function" then
        return false, "setter missing: " .. tostring(setterName)
    end
    local args = {}
    if prefixArgs ~= nil then
        for i = 1, #prefixArgs do
            args[#args + 1] = prefixArgs[i]
        end
    end
    if valueArgs ~= nil then
        for i = 1, #valueArgs do
            args[#args + 1] = valueArgs[i]
        end
    end
    local ok, err = pcall(function()
        setter(unpack(args))
    end)
    if not ok then
        return false, err
    end
    return true, nil
end

local function resolveExpertFlag(opts)
    if opts ~= nil and opts.expertMode ~= nil then
        return opts.expertMode == true
    end
    if FS25E_SettingsSchema ~= nil and FS25E_SettingsSchema.get ~= nil then
        return FS25E_SettingsSchema.get("expertMode") == true
    end
    return false
end

--- Check GATED getSupports* gate. Returns ok, errOrNil.
function FS25E_CapabilityApplier.checkGatedSupport(capabilityId)
    local supportName = GATED_SUPPORT[capabilityId]
    if supportName == nil then
        return true, nil
    end
    local fn = resolveGlobal(supportName)
    if type(fn) ~= "function" then
        return false, "support gate missing: " .. tostring(supportName)
    end
    local ok, supported = pcall(fn)
    if not ok then
        return false, "support gate pcall failed: " .. tostring(supported)
    end
    if supported ~= true then
        return false, "getSupports* returned false (" .. tostring(supportName) .. ")"
    end
    return true, nil
end

local function valuesEqual(a, b)
    if a == b then
        return true
    end
    if type(a) == "number" and type(b) == "number" then
        return math.abs(a - b) < 1e-4
    end
    return false
end

local function valuesListEqual(a, b)
    if a == nil or b == nil then
        return a == b
    end
    if #a ~= #b then
        return false
    end
    for i = 1, #a do
        if not valuesEqual(a[i], b[i]) then
            return false
        end
    end
    return true
end

--- Apply a capability when registry allowsApply (CONFIRMED, or Expert statuses with expertMode).
--- opts = { prefixArgs, values|value, keySuffix, skipRestoreRegister, expertMode, skipGateCheck }
--- Returns ok, errOrNil
function FS25E_CapabilityApplier.apply(capabilityId, opts)
    opts = opts or {}
    local cap = FS25E_CapabilityRegistry ~= nil and FS25E_CapabilityRegistry.get(capabilityId) or nil
    if cap == nil then
        return false, "unknown capability"
    end

    local expert = resolveExpertFlag(opts)
    if FS25E_CapabilityRegistry.allowsApply == nil
        or not FS25E_CapabilityRegistry.allowsApply(capabilityId, expert) then
        if FS25E_CapabilityRegistry.markSkipped ~= nil then
            FS25E_CapabilityRegistry.markSkipped(capabilityId, "not allowed (expertMode=" .. tostring(expert) .. " status=" .. tostring(cap.status) .. ")")
        end
        return false, "not allowed (expertMode=" .. tostring(expert) .. " status=" .. tostring(cap.status) .. ")"
    end
    if cap.setter == nil or cap.setter == "" or cap.setter == "NONE" then
        return false, "no setter (query-only)"
    end
    if cap.applyMode == "RESTART" then
        return false, "RESTART applyMode blocked on Fast path"
    end

    -- Never call these without explicit opt-in elsewhere; block if somehow registered for apply.
    if capabilityId == "save-hardware-scalability" or capabilityId == "apply-performance-class"
        or capabilityId == "terrain-quality" then
        return false, "blocked: requires explicit opt-in / not Fast path"
    end

    local setter = resolveGlobal(cap.setter)
    if type(setter) ~= "function" then
        FS25E_CapabilityRegistry.reject(capabilityId, "setter not a function: " .. tostring(cap.setter))
        FS25E_Debug.warning("CapabilityApplier", string.format(
            "REJECTED capabilityId=%s reason=setter not a function setter=%s",
            tostring(capabilityId), tostring(cap.setter)
        ))
        return false, "setter not a function"
    end

    -- GATED: getSupports* BEFORE set
    local base = cap.baseStatus or cap.status
    if not opts.skipGateCheck
        and (base == "GATED" or cap.status == "GATED" or GATED_SUPPORT[capabilityId] ~= nil) then
        local gateOk, gateErr = FS25E_CapabilityApplier.checkGatedSupport(capabilityId)
        if not gateOk then
            FS25E_Debug.warning("CapabilityApplier", string.format(
                "GATED skip capabilityId=%s reason=%s",
                tostring(capabilityId), tostring(gateErr)
            ))
            return false, gateErr
        end
    end

    local prefixArgs = opts.prefixArgs or {}
    local values = opts.values or {}
    if #values == 0 and opts.value ~= nil then
        values = { opts.value }
    end

    local key = cacheKey(capabilityId, opts.keySuffix or (prefixArgs[1] ~= nil and tostring(prefixArgs[1]) or ""))

    -- Delta skip: do not re-set / re-markApplied when value unchanged
    local prevApplied = applied[key]
    if prevApplied ~= nil and valuesListEqual(prevApplied.appliedValues or { prevApplied.appliedValue }, values) then
        return true, nil
    end
    if FS25E_SettingsCache ~= nil then
        local e = FS25E_SettingsCache.get(key)
        if e ~= nil and e.current ~= nil and #values >= 1 and valuesEqual(e.current, values[1]) then
            -- keep applied[] in sync without engine write
            applied[key] = applied[key] or {
                capabilityId = capabilityId,
                setterName = cap.setter,
                getterName = cap.getter,
                prefixArgs = prefixArgs,
                original = e.original,
                hadGetter = e.original ~= nil,
                appliedValue = values[1],
                appliedValues = values,
                restoreStrategy = cap.restoreStrategy,
            }
            return true, nil
        end
    end

    -- Capture original once via getter when available
    local original = nil
    local hadGetter = false
    if FS25E_SettingsCache ~= nil then
        local existing = FS25E_SettingsCache.get(key)
        if existing ~= nil and existing.original ~= nil then
            original = existing.original
            hadGetter = true
        end
    end
    if not hadGetter then
        local gVal, gOk = callGetter(cap.getter, prefixArgs)
        if gOk then
            original = gVal
            hadGetter = true
        end
        if FS25E_SettingsCache ~= nil then
            FS25E_SettingsCache.captureOriginal(key, original)
            local e = FS25E_SettingsCache.get(key)
            if e ~= nil then
                e.applyMode = FS25E_SettingsCache.APPLY_MODE.SESSION
                e.needsCalibration = true
                e.capabilityId = capabilityId
            end
        end
    end

    local okSet, errSet = callSetter(cap.setter, prefixArgs, values)
    if not okSet then
        FS25E_CapabilityRegistry.reject(capabilityId, "apply pcall failed: " .. tostring(errSet))
        if hadGetter and original ~= nil then
            callSetter(cap.setter, prefixArgs, { original })
        elseif cap.restoreStrategy == "shadowFocusBoxReset" then
            local resetFn = resolveGlobal("setShadowFocusBox")
            if type(resetFn) == "function" then
                pcall(resetFn, 0)
            end
        end
        FS25E_Debug.warning("CapabilityApplier", string.format(
            "apply failed REJECTED capabilityId=%s err=%s",
            tostring(capabilityId), tostring(errSet)
        ))
        return false, errSet
    end

    if FS25E_SettingsCache ~= nil then
        FS25E_SettingsCache.setRequested(key, values[1])
        local e = FS25E_SettingsCache.get(key)
        if e ~= nil then
            e.current = values[1]
            e.needsCalibration = true
        end
    end

    applied[key] = {
        capabilityId = capabilityId,
        setterName = cap.setter,
        getterName = cap.getter,
        prefixArgs = prefixArgs,
        original = original,
        hadGetter = hadGetter,
        appliedValue = values[1],
        appliedValues = values,
        restoreStrategy = cap.restoreStrategy,
    }

    if not opts.skipRestoreRegister and FS25E_RestoreManager ~= nil and FS25E_RestoreManager.registerCapabilityRestore ~= nil then
        FS25E_RestoreManager.registerCapabilityRestore(key)
    end

    if FS25E_CapabilityRegistry.markApplied ~= nil then
        FS25E_CapabilityRegistry.markApplied(capabilityId, key)
    end

    FS25E_Debug.info("CapabilityApplier", string.format(
        "APPLIED capabilityId=%s key=%s setter=%s session-only needsCalibration=true expertMode=%s",
        tostring(capabilityId), key, tostring(cap.setter), tostring(expert)
    ))
    return true, nil
end

--- Restore a single applied capability by cache key.
function FS25E_CapabilityApplier.restoreOne(key)
    local entry = applied[key]
    if entry == nil then
        return true
    end
    if entry.restoreStrategy == "NO" then
        applied[key] = nil
        return true
    end

    if entry.restoreStrategy == "splitLightShadow" then
        local split = resolveGlobal("splitLightShadow")
        if type(split) == "function" and entry.prefixArgs ~= nil and entry.prefixArgs[1] ~= nil then
            local ok, err = pcall(split, entry.prefixArgs[1])
            if not ok then
                FS25E_Debug.warning("CapabilityApplier", "splitLightShadow restore failed: " .. tostring(err))
            end
        end
        applied[key] = nil
        return true
    end

    if entry.restoreStrategy == "shadowFocusBoxReset" then
        local resetFn = resolveGlobal("setShadowFocusBox")
        if type(resetFn) == "function" then
            local ok, err = pcall(resetFn, 0)
            if not ok then
                FS25E_Debug.warning("CapabilityApplier", "setShadowFocusBox(0) restore failed: " .. tostring(err))
            end
        end
        applied[key] = nil
        return true
    end

    if entry.hadGetter and entry.original ~= nil then
        local ok, err = callSetter(entry.setterName, entry.prefixArgs, { entry.original })
        if not ok then
            FS25E_Debug.warning("CapabilityApplier", string.format("restoreOne failed key=%s err=%s", tostring(key), tostring(err)))
            return false
        end
    else
        FS25E_Debug.info("CapabilityApplier", string.format("restoreOne skip (no original) key=%s", tostring(key)))
    end
    applied[key] = nil
    return true
end

--- Restore all capabilities applied through the applier (LIFO).
function FS25E_CapabilityApplier.restoreAll()
    FS25E_Debug.info("CapabilityApplier", "restoreAll begin")
    local keys = {}
    for k in pairs(applied) do
        keys[#keys + 1] = k
    end
    table.sort(keys)
    for i = #keys, 1, -1 do
        FS25E_CapabilityApplier.restoreOne(keys[i])
    end
    applied = {}
    FS25E_Debug.info("CapabilityApplier", "restoreAll done (session restore; no saveHardwareScalability)")
end

function FS25E_CapabilityApplier.getApplied()
    return applied
end

function FS25E_CapabilityApplier.reset()
    applied = {}
end

--- Resolve global by name with type(fn)=="function" check (shared helper).
function FS25E_CapabilityApplier.resolveGlobal(name)
    return resolveGlobal(name)
end

function FS25E_CapabilityApplier.getGatedSupportMap()
    return GATED_SUPPORT
end
