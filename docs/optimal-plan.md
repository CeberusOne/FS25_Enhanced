# FS25 Enhanced Mod — Optimaler Plan

> **Quellenbasis:** User-PDF `FS25_Enhaced` Umsetzungsplan + GDN Research Briefing (`fs25-gdn-giants-engine-research.md`) + verifizierte FS25 LuaDoc v1.20.0.0 (Script/Engine) offizielles eBook *Scripting Farming Simulator with Lua* (GDN downloadId=134) + Community-Report (`fs25-enhanced-community-optimizations.md`).  
> **Hinweis Schreibweise:** Projektname im Optimalplan **FS25_Enhanced** (Korrektur von „Enhaced“).

---

## Änderungen gegenüber deinem Plan (Executive)

1. **Intent beibehalten:** adaptiver Graphics-Governor mit Presets Performance/Balanced/Quality/Cinematic, Capability-Registry, Research Freeze, Restore/Fail-Safe, Lokalisierung, kein Binary-Hook.
2. **Architektur korrigiert:** kein „Rendergraph vor der Pipeline“, sondern **Client-seitiger Control-Layer**, der **dokumentierte Engine-/Settings-Setter** aufruft und Wirkung erst in **folgenden Frames** entfaltet.
3. **Einstiegsweg ergänzt:** `modDesc.xml` + `extraSourceFiles`, `g_currentModName`, Mission-Lifecycle (`loadMap`/`deleteMap`/Updateable), optional leichte **Vehicle-Specialization** für RealLights — nicht nur freie Manager-Lua-Dateien.
4. **API-Mapping verankert:** zentrale Quelle ist `SettingsModel` (GUI-Klasse) + Engine **Lighting / Rendering / Precipitation / Particle System / Foliage / ShallowWaterSimulation**.
5. **Shadow-/Light-Features priorisiert nach CONFIRMED APIs:** `mergeLightShadows`, `setLightShadowPriority`, IES/Scattering-Setter, `setShadowFocusBox`, `setFastShadowUpdate`.
6. **LOD/Foliage auf echte Coeff-Setter gemappt:** `setViewDistanceCoeff`, `setLODDistanceCoeff`, `setFoliageViewDistanceCoeff`, `setFoliageLODDistanceCoeff`, `setTerrainLODDistanceCoeff`.
7. **Weather auf Precipitation-API gemappt:** `setRain*` (u. a. Density, Turbulence, Wind, Bounce) — nicht erfundene Rain-Simulator-Objekte.
8. **Scope diszipliniert:** v1 = Core + Shadows/Lighting + LOD/Foliage + Settings-GUI; Water/Materials/Reflections bleiben EXPERIMENTAL und blockieren 1.0 nicht.
9. **Multiplayer explizit:** Grafik-Governor ist **client-lokal**; keine Network-`Event`-Sync für Qualitätswerte (außer optional UI-Presets in Savegame).
10. **Tooling:** VS Code *Farming Simulator IDE Support* (Studio discontinued), `Logging.*`, `descVersion` laut aktueller ModHub-Guideline.
11. **Lokalisierung gestaffelt:** Key-Architektur sofort; Vollübersetzung aller FS25-Sprachen nicht als Gate für Alpha.
12. **Performance Class respektieren:** nicht gegen `applyPerformanceClass` / `saveHardwareScalability` kämpfen; Originalwerte cachen und bei Restore/Disable zurücksetzen.

---

## Kurzfazit (was du vom User-Plan übernommen / geändert hast)

### Übernommen (unverändert in der Absicht)
- Ziel: intelligenter nutzen, was die GIANTS Engine 10 öffentlich erlaubt — nicht DLL/DX-Hooks.
- Vier Presets + Manual/Auto, Target-FPS-Schutz, Hysterese, Budget-Allokation, Scene Analyzer.
- Capability-Registry mit Status CONFIRMED / GATED / EXPERIMENTAL / ASSET_DEPENDENT / UNSUPPORTED / REJECTED.
- Research Freeze vor Feature-Bau.
- Restore-System, Fail-Safe pro Modul, Compatibility Manager, Benchmark-Gates.
- Enhanced Shadows (Priority, Merge, Soft, Focus experimentell), Lighting (IES, Scattering, Culling), adaptive LOD/Foliage/Particles/Weather.
- Separate Advanced- und Live-Tuning-GUI, Lock-System, Kostenanzeigen.
- Phasierung: Core zuerst, experimentelle Water/Materials/Reflections nach 1.0.

### Geändert / geschärft
- **Technisches Modell:** „Setter- und Capability-Layer“ statt imaginärer Pre-Render-Injection.
- **FS25-Patterns:** Specializations/`SpecializationUtil` nur dort, wo Fahrzeug-/Placeable-Lichtzustände nötig sind; Governor selbst als Mission-Updateable.
- **API-Wahrheitspflicht:** Jede Capability braucht exakten GDN-Funktionsnamen + Getter/Setter aus LuaDoc/SettingsModel-Source — sonst EXPERIMENTAL/UNSUPPORTED.
- **GUI-Anbindung** an bestehendes Settings-Ökosystem (`SettingsModel`, `g_gameSettings`, `g_i18n`) statt parallelem „Freestyle“ ohne Schema.
- **FPS-Messung** über `update(dt)`-Statistik (Frame-Time), nicht über undokumentierte `getFps`-Annahmen; Debug weiter über F2/`showFps`.
- **Namen & Struktur:** `FS25_Enhanced`, schlankere Ordner für v0.x, Docs/Tools bleiben.

