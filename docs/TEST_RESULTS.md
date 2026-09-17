# Prüfbericht FS25 Enhanced 0.5.5.0

Stand: 2026-09-11T19:56:54

**45 Prüfgruppen bestanden; 0 fehlgeschlagen.** Katalog: 114 Einträge einschließlich Presets, Profilaktionen und Statusanzeige. Die tatsächliche Verfügbarkeit hängt von nativen APIs und geladenen Assets ab.

Geprüft wurden Lua-Code und nativer Datenfluss mit Engine-Ersatzfunktionen, echte GIANTS-Menümethoden, SDK-Signaturen, originale Regenassets und Fahrzeugshader. Kein neuer FS25-Lauf, keine Pixel-/FPS-Messung und keine vollständige Karten-/Mod-Kompatibilitätsfreigabe. Die reale Logdatei vor Installation gehört zum vorherigen Build und ist kein Testbeleg für 0.5.5.0.

## Ergebnisse

- PASS `test_applier_audit`
- PASS `test_bootstrap_guards`
- PASS `test_core_compatibility`
- PASS `test_core_light_profiles`
- PASS `test_core_real_ab`
- PASS `test_environment_lighting`
- PASS `test_environment_modules`
- PASS `test_gui_lifecycle`
- PASS `test_integration_environment`
- PASS `test_light_request_mask`
- PASS `test_lighting_material_effects`
- PASS `test_lights_native`
- PASS `test_live_text_state`
- PASS `test_live_ui`
- PASS `test_manual_environment_reset`
- PASS `test_manual_legacy_startup`
- PASS `test_manual_mode`
- PASS `test_manual_presets`
- PASS `test_manual_reset_feedback`
- PASS `test_material_replacement`
- PASS `test_material_world_link`
- PASS `test_native_cursor_restore`
- PASS `test_native_f9`
- PASS `test_native_menu_crash`
- PASS `test_native_selection`
- PASS `test_particle_manual`
- PASS `test_placeable_light_groups`
- PASS `test_probe_session`
- PASS `test_repairs`
- PASS `test_restore_integration`
- PASS `test_runtime_probe`
- PASS `test_runtime_probe_review`
- PASS `test_sandbox_reads`
- PASS `test_scene_context`
- PASS `test_sunlight_native`
- PASS `test_visual_profiles`
- PASS `test_weather_giants_lifecycle`
- PASS `test_weather_safety`
- PASS `test_native_selection_layout`
- PASS `smoke_bootstrap`
- PASS `check_syntax`
- PASS `test_localization_validator`
- PASS `validateConfig`
- PASS `validateLocalization`
- PASS `test_material_stock_classification`

## Ersetzte Anforderungen

- `test_core_native_menu.lua`: duplicate wrapper of test_native_menu_crash
- `test_core_adaptive.lua`: automatic budget/calibration policy removed; test_manual_mode replaces it
- `test_core_lifecycle.lua`: timed Cinematic and calibration removed; manual reset/preset lifecycle replaces it
- `test_scope_presets.lua`: radius-gating requirement withdrawn; test_manual_presets covers global presets
- `test_visible_scope.lua`: radius requirement withdrawn; test_manual_mode and module regressions cover global access
- `test_core_simple_menu.lua`: old four-tab dialog is no longer loaded; test_native_f9 and selection tests replace it

Der alte Dialog-Geometrietest und der alte Sechs-Regler-Runtimetest wurden durch native Seiten-/Übergangstests und test_manual_mode ersetzt. Radius- und Automatiktests werden nicht als bestanden ausgegeben; die entsprechenden Anforderungen wurden auf ausdrücklichen Nutzerwunsch entfernt.
