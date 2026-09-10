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

## Ring log + optional file / Ring + optionale Datei

- In-memory ring (default size 64) via `FS25E_Diagnostics.getRing()` / `fs25eDumpDiagLog`.
- Optional append to `modSettings/FS25_Enhanced/diagnostics.log` when `FS25E_ModSettings` is ready (`getFilePath("diagnostics.log")`). Soft-fails if IO unavailable.
- Ring-Puffer (Standardgröße 64). Optionales Anhängen an `modSettings/FS25_Enhanced/diagnostics.log`, wenn ModSettings bereit ist; IO-Fehler werden still abgefangen.

## GUI API / GUI-API

`FS25E_Diagnostics.getSnapshot()` returns:

- `version`, `capCount`
- `countsByStatus`, `countsByLastResult`
- `caps[]` — `{ id, status, lastResult, lastError, applyMode }`
- `recentErrors[]` — up to 20 newest ring entries with errors

Read-only; does not mutate engine state or enable auto-apply.

## Soft-subscribe / Soft-Subscribe

`installHooks()` wraps Applier/Registry/RestoreManager apply & restore paths (once).  
`trySubscribeListeners()` soft-subscribes `FS25E_CapabilityRegistry.onApply` / `onReject` / `onSkip` **when present** (future Settings-API PR) — no edits to CapabilityRegistry or SettingsSchema required from Diagnostics.
