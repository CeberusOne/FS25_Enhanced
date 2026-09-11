# FS25 Pro Live-HUD — Machbarkeitsanalyse

**Datum:** 2026-09-10  
**Scope:** Farming Simulator 25 / Giants Engine 10 — GDN LuaDoc **Script/Engine v1.20.0.0** (GDN LuaDoc v1.20)  
**Primärquellen:**  
- https://gdn.giants-software.com/documentation_scripting_fs25.php  
- https://gdn.giants-software.com/documentation_overview.php  
- Projekt: `/workspace/FS25_Enhanced/docs/` (`capability-matrix`, `LIVE_OVERLAY_API`, `expert-live-overlay`, `gdn-research`, `community-optimizations`, `calibration-notes`, `PHASE1`)  
- Community (nur verifizierte Aussagen): AutoVRAMOptimizer (KeilerHirsch), GDN-Forum Sandbox-Hinweis (Bilbo Beutlin)

**Regel:** Keine erfundenen Engine-APIs. Statuslegende: **CONFIRMED** (GDN/Projektmatrix) · **COMMUNITY** (externe Mods, mit Caveat) · **NICHT VERFÜGBAR** · **SIDECAR** (außerhalb Lua).

---

## 1. Kurzfazit

| Ziel | Machbarkeit in reinem Lua | Pfad |
|------|---------------------------|------|
| Feintuning aller Matrix-Grafik-Caps (0,01-Schritte) | **Ja** (teilweise schon da) | `FS25E_SettingsAPI.live*` + Capability-Registry; Overlay erweitern |
| FPS / Frametime live | **Ja** (abgeleitet) | Mission-`update(dt)` → `FS25E_PerformanceMonitor`; kein `getFps` |
| CPU-/GPU-Last, Temperaturen, VRAM-/RAM-Belegung | **Nein in Lua** | Optional **Sidecar** → `modSettings/FS25_Enhanced/telemetry.json`; sonst `UNSUPPORTED` / `SKIPPED` |
| Bewegliche/pinbare HUD-Widgets + Sparklines | **Ja** | Bestehende Draw-Primitives (`renderText` / `drawFilledRect`) wie Live-Overlay |

---

## 2. BESTÄTIGTE APIs: FPS / Frametime / Performance-Zähler

### 2.1 Frametime & abgeleitete FPS — CONFIRMED

| Mechanismus | Nachweis | Nutzung |
|-------------|----------|---------|
| `update(dt)` / Mission-Update-Hook | GDN: Update „every frame“; `dt` = Zeit seit letztem Aufruf (Forum: ms; FS25_Enhanced wandelt Sekunden→ms) | Ringpuffer über Framezeiten |
| `Utils.appendedFunction(FSBaseMission.update, …)` bzw. `g_currentMission:addUpdateable` | `gdn-research.md`, `community-optimizations.md` | Feed an PerformanceMonitor |
| `FS25E_PerformanceMonitor` | `scripts/Core/PerformanceMonitor.lua` — **explizit „NO getFps“** | `getLastFrameMs()`, `getAverageMs()`, `getVariance()`, `isSpike()`, `isOverBudget()`, Target-Budget aus Target-FPS |

**Ableitung (kein Engine-Getter):**

- Frametime \(ms\) = `dt * 1000` (so im Monitor implementiert)  
- FPS ≈ `1000 / max(frameMs, ε)` — **Mod-eigene Statistik**, nicht Engine-API  
- Sparkline-Daten: Ringpuffer der letzten N Framezeiten (Monitor-Fenster aktuell 60 Samples)

### 2.2 Engine-/Dev-Hilfen — CONFIRMED, aber keine Lua-Getter

Quelle: `documentation_overview.php` (Development Controls):

| Element | Rolle | Für HUD? |
|---------|-------|----------|
| Taste **F2** | FPS-Anzeige (Engine-Debug) | Nur Beobachtung; kein Script-Zugriff |
| Konsole `showFps` | FPS ein/aus | Kein Return-Wert an Lua |
| `enableFramerateLimit` / `framerateLimitFPS` | Limiter | Settings/Dev; kein Live-Counter-API |
| F3 / F8 | Limiter / Stats-Toggle | Debug, nicht HUD-Datenquelle |

