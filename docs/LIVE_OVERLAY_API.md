# Expert Live-Overlay API

**For:** FS25 GUI `feature/expert-live-overlay`  
**Module:** `scripts/Core/SettingsAPI.lua`  
**Widgets:** MultiTextOption / numeric text only — **no Giants Slider**

## Preferred apply path (GUI)

Do **not** call engine setters. Use only:

| Function | Role |
|----------|------|
| `FS25E_SettingsAPI.liveGet(capabilityId, opts?)` | Read `{requested,current,original,locked,status,lastResult}` |
| `FS25E_SettingsAPI.liveSetRequested(capabilityId, number, opts?)` | Cache float only |
| `FS25E_SettingsAPI.liveApply(capabilityId, number\|nil, opts?)` | Set requested (if number) + apply |
| `FS25E_SettingsAPI.liveApplyRequested(capabilityId, opts?)` | Apply cached requested |
| `FS25E_SettingsAPI.liveRestore(capabilityId, opts?)` | Session restore for that cap key |

`opts = { prefixArgs = { lightId }, keySuffix = "..." }` for per-light caps.

## Gates (unchanged)

- `expertMode` / Soft-Apply via existing ModSettings + Registry `allowsApply`
- `CapabilityApplier` still markApplied / REJECTED / SKIPPED
- GUI must not bypass Soft-Apply or call Lighting/Rendering setters directly

## Float storage

- Session: `SettingsCache.setRequestedNumber` (authoritative for live overlay)
- Persist of live floats: optional later; Gen-1 overlay may be session-only

## Example (0.01 step in GUI)

1. User edits MultiTextOption → tonumber → `liveSetRequested("view-distance-coeff", 1.25)`
2. Confirm / debounce → `liveApply("view-distance-coeff", 1.25)`
3. Status-Tab / Diagnostics reads `lastResult` / `liveGet`

## Pro Live HUD extensions (v0.4.2.0)

- `FS25E_SettingsAPI.liveListCaps()` — all registry caps + `cost` / `warn` from `config/costCatalog.xml`
- `FS25E_SettingsAPI.getCapCost(id)` — `{cost, warn, notes?}`
- `FS25E_SettingsAPI.getHudTelemetry()` — `{ engine=PerformanceMonitor.getSnapshot(), system=TelemetryReader.getSnapshot() }`
- Engine metrics: FPS/frametime from **dt only** (CONFIRMED). System metrics: optional sidecar `modSettings/FS25_Enhanced/telemetry.json`; stale >2s → DISCONNECTED. No fake numbers.
- See `docs/PRO_LIVE_HUD_CORE.md`.