---

## Abgleich mit GDN (korrekt / problematisch / fehlt)

### Korrekt (User-Intent deckt sich mit offiziellen Fähigkeiten)

| User-Thema | GDN-/LuaDoc-Anker | Status |
|------------|-------------------|--------|
| Regulärer Lua/XML-Mod, keine Binary-Hooks | eBook modDesc/`extraSourceFiles`; VS Code IDE | Verified |
| Per-Light Shadow Priority | Engine Lighting: `setLightShadowPriority` / `getLightShadowPriority` | CONFIRMED |
| Shadow Merge | `mergeLightShadows`, `setMergedShadow*`, `hasMergedShadow`, `splitLightShadow` | CONFIRMED |
| Soft Shadows / Bias / Size / Distance | `setLightSoftShadow*`, `getLightSoftShadow*` | CONFIRMED |
| Shadow Ignore / Self-Shadow | `addLightShadowIgnoreShapes`, `clearLightShadowIgnoreShapes` | CONFIRMED |
| Shadow Focus (experimentell) | Rendering: `setShadowFocusBox(shapeId)` | CONFIRMED API, EXPERIMENTAL Nutzung |
| Fast Shadow Update (experimentell) | Rendering: `setFastShadowUpdate(cameraId, fastUpdate)` | CONFIRMED API, EXPERIMENTAL Nutzung |
| IES | `setLightIESProfile` / `getLightIESProfile` / `getLightConeAngleFromIESProfile` | CONFIRMED (ASSET_DEPENDENT) |
| Light Range / Drop-Off / Cone | `setLightRange`, `setLightDropOff`, `setLightConeAngle` | CONFIRMED |
| Light Scattering | `setLightUseLightScattering`, `setLightScatteringIntensity`, Color/Cone/Direction | CONFIRMED |
| Light Culling World Props | `setLightCullingWorldProperties` | CONFIRMED (Verhalten testen) |
| Global Shadow Quality / Max Lights | via SettingsModel → `setShadowQuality`, `setMaxNumShadowLights`, `setShadowDistanceQuality`, `setShadowFilterQuality` | CONFIRMED (indirekt dokumentiert in SettingsModel-Source) |
| Object/LOD/Foliage/Terrain Distances | `setViewDistanceCoeff`, `setLODDistanceCoeff`, `setFoliageViewDistanceCoeff`, `setFoliageLODDistanceCoeff`, `setTerrainLODDistanceCoeff` | CONFIRMED |
| Foliage Shadows | `setAllowFoliageShadows` / `getAllowFoliageShadows` | CONFIRMED |
| Foliage Bending (Interaktion) | `createFoliageBendingRectangle`, `setFoliageBendingRectangleAttributes`, Spec `FoliageBending` | CONFIRMED / ASSET_DEPENDENT |
| Rain Tuning | Precipitation: `setRainAmountMultiplier`, `setRainActiveDropsMultiplier`, `setRainTurbulenceParameters`, `setRainWindForce`, Bounce/Spawn/… | CONFIRMED |
| Particles | Particle System: `setEmitCountScale`, `setMaxNumOfParticles`, Speed/Lifespan/… | CONFIRMED (Instanz-IDs nötig) |
| Shallow Water / Puddles | Engine ShallowWaterSimulation (`createShallowWaterSimulation`, Paint/Update/…) | CONFIRMED API, EXPERIMENTAL Feature |
| Material Wetness / Custom Params | `setWetness`/`getWetness`, `getMaterial*`/`setMaterialCustomParameter`, `setMaterialCustomShaderVariation` | ASSET_DEPENDENT |
| SSR Quality | `setScreenSpaceReflectionsQuality` (SettingsModel/`ScreenSpaceReflectionsQuality`) | CONFIRMED global; keine universelle Planar-Mirror-API |
| Vehicle RealLights | Specialization `Lights` (`spec_lights.realLights.low/high`, `getRealLightFromNode`, `onLightsProfileChanged`) | CONFIRMED |
| Placeable Lights | Spec `PlaceableLights` | CONFIRMED (Details Research Freeze) |
| Settings Persistenz | `g_gameSettings`, `SettingsModel:saveChanges` → `saveHardwareScalability()` | CONFIRMED |
| Logging | `Logging.error/warning/info/fatal` (+ xml/i3d Varianten) | CONFIRMED |
| Utils-Hooks | `Utils.prependedFunction` / `appendedFunction` / `overwrittenFunction` | CONFIRMED |
| Dev-Controls / FPS-Anzeige | `documentation_overview.php`: F2, `showFps` | Verified |

### Problematisch / überzogen im User-Plan

