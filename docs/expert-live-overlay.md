# Expert Live-Overlay (GUI)

**Version:** 0.4.2.1  
**Module:** `scripts/UI/FS25E_LiveOverlay.lua`  
**Depends on Core:** `SettingsAPI.live*` (merged via PR #21) + `Diagnostics.getStatusForSetting` (PR #22)

## Purpose

In-world overlay (not a fullscreen dialog) for fine-grained float tuning of Wave-1 + Expert caps.
Custom drawn bars / toggles — **no Giants GuiSlider / Slider profiles**.

## Gates

```lua
expertMode == true AND liveTuningEnabled == true
```

Toggle without gates → notification `FS25E_LIVE_OVERLAY_GATE_REQUIRED`.

## Hotkey / entry points

| Entry | Action |
|-------|--------|
| **Ctrl+Shift+E** | `FS25E_TOGGLE_LIVE_OVERLAY` |
| Legacy `FS25E_LIVE_HINT` | Routes to same toggle |
| Expert-tab button | Sets `liveTuningEnabled=true`, closes dialog, `Overlay.toggle(true)` |
| Console | `fs25eLiveOverlay [0\|1]` |

## Apply path (hard dock — no engine setters from GUI)

| Call | Role |
|------|------|
| `FS25E_SettingsAPI.liveGet(capabilityId, opts?)` | Read requested/current/status |
| `FS25E_SettingsAPI.liveSetRequested(capabilityId, number, opts?)` | Cache float only |
| `FS25E_SettingsAPI.liveApply(capabilityId, number\|nil, opts?)` | Set + apply (managers / CapabilityApplier) |
| `FS25E_SettingsAPI.liveApplyRequested(capabilityId, opts?)` | Apply cached |
| `FS25E_SettingsAPI.liveRestore(capabilityId, opts?)` | Session restore |

Example: `liveApply("view-distance-coeff", 1.25)`.

### Expert Soft-Apply

Expert rows (`rain-amount-mult`, gated qualities, bool EXPERIMENTAL caps):

- **`expertSoftApply` ON** → `liveApply` (Registry gates unchanged)
- **OFF** → `liveSetRequested` only + row status **SKIPPED** (“value stored, not applied”)

Wave-1 CONFIRMED coeffs/shadow lights always use `liveApply` (subject to Registry `allowsApply`).

## Diagnostics hybrid (read-only)

1. Overlay **open** → `FS25E_Diagnostics.getSnapshot()` then refresh each row via `getStatusForSetting(settingId)` (fallback: `getCapRuntime` / `getLastResult`)
2. Listeners `CapabilityRegistry.onApply` / `onReject` / `onSkip` → refresh **affected** capability row only
3. Overlay never writes Diagnostics

Status badges per row: `APPLIED` / `REJECTED` / `SKIPPED`.

## Parameters (0.01 float steps unless noted)

> **v0.4.2.1:** Primary list from `SettingsAPI.liveListCaps()`; table below is preferred Wave-1/Expert meta/order. Additional global caps appear with inferred ranges.


| Overlay id | capabilityId | Range | Kind |
|------------|--------------|-------|------|
| viewDistance | view-distance-coeff | 0.50–1.50 / 0.01 | Wave-1 |
| lodDistance | lod-distance-coeff | 0.50–1.50 / 0.01 | Wave-1 |
| foliageViewDistance | foliage-view-distance-coeff | 0.50–1.50 / 0.01 | Wave-1 |
| foliageLodDistance | foliage-lod-distance-coeff | 0.50–1.50 / 0.01 | Wave-1 |
| terrainLodDistance | terrain-lod-distance-coeff | 0.50–1.50 / 0.01 | Wave-1 |
| maxShadowLights | max-num-shadow-lights | 1–8 / 1 | Wave-1 |
| rainAmountMult | rain-amount-mult | 0.00–2.00 / 0.01 | Expert |
| ssrQuality | ssr-quality | 0–3 / 1 | Expert |
| atmosphereQuality | atmosphere-quality | 0–3 / 1 | Expert |
| drsQuality | drs-quality | 0–3 / 1 | Expert |
| shadowFocus | shadow-focus-box | bool | Expert |
| fastShadowUpdate | fast-shadow-update | bool | Expert |
| rainShallowWater | rain-shallow-water-simulation | bool | Expert |

## Draw / input

- Hook: `FSBaseMission.draw` (appended) + optional `mouseEvent` / `mouseWheelEvent` / `keyEvent`
- Primitives: `renderText` / `setTextColor` / `drawFilledRect` when present; else text bar `[████░░]`
- Esc closes overlay (does not open Settings)
- Persist: session via `SettingsCache` (`setRequestedNumber`); Gen-1 float ModSettings persist optional / session-only marked in UI

## See also

- `docs/LIVE_OVERLAY_API.md` — Core live* contract
- `docs/EXPERT_CAPS.md` — Expert capability list
- `docs/CAPABILITY_HOOKS.md` — APPLIED/REJECTED/SKIPPED listeners

## Pro Live HUD (v0.4.2.1)

See `docs/pro-live-hud-gui.md` for `liveListCaps` / cost-warn / `getHudTelemetry` docks and mini HUD behavior.
