# FS25 Enhanced

**Author / Autor:** CeberusOne  
**Current version / Aktuelle Version:** 0.4.2.7  
**Game:** Farming Simulator 25 (GIANTS Engine 10, Lua, modDesc 113)

Client-side graphics controls in one movable live window. Every control is a documented engine setter, a GameSettings value or an authored shader parameter of the game — read, written, read back and restored. No custom renderer, no binary hooking.

Client-seitige Grafikregler in einem verschiebbaren Live-Fenster. Jeder Regler ist ein dokumentierter Engine-Setter, ein GameSettings-Wert oder ein ab Werk vorhandener Shader-Parameter des Spiels — gelesen, geschrieben, zurückgelesen und zurückgenommen. Keine eigene Renderpipeline, kein Binary-Hooking.

---

## Deutsch

### Bedienung
- **F9** öffnet und schließt das Live-Fenster (auch Shift+F9 / Strg+E). Titelleiste ziehen = verschieben, rechte untere Ecke = Größe ändern, `[]` setzt das Layout zurück. Maus, Tastatur und Controller.
- **Alt+F9** (oder der Knopf in der Kopfzeile) schaltet zwischen **MOD** und **VANILLA** um – direkter Vergleich, die Einstellungen bleiben erhalten.
- **Presets → Qualitätsstufe:** Niedrig / Mittel / Hoch / Sehr hoch / **Ultra** setzt alle Qualitätsregler auf einmal. Ultra = jeder Regler auf Maximum, unabhängig von der Stufe im Spielmenü.
- **Presets → Mod-Sprache:** Auto (Spielsprache) / Deutsch / Englisch.
- Jeder Regler zeigt, was er kostet und ob er gerade wirken kann („nicht verfügbar“, „Weltmaterialien werden gesucht“, …). Nichts wird behauptet, was nicht zurückgelesen wurde.

### Was drin ist (14 Kategorien, 131 Regler)
- **Schatten:** Qualität, Distanz, Filter, Lichter mit Schatten, Wolkenschatten, Spotschatten-Atlas, Fahrzeugschatten-Budget und -Auflösung
- **Lichter & Lampen:** Stärke, Wärme, Tönung, Reichweite, IES, Streuung (schaltet wirklich ein), Budgets, Lichtprofil
- **Umgebung:** Sonnenstärke/-wärme/-tönung, Streuung, **God Rays**, Lichtstimmungen, Baumkronen-Verdeckung und -Gegenlicht, Lichtdurchlass von Feldfrucht und Vegetation, Kontrast/Helligkeit bemalter Flächen
- **Bild & Tonwerte:** SSAO, filmische Tonwertkurve (Kontrast, Schatten, Lichter, Schwarz-/Weißpunkt)
- **Wasser:** Bodennässe (dynamisch mit dem Regen), Abtrockenzeit, Nassspiegelung und -stärke auf Gebäuden und Straßen, Pfützen, Wasser-Reflexionsrauheit, Schaum
- **Materialien:** Lackspiegelung relativ zur ab Werk hinterlegten Lackierung – Glas, blanker Gummi, Holz, Stoff und Rückstrahler werden nie angefasst, lackierter Gummi/Kunststoff wird automatisch erkannt
- **Atmosphäre, Reflexionen, Wetter, Vegetation, Sichtweite/LOD, Kamera & Spiegel** (Sichtfeld, Spiegelanzahl)

### Strikt getrennt vom Spielmenü
Die Engine hat nur einen Zustand. Deshalb nimmt der Mod alle seine Werte zurück, bevor die Grafikseite des Spiels liest oder das Spiel speichert, und wendet sie danach wieder an. Die Spielseite sieht, bearbeitet und speichert nur die eigenen Werte des Spielers. Upscaler, Kantenglättung, VRS, DRS, Textur- und Shaderqualität sind bewusst **nicht** im Mod – sie gehören ins Hauptmenü.

### Was der Mod nicht macht
- keine eigene Renderpipeline, keine erfundenen Shader – nur Parameter, die das Spiel selbst mitbringt (`data/shaders/*.xml`, `SettingsModel.lua`, Script-Binding)
- keine Memory-Hooks, kein Gameplay-Vorteil, kein Netzwerk-Sync (rein client-lokal)
- keine FPS-Garantie; die Qualitätsstufe ist ein Bündel von Reglern, kein Autopilot

