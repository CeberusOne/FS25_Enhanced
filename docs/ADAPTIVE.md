# Adaptive / Casual-Automatik (Wave-1)

**Simple UX:** Mod an + Adaptive an + Target-FPS → Governor hält die Ziel-FPS über **Wave-1 CONFIRMED** Caps.

## What it DOES

- Watches frametime vs Target-FPS (`PerformanceMonitor`, dt-based — no fake sensors).
- With hysteresis, switches presets: **Performance / Balanced / Quality** (never Cinematic via Adaptive).
- Applies preset targets through `ProfileManager.applySelected` → `LodGovernor` / `ShadowManager` (session-only).
- Optional **fine nudge** (~2s): scales Wave-1 distance coeffs and `maxNumShadowLights` toward documented floors/ceils using FPS pressure + `SceneAnalyzer.getLoadHint()`.
- Uses `loadHint` to avoid climbing to Quality in heavy scenes (vehicle/fog/rain/night).

## What it does NOT do

- No Expert / Experimental / GATED auto-apply.
- No Giants-Slider, no `saveHardwareScalability`, no `setTerrainQuality` fast-path.
- No invented CPU/GPU/VRAM numbers (telemetry is separate / optional sidecar).
- Does not run when `enabled=false` or Adaptive off.

## Defaults (safe)

| Key | Default |
|-----|---------|
| `enabled` | false |
| `adaptive` / `autoApply` | false (synced; Adaptive is the Simple toggle) |
| `targetFps` | `60` |
| `softApply` / `expertMode` | false |

## Manual preset

Choosing a preset **explicitly** turns Adaptive off, applies that preset once (if Mod enabled), then stays put.

## Restore

Map-leave / mod disable still goes through existing RestoreManager / vanilla restore — unchanged.