| Annahme | Problem | Korrektur |
|---------|---------|-----------|
| „Entscheidet … bevor die Renderpipeline arbeitet“ | Lua-Mods injizieren keinen Rendergraph | Formulieren als: Setter ändern Engine-Zustand; Wirkung ab nächsten Frames |
| Per-Distanz Shadow-Resolution-Tiers als gesicherte Engine-Feature | `setLightShadowMap` existiert; exakte Auflösungs-Semantik/Live-Kosten **müssen Research Freeze beweisen** | Capability EXPERIMENTAL bis gemessen |
| „Outdoor Shadow Focus = eigene Cascade“ | API ist Focus-**Box**, keine Cascade-API in LuaDoc | Weiterhin experimentell, nie als Cascade vermarkten (User hatte das schon richtig eingeschränkt) |
| Vollständiger eigener Deferred/GBuffer/Temporal/RT | bewusst ausgeschlossen — gut; trotzdem droht Feature-Creep über Materials/Reflections | Strikte EXPERIMENTAL-Gates behalten |
| 27 Sprachen vor Feature-Stabilität | blockiert Alpha unnötig | Key-Framework sofort; Übersetzungen gestaffelt |
| Selbstlernendes Kostenmodell früh | ohne stabile Metrik/Capability-Matrix wertlos | erst nach Kalibrierungs-Baseline |
| Fehlende MP-/Client-Klarheit | Settings/Lights Profile sind teils global, Governor-Logik lokal | Client-only Governor dokumentieren |
| Kein modDesc-/IDE-Pfad | ohne `extraSourceFiles` und VS Code Schema bricht der Einstieg | siehe Architektur |
| „GIANTS Engine Runtime API“ pauschal | viele Setter sind **nicht** als eigene Engine-TOC-Seite, sondern über **SettingsModel-Source** sichtbar | Capability speichert **beides**: Engine-Name + SettingsModel-Writer |

### Fehlt im User-Plan (kritische Lücken)

1. **`modDesc.xml`-Vertrag:** `descVersion` (ModHub-Guideline), `multiplayer`, `extraSourceFiles`, `l10n`, Icon, Actions.
2. **Mission-Lifecycle:** Registrierung als Updateable / `loadMap`/`deleteMap`, Restore bei Mission-Ende.
3. **`SettingsModel` als Canonical Map** aller Quality-Getter/Setter inkl. Restart-Flags (`needsRestartToApplyChanges`).
4. **Respekt vor Performance Class:** `applyPerformanceClass`, `getPerformanceClass`, `Utils.getPerformanceClassIndex`.
5. **Lights-Specialization-Integration** statt Blind-Scannen aller Nodes.
6. **MessageCenter:** `MessageType.SETTING_CHANGED[...]`, `DAY_NIGHT_CHANGED` (wie `Lights` selbst).
7. **GUI-Technik:** `Gui`/`ScreenElement`/`InGameMenu`-Erweiterungsmuster, XML-Schemas via VS Code.
8. **Explizite Client-Only-Policy** und Savegame-Schema für Mod-Presets (nicht Hardware-Scalability überschreiben, sofern User nicht „persist“ wählt).
9. **Capability-Matrix-Datei** als Build-Artefakt (`config/capabilityProfiles.xml` an echte Funktionsnamen binden).
10. **Test gegen `Platform.isConsole`:** viele Quality-Settings nur Desktop (`addManagedSettings`-Guard).

---

## Ziel & Scope

### Ziel
**FS25_Enhanced** ist ein **client-seitiger, adaptiver Grafik- und Optimierungs-Mod** für Farming Simulator 25 (Giants Engine 10 / LuaDoc Script+Engine **v1.20.0.0**). Er steuert ausschließlich **öffentlich belegte** Engine- und Settings-APIs, priorisiert sichtbaren Near-Field-Nutzen und schützt Target-Frame-Time.

### In Scope (Gen 1 / bis v1.0)
- Capability Registry + Research Freeze
- Core Runtime (Mission, Kamera, Environment, Fahrzeuge, Wetterflags)
- Performance Monitor (dt-basiert) + Scene Analyzer + Graphics Governor
- Enhanced Shadows & Lighting (CONFIRMED APIs)
- LOD / Object / Foliage / Terrain Distance Governor
- Rain/Particle Budgets (soweit Instanzen auffindbar)
- Settings-/Live-Tuning-GUI (Grundumfang) + Lokalisierungs-Framework
- Restore / Fail-Safe / Compatibility Gates
- Presets Performance / Balanced / Quality / Cinematic

### Explizit Out of Scope (Gen 1)
- DLL, Memory Patch, DX12/Vulkan, Rendergraph-, GBuffer-, Temporal-, Raytracing-Hooks
- Eigene Deferred-Pipeline
- Universelle planare Spiegel / beliebige Material-Overrides ohne Asset-Nachweis
- Globale Karten-weite Shallow-Water-Simulation
- Server-authoritative Sync der Grafikparameter

