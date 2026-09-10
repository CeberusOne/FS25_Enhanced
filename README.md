# FS25 Enhanced

**Author / Autor:** CeberusOne  
**Current version / Aktuelle Version:** 0.4.2.3  
**Game:** Farming Simulator 25 (Giants Engine 10, Lua)

Client-local graphics & performance helper. It tunes **documented** engine graphics settings (shadows, LOD/view distance, etc.) through a safe capability layer — **not** a custom renderer and **not** binary hooking.

Client-seitiger Grafik-/Performance-Helfer. Er justiert **dokumentierte** Engine-Grafikeinstellungen (Schatten, LOD/Sichtweite usw.) über eine sichere Capability-Schicht — **keine** eigene Renderpipeline und **kein** Binary-Hooking.

---

## Deutsch

### Was die Mod macht
- **Simple:** Mod an/aus, Preset (Performance / Balanced / Quality / Cinematic), Target-FPS, **Adaptiv**
- **Advanced:** Wave-1-Einstellungen (Schatten, LOD, Sichtweite, Foliage …) in Stufen
- **Expert:** Experimentelle Caps hinter Expert-Modus; Soft-Apply; Live-Overlay mit eigenen Balken (kein Giants-Slider)
- **Status / Diagnostics:** Was APPLIED / REJECTED / SKIPPED wurde — zum Nachvollziehen
- **Pro-HUD:** FPS & Frametime aus der Engine; Systemwerte (CPU/GPU/Temp/VRAM/RAM) nur mit optionalem Sidecar, sonst **DISCONNECTED** (keine Fake-Zahlen)
- **Hover-Hilfe:** Kurze spielerfreundliche Erklärungen zu den Parametern (was du siehst / was es kostet)
- Beim Verlassen der Map: **Vanilla-Restore** der von der Mod gesetzten Werte
- Settings landen unter `modSettings/FS25_Enhanced/`

### Casual-Automatik (Adaptiv)
Wenn **Mod an** + **Adaptiv an** + Target-FPS: Der Governor hält die Ziel-FPS über **Wave-1-Presets** (Performance ↔ Balanced ↔ Quality), inkl. leichter Feinjustierung innerhalb dieses Bündels. Manuelles Preset schaltet Adaptiv aus.

### Was sie bewusst nicht macht / nicht kann
- **Keine eigene Renderpipeline** — nur Parameter der bestehenden Engine
- **Kein Binary-/Memory-Hook**, kein Cheat, kein Gameplay-Vorteil im klassischen Sinn
- **Kein Auto für Expert/Experimental** (SSR, FocusBox, Rain-Suite …) — nur manuell hinter Expert
- **Kein feines „Umgebung um den Spieler“-Raycast-System** — Adaptiv ist FPS-/Last-gesteuert, kein KI-Weltanalyse-Zauber
- **Keine echten System-Sensoren aus Lua allein** — ohne Sidecar keine CPU/GPU/VRAM-Zahlen
- **Keine Giants-nativen Slider** (Crash-Risiko) — Overlay nutzt eigene Balken
- **Kein Netzwerk-Sync der Grafikwerte** — rein **client-lokal** (jeder Spieler seine Einstellungen)
- **Keine Garantie für +X % FPS** — hängt von Hardware, Map und Ausgangseinstellungen ab
- Defaults sind **sicher**: Adaptiv / Soft-Apply / Experimental standardmäßig **aus**

### Download & Install
1. Release-Zip von der [Releases-Seite](https://github.com/CeberusOne/FS25_Enhanced/releases) laden (`FS25_Enhanced_x.y.z.z.zip`)
2. Entpacken nach `mods/FS25_Enhanced/` (Ordnername muss passen)
3. Im Mod-Menü aktivieren und `log.txt` auf `[FS25_Enhanced]` prüfen

Ältere Versionen bleiben auf der Releases-Seite zum Download.

### Lizenz
All Rights Reserved — Copyright © 2026 CeberusOne. Siehe [`LICENSE`](LICENSE).  
Farming Simulator / Giants Engine sind Marken der jeweiligen Rechteinhaber. Unofficial Mod, nicht von GIANTS endorsed.

---

## English

### What this mod does
- **Simple:** enable/disable, presets (Performance / Balanced / Quality / Cinematic), target FPS, **Adaptive**
- **Advanced:** Wave-1 controls (shadows, LOD, view distance, foliage, …) as stepped options
- **Expert:** experimental caps behind Expert mode; Soft-Apply; live overlay with custom bars (no Giants sliders)
- **Status / Diagnostics:** APPLIED / REJECTED / SKIPPED visibility for troubleshooting
- **Pro HUD:** engine FPS & frametime; system metrics (CPU/GPU/temp/VRAM/RAM) only with an optional sidecar — otherwise **DISCONNECTED** (never invents numbers)
- **Hover help:** short player-friendly explanations (what you see / what it costs)
- **Vanilla restore** when leaving the map for values the mod applied
- Settings stored under `modSettings/FS25_Enhanced/`

### Casual automation (Adaptive)
With **mod on** + **Adaptive on** + target FPS, the governor holds your target FPS via **Wave-1 presets** (Performance ↔ Balanced ↔ Quality), with light fine-nudges inside that bundle. Choosing a preset manually turns Adaptive off.

### What it intentionally does not do / cannot do
- **No custom render pipeline** — only existing engine parameters
- **No binary/memory hooks**, not a cheat / gameplay exploit
- **No auto-apply for Expert/Experimental caps** (SSR, FocusBox, rain suite, …) — manual / Expert only
- **No fine “world around the player” scene AI** — Adaptive is FPS/load driven, not a per-object environment tuner
- **No native Lua access to full system sensors** — without a sidecar there are no CPU/GPU/VRAM figures
- **No Giants native sliders** (crash risk) — overlay uses custom bars
- **No network sync of graphics values** — **client-local only**
- **No promised +X% FPS** — results depend on hardware, map, and baseline settings
- Safe defaults: Adaptive / Soft-Apply / Experimental stay **off** until you enable them

### Download & install
1. Get the zip from [Releases](https://github.com/CeberusOne/FS25_Enhanced/releases) (`FS25_Enhanced_x.y.z.z.zip`)
2. Extract to `mods/FS25_Enhanced/` (folder name must match)
3. Enable in the mod screen; check `log.txt` for `[FS25_Enhanced]`

Older releases remain available for download.

### License
All Rights Reserved — Copyright © 2026 CeberusOne. See [`LICENSE`](LICENSE).  
Farming Simulator / Giants Engine are trademarks of their respective owners. Unofficial mod, not affiliated with or endorsed by GIANTS Software.

---

## Quick links

- [Latest release](https://github.com/CeberusOne/FS25_Enhanced/releases/latest)
- [Adaptive (honest scope)](docs/ADAPTIVE.md)
- [Hover help](docs/hover-help.md)
- [Capability matrix](docs/capability-matrix.md)
