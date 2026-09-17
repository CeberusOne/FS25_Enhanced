# FS25 environment API audit — 2026-09-11

Read-only audit for the separate EnvironmentLighting provider. Existing atmosphere and local-lamp controls remain the integration owner's responsibility. No visual effect was verified inside the running game.

## Verified reversible native parameters

Installed contract: `D:/SteamLibrary/steamapps/common/Farming Simulator 25/sdk/debugger/scriptBinding.xml`. Each following pair accepts a light entity as its first argument; require a live `ClassIds.LIGHT_SOURCE` and preserve its actual native getter result before writing.

| Getter / setter suffix | Value | Notes |
| --- | --- | --- |
| `LightScatteringIntensity` | float | Getter and setter present. Finite values only; readback verifies state, not perceptual visibility. |
| `LightScatteringConeAngle` | float | Getter and setter present. Neither binding nor GDN specifies the unit; do not label this as degrees without further evidence. |
| `LightScatteringDirection` | x,y,z | Preserve the complete tuple. |
| `LightUseLightScattering` | boolean | Scattering remains conditional on rendering/environment state. |
| `LightShadowExtrusionDistance` | float | How far behind the camera, from the light's perspective, shadow casters remain relevant. |
| `LightSoftShadowSize` | float | Getter and setter present. |
| `LightSoftShadowDepthBiasFactor` | float | Getter and setter present; not a brightness control. |
| `LightSoftShadowDistance` | float | Fixed surrogate light distance for directional-light soft shadows; ignored for spot lights. |
| `LightShadowPriority` | float | Selection priority when too many shadow lights are on screen; not shadow intensity. |

The public original `dataS/scripts/placeables/specializations/PlaceableSolarPanels.lua:190` accesses `g_currentMission.environment.lighting.sunLightId`. Validate this owner, do not search arbitrary scene lights. Environment updates can change native lighting; any persistent override must preserve freshly observed vanilla values and avoid reading its own previous transformed tuple as the baseline.

`setLightScatteringColor(lightId,r,g,b)` exists, but no corresponding getter was found. `getLightColor` is a different property and cannot supply this baseline. Only an actual observed stock setter tuple could make this reversible.

GDN FS25 1.20 primary references inspected:

- [Scattering intensity setter](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=11&function=211&version=engine)
- [Scattering intensity getter](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=11&function=189&version=engine)
- [Scattering cone angle setter](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=11&function=209&version=engine)
- [Scattering enabled setter](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=11&function=218&version=engine)
- [Current rendering API index](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=22&function=596&version=engine)

## Existing renderer quality options

Original `dataS/scripts/gui/base/SettingsModel.lua:288-291` registers `getAtmosphereQuality/setAtmosphereQuality`, `getLensFlareQuality/setLensFlareQuality`, and `getVolumetricFogQuality/setVolumetricFogQuality`, alongside matching `getSupports...` functions and enum types. These generated APIs are proven by stock script even though their names are absent from the binding file. They are discrete quality settings, not arbitrary fog density, exposure, or lens-flare intensity. Reuse existing controls; do not mislabel them as new effects. Hardware support must be checked for each enum value.

The same file contains brightness/HDR/overlay display setting names and UI ranges, but their implementation functions are not published in this source snapshot. Those UI references alone are insufficient to establish a direct exposure adjustment contract.

## Authored visual features without a verified live Lua contract

Inspected installed `data/maps/mapUS/config/environment.xml` and `colorGrading.xml` plus corresponding EU/AS/default resources. The environment authors:

- Auto-exposure curves with key luminance, minimum and maximum exposure; fixed-exposure curves.
- Bloom magnitude/threshold; tone-mapping slope, toe, shoulder, black/white clipping.
- Lens-flare intensity, saturation, shape/threshold and other coefficients.
- Day/night color-grading resource selection.
- Primary/secondary extraterrestrial color, light-scattering rotation, sun/moon brightness and size, asymmetry factor.
- Ground/height fog and cloud definitions.

Color-grading XML contains saturation, contrast, gamma and gain RGB/scales for global, shadows, midtones and highlights. These files prove rendering features exist. They do not establish the private runtime Lighting object layout, a reversible Lua setter, or a supported live XML/LUT swap. Do not invent `setExposure`, `setColorGrading`, `setBloom`, `setFog` or private fields from their XML names.

No matching current public live contract was found across the installed binding, published original scripts or GDN FS25 Rendering. This is a bounded evidence statement, not proof that GIANTS has no internal implementation. Ancient GDN `setFog` posts concern FS2009/2011 and do not justify use in FS25.

## Shader-overlay boundary

The native `getHasShaderParameter/getShaderParameter/setShaderParameter` APIs belong to Shape and operate on existing shape materials/custom shader parameters. They do not create a global screen-space post-processing pass. `POST_DIFFUSE_COLOR_FS` injections in installed material shaders are material pipeline hooks, not proof of full-screen processing support.

The inspected Overlay API exposes image/texture overlays, color, corners, UV, rotation, layer and rendering operations. No public overlay custom-shader, scene-color capture or postFX chain insertion was found. A transparent colored HUD rectangle is a 2D tint; presenting that as color grading, exposure, HDR, sharpening or a physically based atmosphere shader would be misleading.

## Follow-up: exposure console command lead

[FS25 console command list on the GIANTS forum](https://forum.giants-software.com/viewtopic.php?t=210083) includes `gsSetFixedExposureSettings keyValue, minExposure, maxExposure`, plus auto-exposure and tone-mapping debug commands. This is a player's help/log listing posted on November 22, 2024, hosted by GIANTS; it is not a GIANTS-authored current Lua API contract. No getter, original-state query, documented restore operation or Lua callback implementation is supplied. A GIANTS QA employee later responds to an unrelated field command in the thread; that reply does not validate exposure semantics.

Searching the currently installed `scriptBinding.xml` and published original `dataS/scripts` for exposure and the exact command names found no relevant function implementation. Thus this is useful evidence that a debug command existed in a reported FS25 build, but insufficient evidence for a reversible mod feature or fullscreen shader pipeline. No command was executed or added to production. Next admissible evidence would be the actual current callback/registration contract and its native state getter, or an observed complete pre-override tuple with a proven reset lifecycle; guessing command execution and map-default values would not meet that bar.

## Related weather regression corrected during this audit

User log at 19:18:38 reported `asset load observed` then `asset capture missing XML or scene API`. `WeatherManager.captureAsset` incorrectly required `deleteXMLFile`, absent from current installed native exports; FS25 provides `delete(xmlHandle)`. The narrow fix selects this native cleanup fallback and reports each missing API by name. The lifecycle regression now checks required names against the actual installed binding and deliberately exposes only `delete`, then executes actual installed GIANTS I3DManager sync/async methods against stock rain XML. Tests confirm real authored baseline propagation to precipitation geometry, cleanup, weather reload and restore within the fixture; this is not an in-game visual test. Rain-amount floor remains 0.01.
