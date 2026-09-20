# Änderungen

## 0.4.2.8 – 2026-09-20 – aktuellen lokalen Modstand übernommen

Fortsetzung der GitHub-Version 0.4.2.7. Übernommen wurde der installierte
Modstand aus dem FS25-Modordner. `VERSION` ist die einzige Versionsdatei im
Repository; modDesc.xml, Laufzeitversion und README verwenden ebenfalls 0.4.2.8.

Gegenüber 0.4.2.7:

- Neuaufbau: eine Qualitätsstufe Niedrig–Ultra nur für Aufwand (Sichtweite,
  Schatten, Lampen, SSAO, Reflexionen). Lack, Nässe, Farbe, Sichtfeld,
  Tonwertkurve und Stimmungen bleiben eigene Regler.
- Nur noch **F9** für das Live-Fenster. Shift+F9, Strg+F9 und Strg+E entfernt.
- Governor-, Expert- und Preset-Schicht entfernt (Performance/Balanced/Quality/
  Cinematic, Adaptive, Ziel-FPS, DRS, Shadow-Focus, Fast-Shadow-Update).
- Lack: Mikrostruktur, Frontalspiegelung, Frontalglanz, Grundglanz, Metallic-
  Anteil; eigene feinere Normalen (`textures/paintUni_n.png`, `paintMetallic_n.png`).
- Umgebung, Pflanzen, Wasser: Shader-Regler aus den GIANTS-XMLs (Feldfrucht-
  Biegung, SSAO in Pflanzen, Detail-Distanz, Wasser-Normalen/Tiefe/Wellen,
  Pfützen-Kräuselung, Kaustik).
- FOV in Grad (Fahrzeug 50–80°). God-Rays-Regler entfernt (keine sichtbare Wirkung).
- ZIP-Pfade mit Schrägstrich, damit GIANTS Lua lädt.

Die nachfolgenden 0.5.x/0.6.x-Einträge dokumentieren frühere lokale Arbeitsstände;
sie sind keine neueren Veröffentlichungen dieser GitHub-Versionsreihe.

## 0.6.0.9 – 2026-09-19 – Umgebung, Pflanzen, Wasser

Neue Shader-Regler aus den GIANTS-XMLs: Feldfrucht-Biegung, SSAO in Pflanzen, Detail-Distanz (3D-Pflanzen länger), Wasser-Normalen/Tiefe/Wellenmaßstab/Unterwasserfarbe, Pfützen-Kräuselung, Kaustik. Kein Bloom/Belichtung (kein Live-API). Terrain-Shader bleibt Engine-intern.

## 0.6.0.8 – 2026-09-19 – Frontalglanz + feine Normalen

Grobe Micro-Normalen ersetzt durch sehr schwache Karten (Detail-Normale wird addiert, starke Maps wirken wie abgelaugter Lack). Neuer Regler Frontalglanz (Klarlack-Glätte + smoothnessScale). Extra: Grundglanz, Metallic-Anteil. Mikrostruktur: Aus / Sehr fein / GIANTS kalibriert.

## 0.6.0.7 – 2026-09-19 – Echter Lack, kein Schleier

Klarlack geht nicht mehr auf 1,0 / SSR-Bias −1 (Folien-Look). Nur glänzender Uni- und Metallic-Lack; Plastik, Gummi, Glas, Matt, Rough und Pulverlack bleiben. Eigene feinere Normalen im Mod (`textures/paintUni_n.png`, `paintMetallic_n.png`).

## 0.6.0.6 – 2026-09-19 – Lack-Regler immer sichtbar

Lack-Mikrostruktur und Lackspiegelung bleiben in der Liste, auch während die Weltsuche läuft oder SSR aus ist. Flat/Default-Normalen ohne Custom-Map werden jetzt erkannt.

## 0.6.0.5 – 2026-09-19 – Frontal-Lackspiegelung

Lackspiegelung skaliert den Klarlack nicht mehr nur (0,1×3 bleibt 0,3 und unter der SSR-Schwelle 0,25). Werte über 1 füllen Klarlack und Glätte und setzen die SSR-Schwelle auf 0, damit Spiegelung auch von vorn bleibt, nicht nur im Streiflicht.

## 0.6.0.4 – 2026-09-19 – Lack-Mikrostruktur

Neuer Regler *Lack-Mikrostruktur*: ersetzt `flat_normal` auf Fahrzeuglack durch GIANTS-Karten `calibratedPaint_normal`, `calibratedPaintBumpy_normal` oder `metallicPaint_normal`. Kein eigener Shader, kein Tausch der Karosserie-Normalen.

## 0.6.0.3 – 2026-09-19 – F9, FOV, God Rays

- X öffnete das Fenster, weil Tastencode 120 (X) als F9 galt. Nur noch die echte F9-Taste.
- FOV wird in Grad bedient (Fahrzeug 50–80°). Vorher wurden Grad ins Bogenmaß-Feld geschrieben; 30 blieb hängen. Reset und nächster Start bekommen den Spielwert zurück.
- God-Rays-Regler entfernt (keine sichtbare Wirkung).