**Projektregel (Smoke/Plan):** Keine undokumentierte `getFps`-API annehmen oder erfinden (`wave1-smoke-checklist.md`, `optimal-plan.md`, `PHASE1.md`).

### 2.3 Weitere Performance-bezogene, aber keine Sensor-APIs — CONFIRMED

| API / Symbol | Quelle | Hinweis |
|--------------|--------|---------|
| `getPerformanceClass` / `getAutoPerformanceClass` / `Utils.getPerformanceClassIndex` | SettingsModel LuaDoc | Qualitätsklasse, **kein** CPU/GPU-% |
| `SettingsModel:applyPerformanceClass` | Matrix `apply-performance-class` | **Nicht** für Live-HUD-Tuning ohne Opt-in; Soft-Apply-Ausschluss |
| `saveHardwareScalability` | SettingsModel | Persistenz; **nie** auto on load |
| `getDRSQuality` / `setDRSQuality` + `getSupportsDRSQuality` | SettingsModel, GATED | DRS-Ziel-FPS-Texte existieren; das ist **kein** Live-FPS-Zähler |
| Frame-Limit-Settings (`Platform.hasAdjustableFrameLimit`, `g_gameSettings.frameLimitValues`) | SettingsModel Source | Limit-Werte, keine Messung |

### 2.4 Explizit NICHT gefunden (GDN LuaDoc v1.20.0.0)

- `getFps` / `getFPS` / `getFrameTime` / `getFrametime` als Engine-Funktion  
- CPU-Last-%, CPU-Temperatur, GPU-Last-%, GPU-Temperatur  
- Physische VRAM-Belegung / freier System-RAM als Getter  
- Dedizierte Engine-Seite für `setTextureStreamingMemoryBudget` / `getTextureStreamingMemoryBudget` (siehe §3.2)

---

## 3. Was in Lua NICHT verfügbar ist (klare Aussage)

### 3.1 Hardware-Sensoren — NICHT VERFÜGBAR in GDN Lua

| Metrik | Lua / GDN v1.20 | Begründung |
|--------|-----------------|------------|
| CPU-Last (%) | **NICHT VERFÜGBAR** | Kein Symbol in Engine/Script-LuaDoc; Sandbox |
| CPU-Temperatur (°C) | **NICHT VERFÜGBAR** | Kein Symbol; Sandbox |
| GPU-Last (%) | **NICHT VERFÜGBAR** | Kein Symbol; Sandbox |
| GPU-Temperatur (°C) | **NICHT VERFÜGBAR** | Kein Symbol; Sandbox |
| VRAM-Nutzung (belegt/gesamt) | **NICHT VERFÜGBAR** als Live-Read | AutoVRAM: *„Lua can't read physical VRAM in-game“*; Detection nur außerhalb (Registry / nvidia-smi) |
| System-RAM-Nutzung | **NICHT VERFÜGBAR** | Kein GDN-Getter; Sandbox |
| OS-/Prozess-I/O zu Sensor-APIs | **NICHT VERFÜGBAR** | GDN-Forum: Lua-Sandbox kann nicht mit externen Programmen interagieren; indirekt nur über Dateien |

**Klare Produktaussage für HUD:** Ohne Sidecar zeigen diese Zeilen **`UNSUPPORTED`** (oder `SKIPPED`, wenn Feature bewusst ausgeschaltet) — **niemals** erfundene/Platzhalter-Zahlen als Messwerte ausgeben.

### 3.2 Texture-Streaming-Budget — COMMUNITY, nicht GDN-CONFIRMED

| Claim | Status |
|-------|--------|
| AutoVRAM ruft `setTextureStreamingMemoryBudget(bytes)` auf, wenn `type(fn)=="function"` | **COMMUNITY** (KeilerHirsch/FS25_AutoVRAMOptimizer README) |
| Symbol auf GDN LuaDoc FS25 v1.20 Engine/Script-Seiten | **Nicht gefunden** (Search/Rendering/General-Scrape; nicht in Capability-Matrix) |
| Live-Read physischer VRAM | **Nein** — Helper schreibt Config; Lua setzt nur Budget |

