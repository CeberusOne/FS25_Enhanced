# FS25 Enhanced 0.5.5.0

Enthält sämtliche Änderungen aus 0.5.4.0: eigene Umgebungskategorie mit 17 Reglern, Lackschutz für Glas/Gummi, Umbenennung in Lichter & Lampen, Wetter-XML-Fix und Korrektur der veränderlichen Szenenbaum-Indizes.

Zusätzlich gibt es eine manuell auslösbare Laufzeitdiagnose für Umgebung, Lichter, Wetter, Materialien und Renderoptionen. Sie liest bekannte native Getter, angeforderte Modwerte und Providerdiagnosen. Ein begrenzter Blick auf relevante Laufzeittabellen und Funktionsnamen hilft dabei, zusätzliche tatsächlich vorhandene Schnittstellen zu entdecken. Unbekannte Funktionen werden nicht aufgerufen; die Diagnose schreibt keine Grafikwerte.

Im Live-Menü unter **Leistung**: **Diagnose protokollieren** und **Änderungen 60 Sekunden aufzeichnen**. Beide Aktionen lassen sich wie andere Einträge auf der nativen Einstellungsseite ein-/ausblenden. Die zweite Aktion stoppt bei erneutem Klick. Die reine FPS-/Frametime-Statusanzeige bleibt unverändert.

Konsolenbefehle:

```text
fs25eProbe all
fs25eProbe materials
fs25eProbeWatch 60 environment
fs25eProbeWatch 120 weather
fs25eProbeStop
```

Die Ausgabe steht in der normalen FS25-`log.txt`, erkennbar an `FS25E_PROBE`. Snapshots enthalten Start-/Endmarken, Versionsnummer, native Werte, Feldtypen und begrenzte API-Funde. Die Aufzeichnung erfasst einen Ausgangsstand und danach alle zwei Sekunden nur Änderungen. Sie endet nach 2–300 Sekunden aktiver Updatezeit, beim Entladen/Wechsel der Mission, bei einem Fehler oder beim Erreichen der Protokollgrenzen. Kein automatischer Start beim Laden; keine Registrierung neuer Engine-Hooks für die Diagnose.

Zur Auswertung einen problematischen Regler während der Aufzeichnung ändern und den sichtbaren Eindruck notieren. Nach Beenden des Tests die Logdatei sichern, bevor FS25 sie beim nächsten Start ersetzt. Native Werte belegen den Datenweg; sichtbare Pixelwirkung und Eignung einer neu gefundenen Funktion müssen anschließend gesondert geprüft werden. Unbekannte Funktionsnamen sind ausdrücklich kein Freigabenachweis für neue Setter.

Die bestehenden 0.5.4.0-Änderungen bleiben getestet; neue Diagnoseprüfungen behandeln begrenzte Traversierung, zyklische Tabellen, fehlende APIs, Logger-/Getterfehler, unveränderte Zustände, Änderungserkennung, vorzeitigen Stopp und Konsolenargumente. Der Prüfbericht nennt die vollständigen Ergebnisse. Kein neuer Ingame-/Renderingtest dieses Builds.

Details zur Bedienung: DEBUG_ANLEITUNG.md. Technische Grenzen und Quellen: RUNTIME_PROBE.md. Umgebungsregler und Materialschutz: RELEASE_0.5.4.0.md.