## 0.6.0.2 – 2026-09-19 – ZIP-Pfade für GIANTS

Windows hatte die ZIP mit Backslash-Pfaden geschrieben. Die Engine lädt nur `scripts/Core/...` mit Schrägstrich — deshalb kam kein Lua-Skript, F9 tat nichts.

## 0.6.0.1 – 2026-09-19 – F9 öffnet das Live-Fenster

Nur noch **F9** (öffnen und schließen). Shift+F9, Strg+F9 und Strg+E entfernt — die Extra-Kombinationen haben das einfache F9 in der Engine oft geschluckt. F9-Hook sitzt jetzt schon beim Mod-Laden, nicht erst nach Missionsstart. Zeichnen und Katalog sind gegen Lua-Fehler abgesichert.

## 0.6.0.0 – 2026-09-19 – Neuaufbau

Ein Bedienmodell, keine Governor-Schicht, keine Expert-Bools für APIs die Shapes oder Neustart brauchen.

- **Eine Qualitätsstufe** Niedrig–Ultra nur für Aufwand. Lack, Nässe, Farbe, Sichtfeld, Tonwertkurve und Stimmungen sind keine Mitglieder mehr.
- Alte Profile Performance/Balanced/Quality/Cinematic, Adaptive, Ziel-FPS, Expert-Soft-Apply, DRS, Shadow-Focus, Fast-Shadow-Update und persistHardware entfernt.
- Tote Dateien entfernt: Governor, Kalibrierung, Benchmark, Budget, VisibleScope, LodGovernor, ShadowManager, SettingsSchema, SettingsAPI, Partikel-Reste, Probe-Session, Diagnostics, capabilityProfiles.xml, presets.xml.
- Live-Fenster blendet nicht verfügbare Regler aus; Tab-Reset; **Hof bei Nacht** für lokale Lampen.
- Sonnenschattenkarte 1024/2048/4096 (8192 raus). Shadow-Merge nicht mehr angeboten.
- Höhennebel- und Atmosphären-Asymmetrie-Regler entfernt (kein belastbarer Live-Vertrag).
- VanillaGuard nimmt GameSettings (FOV/Spiegel/Lichtprofil) auch ohne Compare-Helfer vor dem Speichern zurück.
- VERSION, modDesc, Laufzeit und README stehen einheitlich auf 0.6.0.0.

Frühere 0.4.x/0.5.x-Einträge beschreiben den Stand vor diesem Neuaufbau.

## 0.4.2.7 – 2026-09-17 – aktuellen lokalen Modstand übernommen

Fortsetzung der GitHub-Version 0.4.2.6. Übernommen wurde der installierte
Modstand einschließlich der Änderungen vom 14. September, ohne funktionale
Änderungen bei dieser Übertragung. VERSION, FS25_Enhanced.VERSION,
modDesc.xml, Laufzeitversion und README verwenden einheitlich 0.4.2.7.

Die nachfolgenden 0.5.x-Einträge dokumentieren frühere lokale Arbeitsstände;
sie sind keine neueren Veröffentlichungen dieser GitHub-Versionsreihe.
Lokale Sicherungen, Python-Caches und Build-Artefakte gehören nicht zum Quellstand.

## 0.5.1.0 – lokaler Stand nach dem zweiten Spieltest (Log 14.09., 20:39–21:17), noch nicht veröffentlicht

Nur der installierte Mod-Ordner; das GitHub-Repo bleibt auf 0.5.0.0, bis der
Stand im Spiel bestätigt ist.

- **Bäume wurden nie erreicht.** Karten-Bäume sind `MESH_SPLIT_SHAPE`-Knoten, und
  die Engine meldet diese Klasse getrennt von `SHAPE` (TreePlantManager prüft
  beide). Die Weltsuche nahm nur `SHAPE`, darum standen im Log 11 „Baum“-
  Materialien (Setzlinge/Deko) und die Kronenregler blieben ohne Wirkung. Jetzt
  werden beide Klassen erfasst; das Log zeigt `splitShapes=<n>`.
- **Sichtbare Vegetationsregler** mit ab Werk hinterlegten Parametern, alle
  im Reiter *Vegetation*: Bäume: Windstärke (`windSnowLeafScale.x`, auch
  Billboards), Farbvariation (`seasonalTintIntensity`, Kronen/Billboards/
  Hintergrundbäume, alle drei Jahreszeiten in einem Schreibvorgang), Gegenlicht-
  Grundwert (`backfaceDiffuseScale.y`); Feldfrucht/Gras: Windstärke (`windScale`).
  Kronenverdeckung, Gegenlicht, Bodenschattierung und Lichtdurchlass ziehen aus
  *Umgebung* nach *Vegetation* um; ihre Tooltips sagen jetzt ehrlich, wann der
  Effekt sichtbar ist (SSAO-Exponent nur in beschatteten Kronen, Gegenlicht nur
  mit Sonne hinter dem Baum, Lichtdurchlass nur gegen tiefe Sonne, Feldregler nur
  bis ~80 m – dahinter zeichnet das Spiel die Distanztextur).
