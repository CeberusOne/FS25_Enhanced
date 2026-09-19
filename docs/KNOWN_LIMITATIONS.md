# Bekannte Grenzen – 0.6.0.0

- Kein eigener Renderer, keine Pfützen-Simulation, keine Belichtung/Bloom/Color-Grading-Live-API.
- God Rays brauchen volumetrische Nebelqualität über Aus; der Faktor schaltet Streuung nie aus (Himmel).
- Kronenverdeckung braucht SSAO und beschattete Kronen.
- Feldfrucht-Wind schreibt in Blockshape-Materialien. Ob der Foliage-Renderer sie live liest, ist im Spiel zu prüfen. Ab ~80 m Distanztextur.
- Wasser-Schaum nur mit vorhandener Shallow-Water-Simulation der Karte.
- Zusätzliche Pflanzen-Biegezonen vergrößern vorhandene Footprints, nicht die Bending-Texturauflösung.
- IES nur mit vorhandenen Profilen am Licht.
- Tonwertkurve und Spotschatten-Atlas stehen in `scriptBindingChanges.txt`. Fehlt eine Funktion, bleibt der Regler versteckt.
- FOV/Spiegel/Lichtprofil laufen über `g_gameSettings`. VanillaGuard nimmt sie vor dem Speichern zurück; ein Crash dazwischen kann Werte in `gameSettings.xml` lassen.
- Default-Font deckt Arabisch und volles CJK nicht ab. Geprüft: Deutsch und Englisch.