Für Enhanced: nur mit Runtime-Gate + Capability-Status; **nicht** als CONFIRMED-Matrix-Cap ohne GDN-Nachweis bewerben. Kein Ersatz für VRAM-%-Anzeige.

### 3.3 Erlaubte „weiche“ Lua-Proxies (kein Hardware)

| Proxy | Status | Nutzen |
|-------|--------|--------|
| Gleitende Frame-`dt` / Spike / Varianz | CONFIRMED (Mod) | HUD FPS/Frametime |
| `collectgarbage("count")` (falls in Sandbox erlaubt) | **Nicht als System-RAM verkaufen** | Nur Lua-Heap-KB, optional Diagnose |
| SceneAnalyzer-Flags (Wetter/Stunde/Fahrzeug) | CONFIRMED Projekt PHASE2 | Kontext, keine Hardware |

---

## 4. Optionale Sidecar-Telemetrie (wenn Engine keine Sensoren hat)

### 4.1 Architekturprinzip

```
[Windows Sidecar]  --schreibt-->  modSettings/FS25_Enhanced/telemetry.json
                                        ^
[FS25 Lua Mod]  --liest periodisch (Throttle)--┘
```

- Entspricht GDN-Sandbox-Muster: **nur Dateikommunikation**, kein Socket aus Lua.  
- Vorbild-Muster: AutoVRAM schreibt Hardware-Ergebnis nach `modSettings/…`; Lua liest lokal.  
- Sidecar ist **optional**, opt-in, nie Pflicht für Core-Grafik-Tuning.  
- **Keine Fake-Zahlen:** fehlende Felder → `null` + Status `UNSUPPORTED` / `STALE` / `MISSING`.

### 4.2 Windows-Backends (Sidecar, nicht Lua)

| Backend | Typische Metriken | Lizenz / Admin-Hinweise |
|---------|-------------------|------------------------|
| **LibreHardwareMonitor (LHM)** | CPU/GPU-Temp, Last, Speichersensoren (hw-abhängig) | MPL-2.0; oft **Admin** oder signierte Treiber nötig; optional Web-JSON `localhost` — Sidecar pollt LHM, **nicht** das Spiel |
| **PDH** (Performance Data Helper) | CPU-%, Prozess-%, manche Speicherzähler | Windows-API; Admin meist nicht nötig; **keine** zuverlässigen GPU-Temps |
| **NVAPI** (NVIDIA) | GPU-Temp, Utilization, Speicher (Treiber) | NVIDIA-Lizenzbedingungen; nur NVIDIA; Header/SDK-Bindung im Sidecar |
| AMD ADL / Intel-Pfade | GPU-seitig analog | Vendor-SDK; hw-abhängig |
| Registry / `nvidia-smi` (AutoVRAM-Stil) | **Installierte** Adapter-VRAM-Größe | Einmalig/statisch; **kein** Live-Usage-% |

Empfehlung: Sidecar wählt Backend per Config (`lhm` | `pdh` | `nvapi` | `auto`); fehlende Sensoren einzeln als `null` belassen.

### 4.3 Dateipfad & JSON-Schema (Vorschlag)

**Pfad:** `modSettings/FS25_Enhanced/telemetry.json`  
(über bestehendes `FS25E_ModSettings.getFilePath("telemetry.json")` / `getUserProfileAppPath()`-Muster)

```json
{
  "schemaVersion": 1,
  "source": "fs25e-telemetry-sidecar",
  "backend": "lhm",
  "tsUtc": "2026-09-10T17:00:00.000Z",
  "tsUnixMs": 1789059600000,
  "intervalMs": 1000,
  "host": {
    "cpuLoadPct": 42.5,
    "cpuTempC": 67.0,
    "ramUsedBytes": 18900000000,
    "ramTotalBytes": 34359738368
  },
  "gpu": {
    "name": "Example GPU",
    "loadPct": 71.0,
    "tempC": 74.0,
    "vramUsedBytes": 6200000000,
    "vramTotalBytes": 12884901888
  },
  "sensors": {
    "cpuLoadPct": "ok",
    "cpuTempC": "ok",
    "gpuLoadPct": "ok",
    "gpuTempC": "ok",
    "vramUsedBytes": "ok",
    "ramUsedBytes": "ok"
  },
  "notes": []
}
```