- **Tiefe der Umgebung:** Gebäude: Moos und Schmutz (`buildingShader
  dirtMossMix`), Felsen: Moos/Schmutz (`placeableShader mossLevel`) – Verwitterung
  als Regler, relativ zum Hersteller-Wert.
- **Sonnenschatten: Kartengröße** (Umgebung): `setLightShadowMap` auf der
  Missionssonne mit `getLightCastingShadowMap`-Rücklesen, 1024/2048/4096/8192 px.
  Der Datensatz merkt sich die rohe Spielgröße, „Aus“ gibt sie exakt zurück.
  Nicht Teil der Qualitätsstufen (8192 kostet viel Grafikspeicher).
- **God Rays richtig behandelt.** Der bisherige Ein/Aus-Schalter setzte
  `setLightUseLightScattering` auf der Sonne – dieselbe Streuung beleuchtet den
  Himmel, „aus“ machte ihn schwarz. Der Regler ist jetzt ein **Faktor 0,1–4 auf
  die spieleigene Streuintensität** (`setLightScatteringIntensity`), wird bei jeder
  Änderung durch das Spiel neu bezogen (Tageszeit/Wetter bleiben dynamisch), nie
  abgeschaltet und nie unter 0,1 geschrieben. Der doppelte Absolutregler
  „Streuintensität“ entfällt; die Lichtstimmungen nutzen den Faktor.
- **Kein Fahrzeug mehr nötig.** Die zusätzliche Pflanzeninteraktion nahm nur
  aktive Biegeflächen des gesteuerten Fahrzeugs (Status „Benötigt ein aktives
  Fahrzeug“). Jetzt: zu Fuß die 1-m-Fläche der Spielerfigur
  (`HumanGraphicsComponent.foliageBendingNode`), im Fahrzeug Fahrzeug samt
  Anbaugeräten, Stufe 2 zusätzlich aktive Helfer nahe der Kamera; Wechsel werden
  alle 500 ms erkannt. Alle anderen Regler brauchten auch vorher kein Fahrzeug –
  Lampenregler melden „keine lokalen Lichter“, wenn im Umkreis kein Licht
  registriert ist.
- **Log-Flut behoben:** 1424 × „Unknown entity id 49367 … getMaterialCustomShaderFilename“
  mit Stacktrace. `getMaterial` liefert dort eine Material-ID, die kein Entity
  mehr ist; die Suche prüft jetzt `entityExists` und merkt sich jedes einmal
  eingeordnete Material (`badMaterials=<n>` im Log), statt es bei jedem
  15-s-Durchlauf erneut zu befragen.
- **API-Inventar** (`[ApiInventory]` im Log, einmal je Mission, nur Namen, kein
  Aufruf): alle Engine-/Spielfunktionen mit Belichtungs-/Bloom-/Tonwert-/
  Farbkorrektur-/Nebel-/Atmosphären-Schlüsselwörtern, die Felder und Methoden des
  Lighting-Objekts der Mission sowie der Befund der abgesicherten Regler (Nebel,
  Atmosphären-Asymmetrie). Das ist die Grundlage, um Belichtung/Bloom/
  Farbkorrektur aus `environment.xml` als echte Regler anzubieten, ohne Namen zu
  raten. Konsole: `fs25eApiInventory`.
- **Atmosphäre: Bündelung des Sonnenhofs** (`getAtmosphereCornettShrankAsymmetryFactor`,
  Getter in `sdk/scriptBindingChanges.txt`; Setter wird zur Laufzeit geprüft wie
  bei den Nebelreglern) – erscheint nur, wenn der Spielstand ihn hat.
- Fehlender Eingabetext `input_FS25E_TOGGLE_COMPARE` ergänzt.
- Neuer Offline-Test `tools/smokeFoliageLight.lua` (Pflanzeninteraktion zu Fuß/
  im Fahrzeug/Helfer, God-Ray-Faktor mit Neubezug, Untergrenze und Rückgabe);
  `tools/smokeWetSurfaces.lua` deckt Split-Shapes, veraltete Material-IDs,
  Mehrkomponenten-Schreibvorgänge und die neuen Regler ab.

Offen bis zum nächsten Log: ob die Feldfrucht-Blockmaterialien (486 Stück im
Log, aus `foliage/*/*.i3d`) vom Foliage-Renderer live gelesen werden – der
Windregler ist der eindeutige Test (0 = Felder stehen still). Bleibt das ohne
Wirkung, hält die Engine eigene Kopien und die Feldregler werden als nicht
erreichbar gekennzeichnet.

