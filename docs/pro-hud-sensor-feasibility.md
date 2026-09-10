# Pro Live HUD — Sensor-Feasibility (Research)

**Repo:** CeberusOne/FS25_Enhanced  
**Quelle:** GDN LuaDoc FS25 Script/Engine **v1.20.0.0** + bestehende Repo-Docs (`capability-matrix.md`, `wave1-smoke-checklist.md`, `gdn-research.md`, `community-optimizations.md`, `LIVE_OVERLAY_API.md`, `expert-live-overlay.md`)  
**Scope:** Docs only. **Keine spekulativen Engine-APIs.** Erfundene / community-übliche, aber in GDN nicht gelistete Namen → **UNSUPPORTED**.  
**Telemetrie-Entscheidung (Stabschef):** Engine/Lua-nativ nur **FPS + Frametime**. CPU/GPU/VRAM/RAM **nicht** als Engine-CONFIRMED verkaufen — optionaler **Sidecar** schreibt `modSettings/FS25_Enhanced/telemetry.json`.

---

## Executive

| Frage | Kurzantwort |
|-------|-------------|
| FPS „safe“ als Engine-Sensor? | **Nein als Lua-Getter.** GDN dokumentiert nur Console/`showFps` und F2-Anzeige (`documentation_overview.php`). Kein `getFps` in LuaDoc v1.20.0.0. |
| FPS im Mod-HUD? | **Ja — MOD_SIDE:** aus `update(dt)` ableiten (`fps ≈ 1000/dt` bzw. gleitendes Fenster). Optional Vanilla F2/`showFps` nur zur Beobachtung. |
| Frametime? | **MOD_SIDE — sicher:** `dt` aus Mission-`update(dt)` (bereits Phase-1 `PerformanceMonitor`). Kein Engine-Sensor nötig. |
| CPU/GPU Load + Temp, VRAM, RAM? | **UNSUPPORTED** als GDN Engine/Script-Sensor. Keine Symbole `getCpu*`, `getGpu*`, `getVram*`, `getMemory*` (Load/Temp) in LuaDoc v1.20.0.0 gefunden. **Nur via optionalem Sidecar** → JSON-Datei. |
| Performance-Class Utils? | `Utils.getPerformanceClassFromIndex` / `getPerformanceClassId` / `getPerformanceClassIndex` und SettingsModel `getPerformanceClass()` / `getAutoPerformanceClass()` = **Profil-Labels**, **keine** Live-FPS/HW-Last. |
| AutoVRAM / TextureStreaming? | Community erwähnt `setTextureStreamingMemoryBudget` (AutoVRAMOptimizer) — **kein** bestätigter GDN-Telemetry-Getter für belegte VRAM; nicht als HUD-Sensor verkaufen. |
| Fake-Zahlen? | **Verboten.** Fehlt Sidecar oder Daten stale → UI „disconnected“ / Felder auslassen — **nie** 0 % oder Platzhalter-Last vortäuschen. |

**MVP-HUD:** nur Frametime (+ abgeleitete FPS) aus Lua. Hardware-Metriken nur wenn Sidecar frisch liefert.

---

## Sensor matrix table

| metric | approach | GDN symbol or NONE | status | notes |
|--------|----------|--------------------|--------|-------|
| **FPS** | Mod: gleitend aus `dt`; Debug: Vanilla-Anzeige | Console **`showFps`**; Shortcut **F2** (`documentation_overview.php`). **Kein** Script/Engine-`getFps` in LuaDoc | **MOD_SIDE** (Anzeige-API CONFIRMED nur als Console/Debug) | Safe für HUD-Schätzung. Nicht als „Engine FPS Sensor API“ labeln. |
| **Frametime** | `update(dt)` / Sliding Window | **NONE** (Engine-Sensor); Parameter `dt` der Mission-Update-Schleife | **MOD_SIDE** | Explizit erlaubt als mod-seitige Messung. Spike/Variance wie Phase-1. |
| **CPU load** | Sidecar → JSON | **NONE** in GDN LuaDoc | **UNSUPPORTED** (Engine) / **SIDECAR** | Siehe Sidecar-Backends. |
| **CPU temp (°C)** | Sidecar → JSON | **NONE** | **UNSUPPORTED** / **SIDECAR** | Oft Admin-/Treiber-abhängig. |
| **GPU load** | Sidecar → JSON | **NONE** | **UNSUPPORTED** / **SIDECAR** | Vendor-APIs (z. B. NVAPI) ≠ Giants. |
| **GPU temp (°C)** | Sidecar → JSON | **NONE** | **UNSUPPORTED** / **SIDECAR** | |
| **VRAM** (used/total) | Sidecar → JSON | **NONE** als Usage-Getter | **UNSUPPORTED** / **SIDECAR** | `setTextureStreamingMemoryBudget` (Community) ≠ Live-VRAM-Sensor; in GDN-Suche nicht als Telemetry bestätigt. |
| **RAM** (used/total) | Sidecar → JSON | **NONE** | **UNSUPPORTED** / **SIDECAR** | Lua `collectgarbage("count")` = **Lua-Heap**, nicht System-RAM — **nicht** als RAM-Metrik verwenden. |

