# Globale Engine-Grafikeinstellungen (0.5.0.0)

Quellen, aus denen jede Einstellung stammt – alles im installierten Spiel nachprüfbar:

| Quelle | Pfad |
| --- | --- |
| Lua-Quelltext des Spiels | `sdk/debugger/gameSource.zip` → `dataS/scripts/gui/base/SettingsModel.lua` |
| Script-Binding-Referenz | `sdk/debugger/scriptBinding.xml` |
| Neue Funktionen ab FS25 1.0 | `sdk/scriptBindingChanges.txt` |
| Materialvorlagen | `data/shared/detailLibrary/materialTemplates.xml` |
| Fahrzeug-Shader | `data/shaders/vehicleShader.xml` |
| Schriftabdeckung | `shared/font/defaultFont.font` |

## 1. Regler, die GIANTS selbst auf der Grafikseite schreibt

Jede Zeile entspricht einem `SettingsModel:add…Setting`. Getter und Setter sind
globale Engine-Funktionen; der `CapabilityApplier` schreibt, liest zurück und
nimmt bei Abweichung sofort zurück.

| Regler-ID | Getter / Setter | SettingsModel |
| --- | --- | --- |
| `ssao-quality` | `getSSAOQuality` / `setSSAOQuality` | `addSSAOQualitySetting` |
| `cloud-shadows-quality` | `getCloudShadowsQuality` / `setCloudShadowsQuality` | `addCloudShadowsQualitySetting` (0/1) |
| `shadow-map-filter-size` | `getShadowMapFilterSize` / `setShadowMapFilterSize` | `addShadowMapFilteringSetting`, Index über `SettingsModel.getShadowMapFilterByIndex` |
| `volume-mesh-tessellation-coeff` | `getVolumeMeshTessellationCoeff` / `setVolumeMeshTessellationCoeff` | `addVolumeMeshTessellationSetting`, Bereich 0,5–2,0 |
| `tyre-tracks-segments-coeff` | `getTyreTracksSegmentsCoeff` / `setTyreTracksSegmentsCoeff` | `addMaxTireTracksSetting`, Bereich 0–4 |

`terrain-quality` ist bewusst **nicht** enthalten: GIANTS vermerkt im Quelltext
„restart needed to use correct shader cache“, und der `CapabilityApplier` lehnt
Einstellungen ohne Live-Pfad ab.

## 2. Engine-Qualitäts-Enums (`addEngineQualitySetting`)

Die Auswahl wird zur Laufzeit aus der globalen Enum-Tabelle gebildet, die
Beschriftung kommt aus `get<Name>Name`, und `getSupports<Name>` filtert auf das,
was die Hardware wirklich kann.

| Regler-ID | Enum | Hardware-Gate |
| --- | --- | --- |
| `atmosphere-quality` | `AtmosphereQuality` | `getSupportsAtmosphereQuality` |
| `ssr-quality` | `ScreenSpaceReflectionsQuality` | `getSupportsScreenSpaceReflectionsQuality` |
| `volumetric-fog-quality` | `VolumetricFogQuality` | `getSupportsVolumetricFogQuality` |
| `lensflare-quality` | `LensFlareQuality` | `getSupportsLensFlareQuality` |
| `screen-space-shadows-quality` | `ScreenSpaceShadowsQuality` | `getSupportsScreenSpaceShadowsQuality` |

**Bewusst nicht im Mod** (seit 0.5.7.0): MSAA, Post-Process-AA, DLSS, FSR 1/3,
XeSS, VALAR, Variable Rate Shading, DRS, Texturauflösung, Shader-Qualität und
Texturfilterung. Sie lösen Ressourcen- oder Shader-Neuladen aus, DRS lehnte nach
einem Upscaler-Wechsel jede Änderung ab (Log 19:57), und sie gehören ins
Hauptmenü des Spiels.

## 3. Neue Funktionen aus FS25 1.0

`sdk/scriptBindingChanges.txt` führt diese Funktionen unter „added“. Sie stehen
nicht in `scriptBinding.xml`, weil dort nur Szenengraph-Funktionen dokumentiert
sind – die globalen Einstellungsfunktionen (auch `setLODDistanceCoeff` oder
`setMSAA`) fehlen dort ebenso.