## 0.5.0.0 – 2026-09-14 – GitHub-Release (Nachfolger von 0.4.2.6)

Erste veröffentlichte Fassung der neuen Generation. Alles darunter unter
„Entwicklungsstand 0.5.x/0.6.x“ sind interne Zwischenstände, die zusammen in
dieser Version enthalten sind. Download: `FS25_Enhanced.zip` von der Releases-Seite.

Gegenüber 0.4.2.6:

- **Ein Fenster statt drei Oberflächen.** Die Seite im Spielmenü und der
  F9-Dialog sind weg; **F9** öffnet das verschieb- und skalierbare Live-Fenster
  mit 14 Kategorien und 131 Reglern. Mod-Sprache umschaltbar (Auto/Deutsch/Englisch).
- **Strikt vom Spielmenü entkoppelt** (VanillaGuard): Die Grafikseite des Spiels
  und seine Speichervorgänge sehen nie Mod-Werte; **Alt+F9** vergleicht MOD/VANILLA.
- **Qualitätsstufe Niedrig–Ultra** für alle Effekte; Ultra setzt jeden Regler auf
  Maximum, unabhängig von der Stufe im Spielmenü (auch Schatten und echte Lampen).
- **Globale Engine-Regler** aus GIANTS' eigenem SettingsModel (SSAO, Wolkenschatten,
  Shadowmap-Filter, Tessellierung, Reifenspuren …), filmische **Tonwertkurve**,
  **Spotschatten-Atlas**, Sichtfeld, Spiegelanzahl, Lichtprofil.
- **Umgebung:** Sonnenstärke/-wärme/-tönung, Streuung mit Untergrenze, **God Rays**,
  Lichtstimmungen, Baumkronen-Verdeckung und -Gegenlicht, Lichtdurchlass von
  Feldfrucht und Vegetation, Kontrast/Helligkeit bemalter Flächen.
- **Wasser / nasse Umgebung:** Bodennässe mit Abtrockenzeit, Nassspiegelung auf
  Gebäuden und Straßen, Pfützen, Wasser-Reflexionsrauheit, Schaum.
- **Lackspiegelung:** ein Regler, relativ zur ab Werk hinterlegten Lackierung;
  Glas, blanker Gummi, Holz, Stoff und Rückstrahler werden nie angefasst,
  lackierter Gummi/Kunststoff automatisch erkannt.
- **Lampen:** Streuung schaltet wirklich ein; Schatten-/IES-/Streubudgets.
- **Behoben:** Per-Frame-Schreibsturm beim Ziehen, fehlende Schriftzeichen
  (U+2212/U+25CF), Log-Flut der Lichtsuche, doppelte Hooks, Materialdatensätze
  gingen bei Washable-Materialinstanzen verloren, verschluckte Rückgabewerte in
  den Diagnose-Wrappern, Ruckeln beim Anwenden (Warteschlange statt 1500 Slots
  pro Frame).
- **Entfernt:** Upscaler/AA/VRS/DRS/Textur- und Shaderqualität (bleiben im
  Hauptmenü), Partikelmodul, Weltverbindung der Materialien, RGB-Kanäle der Sonne.

Nachtrag nach dem ersten Spieltest der 0.5.0.0 (Log 14.09., 19:48–20:30):

- Weltmaterialien (Nässe, Baumkronen, Feldfrucht, bemalte Flächen) werden jetzt
  **pro geteiltem Material** erfasst und mit `shared=true` geschrieben statt pro
  Knoten/Slot mit Materialklon. Vorher lief die Suche bei 6000 Datensätzen voll
  (ein Wald = tausende Slots) und später gefundene Gebäude/Straßen/Pfützen kamen
  nie an; zusätzlich entstanden tausende Materialinstanzen.
- Bodennässe: Der Lua-Hook auf `setWetness` hat im Spiel nie gefeuert (Status
  „nur beobachtet“), das Wetter schreibt also nativ. Der Abgleich läuft jetzt auch
  im Draw-Pass, und das Log meldet `wetnessSticks=<hält>/<gesamt>`, ob der Wert
  bis zum Rendern stehen bleibt.
- Die LiveApply-Zeilen enthalten jetzt die Materialzahlen je Shaderklasse und
  die Nässe-Diagnose.

Prüfung: 60 Lua-Dateien, Konfig- und Sprachvalidatoren, fünf Offline-Tests
(`tools/smoke*.lua`) inklusive vollständigem Lade- und Missionslauf. Kein
In-Game-Test durch den Autor dieser Fassung; siehe docs/KNOWN_LIMITATIONS.md.

## Entwicklungsstand 0.6.1.0 – Gesamtprüfung

