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
