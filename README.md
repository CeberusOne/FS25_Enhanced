# FS25 Enhanced

> **More control over the way Farming Simulator 25 looks — using graphics options the game does not expose, or exposes only partially.**

**Author / Autor:** CeberusOne

**Current release / Aktuelle Version:** 0.4.2.8

**Game:** Farming Simulator 25 · GIANTS Engine 10 · PC

FS25 Enhanced adds a movable live graphics panel to Farming Simulator 25. It brings together a broad range of runtime settings for shadows, lighting, environment, materials, vegetation, visibility and image presentation. Many of these parameters already exist in the GIANTS Engine but are not available in the normal graphics menu, or can only be changed indirectly through combined quality presets.

The purpose is simple: **the player decides which visual effects matter and where the available performance should be spent.** FS25 Enhanced does not force one definition of “better graphics”. Every system can be tuned individually, compared with Vanilla and returned to its original value.

FS25 Enhanced is a regular Lua/XML mod. It does not replace the renderer, inject binary code or add ray tracing.

---

## Deutsch

### Worum geht es bei FS25 Enhanced?

Der Landwirtschafts-Simulator 25 enthält deutlich mehr Grafikparameter, als das normale Einstellungsmenü zeigt. Einige Einstellungen sind gar nicht sichtbar, andere werden nur gemeinsam über eine Qualitätsstufe verändert.

FS25 Enhanced macht viele dieser erreichbaren Einstellungen in einem eigenen Live-Fenster zugänglich. Dadurch kannst du selbst entscheiden:

- welche Effekte du sehen möchtest,
- welche Bereiche für dich wichtiger sind,
- wo du mehr Bildqualität willst,
- und auf welche Effekte du zugunsten einer ruhigeren Leistung verzichten kannst.

Der Mod ist deshalb kein starres Grafik-Preset. Er ist ein **Werkzeug für persönliche Bildgestaltung und gezielte Leistungsverteilung**.

### Was lässt sich einstellen?

Je nach Karte, Spielversion und verfügbarer Engine-Funktion umfasst der Mod unter anderem:

- **Schatten:** Qualität, Auflösung, Filterung und verfügbare Schattenbudgets
- **Lichter und Lampen:** Reichweite, Streuung, Schatten und vorhandene Lichtprofile
- **Umgebung:** Sonne, Lichtstimmungen, atmosphärische Wirkung und God Rays
- **Sichtweite und LOD:** Detail- und Darstellungsdistanzen für verschiedene Bereiche
- **Bild und Tonwerte:** SSAO und erreichbare Parameter der filmischen Tonwertkurve
- **Materialien und Lack:** Reflexionswirkung auf dafür geeigneten Materialien
- **Wasser und Nässe:** vorhandene Nässe-, Reflexions-, Pfützen- und Wasserparameter
- **Vegetation:** erreichbare Shader- und Darstellungsparameter
- **Kamera und Spiegel:** verfügbare Sichtfeld-, Spiegel- und Lichtprofile

Nicht jede Funktion ist auf jeder Karte oder in jeder Situation verfügbar. Der Mod prüft deshalb die vorhandenen Schnittstellen und blendet nicht verfügbare Regler standardmäßig aus. Auf Wunsch können sie zusammen mit dem jeweiligen Grund angezeigt werden.

### Freiheit statt Zwang

Die Qualitätsstufen **Niedrig bis Ultra** sind ein schneller Ausgangspunkt. Sie verändern vor allem den grafischen Aufwand, ersetzen aber nicht die manuellen Regler. Lack, Nässe, Farbe, Sichtfeld und Lichtstimmungen bleiben bewusst separat einstellbar.

Du kannst also beispielsweise:

- bessere Schatten nutzen, aber andere Effekte reduzieren,
- mehr Sichtweite wählen, ohne automatisch jede Reflexion zu maximieren,
- Nässe und Lackwirkung anpassen, ohne die gesamte Grafikqualität zu verändern,
- oder nur einzelne Bereiche verbessern und den Rest auf Vanilla belassen.

Mit **MOD / VANILLA** kannst du die aktuelle Einstellung direkt mit dem unveränderten Spiel vergleichen. Änderungen werden beim Zurücksetzen oder Beenden des Mod-Zustands auf die erfassten Originalwerte zurückgeführt.

### Bedienung

- **F9** öffnet und schließt das Live-Fenster.
- Ziehe die Titelleiste, um das Fenster zu verschieben.
- Ziehe die rechte untere Ecke, um die Größe zu ändern.
- `[]` setzt das Fensterlayout zurück.
- **MOD / VANILLA** in der Kopfzeile oder **Alt+F9** schaltet den Direktvergleich um.
- **Tab zurück** setzt nur die aktuell geöffnete Kategorie zurück.
- Unter **Presets → Mod-Sprache** stehen Auto, Deutsch und Englisch zur Verfügung.

