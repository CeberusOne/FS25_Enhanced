# FS25_Enhanced — Kalibrierungsnotizen (Wave-1)

**Zweck:** Sinnvolle Startwerte und Clamp-Hinweise für die Wave-1 Distance-Coeffs und `MaxShadowLights`.  
**Scope:** Docs-only. Nur **CONFIRMED**-Setter/Getter aus der Capability-Matrix. Keine erfundenen APIs.  
**GDN:** Script/Engine **v1.20.0.0** (SettingsModel).  
**Status der Zahlen:** Alles unter **Kalibrierungsheuristik** — **nicht** GDN-vorgeschrieben.

**Querverweise:**

- Matrix: [`docs/capability-matrix.md`](capability-matrix.md)
- Smoke: [`docs/wave1-smoke-checklist.md`](wave1-smoke-checklist.md)
- Community-Warnungen: [`docs/community-optimizations.md`](community-optimizations.md)

---

## 1. Regeln (applyMode = UNKNOWN)

Alle hier gelisteten Caps haben in der Matrix `applyMode=UNKNOWN` und `restoreStrategy=YES`. Deshalb:

1. **Getter zuerst cachen** (`get*` → Originalwert speichern).
2. **Calibration-Flag** muss aktiv sein, bevor ein Setter live aufgerufen wird.
3. **Restore ist Pflicht** (Session-Ende / Map-Ende / `fs25eRestore` / Cap-Fehler → Original zurück).
4. Nie `LIVE` annehmen; Session-Apply + Restore wie im Smoke-Checklist.

---

## 2. Distance-Coeffs (LodGovernor)

### 2.1 Bestätigte APIs (SettingsModel, CONFIRMED)

| capabilityId | Getter | Setter |
|--------------|--------|--------|
| `view-distance-coeff` | `getViewDistanceCoeff` | `setViewDistanceCoeff` |
| `lod-distance-coeff` | `getLODDistanceCoeff` | `setLODDistanceCoeff` |
| `foliage-view-distance-coeff` | `getFoliageViewDistanceCoeff` | `setFoliageViewDistanceCoeff` |
| `foliage-lod-distance-coeff` | `getFoliageLODDistanceCoeff` | `setFoliageLODDistanceCoeff` |
| `terrain-lod-distance-coeff` | `getTerrainLODDistanceCoeff` | `setTerrainLODDistanceCoeff` |

Quelle: Matrix-Zeilen `view-distance-coeff` … `terrain-lod-distance-coeff` (SettingsModel, `UNKNOWN`, Restore YES).

### 2.2 Clamp — **Kalibrierungsheuristik**

| Parameter | Bereich | Herkunft |
|-----------|---------|----------|
| Alle fünf Distance-Coeffs | **[0.5, 2.0]** | Stabschef Wave-1 Startvorgabe; Core/WAVE1 nutzt denselben Platzhalter-Clamp |

- **Nicht** GDN-mandatiert (keine offizielle Range auf den SettingsModel-Symbolseiten).
- Werte außerhalb des Clamps verwerfen/clampen — **nie ohne Expert-Freigabe** außerhalb setzen.
- WAVE1.md: „placeholder range; calibrate later“ — diese Notiz ist der Kalibrierungs-Einstieg.

### 2.3 Konservativer Start

1. **Start = aktueller Vanilla-Getter-Wert** (nicht blind auf 1.0 oder Maximum setzen).
2. Explorative Deltas **klein** (z. B. ±0.05 … ±0.1 pro Schritt), Caps **einzeln**.
3. Bei steigender Frame-`dt` / Rucklern: sofort Restore (siehe Smoke §4).

### 2.4 Community-Warnung (CPU)

Draw-Distance / LOD-Coeffs **nicht blind erhöhen**. Community (Hone / PMC, vgl. `community-optimizations.md`): höhere Coeffs belasten vor allem die **CPU** (mehr Drawcalls / LOD-Übergänge), nicht nur GPU. Blindes Hochdrehen → Stutter.

### 2.5 Restore (One-Liner)

Pro Cap: gecachten Getter-Wert erneut per Setter setzen (`RestoreManager` / Cap-Restore); Readback muss dem Cache entsprechen.

---

## 3. Max Shadow Lights

### 3.1 Bestätigte API (SettingsModel, CONFIRMED)

| capabilityId | Getter | Setter |
|--------------|--------|--------|
| `max-num-shadow-lights` | `getMaxNumShadowLights` | `setMaxNumShadowLights` |

Quelle: Matrix `max-num-shadow-lights` (SettingsModel, `UNKNOWN`, Restore YES).

### 3.2 Startwert — **Kalibrierungsheuristik**

- **Start = aktueller `getMaxNumShadowLights()`** (Vanilla-/High-Setting der Session).
- Kein festes „Enhanced-Default“ ohne Messung.

### 3.3 Clamp — **provisorisch** (bis Smoke bestätigt)

| Hinweis | Detail |
|---------|--------|
| Status | Clamp-Vorschlag **provisorisch**, bis Wave-1-Smoke (`wave1-smoke-checklist.md` §2.1) gemessen hat |
| Praxis | Vanilla-/High-Werte **nicht ohne Messung überschreiten** |
| Explizit **nicht** | **Max Shadow Lights = 10 als Default-Fix** — Hone: Engine-Bug, Qualität kann auf Medium fallen (`community-optimizations.md`, „Was NICHT übernommen“) |

Kleine kontrollierte Deltas hinter Calibration-Flag; bei Artefakten / Qualitätsabfall sofort Restore.

### 3.4 Restore (One-Liner)

Gecachten `getMaxNumShadowLights()`-Wert per `setMaxNumShadowLights` zurückschreiben; Readback = Cache.

---

## 4. Kalibrierungsablauf (Kurz)

| Schritt | Aktion |
|---------|--------|
| 1 | Baseline: alle sechs Getter loggen (`[FS25_Enhanced]`) |
| 2 | Calibration-Flag an; Governor `autoApply` bleibt aus |
| 3 | Ein Cap: kleines Delta innerhalb Heuristik-Clamp |
| 4 | Readback + subjektive Szene (Open Field / Farmyard Night) + optional gleitende Frame-`dt` |
| 5 | Restore; nächsten Cap erst nach stabilem Restore |
| 6 | Werte außerhalb Clamp nur mit Expert-Freigabe und dokumentierter Messung |

Smoke-Details und Pass/Fail: [`wave1-smoke-checklist.md`](wave1-smoke-checklist.md).

---

## 5. Nicht Gegenstand dieser Notiz

- Andere Wave-1-Caps (z. B. Soft-Shadows, Merge/Split, `allow-foliage-shadows`) — hier keine Start/Clamp-Empfehlung.
- GATED / EXPERIMENTAL / `setTerrainQuality` (RESTART) — ausgeschlossen.
- Erfundene FPS-/Engine-APIs — verboten; Metriken nur wie Smoke erlaubt.

---

*Docs-only Deliverable. Zahlen = **Kalibrierungsheuristik** (Stabschef [0.5, 2.0] für Coeffs; MaxShadowLights-Clamp provisorisch). Matrix und Scripts unverändert.*
