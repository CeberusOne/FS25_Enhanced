Aktuell 0.5.1.0 (lokal, unveröffentlicht): Bäume als Split-Shapes erreichbar, sichtbare Vegetationsregler (Wind, Farbvariation), God Rays als Faktor, Pflanzeninteraktion zu Fuß, API-Inventar im Log. Davor 0.5.0.0 (GitHub): Gesamtprüfung mit Integrationslauf; Licht/Tiefe-Shader der Welt; VanillaGuard (Spielmenü entkoppelt); Qualitätsstufen, Sprachschalter, nur Live-Fenster; nasse Umgebung, Lichtstimmungen, MOD/VANILLA-Schalter, budgetierte Materialschreibvorgänge; globale Engine-Grafikeinstellungen, filmische Tonwertkurve, Spotschatten-Feinabstimmung, Sichtfeld/Spiegel über GameSettings und ein relativer Lackspiegelungsregler. Details: ENGINE_SETTINGS.md und CHANGELOG.md. Frühere Radius-/Automatikbeschreibungen sind Entwicklungshistorie.

# Bekannte Grenzen

Dieser Stand ist eine umfangreich überarbeitete Entwicklungsversion. Die 63 Abschnitte des Plans sind in FEATURE_MATRIX.md einzeln abgeglichen. Vorhandene Regler und bestandenes Mock-Testing bedeuten nicht, dass der gesamte PDF-Plan fertig oder visuell freigegeben ist.

- Keine neu erstellten Pfützen-/Wasserrenderassets, keine zusätzliche Sonnenkaskade und kein eigener Renderer. Wasseradapter können nur belegte kompatible vorhandene Szenenobjekte nutzen; fehlende Voraussetzungen werden im Menü erklärt.
- Shadow-Focus braucht eine passende Shape-/Kamera-Struktur. Ein boolescher Aufruf ist ungültig. Fremde Self-Shadow-Ignore-Listen und Merge-Nearplanes werden ohne vollständige Restoreinformation nicht überschrieben.
- IES verwendet vorhandene Assetprofile. Universelle Nachrüstung, photometrisch vermessene neue Profile und universelle Spotlicht-Streuung sind nicht zugesichert.
- Material-Normalstärke/Microdetail brauchen geeignete Shaderparameter oder eigene Assets. Generische Spiegelbudgets und neu entworfene Atmosphärenprofile sind noch offen.
- Wetter ohne Getter kann nur „gesendet/beobachtet“ melden. Inaktive Lichter und noch nicht beobachtete Partikelsysteme zeigen wartende Konfiguration; eine sichtbare Sofortwirkung wird nicht behauptet.
- Vegetationsdichte/Occlusion und Partikeltypen sind nicht vollständig klassifiziert. Manche Szenenmerkmale sind Heuristiken.
- Keine reale FS25-Visualprüfung, Performance-Messreihe oder vollständige Karten-/Mod-Kompatibilitätsprüfung für diesen Build. CJK-Schrift, Controller und sämtliche UI-Skalierungen müssen im Spiel geprüft werden.
- Sprachdateien enthalten echte Übersetzungen für aktive Elemente sowie ausdrücklich ausgewiesene englische Fallbacks für ältere Diagnosekeys; LOCALIZATION.md und der Coveragebericht geben den tatsächlichen Stand an.

Die PDF-Release-Strategie lässt Wasser-/Material-/Reflexionsexperimente ausdrücklich später zu. Das ändert nichts daran, dass die Forderung nach sämtlichen PDF-Funktionen erst nach der verbleibenden Assetentwicklung und realen Testfreigabe erfüllt ist.

## Grenzen des lokalen Stands 0.5.1.0

- Feldfrucht-/Grasregler schreiben in die Materialien der Blockshapes aus
  `data/foliage/*/*.i3d` (Lesen/Schreiben per Engine bestätigt, 486 Materialien im
  Log). Ob der Foliage-Renderer diese Materialien beim Zeichnen live liest, ist
  erst mit dem Windregler im Spiel entscheidbar. Ab ~80 m zeichnet das Spiel
  Felder als Distanztextur; dort wirkt kein Pflanzenparameter.
- Kronenverdeckung ist ein Exponent auf den SSAO-Anteil (`treeBranchShader`
  `pow(ssao, aoIntensity)`), nicht auf eine eingebackene Verdeckung: ohne SSAO
  oder in voll beleuchteten Kronen bleibt sie unsichtbar.
- God Rays brauchen volumetrische Nebelqualität über *Aus*; der Faktor kann
  Strahlen nur verstärken oder abschwächen, nie erzeugen, wo die Engine keine
  volumetrische Streuung zeichnet.
- Belichtung, Bloom und Farbkorrektur (`environment.xml`) bleiben ohne Regler,
  bis das API-Inventar im Log die echten Laufzeitnamen liefert.
- Die zusätzliche Pflanzeninteraktion kopiert nur vorhandene Biegeflächen
  (Spielerfigur 1 m, Fahrzeuge wie vom Hersteller); Fahrzeuge ohne
  FoliageBending-Spezialisierung bekommen keine.

## Grenzen der Fassung 0.5.6.0 / 0.5.7.0

- Auflösungsskalierung, Schärfe und Frame Generation fehlen bewusst: die
  zugehörigen `SettingsModel`-Methoden sind im ausgelieferten Quelltext leer,
  und ein geratener Funktionsname wäre keine belegte Schnittstelle.
- `terrain-quality` bleibt gesperrt. GIANTS vermerkt im eigenen Quelltext, dass
  dafür ein Neustart nötig ist, und der CapabilityApplier lässt nur
  Live-Einstellungen zu.
- Tonwertkurve und Spotschatten-Regler stammen aus `sdk/scriptBindingChanges.txt`
  und sind dort nur namentlich geführt. Fehlt eine Funktion in einer künftigen
  Spielversion, meldet der Regler „nicht verfügbar“.
- Sichtfeld, Spiegelanzahl und Lichtprofil werden über `g_gameSettings`
  geschrieben. Speichert das Spiel seine Einstellungen, während ein geänderter
  Wert aktiv ist, steht dieser bis zur Rücknahme in `gameSettings.xml`.
- Upscaler, MSAA/AA, VRS, DRS, Textur-/Shader-Qualität und Texturfilterung sind
  seit 0.5.7.0 nicht mehr im Mod (Hauptmenü).
- Ob das Wetter `setWetness` über Lua oder nativ schreibt, ist ohne Spieltest offen.
  Beide Fälle sind abgedeckt (Hook und Frame-Abgleich), gemessen ist keiner.
- Die Weltsuche für nasse Flächen kann auf großen Karten einige hundert Frames
  brauchen; solange zeigt der Regler „Weltmaterialien werden gesucht“.
- Die Lackspiegelung ist offline gegen dreizehn echte Materialvorlagen geprüft
  (`tools/smokeMaterials.lua`), aber nicht visuell im Spiel abgenommen.
- `shared/font/defaultFont.font` deckt weder Arabisch noch alle CJK-/Hangul-Zeichen
  ab, die in den älteren Sprachdateien stehen. Diese Sprachen laden im Spiel eine
  eigene Schrift; geprüft ist nur, dass Englisch und Deutsch vollständig in der
  Standardschrift enthalten sind.
