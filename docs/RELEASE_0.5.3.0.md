# FS25 Enhanced 0.5.3.0

## Licht

Lampenintensität ist jetzt von **0 bis 8×** einstellbar; Wärme und Farbstich sind deutlich kräftiger, bleiben aber in Schritten von **0,001** einstellbar. Die Regler ändern aktive Fahrzeug- und Gebäudelampen. Ausgeschaltete Lampen bleiben ausgeschaltet.

Zusätzlich gibt es eigene **Sonnenlichtintensität, Sonnenlicht-Wärme und Sonnenlicht-Farbstich**. Diese verändern die tatsächliche, von GIANTS verwendete Sonnenlichtquelle mit nativen RGB-Rückleseprüfungen. Intensität ebenfalls 0–8×. Wetter- und Tageszeitänderungen liefern neue Originalwerte, auf die der gewählte Faktor angewendet wird. Eine vorübergehend fehlende Sonnenquelle wird abgewartet; der Mod deaktiviert das Modul deswegen nicht dauerhaft. Die Regler ersetzen weder alle Himmelskurven noch sämtliches indirektes Umgebungslicht. Der separate Bildhelligkeitsregler verwendet weiterhin die vom Spiel angebotenen Stufen.

## Materialien

Standardmäßig gelten die Materialregler für **alle geladenen Fahrzeuge und Geräte, auch zu Fuß**. Einsteigen ist nicht nötig. Die Erkennung prüft jeden unterstützten Parameter einzeln: Ein Material ohne Klarlack/SSR oder mit hoher Porosität wird nicht mehr pauschal auch von der Grundglätte ausgeschlossen. Materialtausch und spät geladene Teile auf demselben Fahrzeug werden erneut erkannt; vorhandene Änderungen gehen beim Ein-/Aussteigen nicht verloren.

**Grundglätte: Faktor 0–10**, entsprechend dem installierten GIANTS-Fahrzeugshader. Das Oberflächenprofil „Poliert“ setzt Klarlackintensität 1, Klarlackglätte 1 und Grundglätte 5. „Matt“ setzt 0, 0 und 0,1. Klarlackglätte benötigt eine Klarlackintensität größer null; Schmutz, Schnee und Texturmasken können den sichtbaren Effekt begrenzen. Nässewirkung bleibt ein Faktor auf vorhandene Nässe – trocken mal Faktor bleibt trocken.

Neuer An/Aus-Verbinder **„Materialien kartenweit verbinden“**:

- **Aus:** nur Fahrzeuge und Geräte.
- **An:** zusätzlich passende Materialien des unterstützten Fahrzeug-Shadertyps auf der Karte. Die Suche läuft schrittweise ohne Entfernungs- oder Fahrzeugbesitzgrenze.
- **Wieder aus:** Originalwerte nur der zusätzlichen Kartenmaterialien wiederherstellen; Fahrzeugwerte bleiben erhalten.

Der Verbinder wird gespeichert. Materialien mit anderen Shadern werden nicht zwangsläufig gleich behandelt: Der Mod ersetzt keine Shader und macht aus einem Terrain-/Gebäude-/Vegetationsshader keinen Fahrzeugshader. Native Änderungen bleiben privat je Materialslot; gemeinsam verwendete Originalmaterialien werden nicht pauschal überschrieben.

## Wetter

Die bisherige Fassung beobachtete Funktionsaufrufe teilweise nur in der Mod-Umgebung. Nun werden die tatsächliche GIANTS-Funktionsumgebung und zusätzlich die gemeinsamen I3DManager-Ladewege erfasst. Die Erkennung akzeptiert absolute/relative Pfade, zusätzliche Root-Knoten und vor der Missionsbindung geladene Regen-/Hagel-/Schnee-Assets. Wetter-Neuladen wird erneut erfasst. Einmalige Logmeldungen benennen erfolgreiche Registrierung oder die konkrete fehlgeschlagene Capture-Stufe.

Für einzelne Regenparameter fehlen native Getter. Diese werden weiterhin ehrlich als beobachteter Schreibaufruf ausgewiesen. Turbulenz ohne belegte Originalfrequenz wird nicht frei erfunden. **Regen-Multiplikator nie unter 0,01.**

## Prüfung und Anwendung

Native Setter-/Getter-Fixtures, originale GIANTS-Skripte und der installierte SDK-/Shaderstand werden geprüft. Die Wetterprüfung führt die originale `I3DManager.lua` in getrennten Mod-/Engine-Umgebungen aus. Der Lichttest nutzt den echten Sonnenlichtpfad von `PlaceableSolarPanels`. Materialtests prüfen Austausch, spät geladene Teile, 300 Fahrzeuge, starke Werte, Weltverbinder samt Rücknahme und begrenzte Sucharbeit. Die Mod schreibt gedrosselte `LiveApply`-Diagnosen mit Zielanzahl und bei Sonne den nativen RGB-Werten in die Logdatei.

**Noch kein visueller Test in einer echten FS25-Sitzung für diesen Build.** Die neuen Prüfungen belegen Aufrufwege und Rücklesewerte, nicht bereits sichtbare Pixeländerungen im konkreten Spielstand. Für einen deutlichen Vergleich tagsüber die neuen Sonnenregler verwenden; Lampenregler bei eingeschalteten Lampen. Für Materialien „Poliert“ und „Matt“ vergleichen. Die Statusanzeige bleibt auf FPS/Frametime beschränkt; das Live-Fenster behält seine Gestaltung.

F9/Strg+E: native Einstellungsseite. Strg+F9 oder Umschalt+F9: Live-Menü. Nach Austausch der Dateien FS25 neu starten. Solange die alte Sitzung läuft, verwendet sie noch den vorherigen Build. Automatik, Bedienungsstufen und der alte Wirkungsradius bleiben entfernt.

## Quellen

- [GIANTS setShaderParameter](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=24&function=698&version=engine): private Schreibzugriffe je Shape/Materialslot.
- [GIANTS PlaceableSolarPanels](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=78&class=763&version=engine): dokumentierter Sonnenlichtknoten.
- Installiertes `vehicleShader.xml`: smoothnessScale 0–10, Klarlackintensität und -glätte 0–1; echte Stock-`VehicleMaterial.lua` und `I3DManager.lua`.
