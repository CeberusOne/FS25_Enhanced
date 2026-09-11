# Expert-path caps (v0.3.2.0)

**Branch:** `feature/experimental-caps`  
**Gate:** `expertMode` (default `false`) + Soft-Apply (default `false`)

## allowsApply contract

| expertMode | Allowed statuses |
|---|---|
| `false` | `CONFIRMED` only (Wave1 unchanged). `APPLIED` with `baseStatus=CONFIRMED` also allowed. |
| `true` | + `EXPERIMENTAL` \| `GATED` \| `ASSET_DEPENDENT` (and their `APPLIED`) |

`REJECTED` / `UNSUPPORTED` never allowed. Materials omitted.

## APPLIED-capable (wired through CapabilityApplier / ExperimentalCaps)

| capabilityId | status | notes |
|---|---|---|
| shadow-focus-box | EXPERIMENTAL | restore `setShadowFocusBox(0)` |
| fast-shadow-update | EXPERIMENTAL | |
| rain-shallow-water-simulation | EXPERIMENTAL | |
| ssr-quality | GATED | `getSupportsScreenSpaceReflectionsQuality` before set |
| atmosphere-quality | GATED | `getSupportsAtmosphereQuality` before set |
| drs-quality | GATED | `getSupportsDRSQuality` before set |
| light-ies-profile | ASSET_DEPENDENT | requires `lightId` + `*.ies` path |
| rain-* (CONFIRMED suite) | CONFIRMED | Expert soft-apply entry; shallow-water excluded |

## Stubs / query-only

| capabilityId | status | notes |
|---|---|---|
| light-ies-cone-angle | ASSET_DEPENDENT | query-only |
| foliage-bending-create | ASSET_DEPENDENT | stub → `REJECTED` (no scene handle) |
| supports-ssr/atmosphere/drs-quality | GATED | query-only gates |

## Soft-Apply

- `expertSoftApply` / `ExperimentalCaps.setSoftApplyEnabled` default **false**
- User must enable `expertMode` + Soft-Apply (console `fs25eExpertMode` / `fs25eExpertSoftApply`, or settings)
- Never auto on load; no `saveHardwareScalability` / `setTerrainQuality` / `applyPerformanceClass`

## Setting key (v0.4.2.x)

`rainShallowWater` is the single key for GUI, Live-Overlay, Soft-Apply, and `liveApply`. Legacy `expertRainShallowWater` aliases to it in ModSettings.
