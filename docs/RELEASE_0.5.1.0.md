# FS25 Enhanced 0.5.1.0

## Bedienung

Die eigene Enhanced-Seite im Escape-Spielmenü nutzt jetzt den großen nativen FS25-Inhaltsbereich. Links eine Kategorie wählen; rechts einzelne Regler oder die gesamte Kategorie fürs Live-Menü anzeigen bzw. ausblenden. Die Auswahl wird im Mod-Einstellungsordner gespeichert und verändert keine Grafikwerte. Pro Seite sind acht Regler mit Zustandsanzeige angeordnet.

Das Live-Fenster behält sein bisheriges Layout und seine feinen Regler. Unter **Automatik → Wirkungsradius** lässt sich der lokale Bereich von **5 bis 300 m** einstellen; Standard **80 m**. Es gelten die Position, Blickrichtung und das tatsächliche Sichtfeld der aktiven Kamera. LOD-, Objekt-, Pflanzen- und Terrain-Sichtweiten bleiben separat einstellbar.

Der Status-HUD zeigt weiterhin ausschließlich FPS und Frametime. Der Cursorzustand des F9-Dialogs wird jetzt vor GIANTS' eigener Cursoraktivierung gespeichert. Schließen und Übergang ins Live-Fenster stellen den vorherigen Zustand wieder her.

## Was der Wirkungsradius tatsächlich tut

- Lokale Lampen, ihre Schatten, IES und Streuung: nur ausgewählte Lichtquellen im Radius bzw. mit möglichem Einfluss auf das Kamerasichtfeld. Außerhalb werden geänderte Originalwerte und mod-eigene Schattenzusammenfassungen zurückgenommen; Prüfung ungefähr alle 250 ms.
- Fahrzeugmaterialien: aktuelle bzw. nahe Fahrzeuge und jedes kompatible Mesh werden geprüft. Beim Blick-/Bereichswechsel werden ursprüngliche Materialwerte wiederhergestellt, bei Wiedereintritt die gewünschten Werte erneut angewendet; maximal acht Fahrzeugkandidaten, Prüfung im Sekundentakt.
- Partikel: nur beobachtete, kompatible Emitter im sichtbaren Bereich. Faktoren werden in den äußeren 15 % des Radius und am Sichtfeldrand Richtung Original gemischt; Prüfung alle 250 ms. Keine zusätzlichen Schreibaufrufe auf bereits unveränderte Emitter.
- Vegetation: nur vorhandene Fahrzeug-/Anbaugeräte-Fußabdrücke; zusätzliche Biegezonen müssen in den Radius passen und werden nach einem Sicht-/Bereichswechsel entfernt. Vanilla-Zonen bleiben erhalten; Prüfung etwa alle 500 ms.
- Presets und Automatik verwenden die gleichen Grenzen. Gesperrte globale Optionen werden ausdrücklich übersprungen statt wiederholt erfolglos gesetzt.

**Objektauswahl, keine pixelgenaue Maske:** Ein großer Mesh, Lichtschein oder bereits ausgestoßener Partikel kann die Grenze überschreiten. Verdeckte Objekte hinter Wänden werden nicht durch eine eigene exakte Occlusion-Abfrage ausgeschlossen. Der Mod nimmt außerhalb ausgewählte Änderungen zurück; er schaltet keine Vanilla-Weltobjekte ab. Dies reduziert zusätzliche Modarbeit, garantiert aber keinen FPS-Gewinn und verschiebt kein nachgewiesenes globales GIANTS-GPU-Budget.

## Globale Grenzen und Regen

Die neue Vorgabe, außerhalb des Bereichs Vanilla zu behalten, hat Vorrang: Globale Bildhelligkeit, globale Schatten-/Reflexionsqualitäten, Rendereroptionen, Regenparameter und das gesamte Wassersimulations-Schaumverhalten sind im räumlichen Modus **mit Begründung gesperrt**. Die APIs besitzen keine frei wählbare Radiusmaske. Die fünf LOD-/Sichtweitenregler sind die ausdrücklich gewünschten Ausnahmen. Hinterkamera-Reduktion ist im sichtbaren Modus automatisch ersetzt und daher nicht separat wirksam.

Regen-Multiplikator: **Untergrenze 0,01**, zusätzlich im nativen Schreibpfad geschützt, einschließlich Rücknahme-/Fehlerpfaden. Der Radius-Modus sperrt diesen globalen Regler darüber hinaus. Natürliche Wetterübergänge des Spiels zu trockenem Wetter werden nicht überschrieben. Originale Regen-Assets liefern nun korrekte Wind-/Geschwindigkeits-Baselines; Turbulenz wird ohne belegte Frequenz nicht erfunden. Diese Adapter bleiben unter der strikten Radiusvorgabe gesperrt.

## Ursachen wirkungsloser Einstellungen

Korrigiert wurden der falsche Kameraschlüssel, unzuverlässige Priorität mehrfach referenzierter aktiver Lichtprofile, das Aussortieren matter Lacke mit Klarlackwert null und eine dauerhaft leere Materialsuche bei später geladenen Assets. SSR-Materialregler melden ausdrücklich, wenn SSR im Spiel ausgeschaltet ist. Lokale Lampen müssen eingeschaltet und geeignete Materialflächen im Bereich vorhanden sein. Physische Sonnen-/Exposure-Änderungen werden ohne belegte rücknehmbare API nicht vorgetäuscht.

## Prüfung

Automatisierte Prüfungen testen originale GIANTS-Menü-/Cursor-Lua-Methoden mit simulierten Enginegrenzen, Native-API-Argumente, Rücklesen/Rücknahme, den echten Kamera-/Frustumcode, Bereichs- und Blickwechsel, direkte Aufrufwege, Presets, Regen-Nullschutz, Layout, XML, SDK-Profile und 27 Sprachdateien. Einzelne Fälle und Ergebnisse stehen im Testbericht.

**Keine neue reale FS25-Sitzung durchgeführt.** Darstellung, tatsächliche Pixelwirkung, Mod-/Kartenkompatibilität und Performance müssen im Spiel bestätigt werden. Die früher dokumentierten offenen Asset-/PDF-Aufgaben sind damit nicht als vollständig erledigt freigegeben.

Nach Installation: Spiel neu starten. F9 öffnen/schließen und F9 → Live → Schließen prüfen. In der eigenen Spielmenüseite Regler abwählen, Live-Menü öffnen und die Auswahl kontrollieren. Dann nachts mit eingeschalteten Lampen bzw. vor einem geeigneten Fahrzeuglack kleine/große Radien und Blickwechsel vergleichen. Anschließend neue log.txt prüfen.

## Grundlagen

Abgeglichen mit lokal vorhandenen GIANTS-Skripten und dem installierten SDK sowie [TabbedMenu](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=43&class=491&version=engine), [BinaryOptionElement](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=43&class=420&version=engine), [MultiTextOptionElement](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=43&class=470&version=engine), [GIANTS I3D-Schema](https://i3d.giants.ch/schema/i3d-1.6.xsd) und [Regen-Turbulenzsignatur](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=21&function=593&version=engine). SDK: getCamera, getFovY (Radiant), worldToLocal, getHasClassId, Material- und Lichtsignaturen. Weitere Quellen: LIGHTING_MATERIAL_FIXES.md.