### Explizit UNSUPPORTED (häufig erfunden / undokumentiert)

Falls in Code/Foren auftauchen und **nicht** auf GDN Script/Engine v1.20.0.0 stehen:

`getFps`, `getFrameTime`, `getCpuLoad`, `getCpuTemp`, `getGpuLoad`, `getGpuTemp`, `getVram`, `getVramUsage`, `getGpuMemory`, `getMemoryUsage`, `getAvailableMemory`, `getSystemMemory` — Status: **UNSUPPORTED**.

### Verwandte CONFIRMED Symbole (kein HUD-Sensor)

| Symbol | Rolle |
|--------|--------|
| `Utils.getPerformanceClassFromIndex` / `getPerformanceClassId` / `getPerformanceClassIndex` | Profil-Index ↔ Label |
| `getPerformanceClass()` / `getAutoPerformanceClass()` (via SettingsModel-Source) | Aktuelle Performance-Class / Auto-Flag |
| `SettingsModel:applyPerformanceClass` / `saveHardwareScalability` | Apply/Persist Hardware-Scalability — **nicht** Live-Telemetrie; Wave-1 ausgeschlossen ohne Opt-in |
| `enableFramerateLimit` / `framerateLimitFPS` | Console Limiter — kein Sensor |

---

## Sidecar-Telemetrie (nicht Giants)

### Vertrag

- **Pfad:** `modSettings/FS25_Enhanced/telemetry.json` (unter User-Profile / `getUserProfileAppPath()`-Konvention wie übrige ModSettings).
- **Schreiber:** optionaler externer Prozess (Windows Sidecar). Mod **liest nur**; schreibt keine Fake-HW-Werte.
- **Ohne Sidecar:** Pure-Lua-HUD zeigt nur FPS/Frametime; HW-Zeilen **disconnected** / ausgeblendet — graceful, kein Crash.

### Schema-Felder (Stabschef)

| Feld | Typ (erwartet) | Bedeutung |
|------|----------------|-----------|
| `timestamp` | number (Unix epoch s oder ms — Sidecar dokumentieren) | Schreibzeitpunkt |
| `cpuLoad` | number (0–100 oder 0–1 — Sidecar dokumentieren) | CPU-Auslastung |
| `cpuTempC` | number | CPU-Temperatur °C |
| `gpuLoad` | number | GPU-Auslastung |
| `gpuTempC` | number | GPU-Temperatur °C |
| `vramUsedMB` | number | Belegter VRAM (MB) |
| `vramTotalMB` | number | Gesamt-VRAM (MB) |
| `ramUsedMB` | number | Belegter System-RAM (MB) |
| `ramTotalMB` | number | Gesamt-System-RAM (MB) |

### Stale / Disconnect

- Wenn `timestamp` fehlt **oder** Alter **> 2 s** → Status **disconnected**.
- Bei disconnected: **keine** alten Werte anzeigen als aktuell; **keine** erfundenen Defaults.
- Parse-Fehler / Datei fehlt → ebenfalls disconnected.

### Typische Windows-Backends (Research Notes — **keine** Giants-APIs)

| Backend | Liefert typischerweise | Caveats |
|---------|------------------------|---------|
| **LibreHardwareMonitor** (LHM / OpenHardwareMonitor-Fork) | CPU/GPU Load + Temp, RAM; teils GPU-Speicher je Hardware | Sensor-Namen hardwareabhängig; oft erhöhte Rechte; DLL/IPC-Setup außerhalb des Mods |
| **NVAPI** (NVIDIA) | GPU Load, Temp, VRAM (NVIDIA) | Nur NVIDIA; Treiber-/SDK-Bindung; Lizenz/Redistribution beachten |
| **Windows Performance Counters** | CPU %, Prozess-RAM, teils GPU-Engine (je OS-Version) | GPU-Counter inkonsistent; kein universelles VRAM/Temp |
| **WMI** | CPU Load, Temp (wenn Treiber exponiert), RAM | Temp oft unzuverlässig/fehlt; Latenz; Admin-Policies |

