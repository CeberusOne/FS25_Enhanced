Aktuell 0.5.5.0: Umgebung und Lackschutz aus 0.5.4.0 plus manuelle Laufzeitdiagnose und begrenzte Änderungsaufzeichnung. Details: RELEASE_0.5.5.0.md. Frühere Radius-/Automatikbeschreibungen sind Entwicklungshistorie.

# Performance und Messgrenzen

Ziel-FPS 15–240 definieren das Zeitbudget 1000/FPS, keinen Framelimiter. Die einfachen Menüs bieten 30/60/90/120 sowie im nativen Menü einen vorhandenen benutzerdefinierten Wert; das Live-Menü erlaubt jede ganze Zahl im Bereich. Automatik startet standardmäßig ausgeschaltet.

Messwerte: Framezeiten aus Mission-dt, gleitende Fenster 1/5/30 s, Mittelwert, p99/1%-Low, Varianz und Spitzen. GPU-Zeit, CPU-Passkosten und VRAM bleiben unbekannt, solange keine verlässliche Quelle existiert. dt-Korrelation ist kein isolierter GPU-Benchmark.

Automatische Regelintervalle: FAST 1 s, MEDIUM 5 s, SLOW 20 s. Hysterese verlangt anhaltenden Druck beziehungsweise Reserve; einzelne Frames ändern keine Qualitätsstufe. Lokale Lichtpriorisierung läuft alle 250 ms; große automatische Shadow-Auflösungswechsel mindestens 15 s auseinander. Scans und Mutationen sind begrenzt. Manuelle Locks und experimentelle Ausschlüsse gelten auch für Presets und Kalibrierung.

Presets unterscheiden unter anderem globale/lokale Schattenbudgets 4/6/8/12 und Nah-/Fernauflösungen 512/256, 1024/512, 2048/512, 2048/1024. Sichtweiten steigen von Performance bis Cinematic. Diese Ziele sind implementiert; bessere Grafik bei gleicher Bildrate ist noch kein nachgewiesenes Ergebnis.

Kalibrierung: stabile Ausgangsphase, kleine rücknehmbare Änderung, Einschwingphase und Vergleich. Kamera-/Szenenwechsel und Cinematic/A-B brechen beziehungsweise verhindern den Versuch. Gelernte Kosten tragen Kontext, Samples und Confidence. Fehlende oder unsichere Daten nutzen Schätzwerte.

Benchmark: 60 s Aufnahme über die Performance-Kategorie, anschließend XML-Export. Für Vergleiche identische Kamerawege, Tageszeit, Wetter, Fahrzeuge, Auflösung, Upscaler und Hintergrundlast. Die zehn Szenen und vier Vergleichspaare stehen in TEST_MATRIX.md. Reale Ergebnisse wurden hier nicht erzeugt.