### Filmische Tonwertkurve

`get/setToneMappingCurve{Slope,Toe,Shoulder,BlackClip,WhiteClip}` – Kontrast,
Schattenbereich, Lichterabfall, Schwarz- und Weißpunkt der Bildkurve.
Regler-IDs `tone-mapping-slope`, `-toe`, `-shoulder`, `-black-clip`,
`-white-clip`.

### Spotschatten-Atlas

`get/setSpotShadow{AtlasSlotFactor,DistanceFrequencyFactor,FullResolutionPercentage,MinimumConeAnglePercentage,ReducedConeAngleFactor}`
– wie viele Lampen einen Schattenplatz bekommen, in welcher Auflösung und wie
oft entfernte Schatten neu berechnet werden.

Beide Gruppen haben Getter, laufen deshalb über denselben
Lesen-Schreiben-Zurücklesen-Pfad wie alles andere. Fehlt eine Funktion in einer
künftigen Spielversion, meldet der Regler „nicht verfügbar“, statt etwas zu
raten.

## 4. GameSettings statt Engine-Funktion

Sichtfeld, Spiegelanzahl und Lichtprofil liegen nicht in einer globalen
Funktion, sondern in `g_gameSettings` – genau dort schreibt sie auch die
Vanilla-Einstellungsseite. `scripts/Core/GameSettingsControls.lua` benutzt
`g_gameSettings:setValue`, wodurch Kameras und die Lights-Spezialisierung über
`MessageType.SETTING_CHANGED` sofort nachziehen.

| Regler-ID | GameSettings.SETTING |
| --- | --- |
| `fovVehicle` | `FOV_Y` |
| `fovFirstPerson` | `FOV_Y_PLAYER_FIRST_PERSON` |
| `fovThirdPerson` | `FOV_Y_PLAYER_THIRD_PERSON` |
| `maxMirrors` | `MAX_NUM_MIRRORS` |
| `lightsProfile` | `LIGHTS_PROFILE` |

Der Ursprungswert wird beim ersten Schreiben gemerkt und am Missionsende
zurückgeschrieben. Speichert das Spiel seine Einstellungen ab, während ein
geänderter Wert aktiv ist, steht dieser bis zur Rücknahme in `gameSettings.xml`.

## 5. Lackspiegelung

`vehicleShader.xml` liefert die Parameter, alle in der Gruppe `base` und damit
in jeder der 33 Shader-Variationen vorhanden:

| Parameter | Standard | Bedeutung laut Shader |
| --- | --- | --- |
| `clearCoatIntensity` | 0,0 | Stärke der Klarlackschicht |
| `clearCoatSmoothness` | 0,0 | Glätte der Klarlackschicht |
| `smoothnessScale` | 1,0 | Multiplikator auf die Grundglätte |
| `porosity` | 0,0 | verdunkelt diffus; 1,0 = Holz/Stoff/Schnee |
| `ssrParameters` | 0,25 / 0,1 / −0,19 | X Klarlackschwelle für SSR, Y Rauheits-Bias Grundschicht, Z Rauheits-Bias Klarlack |

Der „Schleier“ auf Standardlack entsteht aus zwei Voreinstellungen: `calibratedPaint`
hat `clearCoatIntensity` 0,1, liegt damit **unter** der SSR-Klarlackschwelle 0,25
und wird über die Grundschicht gespiegelt – und deren Rauheits-Bias ist mit
+0,1 bewusst ins Unschärfere verschoben.

Der Regler `paintReflectivity` (0–3, Standard 1) skaliert jedes Material aus
seinen **eigenen** Werten:

* `clearCoatIntensity` und `clearCoatSmoothness` werden mit dem Reglerwert multipliziert.
* Steigt der Wert, wird die SSR-Klarlackschwelle unter die neue Klarlackstärke gezogen, sodass die Spiegelung wirklich durch den Klarlack läuft.
* Die Rauheits-Biases werden Richtung „schärfer“ verschoben, gewichtet mit der ursprünglichen Klarlackstärke.

Dadurch wird Glanz- und Metallic-Lack zum echten Spiegel, während matter
Pulverlack (Klarlack 0) unverändert bleibt.

