# Wave 1 — CONFIRMED capability wiring

**Branch:** `feature/wave1-confirmed-setters`  
**Source matrix:** [capability-matrix.md](capability-matrix.md) (Research Freeze on `main`)  
**Version:** 0.2.0.0  
**Policy:** Client-local · session-only apply + restore · **auto-apply OFF** · no hardware profile writes

## Wired (CONFIRMED)

### Global / SettingsModel writers

| capabilityId | setter / getter | Manager |
|---|---|---|
| max-num-shadow-lights | set/getMaxNumShadowLights | ShadowManager |
| shadow-quality | set/getShadowQuality | ShadowManager |
| shadow-distance-quality | set/getShadowDistanceQuality | ShadowManager |
| shadow-filter-quality | set/getShadowFilterQuality | ShadowManager |
| view-distance-coeff | set/getViewDistanceCoeff | LodGovernor |
| lod-distance-coeff | set/getLODDistanceCoeff | LodGovernor |
| foliage-view-distance-coeff | set/getFoliageViewDistanceCoeff | LodGovernor |
| foliage-lod-distance-coeff | set/getFoliageLODDistanceCoeff | LodGovernor |
| terrain-lod-distance-coeff | set/getTerrainLODDistanceCoeff | LodGovernor |
| allow-foliage-shadows | set/getAllowFoliageShadows | LodGovernor |

Distance coefficients are clamped to **[0.5, 2.0]** (placeholder range; calibrate later — see [`docs/calibration-notes.md`](calibration-notes.md)).

### Per-light (Engine Lighting) — `lightId` required

| capabilityId | API | Notes |
|---|---|---|
| light-shadow-priority | set/getLightShadowPriority | |
| light-shadow-map | setLightShadowMap / getLightCastingShadowMap | |
| light-soft-shadow-size | set/getLightSoftShadowSize | |
| light-soft-shadow-distance | set/getLightSoftShadowDistance | |
| light-soft-shadow-depth-bias | set/getLightSoftShadowDepthBiasFactor | |
| merge-light-shadows | mergeLightShadows | Explicit API only; tracked |
| split-light-shadow | splitLightShadow | Restore path for merges |
| has-merged-shadow | hasMergedShadow | Query only (no setter) |

Soft discovery stub returns an **empty** light list until Lights Spec supplies ids. No blind world-node scan.

### Console smoke helpers (manual; Soft-Apply / autoApply OFF)

| Command | Manager API |
|---|---|
| `fs25eApplyLightSoft <lightId> <size> [distance] [bias]` | Soft-Shadow setters |
| `fs25eMergeLights <idA> <idB> [more…]` | `mergeLightShadows` |
| `fs25eSplitLight <lightId>` | `splitLightShadow` |
| `fs25eDumpMerges` | tracked merges dump |

`lightId` from `fs25eLightsDump` only. These commands do **not** enable Soft-Apply or `autoApply`.

## Explicitly excluded (Wave 1)

| Kind | Symbols / caps | Reason |
|---|---|---|
| EXPERIMENTAL | `setShadowFocusBox`, `setFastShadowUpdate`, `setRainShallowWaterSimulation` | Gen-1 risky — never called |
| GATED | SSR / Atmosphere / DRS (`setScreenSpaceReflectionsQuality`, `setAtmosphereQuality`, `setDRSQuality`) | Need `getSupports*` |
| RESTART | `setTerrainQuality` | Restart required — not on Fast path |
| Persistence | `saveHardwareScalability`, `applyPerformanceClass` | Session-only; no profile write without user opt-in |
| Rain suite | other `setRain*` | Not in Wave 1 confirmed set scope for this PR |

## Runtime behaviour

1. `CapabilityRegistry.load` parses `config/capabilityProfiles.xml`; Lua `WAVE1_FALLBACK` seeds the same list if XML soft-fails.
2. `CapabilityApplier.apply` requires `status=CONFIRMED`, `type(fn)=="function"`, `pcall`; on failure → `REJECTED` + restore that cap.
3. Originals cached in `SettingsCache` (`needsCalibration=true`); `UNKNOWN` applyMode → session apply.
4. `RestoreManager.restoreAll` (deleteMap): ShadowManager splits tracked merges → CapabilityApplier restores setters → SettingsCache. **Hooks stay installed.**
5. `GraphicsGovernor`: `enabled=false`, `autoApply=false`; logs `wave1 registered, auto-apply off`. Manager APIs remain callable explicitly.

## Config

See `config/capabilityProfiles.xml` (wave=`1`).

## Casual Adaptive (v0.4.2.2)

See `docs/ADAPTIVE.md`. Adaptive applies only Wave-1 preset targets + fine coeff nudge; never Expert caps.