Neuer Integrationslauf `tools/smokeBootstrap.lua`: lädt alle 46 Quelldateien in
modDesc-Reihenfolge gegen die Engine-Nachbildung, feuert die Missions-Hooks wie
das Spiel, lässt 30 Frames laufen, zeichnet alle 14 Kategorien des Live-Fensters,
verschiebt/skaliert es, prüft Esc/F9, Ultra/Aus, MOD/VANILLA, VanillaGuard,
Sprachumschaltung und den Missionsabbau. Die Engine-Nachbildung liest jetzt echte
XML-Dateien (Presets, Sprachen, Capabilities) statt nur Capability-Knoten.

Dabei gefunden und behoben:

- `Diagnostics` umwickelte `CapabilityApplier.restoreAll` und
  `RestoreManager.restoreAll`, verschluckte aber deren Rückgabewerte. Folge: der
  MOD/VANILLA-Schalter meldete immer „Rücknahme fehlgeschlagen“, obwohl alles
  zurückgesetzt war; dieselbe Rückgabe steuert auch VanillaGuard und Reset-Pfade.
- `MaterialManager.refresh` lief aus jeder gezeichneten Materialzeile in jedem Frame
  über alle ~1500 Slots (`getMaterial` pro Slot). Die Durchsicht ist jetzt auf
  einmal pro Sekunde begrenzt; das Erkennen neuer Fahrzeuge bleibt.

Zusätzlich geprüft: keine unbekannten Globals in 46 Skripten (luac-Bytecode gegen
Spielquelltext und Binding), alle in Skripten benutzten Sprachschlüssel vorhanden,
32 XML-Dateien wohlgeformt, keine fehlenden Glyphen für EN/DE, keine Verweise auf
entfernte Module. Vier Dateien unter `scripts/Core` (BenchmarkManager,
BudgetAllocator, CalibrationManager, VisibleScope) stehen seit früheren
Versionen nicht in modDesc.xml und werden nie geladen; jeder Verweis darauf ist
abgesichert.

## Entwicklungsstand 0.6.0.0 – Licht und Tiefe in der Umgebung

Sieben neue Regler unter Umgebung, jeder ein belegter Parameter aus
`data/shaders/*.xml`, skaliert oder gesetzt, zurückgelesen und rücknehmbar:

| Regler | Shader | Parameter |
| --- | --- | --- |
| Baumkronen: Umgebungsverdeckung | treeBranchShader | `aoIntensity` (1,0) |
| Baumkronen: Gegenlicht | treeBranchShader | `backfaceDiffuseScale.x` (0,35) |
| Feldfrucht: Umgebungsverdeckung | fruitGrowthFoliageShader | `aoIntensity.x` (2,0) |
| Feldfrucht: Lichtdurchlass | fruitGrowthFoliageShader | `translucencyAmount` (0) |
| Vegetation: Lichtdurchlass | translucencyShader | `translucencyAmount` (0,35) |
| Bemalte Flächen: Kontrast | vertexPaintShader | `contrastLuminiosity.x` (1,0) |
| Bemalte Flächen: Helligkeit | vertexPaintShader | `contrastLuminiosity.y` (0) |

Die Weltsuche des Nass-Moduls liefert die Datensätze; ein Regler wirkt nur auf
die Shaderklassen, für die er definiert ist (Baum-AO trifft keine Feldfrucht).
Komponentenweises Schreiben: nur die adressierte Vektorkomponente wird gesetzt,
die übrigen bleiben – so wie Washable eine einzelne Nässekomponente schreibt.
`vertexPaintShader` (Straßen, Höfe) nimmt jetzt auch an Nassspiegelung und
Nassstärke teil.

## Entwicklungsstand 0.5.9.0 – strikte Entkopplung vom Spielmenü

Die Engine hat nur einen Zustand; deshalb zeigte die Grafikseite des Spiels
bisher die Mod-Werte und speicherte sie beim Schließen in game.xml/gameSettings.xml.

Neu `scripts/Core/VanillaGuard.lua`: umschließt `SettingsModel:refresh`,
`refreshChangedValue`, `applyChanges`, `applyCustomSettings`, `reset`,
`saveHardwareScalability()`, `GameSettings:save` und `saveToXMLFile`. Vor jedem
dieser Momente werden alle Mod-Werte zurückgenommen (derselbe Pfad wie der
MOD/VANILLA-Schalter), danach wieder angewendet. Die Spielseite sieht, bearbeitet
und speichert nur noch die eigenen Werte des Spielers; Änderungen dort werden
automatisch die neue Basis, auf die der Mod zurücksetzt.

Das Live-Fenster bleibt davon unabhängig: jeder Regler läuft direkt über die
Engine-Setter bzw. `g_gameSettings` zur Laufzeit, und die Qualitätsstufe Ultra
setzt alles auf Maximum – auch Schatten und echte Lichter, wenn das Spielmenü
auf Niedrig steht (das Lichtprofil wird über den Regler „Fahrzeuglicht-Profil“
bzw. Ultra angehoben).

