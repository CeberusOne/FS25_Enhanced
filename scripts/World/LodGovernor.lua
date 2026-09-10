-- FS25_Enhanced / scripts/World/LodGovernor.lua
-- Wave 1: distance coeffs + allow foliage shadows. Clamp coeffs. Auto-apply OFF.

FS25E_LodGovernor = {}

local initialized = false

-- Sensible placeholder clamp for distance coefficients (document in WAVE1.md).
local COEFF_MIN = 0.5
local COEFF_MAX = 2.0

local COEFF_CAPS = {
    { id = "view-distance-coeff", name = "view" },
    { id = "lod-distance-coeff", name = "lod" },
    { id = "foliage-view-distance-coeff", name = "foliageView" },
    { id = "foliage-lod-distance-coeff", name = "foliageLod" },
    { id = "terrain-lod-distance-coeff", name = "terrainLod" },
}

function FS25E_LodGovernor.init()
    initialized = true
    FS25E_Debug.info("LodGovernor", string.format(
        "init (wave1 coeffs clamp=[%.1f,%.1f]; auto-apply off)",
        COEFF_MIN, COEFF_MAX
    ))
end

function FS25E_LodGovernor.reset()
    initialized = false
end

function FS25E_LodGovernor.clampCoeff(value)
    local v = tonumber(value)
    if v == nil then
        return nil
    end
    if v < COEFF_MIN then
        return COEFF_MIN
    end
    if v > COEFF_MAX then
        return COEFF_MAX
    end
    return v
end

function FS25E_LodGovernor.getClampRange()
    return COEFF_MIN, COEFF_MAX
end

local function applyCoeff(capabilityId, value)
    local clamped = FS25E_LodGovernor.clampCoeff(value)
    if clamped == nil then
        return false, "invalid coeff"
    end
    if FS25E_CapabilityApplier == nil then
        return false, "CapabilityApplier missing"
    end
    return FS25E_CapabilityApplier.apply(capabilityId, { value = clamped })
end

function FS25E_LodGovernor.setViewDistanceCoeff(value)
    return applyCoeff("view-distance-coeff", value)
end

function FS25E_LodGovernor.setLODDistanceCoeff(value)
    return applyCoeff("lod-distance-coeff", value)
end

function FS25E_LodGovernor.setFoliageViewDistanceCoeff(value)
    return applyCoeff("foliage-view-distance-coeff", value)
end

function FS25E_LodGovernor.setFoliageLODDistanceCoeff(value)
    return applyCoeff("foliage-lod-distance-coeff", value)
end

function FS25E_LodGovernor.setTerrainLODDistanceCoeff(value)
    return applyCoeff("terrain-lod-distance-coeff", value)
end

function FS25E_LodGovernor.setAllowFoliageShadows(allow)
    if FS25E_CapabilityApplier == nil then
        return false, "CapabilityApplier missing"
    end
    return FS25E_CapabilityApplier.apply("allow-foliage-shadows", { value = allow == true })
end

--- Apply a table of coeff values (keys: view, lod, foliageView, foliageLod, terrainLod, allowFoliageShadows).
function FS25E_LodGovernor.applyValues(values)
    if values == nil then
        return false, "nil values"
    end
    local map = {
        view = FS25E_LodGovernor.setViewDistanceCoeff,
        lod = FS25E_LodGovernor.setLODDistanceCoeff,
        foliageView = FS25E_LodGovernor.setFoliageViewDistanceCoeff,
        foliageLod = FS25E_LodGovernor.setFoliageLODDistanceCoeff,
        terrainLod = FS25E_LodGovernor.setTerrainLODDistanceCoeff,
    }
    for key, fn in pairs(map) do
        if values[key] ~= nil then
            fn(values[key])
        end
    end
    if values.allowFoliageShadows ~= nil then
        FS25E_LodGovernor.setAllowFoliageShadows(values.allowFoliageShadows)
    end
    return true, nil
end

function FS25E_LodGovernor.restoreAll()
    FS25E_Debug.info("LodGovernor", "restoreAll (defer to CapabilityApplier for coeff/foliage caps)")
    -- CapabilityApplier.restoreAll restores cached originals for these ids.
end

function FS25E_LodGovernor.isInitialized()
    return initialized
end

function FS25E_LodGovernor.applyPresetStub(preset)
    FS25E_Debug.info("LodGovernor", "applyPresetStub name=" .. tostring(preset) .. " (no-op unless explicitly invoked)")
    return true
end
