# Pro Live HUD + Expert Live-Overlay GUI (v0.4.2.1)

**Branch:** `feature/pro-live-hud-gui`  
**Modules:** `scripts/UI/FS25E_LiveOverlay.lua`, `scripts/UI/FS25E_HudOverlay.lua`  
**Core docks:** `docs/PRO_LIVE_HUD_CORE.md`, `docs/LIVE_OVERLAY_API.md`

## Purpose

Hard-dock the Expert Live-Overlay and a lightweight Pro HUD against Core SettingsAPI extensions shipped in v0.4.2.0:

| API | GUI use |
|-----|---------|
| `liveListCaps()` | Primary source of fine-tune rows (not hardcoded-only) |
| `getCapCost(id)` / cap `cost`+`warn` | Cost badge beside each row; warn styling when `warn=true` |
| `getHudTelemetry()` | Engine FPS/frametime + optional system sidecar |
| `liveGet` / `liveSetRequested` / `liveApply` / `liveRestore` | Apply / cache / restore only — **no engine setters from GUI** |
| `Diagnostics.getStatusForSetting` + Registry listeners | Row status APPLIED / REJECTED / SKIPPED |

## Overlay fine-tune list

1. Call `FS25E_SettingsAPI.liveListCaps()`.
2. Filter: `scope=global`, non-`NONE` setter, skip multi-arg / query-only / per-light (no lightId UI yet).
3. Prefer `allowsApply`; with `expertMode` also list EXPERIMENTAL/GATED/CONFIRMED globals.
4. Merge `ROW_META` for Wave-1/Expert ordering, ranges, labels; unknown caps get inferred float/int/bool ranges (0.01 fine-tune where applicable).
5. Fallback to `ROW_META` only if `liveListCaps` is empty.
6. Custom text bars / toggles — **no Giants Slider**.

### Soft-Apply (unchanged)

- Expert rows (`applyKind=expert`: rain suite, GATED qualities, EXPERIMENTAL bools): Soft-Apply **OFF** → `liveSetRequested` only + row **SKIPPED**; **ON** → `liveApply`.
- Wave-1 CONFIRMED coeffs / shadow globals → `liveApply` (Registry `allowsApply` still enforced in Core).

### Cost / warn

- Badge shows `LOW` / `MED` / `HIGH` / `EXTREME` from cost catalog.
- `warn=true` → warm row tint + `!` on cost + notes on selected row.

## HUD behavior

| Mode | When | Content |
|------|------|---------|
| Header HUD | Live Overlay open | Engine `fpsAvg/fpsLast/frameMsAvg/frameMsLast` + System (real sidecar or **DISCONNECTED**) |
| Mini corner HUD | `liveTuningEnabled` and overlay **closed** | Compact same metrics |

**Never invent** CPU/GPU/VRAM/RAM numbers. System metrics only when `system.connected==true` from `TelemetryReader` (sidecar `modSettings/FS25_Enhanced/telemetry.json`).

## Hotkeys

| Input | Action |
|-------|--------|
| **Ctrl+Shift+E** | Toggle Live Overlay (`FS25E_TOGGLE_LIVE_OVERLAY`) |
| Esc | Close overlay |
| +/- / arrows / wheel | Nudge selected row |
| R | `liveRestore` selected capability |
| PgUp/PgDn | Scroll long cap list |
| Console `fs25eLiveOverlay [0\|1]` | Force show/hide |

Gates: `expertMode` + `liveTuningEnabled` (unchanged).

## Files

- `scripts/UI/FS25E_LiveOverlay.lua` — expanded overlay
- `scripts/UI/FS25E_HudOverlay.lua` — telemetry draw helper + mini HUD
- `l10n/l10n_en.xml` / `l10n/l10n_de.xml` — HUD + extra row labels
- `docs/expert-live-overlay.md` — points here for Pro HUD docks

## Constraints

- No engine setters from GUI
- No fake telemetry numbers
- No Giants Slider widgets
