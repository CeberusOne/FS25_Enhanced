# Pro Live HUD / Overlay — Core interfaces

**Branch:** `feature/pro-live-hud-core`  
**For GUI:** `feature/pro-live-hud`

## Live overlay (all matrix caps)

- `FS25E_SettingsAPI.liveListCaps()` → array of `{id,status,cost,warn,allowsApply,...}`
- Existing: `liveGet` / `liveSetRequested` / `liveApply` / `liveApplyRequested` / `liveRestore`
- Cost: `FS25E_SettingsAPI.getCapCost(id)` + `config/costCatalog.xml`

## HUD telemetry

- `FS25E_SettingsAPI.getHudTelemetry()` → `{ engine=PerformanceMonitor snapshot, system=TelemetryReader snapshot }`
- Engine (CONFIRMED): `fpsAvg`, `fpsLast`, `frameMsAvg`, `frameMsLast` from **dt only**
- System: only if sidecar wrote `modSettings/FS25_Enhanced/telemetry.json`; else `connected=false` / DISCONNECTED — **no fake numbers**

## Sidecar file schema (Windows first)

```json
{
  "timestamp": 1710000000,
  "cpuLoad": 0.42,
  "cpuTempC": 65.0,
  "gpuLoad": 0.71,
  "gpuTempC": 72.0,
  "vramUsedMB": 4200,
  "vramTotalMB": 12288,
  "ramUsedMB": 16000,
  "ramTotalMB": 32000,
  "backend": "LibreHardwareMonitor"
}
```

Poll ≤1Hz; stale >2s → disconnected. Pure Lua mod runs without sidecar.