### Success Criteria
- Jede Stable-Capability hat GDN-URL oder Klassen-/Funktionsnamen + Getter/Setter + Live/Reload/Restart-Flag.
- Disable/Unload stellt Vanilla-Zustand wieder her (gemessen).
- Kein `Logging.fatal`/Crash bei fehlenden Light-/Particle-Nodes.
- Alpha lauffähig mit nur EN+DE-Texten.

---

## Architektur (Mod-Struktur, Specializations, Events, modDesc)

### Empfohlenes Laufzeitmodell

```
modDesc.xml (extraSourceFiles)
  └─ scripts/FS25_Enhanced.lua          -- Bootstrap, g_currentModName capture
       ├─ register Mission hooks (loadMap/deleteMap/update)
       ├─ CapabilityRegistry.load(config)
       ├─ SettingsCache + RestoreManager
       ├─ GraphicsGovernor (Fast/Medium/Slow controller)
       ├─ Module managers (Shadows, Lighting, World, Weather, …)
       ├─ optional: Vehicle Spec EnhancedLightsProbe (read-only / soft apply)
       └─ UI: EnhancedSettingsFrame + LiveTuning (Gui XML)
```

**Wichtig:** Der Governor ist **kein** Vehicle-Type-Ersatz. Er ist ein **Mission-Level-Service**. Vehicle-/Placeable-Specs dienen der **sicheren Enumeration** von RealLights (`Lights` / `PlaceableLights`), nicht dem Ersetzen der Renderpipeline.

### modDesc.xml (Minimalvertrag)

```xml
<?xml version="1.0" encoding="utf-8" standalone="no"?>
<modDesc descVersion="TODO_FROM_MODHUB_GUIDELINE">
    <author>...</author>
    <version>0.1.0.0</version>
    <multiplayer supported="true"/>
    <title><en>FS25 Enhanced</en><de>FS25 Enhanced</de></title>
    <description>...</description>
    <iconFilename>icon.png</iconFilename>
    <extraSourceFiles>
        <sourceFile filename="scripts/FS25_Enhanced.lua"/>
        <!-- weitere SourceFiles oder Specialization-Dateien -->
    </extraSourceFiles>
    <!-- optional: <specializations> falls Vehicle-Spec genutzt wird -->
    <!-- <l10n> / l10n_*.xml nach ModHub-/Schema-Konvention -->
    <!-- <actions> für Live-Tuning Hotkey -->
</modDesc>
```

- `descVersion`: **nicht** eBook-`72` blind übernehmen — aktuelle **ModHub Creation Guidelines** (GDN downloadId=124) lesen.
- Multiplayer `supported="true"`: Mod darf auf MP-Clients laufen; Governor bleibt lokal.

### Dateistruktur (optimiert, v0.x-schlank)

```
FS25_Enhanced/
├── modDesc.xml
├── icon.png
├── scripts/
│   ├── FS25_Enhanced.lua
│   ├── Core/
│   │   ├── CapabilityRegistry.lua
│   │   ├── SettingsCache.lua
│   │   ├── RestoreManager.lua
│   │   ├── PerformanceMonitor.lua
│   │   ├── SceneAnalyzer.lua
│   │   ├── GraphicsGovernor.lua
│   │   ├── BudgetAllocator.lua
│   │   ├── CompatibilityManager.lua
│   │   ├── ProfileManager.lua
│   │   ├── CalibrationManager.lua
│   │   └── Debug.lua
│   ├── Shadows/   ShadowManager.lua, ShadowMergeManager.lua, ShadowFocusManager.lua
│   ├── Lighting/  LightingManager.lua, IESManager.lua, ScatteringManager.lua, LightCullingManager.lua
│   ├── World/     LodGovernor.lua, FoliageManager.lua
│   ├── Weather/   RainManager.lua, ParticleBudgetManager.lua
│   ├── Experimental/  Water/, Materials/, Reflections/   (nicht in Stable-Presets)
│   ├── Specializations/  EnhancedLightsProbe.lua   (optional)
│   └── UI/
├── gui/
├── config/   defaults.xml, presets.xml, capabilityProfiles.xml, costModel.xml
├── l10n/
├── docs/
└── tools/
```

User-Ordner Atmosphere/Materials/Water dürfen existieren, aber **Experimental-Branch-Policy** gilt.

### Specializations (wo sinnvoll)

| Spec | Zweck | Pattern |
|------|-------|---------|
| `EnhancedLightsProbe` (optional) | RealLight-Nodes aus `spec_lights` sammeln, Soft-Apply von Priority/IES/Scattering, Restore onDelete | `prerequisitesPresent` → `SpecializationUtil.hasSpecialization(Lights, …)`; `registerEventListeners`: `onLoad`, `onDelete`, `onUpdateTick` (selten); Spec-Table `spec_<modName>.enhancedLightsProbe` |
| Placeable-Äquivalent | PlaceableLights entdecken | analog Placeable-Spec |

**Injection in alle Lights-Fahrzeuge** (eBook-Mileage-Pattern):