### Technische Grenzen

FS25 Enhanced erweitert die vorhandenen Möglichkeiten des Spiels, aber nicht die Render-Engine selbst:

- keine eigene Renderpipeline und kein Raytracing
- keine Binary-Hooks oder externen DLLs
- keine erfundenen Shader oder Effekte ohne vorhandenen Engine-/Asset-Pfad
- keine Garantie für mehr FPS oder identische Wirkung auf jeder Karte
- Upscaler, Anti-Aliasing sowie schwere Textur- und Shaderoptionen bleiben im Hauptmenü des Spiels

Entscheidend ist nicht, jeden Regler auf Maximum zu stellen. Das Ziel ist, die gewünschte Optik mit einer für das eigene System sinnvollen Belastung zu kombinieren.

### Download und Installation

1. Lade `FS25_Enhanced.zip` von der [aktuellen Release-Seite](https://github.com/CeberusOne/FS25_Enhanced/releases/latest) herunter.
2. Lege die ZIP-Datei unverändert in `Dokumente/My Games/FarmingSimulator2025/mods/`.
3. Aktiviere den Mod im Mod-Menü des Spiels.
4. Öffne das Live-Fenster im Spiel mit **F9**.

Bei der Fehlersuche findest du Einträge mit `[FS25_Enhanced]` in der `log.txt`.

### Dokumentation

- [Dokumentationsübersicht](docs/README.md)
- [Bedienung und Einstellungsprinzip](docs/USER_GUIDE.md)
- [Bekannte Grenzen](docs/KNOWN_LIMITATIONS.md)
- [Kompatibilität](docs/COMPATIBILITY.md)
- [Änderungsverlauf](docs/CHANGELOG.md)

---

## English

### What is FS25 Enhanced?

Farming Simulator 25 contains more graphics parameters than its standard settings menu exposes. Some options are hidden completely, while others are changed only as part of a combined quality preset.

FS25 Enhanced makes many of these reachable parameters available in one live panel. It gives the player direct control over which effects are visible, which areas receive more quality and which options can be reduced to preserve performance.

It is not a fixed “maximum graphics” preset. It is a **tool for personal visual tuning and deliberate performance allocation**.

### Main control areas

Depending on the map, game version and available engine functions, controls include:

- shadows, shadow filtering and available shadow budgets
- local lights, lamps, scattering and existing light profiles
- sun, lighting moods, atmosphere and light shafts
- view distance and LOD parameters
- SSAO and reachable filmic tone-mapping parameters
- compatible material, paint and reflection parameters
- existing wetness, puddle, water and reflection parameters
- reachable vegetation shader and display parameters
- available camera, field-of-view and mirror settings

Unavailable controls are hidden by default. They can be shown together with the reason why the current game, map or asset does not provide the required path.

### Player choice first

The **Low to Ultra** quality levels provide quick starting points, but manual controls remain independent. You can improve shadows while reducing another effect, increase view distance without maximizing every reflection, or keep most systems at Vanilla and change only the details that matter to you.

The **MOD / VANILLA** comparison switches between the current mod configuration and the captured original game values.

### Controls

- Press **F9** to open or close the movable live panel.
- Drag the title bar to move it and the lower-right corner to resize it.
- Use `[]` to reset the panel layout.
- Use the header button or **Alt+F9** for MOD / VANILLA comparison.
- **Reset tab** restores only the currently open category.

### Technical boundaries

FS25 Enhanced works with existing game and engine paths:

- no custom renderer or ray tracing
- no binary hooks or external DLL injection
- no invented shaders or unsupported effects
- no FPS guarantee and no promise of identical results on every map
- upscalers, anti-aliasing and heavy texture/shader options remain in the game menu

The goal is not to maximize every setting. The goal is to combine the desired visual result with a sensible workload for the player's own system.

### Download and installation

1. Download `FS25_Enhanced.zip` from the [latest release](https://github.com/CeberusOne/FS25_Enhanced/releases/latest).
2. Place the unchanged ZIP in `Documents/My Games/FarmingSimulator2025/mods/`.
3. Enable the mod in the game's mod selection.
4. Press **F9** in game.

### Documentation

- [Documentation index](docs/README.md)
- [Controls and tuning guide](docs/USER_GUIDE.md)
- [Known limitations](docs/KNOWN_LIMITATIONS.md)
- [Compatibility](docs/COMPATIBILITY.md)
- [Changelog](docs/CHANGELOG.md)

---

## License

All Rights Reserved — Copyright © 2026 CeberusOne. See [`LICENSE`](LICENSE).
