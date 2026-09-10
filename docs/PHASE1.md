# Phase 1 — v0.1 PoC Core

**Branch:** `feature/skeleton`  
**Author:** CeberusOne  
**Goal:** Loadable FS25 Lua mod skeleton. Mission-level service only (no vehicle Spec).

## What is implemented

| Module | Role |
|--------|------|
| `modDesc.xml` | descVersion **106** (TODO verify ModHub guideline downloadId=124; **not** 72), MP supported, EN+DE, l10n, extraSourceFiles order |
| `scripts/FS25_Enhanced.lua` | Bootstrap; captures `g_currentModName` / `g_currentModDirectory`; mission hooks; `update(dt)` |
| `HookManager` | `Utils.prepended/appended/overwrittenFunction` only; `uninstallAll` |
| `CapabilityRegistry` | Status enum + query API; loads stub XML; **no setters** |
| `SettingsCache` | original / current / requested / auto / locked |
| `SettingsSchema` | Runtime defaults table + GUI-oriented schema stubs (MultiText/binary; no sliders) |
| `ModSettings` | Prepares `getUserProfileAppPath()` → `modSettings/FS25_Enhanced/` (no heavy persist) |
| `RestoreManager` | Cache restore on deleteMap; `unload()` also uninstalls hooks; safe no-op |
| `PerformanceMonitor` | Sliding frame-time from `dt`; spike/variance; target budget; **no getFps** |
| `GraphicsGovernor` | Fast/Medium/Slow + hysteresis stubs; **no engine writes** |
| `CompatibilityManager` | Soft detection stub |
| `Debug` | Prefixed `[FS25_Enhanced]` logging; `pcall` helper; never `Logging.fatal` for optional nodes |
| Config / l10n | `capabilityProfiles.xml`, `defaults.xml`, `presets.xml`, `l10n_en.xml`, `l10n_de.xml` |
| GUI prep (docs) | `config/settingsSchema.stub.lua`, `docs/settings-schema.md`, `docs/gui-design.md` — data/docs only, not engine-wired |

## Intentionally not wired (blocked until Research Freeze)

- **No live engine graphics setters:** `setShadow*`, `setLight*`, `set*DistanceCoeff`, `setRain*`, SettingsModel quality writers, `applyPerformanceClass` / `saveHardwareScalability` writes
- Lights Spec / EnhancedLightsProbe
- GUI / InGameMenu frames (schema stubs only)
- SceneAnalyzer (full), BudgetAllocator, CalibrationManager
- Live Shadow / Lighting / Weather / LOD managers
- Network `Event` for quality (client-local only)
- Binary / DLL / memory hooks

## Mission lifecycle (NO-OP-safe)

1. **load** — init managers behind `pcall`; governor stays **disabled**; ModSettings path prepared
2. **update(dt)** — early-out if not initialized; feed PerformanceMonitor; Governor update is no-write
3. **delete** — disable governor; reset monitor; `RestoreManager.restoreAll()` (cache only; **hooks retained** for in-session reload)

Missing mission classes / XML / profile path APIs log warnings and continue.

## Test plan

1. Place mod in FS25 `mods/FS25_Enhanced`
2. Load a single-player map; confirm `[FS25_Enhanced]` bootstrap / loadMap logs
3. Play briefly; no crashes; PerformanceMonitor uses `dt` only (no `getFps`)
4. Exit mission; confirm deleteMap + restoreAll logs
5. Reload savegame in same session; hooks still active (not uninstalled on delete)

## descVersion note

Using **106** (common FS25 community template). Confirm against current ModHub Creation Guidelines (GDN downloadId=124) before ModHub upload. Do **not** use eBook example `72`.
