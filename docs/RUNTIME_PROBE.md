# Begrenzte Laufzeitdiagnose

`FS25E_RuntimeProbe` erzeugt auf ausdrücklichen Aufruf einen lesenden Snapshot der aktuellen GIANTS-Laufzeit. Das Modul startet keine Aufzeichnung, installiert keine Hooks und verändert keine Grafikwerte. UI-, Konsolen- und zeitlich begrenzte Vergleichsaufzeichnungen werden außerhalb dieses Moduls angebunden.

## Schnittstelle

```lua
local flatMap, summary = FS25E_RuntimeProbe.collect("environment")
local sameMap, sameSummary = FS25E_RuntimeProbe.takeSnapshot("lighting")
local emittedSummary = FS25E_RuntimeProbe.emitSnapshot("all")
```

Kategorien: `all`, `environment`, `lighting`, `weather`, `materials`, `render`. Ohne Argument wird `all` verwendet. Eine ungültige Kategorie liefert `nil, {ok=false, error="invalid-category"}`.

`collect` liefert eine flache Tabelle mit ausschließlich String-Schlüsseln und String-Werten. Beispiele:

```text
native.sun.getLightColor.1 = number:2
native.materialSample.1.paintEligible = boolean:true
controls.sunIntensity.error = string:FS25E_status_missingApi
api.giants.getExposure = function:present/unverified/not-called
api.giants.setLightScatteringColor = function:documented-setter/presence-only
```

Zeit, laufende Nummer und weitere Metadaten stehen ausschließlich in der zweiten Rückgabe. Die Wertekarte enthält keine ständig wechselnden Zeit-/Sequenzfelder und kann direkt für begrenzte Vorher-/Nachher-Vergleiche verwendet werden.

`summary` enthält `ok`, `category`, `schema`, `sequence`, `version`, `gameTime`, `nativeEnvironment`, `entries`, `bytes`, `truncated`, `errors`; bei einem Ausgabeproblem außerdem `error`. `takeSnapshot` ist ein Alias von `collect`.

`emitSnapshot` schreibt ausschließlich mit `Logging.info("%s", line)`. Die Ausgabe wird durch `FS25E_PROBE BEGIN` und `FS25E_PROBE END` eingerahmt. Der Beginn nennt Schema, Modversion, Sequenz, Spielzeit, Kategorie und Herkunft der untersuchten Lua-Umgebung. Das Ende enthält Eintrags-/Byteanzahl, Abschneidung und Fehleranzahl. Fehlt `Logging.info`, wird `ok=false, error="logging-unavailable"` zurückgegeben; Ausgabefehler werden als `logging-failed` gemeldet.

## Erfasste Belege

- Ausschließlich fest erlaubte, dokumentierte Getter: aktueller Regenmengenmultiplikator, Nässe und vier Grafikqualitäten; an einem validierten Sonnen-LIGHT_SOURCE außerdem RGB, Streuung und ausgewählte Schatteneigenschaften. Fehlende APIs werden als fehlend gemeldet. Kein unbekannter Getter wird zur Entdeckung von Argumenten aufgerufen.
- Vorhandene eigene Providerdiagnosen und explizite Anforderungen. Der große Materialdiagnose-Scan wird durch konstante Tabellenanzahlen und eine begrenzte letzte Diagnose ersetzt.
- Bis zu 16 bereits berührte Regler mit gecachten Status-, Fehler-, Anforderungs- und Istwerten. Hierzu werden ausschließlich die eigenen `VisualControls.getControls/getState` verwendet; keine `read/available`-Callbacks der einzelnen Regler werden ausgeführt.
- Höchstens drei bereits entdeckte Material-Shapes. Nach SHAPE-, Existenz- und Materialslot-Prüfung werden nur bekannte vorhandene Shaderparameter gelesen. Dazu kommen `paintEligible` und bekannte Materialklassifikationen. Keine Fahrzeugsuche und kein globaler Scenegraph-Scan.
- Tatsächliche Tabellenfelder von `environment.lighting`, `environment.weather`, der flachen Umgebung sowie ausgewählten Grafik-Enums. Methodennamen aus `__index`-Tabellen werden mit erfasst. `__index`-Funktionen und sonstige Metamethoden werden nicht aufgerufen.
- Gefilterte API-Namensinventur in der tatsächlichen GIANTS-Lua-Umgebung sowie bei Bedarf der Mod-Umgebung. Noch nicht dokumentierte Exposure-/Bloom-/Tone-/ColorGrading-/Fog-/Ambient-/PostFX-Kandidaten werden vor bereits bekannten APIs ausgegeben. Die bloße Existenz einer Funktion bestätigt weder Signatur noch Verwendbarkeit.