```lua
local modName = g_currentModName
TypeManager.finalizeTypes = Utils.prependedFunction(TypeManager.finalizeTypes, function(self)
    if self.typeName == "vehicle" then
        for typeName, typeEntry in pairs(self:getTypes()) do
            if typeEntry.specializationsByName["lights"] ~= nil then
                self:addSpecialization(typeName, modName .. ".enhancedLightsProbe")
            end
        end
    end
end)
```

Quellen: eBook Mileage Counter; LuaDoc `TypeManager`, `SpecializationUtil`, Spec `Lights`.

### Events / Networking

| Art | Verwendung in diesem Mod |
|-----|--------------------------|
| Specialization events (`onLoad`, `onUpdateTick`, …) | Lights-Probe |
| Network `Event` (`readStream`/`writeStream`/`run`) | **nicht** für Grafikqualität; optional später nur für Shared-Preset-Codes falls gewünscht |
| `g_messageCenter` | `SETTING_CHANGED` (Lights Profile, Performance), `DAY_NIGHT_CHANGED` |

### Settings & Persistenz

1. **Vanilla Hardware Scalability** nur anfassen, wenn Capability `applyMode` es erlaubt und User „Persist“ aktiviert — sonst Session-Cache + Restore.
2. Mod-eigene Presets/Locks in **Mod-Savegame/XML** unter Mod-Directory (nicht stillschweigend `gameSettings` überschreiben).
3. Writer immer denselben Pfad wie `SettingsModel` nutzen (gleiche Engine-Funktion), damit Restore und Vanilla-Menü konsistent bleiben.

### Tooling

- **VS Code Farming Simulator IDE Support** — https://gdn.giants-software.com/vscode.php  
- `game.xml` → `<development><controls>true</controls></development>`  
- Hot-Reload / Log Viewer laut VS Code Docs  
- `Logging.info` mit Prefix `[FS25_Enhanced]`

---

## Features (priorisiert, mit technischem Ansatz laut FS25)

Priorität: **P0** muss vor Alpha, **P1** für 1.0, **P2** post-1.0 / Experimental.

### P0 — Foundation

| Feature | Technischer Ansatz | GDN-Anker |
|---------|--------------------|-----------|
| Bootstrap + Lifecycle | `extraSourceFiles`, Mission load/delete, Updateable `update(dt)` | eBook; `g_currentMission` (LuaDoc source) |
| Capability Registry | XML → Runtime table; Status-Enum; Getter/Setter closures | SettingsModel writers + Engine Lighting/Rendering/… |
| Settings Cache / Restore | original/current/requested/auto/locked; ApplyMode LIVE / RESTART | SettingsModel `needsRestartToApplyChanges` |
| Performance Monitor | gleitende Frame-Time aus `dt`; Spikes/Varianz; Target-Budget | Messung in Lua; Debug F2/`showFps` |
| Scene Analyzer | Kamera/Player/Vehicle aus Mission; `environment` (Hour, Sun, Weather); Fog/Rain Flags | `g_currentMission.environment` (Lights-Source) |
| Governor + Hysterese | Fast/Medium/Slow wie User-Plan; Locks respektieren | eigene Logik auf CONFIRMED Settern |
| Fail-Safe | pcall-Modulgrenzen; Capability → REJECTED bei Fehler | `Logging.warning` |

### P1 — Shadows & Lighting (High Value)

| Feature | Ansatz | APIs |
|---------|--------|------|
| Shadow Priority Budget | Importance-Score → `setLightShadowPriority` | Lighting |
| Shadow Map on/off | `setLightShadowMap` / `getLightCastingShadowMap` | Lighting |
| Max Shadow Lights global | `setMaxNumShadowLights` | SettingsModel |
| Shadow Quality / Distance / Soft (global) | `setShadowQuality`, `setShadowDistanceQuality`, `setShadowFilterQuality` | SettingsModel |
| Shadow Merge | ähnliche Scheinwerfer-Gruppen → `mergeLightShadows` / `setMergedShadowSettings*` / `splitLightShadow` on restore | Lighting |
| Soft per light | `setLightSoftShadowSize/Distance/DepthBiasFactor` | Lighting |
| Ignore shapes | `addLightShadowIgnoreShapes` vorsichtig, dokumentiert | Lighting |
| Shadow Focus | Kamera-/Fahrzeug-Box → `setShadowFocusBox` | Rendering — EXPERIMENTAL |
| Fast Shadow Update | aktive Kamera → `setFastShadowUpdate` | Rendering — EXPERIMENTAL |
| IES Manager | nur Lights mit Profil / Asset; Cap „Max Active IES“ | `setLightIESProfile` |
| Scattering Manager | Wetter/Nebel/Importance → Intensity + Use-Flag | `setLightUseLightScattering`, `setLightScattering*` |
| Light Range/DropOff/Cone | Near vs Far Softening | `setLightRange`, `setLightDropOff`, `setLightConeAngle` |
| Culling | `setLightCullingWorldProperties` + Deaktivieren entfernter Scattering/IES | Lighting |
| RealLight Discovery | Spec `Lights` low/high profiles; respektiere `LIGHTS_PROFILE` / `getUseHighProfile` | Spec Lights, `g_gameSettings` |

