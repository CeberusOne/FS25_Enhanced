-- FS25_Enhanced / Core/CompatibilityManager.lua
-- Soft stub: detect known mods; no hard dependencies. Phase 1 structure only.

FS25E_CompatibilityManager = {}

local knownMods = {
    "FS25_AutoDrive",
    "FS25_Courseplay",
    "FS25_UniversalAutoload",
    "FS25_AutoVRAMOptimizer",
}

local detected = {}
local softConflicts = {}

function FS25E_CompatibilityManager.init()
    detected = {}
    softConflicts = {}
    FS25E_Debug.info("CompatibilityManager", "init soft stub")
end

local function isModLoaded(modName)
    if g_modIsLoaded ~= nil and g_modIsLoaded[modName] == true then
        return true
    end
    if g_modManager ~= nil and g_modManager.getModByName ~= nil then
        local ok, mod = pcall(function()
            return g_modManager:getModByName(modName)
        end)
        if ok and mod ~= nil then
            return true
        end
    end
    return false
end

--- Soft scan; never errors if APIs missing.
function FS25E_CompatibilityManager.scan()
    detected = {}
    softConflicts = {}
    for _, name in ipairs(knownMods) do
        local ok, loaded = pcall(isModLoaded, name)
        if ok and loaded then
            detected[name] = true
            FS25E_Debug.info("CompatibilityManager", "detected " .. name)
        end
    end
    -- Future: mark softConflicts when another graphics governor is present
end

function FS25E_CompatibilityManager.isDetected(modName)
    return detected[modName] == true
end

function FS25E_CompatibilityManager.getDetected()
    return detected
end

function FS25E_CompatibilityManager.getSoftConflicts()
    return softConflicts
end

--- Whether a capability should be throttled due to soft conflict (always false in Phase 1).
function FS25E_CompatibilityManager.shouldThrottle(capabilityId)
    return false
end
