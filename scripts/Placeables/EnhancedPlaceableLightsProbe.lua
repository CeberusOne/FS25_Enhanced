-- FS25_Enhanced / scripts/Placeables/EnhancedPlaceableLightsProbe.lua
-- Placeable specialization: enumerate RealLight nodes via PlaceableLights (GDN class 746).
-- Flat arrays spec.realLights.low/high of {node, groupIndex}. Read-only by default.
-- Spec table: "spec_" .. g_currentModName .. ".enhancedPlaceableLightsProbe"

EnhancedPlaceableLightsProbe = {}

EnhancedPlaceableLightsProbe.MOD_NAME = g_currentModName
EnhancedPlaceableLightsProbe.SPEC_NAME = "enhancedPlaceableLightsProbe"
EnhancedPlaceableLightsProbe.SPEC_TABLE_NAME = "spec_" .. tostring(g_currentModName) .. ".enhancedPlaceableLightsProbe"

local LOG = "EnhancedPlaceableLightsProbe"

local function getSpec(placeable)
    if placeable == nil then
        return nil
    end
    return placeable[EnhancedPlaceableLightsProbe.SPEC_TABLE_NAME]
end

function EnhancedPlaceableLightsProbe.prerequisitesPresent(specializations)
    -- Prefer PlaceableLights when the global class exists; else Lights-named placeable spec.
    if SpecializationUtil ~= nil and SpecializationUtil.hasSpecialization ~= nil then
        if PlaceableLights ~= nil then
            local ok, result = pcall(SpecializationUtil.hasSpecialization, PlaceableLights, specializations)
            if ok then
                return result == true
            end
        end
        if Lights ~= nil then
            local ok, result = pcall(SpecializationUtil.hasSpecialization, Lights, specializations)
            if ok then
                return result == true
            end
        end
    end
    return true
end

function EnhancedPlaceableLightsProbe.initSpecialization()
end

function EnhancedPlaceableLightsProbe.registerEventListeners(placeableType)
    if SpecializationUtil == nil or SpecializationUtil.registerEventListener == nil then
        return
    end
    SpecializationUtil.registerEventListener(placeableType, "onLoad", EnhancedPlaceableLightsProbe)
    SpecializationUtil.registerEventListener(placeableType, "onDelete", EnhancedPlaceableLightsProbe)
    -- onFinalizePlacement is when PlaceableLights calls lightSetupChanged; re-collect if needed.
    SpecializationUtil.registerEventListener(placeableType, "onFinalizePlacement", EnhancedPlaceableLightsProbe)
end

function EnhancedPlaceableLightsProbe:onLoad(savegame)
    local spec = getSpec(self)
    if spec == nil then
        self[EnhancedPlaceableLightsProbe.SPEC_TABLE_NAME] = {}
        spec = self[EnhancedPlaceableLightsProbe.SPEC_TABLE_NAME]
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
            spec.discovered = FS25E_LightDiscovery.collectFromPlaceable(self) or 0
            if FS25E_LightDiscovery.isSoftApplyEnabled and FS25E_LightDiscovery.isSoftApplyEnabled() then
                FS25E_LightDiscovery.trySoftApplyForOwner("placeable", self)
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

function EnhancedPlaceableLightsProbe:onFinalizePlacement()
    -- PlaceableLights applies lightSetupChanged here; ensure registry reflects current nodes.
    local ok, err = pcall(function()
        if self.spec_lights == nil or FS25E_LightDiscovery == nil then
            return
        end
        FS25E_LightDiscovery.unregisterOwner("placeable", self)
        local spec = getSpec(self)
        if spec == nil then
            self[EnhancedPlaceableLightsProbe.SPEC_TABLE_NAME] = {}
            spec = self[EnhancedPlaceableLightsProbe.SPEC_TABLE_NAME]
        end
        spec.discovered = FS25E_LightDiscovery.collectFromPlaceable(self) or 0
        if FS25E_LightDiscovery.isSoftApplyEnabled and FS25E_LightDiscovery.isSoftApplyEnabled() then
            FS25E_LightDiscovery.trySoftApplyForOwner("placeable", self)
        end
    end)
    if not ok then
        FS25E_Debug.warning(LOG, "onFinalizePlacement failed: " .. tostring(err))
    end
end

function EnhancedPlaceableLightsProbe:onDelete()
    local ok, err = pcall(function()
        if FS25E_LightDiscovery ~= nil then
            FS25E_LightDiscovery.unregisterOwner("placeable", self)
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