## Grenzen und Datenschutz

Pro Snapshot gelten höchstens 700 Werte und 90.000 budgetierte Zeichen, Tiefe 3, 64 untersuchte Schlüssel je normaler Tabelle, 160 Zeichen je Wert und 180 Zeichen je vollständigem Pfad. Zu lange Pfade werden ausgelassen, damit unterschiedliche Felder nicht zu einem gemeinsamen gekürzten Schlüssel verschmelzen. Eigene Abschnittsquoten schützen native Messwerte, Materialstichproben, Licht-/Wetterstrukturen und API-Namen gegeneinander. Pro Lua-Umgebung werden höchstens 4096 globale Schlüssel betrachtet; die API-Ausgabe hat zusätzlich eine eigene Quote von 95 Schreibversuchen. Begrenzungen werden über `truncated=true` sichtbar. `getLimits()` liefert eine Kopie der allgemeinen Grenzen.

Tabellen werden mit `next/rawget` gelesen, Zyklen markiert und Tabellenadressen nicht ausgegeben. Spieler-, Eigentümer-, Netzwerk-, Konto- und ähnliche Felder sowie Missions-/Fahrzeugrückverweise werden ausgeschlossen. Unbekannte Stringinhalte, Dateipfade und freie Fehlertexte werden nur als Typ und Länge erfasst. Eigene `FS25E_...`-Statusschlüssel und wenige bekannte Diagnose-Enums bleiben lesbar. Es werden keine privaten Spieler- oder Fahrzeugeigentümer-IDs gesammelt.

Fehlende Getter, unbekannte Methoden oder ein Getterfehler lösen keine Setterversuche aus. Ein Snapshot kann Fähigkeiten sichtbar machen, die anschließend anhand belastbarer Quellen geprüft werden müssen. Er ist kein Nachweis, dass ein vermeintlicher Postprocessing-Regler tatsächlich unterstützt wird oder sichtbar wirkt.

## Quellen und Prüfung

Die Sonnenquelle ist im öffentlichen [GIANTS PlaceableSolarPanels-Code](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=78&class=763&version=engine) belegt. Die qualitätsbezogenen No-Argument-Getter werden im [GIANTS SettingsModel](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=43&class=486&version=engine) verwendet. Das installierte `sdk/debugger/scriptBinding.xml` bestätigt die Licht-, Regen-, Nässe- und Shaderparameter-Verträge. RGB-Lichtzugriff ist zusätzlich durch den Originalcode `RealLight.lua` belegt.

`work/test_runtime_probe.lua` und die unabhängige Prüfung `work/test_runtime_probe_review.lua` testen Native-Argumente, Typ-/Slot-Grenzen, getrennte Lua-Umgebungen, unbekannte Funktionen, Metamethodenfallen, redaktierte Inhalte, lesbare eigene Statusschlüssel, sichere Logformatierung, große zyklische Tabellen, lange kollidierende Pfade und begrenzte Traversierung. Die Tests rufen keinen Renderer-Schreibweg auf. Ein echter Spiel-Snapshot ist für die Entdeckung der tatsächlich verfügbaren Laufzeitfelder erforderlich.
