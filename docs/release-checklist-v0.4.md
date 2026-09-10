# FS25_Enhanced — Release-Checklist v0.4

**Zweck:** Kurzer manueller Release-Smoke vor Tag/Release (Docs-only).  
**Basis:** `main` (Wave 1 + Phase 2 laut Repo-Doku).  
**Sprache:** Deutsch.  
**Policy:** Nur dokumentierte Fakten aus WAVE1 / PHASE / Smoke / GUI-Schema / LIGHTS_PROBE — **keine spekulativen APIs.**

**Querverweise:**

| Doc | Pfad |
|-----|------|
| Capability-Matrix | [`docs/capability-matrix.md`](capability-matrix.md) |
| Wave-1 Smoke | [`docs/wave1-smoke-checklist.md`](wave1-smoke-checklist.md) |
| Wave-2 Kandidaten | [`docs/wave2-candidates.md`](wave2-candidates.md) |
| Kalibrierungsnotizen | [`docs/calibration-notes.md`](calibration-notes.md) — **Hinweis:** PR #8 (`docs/calibration-notes`) kann noch offen sein; Pfad ist der erwartete Stand auf `main` nach Merge |

Weitere Quellen dieser Checklist: [`WAVE1.md`](WAVE1.md), [`PHASE2.md`](PHASE2.md), [`gui-design.md`](gui-design.md), [`settings-schema.md`](settings-schema.md), [`LIGHTS_PROBE.md`](LIGHTS_PROBE.md).

---

## 1. Load-Smoke

| Check | Erwartung | Pass / Fail |
|-------|-----------|-------------|
| Mod lädt | SP-Map starten; Mod ohne Crash im Log | ☐ |
| Log-Prefix | Zeilen mit **`[FS25_Enhanced]`** (Bootstrap / Wave-1 / Phase-2 laut Version) | ☐ |
| Policy-Defaults | Log zeigt Governor/`GraphicsGovernor`: **`enabled=false`**, **`autoApply=false`** (WAVE1 / PHASE2) | ☐ |
| Kein Hard-Crash | Mission lädt; kein Script-Error, der den Load abbricht | ☐ |

**Hinweis:** Session-only Apply; **kein** `saveHardwareScalability` / `applyPerformanceClass` ohne User-Opt-in (WAVE1 Ausschlüsse).

---

## 2. GUI-Open

**Quellen:** [`settings-schema.md`](settings-schema.md), [`gui-design.md`](gui-design.md).

| Check | Erwartung | Pass / Fail / N/A |
|-------|-----------|-------------------|
| Settings / Live-UI öffnen | **Wenn GUI vorhanden:** Dialog/Overlay öffnet **ohne White-Box** | ☐ |
| Widget-Typ | **Keine Slider** — Optionen als **`MultiTextOption`** / bool\|enum laut Schema | ☐ |
| GUI noch Stub | **Wenn GUI noch nicht verdrahtet:** **N/A** — Design-Vorgaben in `gui-design.md` / `settings-schema.md` beachten (MessageDialog-Basis, `extends="fs25_*"`, keine Custom-Profiles ohne extends) | ☐ |

**Verboten laut Design-Doku:** Slider-Widgets, `DialogElement` als Basis, freie Int-/Float-Eingaben.

---

## 3. Preset-Wechsel

**Quellen:** `settings-schema.md` (Preset-Enum), `PHASE2.md` (`ProfileManager` / `config/presets.xml`).

| Preset-ID (Schema) | PHASE2 / presets.xml | Erwartung | Pass / Fail / N/A |
|--------------------|----------------------|-----------|-------------------|
| `off` | Schema-Option | Nur dokumentierte Option prüfen | ☐ |
| `performance` | Performance | Cache-only Select (`fs25eSelectPreset` / UI) — **kein** automatischer Engine-Apply | ☐ |
| `balanced` | Balanced (Default Schema) | wie oben | ☐ |
| `quality` | Quality | wie oben | ☐ |
| `cinematic` | Cinematic | wie oben; Extreme-Kosten-Hinweis laut Schema optional | ☐ |

**Regel (PHASE2):** `selectPreset` füllt **SettingsCache requested**-Slots (Locks respektieren). **Kein Engine-Apply** durch Phase-2-Decision-Pfade. Console `fs25eSelectPreset <name>` = Cache-only.

Nur testen, was in WAVE1/PHASE-Docs bzw. Schema auf `main` existiert — keine erfundenen Preset-Namen.

---

## 4. Restore on deleteMap

**Quelle:** WAVE1 Runtime §4, Smoke §3 / §6.

