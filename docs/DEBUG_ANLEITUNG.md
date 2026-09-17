# FS25 Enhanced – Grafikdiagnose

Die Diagnose liest Grafikdaten und schreibt sie in die vorhandene `log.txt`. Sie verändert keine Grafikeinstellungen und startet nicht automatisch. Ein geladener Spielstand ist erforderlich.

## Im Live-Menü

In der Kategorie **Leistung** stehen zwei Aktionen:

- **Diagnose protokollieren** schreibt eine einmalige Momentaufnahme.
- **Änderungen 60 Sekunden aufzeichnen** startet eine begrenzte Aufzeichnung. Ein erneuter Klick stoppt sie vorzeitig.

Für einen aussagekräftigen Test die Aufzeichnung starten und anschließend genau den problematischen Regler verändern. Zum Beispiel den Klarlack am selben Fahrzeug erhöhen oder die Sonnenlicht-Wärme bei Tageslicht verstellen. Die Aufzeichnung prüft alle zwei Sekunden auf Änderungen. Sie endet automatisch; bei sehr vielen Änderungen kann die Protokollgrenze sie früher beenden.

## Über die Spielkonsole

```text
fs25eProbe all
fs25eProbe materials
fs25eProbeWatch 60 environment
fs25eProbeStop
```

`fs25eProbe` erstellt eine Momentaufnahme. Ohne Kategorie verwendet es `all`.

`fs25eProbeWatch` zeichnet Änderungen auf. Die Dauer ist frei von **2 bis 300 Sekunden** wählbar; ohne Argumente gelten 60 Sekunden und `all`. `fs25eProbeStop` beendet eine laufende Aufzeichnung.

Mögliche Kategorien: `all` (alles), `environment` (Umgebung), `lighting` (Lichter und Lampen), `weather` (Wetter), `materials` (Materialien) und `render` (Grafikoptionen).

## Ergebnis weitergeben

Die Einträge stehen in:

```text
C:\Users\aabbc\OneDrive\Dokumente\My Games\FarmingSimulator2025\log.txt
```

Nach dem Test die Datei sichern, bevor das Spiel erneut gestartet wird. In der Datei nach **FS25E_PROBE** suchen. Bei einer Aufzeichnung gehören die Zeilen von `WATCH_BEGIN` bis `WATCH_END` zusammen; `CHANGE` zeigt veränderte Werte. Dazu kurz angeben, welcher Regler verändert wurde und welche sichtbare Wirkung erwartet wurde.

Ein erfolgreicher Schreib- oder Lesewert belegt noch keine sichtbare Bildänderung. Die Diagnose hilft zu unterscheiden, ob die Engine einen Wert annimmt, eine andere Spielroutine ihn zurücksetzt oder kein passendes Material beziehungsweise Licht verfügbar ist.
