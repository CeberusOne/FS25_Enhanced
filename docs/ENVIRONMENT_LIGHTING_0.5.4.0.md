# Umgebung: native Lichtsteuerung

17 ergänzende Bedienelemente sind in der Kategorie `environment` registriert. Die vorhandenen Sonnen-, Lampen- und Atmosphäre-Regler bleiben bestehen. Ohne ausdrückliche Benutzereingabe verändert der neue Provider keine Grafikwerte.

| Bereich | Regler | Wirkung und Grenze |
|---|---|---|
| Direktes Sonnenlicht | Helligkeit, Wärme, Farbstich | Gemeinsamer Zustand und nativer Schreibweg mit den drei bisherigen Sonnenreglern. Keine doppelte Anwendung. |
| Direktes Sonnenlicht | Rot, Grün, Blau | Drei zusätzliche Kanalmultiplikatoren im selben `GlobalLighting`-Writer. 1 ist neutral, 0–4 einstellbar. Native RGB-Werte werden rückgelesen. |
| Sonnenstreuung | Ein/Aus, Intensität | `get/setLightUseLightScattering` und `get/setLightScatteringIntensity` am dokumentierten Sonnenknoten. Intensität schaltet Streuung nicht selbst ein. |
| Sonnenschatten | Lichtquellengröße, virtuelle Lichtdistanz, Tiefenversatz-Faktor, Extrusionsdistanz | Vier getrennte native Eigenschaften mit Getter, Setter und Restore. Die virtuelle Lichtdistanz beeinflusst die Berechnung weicher Schatten; sie ist keine Sichtweite. |
| Sonnenstreufarbe | Wärme, Farbstich, Rot, Grün, Blau | `setLightScatteringColor` besitzt keinen veröffentlichten Getter. Der Provider beobachtet tatsächliche GIANTS-RGB-Aufrufe und arbeitet erst nach Erfassung einer vollständigen Originalfarbe. Status bleibt ausdrücklich „beobachtet“. |

Sonnenlicht und Streulicht sind keine globale Bildnachbearbeitung. Die Wirkung hängt unter anderem von aktivem Sonnenlicht, Wetter, Blickrichtung, Streuungsstatus und Schattenfilterung ab. Ein erfolgreicher Getter-/Setter-Test belegt den nativen Datenweg; er ersetzt keine Sichtprüfung im Spiel.

## Wiederherstellung und Zuständigkeit

Jede skalare Eigenschaft erhält unmittelbar vor ihrer ersten Änderung eine native Originalaufnahme. Nach einer GIANTS-Lichtaktualisierung werden nur ausdrücklich angeforderte Eigenschaften erneut angewendet. Neu vom Spiel gesetzte Ausgangswerte werden als aktuelle Wiederherstellungsbasis übernommen. Ein fehlender Sonnenknoten während eines Ladevorgangs führt zum Warten, nicht zur Quarantäne.

Die Umgebungs-Sonnenregler delegieren an `GlobalLighting`. Revisionsnummern je Kanal verhindern, dass ein später im bisherigen Sonnenmenü veränderter Wert vom Reset eines älteren Umgebungsreglers gelöscht wird. Das Zurücksetzen des Umgebungsproviders löscht keine unabhängigen Sonnen-Anforderungen. A/B-Vergleich wurde mit dem tatsächlichen `VisualProfiles`-Code für bestehenden Intensitätsregler plus neuen RGB-Regler geprüft.

Der Farbbeobachter wird in der Lua-Umgebung eines echten GIANTS-Skriptverfahrens installiert. Aufrufe anderer Lichtknoten werden unverändert weitergegeben. Ohne manuelle Farbanforderung wird auch die Sonnenfarbe unverändert weitergegeben. Neue native Farbgrundlagen werden jeweils einmal transformiert. Die letzte vollständig beobachtete Originalfarbe bleibt für Restore erhalten; mangels Getter kann eine native stille Ablehnung nicht ausgeschlossen werden. Fehler oder abgelehnte native Schreibversuche behalten keine neu abgelehnten Anforderungen. Scheitert auch ein Rollback, bleibt dessen Originalaufnahme für einen weiteren Wiederherstellungsversuch erhalten.

## Quellen und bewusst nicht angebotene Regler

- GIANTS `PlaceableSolarPanels.updateHeadRotation` belegt `g_currentMission.environment.lighting.sunLightId`: [FS25 GDN](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=78&class=763&version=engine).
- [Lichtstreuungsintensität](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=11&function=211&version=engine), [zugehöriger Getter](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=11&function=189&version=engine), [Streuung aktivieren](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=11&function=218&version=engine).
- [Weiche Schatten: Größe der Lichtquelle](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=11&function=217&version=engine). Das installierte GIANTS `sdk/debugger/scriptBinding.xml` bestätigt außerdem die Getter/Setter für SoftShadowDistance, SoftShadowDepthBiasFactor, ShadowExtrusionDistance und die RGB-Signatur von setLightScatteringColor.
- Installierte `data/maps/mapUS/config/environment.xml` und `colorGrading.xml` zeigen Auto-/FixedExposure, Bloom, ToneMapping und Farbkurven. Ihre Existenz als Map-Asset ist kein Nachweis einer rücklesbaren Live-Lua-Schnittstelle.

Ambient-RGB, freie Belichtungskurven, Sättigung/ColorGrading, Bloom und Nebeldichte werden nicht mit erfundenen Runtime-Funktionen angeboten. Die geprüften öffentlichen FS25-Quellen liefern dafür keinen belastbaren Live-Vertrag. Verfügbare diskrete Grafikqualitäten verbleiben bei ihren bisherigen Reglern. Alte `setFog`-Beispiele aus FS2009/Editor-Versionen werden nicht auf FS25 übertragen. `setShaderParameter` betrifft Shape-/Materialparameter; es ist kein Zugang zu einem vollständigen Postprocessing-Pass. Ein farbiges 2D-Overlay wäre kein entsprechender Shader und wurde nicht eingebaut.

ScatteringConeAngle und ScatteringDirection sind zwar als Getter/Setter veröffentlicht, aber ohne hinreichend dokumentierte Winkel-/Raumsemantik und sichtbare Bedeutung auf gerichteten Sonnenlichtern. Sie werden daher nicht als scheinbar wirksame Sonnenregler exponiert.

## Verifikation

`test_environment_lighting.lua` prüft 17 Regler gegen installierte SDK-Funktionsnamen, exakte skalare Native-Argumente, Readback, Ablehnung/Rollback, getrennte GIANTS-/Mod-Umgebungen, beobachtete Farbtupel, Teilreset, Alias-Zuständigkeit, A/B mit Original-VisualProfiles und kurzzeitigen Verlust des Sonnenknotens. Bestehende Sonnen- und Lampentests bleiben zusätzliche Regressionen. Sichtbare Darstellung und Leistungswirkung müssen im Spiel geprüft werden.