**Hinweis:** Sidecar-Implementierung ist **außerhalb** GDN-LuaDoc und Gen-1 Engine-CONFIRMED. Research flaggt nur Machbarkeit + Schema; Core verkauft HW-Metriken nicht als Engine-API.

---

## Live-Overlay API risks (0.01 fine tune)

Bezug: `docs/expert-live-overlay.md`, `docs/LIVE_OVERLAY_API.md`, Matrix. UI (MultiTextOption / Custom Overlay) = GUI-Team; Research flaggt nur **Restore/Apply-Risiken**.

### Regel

- **Kein Giants Slider** (`GuiSlider`) — Enum/`MultiTextOption` oder custom Overlay-Drawing.
- Feintuning **0.01** für alle Float-Matrix-Caps im Overlay (Wave-1 Coeffs + Expert `rain-amount-mult`).
- Apply nur über `FS25E_SettingsAPI.live*` — keine direkten Engine-Setter aus GUI.
- Matrix-`applyMode=UNKNOWN` → **nie LIVE annehmen**; Session-Apply + Getter-Cache/Restore.
- **`setTerrainQuality`:** `applyMode=RESTART` (SettingsModel-Kommentar: Shader-Cache) — **nicht** im Live-Overlay-Fast-Path.

### Wave-1 / Expert Caps mit Getter für Restore (Overlay-relevant)

| capabilityId | Getter (Restore) | applyMode | Overlay 0.01? |
|--------------|------------------|-----------|---------------|
| `view-distance-coeff` | `getViewDistanceCoeff` | UNKNOWN | ja (0.50–1.50) |
| `lod-distance-coeff` | `getLODDistanceCoeff` | UNKNOWN | ja |
| `foliage-view-distance-coeff` | `getFoliageViewDistanceCoeff` | UNKNOWN | ja |
| `foliage-lod-distance-coeff` | `getFoliageLODDistanceCoeff` | UNKNOWN | ja |
| `terrain-lod-distance-coeff` | `getTerrainLODDistanceCoeff` | UNKNOWN | ja |
| `max-num-shadow-lights` | `getMaxNumShadowLights` | UNKNOWN | nein (Schritt 1) |
| `allow-foliage-shadows` | `getAllowFoliageShadows` | UNKNOWN | bool |
| `shadow-quality` | `getShadowQuality` (+ `getHasShadowFocusBox` in Reader) | UNKNOWN | enum |
| `shadow-distance-quality` | `getShadowDistanceQuality` | UNKNOWN | enum |
| `shadow-filter-quality` | `getShadowFilterQuality` | UNKNOWN | enum |
| `rain-amount-mult` | `getRainAmountMultiplier` | UNKNOWN | ja (Expert) |
| `ssr-quality` | `getScreenSpaceReflectionsQuality` | UNKNOWN | GATED + `getSupports*` |
| `atmosphere-quality` | `getAtmosphereQuality` | UNKNOWN | GATED |
| `drs-quality` | `getDRSQuality` | UNKNOWN | GATED |
| `light-soft-shadow-size` | `getLightSoftShadowSize` | UNKNOWN | per-light |
| `light-soft-shadow-distance` | `getLightSoftShadowDistance` | UNKNOWN | per-light |
| `light-soft-shadow-depth-bias` | `getLightSoftShadowDepthBiasFactor` | UNKNOWN | per-light |
| `light-shadow-priority` | `getLightShadowPriority` | UNKNOWN | per-light |

### Ohne zuverlässigen Getter / hohes Risiko

| capabilityId | Risiko |
|--------------|--------|
| `shadow-focus-box` | EXPERIMENTAL; Setter `setShadowFocusBox`, **kein** dedizierter Getter; Restore via `setShadowFocusBox(0)` |
| `fast-shadow-update` | EXPERIMENTAL; **kein** Getter in Matrix |
| `rain-shallow-water-simulation` | EXPERIMENTAL; **kein** Getter |
| `merge-light-shadows` | Restore über `splitLightShadow` / Merge-Membership-Cache, nicht einfacher Float-Getter |
| `terrain-quality` | **RESTART** — nicht Live-tunen |
| `save-hardware-scalability` / `apply-performance-class` | Persistenz/Profil — nicht Overlay |

