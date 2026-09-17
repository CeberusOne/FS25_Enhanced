Aktuell 0.5.5.0: Umgebung und Lackschutz aus 0.5.4.0 plus manuelle Laufzeitdiagnose und begrenzte Änderungsaufzeichnung. Details: RELEASE_0.5.5.0.md. Frühere Radius-/Automatikbeschreibungen sind Entwicklungshistorie.

# Architektur – 0.5.0.0

`FS25_Enhanced.lua` lädt clientseitige Dienste nach Missionsstart. Moduladapter installieren ihre Beobachtungshooks bereits beim Laden des Mods, um ursprüngliche Wetter-/Partikelargumente zu erfassen. Vor dem Löschen der Mission enden Kalibrierung, A/B und Cinematic; anschließend werden Renderwerte vor der Entity-Löschung zurückgesetzt. Dedicated Server starten keine Grafikdienste.

`VisualControls` ist der gemeinsame Katalog für Live-Menü, native Spielmenüseite, Automatik und eigene Profile. Validierung → Verfügbarkeit → Lock → typisierter Adapter → Rücklesen → Status. Stufen werden nur aus tatsächlich unterstützten Engine-Enums gebildet; NUM ist keine Stufe. Kontinuierliche Werte haben normalerweise 0,001-Schritte. Begrenzungen sind geprüfte Modbereiche, keine behaupteten Hardwaremaxima.

`CapabilityApplier` verarbeitet ausschließlich reversible globale Skalare; mehrparametrige Licht-/Wetter-/Materialaufrufe gehören in ihre Adapter. Fehlgeschlagene oder nur teilweise angenommene Aufrufe werden rückgängig gemacht. Ausstehende Rücknahmen bleiben gespeichert. Ein neuer Wert von GIANTS/anderen Mods wird nicht durch eine veraltete Baseline überschrieben.

`ModuleRuntime` begrenzt Fehler auf einzelne Module und wiederholt ausstehende Rücknahmen. Provider besitzen nur ihre Änderungen und berücksichtigen Mission-Identität und gelöschte Nodes. `PerformanceMonitor` misst dt; `SceneAnalyzer` liefert verfügbare Szenenmerkmale. `BudgetAllocator`, `GraphicsGovernor` und `CalibrationManager` arbeiten mit ausdrücklich geschätzten beziehungsweise korrelierten Kosten.

`FS25E_GraphicsMenuIntegration` nutzt TabbedMenu:addPage für eine zusätzliche Spielmenüseite. `FS25E_SettingsDialog` bleibt als F9-Einstieg verfügbar. `FS25E_LiveOverlay` besitzt einen getrennten Eingabekontext und stellt Cursor/Input beim Schließen wieder her. Native GUI-Refreshs lösen keine Einstellungsänderung aus.

Persistenz: `modSettings/FS25_Enhanced/settings.xml`, explizit gespeichertes `liveProfile.xml`, Kalibrierung und Benchmarkbericht. Keine Multiplayer-Synchronisierung grafischer Clientwerte, keine Spielstand-/Wirtschaftsänderung und keine Binärkomponenten. Die modlokalen XML-Dateien sind Konfiguration, keine Engine-Hardwareprofile.