Der MOD/VANILLA-Vergleich stellt jetzt zusätzlich jeden erfassten Regler über
seinen eigenen Pfad zurück, unabhängig von der Modulliste.

Objekt-Sichtweite: Presets Quality/Cinematic und die Stufen Hoch/Sehr hoch starten
mit 1,05 statt 1,25/1,5.

Werkzeug: `tools/smokeVanillaGuard.lua`.

## Entwicklungsstand 0.5.8.0 – Qualitätsstufen, Sprachschalter, nur noch das Live-Fenster

Neu:

- **Qualitätsstufe (alle Effekte)** unter Presets: Niedrig / Mittel / Hoch / Sehr hoch /
  Ultra setzt 39 Qualitätsregler auf einmal (Sichtweiten, Schatten, Lampen, SSAO,
  Reflexionen, nasse Welt, Regen). Ultra = jeder Regler auf seinem Maximum. Farbe,
  Sichtfeld, Tonwertkurve und Stimmungen bleiben unberührt; Aus gibt alles zurück.
- **Mod-Sprache** unter Presets: Auto (Spielsprache) / Deutsch / Englisch, wirkt
  sofort auf jeden Text im Fenster und HUD.
- **Sonnen-Lichtstrahlen (God Rays)**: Schalter für die volumetrische Streuung des
  Sonnenlichts (`setLightUseLightScattering` auf dem Sonnenknoten). Die
  Streuintensität behält ihre Untergrenze 0,1.
- **Nebel: Bodendichte / Maximalhöhe** (Atmosphäre): Getter stehen in
  `sdk/scriptBindingChanges.txt`; die Setter werden zur Laufzeit geprüft und nur
  angeboten, wenn der Spielstand sie hat. `fs25eApiDump Fog` zeigt, was existiert.
- **Pfützen** (Wasser): skaliert die Deckkraft der Pfützen-Decals der Karte
  (`puddleShader.waterOpacity`); sie folgen der Bodennässe.
- Konsole `fs25eApiDump <Muster>` listet die globalen Engine-Funktionen des
  laufenden Spiels.

Geändert:

- Die Seite im Spielmenü und der F9-Dialog sind entfernt. **F9** öffnet jetzt das
  Live-Fenster (Shift+F9 weiterhin). Vier UI-Dateien und der GUI-Ordner sind weg.
- Lampenstreuung: Ein Intensitätswunsch schaltet die Streuung der betroffenen
  Lampen ein und behandelt eine ab Werk mit 0 gesetzte Intensität als 1 – vorher
  blieb 0×Multiplikator immer 0, deshalb war nichts zu sehen.
- Partikelmodul und Kategorie entfernt.
- „Materialien mit Welt verbinden“ samt Szenengraph-Scan entfernt (Leistung,
  Fehler). Fahrzeuglack bleibt; Weltflächen laufen über die Wasser-Kategorie.

Werkzeuge: `tools/smokeControls.lua` prüft jetzt auch Ultra/Aus der Qualitätsstufe.

## Entwicklungsstand 0.5.7.0 – nasse Umgebung, MOD/VANILLA-Schalter, ruckelfreies Anwenden

Neu:

- **Wasser** (Kategorie neu belegt): Bodennässe (Multiplikator auf die Wetter-Nässe
  der Engine, `setWetness`/`getWetness`), Abtrockenzeit (hält Straßen und Höfe nach dem
  Regen länger feucht), Nassspiegelung und Nassstärke auf Gebäuden/Straßen
  (`placeableShader.wetShininess`, `wetnessScale`, `buildingShader.wetnessScale`),
  Wasser-Reflexionsrauheit (`oceanShader.ssrRoughness`). Nur Boden, Gebäude, Straßen,
  Wasser und (über den Lackpfad) Fahrzeuge; Vegetation und Bäume haben keinen
  Nässekontrakt und bleiben unberührt. Die sieben nie verfügbaren Pfützen-Platzhalter
  sind entfernt.
- **MOD / VANILLA** (Alt+F9, Kopfzeile des Live-Fensters, Aktion unter Presets):
  stellt alle gehaltenen Werte zurück und wendet sie beim zweiten Druck wieder an.
- **Lichtstimmung** (Umgebung): fünf abgestimmte Kombinationen aus Sonnenstärke,
  Farbtemperatur, Tönung und Streuung, jederzeit einzeln nachjustierbar.

Geändert:

- Upscaler (DLSS/FSR/XeSS/VALAR), MSAA, Post-Process-AA, Variable Rate Shading,
  DRS, Texturauflösung, Shader-Qualität und Texturfilterung sind aus dem Mod
  entfernt – sie lösen Ressourcen-Neuladen aus und gehören ins Hauptmenü.