### P1 — World Distances

| Feature | APIs |
|---------|------|
| Object Draw Distance | `get/setViewDistanceCoeff` |
| LOD Distance | `get/setLODDistanceCoeff` |
| Foliage Draw / LOD | `get/setFoliageViewDistanceCoeff`, `get/setFoliageLODDistanceCoeff` |
| Terrain LOD | `get/setTerrainLODDistanceCoeff` |
| Foliage Shadows | `setAllowFoliageShadows` |

Szeneabhängige Budgets (Nebel → Far runter, Near Lights hoch) bleiben wie im User-Plan — aber nur über diese Coeffs + Light-Module.

### P1 — Weather / Particles (Alpha spät / 0.9)

| Feature | APIs |
|---------|------|
| Rain Density / Max Drops | `setRainAmountMultiplier`, `setRainActiveDropsMultiplier`, `setRainMaxDropsMultiplier` |
| Turbulence / Wind / Camera Velocity | `setRainTurbulenceParameters`, `setRainWindForce`, `setRainCameraVelocityMultiplier` |
| Bounce | `setRainMaxBounces`, `setRainBounceRandomFactor`, `setRainBounceRestitution` |
| Weather Type | `setRainWeatherType` + Enum `RainSimWeatherType` |
| Particle Budgets | Emitter-IDs finden (WorkParticles etc.), dann `setEmitCountScale` / `setMaxNumOfParticles` |

### P1 — UI / UX

| Feature | Ansatz |
|---------|--------|
| Simple Auto Panel | On/Off, Mode, Target FPS, Adaptive On/Off |
| Advanced Tabs | Shadows/Lighting/LOD/… — nur CONFIRMED Caps |
| Live Tuning | Hotkey Action; LIVE-ApplyMode Caps; Lock/Auto-Anzeige |
| L10N | Keys `FS25E_*`; `g_i18n:getText`; Vanilla `setting_*` / `ui_*` wiederverwenden |
| Warnungen | lokalisierte Tooltips für EXTREME Cost |

GUI-Klassen-Referenz: LuaDoc Script GUI (`SettingsModel` class 486, `InGameMenu`, `ScreenElement`, …). Konkretes Hooking der Settings-Frames im Research Freeze gegen aktuelle FS25-GUI-Struktur verifizieren (Utils.overwrittenFunction / Frame-Load).

### P2 — Experimental (nicht 1.0-blocking)

| Feature | APIs / Hinweis |
|---------|----------------|
| Shallow Water / Puddles lokal | `createShallowWaterSimulation`, Paint/Update, `setRainShallowWaterSimulation` — Radius begrenzt, Restore zwingend |
| Materials | nur nach `getMaterialCustomShaderFilename` / Variation-Checks; `setMaterialCustomParameter`, `setWetness` |
| Reflections | global SSR Quality; Mirror Budget nur wenn `maxNumMirrors`-Pfad verstanden; keine „überall Spiegel“-Claims |
| Atmosphere Quality | `setAtmosphereQuality` / `VolumetricFogQuality` — Restart/Support-Flags beachten (`getSupports*`) |
| Foliage Interaction Extra | `createFoliageBendingRectangle` — Konflikt mit Spec `FoliageBending` prüfen |
| DRS als letzte Reduktionsstufe | `setDRSQuality` / Target-FPS Settings — nur mit Support-Check |

### Visual Value / Budget (Logik behalten, Daten eichen)

User-Formeln (Importance, VisualValue, Reduction/Increase Order) bleiben. Jeder Schritt darf **nur** Caps mit Status ≥ CONFIRMED (oder bewusst EXPERIMENTAL im Cinematic-Modus) anfassen.

---

## Umsetzungsphasen

### Phase 0 — Research Freeze (1–2 Iterationen, Gate)
1. Capability-Tabelle aus SettingsModel-Writern + Engine Lighting/Rendering/Precipitation/Particle/Foliage/SWS befüllen.
2. Pro Funktion: Signatur, Live?, Restart?, Support-Check, Nebenwirkungen, Teststatus.
3. Lights-/RealLight-Datenmodell aus Spec `Lights` dokumentieren.
4. Output: `docs/RESEARCH.md` + `config/capabilityProfiles.xml` (nur Belegtes).

### Phase 1 — v0.1 Poc Core
- Bootstrap, Logging, Update-Loop, PerformanceMonitor, SettingsCache, Restore, leeres Governor-Gerüst.
- **Gate:** Mission starten/beenden ohne Leaks; Restore no-op sicher.

### Phase 2 — v0.2 Governor + Scene
- SceneAnalyzer + Hysterese + Presets-Stubs.
- **Gate:** dt-Statistik stabil; keine Engine-Writes außer Debug.

### Phase 3 — v0.3 Shadows Alpha
- Priority, MaxLights, ShadowMap toggles, Merge (mit Split-Restore), Soft tuning.
- Focus/FastUpdate hinter Experimental-Flag.
- **Gate:** Farmyard Night Visuell + Performance; Restore 100%.

