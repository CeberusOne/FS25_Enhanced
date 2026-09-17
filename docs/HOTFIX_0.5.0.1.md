# FS25 Enhanced 0.5.0.1 – Menü- und Log-Hotfix

Die Absturz-Log des Builds 0.5.0.0 wurde ausgewertet. Sie enthält massenhaft native Licht-Typfehler sowie `PagingElement.lua:249: attempt to index nil with disabled` und anschließend `TabbedMenu.lua:236: attempt to index nil with requestClose`.

## Korrekturen

- Live-Statusanzeige auf genau zwei Werte reduziert: FPS und Frametime in Millisekunden. Kein Zielwert, Profil, Szenentyp oder weitere Diagnosewerte. Kleineres Panel ohne Überschrift; das Slider-Menü bleibt vollständig erhalten.

- Spielmenü: Frame-Controller und Paging-Seite verwenden denselben Eintrag. Fehlgeschlagene Registrierung wird vollständig zurückgenommen. Kein Wiederholungsversuch in einer bereits fehlgeschlagenen Menüinstanz. Einfügen erst bei geschlossenem Menü; Größe und Ursprung folgen dem nativen Paging-Bereich.
- F9-Dialog: Button-Anker, feste Buttonbreiten, getrennte Beschriftungs-/Wertspalten und Hintergrundreihenfolge korrigiert. Kategoriebuttons lösen nicht mehr alle dieselbe globale Bestätigungstaste aus.
- Live-Menü: explizite native Textausrichtung am oberen Rand, bereinigte Wrap-/Clip-Zustände, korrekte Messung fetter Schrift und Begrenzung langer UTF-8-Beschriftungen.
- Lichtverwaltung: PlaceableLights darf Transformgruppen liefern. Nur nachgewiesene LIGHT_SOURCE-Knoten erreichen native Lichtfunktionen; der begrenzte Unterbaum der eigenen Lichtgruppe wird aufgelöst. Sichtbarkeit von Zwischenknoten wird beachtet. Gelöschte bzw. inzwischen fremdklassige Handles werden sicher ausgetragen.
- Dateizugriffe: Kostenkatalog über native XML-API mit Freigabe des Handles. Keine verbotenen JSON-Leseversuche im FS25-Lua-Sandboxbetrieb. Externe Hardwaretelemetrie bleibt als nicht verbunden ausgewiesen; Spiel-Framezeiten bleiben verfügbar.

## Prüfung und Grenzen

Der neue Menütest reproduziert den alten Fehler mit den originalen GIANTS-Lua-Methoden. Mit dem Hotfix bestehen zwölf Öffnen-/Tabwechsel-/Schließen-/Missionswechsel sowie drei absichtlich ausgelöste Registrierungsfehler mit vollständiger Rücknahme. Engineinterne GUI-Primitive werden simuliert.

Der neue Lichttest enthält echte PlaceableLights-Datenstrukturen mit Gruppen und Kindlichtern. Er prüft native Änderungen und Rücknahme, versteckte Zwischenknoten, ungültige Deklarationen, fehlende Klassenerkennung sowie gelöschte/wiederverwendete Handles. Native Typfehler im Test: null. Weitere Tests prüfen 19 Dialogelemente, Textzustände und ausbleibende verbotene Dateizugriffe.

**Kein neuer realer FS25-Spieltest.** Die ursprüngliche Fehlerlog ist analysiert; Fehlerfreiheit der neuen Sitzung und tatsächliche Darstellung müssen nach dem Neustart geprüft werden. Die verbliebenen PNG-Format-/Mipmap-Warnungen des Icons und fremde Basis-/Kartenwarnungen werden von diesem Hotfix nicht als behoben behauptet. Der Gesamtumfang und die offenen Asset-/Visualaufgaben aus dem PDF ändern sich durch diesen Hotfix nicht.

Zum Prüfen: Spiel neu starten, Spielstand laden, Escape-Spielmenü mehrfach öffnen, zur Enhanced-Seite und zurück wechseln. F9-Dialog und Live-Menü öffnen/schließen; an einem Gebäude mit Lichtern und einem Fahrzeug testen. Bei erneuten Fehlern die neue log.txt sichern.

## GIANTS-Grundlagen

- [TabbedMenu](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=43&class=491&version=engine) und [PagingElement](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=43&class=482&version=engine): Menü- und Paging-Verträge; zusätzlich lokal vorhandene originale GIANTS-Skripte.
- [PlaceableLights](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=78&class=746&version=engine): Einträge enthalten einen Szenenknoten; die native Lichtquellenklasse muss vor Licht-API-Aufrufen geprüft werden. Abgleich mit lokalem RealLight.lua und SDK scriptBinding.xml.
