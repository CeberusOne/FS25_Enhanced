# Lights Spec Probe — RealLight discovery

**Branch:** `feature/lights-spec-probe`  
**Version:** 0.2.1.0  
**Source of truth:** [wave2-candidates.md](wave2-candidates.md) §1 · Optimalplan EnhancedLightsProbe  
**GDN:** Lights class **691** · PlaceableLights class **746** (Script v1.20.0.0)

## Goal

Enumerate RealLight nodes through the **vehicle `Lights`** and **placeable `PlaceableLights`** specializations. Register node ids for later managers (ShadowManager / IES / Scattering).

**Not in scope:** IES/Scattering manager logic, GUI, particle budgets, EXPERIMENTAL setters.

## No global scan

There is **no** mission-global RealLight registry in LuaDoc and **no** engine free-function to list lights. This probe therefore:

- Does **not** walk the scene graph by node class id
- Does **not** blind-scan world nodes looking for lights
- Only reads `spec_lights.realLights` on objects that already have the Lights / PlaceableLights specialization

## How discovery works

```
TypeManager.finalizeTypes (HookManager prepended)
  └─ for vehicle/placeable types that already have "lights"
       addSpecialization(modName.enhancedLightsProbe / enhancedPlaceableLightsProbe)

Vehicle onLoad
  └─ pairs(spec.realLights) → pairs(profile buckets) → ipairs(realLight) → realLight.node
       └─ FS25E_LightDiscovery.registerLight({ kind=vehicle, profile=low|high, bucket=... })

Placeable onLoad / onFinalizePlacement
  └─ ipairs(spec.realLights.low|high) → { node, groupIndex }
       └─ FS25E_LightDiscovery.registerLight({ kind=placeable, profile=low|high, groupIndex=... })
```

### Active profile

- Call `owner:getUseHighProfile()` when present (CONFIRMED on both specs).
- Vehicle mask path uses `realLights.high` when high, else `realLights.low`.
- Registry keeps **both** profile node lists and marks `active` for the current profile.

### Profile-change subscription

| Source | Message key (CONFIRMED in Research) |
|--------|-------------------------------------|
| Vehicle Lights | `MessageType.SETTING_CHANGED[GameSettings.SETTING.LIGHTS_PROFILE]` |
| PlaceableLights | `MessageType.SETTING_CHANGED["lightsProfile"]` (string) |

`FS25E_LightDiscovery` subscribes to **both** without inventing a unified key. On change it re-resolves `active` flags (nodes remain valid; active set swaps). If the message center is unavailable, re-scan / re-resolve is on demand (`fs25eLightsDump` / next collect).

## Soft-Apply (OPTIONAL, OFF by default)

| Flag | Default | Behaviour |
|------|---------|-----------|
| `FS25E_LightDiscovery.isSoftApplyEnabled()` | **false** | Read-only discovery + registry only |
| Soft-Apply ON | explicit | May call **CONFIRMED** ShadowManager priority / soft / map APIs only |

- `autoApply` on GraphicsGovernor stays **false**.
- Soft-Apply never calls EXPERIMENTAL setters (`setShadowFocusBox`, `setFastShadowUpdate`, `setRainShallowWaterSimulation`).
- Soft-Apply never calls `saveHardwareScalability` / `applyPerformanceClass` / `setTerrainQuality`.

## Restore rules (Vanilla restore Pflicht)

1. **Default path (read-only):** onDelete only drops registry handles; no engine mutation → nothing to restore.
2. **If Soft-Apply was used:** onDelete → `unregisterOwner` → `restoreSoftForOwner` → `CapabilityApplier.restoreAll()` (session originals captured at first apply via SettingsCache / CapabilityApplier).
3. **Mission deleteMap:** existing `RestoreManager.restoreAll` still restores any Wave-1 applies; LightDiscovery registry is cleared in bootstrap reset.
4. Soft-applied per-light keys are restored before handles are dropped so nodes remain valid during restore.

## Console

| Command | Effect |
|---------|--------|
| `fs25eLightsDump` | Print discovered counts + up to 64 nodes; **no apply** |

Registered via `addConsoleCommand` when available.

## Files

| Path | Role |
|------|------|
| `scripts/Lighting/LightDiscovery.lua` | Central registry, profile subscribe, soft flag, type inject, console |
| `scripts/Specializations/EnhancedLightsProbe.lua` | Vehicle optional specialization |
| `scripts/Placeables/EnhancedPlaceableLightsProbe.lua` | Placeable specialization equivalent |
| `modDesc.xml` | `<specializations>` / `<placeableSpecializations>` + `extraSourceFiles` |

## Injection (Mileage pattern)

```lua
-- Via HookManager.register(TypeManager, "finalizeTypes", "prepended", ...)
if self.typeName == "vehicle" then
  for typeName, typeEntry in pairs(self:getTypes()) do
    if typeEntry.specializationsByName["lights"] ~= nil then
      self:addSpecialization(typeName, modName .. ".enhancedLightsProbe")
    end
  end
end
-- analogous for placeable + enhancedPlaceableLightsProbe
```

All inject / collect / restore paths are wrapped in `pcall` with `[FS25_Enhanced]` debug logging.

## Hard constraints (this PR)

- No EXPERIMENTAL setters
- No particle emitter discovery
- No `saveHardwareScalability` / `applyPerformanceClass` / `setTerrainQuality`
- Soft-Apply / auto-apply remain false unless explicitly enabled at runtime
- Client-local only
