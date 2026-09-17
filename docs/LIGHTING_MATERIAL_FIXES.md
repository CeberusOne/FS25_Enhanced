# Lighting and material revision, 2026-09-11

Camera, frustum and radius restrictions have been removed from these modules. Global image brightness is available through the registered SettingsModel BRIGHTNESS reader, writer and option labels. Successful writes require native readback. Original brightness and unrelated pending vanilla options are preserved; this is full-image display brightness, not a replacement sunlight implementation.

Materials target every loaded vehicle reported by the GIANTS vehicle system. No camera, distance or eight-vehicle limit remains. Discovery processes 128 queued nodes per batch and continues on subsequent updates; it no longer permanently stops at 4096 nodes. Only vehicle component trees are visited, never the world scene root. Empty discovery is retried for delayed assets. Unchanged values avoid redundant private material writes.

Two material exclusions were corrected: clear-coat intensity zero is valid, and a missing base normal/gloss filename does not invalidate stock vehicleShader materials using custom detailNormal/detailSpecular arrays. Edits remain private to validated opaque, nonporous vehicleShader material slots. SSR controls require active screen-space reflections. Shader masks, detail maps, lighting and viewing angle still determine the visible result.

Artificial-light tuning uses cameraId/rainAmount, retains LIGHT_SOURCE checks and prefers active quality-profile aliases. All loaded active lamps receive color/range changes: no hidden 64-lamp cutoff or 0.7 range reduction remains. User-configured shadow, IES and scattering budgets still govern their respective features. Switched-off lamps report queued values. Global restore clears old light requests so a later individual slider does not revive previous adjustments.

Enabled now means readiness: the light adapter writes no defaults until a control or explicit preset creates a request. Each property family is independent. Color does not resize shadows; softness does not enable casting; a resolution request preserves casting state; scattering intensity does not silently enable scattering or use a default weather multiplier. Global reset clears the request mask. Persisted legacy softApply flags are inert, and the former specialization callback writer has been removed.

Primary references:

- [GIANTS SettingsModel](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=43&class=486&version=engine): registered readers/writers and brightness options.
- [GIANTS getShaderParameter](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=24&function=681&version=engine): material-slot readback.
- [GIANTS setShaderParameter](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=24&function=698&version=engine): private edits with explicit material index.
- [GIANTS getHasShaderParameter](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=24&function=674&version=engine): checks each material slot.
- Installed data/shaders/vehicleShader.xml: actual clear-coat parameter consumption, allowed zero values, detail arrays and SSR biases.
- Stock VehicleMaterial.applyToMaterial and RealLight.setCharge: actual per-slot material and lamp color writes.

Verification: test_lighting_material_effects.lua covers brightness readback/ownership, delayed matte assets, lamp queues/reset, and 300 globally selected vehicles processed in batches without a camera. It executes the real extracted GIANTS VehicleMaterial.applyToMaterial method and compares native parameters with this adapter; it also checks consuming expressions in the installed shader. Existing light, profile, type-check and environment tests pass. Native functions still use a test harness: no in-game visual pass is claimed.

test_light_request_mask.lua additionally counts native setter calls: startup and reset produce none; single-property requests preserve unrelated fields; explicitly requested preset fields combine; old softApply flags cannot initiate native writes.

Single-row light reset removes that request, restores its native property-family baseline, then reapplies the remaining requested controls. The regression verifies that resetting warmth keeps the requested intensity without substituting a generic white/color-temperature baseline. Resetting the final request stops subsequent writes; resetting a shadow budget restores the original casting state and resolution.