### Download & Installation
1. `FS25_Enhanced.zip` von der [Releases-Seite](https://github.com/CeberusOne/FS25_Enhanced/releases/latest) laden – die Datei heißt immer so, ohne Versionsnummer.
2. Die Zip unverändert nach `Dokumente/My Games/FarmingSimulator2025/mods/` legen (oder entpackt als `mods/FS25_Enhanced/`).
3. Im Mod-Menü aktivieren, im Spiel **F9** drücken. `log.txt` zeigt `[FS25_Enhanced]`-Zeilen.

### Entwicklung
Offline-Prüfung ohne Spiel (Lua 5.1):

```bash
MOD_DIR="$PWD" lua tools/smokeBootstrap.lua     # kompletter Lade- und Missionslauf
MOD_DIR="$PWD" lua tools/smokeControls.lua
MOD_DIR="$PWD" lua tools/smokeMaterials.lua
MOD_DIR="$PWD" lua tools/smokeWetSurfaces.lua
MOD_DIR="$PWD" lua tools/smokeVanillaGuard.lua
python tools/validateConfig.py && python tools/validateLocalization.py
```

Quellen und Belege jedes Reglers: [`docs/ENGINE_SETTINGS.md`](docs/ENGINE_SETTINGS.md). Bekannte Grenzen: [`docs/KNOWN_LIMITATIONS.md`](docs/KNOWN_LIMITATIONS.md). Änderungen: [`docs/CHANGELOG.md`](docs/CHANGELOG.md).

### Lizenz
All Rights Reserved — Copyright © 2026 CeberusOne. Siehe [`LICENSE`](LICENSE).  
Farming Simulator / GIANTS Engine sind Marken der jeweiligen Rechteinhaber. Inoffizieller Mod, nicht von GIANTS unterstützt.

---

## English

### Controls
- **F9** opens and closes the live window (also Shift+F9 / Ctrl+E). Drag the title bar to move it, the bottom-right corner to resize, `[]` resets the layout. Mouse, keyboard and controller.
- **Alt+F9** (or the header button) switches between **MOD** and **VANILLA** for a direct comparison; the settings are kept.
- **Presets → Quality level:** Low / Medium / High / Very high / **Ultra** sets every quality control at once. Ultra puts each control at its maximum, independent of the level chosen in the game menu.
- **Presets → Mod language:** Auto (game language) / German / English.
- Every control states its cost and whether it can act right now ("unavailable", "scanning world materials", …). Nothing is claimed that was not read back.

### What is inside (14 categories, 131 controls)
- **Shadows:** quality, distance, filter, shadow-casting lights, cloud shadows, spot shadow atlas, vehicle shadow budget and resolution
- **Lights & lamps:** intensity, warmth, tint, range, IES, scattering (actually switches on), budgets, lights profile
- **Environment:** sun intensity/warmth/tint, scattering, **god rays**, light moods, canopy occlusion and backlight, crop and foliage translucency, contrast/brightness of painted surfaces
- **Image & tone:** SSAO, filmic tone curve (contrast, shadows, highlights, black/white point)
- **Water:** ground wetness (dynamic with the rain), drying time, wet reflection and strength on buildings and roads, puddles, water reflection roughness, foam
- **Materials:** paint reflection relative to each material's authored finish – glass, bare rubber, wood, fabric and reflectors are never touched, lacquered rubber/plastic is detected automatically
- **Atmosphere, reflections, weather, foliage, draw distance/LOD, camera & mirrors** (field of view, mirror count)

### Strictly separate from the game menu
The engine has one state. The mod therefore restores all of its values before the game's graphics page reads or the game saves, and applies them again afterwards. The game page only ever sees, edits and stores the player's own settings. Upscalers, anti-aliasing, VRS, DRS, texture and shader quality are deliberately **not** part of the mod – they belong in the main menu.

### What the mod does not do
- no custom render pipeline, no invented shaders – only parameters the game ships (`data/shaders/*.xml`, `SettingsModel.lua`, script binding)
- no memory hooks, no gameplay advantage, no network sync (client-local only)
- no FPS promise; the quality level is a bundle of controls, not an autopilot

### Download & install
1. Get `FS25_Enhanced.zip` from the [latest release](https://github.com/CeberusOne/FS25_Enhanced/releases/latest) – the file is always named like this, without a version number.
2. Put the zip unchanged into `Documents/My Games/FarmingSimulator2025/mods/` (or extract it as `mods/FS25_Enhanced/`).
3. Enable it in the mod screen and press **F9** in game. `log.txt` shows `[FS25_Enhanced]` lines.

### Development
Offline checks without the game (Lua 5.1): see the commands in the German section. Sources for every control: [`docs/ENGINE_SETTINGS.md`](docs/ENGINE_SETTINGS.md) (German). Known limits: [`docs/KNOWN_LIMITATIONS.md`](docs/KNOWN_LIMITATIONS.md). Changes: [`docs/CHANGELOG.md`](docs/CHANGELOG.md).

### License
All Rights Reserved — Copyright © 2026 CeberusOne. See [`LICENSE`](LICENSE).  
Farming Simulator / GIANTS Engine are trademarks of their respective owners. Unofficial mod, not affiliated with or endorsed by GIANTS Software.