### Welche Materialien überhaupt in Frage kommen

`paintClassification` in `MaterialManager.lua` entscheidet in dieser Reihenfolge:

1. alphagemischt oder alphagetestet → `transparent`, nie anfassen
2. Variation enthält `glass`/`window` → `glass`
3. Variation enthält `reflector` → `reflector` (Rückstrahler brauchen ihre Kennlinie)
4. `porosity` > 0,25 → `porous` (Gummi 0,5, Holz/Stoff/Schmutz/Schnee 1,0)
5. **`clearCoatIntensity` > 0 → `coated`**, unabhängig vom Grundmaterial. Das ist die automatische Erkennung für lackierten Gummi oder Kunststoff.
6. Sonst: exakte Paarung aus `detailDiffuse` und `detailSpecular` gegen die Lackvorlagen aus `materialTemplates.xml` → `paint`
7. Alles andere → `unverified`, unverändert

`tools/smokeMaterials.lua` prüft diese Einstufung offline gegen dreizehn echte
Vorlagen, inklusive „lackierter Gummi“ und „Pulverlack matt“.

## 6. Nasse Umgebung

Belegte Parameter aus den Shadern des Spiels:

| Datei | Parameter | Standard | Wirkung |
| --- | --- | --- | --- |
| `placeableShader.xml` | `wetnessScale` | 1,0 | wie stark ein Platzierbares auf Nässe reagiert |
| `placeableShader.xml` | `wetShininess` | 0,2 | Glanz/Spiegelung im nassen Zustand |
| `buildingShader.xml` | `wetnessScale` | 1,0 | wie stark ein Gebäude auf Nässe reagiert |
| `oceanShader.xml` | `ssrRoughness` | 0,0 | Rauheit der SSR auf Wasserflächen |
| `puddleShader.xml` | Variation `surfaceWetnessOpacity` | – | Pfützen-Decals folgen der globalen Nässe |
| Engine | `setWetness(float)` / `getWetness()` | – | globale Nässe (Boden, Pfützen, Nassmasken) |

`FS25E_WetSurfaceManager`:

* `groundWetnessScale` multipliziert die Wetter-Nässe. Der Setter wird in der
  Stock-Lua-Umgebung gehakt; schreibt das Wetter nativ, greift die Abgleichung
  pro Frame über `getWetness()`, wobei ein Wert, der exakt dem zuletzt selbst
  geschriebenen entspricht, nicht als neuer Engine-Wert gilt.
* `groundWetnessHold` bremst nur die Abwärtsrichtung: nach dem Regen fällt die
  Nässe höchstens um 1,0 pro eingestellter Minutenzahl.
* `wetSurfaceShininess` / `wetSurfaceIntensity` skalieren die Shaderwerte relativ
  zum Autorenwert; `waterReflectionRoughness` ist absolut.
* Die Weltsuche läuft budgetiert (96 Knoten pro Frame) über den Szenengraphen,
  überspringt Fahrzeugwurzeln und erfasst nur die drei Shader oben. Bäume,
  Vegetation und Fahrzeuge werden hier nie angefasst.

`tools/smokeWetSurfaces.lua` prüft Suche, Skalierung, Abtrockenzeit und Rücknahme offline.

## 7. Offline-Tests

```bash
MOD_DIR="$PWD" lua tools/smokeControls.lua
MOD_DIR="$PWD" lua tools/smokeMaterials.lua
MOD_DIR="$PWD" lua tools/smokeWetSurfaces.lua
MOD_DIR="$PWD" lua tools/smokeVanillaGuard.lua
MOD_DIR="$PWD" lua tools/smokeBootstrap.lua   # kompletter Lade- und Missionslauf
MOD_DIR="$PWD" lua tools/exportCatalog.lua   # erneuert docs/CONTROL_CATALOG.json
```

`smokeControls` lädt den Regler-Stack gegen eine nachgebildete Engine und führt
für jeden Regler Lesen, Anwenden, Zurücklesen und Zurücknehmen aus.
`smokeMaterials` prüft Materialeinstufung, Spiegelungskette und Rücknahme.
Beide Tests ersetzen keine Prüfung im laufenden Spiel.