- Sonnenlicht: nur noch Stärke, Wärme und Tönung. Die Rot/Grün/Blau-Kanäle sind weg.
  Sonnenstreuung hat eine Untergrenze von 0,1 und keinen Aus-Schalter mehr, weil
  beides den Himmel komplett verschwinden ließ. Die doppelten Sonnenregler unter
  „Lichter & Lampen“ sind entfernt.

Behoben:

- **Ruckeln beim Anwenden**: Materialschreibvorgänge laufen jetzt über eine Warteschlange
  (48 sofort, danach 96 pro Frame) statt ~1500 Slots in einem Frame. Die Nässe-Nachführung
  lief jede Sekunde über alle Materialien und läuft jetzt alle zwei Sekunden über die
  Warteschlange; die Fahrzeug-Neusuche alle 2 s ist auf 10 s gestreckt.
- Materialdatensätze gingen verloren, sobald Washable/Wearable mit `shared=false`
  eine neue Materialinstanz erzeugte; die Originalwerte wurden dann von bereits
  geänderten Werten überschrieben. Datensätze hängen jetzt am Slot, nicht an der Material-ID.
- Trennzeichen in der Fenster-Hilfezeile enthielt Steuerzeichen (Logwarnung
  „Character '1' not found“).

Werkzeuge: `tools/engineStub.lua` (gemeinsame Engine-Nachbildung), `tools/smokeWetSurfaces.lua`,
`tools/exportCatalog.lua` (erzeugt `docs/CONTROL_CATALOG.json` aus den echten Reglerdefinitionen).

## Entwicklungsstand 0.5.6.0 – Engine-Grafikeinstellungen, Tonwertkurve und Lackspiegelung

31 zusätzliche Regler, alle aus dem installierten Spiel belegt (SettingsModel.lua,
scriptBindingChanges.txt, vehicleShader.xml, materialTemplates.xml):

- **Bild & Tonwerte** (neue Kategorie): SSAO, Texturauflösung, Shader-Qualität,
  Texturfilterung und die fünf Parameter der filmischen Tonwertkurve.
- **Leistung**: MSAA, Post-Process-Kantenglättung, DLSS, FSR 1, FSR 3, XeSS,
  VALAR und Variable Rate Shading. Konkurrierende Verfahren schalten sich
  gegenseitig ab, wie in der Spiel-Grafikseite.
- **Schatten**: Wolkenschatten, Shadowmap-Filter und fünf Spotschatten-Regler
  aus dem FS25-1.0-Script-Binding.
- **Sichtweite/LOD**: Volumen-Tessellierung und Reifenspur-Länge.
- **Kamera & Spiegel** (neue Kategorie): Sichtfeld für Fahrzeug, Ego- und
  Verfolgerkamera, Spiegelanzahl; dazu das Fahrzeuglicht-Profil.
- **Lackspiegelung**: ein Regler für Klarlack, Klarlack-Glätte und den
  SSR-Rauheits-Bias, relativ zur ab Werk hinterlegten Lackierung. Der Schleier
  auf Standardlack entstand daraus, dass dessen Klarlackstärke (0,1) unter der
  SSR-Klarlackschwelle (0,25) liegt und deshalb die absichtlich unschärfer
  eingestellte Grundschicht gespiegelt wurde.

Materialerkennung erweitert: eine vorhandene Klarlackschicht gilt jetzt selbst
als Nachweis, wodurch lackierter Gummi oder Kunststoff automatisch erfasst wird.
Blanker Gummi, Glas, Holz, Stoff und Rückstrahler bleiben ausgeschlossen; die
Porositätsgrenze liegt bei 0,25 statt bei 0, damit Pulverlack (0,1) erfasst wird.

Live-Fenster: an der Titelleiste verschiebbar, an der rechten unteren Ecke
skalierbar, `[]` setzt das Layout zurück. Position und Größe werden in
modSettings gespeichert, die Zeilenzahl pro Seite folgt der Fensterhöhe.

Behoben:

- Ein gehaltener Schieberegler schrieb den Engine-Wert in jedem Frame neu und
  erzeugte pro Sekunde rund 35 Logzeilen. Unveränderte Werte werden jetzt
  übersprungen, APPLIED wird nur beim Statuswechsel protokolliert.
- `defaultFont.font` enthält kein U+2212 (Minuszeichen) und kein U+25CF. Beide
  wurden in allen 27 Sprachdateien durch Zeichen aus der Schrift ersetzt; die
  Logwarnung „Character '8722' not found in texture font“ entfällt.
- Lichtsuche und die beiden Probe-Spezialisierungen protokollierten jedes
  Objekt auf Info-Ebene (mehrere tausend Zeilen pro Kartenladung) – jetzt
  Debug-Ebene.
- Sonnenfarbe und Umgebungsregler registrierten zwei getrennte Hooks auf
  `Lighting:update`; beide teilen sich jetzt einen. `HookManager.register`
  nimmt ein Token entgegen und verhindert damit doppelte Wrapper nach einem
  Kartenwechsel.
