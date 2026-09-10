# FS25 Enhanced — Kurzvergleich User-Plan vs. Optimalplan

**Dateien:**  
- Optimalplan: `/workspace/fs25-enhanced-mod-optimal-plan.md`  
- Quelle User: PDF `FS25_Enhaced` Umsetzungsplan  
- Quelle GDN: `/workspace/fs25-gdn-giants-engine-research.md` + LuaDoc v1.20.0.0

## Übernommen
- Adaptiver Graphics-Governor, Presets, Target-FPS, Hysterese, Budget, Scene Analyzer
- Capability-Registry + Research Freeze vor Feature-Bau
- Keine Binary-/Rendergraph-Hooks in Gen 1
- Shadows/Lighting/IES/Scattering/Merge/Focus-Idee, LOD/Foliage, Rain/Particles
- Restore, Fail-Safe, Locks, Live-Tuning, Lokalisierungs-Keys
- Water/Materials/Reflections erst experimentell / nach 1.0

## Geändert / korrigiert
1. Name: **FS25_Enhanced** (Tippfehler „Enhaced“)
2. Kein Pre-Render-Injection — nur dokumentierte Setter mit Wirkung in Folgerahmen
3. Einstieg über **modDesc / extraSourceFiles / Mission-Updateable**; optional Lights-Specialization
4. APIs an **SettingsModel + Engine Lighting/Rendering/Precipitation/…** gebunden
5. Shadow Focus / Fast Update = echte APIs (`setShadowFocusBox`, `setFastShadowUpdate`), aber EXPERIMENTAL
6. LOD/Foliage über `*DistanceCoeff`-Setter, Rain über `setRain*`
7. Governor **client-lokal** (kein Network-Event für Qualität)
8. Tooling: **VS Code FS IDE**, nicht GIANTS Studio
9. Sprachen gestaffelt (Framework sofort, nicht 27 Locales als Alpha-Gate)
10. Performance Class / Upscaler-Konflikte aktiv respektieren

## Größte Lücken im Original
- Kein konkreter modDesc-/Lifecycle-/SettingsModel-Pfad
- Keine Anbindung an Spec `Lights` / RealLights
- Viele Features ohne belegtete Funktionsnamen
- MP-/Persistenz-Politik unklar

## Empfohlener Start nach Freigabe
Research Freeze → Skeleton-Mod → Shadow Priority/MaxLights → Lights-Probe → Distanz-Coeffs → EN/DE-GUI

## Community-Nachzug
- Hook/Restore-Lifecycle, modSettings-Trennung, Capability-Gates, MP client-lokal, Schema-GUI ohne Slider, Timer-Monitor
- Soft CompatibilityManager, Hotkeys/Key-Konflikt, Expert-Mode später
- Keine schweren Syncs, keine undokumentierten Memory-Hooks, keine Draw-Distance-Blindboosts
