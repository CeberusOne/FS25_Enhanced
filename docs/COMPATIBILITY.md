# Kompatibilität

Entwicklungsgrundlage: Windows-PC-Installation, GIANTS Engine 10 / FS25, modDesc 113. GDN-Skript-/Engine-Dokumentation v1.20.0.0 und lokal installiertes SDK wurden geprüft. Andere Plattformen, Karten und Modkombinationen sind nicht getestet.

Lichtadapter verwenden tatsächliche RealLight-Besitzer und aktive High/Low-Quellen. Vorhandene Mergegruppen, IES-Profile und fremde neuere Werte werden geschützt. Materialadapter verändern ausschließlich kompatible vehicleShader-Parameter in privaten Materialslots; fehlende Shaderverträge sperren die betroffenen Optionen. Getterlose Wetterfunktionen werden nur mit zuvor beobachteten Originalargumenten verwendet.

Die Kompatibilitätsprüfung erkennt fehlende APIs/Assets sowie wiederholte fremde Änderungen; die Automatik pausiert für das betroffene Feld. Geladene Mods werden aus g_modIsLoaded gelesen. Eine Namensliste allein gilt nicht als bewiesener Konflikt.

Noch erforderlich: Vanilla-Karten, Modmap, 4x-Karte, Modfahrzeuge, Kameramods, Custom Lighting, Multiplayer-Client und Dedicated Server in realen Sitzungen. Aktuell bestätigte reale Testkarten/Fahrzeuge für 0.5.0.0: keine. Keine plattformweite Kompatibilitätsgarantie.