- `FS25_Enhanced.VERSION` stand noch auf 0.4.2.8.
- Neue Capabilities sind zusätzlich in Lua hinterlegt, damit die Regler auch
  ohne lesbare `capabilityProfiles.xml` funktionieren.

Neu: `tools/smokeControls.lua` und `tools/smokeMaterials.lua` prüfen offline
alle 48 globalen Regler sowie Materialeinstufung und Lackkette. Details:
docs/ENGINE_SETTINGS.md.

## Entwicklungsstand 0.5.5.0 – gezielte Laufzeitdiagnose

Manuelle Snapshots und zeitlich begrenzte Änderungsaufzeichnung für Grafik-/Wetterdaten, ohne Grafikänderungen durch die Diagnose. Details: RELEASE_0.5.5.0.md.

## Entwicklungsstand 0.5.4.0 – Umgebung und Lackschutz

Separate Umgebungsregler; bisherige Lichtkategorie in Lichter & Lampen umbenannt. Lackglanz schützt Glas/Gummi/unerkanntes Material; veränderliche Szenenbaum-Indizes und Wetter-XML-Cleanup korrigiert. Details: RELEASE_0.5.4.0.md.

## Entwicklungsstand 0.5.3.0 – Licht, Materialerkennung und Wetter

Stärkere Lampen und native Sonnenlichtregler; Grundglätte bis10; Materialtausch und spätes Laden erkannt; optionaler Weltverbinder; GIANTS-Wetter-Ladeumgebung erfasst. Details: RELEASE_0.5.3.0.md.

## Entwicklungsstand 0.5.2.0 – globale manuelle Bedienung

Automatik und Wirkungsradius entfernt; eine native Einstellungsseite plus Live-Menü ohne Bedienungsstufen. Verdeckte Start-Schreibpfade deaktiviert, explizite Presets nach Änderungen erneut wirksam. Materialerkennung, Wetter-Geometrie-IDs und Cursorübergänge korrigiert. Regenminimum0,01 erhalten. Details: RELEASE_0.5.2.0.md.


## Entwicklungsstand 0.5.1.0 – 2026-09-11

Native Vollflächen-Seite mit gespeicherter Auswahl der Live-Regler; Cursor-Lebenszyklus korrigiert. Einstellbarer Kamera-/Sichtfeldradius 5–300m für lokale Licht-, Material-, Partikel- und Vegetationsänderungen mit Rücknahme. Globale nicht maskierbare Effekte unter dieser Vorgabe gesperrt; LOD/Sichtweiten ausgenommen. Regen-Multiplikator gegen null geschützt. Wirkungslose Kamera-/Material-/Lichtpfade korrigiert. Details und technische Grenzen: RELEASE_0.5.1.0.md.

## Entwicklungsstand 0.5.0.1 – 2026-09-11 – Menü- und Log-Hotfix

Spielmenüregistrierung, F9-Layout, Live-Textzustände, LIGHT_SOURCE-Klassengrenzen und Sandbox-Dateizugriffe korrigiert. Einzelheiten und neue Regressionen: HOTFIX_0.5.0.1.md. Realer Spieltest steht aus.

## Entwicklungsstand 0.5.0.0 – 2026-09-11 – Entwicklungsstand

- Live-Menü neu: FS25-Farbwelt, zwölf Kategorien, echte Schieberegler, Zahleneingabe, 0,001-Feinschritte, Maus/Keyboard/Controller, feldweise Reset und Auto-Locks.
- Wiederholtes Öffnen/Schließen, veralteter currentDialogName, Cursor-Rückgabe, GUI-Wiederverwendung und Konsolen-Schließpfad repariert. Zusätzlicher Einstieg im nativen Spielmenü.
- Typisierte globale und lokale Engineadapter mit geprüften Signaturen, Support-Enums, Originalwerten, Readback und Rücknahme. Ungültige boolesche Asset-Aufrufe entfernt.
- Lokale Schatten/Lichter/IES/Streuung, echte Presetdifferenzen, drei Automatikintervalle, Kostenkalibrierung, Benchmarkaufnahme, Telemetrie und Kompatibilitätsprüfung integriert.
- Wetter-/Partikel-/Material-/Vegetationsadapter als geschützte Experimente; klare Assetgründe statt wirkungsloser Scheinregler. Wasserstatus siehe FEATURE_MATRIX.
- Eigene Live-Profile, Original/Enhanced-Vergleich und 60-Sekunden-Cinematic mit Zustandssicherung. 27 Sprachdateien, Formatvalidator, Configprüfung und reproduzierbarer ZIP-Build.
- Syntax-/Mockregressionen dokumentiert. Keine vorgetäuschte Ingame-/Visual-/Performance-Freigabe.

## Entwicklungsstand 0.4.2.8

Reparatur von Start, Konsolenregistrierung, GUI-Profilen und ersten nativen Live-Einstellungen auf Basis des vorhandenen Modordners.
