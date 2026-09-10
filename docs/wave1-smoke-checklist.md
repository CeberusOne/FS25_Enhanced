# FS25_Enhanced — Wave-1 Ingame Smoke Checklist

**Zweck:** Kurzer manueller Smoke-Test der **Welle-1 CONFIRMED**-Capabilities, die Core verdrahtet.  
**Quelle:** `docs/capability-matrix.md` (Research Freeze), `docs/WAVE1.md`  
**GDN:** Script/Engine **v1.20.0.0** — nur dokumentierte Symbole; keine spekulativen APIs.  
**Scope:** Docs-only Deliverable zur Core-Verifikation (optional Research).

---

## 1. Zweck und Voraussetzungen

### 1.1 Zweck

- Nachweis: Getter → Cache → Apply (hinter Calibration-Flag) → Readback → **Restore** für Wave-1 Caps.
- Kein Auto-Apply: Governor bleibt `autoApply=false`; Caps explizit (Dev-Controls / Console) auslösen.
- `applyMode=UNKNOWN` (Matrix): nie LIVE annehmen; Session-Apply + Restore zwingend.

### 1.2 Voraussetzungen

| Item | Anforderung |
|------|-------------|
| Mod | FS25_Enhanced geladen (Client), Log-Prefix **`[FS25_Enhanced]`** |
| Dev-Controls | Explizite Apply/Restore-Pfade für Wave-1 Caps erreichbar |
| Calibration | Set hinter Calibration-Flag; ohne Flag kein Setter-Aufruf |
| Szenen | **Farmyard Night** (viele Lichter / Schatten) und **Open Field** (Distanz / Foliage / Terrain-LOD) |
| Baseline | Vor Test: Vanilla-Defaults notieren (Getter-Log), kein paralleles Tuning anderer Grafik-Mods |
| Ausschluss | **EXPERIMENTAL** nie aufrufen; **GATED** (SSR/Atmosphere/DRS) nicht in Wave-1; **`setTerrainQuality`** (RESTART) nicht im Fast-Path |

### 1.3 Logging-Konvention

Jeder Schritt muss im Log mit Prefix `[FS25_Enhanced]` erscheinen:

1. **VOR Apply:** Getter-Wert(e) + Cap-Id  
2. **NACH Apply:** erwarteter Readback / Status (`APPLIED` / `REJECTED`)  
3. **Restore:** Wert wieder = gecachter Originalwert  

---

## 1.4 Lights-Discovery Voraussetzung

Nach Map-Load mit Fahrzeugen/Placeables, die Lights haben:

1. Console: `fs25eLightsDump`
2. Erwartung im Log (`[FS25_Enhanced]`): `total` / `active` / `vehicle` / `placeable` Counts (+ `lightsProfile`, `softApply=false`)
3. Für §2.2 / §3: **`lightId` = `node=` / `lightId=` der Zeilen mit `active=true`** (aktive RealLight-Nodes aus Spec-Discovery)
4. Wenn **`total=0`**: Per-Light Caps (§2.2 / §3) **SKIP** mit Log-Notiz — **nicht FAIL**. Kein globaler World-Node-Scan (WAVE1 / LIGHTS_PROBE).

Details: [`docs/LIGHTS_PROBE.md`](LIGHTS_PROBE.md). Soft-Apply / `autoApply` bleiben **OFF** (Default).

### Console-Befehle (Referenz)

| Command | Zweck |
|---------|--------|
| `fs25eDumpCaps` | Capability-Registry dump |
| `fs25eDumpScene` | Scene / Governor / Perf Snapshot |
| `fs25eApplyLodCoeff <float>` | Manuell `setViewDistanceCoeff` (LodGovernor) |
| `fs25eApplyMaxShadowLights <int>` | Manuell `setMaxNumShadowLights` |
| `fs25eRestore` | Session-Restore (`RestoreManager.restoreAll`) |
| `fs25eSelectPreset <name>` | Preset nur in SettingsCache (kein Engine-Apply) |
| `fs25eGovernor` `0`/`1` | Governor observe enable; **setzt nie** `autoApply=true` |
| `fs25eLightsDump` | Discoverte RealLight-Nodes (read-only; `lightId` für §2.2) |
| `fs25eApplyLightPriority <lightId> <priority>` | Manuell `setLightShadowPriority` (Id aus Dump) |
| `fs25eSoftApply` `0`/`1` | **DANGER:** Soft-Apply an/aus — Default **0**; aktiviert **nicht** `autoApply` |

Keiner dieser Befehle aktiviert `autoApply`. Soft-Apply nur explizit mit `fs25eSoftApply 1`.

---

## 2. Pro Cap — Getter vor Apply, Erwartung nach Apply, Restore, Fail

**Gemeinsame Regel (Research Freeze):**  
`get*` → Cache (`needsCalibration`) → nur bei Calibration-Flag `set*` → Readback → bei Map-Ende / Restore-Befehl Original wiederherstellen.  
`pcall`-Fehler → `REJECTED` + sofortiger Cap-Restore.

### 2.1 Global / SettingsModel