### Phase 4 — v0.4 Lighting Alpha
- IES/Scattering/Culling/Range; Lights-Probe Spec.
- Respektiere `GameSettings.SETTING.LIGHTS_PROFILE`.
- **Gate:** keine Broken Lights bei Profilwechsel (`onLightsProfileChanged`).

### Phase 5 — v0.5 LOD/Foliage
- Coeff-Governor szenenabhängig.
- **Gate:** Fog/OpenField Vergleich Vanilla vs Enhanced.

### Phase 6 — v0.6 GUI + L10N Framework
- Simple + Advanced Menü; EN+DE vollständig; Key-Validator.
- **Gate:** keine Hardcoded UI-Strings.

### Phase 7 — v0.7 Live Tuning + Locks
- Hotkey, Slider-Metadaten, Lock vs Auto.

### Phase 8 — v0.8 Calibration + Cost Model
- Erstkalibrierung; statistisches Kostenmodell (kein ML).

### Phase 9 — v0.9 Weather/Particles Beta
- Rain-Setter + Particle Budgets.

### Phase 10 — v1.0 Stable
- Nur CONFIRMED Caps in Stable Presets; Compatibility/Benchmark Docs; Experimental klar getrennt.

### Post-1.0
- Water, Materials, Reflections, erweiterte Sprachen, Cinematic Screenshot Mode.

---

## Risiken & offene Punkte

| Risiko | Mitigation |
|--------|------------|
| Undokumentierte Seiteneffekte von Live-Quality-Settern | Research Freeze + ApplyMode; nie blind in Fast-Controller |
| Konflikt mit Vanilla Performance Class / Upscalern (DLSS/FSR/XeSS) | SettingsModel OnChange-Logik nachbauen; DRS/Upscaler nur Slow-Controller |
| Shadow Merge zerlegt Fahrzeug-Licht-Setups | nur gruppieren wenn Nodes/Typen passen; immer `splitLightShadow` in Restore |
| IES ohne Asset → hässliche/fehlende Lights | ASSET_DEPENDENT; Fallback ohne IES |
| Shallow Water CPU/GPU Spikes | Experimental, kleiner Radius, Cap auf Cinematic |
| Material-Overrides brechen Mod-Fahrzeuge | Capability Rejection bei fremdem Shader |
| MP-Verwechslung (Host ändert „Welt“) | Client-only Policy in UI/Docs |
| Console/Platform | `Platform.isConsole`-Guards wie SettingsModel |
| `descVersion` / ModHub Reject | Guidelines PDF vor Release |
| Überambitionierte Manager-Anzahl | P0/P1 zuerst; Dateien für P2 dürfen leer/experimental bleiben |
| FPS-Metrik ungenau bei Unlimited Frame Limit | Target + Limiter-Hinweise; gleitende Fenster |
| Rechtliche/ToS: aggressive Engine-Nutzung | nur öffentliche APIs; keine Memory-Hooks (bereits im User-Plan) |

### Offene Research-Fragen (vor Implementierung klären)
1. Exakte Semantik von `setLightShadowMap` (Auflösung vs Bool/Enum)?
2. Sicheres Enumerieren aller aktiven Light-entityIds ohne Spec (Fallback)?
3. Welcher FS25-GUI-Hook ist für Custom-Settings-Frame am robustesten?
4. Persistenzort für Mod-Presets ohne `saveHardwareScalability` Nebenwirkungen?
5. Aktuelle ModHub `descVersion` für FS25?

---

---

## Community-Optimierungen (GitHub / Foren / Reddit) — integriert

Quellen-Report: `fs25-enhanced-community-optimizations.md` (Courseplay, UniversalAutoload, SoilFertilizer, AutoVRAM, UsedPlus-Pitfalls, EnhancedVehicle, GDN-Forum, Performance-Guides).

### Übernommen in den Optimalplan (HIGH)

| Add-on | Umsetzung im Plan |
|--------|-------------------|
| Hook-/Restore-Lifecycle-Manager | Jede `Utils.*Function`-Injection + jeder Runtime-Setter mit Original + Cleanup bei `deleteMap`/Unload |
| Persistenz-Trennung | Client-Grafik in `modSettings/FS25_Enhanced/`; optionale Farm-Presets nur im Savegame |
| Capability-Gates + Clamp + `pcall` | Setter nur wenn Funktion existiert; Fehler → Capability `REJECTED` + Restore |
| MP client-lokal | Keine Governor-Sync; Events nur für optionale geteilte Presets |
| Schema-Settings + Giants-GUI | SettingsSchema → XML/UI/Console; `MessageDialog` / MultiTextOption; lazy `g_gui:loadGui` — **keine Slider** |
| Timer-/Hysterese-Monitor | Fast/Med/Slow; keine schwere Analyse jedes Frame |

### MED (in Gen 1 einplanen)

- Mission-Layer statt Vehicle-Spec für globale Grafik; Spec nur für echte Light-Probes
- Hotkeys + ActionEvents + MP-Key-Konflikt-Check
- Prefixed Logging `[FS25_Enhanced][...]`, Console Dump/Restore, Debug-Overlay nur bei Flag
- i18n-First (`FS25E_*`), Vanilla-Texte wiederverwenden
- CompatibilityManager soft-detect (`g_modIsLoaded` / bekannte Globals) gegen andere Graphics-/Draw-Mods