**Feldregeln:**

- Zahlen nur wenn wirklich gelesen; sonst JSON `null` und in `sensors.*` Status `"unsupported"` | `"error"` | `"ok"`.  
- `tsUnixMs` / `tsUtc` **Pflicht** für Stale-Erkennung.  
- Keine erfundenen Defaults (kein `0` als „keine Messung“).

### 4.4 Stale-Handling (Lua)

| Bedingung | HUD-Status | Anzeige |
|-----------|------------|---------|
| Datei fehlt | `MISSING` / Feature `UNSUPPORTED` | „Sidecar nicht aktiv“ — **kein** Zahlenwert |
| JSON parse fail / Schema ≠ 1 | `INVALID` | Placeholder-Text, Log einmal throttled |
| `now - tsUnixMs > staleAfterMs` (Empfehlung: **3000–5000 ms** bei `intervalMs=1000`) | `STALE` | Letzten Wert grau + Badge „veraltet“ **oder** ausblenden (Config) |
| Sensor-Feld `null` / status ≠ `ok` | `UNSUPPORTED` für **diese** Metrik | Einzelne Zeile übersprungen |
| Sidecar-Opt-in aus | `SKIPPED` | Widget-Toggle speichert Off; kein Datei-Polling |

**Implementierungshinweise:**

- Poll-Intervall im Mod **≥ 250–500 ms** (nicht jedes Frame Datei lesen).  
- Atomar schreiben im Sidecar (`*.tmp` → rename), um Halb-Reads zu vermeiden (GDN-Forum: paralleles R/W → Permission Denied).  
- MP: Telemetrie **client-lokal**, nie syncen.

### 4.5 Admin- / Lizenz-Caveats (Dokumentation für User)

1. LHM/ähnliche Treiber können **Administratorrechte** oder Secure-Boot-Ausnahmen brauchen.  
2. NVAPI/ADL unterliegen **Vendor-Lizenz**; Sidecar-Binary separat verteilen, nicht in ModHub-Zip vermischen ohne Klärung.  
3. Sidecar ist **kein** Teil der Vanilla-Engine; Antivirus kann false positives melden.  
4. Ohne Sidecar bleibt der Mod voll funktionsfähig (Tuning + FPS aus `dt`).  
5. Keine Zusicherung „alle Sensoren auf jeder Hardware“.

---

## 5. Empfohlene Architektur

### 5a) Expert Live Overlay → alle Matrix-Caps, 0,01-Schritte + Hover-Kostenwarnungen

**Ist-Zustand:** `FS25E_LiveOverlay` + `SettingsAPI.live*` — Teilmenge Wave-1 + Expert (siehe `expert-live-overlay.md`).

**Soll:**

1. **Apply-Pfad unverändert hard-docken:** nur `liveGet` / `liveSetRequested` / `liveApply` / `liveApplyRequested` / `liveRestore` — **keine** direkten Lighting/Rendering-Setter aus der GUI (`LIVE_OVERLAY_API.md`).  
2. **Row-Katalog aus Capability-Matrix generieren** (74 Caps), UI-Gruppen:
   - **Float/Coeff** (Distance, Rain-Mults, Soft-Shadow-Floats, …): Schritt **0,01** wo sinnvoll; Clamp laut Kalibrierung (Distance vorerst Overlay 0,50–1,50 bzw. Core-Heuristik bis 2,0).  
   - **Int/Enum/Quality:** Schritt 1 (Shadow Lights, SSR/Atmosphere/DRS, Shadow-Quality-Indizes).  
   - **Bool:** Toggle.  
   - **Query-only / Gates** (`supports-*`, `has-*`, `needs-restart-*`): read-only Zeilen.  
   - **ASSET_DEPENDENT / per-light:** nur mit `opts.prefixArgs` / `keySuffix` (IES, Soft-Shadow pro Light).  
   - **Nicht im Overlay live:** `save-hardware-scalability`, `apply-performance-class`, `terrain-quality` (RESTART) — oder nur Anzeige + Warnung „nicht live“.  
