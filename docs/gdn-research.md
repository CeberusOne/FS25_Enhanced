# FS25 / Giants Engine 10 — GDN Lua Modding Research Briefing

**Research date:** 2026-09-10  
**Primary source:** [Giants Developer Network (GDN)](https://gdn.giants-software.com/)  
**LuaDoc version documented:** Script **v1.20.0.0** / Engine **v1.20.0.0** (FS25)  
**Scope:** Official GDN documentation relevant to building an FS25 “Enhanced” Lua script mod (architecture, API, hooks, registration, debugging).

**Verification legend**
- **Verified** — fetched/parsed from official GDN pages (or official GDN eBook PDF download).
- **Inferred from verified code** — behavior described by official LuaDoc source listings (not separate prose docs).
- **Not found on GDN** — searched/fetched; no dedicated official page or incomplete coverage.

---

## Executive summary

1. **Official scripting hub for FS25** is the LuaDoc at  
   `https://gdn.giants-software.com/documentation_scripting_fs25.php`  
   labeled **LUADOC - FARMING SIMULATOR 25**, Script/Engine **v1.20.0.0**. It is split into **Script** (game Lua classes), **Engine** (native engine functions), and **Foundation Reference**.

2. **FS25 modding tooling has shifted**: GDN documents that **GIANTS Studio/Debugger is discontinued**; the recommended tool is the **Farming Simulator IDE Support** VS Code extension (`vscode.php`), with IntelliSense, XML schemas (including mod descriptors), Lua debugger (F10), hot-reload, and game log viewer.

3. **Core scripting model is specialization-based**: types (vehicle/placeable/…) are compositions of specializations registered via `SpecializationManager` / `TypeManager`. Mods extend behavior with `SpecializationUtil.registerEventListener`, `registerFunction`, `registerOverwrittenFunction`, and network `Event` subclasses (`readStream` / `writeStream` / `run`).

4. **modDesc.xml is the mod entry point** (verified in official eBook *Scripting Farming Simulator with Lua*, 2024, downloadable from GDN). Scripts load via `<extraSourceFiles>`, custom specs via `<specializations>` / `<placeableSpecializations>`, types via `<vehicleTypes>` / `<placeableTypes>`. **No dedicated FS25 modDesc reference page** was found in free HTML docs; VS Code XML schema support is the live schema path.

5. **Important globals** (`g_currentMission`, `g_server`, `g_currentModName`, managers) appear throughout LuaDoc **source listings** but are **not catalogued as a standalone “globals” API chapter** on GDN.

6. **Best official learning path for an Enhanced mod**: FS25 LuaDoc + VS Code extension docs + eBook samples on GDN Downloads + engine overview console/dev controls page. Basic engine tutorials (`tutorials.php`) teach standalone engine `main.lua` loops, not FS mod specializations.

---

## Official URLs (catalog)

### Entry points

| Resource | URL | Notes |
|----------|-----|-------|
| GDN home | https://gdn.giants-software.com/ | Hub |
| Documentation index | https://gdn.giants-software.com/documentation.php/index.php | Fundamentals + Scripting + Content Creation |
| Documentation overview (dev controls / console) | https://gdn.giants-software.com/documentation_overview.php | `game.xml` development controls, console commands |
| FS25 LuaDoc | https://gdn.giants-software.com/documentation_scripting_fs25.php | **Primary API reference** |
| FS22 / FS19 LuaDoc | `documentation_scripting_fs22.php` / `documentation_scripting_fs19.php` | Historical |
| Scripting tutorials (engine samples) | https://gdn.giants-software.com/tutorials.php | Basic engine Lua (not FS specialization) |
| Tutorial 01 | https://gdn.giants-software.com/tutorial01.php | `init`/`update`/`draw`, i3d load |
| VS Code IDE Support (FS25) | https://gdn.giants-software.com/vscode.php | **Recommended** debugger/IDE |
| Debugger/Studio (discontinued) | https://gdn.giants-software.com/debugger.php | Kept for reference; points to VS Code |
| Editor docs | https://gdn.giants-software.com/editor.php | GIANTS Editor |
| Downloads | https://gdn.giants-software.com/downloads.php | Editor, exporters, eBook, samples |
| Scripting eBook landing / samples | https://gdn.giants-software.com/lp/scriptingBook.php | Code sample ZIPs |
| eBook PDF | https://gdn.giants-software.com/download.php?downloadId=134 | *Scripting Farming Simulator with Lua* (2024) |
| ModHub guide PDF | https://gdn.giants-software.com/download.php?downloadId=124 | ModHub guidelines (descVersion) |
| Videos | https://gdn.giants-software.com/videoTutorials2.php | Includes FS25 modding/mapping |
| Forum | https://gdn.giants-software.com/forum.php | Community (account may be needed for full use) |
| Search | https://gdn.giants-software.com/search.php | Site search |

### FS25 LuaDoc — Script categories (v1.20.0.0)

Base URL pattern:  
`https://gdn.giants-software.com/documentation_scripting_fs25.php?version=script&category=CAT&class=CLASS`

| Category | First class id | Category id |
|----------|----------------|-------------|
| Activatables | 145 | 2 |
| AI | 146 | 3 |
| Animals | 157 | 4 |
| Base | 159 | 7 |
| Collections | 162 | 13 |
| Components | 164 | 14 |
| Configurations | 171 | 15 |
| Contracts | 182 | 17 |
| Data | 184 | 19 |
| Debug | 191 | 20 |
| Economy | 213 | 25 |
| Elements | 215 | 27 |
| Errors | 219 | 29 |
| Events | 248 | 30 |
| Extensions | 394 | 31 |
| Field | 403 | 35 |
| FillTypes | 408 | 36 |
| Fruits | 410 | 38 |
| GUI | 418 | 43 |
| Handtools | 510 | 45 |
| Hud | 526 | 47 |
| I3d | 532 | 49 |
| Input | 533 | 51 |
| Jobs | 535 | 54 |
| Materials | 541 | 57 |
| Misc | 547 | 58 |
| Missions | 560 | 59 |
| Networking | 562 | 61 |
| Objects | 567 | 63 |
| Parameters | 581 | 65 |
| Placeables | 590 | 66 |
| Placement | 595 | 67 |
| Player | 597 | 69 |
| Shop | 605 | 75 |
| Sounds | 610 | 76 |
| **Specialization** | **613** | **77** |
| **Specializations** | **616** | **78** |
| StateMachine | 835 | 80 |
| Tasks | 843 | 81 |
| Triggers | 850 | 88 |
| **Utils** | **857** | **90** |
| **Vehicles** | **881** | **91** |
| Weather | 901 | 92 |
| Wheels | 902 | 93 |

### High-value class pages (verified)

| Topic | URL |
|-------|-----|
| SpecializationManager | `...?version=script&category=77&class=613` |
| **SpecializationUtil** | `...?version=script&category=77&class=614` |
| **TypeManager** | `...?version=script&category=77&class=615` |
| Logging | `...?version=script&category=58&class=553` |
| Utils | `...?version=script&category=90&class=880` |
| ClassUtil | `...?version=script&category=90&class=861` |
| MathUtil | `...?version=script&category=90&class=871` |
| Vehicle | `...?version=script&category=91&class=888` |
| Placeable | `...?version=script&category=66&class=591` |
| DebugUtil | `...?version=script&category=20&class=211` |
| DebugManager | `...?version=script&category=20&class=201` |
| Example specialization (AIAutomaticSteering) | `...?version=script&category=78&class=616` |
| Example network Event (VehicleAttachEvent) | `...?version=script&category=30&class=370` |
| Engine Network streams | `...?version=engine&category=14&function=243` |
| Foundation Scenegraph | `...?version=foundation&fCategory=1&fFunction=1` |

### Engine function categories (v1.20.0.0)

Animation, Camera, Debug, Entity, Fillplanes, Foliage, General/general, I3D, Input, Lighting, Math, NavMesh, **Network**, Node, NoteNode, Overlays, Particle System, Physics, PointList2D, Precipitation, Rendering, ShallowWaterSimulation, Shape, Sound, Spline, String, Terrain, Terrain Detail, Text Rendering, Tire Track, VoiceChat, **XML**.

---

## Lua & script architecture

### Two layers (Verified)

1. **Engine / Foundation** — low-level functions (`translate`, `loadI3DFile`, stream read/write, XML, physics, etc.). Basic GDN tutorials demonstrate a standalone `main.lua` with `init()`, `update()`, `draw()`, `keyEvent()`, `mouseEvent()` wired via a game XML `-script` path. This is **engine-sample** style, not the FS mission/mod specialization model.

2. **Script (game)** — FS25 gameplay classes: vehicles, placeables, missions, GUI, events, specializations. This is what FS25 mods primarily extend.

### How specialization scripts load (Verified from LuaDoc)

**SpecializationManager.addSpecialization(name, className, filename, customEnvironment)**  
- Rejects duplicates / missing className/filename (via `Logging.error`).  
- Calls **`source(filename, customEnvironment)`** to load the Lua file.  
- Resolves class via **`ClassUtil.getClassObject(className)`**.  
- Stores `{name, className, filename}` and inserts into sorted list.

**SpecializationManager.loadMapData** reads an XML of the form:

```xml
specializations.specialization
  #name, #className, #filename
```

and queues `addSpecialization` via `g_asyncTaskManager:addSubtask`.

**initSpecialization / postInitSpecialization** (optional on the specialization class) are invoked asynchronously during `initSpecializations` / `postInitSpecializations`.

### Type composition (Verified — TypeManager)

**TypeManager.addType(typeName, className, filename, customEnvironment, parent)**  
- `source(filename, customEnvironment)`  
- Creates type entry with: `specializations`, `specializationNames`, `specializationsByName`, `functions`, `events`, `eventListeners`, `customEnvironment`, `parent`.

**TypeManager.addSpecialization(typeName, specName)** attaches a known specialization object to a type.

**TypeManager.finalizeTypes()** (order matters — Verified source):

1. Base class `registerEvents(typeEntry)`  
2. Base class `registerFunctions(typeEntry)`  
3. Each specialization `registerEvents`  
4. Each specialization `registerFunctions`  
5. Each specialization `registerOverwrittenFunctions`  
6. Each specialization `registerEventListeners`  

Then functions are copied onto instances via **`SpecializationUtil.copyTypeFunctionsInto(typeDef, target)`** (seen in `Vehicle:load`).

### Specialization class contract (Verified from LuaDoc examples + eBook)

Typical specialization module pattern (names verified in FS25 LuaDoc / eBook):

| Hook / API | Role |
|------------|------|
| `prerequisitesPresent(specializations)` | Gate load; often uses `SpecializationUtil.hasSpecialization(...)` |
| `initSpecialization()` | Register XML schema paths (`Vehicle.xmlSchema` / savegame schema) |
| `postInitSpecialization()` | Optional post-init |
| `registerEvents(type)` | `SpecializationUtil.registerEvent(type, "onSomething")` |
| `registerFunctions(type)` | Expose methods on the type |
| `registerOverwrittenFunctions(type)` | Wrap existing type functions (`superFunc` pattern) |
| `registerEventListeners(type)` | Bind lifecycle/network callbacks |
| Instance methods | `onLoad`, `onUpdate`, … receive `self` as vehicle/placeable |
| Spec storage | `self.spec_<name>` in base game; eBook uses `SPEC_TABLE_NAME = "spec_"..g_currentModName.."."..name` for mod specs |

### Script environments / mod name (Verified in eBook)

- **`g_currentModName`** is available **while the Lua file is being sourced**; store it in a local (`local modName = g_currentModName`).  
- TypeManager uses **`customEnvironment`** when sourcing type/spec files (mod types print `Register <typeName> type: ...` when customEnvironment ≠ `""`).  
- **`g_modIsLoaded[modName]`** referenced in `TypeManager:getTypeByName` error path (LuaDoc source).

### Vehicle load path snippet (Verified)

`Vehicle:load` sets loading step `SpecializationLoadStep.PRE_LOAD`, loads XML via `XMLFile.load`, then **`SpecializationUtil.copyTypeFunctionsInto(self.type, self)`**.

---

## API overview (with links)

> Only names **seen in official LuaDoc / eBook** are listed. This is not a complete dump of all 200+ specializations or 140+ events.

### Global / mission objects (appear in LuaDoc source — no dedicated globals page)

Observed in official FS25 LuaDoc code listings (**Inferred from verified code**):

| Symbol | Usage seen in docs |
|--------|--------------------|
| `g_currentMission` | Mission/session; `getIsServer()`, `addUpdateable`/`removeUpdateable`, `placeableSystem`, `terrainSize`, `terrainDetailId`, `growthSystem`, `animalFoodSystem`, `animalSystem`, … |
| `g_server` | Server-side event broadcast (e.g. `g_server:broadcastEvent`) |
| `g_asyncTaskManager` | Async subtasks during manager init |
| `g_storeManager` | Store items / spec types |
| `g_soundManager` | Sample load/play |
| `g_i18n` | Localized strings |
| `g_gameSettings` | Settings get/set |
| `g_fieldCourseManager` | Field course generation (AI steering) |
| `g_i3DManager` | Shared i3d release |
| `g_brandManager` | Brands |
| `g_currentModName` | Mod name during `source` (eBook) |
| `g_modIsLoaded` | Mod load flags (TypeManager) |

**Not found:** A single official “Globals reference” page listing all `g_*` objects.

### SpecializationUtil  
URL: [class 614](https://gdn.giants-software.com/documentation_scripting_fs25.php?version=script&category=77&class=614)

| Function | Purpose (from LuaDoc descriptions) |
|----------|-------------------------------------|
| `registerEvent` | Register event name on object type; creates listener list |
| `registerEventListener` | Bind specialization method named like the event |
| `removeEventListener` | Unbind listener from an **object** instance |
| `raiseEvent` | Synchronously call all listeners for event |
| `raiseAsyncEvent` | Same via `object:addAsyncTask` |
| `registerFunction` | Add function to type’s function table |
| `registerOverwrittenFunction` | Replace type function via `Utils.overwrittenFunction` |
| `hasSpecialization` | Prerequisite checks |
| `initSpecializationsIntoTypeClass` | Copy type/spec/eventListeners onto target |
| `copyTypeFunctionsInto` | Copy type functions onto instance |
| `createLoadingTask` / `finishLoadingTask` | Async loading task tracking → `onFinishedLoading` |
| `setLoadingStep` / `getIsValidLoadingStep` | `SpecializationLoadStep` enum |

### TypeManager / SpecializationManager  
- [TypeManager 615](https://gdn.giants-software.com/documentation_scripting_fs25.php?version=script&category=77&class=615)  
- [SpecializationManager 613](https://gdn.giants-software.com/documentation_scripting_fs25.php?version=script&category=77&class=613)

### Logging  
URL: [Logging 553](https://gdn.giants-software.com/documentation_scripting_fs25.php?version=script&category=58&class=553)

Documented methods: `error`, `warning`, `info`, `fatal`, `xmlError`, `xmlWarning`, `xmlInfo`, `i3dError`, `i3dWarning`, `i3dInfo`.  
Printf-style placeholders supported. `fatal` **stops the game**.  
**Note:** LuaDoc source elsewhere calls `Logging.devInfo(...)` (e.g. AIAutomaticSteering) but **`devInfo` is not listed** on the Logging class page — treat as present in engine builds but **not documented on that page**.

### Utils  
URL: [Utils 880](https://gdn.giants-software.com/documentation_scripting_fs25.php?version=script&category=90&class=880)

Documented function list (complete from LuaDoc TOC):  
`appendedFunction`, `clearBit`, `clearFlags`, `compareVersions`, `compareVersionStrings`, `formatTime`, `getClosestMatchingString`, `getCoinToss`, `getDirectory`, `getDirectoryName`, `getFilename`, `getFilenameFromPath`, `getFilenameInfo`, `getGreenRedBlendedColor`, `getIntersectionOfLinearMovementAndTerrain`, `getMasterVolumeFromIndex`, `getMasterVolumeIndex`, `getMaxJointForceLimit`, `getMinuteOfDayFromTime`, **`getModNameAndBaseDirectory`**, `getMovedLimitedValue`, `getMovedLimitedValues`, `getNoNil`, `getNoNilRad`, `getNormallyDistributedRandomVariables`, `getNumOfWords`, `getNumTimeScales`, `getPathIsValid`, `getPerformanceClassFromIndex`, `getPerformanceClassId`, `getPerformanceClassIndex`, `getRecordingVolumeFromIndex`, `getRecordingVolumeIndex`, `getStateFromValues`, `getTimeScaleFromIndex`, `getTimeScaleIndex`, `getTimeScaleString`, `getUIScaleFromIndex`, `getUIScaleIndex`, `getUniqueId`, `getValueIndex`, `getVersatileRotation`, `getYRotationBetweenNodes`, `isBitSet`, `limitTextToWidth`, `maskToFormat`, `naturalSort`, **`overwrittenFunction`**, `parseConsoleParameter`, **`prependedFunction`**, `renderMultiColumnText`, `renderTextAtWorldPosition`, `resolveRelativePath`, `setBit`, `setMovedLimitedValues`, `shuffle`, `stringToBoolean`.

**Pattern (eBook + Utils API):**  
- `Utils.prependedFunction(old, new)` / `appendedFunction` / `overwrittenFunction` — used to inject into managers (e.g. prepend to `TypeManager.finalizeTypes` to auto-add a specialization to all motorized vehicles).

### ClassUtil  
[861](https://gdn.giants-software.com/documentation_scripting_fs25.php?version=script&category=90&class=861): `getClassObject`, `getClassName`, `getClassModName`, `getFunction`, validation helpers.

### MathUtil / other Utils siblings  
BitmapUtil, BlurUtil, FSDensityMapUtil, ObjectChangeUtil, ParticleUtil, SplineUtil, SplitShapeUtil, StateMachine, StoreItemUtil, etc. under Utils category.

### Vehicles / Placeables  
- [Vehicle 888](https://gdn.giants-software.com/documentation_scripting_fs25.php?version=script&category=91&class=888) — large surface (load, physics, selection, AI helpers, …).  
- Related: VehicleSystem, VehicleMotor, VehicleCamera, AIVehicleUtil, WheelsUtil, …  
- [Placeable 591](https://gdn.giants-software.com/documentation_scripting_fs25.php?version=script&category=66&class=591) — load/placement/sell/day-hour callbacks.  
- PlaceableSystem, PlaceableLoadingData, BeehiveSystem.

### Events (network) category  
~146 event classes under Script → Events. Parent type documented as **`Event`** (e.g. VehicleAttachEvent).  

Typical Event API (Verified on VehicleAttachEvent):

| Method | Role |
|--------|------|
| `emptyNew()` | `Event.new(Class_mt)` |
| `new(...)` | Populate fields |
| `writeStream(streamId, connection)` | Serialize |
| `readStream(streamId, connection)` | Deserialize; often calls `run` |
| `run(connection)` | Apply logic; may `g_server:broadcastEvent` |

Uses **`NetworkUtil.readNodeObject` / `writeNodeObject`** and engine **`streamRead*` / `streamWrite*`**.

### Engine Network streams  
[Engine Network](https://gdn.giants-software.com/documentation_scripting_fs25.php?version=engine&category=14&function=243):  
`streamRead/Write` Bool, Float32, Int8/16/32/N, UInt8/16/32/N, String, Timestamp helpers, stream offsets/align.

### Debug  
Script Debug category: DebugManager, DebugUtil (`drawDebug*`, `printTableRecursively`, …), geometric debug helpers.  
Engine Debug category also exists.

### Specializations catalog (Verified — 219 classes in category 78)

Includes vehicle specs (Drivable, Motorized, FillUnit, Dischargeable, WorkArea, …), AI specs, and many **Placeable\*** specs (PlaceableHusbandry\*, PlaceableSilo, PlaceableProductionPoint, …). Full list scraped from GDN LuaDoc category 78 (see research notes / `/tmp/gdn_pages/all_specializations.txt` during research). Start browsing at [AIAutomaticSteering](https://gdn.giants-software.com/documentation_scripting_fs25.php?version=script&category=78&class=616).

---

## Hooks / events / callbacks

### Specialization event system (Verified)

1. **Register event name** on type: `SpecializationUtil.registerEvent(objectType, eventName)`  
2. **Register listener**: `SpecializationUtil.registerEventListener(objectType, eventName, SpecClass)` — requires `SpecClass[eventName]` to exist.  
3. **Raise**: `SpecializationUtil.raiseEvent(object, eventName, ...)` calls `spec[eventName](object, ...)` for each listener in order.  
4. Async variant: `raiseAsyncEvent`.

If event was never registered, `raiseEvent` logs via `printError` / `printCallstack`.

### Lifecycle listeners seen on official specializations

**AIAutomaticSteering.registerEventListeners** (Verified FS25 LuaDoc) registers:

- `onLoad`, `onPostLoad`, `onRegisterDashboardValueTypes`, `onDelete`  
- `onReadStream`, `onWriteStream`, `onReadUpdateStream`, `onWriteUpdateStream`  
- `onUpdate`, `onUpdateTick`, `onStateChange`  
- `onAIModeChanged`, `onAIModeSettingsChanged`  
(+ later in listing: `onActivate`, `onLeaveVehicle`, `onRegisterActionEvents`, `onAIAutomaticSteeringLineEnd` as method names)

**Documented signatures (examples):**

- `onLoad(savegame)` — “Called on loading”  
- `onUpdate(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)` — “Called on update”  
- Custom events via `registerEvents` + `raiseEvent` (e.g. `onAIAutomaticSteeringLineEnd`)

**eBook examples also use:** `onDelete`, network stream pair, and placeable `onLoad`/`onUpdate`.

### Overwritten functions (Verified)

`registerOverwrittenFunction(objectType, funcName, func)` replaces `objectType.functions[funcName]` with `Utils.overwrittenFunction(...)`.  
Specialization implementations take **`superFunc` as first argument after self** (community/docs pattern; eBook and forum discuss this; FS25 LuaDoc shows registration API clearly).

### Network Events vs specialization events (Verified distinction)

| Kind | Mechanism |
|------|-----------|
| **Specialization events** | In-process callbacks on a vehicle/placeable type (`onLoad`, custom `onX`) |
| **Network Events** | Classes under Events category, inherit `Event`, stream serialize, `run` on receivers, often broadcast via `g_server` |

### Loading steps (Verified)

`SpecializationLoadStep` enum validated by `getIsValidLoadingStep`. Vehicle load begins at `SpecializationLoadStep.PRE_LOAD`. Loading tasks pair `createLoadingTask` / `finishLoadingTask` → `onFinishedLoading` when queue empty and `readyForFinishLoading`.

---

## modDesc / registration

### Official prose source

**No standalone FS25 “modDesc.xml reference” HTML page** was found under Documentation. Coverage comes from:

1. Official eBook PDF (GDN downloadId=134), chapters 4–10 — **Verified**.  
2. VS Code extension docs: XML schema validation for **mod descriptors** — **Verified** (`vscode.php`).  
3. Debugger legacy docs mention `mods/<name>/modDesc.xml` layout — **Verified** (`debugger.php`).  
4. ModHub guidelines PDF (downloadId=124) for current **`descVersion`** — **not fully extracted in this pass**; eBook says use latest ModHub guidelines for descVersion.

### eBook patterns (descVersion="72" in examples — likely FS22-era book ©2024; confirm FS25 ModHub guideline value)

**Minimal script mod:**

```xml
<modDesc descVersion="72">
  <author>...</author>
  <version>1.0.0.0</version>
  <multiplayer supported="true" />
  <title><en>...</en></title>
  <description><en>...</en></description>
  <iconFilename>icon.png</iconFilename>
  <extraSourceFiles>
    <sourceFile filename="scripts/helloWorld.lua"/>
  </extraSourceFiles>
</modDesc>
```

**Placeable specialization mod:**  
`<placeableSpecializations>` + `<placeableTypes>` (parent type + `<specialization name="..."/>`) + `<storeItems>`.

**Vehicle specialization mod:**  
`<specializations>` + vehicle type entries listing specialization names + `<extraSourceFiles>` for Event scripts / InjectSpecialization / main spec Lua + store items.

**Injecting into all matching base types** (eBook Mileage Counter):  
`Utils.prependedFunction(TypeManager.finalizeTypes, function(self) ... self:addSpecialization(typeName, modName..".mileageCounter") end)` when `self.typeName == "vehicle"` and type has `motorized`.

### Registration checklist for an Enhanced mod (officially grounded)

1. Declare files in **modDesc** `extraSourceFiles` (and specialization/type blocks as needed).  
2. Implement specialization module with prerequisites / initSpecialization / register* hooks.  
3. Rely on TypeManager finalize order for wiring.  
4. Use `SpecializationUtil` for listeners/functions/overwrites.  
5. Use network `Event` classes for MP sync; stream APIs for fields; dirty flags / update streams as in eBook mileage example.  
6. Validate XML via VS Code GDN schemas.

---

## FS25-specific notes

| Topic | Finding | Status |
|-------|---------|--------|
| LuaDoc branding | Explicit **Farming Simulator 25** LuaDoc, Script/Engine **v1.20.0.0** | Verified |
| Engine generation | Downloads/tools labeled Editor/Exporters **v10.x (FS25)** → Giants Engine 10 tooling | Verified (downloads listings) |
| Recommended IDE | **VS Code Farming Simulator IDE Support** replaces Studio | Verified (`vscode.php`, `debugger.php` notice) |
| Hot-reload | `FS Lua: Reload Script in Game` (Ctrl+R) while debug session active | Verified |
| New/FS25 content in LuaDoc | Specs like `AIAutomaticSteering`, many `Extended*`, `PlaceableRiceField*`, `PrecisionFarmingStatistic`, etc. appear in FS25 Specializations list | Verified list |
| eBook currency | *Scripting Farming Simulator with Lua* ©2024; examples use `descVersion="72"` and GIANTS Studio — architecture still matches FS25 LuaDoc APIs, but **tooling + descVersion must be updated per FS25 ModHub guidelines** | Verified with caveat |
| Dedicated “FS25 migration / Engine 10 changelog” scripting page | **Not found** on documentation index | Not found |
| Foundation Reference | Present (Scenegraph, Input) alongside Engine/Script | Verified |

---

## Best practices, limitations, common patterns (from official docs)

**From LuaDoc + eBook + VS Code docs (Verified):**

1. Prefer **specializations** over ad-hoc globals for vehicle/placeable features.  
2. Always implement **`prerequisitesPresent`** when depending on other specs.  
3. Register XML via **`initSpecialization`** + `schema:setXMLSpecializationType` / `schema:register`.  
4. Use **`Logging.*`** (and XML/i3d variants) instead of raw prints for diagnostics; avoid `Logging.fatal` unless unrecoverable.  
5. Multiplayer: implement **stream listeners** and/or dedicated **Event** classes; don’t assume client-local state.  
6. Capture **`g_currentModName`** at file load time.  
7. Use **`Utils.prependedFunction` / `overwrittenFunction` / `appendedFunction`** carefully when injecting into managers.  
8. Develop with **VS Code extension**: trust workspace, set game path, F10 connect, breakpoints, game log channel.  
9. Enable development controls in **`game.xml`** (`<development><controls>true</controls></development>`) for console/FPS/debug keys (overview page).  
10. Basic engine tutorials are **not** the FS25 mod model — use LuaDoc specializations + eBook samples for mods.

**Limitations / gaps called out by official materials:**

- Studio discontinued; old Studio multiplayer debug zip workflow documented only as legacy.  
- LuaDoc is reference + source dump, not a narrative “how to build a mod” guide.  
- Forum/account: eBook notes GDN account needed for full feature set (forum). HTML docs/LuaDoc fetched here **did not require login**.

---

## Debugging, console, logging

### Development controls (Verified — documentation_overview.php)

In `game.xml`:

```xml
<development>
  <controls>true</controls>
</development>
```

**Runtime shortcuts:** `` ` `` / `~` console; F2 FPS; F3 framerate limiter; F4 wireframe; F5 debug rendering; F7 camera; F8 stats.

**Console commands documented on overview:** `help`, `showFps`, `enableFramerateLimit`, `framerateLimitFPS`, `listEntities`, `listResources`, `parallelRenderingAndPhysics`, `exit`/`quit`/`q`.

### Logging (Verified — Logging class)

`Logging.error/warning/info/fatal` (+ xml* / i3d* variants) → console and logfile.

### VS Code debugger (Verified — vscode.php)

- Connect: game **F10** or Editor **Scripts > Connect to Studio**  
- Breakpoints (incl. conditional), step controls, call stack, FS Variables panel, watch, debug console  
- Script hot-reload Ctrl+R  
- Game log viewer with clickable paths  
- IntelliSense generated from engine API stubs when FS install detected  

### Debug drawing / tables (Verified — DebugUtil / DebugManager)

`DebugUtil.drawDebug*`, `printTableRecursively`, `DebugManager` console commands (`consoleCommandRemoveElements`, spline debug toggle, …).

### Legacy Studio (Verified — debugger.php)

Historical; superseded. Still documents mod folder vs zip priority and that **zip wins over folder** if both present.

---

## Gaps / pages that require login or could not be fully used

| Gap | Detail |
|-----|--------|
| **No dedicated FS25 modDesc HTML reference** | Rely on eBook + VS Code XSD + ModHub PDF |
| **No globals catalog page** | `g_currentMission` etc. only via source listings / search |
| **Event base class page** | Child events declare `Parent Event`; base `Event` not located as its own browsable class entry in Events list scrape |
| **NetworkUtil class page** | Used in Event code; not found as its own category entry in Utils/Misc/Networking scrapes |
| **Logging.devInfo** | Used in source; not on Logging method list |
| **Engine 10 / FS25 scripting changelog** | Not on documentation index |
| **Forum deep threads** | Search returns many hits; full forum UX may need GDN account (eBook). Not required for LuaDoc. |
| **Paid video tutorials** | eBook notes newest paid tutorial packs; free FS25 videos exist on Videos page |
| **LuaDoc UI** | Server-rendered class pages are fetchable via `?version=script&category=&class=`; category navigation is HTML list (no login observed) |
| **Basic tutorials** | Teach engine `main.lua`, not FS specialization mods |
| **eBook vs FS25 tooling** | Still references GIANTS Studio; use VS Code path for FS25 |

---

## Suggested reading order for an FS25 “Enhanced” mod

1. https://gdn.giants-software.com/documentation.php/index.php  
2. https://gdn.giants-software.com/vscode.php  
3. https://gdn.giants-software.com/documentation_scripting_fs25.php — Specialization / SpecializationUtil / TypeManager / Utils / Logging / Vehicle or Placeable / Events  
4. eBook PDF + samples (`lp/scriptingBook.php`, downloadId=134) for modDesc + end-to-end patterns  
5. https://gdn.giants-software.com/documentation_overview.php for console/dev controls  
6. Browse Specializations category for the gameplay systems you will enhance  

---

## Source integrity notes

- All API **names and function lists** above were taken from fetched GDN LuaDoc HTML or the official GDN eBook PDF.  
- Where behavior is described from code listings inside LuaDoc, it is marked **Inferred from verified code**.  
- Nothing in this report invents APIs not seen in those sources.
