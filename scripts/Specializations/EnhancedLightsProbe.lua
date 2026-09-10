-- FS25_Enhanced / scripts/Specializations/EnhancedLightsProbe.lua
-- Optional vehicle specialization: enumerate RealLight nodes via Lights (GDN class 691).
-- Read-only by default. Soft-Apply OFF unless FS25E_LightDiscovery soft flag enabled.
-- Spec table: eBook pattern SPEC_TABLE_NAME = "spec_" .. g_currentModName .. ".enhancedLightsProbe"

EnhancedLightsProbe = {}

EnhancedLightsProbe.MOD_NAME = g_currentModName
EnhancedLightsProbe.SPEC_NAME = "enhancedLightsProbe"
EnhancedLightsProbe.SPEC_TABLE_NAME = "spec_" .. tostring(g_currentModName) .. ".enhancedLightsProbe"

local LOG = "EnhancedLightsProbe"

local function getSpec(vehicle)
    if vehicle == nil then
        return nil
    end
    return vehicle[EnhancedLightsProbe.SPEC_TABLE_NAME]
end

function EnhancedLightsProbe.prerequisitesPresent(specializations)
    if SpecializationUtil ~= nil and SpecializationUtil.hasSpecialization ~= nil and Lights ~= nil then
        local ok, result = pcall(SpecializationUtil.hasSpecialization, Lights, specializations)
        if ok then
            return result == true
        end
    end
    -- Soft fallback: allow registration; onLoad still guards spec_lights.
    return true
end

function EnhancedLightsProbe.initSpecialization()
    -- no XML schema
end

function EnhancedLightsProbe.registerEventListeners(vehicleType)
    if SpecializationUtil == nil or SpecializationUtil.registerEventListener == nil then
        return
    end
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", EnhancedLightsProbe)
    SpecializationUtil.registerEventListener(vehicleType, "onDelete", EnhancedLightsProbe)
    -- Optional rare tick reserved; profile changes handled via LightDiscovery message center.
end

function EnhancedLightsProbe:onLoad(savegame)
    local spec = getSpec(self)
    if spec == nil then
        -- Giants may allocate under SPEC_TABLE_NAME after type finalize; create local bookkeeping.
        self[EnhancedLightsProbe.SPEC_TABLE_NAME] = {}
        spec = self[EnhancedLightsProbe.SPEC_TABLE_NAME]
    end
    spec.discovered = 0
    spec.activeProfile = "low"
    spec.handlesOwned = true

    local ok, err = pcall(function()
        if self.spec_lights == nil then
            FS25E_Debug.info(LOG, "onLoad skip: no spec_lights")
            return
        end
        local high = false
        if self.getUseHighProfile ~= nil then
            high = self:getUseHighProfile() == true
        end
        spec.activeProfile = high and "high" or "low"

        if FS25E_LightDiscovery ~= nil then
            spec.discovered = FS25E_LightDiscovery.collectFromVehicle(self) or 0
            -- Soft-Apply OPTIONAL and OFF by default.
            if FS25E_LightDiscovery.isSoftApplyEnabled and FS25E_LightDiscovery.isSoftApplyEnabled() then
                FS25E_LightDiscovery.trySoftApplyForOwner("vehicle", self)
            end
        end
        FS25E_Debug.info(LOG, string.format(
            "onLoad discovered=%d profile=%s softApply=%s",
            spec.discovered,
            tostring(spec.activeProfile),
            tostring(FS25E_LightDiscovery ~= nil and FS25E_LightDiscovery.isSoftApplyEnabled
                and FS25E_LightDiscovery.isSoftApplyEnabled())
        ))
    end)
    if not ok then
        FS25E_Debug.warning(LOG, "onLoad failed: " .. tostring(err))
    end
end

function EnhancedLightsProbe:onDelete()
    local ok, err = pcall(function()
        if FS25E_LightDiscovery ~= nil then
            -- Drop handles; if Soft-Apply was used, restore via CapabilityApplier/ShadowManager originals.
            FS25E_LightDiscovery.unregisterOwner("vehicle", self)
        end
        local spec = getSpec(self)
        if spec ~= nil then
            spec.discovered = 0
            spec.handlesOwned = false
        end
    end)
    if not ok then
        FS25E_Debug.warning(LOG, "onDelete failed: " .. tostring(err))
    end
end
