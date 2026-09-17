# Local lighting and shadow implementation

Research checked on 2026-09-11 against GIANTS FS25 GDN v1.20.0.0 and the installed FS25 SDK `sdk/debugger/scriptBinding.xml`. Native signatures are not inferred from the names of setters.

## Primary sources

- [FS25 setLightShadowMap](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=11&function=213&version=engine): requires `(lightId, boolean cast, integer resolution)`. The paired `getLightCastingShadowMap(lightId)` returns casting state and, when enabled, resolution.
- [FS25 shadow priority](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=11&function=214&version=engine): higher numerical priority is preferred by the engine.
- [FS25 soft shadow size](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=11&function=217&version=engine) and [soft shadow distance](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=11&function=216&version=engine): distance only affects directional lights, and is ignored by spotlights.
- [FS25 scattering intensity](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=11&function=211&version=engine): `(lightId, float intensity)`.
- [FS25 culling-world properties](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=11&function=204&version=engine): global nine-argument grid API, not a per-lamp quality slider.
- [FS25 Lights specialization](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=78&class=691&version=engine): nested `realLights[profile][bucket]`, high/low profiles, RealLight ownership.
- [FS25 merged shadow settings](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=11&function=222&version=engine): multiple optional parameters; no generic scalar adapter is appropriate.

Additional evidence: extracted stock `dataS/scripts/vehicles/specializations/components/RealLight.lua`, `dataS/scripts/vehicles/specializations/Lights.lua`, and `dataS/scripts/placeables/specializations/PlaceableLights.lua`. RealLight has `lightSources`, sets visibility in `setState`, writes native light colors in `setCharge`, and manages its own merged groups and self-shadow ignore lists. These existing groups must not be broken on mod restore.

## Implemented

`LightDiscovery.getRuntimeEntries()` enumerates owned RealLight compound child sources, deduplicates them, respects selected profiles and actual root/child lamp visibility, and removes owner state before deletion. Discovery never scans the world scene graph.

`FS25E_LightTuning` exposes 33 categorized controls via `getControls()`. Each has localized label/tooltip keys, finite range, granular step, a cost estimate, native availability, read/write/reset callbacks. `setAuto(id,value)` honors local user locks.

Local importance includes ownership/current vehicle, type, camera distance/direction, actual activation, and fog attenuation. Candidates are ranked every 250 ms; at most 64 sources are mutated. Local shadow resolution allocation has a 15-second automatic interval; explicit live slider writes apply immediately. Near/far map levels use 256/512/1024/2048 resolutions and remain constrained by the global engine shadow budget. Priority, soft shadow size, soft depth bias factor, and shadow extrusion have paired getters and restores.

Lighting controls affect native colors (intensity, luminance-preserving warmth/tint), range, dropoff, and cone. Existing IES assets are budgeted by distance/importance and lamp type; removing an IES profile uses the stock empty-string convention, and restores the original filename. No new IES profile is assigned to incompatible lamps. Scattering has per-type enablement, intensity, distance, count limits, and measured rain/fog response. Far candidates use reduced range rather than forcibly switching a visible lamp off.

Capture happens immediately before the first actual mutation, never at discovery. Native setter calls are followed by typed getter readback; a successful `pcall` alone is not an applied result. Changes by the engine or another owner become the new baseline. Restoring does not overwrite a newer external value. Deleted entities are dropped safely; failed native restores remain tracked for retry. A disabled shadow getter may omit resolution; restoration uses a required placeholder resolution of 512 while restoring `casting=false` (the resolution has no active effect in that state).

Optional merges use same-owner/profile/bucket sources and `RealLight.getAreShadowsMergable`. Preexisting groups are rejected, not split. Only mod-created, readback-confirmed groups are tracked for split restore.

## Integration

Load `scripts/Lighting/LightTuning.lua` after `ShadowManager.lua` and `LightDiscovery.lua`. Call `FS25E_LightTuning.init()` for a loaded client mission. Call `update(dt,scene)` only while the mod is enabled on a client; scene may supply `cameraNode`, `vehicle`, numeric `fog`/`fogFactor`, and numeric `rain`/`rainFactor`. Camera/vehicle fallbacks use current game runtime. `ShadowManager.restoreAll()` already calls `LightTuning.restoreAll()`. `LightDiscovery.unregisterOwner` restores owned state before removal. Local settings are session-only; central persistence can serialize `getSettings()` and feed validated `set` values after discovery.

`getControls()` contract: ordered rows `{id,category,labelKey,tooltipKey,min,max,step,cost,experimental,read,write,restore,available}`. For inactive lamps an accepted value reports `FS25E_status_lightValuesQueued`; no immediate rendered change is claimed. Language additions are supplied as `work/lights_l10n.json` with identical de/en key sets.

## Deliberate compatibility boundaries

- No additional global sunlight cascade or independent shadow rendering pass is created. Engine lighting budgets still apply.
- Existing vanilla self-shadow ignore lists are preserved. GIANTS exposes add/remove/clear operations but no complete ignore-list getter; an arbitrary override cannot satisfy exact reversible restoration.
- Generic merged slope bias, merged near-plane tuning, and focus shapes are not presented as working scalar toggles. The native interfaces require specific ownership/assets and lack complete original-value readback for arbitrary foreign groups.
- No overwrite of the global culling grid: it has nine arguments and no paired complete getter. Local budgets and distance prioritization implement the safe part of the plan.
- IES controls reuse asset-provided profiles; they do not generate headlight photometry or claim that every mod vehicle supports IES.
- Spotlight soft-shadow distance is explicitly unavailable because GDN says the engine ignores it. A change to the native property would not prove a visual effect.
- Full physically measured photometry, global sun/atmosphere rendering, asset-specific focus geometry, and arbitrary self-shadow edits need further asset-specific integration. Their omission must not be described as completed merely because this backend exists.

## Verification

`lua work/test_lights_native.lua` covers compound discovery, high/low and switched-off visibility, typed shadow-map arguments and both-value restore, silently rejected native writes, changed native baselines, color application without compounding, locks, vanilla group protection, owned merge restore, priority scoring, deletion restore, and all 33 control contracts. These are mocked native regression tests. No in-game visual pass, GPU timing, universal mod compatibility, or physical lighting calibration has been claimed.
