# FS25 Enhanced

**Author / Autor:** CeberusOne  
**Current version / Aktuelle Version:** 0.4.2.8  
**Game:** Farming Simulator 25 (GIANTS Engine 10, Lua, modDesc 113)

Client-side graphics controls in one movable live window. Every control is a documented engine setter, a GameSettings value or an authored shader parameter of the game — read, written, read back and restored. No custom renderer, no binary hooking, no adaptive governor.

Client-seitige Grafikregler in einem verschiebbaren Live-Fenster. Jeder Regler ist ein dokumentierter Engine-Setter, ein GameSettings-Wert oder ein ab Werk vorhandener Shader-Parameter — gelesen, geschrieben, zurückgelesen und zurückgenommen. Keine eigene Renderpipeline, kein Binary-Hooking, keine Automatik.

---

## Deutsch

### Bedienung
- **F9** öffnet und schließt das Live-Fenster. Titelleiste ziehen = verschieben, rechte untere Ecke = Größe ändern, `[]` setzt das Layout zurück.
- Der Knopf **MOD / VANILLA** in der Kopfzeile (oder Alt+F9) schaltet den Vergleich um.
- **Presets → Qualitätsstufe:** Niedrig / Mittel / Hoch / Sehr hoch / **Ultra** setzt nur Aufwand (Sichtweite, Schatten, Lampenbudgets, SSAO, Reflexionen). Lack, Nässe, Farbe, Sichtfeld und Stimmungen bleiben eigene Regler.
- **Presets → Mod-Sprache:** Auto / Deutsch / Englisch.
- Nicht verfügbare Regler sind standardmäßig ausgeblendet. Der Schalter *Nicht verfügbare Regler ausblenden* zeigt sie wieder, inklusive Begründung.
- **Tab zurück** gibt nur die offene Kategorie an das Spiel zurück.

### Was drin ist
- **Schatten, Lichter & Lampen** inklusive Hof-bei-Nacht
- **Umgebung:** Sonne, God Rays (Faktor, nie hart aus), Lichtstimmungen, Sonnenschatten 1024–4096
- **Bild & Tonwerte, Wasser, Materialien, Vegetation, LOD, Kamera & Spiegel**
- **VanillaGuard:** die Grafikseite des Spiels sieht und speichert nie Mod-Werte

### Was der Mod nicht macht
- keine eigene Renderpipeline, keine erfundenen Shader
- keine Belichtung / Bloom / Color Grading (kein Live-Lua-Vertrag)
- keine DRS, kein Shadow-Focus als An/Aus, kein Adaptive-Governor
- Upscaler, AA, Textur- und Shaderqualität bleiben im Hauptmenü
- keine FPS-Garantie

### Download & Installation
1. `FS25_Enhanced.zip` von der [Releases-Seite](https://github.com/CeberusOne/FS25_Enhanced/releases/latest) laden – die Datei heißt immer so, ohne Versionsnummer.
2. Die Zip unverändert nach `Dokumente/My Games/FarmingSimulator2025/mods/` legen.
3. Im Mod-Menü aktivieren, im Spiel **F9** drücken. `log.txt` zeigt `[FS25_Enhanced]`-Zeilen.

### Lizenz
All Rights Reserved — Copyright © 2026 CeberusOne. Siehe `LICENSE`.

---

## English

### Controls
- **F9** opens and closes the live window. The header button compares MOD / VANILLA.
- **Quality level** Low–Ultra changes effort only (distance, shadows, lamps, SSAO). Paint, wetness, colour and moods stay separate.
- Unavailable controls are hidden by default.

### Download & install
1. Get `FS25_Enhanced.zip` from the [latest release](https://github.com/CeberusOne/FS25_Enhanced/releases/latest) – the file is always named like this, without a version number.
2. Put the zip unchanged into `Documents/My Games/FarmingSimulator2025/mods/`.
3. Enable it in the mod screen and press **F9** in game.

### What it does not do
- no custom renderer, no invented post-processing
- no exposure / bloom / color grading live API
- no adaptive FPS governor
- upscalers and anti-aliasing stay in the game menu

### License
All Rights Reserved — Copyright © 2026 CeberusOne.