#### `max-num-shadow-lights` — `getMaxNumShadowLights` / `setMaxNumShadowLights`

| Schritt | Aktion / Erwartung |
|---------|-------------------|
| VOR | `getMaxNumShadowLights()` loggen und cachen |
| Apply | Setter nur hinter Calibration-Flag; Zielwert ≠ Cache (kontrollierte Delta) |
| NACH | Readback = gesetzter Wert; Log `APPLIED` |
| Restore | Readback = Cache |
| Fail | Setter ohne vorherigen Getter/Cache; Readback ≠ gesetzt; Restore weicht ab; Lua-Error |

**Szene:** Farmyard Night — sichtbare Schatten-Licht-Budget-Wirkung optional beobachten (kein Pass-Kriterium ohne Metrik).

#### Distance-Coeffs (LodGovernor) — je Cap getrennt smoke’n

| capabilityId | Getter / Setter |
|--------------|-----------------|
| `view-distance-coeff` | `getViewDistanceCoeff` / `setViewDistanceCoeff` |
| `lod-distance-coeff` | `getLODDistanceCoeff` / `setLODDistanceCoeff` |
| `foliage-view-distance-coeff` | `getFoliageViewDistanceCoeff` / `setFoliageViewDistanceCoeff` |
| `foliage-lod-distance-coeff` | `getFoliageLODDistanceCoeff` / `setFoliageLODDistanceCoeff` |
| `terrain-lod-distance-coeff` | `getTerrainLODDistanceCoeff` / `setTerrainLODDistanceCoeff` |

| Schritt | Aktion / Erwartung |
|---------|-------------------|
| VOR | Je Cap Getter loggen + cachen |
| Apply | Nur hinter Calibration-Flag; Core-Clamp **[0.5, 2.0]** (WAVE1) respektieren — Werte außerhalb verwerfen/clampen, nicht blind hochdrehen |
| NACH | Readback = angewandter (ggf. geclampter) Wert |
| Restore | Readback = Cache je Cap |
| Fail | Apply ohne Cache; Clamp ignoriert; einzelner Cap bleibt nach Restore ≠ Cache |

**Szene:** Open Field (+ optional Fog) — siehe §4.

#### `allow-foliage-shadows` — `getAllowFoliageShadows` / `setAllowFoliageShadows`

| Schritt | Aktion / Erwartung |
|---------|-------------------|
| VOR | Boolean via Getter loggen + cachen |
| Apply | Invertieren hinter Calibration-Flag |
| NACH | Readback = gesetzter Boolean |
| Restore | Readback = Cache |
| Fail | Getter fehlend / Restore falsch |

**Szene:** Open Field mit sichtbarer Vegetation bei Nacht/Abend.

---

### 2.2 Per-Light (Engine Lighting) — gültige `lightId` erforderlich

**`lightId` = `node` / `lightId=` aus `fs25eLightsDump`** (bevorzugt `active=true`; siehe §1.4).  
Ohne gültige `lightId` (Dump `total=0` / kein Dev-Pick): Cap **SKIP** mit Log — kein Blind-Scan der World-Nodes (WAVE1).

#### `light-shadow-priority` — `getLightShadowPriority` / `setLightShadowPriority`

| Schritt | Aktion / Erwartung |
|---------|-------------------|
| VOR | `getLightShadowPriority(lightId)` cachen |
| Apply | Priorität ändern (Doc: höhere Prio bei zu vielen Schatten zuerst) |
| NACH | Readback = gesetzt |
| Restore | = Cache |
| Fail | Apply auf ungültige Id; Restore falsch |

#### `light-shadow-map` — `getLightCastingShadowMap` / `setLightShadowMap`

| Schritt | Aktion / Erwartung |
|---------|-------------------|
| VOR | `getLightCastingShadowMap(lightId)` cachen |
| Apply | `setLightShadowMap` mit dokumentiertem Setter; Map-Handle/Parameter aus Dev-Pfad |
| NACH | Getter-Readback konsistent zum Apply (soweit Getter aussagekräftig) |
| Restore | Cache wiederhergestellt |
| Fail | Apply ohne Cache; Restore inkonsistent |

#### Soft-Shadows

| capabilityId | Getter / Setter |
|--------------|-----------------|
| `light-soft-shadow-size` | `getLightSoftShadowSize` / `setLightSoftShadowSize` |
| `light-soft-shadow-distance` | `getLightSoftShadowDistance` / `setLightSoftShadowDistance` |
| `light-soft-shadow-depth-bias` | `getLightSoftShadowDepthBiasFactor` / `setLightSoftShadowDepthBiasFactor` |

| Schritt | Aktion / Erwartung |
|---------|-------------------|
| VOR | Je Getter cachen |
| Apply | Kontrollierte Delta hinter Flag |
| NACH | Readback = gesetzt |
| Restore | = Cache je Cap |
| Fail | Teil-Restore; Error ohne `REJECTED`+Restore |

**Szene:** Farmyard Night, ein bekanntes RealLight.

#### Merge / Split — siehe §3

---