3. Gates: `expertMode` + `liveTuningEnabled`; Expert-Soft-Apply wie heute (`SKIPPED` wenn Soft-Apply aus).  
4. **Hover-Kostenwarnungen nur für teure Caps** (§6) — starke Tooltip-/Badge-Texte; billige Caps ohne Warnungs-Spam.

### 5b) Bewegliche / pinbare / transparente HUD-Widgets + Per-Metrik-Toggles

| Eigenschaft | Vorschlag |
|-------------|-----------|
| Zeichnen | `FSBaseMission.draw` append; `renderText` / `setTextColor` / `drawFilledRect` (bereits Overlay) |
| Drag & Pin | Maus-Drag im Overlay-Stil; Pin speichert Position in `modSettings` |
| Transparenz | Alpha auf Panel-Rect; Config `hudAlpha` |
| Toggles | Pro Metrik: `fps`, `frametime`, `cpuLoad`, `cpuTemp`, `gpuLoad`, `gpuTemp`, `vram`, `ram` — Defaults: FPS/Frametime **an**, Hardware **aus** bis Sidecar `ok` |
| Trennung | **Tuning-Overlay** (Expert) ≠ **Perf-HUD** (immer optional sichtbar) |

### 5c) Horizontale Sparkline-Graphen (FPS / Frametime)

- Datenquelle: ausschließlich `PerformanceMonitor`-Samples (CONFIRMED-Pfad).  
- Darstellung: horizontale Balken-/Punktreihe aus `drawFilledRect` (kein externes Charting).  
- Zwei Spuren optional: Frametime (ms) primär; FPS abgeleitet sekundär.  
- Budget-Linie = `getTargetBudgetMs()` (Target-FPS).  
- Kein Sparkline für Temps/Loads ohne Sidecar-Samples (sonst Lücken/`UNSUPPORTED`).

### 5d) Graceful SKIPPED / UNSUPPORTED für Hardware-Sensoren

| Status | Wann | UI |
|--------|------|----|
| `UNSUPPORTED` | Kein Sidecar / Sensor null / Backend kann Metrik nicht | Text „Nicht verfügbar (Engine/Lua)“; optional grauer Placeholder **ohne Zahl** |
| `SKIPPED` | User-Toggle aus oder Feature-Flag aus | Zeile ausgeblendet oder „deaktiviert“ |
| `STALE` | Datei zu alt | Badge + keine „frischen“ Alarmfarben |
| `OK` | Sidecar-Feld numerisch + frisch | Anzeige Wert + Einheit |

**Platzhalter erlaubt:** Labels/Icons/Layout-Reserven.  
**Verboten:** Zufallswerte, 0 %-Fakes, kopierte Demo-Temperaturen.

---

## 6. High-Cost Caps — starke Hover-Warnungen

Nur Caps mit belegtem Kosten-/Risiko-Hinweis (Community + Matrix „Gen-1 risky“ / CPU-Warnung). Keine Warnungspflicht für unkritische Rain-Cosmetik-Parameter.

