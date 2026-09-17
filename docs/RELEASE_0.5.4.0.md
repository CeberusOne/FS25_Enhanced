# FS25 Enhanced 0.5.4.0

## Materialien

Klarlack, Glätte, SSR-Lackparameter und Oberflächenprofile ändern nur verifizierte Lackmaterialien. Die Erkennung gleicht die tatsächlichen Detail-Texturpaare mit den originalen GIANTS-Materialvorlagen ab. Glas/Alpha-Oberflächen, poröses Gummi und unbekannte Materialien erhalten dadurch keinen zusätzlichen Lackglanz. Matte Lackvorlagen bleiben regelbar. Kompilierte DDS-Texturen werden ebenso erkannt wie ihre PNG-Quellnamen.

Die Einstellung gilt für geladene Fahrzeuge und Geräte, ohne einzusteigen. Der vorhandene An/Aus-Verbinder erweitert dieselbe Lackauswahl auf passende Kartenobjekte. Nässewirkung bleibt ein unabhängiger Faktor auf vorhandene Nässe; sie überzieht trockene Materialien nicht mit Klarlack. Eigene Mod-Lacke ohne nachweisbar passendes Texturpaar werden vorsichtshalber ausgelassen.

Der native Logfehler `getChildAt: Index out of range` bei sich ändernden Terrain-Kindern ist korrigiert: Die schrittweise Kartensuche prüft vor jedem Zugriff die aktuelle Kinderzahl.

## Umgebung

Neue Kategorie **Umgebung** im Einstellungsmenü und Live-Fenster mit 17 Einträgen:

- Sonnenlichtintensität 0–8×, Wärme und Tönung −1 bis +1, einzelne Rot-/Grün-/Blau-Faktoren 0–4×.
- Sonnenlichtstreuung an/aus und Intensität 0–8.
- Weichheit der Sonnenschatten, Abstand der Ersatz-Flächenlichtquelle, Tiefenbias und Schattenextrusion.
- Farbe der Sonnenlichtstreuung: Wärme, Tönung und RGB-Faktoren, sobald ein tatsächlicher Original-Farbaufruf von GIANTS beobachtet wurde.

Die meisten Regler arbeiten in 0,001-Schritten, Distanzregler in 0,1-Schritten. Wärme ist ein relativer Warm/Kalt-Farbfilter, keine Kelvinmessung. Der Schatten-Lichtabstand steuert die simulierte Flächenlichtquelle und ist **keine LOD- oder Schatten-Sichtweite**. Die Wertebereiche sind Mod-Bedienbereiche; ihre sichtbare Wirkung hängt von Tageszeit, Schattenqualität und aktivierter Streuung ab.

Die drei bereits vorhandenen Sonnenregler bleiben erhalten und sind mit ihren Entsprechungen unter Umgebung gekoppelt. Sie verwenden dieselbe Lichtquelle und denselben Schreibpfad. Native RGB- und Scalar-Getter prüfen tatsächliche Werte. Für Streuungsfarbe liefert GIANTS keinen Getter: Ohne beobachtete Originalfarbe wird kein erfundener Ausgangswert geschrieben. Im Menü steht dann der konkrete Wartegrund.

Die bisherige Kategorie Licht heißt jetzt **Lichter & Lampen**. Ihre bestehenden Regler und die Kategorie Atmosphäre bleiben erhalten. Gestaltung und Bedienung des Live-Fensters bleiben gleich, hinzu kommt der Umgebungsreiter. Die Statusanzeige bleibt auf FPS und Frametime beschränkt. Es gibt weiterhin keine Automatik, Bedienungsstufen oder Wirkungsradius.

## Wetter und Grenzen

Der echte Wetter-Logfehler wurde auf eine nicht vorhandene XML-Cleanup-Funktion zurückgeführt. Die Verarbeitung nutzt jetzt das vom aktuellen FS25-SDK angebotene `delete(xml)` als Rückfall und benennt fehlende Funktionen einzeln. Der Regen-Multiplikator bleibt immer mindestens **0,01**.

Zusätzliche Vollbildshader/LUTs, frei einstellbare Belichtung, Bloom und globales Color-Grading sind in diesem Build nicht integriert. Die Recherche in aktuellem GDN, SDK und Originalskripten ergab dafür keinen belegten, sicher rücknehmbaren Live-Lua-Zugriff. Map-XML-Parameter und ältere Konsolenbefehle allein belegen diese Schnittstelle nicht. Die neuen Farbfaktoren verändern die echte Sonne, nicht sämtliche Bildpixel oder alle indirekten Himmelsanteile.

## Prüfung

Lua-Syntax, XML/GUI-Layout, 27 Sprachdateien, echte SDK-Signaturen, originale GIANTS-Materialvorlagen und Wetter-Ladewege werden geprüft. Neue Regressionen prüfen Materialausschlüsse, Änderungen des Szenenbaums, native Sonnen-/Streuungswerte, Fehler-Rücknahme und Originalwiederherstellung. Die genaue Zahl und Ergebnisse stehen im separaten Prüfbericht.

**Kein neuer visueller Test in einer laufenden FS25-Sitzung für 0.5.4.0.** Die Prüfungen belegen Datenfluss und Rücklesewerte, nicht bereits das sichtbare Ergebnis im konkreten Spielstand.

## Bedienung und Quellen

F9/Strg+E öffnet die native Einstellungsseite; Strg+F9 oder Umschalt+F9 öffnet das Live-Menü. Im Einstellungsmenü unter Umgebung wählen, welche neuen Regler im Live-Menü erscheinen. Zum unmittelbaren Tageslichtvergleich eignen sich Sonnenintensität und RGB-Faktoren; Zurücksetzen stellt Originalwerte wieder her.

- [GIANTS Material-Texturabfrage](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=22&function=598&version=engine)
- [GIANTS Sonnenlichtquelle in PlaceableSolarPanels](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=78&class=763&version=engine)
- [GIANTS Lichtstreuungsintensität](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=11&function=211&version=engine)
- [GIANTS Abstand für weiche Schatten](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=11&function=216&version=engine)
- Weitere API-Belege und Grenzen: `ENVIRONMENT_LIGHTING_0.5.4.0.md`, `ENVIRONMENT_API_AUDIT_0.5.4.0.md` im Mod-Dokumentationsordner.