| Check | Erwartung | Pass / Fail |
|-------|-----------|-------------|
| Wave-1 Setter restored | Nach Map-Ende / `deleteMap`: alle Session-Applies der Wave-1 Caps zurück auf gecachte Originale | ☐ |
| Merge-Restore | Getrackte Merges zuerst per **`splitLightShadow`** auflösen, danach CapabilityApplier / SettingsCache | ☐ |
| Reihenfolge | ShadowManager (Splits) → CapabilityApplier → SettingsCache | ☐ |
| Hooks | Hooks bleiben installiert (kein Tear-down nötig für Pass) | ☐ |
| Optional Console | `fs25eRestore` → `RestoreManager.restoreAll` ohne Error | ☐ |

Per-Light / Soft-Apply-Restore nur relevant, wenn Soft-Apply in der Session **explizit** genutzt wurde (siehe §6 / LIGHTS_PROBE).

---

## 5. MP client-local Hinweis

| Check | Erwartung | Pass / Fail |
|-------|-----------|-------------|
| Client-local | Grafik-/Quality-Werte **nicht** über Netzwerk syncen (WAVE1 Policy · PHASE2 · Schema `clientOnlyHint`) | ☐ |
| UI-Hinweis | Falls Settings-UI vorhanden: Client-only-Infotext (`FS25E_CLIENT_ONLY_HINT`) sichtbar oder dokumentiert | ☐ / N/A |

---

## 6. Bekannte Limits

### 6.1 `autoApply` default **off**

Laut **WAVE1.md** / **PHASE2.md** / Smoke-Checklist / LIGHTS_PROBE:

- `GraphicsGovernor`: **`enabled=false`**, **`autoApply=false`**
- Console `fs25eGovernor 0|1` aktiviert Observe/Decision — **setzt nie** `autoApply=true`
- Kein automatischer Engine-Setter aus Phase-2-Decision-Pfaden

### 6.2 Soft-Apply — Gefahr (sorgfältig, nur dokumentiert)

Quellen: [`LIGHTS_PROBE.md`](LIGHTS_PROBE.md), [`wave1-smoke-checklist.md`](wave1-smoke-checklist.md) §1.4, WAVE1 Soft-Discovery.

| Fakt | Detail |
|------|--------|
| Default | Soft-Apply **OFF** (`fs25eSoftApply` Default **0**); `autoApply` bleibt **false** |
| Soft-Discovery | Stub liefert **leere** Light-Liste, bis Lights-Spec IDs liefert — **kein** Blind-World-Node-Scan |
| Risiko | Soft-Shadow- / Merge-Apply **ohne gültige `lightId`s** bzw. ohne Spec-Probe → Cap **SKIP** (Log), nicht blind anwenden |
| Leer = kein Apply | Discovery `total=0` / Soft-Discovery leer → **kein** Per-Light-Apply bis `lightId` vorhanden |
| Console | `fs25eSoftApply 1` = **DANGER**-Toggle; aktiviert **nicht** `autoApply` |
| Scope Soft-Apply ON | Nur CONFIRMED ShadowManager Priority / Soft / Map-APIs; **nie** EXPERIMENTAL (`setShadowFocusBox`, `setFastShadowUpdate`, `setRainShallowWaterSimulation`); **nie** `saveHardwareScalability` / `applyPerformanceClass` / `setTerrainQuality` |

**Release-Hinweis (Stabschef / Core-Policy):** Soft-Apply und `autoApply` bleiben aus, sofern nicht explizit und bewusst für Diagnose aktiviert. Keine erfundenen API-Namen dokumentieren.

### 6.3 Weitere dokumentierte Grenzen

| Limit | Quelle |
|-------|--------|
| Distance-Coeffs Clamp **[0.5, 2.0]** (Platzhalter / Kalibrierung) | WAVE1, calibration-notes |
| EXPERIMENTAL / GATED / `setTerrainQuality` (RESTART) nicht im Wave-1-Fast-Path | WAVE1 |
| Session-only; keine Hardware-Profile-Writes ohne Opt-in | WAVE1 |

---

## Kurz-Ergebnis Release v0.4

| Bereich | Ergebnis |
|---------|----------|
| 1 Load-Smoke | ☐ PASS / ☐ FAIL |
| 2 GUI-Open | ☐ PASS / ☐ FAIL / ☐ N/A |
| 3 Preset-Wechsel | ☐ PASS / ☐ FAIL / ☐ N/A |
| 4 Restore deleteMap | ☐ PASS / ☐ FAIL |
| 5 MP client-local | ☐ PASS / ☐ FAIL |
| 6 Limits gelesen / beachtet | ☐ OK |

**Gesamt:** ☐ READY / ☐ BLOCKED — bei BLOCKED Ursache + Log-Ausschnitt mit `[FS25_Enhanced]` notieren.

---

*Docs-only Deliverable. Scripts unverändert. Keine spekulativen APIs.*
