# FS25 Enhanced 0.5.2.0 – globale manuelle Einstellungen

Die Vorgabe vom 11.09.2026 ersetzt die räumliche und automatische Fassung 0.5.1.0. Diese Version verwendet wieder globale Engine-Einstellungen und erfasst geeignete geladene Objekte ohne Kamera-/Wirkungsradiusfilter.

## Bedienung

- **F9 oder Strg+E:** eigene native Enhanced-Seite im FS25-Spielmenü. Oben das Preset wählen, darunter nach Kategorien festlegen, welche Regler im Live-Menü erscheinen.
- **Strg+F9, Umschalt+F9 oder Strg+Umschalt+E:** Live-Menü. Das bisherige Fenster mit feinen Slidern bleibt erhalten. Werte können direkt eingegeben werden; Umschalt erlaubt die kleinste Schrittweite. Escape schließt.
- **Presets:** Performance, Balanced, Quality und Cinematic. Eine Auswahl wird ausdrücklich angewendet, auch nach einer Änderung am gleichen Preset. Cinematic läuft ohne Zeitbegrenzung. Eigene Einstellungen lassen sich als Profil speichern/laden.
- **Zurücksetzen:** Originalwerte wiederherstellen. Danach lässt sich sofort wieder ein Regler oder Preset wählen.
- **Statusanzeige:** ausschließlich FPS und Frametime; der Schalter befindet sich unter Performance.

Es gibt keine Einfach-/Experten-/Experimental-Bedienungsstufen, keinen Wirkungsradius und keine AUTO-/FIX-Reglersperren. Automatische Qualitätsanpassung, Kalibrierung, automatische Budgetverteilung, Ziel-FPS und zeitgesteuerte Cinematic-Umschaltung wurden aus der aktiven Bedienung und dem laufenden Steuerpfad entfernt. Alte gespeicherte Automatik- und Soft-Apply-Optionen werden deaktiviert. Die Auswahl eines gespeicherten Presetnamens beim Laden verändert noch keine Grafikwerte.

## Konkrete Wirkungs- und Stabilitätskorrekturen

- Globale Belichtung/Bildhelligkeit, Wetter- und Rendererregler werden nicht mehr vom früheren Radiusmodul blockiert. Bildhelligkeit verwendet GIANTS' SettingsModel; globale Optionen werden weiterhin mit nativen Argument- und Rückleseprüfungen angewendet.
- Materialien erfassen alle geladenen Fahrzeuge schrittweise statt nur acht im Kamerabereich. Gültige Fahrzeugshader mit Detail-Texturarrays werden nicht mehr aussortiert. Die Lackparameter werden mit dem echten GIANTS-`VehicleMaterial.applyToMaterial` und dem installierten `vehicleShader.xml` abgeglichen.
- Wetter-I3D-Erkennung verwendet die zugehörige Geometrie-ID. Partikel lesen zusätzliche vorhandene Originalwerte aus der Engine, sobald ein echtes System beobachtet wurde.
- Lichtänderungen benötigen ausdrücklich gesetzte Regler oder Presetziele. Der bloße Spielstart wendet keine Mod-Standardbudgets an. Alte Soft-Apply-Hooks schreiben keine verdeckten Priority-/Softness-Werte mehr.
- Presets ignorieren veraltete Sperren und verwenden denselben manuellen Schreibpfad wie Regler. Ein später bearbeiteter Regler wird nicht durch eine noch wartende Presetanwendung zurückgesetzt.
- Native Menüwechsel verwenden den GIANTS-Eingabe-/Cursorablauf. Der alte Dialog wird nicht mehr geladen; Übergänge zwischen Spielmenü und Live-Fenster wurden geprüft.
- **Regen-Multiplikator mindestens 0,01.** Slider, native Schreib- und Rücknahmepfade behalten den Schutz vor null. Natürliches trockenes Wetter des Spiels wird nicht erzwungen geändert.

## Was global bedeutet und welche Grenzen bleiben

Globale Engineparameter gelten für die gesamte Darstellung. Objektgebundene Licht-, Lack-, Partikel-, Vegetations- und Wasserparameter gelten für kompatible geladene Objekte ohne die zusätzliche Radiusmaske des Mods. Ein Lackparameter benötigt einen entsprechenden Fahrzeugshader; Regenparameter benötigen einen geladenen Niederschlagseffekt. Die Engine stellt nicht für jeden Effekt einen universellen globalen Setter bereit. Fehlende native APIs, passende Assets oder rücklesbare Ausgangswerte werden weiterhin als fehlende Voraussetzung gemeldet; ein erfolgreicher Engineaufruf wird nicht als visuell nachgewiesener Effekt ausgegeben.

Physische Sonnen-/Exposure-Änderungen, universelle zusätzliche Wasser-/Atmosphärenassets und sämtliche früheren PDF-Ideen sind damit nicht als vollständig umgesetzt behauptet. Maßgeblich für diese Änderung ist die gewünschte Vereinfachung auf manuelle Regler und Presets. Ein FPS-Gewinn wird nicht behauptet.

## Prüfung und Installation

Lua-Regressionen prüfen native Argumente/Rücklesewerte mit Engine-Ersatzfunktionen, echte GIANTS-Menümethoden, wiederholte native/Live-Menüwechsel, alte gespeicherte Optionen, isolierte Lichtänderungen, globale Presets, Regen-Nullschutz, fehlgeschlagene Rücknahmen und erneutes Anwenden. Hinzu kommen Syntax, Layout, XML, SDK-Profile und 27 Sprachdateien. Der gesonderte Testbericht enthält die konkreten Ergebnisse und ausdrücklich ersetzte alte Radius-/Automatiktests.

**Kein neuer visueller FS25-Spieltest durchgeführt.** Tatsächliche Bildwirkung, Laufzeitstabilität mit der konkreten Karte und Performance müssen in einer neuen Spielsitzung bestätigt werden. Das ist eine geprüfte Codeänderung, keine Behauptung, dass bereits jeder Regler im Spiel sichtbar getestet wurde.

Der installierte Ordner wird vor dem Ersetzen vollständig gesichert. Das ZIP enthält dieselben geprüften Dateien. FS25 zum Übernehmen neu starten. Danach eignen sich Bildhelligkeit, ein deutlich verändertes Preset, Fahrzeuglack bei passender Beleuchtung und Regenparameter während Regen für sichtbare Vergleiche. Der Menüstatus unterscheidet native Rücklesebestätigung, beobachteten Schreibaufruf und wartende Konfiguration.

## GIANTS-Grundlagen

- [Partikel-Lebensdauer und Geometrie-ID](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=18&function=402&version=engine)
- [GIANTS SimParticleSystem](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=62&class=583&version=script)
- [Fahrzeugmaterial-Vorlagen](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=91&class=895&version=engine)
- Installiertes SDK `scriptBinding.xml`, GIANTS-GUI-Skripte, `VehicleMaterial.lua`, `SettingsModel.lua`, originale Regen-I3D/XML und `vehicleShader.xml`; weitere Belege in `LIGHTING_MATERIAL_FIXES.md` und `ENVIRONMENT_RESEARCH.md`.