### LOW (nice-to-have nach Alpha)

- Expert-Mode für Experimental-Caps
- Changelog-Dialog nach Update
- Console-Reset auf Defaults
- HUD-Position-Presets bei Overlay-Konflikten
- `descVersion` gegen aktuelle ModHub-Guideline prüfen (Release-Blocker)

### Bewusst nicht übernommen

- Schwere MP-Full-Sync à la große Gameplay-Mods (Join-Probleme)
- Undokumentierte Memory-/VRAM-Hooks außer klar exponierten Settern
- Blindes Hochdrehen von Draw-Distance/LOD (CPU-Bottleneck laut Community-Guides)
- Slider-Widgets / DialogElement-Patterns (bekannte Crash-/White-Box-Fallen)

## Empfohlene nächste Schritte (nach Freigabe)

1. Repo `FS25_Enhanced` anlegen; Branch-Policy `main` / `develop` / `experimental/*`.
2. **Research Freeze** durchführen: Capability-CSV/XML aus SettingsModel + Engine-Kategorien Lighting/Rendering/Precipitation/Particle/Foliage/SWS.
3. Skeleton-Mod mit `modDesc` + Hello-Updateable + Restore-Stub in-game laden (VS Code Debugger F10).
4. Lights-Probe Spec gegen ein Vanilla-Fahrzeug mit RealLights validieren.
5. Erste CONFIRMED Caps verdrahten: `setMaxNumShadowLights`, `setLightShadowPriority`, Distance-Coeffs.
6. EN/DE L10N-Keys + Validator-Skript.
7. Testmatrix Farmyard Night / Open Field / Fog mit Screenshots + Frame-Time-Log.
8. Erst danach Merge-Manager und Experimental Focus/FastUpdate.

---

## Anhang A — Verifizierte URL-Anker (Kurzliste)

- FS25 LuaDoc Hub: https://gdn.giants-software.com/documentation_scripting_fs25.php  
- SpecializationUtil: `...?version=script&category=77&class=614`  
- TypeManager: `...?version=script&category=77&class=615`  
- Utils: `...?version=script&category=90&class=880`  
- Logging: `...?version=script&category=58&class=553`  
- SettingsModel: `...?version=script&category=43&class=486`  
- Lights Spec: `...?version=script&category=78&class=691`  
- Engine Lighting: `...?version=engine&category=11`  
- Engine Rendering (`setShadowFocusBox`, `setFastShadowUpdate`): `...?version=engine&category=22`  
- Engine Precipitation: `...?version=engine&category=21`  
- Engine Particle System: `...?version=engine&category=18`  
- Engine Foliage: `...?version=engine&category=6`  
- Engine ShallowWaterSimulation: `...?version=engine&category=23`  
- VS Code IDE: https://gdn.giants-software.com/vscode.php  
- Dev Controls: https://gdn.giants-software.com/documentation_overview.php  
- eBook/Samples: https://gdn.giants-software.com/lp/scriptingBook.php  

## Anhang B — Mapping User-Feature → erste Capability-Kandidaten

| User-Modul | Erste Setter-Kandidaten |
|------------|-------------------------|
| ShadowManager | `setLightShadowMap`, `setLightShadowPriority`, `setMaxNumShadowLights`, `setShadowQuality`, `setShadowDistanceQuality` |
| ShadowMergeManager | `mergeLightShadows`, `setMergedShadowActive`, `setMergedShadowSettings`, `splitLightShadow` |
| ShadowSoftnessManager | `setLightSoftShadowSize`, `setLightSoftShadowDistance`, `setLightSoftShadowDepthBiasFactor`, `setShadowFilterQuality` |
| ShadowFocusManager | `setShadowFocusBox` |
| Fast Shadow Update | `setFastShadowUpdate` |
| IESManager | `setLightIESProfile`, `getLightIESProfile` |
| LightScatteringManager | `setLightUseLightScattering`, `setLightScatteringIntensity`, … |
| LightCullingManager | `setLightCullingWorldProperties` + Budget-Deaktivierung |
| LODManager | `setViewDistanceCoeff`, `setLODDistanceCoeff` |
| FoliageManager | `setFoliageViewDistanceCoeff`, `setFoliageLODDistanceCoeff`, `setAllowFoliageShadows` |
| TerrainManager | `setTerrainLODDistanceCoeff`, `setTerrainQuality` (Restart-Hinweis) |
| RainManager | `setRainAmountMultiplier`, `setRainTurbulenceParameters`, `setRainWindForce`, … |
| ParticleBudgetManager | `setEmitCountScale`, `setMaxNumOfParticles`, … |
| Water/Puddle | ShallowWaterSimulation-* |
| Materials | `setMaterialCustomParameter`, `setWetness`, … |
| Reflections | `setScreenSpaceReflectionsQuality` |

*Ende Optimalplan.*
