# Diagnostics / Diagnose

**EN** · Runtime apply/reject/restore diagnostics for FS25_Enhanced (v0.3.2.0+). Read-only for GUI; **never** enables Soft-Apply or `autoApply`.

**DE** · Laufzeit-Diagnose für Apply/Reject/Restore (ab v0.3.2.0). Nur lesend für die GUI; aktiviert **niemals** Soft-Apply oder `autoApply`.

## Console commands / Konsolenbefehle

| Command | Purpose (EN) | Zweck (DE) |
|---------|--------------|------------|
| `fs25eDumpCaps` | Dump registry + `lastResult` / `lastError` when Diagnostics is present | Registry + ggf. `lastResult` / `lastError` |
| `fs25eCapStatus` | Aggregated cap status snapshot (counts + per-cap last result) | Aggregierter Cap-Status (Zähler + letzter Result) |
| `fs25eDumpDiagLog` | Dump in-memory ring buffer of recent diagnostic events | Ringpuffer der letzten Diagnose-Ereignisse |
| `fs25eDumpScene` | Scene / governor / perf snapshot (unchanged) | Scene-/Governor-/Perf-Snapshot (unverändert) |

## Result meanings / Bedeutungen

| Result | EN | DE |
|--------|----|----|
| `APPLIED` | Capability apply (or restore step) succeeded | Apply (oder Restore-Schritt) erfolgreich |
| `REJECTED` | Apply/reject path failed or registry rejected | Apply fehlgeschlagen bzw. Registry rejected |
| `SKIPPED` | Soft skip (listener / future Core path) | Soft-Skip (Listener / künftiger Core-Pfad) |

## Ring log / Ring-Log

**Note:** File append to `diagnostics.log` was removed — Giants Lua `io.open` only allows `'w'` (append `'a'` spam-warned thousands of times in live logs).

- In-memory ring (default size 64) via `FS25E_Diagnostics.getRing()` / `fs25eDumpDiagLog`.
- In-memory ring only (default size 64) via `getRing()` / `fs25eDumpDiagLog`.
- Ring-Puffer (Standardgröße 64) — Datei-Log absichtlich aus (Giants `io.open` ohne Append).

## GUI API / GUI-API

`FS25E_Diagnostics.getSnapshot()` returns:

- `version`, `capCount`
- `countsByStatus`, `countsByLastResult`
- `caps[]` — `{ id, status, lastResult, lastError, applyMode }`
- `recentErrors[]` — up to 20 newest ring entries with errors

Read-only; does not mutate engine state or enable auto-apply.

## Soft-subscribe / Soft-Subscribe

`installHooks()` wraps Applier/Registry/RestoreManager apply & restore paths (once).  
`trySubscribeListeners()` soft-subscribes `FS25E_CapabilityRegistry.onApply` / `onReject` / `onSkip` (payload `{ status, error, detail, ts }`). `getSnapshot()` also reads `getLastResult(id)` when local runtime is empty.

## Overlay helper / Overlay-Hilfe

`FS25E_Diagnostics.getStatusForSetting(settingId)` → `nil` or `{ settingId, capId, status, lastResult, lastError, applyMode, registryStatus }`  
Maps `SettingsSchema` field `capId`, then Diagnostics runtime / `CapabilityRegistry.getLastResult`.