## 3. Merge-spezifisch: `splitLightShadow`-Restore nachweisen

**APIs (CONFIRMED):** `mergeLightShadows`, `splitLightShadow`, Query `hasMergedShadow` (kein Setter).

| Schritt | Nachweis |
|---------|----------|
| 1 | Mind. zwei gültige `lightId`s wählen; je `hasMergedShadow(lightId)` **VOR** Merge loggen |
| 2 | Merge-Mitgliedschaft / Pre-State cachen (Restore-Strategie Matrix: *splitLightShadow / cache merge membership*) |
| 3 | `mergeLightShadows(...)` nur hinter Calibration-Flag / explizitem Dev-Befehl |
| 4 | **NACH Merge:** `hasMergedShadow` für beteiligte Lights = erwartet (merged) |
| 5 | **Restore:** `splitLightShadow` für getrackte Merges (ShadowManager-Pfad / `RestoreManager`) |
| 6 | **NACH Split:** `hasMergedShadow` wieder = Pre-Merge-Cache; keine hängenden Merges |
| Fail | Merge ohne Membership-Cache; Restore ohne `splitLightShadow`; Query nach Restore noch merged; Apply auf untracked Lights |

`deleteMap` / `restoreAll`: zuerst tracked Merges splitten, danach Setter-Restores — Hooks bleiben installiert (WAVE1 Runtime).

---

## 4. Distanz-Coeffs: Fog / Open Field; CPU-Warnung

| Check | Vorgehen |
|-------|----------|
| Open Field | Baseline-Getter → moderater Coeff-Anstieg innerhalb **[0.5, 2.0]** → Draw-Distance/LOD subjektiv prüfen → Restore |
| Fog (falls Map/Wetter Fog hat) | Denselben Cap-Satz; kein Pass allein über „sieht weiter“ bei dichtem Fog |
| CPU / Frame-Zeit | Coeffs **nicht blind hochdrehen**. Steigende gleitende Frame-`dt` oder Ruckler → sofort Restore und Fail-Notiz |
| Isolation | Caps einzeln ändern; nicht alle fünf gleichzeitig beim ersten Smoke |

---

## 5. Metriken

| Metrik | Erlaubt | Nicht erlaubt |
|--------|---------|---------------|
| Frame-Zeit | Gleitender Mittelwert der Frame-`dt` (Update-Hook / vorhandenes Mod-Logging) | — |
| FPS-Anzeige | Optional Vanilla **F2** / `showFps` (Engine-Debug), nur Beobachtung | **Keine** undokumentierte `getFps`-API erfinden oder annehmen |
| Cap-Readback | Dokumentierte `get*`-Symbole aus der Matrix | Spekulative Helper-APIs |

Metriken sind **Hilfsmittel** für Fail bei spürbarer Regression; Pass/Fail der Caps bleibt Getter/Restore-basiert.

---

## 6. Pass / Fail — Kurzabelle

| Cap / Thema | Pass | Fail |
|-------------|------|------|
| `setMaxNumShadowLights` | Get→Cache→Set→Readback→Restore = Cache | Skip Cache; Readback/Restore falsch |
| Distance-Coeffs (5×) | Je Cap Get/Set/Restore; Clamp [0.5, 2.0] | Blind >2.0; Restore unvollständig |
| `setAllowFoliageShadows` | Boolean Toggle + Restore | Restore ≠ Cache |
| `setLightShadowPriority` | Mit gültiger `lightId`; Restore ok | Blind-Scan; ungültige Id ohne SKIP |
| `setLightShadowMap` | Get (`getLightCastingShadowMap`) / Set / Restore | Restore inkonsistent |
| Soft-Shadow-Trio | Alle drei Restore ok | Teil-Fail ohne Rollback |
| Merge + `splitLightShadow` | `hasMergedShadow` Pre/Post Merge/Split belegt | Merge ohne Split-Restore |
| EXPERIMENTAL / GATED / `setTerrainQuality` | **Nicht aufgerufen** | Jeder Aufruf im Wave-1-Smoke = Fail |
| Calibration-Flag | Set nur wenn Flag an | Set bei Flag aus |
| Metriken | `dt` gleitend; optional F2/`showFps` | Erfundene FPS-API |

### Gesamtergebnis

- **PASS:** Alle getesteten Wave-1 Caps erfüllen Get/Cache/Apply/Restore; Merge-Split nachgewiesen; Ausschlüsse unberührt.  
- **FAIL:** Ein Cap verletzt Restore oder Readback; Merge ohne Split; verbotener Cap-Aufruf; Apply ohne Calibration.  
- **SKIP:** Per-Light Caps ohne verfügbare `lightId` — dokumentieren, nicht als PASS werten.

---

## Referenz (nicht ändern durch dieses Doc)

- Matrix: `docs/capability-matrix.md`  
- Wave-1 Wiring: `docs/WAVE1.md`  
- Wave-2 (explizit außerhalb): `docs/wave2-candidates.md`  
- Lights discovery / Dump: [`docs/LIGHTS_PROBE.md`](LIGHTS_PROBE.md)
