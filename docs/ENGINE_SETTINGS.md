# Engine-Quellen – 0.6.0.0

Nur dokumentierte Live-Setter. Kein geratener PostFX-Pass.

| Gruppe | Quelle |
| --- | --- |
| Qualitäts-Enums, SSAO, Wolkenschatten, Filter, Tessellierung, Reifenspuren | `SettingsModel.lua` |
| LOD-/Sichtweiten-Koeffizienten | globale Engine-Getter/Setter |
| Tonwertkurve, Spotschatten-Atlas | `sdk/scriptBindingChanges.txt`, mit Readback |
| FOV, Spiegel, Lichtprofil | `g_gameSettings` |
| Sonne / God Rays / Sonnenschattenkarte | Lighting an `sunLightId` |
| Lack | `vehicleShader.xml` `clearCoat*` / `ssrParameters` |
| Nässe | `setWetness` / placeable- und building-Shader |
| Vegetation | `treeBranchShader.xml`, `fruitGrowthFoliageShader.xml` |

Bewusst nicht im Mod: MSAA, DLSS/FSR/XeSS, VRS, DRS, Textur-/Shaderqualität, `terrain-quality` (Neustart), `setShadowFocusBox`, `setFastShadowUpdate`, Belichtung, Bloom, Color Grading.
