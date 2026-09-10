-- FS25_Enhanced / Core/CapabilityApplier.lua
-- Generic apply/restore for CONFIRMED capabilities. Session-only (no saveHardwareScalability).

FS25E_CapabilityApplier = {}

local unpack = rawget(_G, "unpack") or table.unpack

local applied = {} -- cacheKey -> { capabilityId, setterName, getterName, argsPrefix, original, appliedValue }

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
    if setter == nil then
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

--- Apply a CONFIRMED capability.
--- opts = { prefixArgs = {lightId,...}, values = {v1,...}, skipRestoreRegister = bool }
--- Returns ok, errOrNil
function FS25E_CapabilityApplier.apply(capabilityId, opts)
    opts = opts or {}
    local cap = FS25E_CapabilityRegistry ~= nil and FS25E_CapabilityRegistry.get(capabilityId) or nil
    if cap == nil then
        return false, "unknown capability"
    end
    if FS25E_CapabilityRegistry.allowsApply == nil or not FS25E_CapabilityRegistry.allowsApply(capabilityId) then
        return false, "not CONFIRMED / not allowed"
    end
    if cap.setter == nil or cap.setter == "" or cap.setter == "NONE" then
        return false, "no setter (query-only)"
    end
    if cap.applyMode == "RESTART" then
        return false, "RESTART applyMode blocked in Wave 1 Fast path"
    end

    local setter = resolveGlobal(cap.setter)
    if type(setter) ~= "function" then
        FS25E_CapabilityRegistry.reject(capabilityId, "setter not a function: " .. tostring(cap.setter))
        return false, "setter not a function"
    end

    local prefixArgs = opts.prefixArgs or {}
    local values = opts.values or {}
    if #values == 0 and opts.value ~= nil then
        values = { opts.value }
    end

    local key = cacheKey(capabilityId, opts.keySuffix or (prefixArgs[1] ~= nil and tostring(prefixArgs[1]) or ""))

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
        -- Attempt restore of this cap if we had an original
        if hadGetter and original ~= nil then
            callSetter(cap.setter, prefixArgs, { original })
        end
        FS25E_Debug.warning("CapabilityApplier", string.format("apply failed id=%s err=%s", tostring(capabilityId), tostring(errSet)))
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
        restoreStrategy = cap.restoreStrategy,
    }

    if not opts.skipRestoreRegister and FS25E_RestoreManager ~= nil and FS25E_RestoreManager.registerCapabilityRestore ~= nil then
        FS25E_RestoreManager.registerCapabilityRestore(key)
    end

    FS25E_Debug.info("CapabilityApplier", string.format(
        "applied id=%s key=%s setter=%s session-only needsCalibration=true",
        tostring(capabilityId), key, tostring(cap.setter)
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

    -- Special: merge restores via splitLightShadow (handled by ShadowManager; still try if setter is merge)
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