---

## Cost-warning heuristic (capabilityId list)

**Label: Heuristik — kein GDN Cost-API.** Ableitung aus Community (`community-optimizations.md`, Performance-Guides) + Matrix-Notizen (hohe Coeffs, viele Shadow-Lights, Foliage, Soft/Merge extrem, Experimental Focus).

| capabilityId | Warum „expensive“-Warnung (heuristisch) |
|--------------|----------------------------------------|
| `view-distance-coeff` | Hohe Object-Draw-Distance → CPU/Draw-Last |
| `lod-distance-coeff` | Mehr Detail-Meshes länger sichtbar |
| `foliage-view-distance-coeff` | Foliage stark FPS-sensitiv (Community/F8-Stats) |
| `foliage-lod-distance-coeff` | Foliage-LOD teuer bei hohen Werten |
| `terrain-lod-distance-coeff` | Terrain-LOD / Distanz |
| `max-num-shadow-lights` | Viele Shadow-Caster → sehr teuer (Ultra/hohe Counts) |
| `shadow-quality` | Shadow-Maps CPU+GPU |
| `shadow-distance-quality` | Shadow-Distanz CPU-lastig |
| `shadow-filter-quality` | Soft Shadows teurer Filter |
| `allow-foliage-shadows` | Foliage + Shadows kombiniert teuer |
| `light-soft-shadow-size` / `distance` / `depth-bias` | Soft-Shadow Extremwerte teuer |
| `merge-light-shadows` | Merge-Approximierung / viele Merges — Vorsicht bei extremem Einsatz |
| `shadow-focus-box` | EXPERIMENTAL Focus — unvorhersehbare Kosten |
| `fast-shadow-update` | EXPERIMENTAL |
| `ssr-quality` / `atmosphere-quality` / `drs-quality` | GATED High-End-Qualitäten |
| `rain-amount-mult` / `rain-max-drops-mult` / `rain-active-drops-mult` | Viele Drops → GPU/CPU |
| `rain-shallow-water-simulation` | EXPERIMENTAL Kopplung |

UI darf Warn-Badges zeigen; **keine** behauptete Engine-`getCost()`-API.

---

## Recommended MVP HUD (only safe metrics)

| Anzeige | Quelle | Bedingung |
|---------|--------|-----------|
| Frametime (ms) | MOD_SIDE `dt` / Sliding Window | Immer (Pure Lua) |
| FPS (abgeleitet) | MOD_SIDE `1000/avg(dt)` o. ä. | Immer; Hinweis „geschätzt“, nicht Engine-Sensor |
| Optional: Hinweis F2/`showFps` | GDN overview | Nur Debug/Vergleich |
| CPU/GPU/VRAM/RAM | Sidecar JSON | Nur wenn Datei lesbar **und** `timestamp` ≤ 2 s; sonst **disconnected** |
| Cost-Warnungen | Heuristik auf Caps | Unabhängig von HW-Sensoren |

**Nicht im MVP:** erfundene `getFps`/HW-Getter, Lua-Heap als System-RAM, AutoVRAM-Budget als VRAM-Anzeige, Performance-Class als „Load %“.

---

## Quellen (GDN + Repo)

- https://gdn.giants-software.com/documentation_overview.php — F2, `showFps`, Limiter-Commands  
- https://gdn.giants-software.com/documentation_scripting_fs25.php — Script/Engine v1.20.0.0 Index  
- Utils: `...?category=90&class=880&version=engine` — `getPerformanceClass*`  
- SettingsModel: `...?version=script&category=43&class=486` — Quality-Writer/Reader, `applyPerformanceClass`, `saveHardwareScalability`, Terrain restart-comment  
- Repo: `docs/capability-matrix.md`, `docs/wave1-smoke-checklist.md`, `docs/PHASE1.md`, `docs/gdn-research.md`, `docs/community-optimizations.md`, `docs/LIVE_OVERLAY_API.md`, `docs/expert-live-overlay.md`

---

*Research-Freeze-Stil: nur exakte, gefundene Symbole als CONFIRMED; Rest UNSUPPORTED oder MOD_SIDE/SIDECAR klar getrennt.*
