# Phase 2 — v0.3 Governor + Scene

**Branch:** `feature/phase2-scene-governor`  
**Base:** `origin/main` after Wave 1 merge  
**Version:** **0.3.0.0** (Wave 1 present on main → bump from 0.2.0.0)  
**Author:** CeberusOne

## Version choice

Wave 1 (`feature/wave1-confirmed-setters`) was merged to `main` before this PR. Phase 2 therefore ships as **0.3.0.0** (not 0.2.1.0). ShadowManager / LodGovernor / CapabilityApplier remain available; Phase 2 does **not** turn on auto-apply and does **not** add new automatic engine setter call sites.

## What Phase 2 does

| Module | Role |
|--------|------|
| `SceneAnalyzer` | Read-only snapshot from `g_currentMission` when available: camera/player/vehicle hints, environment hour/sun/weather/fog/rain flags (nil-safe). Medium (250 ms) refresh / Slow (1 s) log cadence. **No engine writes.** |
| `GraphicsGovernor` | Fast/Medium/Slow timers; hysteresis bands around PerformanceMonitor target frame-time (`avg > 1.10×budget` → FAST, `avg < 0.80×budget` → SLOW, else MEDIUM; SceneAnalyzer load hint can veto SLOW). Computes `desiredMode` / `desiredPreset`. Default `enabled=false`, `autoApply=false`. Observes even when disabled (throttled slow-tick logs). |
| `ProfileManager` | Loads `config/presets.xml` (Performance / Balanced / Quality / Cinematic) with Lua fallback. `selectPreset` fills **SettingsCache requested** slots only (respects locks). **No engine apply.** |
| `ConsoleCommands` (optional) | Soft-registers `addConsoleCommand` helpers for manual tests. Never sets `autoApply=true`. |
| `PerformanceMonitor` | Unchanged; still feeds dt statistics. |

## What Phase 2 does **not** do

- No automatic engine setter calls from Phase-2 decision paths (SceneAnalyzer / ProfileManager / governor observe path).
- Does not enable `GraphicsGovernor.autoApply` by default (and console `fs25eGovernor` keeps autoApply false).
- No EXPERIMENTAL setters (`setShadowFocusBox`, `setFastShadowUpdate`, …).
- No `saveHardwareScalability` / `applyPerformanceClass` / `setTerrainQuality`.
- No GUI / BudgetAllocator / CalibrationManager.
- No network sync of quality values (client-local only).

## Gate

- **dt statistics stable** via existing PerformanceMonitor.
- **No new engine writes** beyond Wave-1 Manager/Applier APIs already on main.
- Mission load / update / delete remain NO-OP-safe if mission nil (`pcall` boundaries, `FS25E_Debug` logging).

## Optional console commands

Require development controls (`game.xml` `<development><controls>true</controls></development>`). If `addConsoleCommand` is missing, registration soft-fails and stubs remain callable from Lua.

| Command | Purpose |
|---------|---------|
| `fs25eDumpCaps` | Dump capability registry |
| `fs25eDumpScene` | Dump SceneAnalyzer + governor + perf snapshot |
| `fs25eApplyLodCoeff <f>` | Manual `LodGovernor.setViewDistanceCoeff` |
| `fs25eApplyMaxShadowLights <n>` | Manual `ShadowManager.setMaxNumShadowLights` |
| `fs25eRestore` | `RestoreManager.restoreAll` |
| `fs25eSelectPreset <name>` | Cache-only preset select |
| `fs25eGovernor <0\|1>` | Enable observe/decision; **never** enables autoApply |

## Test plan

1. Install mod; load SP map — log shows bootstrap `phase2 v0.3.0.0`, SceneAnalyzer init, GraphicsGovernor `phase2 registered; enabled=false autoApply=false`.
2. Play ~15 s — throttled `[SceneAnalyzer] slow tick` / `[GraphicsGovernor] slow tick` lines; PerformanceMonitor averages advance; **no** unexpected setter errors.
3. Exit mission — deleteMap + restore path; no errors.
4. (Optional, with console) `fs25eDumpScene`, `fs25eSelectPreset Balanced`, `fs25eApplyLodCoeff 1.0`, `fs25eRestore` — manual only.

## Confirmation: Phase-2 modules and setters

Phase-2-authored modules (`SceneAnalyzer.lua`, `ProfileManager.lua`, governor decision/observe path, bootstrap wiring) do **not** introduce new engine setter call sites. Manual console helpers deliberately call existing Wave-1 Manager APIs only when the user types a command.