| capabilityId | Warum starke Warnung | Quelle |
|--------------|----------------------|--------|
| `view-distance-coeff` | CPU (Drawcalls), Stutter bei Blind-Increase | calibration-notes, community (Hone/PMC) |
| `lod-distance-coeff` | CPU / LOD-Übergänge | ditto |
| `foliage-view-distance-coeff` | CPU-schwer, Community warnt vor hohen foliage*-Coeffs | ditto |
| `foliage-lod-distance-coeff` | CPU-schwer | ditto |
| `terrain-lod-distance-coeff` | Mehr Terrain-Detail-Last | ditto |
| `max-num-shadow-lights` | GPU/CPU Schatten; **nicht** Default 10 (Engine-Bug-Report) | calibration-notes, community |
| `allow-foliage-shadows` | Zusätzliche Schatten-Draws | Matrix + Praxis |
| `shadow-quality` / `shadow-distance-quality` / `shadow-filter-quality` / `shadow-map-filter-size` | Schattenqualität teuer | SettingsModel quality writers |
| `ssr-quality` | GATED Reflections; GPU | Matrix GATED |
| `atmosphere-quality` | GATED | Matrix GATED |
| `drs-quality` | GATED; beeinflusst Auflösung/FPS-Ziel dynamisch | Matrix GATED |
| `rain-amount-mult` / `rain-active-drops-mult` / `rain-max-drops-mult` | Partikel-/Drop-Budget | Precipitation CONFIRMED; Plan Particle budgets |
| `rain-shallow-water-simulation` | EXPERIMENTAL; CPU/GPU-Spikes | Matrix + optimal-plan |
| `shadow-focus-box` | EXPERIMENTAL / Gen-1 risky | Matrix |
| `fast-shadow-update` | EXPERIMENTAL / Gen-1 risky | Matrix |
| `terrain-quality` | **RESTART**; Shader-Cache | SettingsModel Kommentar |
| `apply-performance-class` / `save-hardware-scalability` | Schreibt/überlagert Hardware-Profil — **nicht** casual live | WAVE1 / EXPERT_CAPS Ausschlüsse |

**Hover-Text-Kern (DE, sinngemäß):**  
„Hohe Kosten: kann Frametime/CPU stark erhöhen. Kleine Schritte, Frame-dt beobachten, bei Spikes Restore.“

---

## 7. Grafik-Setter-Abdeckung (Feintuning) — Bezug Matrix

Die Capability-Matrix listet **74** Caps (62 CONFIRMED, 6 GATED, 3 EXPERIMENTAL, 3 ASSET_DEPENDENT). Live-Feintuning ist über bestehende Setter/Getter **machbar**, sofern:

- Status `allowsApply` (expertMode für Nicht-CONFIRMED),  
- GATED: vorher `getSupports*`,  
- ASSET: lightId/Asset,  
- Restore gecacht,  
- GUI nur über `live*`.

Zusätzlich in SettingsModel-Source sichtbar, aber **noch nicht alle** in der Enhanced-Matrix (künftige Wave, nicht erfinden als „bereits wired“): z. B. `setShaderQuality`, `setSSAOQuality`, `setShadingRateQuality`, `setCloudShadowsQuality`, `setTextureResolution`, `setTyreTracksSegmentsCoeff`, Upscaler-Qualitäten (DLSS/FSR/XeSS) mit Support-Gates. Diese erst nach Matrix-Erweiterung + Smoke.

Vanilla UI nutzt für Distance oft **5 %-Schritte** (`percentStep = 0.05`); Enhanced Overlay darf **0,01** über direkte Coeff-Setter — das ist Feintuning **über** Vanilla-UI, nicht eine neue Engine-API.

---

## 8. Abgrenzung / Nicht-Ziele

- Keine DLL-/DX-/Rendergraph-Hooks, kein Memory-Patching.  
- Keine erfundenen `getFps`-/Temp-/VRAM-APIs.  
- Sidecar nicht als „Engine-Feature“ vermarkten.  
- Kein automatisches `saveHardwareScalability` / `applyPerformanceClass` beim Overlay-Apply.

---

## 9. Quellenverzeichnis (kurz)

1. GDN LuaDoc FS25 v1.20 — SettingsModel class 486; Engine Lighting/Precipitation/Rendering; documentation_overview.php  
2. `/workspace/FS25_Enhanced/docs/capability-matrix.md` (+ CSV)  
3. `/workspace/FS25_Enhanced/docs/LIVE_OVERLAY_API.md`, `expert-live-overlay.md`, `EXPERT_CAPS.md`  
4. `/workspace/FS25_Enhanced/scripts/Core/PerformanceMonitor.lua`  
5. `/workspace/FS25_Enhanced/docs/gdn-research.md`, `community-optimizations.md`, `calibration-notes.md`, `PHASE1.md`  
6. AutoVRAMOptimizer README: Lua liest keine physische VRAM; externer Helper → modSettings  
7. GDN-Forum: Lua-Sandbox → Kommunikation über Dateien  

---

*Dokumentations-Deliverable. Keine neuen Engine-APIs behauptet.*
