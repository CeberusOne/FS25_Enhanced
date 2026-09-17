# Environment backend research and integration

Research date: 2026-09-11. Target: Farming Simulator 25, GIANTS Engine 10.
Status: **EXPERIMENTAL / in-game unverified**. Nine isolated Lua mock scenarios pass; they do not prove a visual improvement, GPU performance or map compatibility.

## Verified references

The installed FS25 SDK `sdk/debugger/scriptBinding.xml` supplies exact function signatures, including optional arguments. Current GDN references:

- [Rain spawn velocity](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=21&function=592&version=engine): precipitation entity plus three velocity components.
- [Rain turbulence](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=21&function=593&version=engine): precipitation entity plus strength, timescale, pulse period and frequency.
- [Maximum rain drops](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=21&function=587&version=engine): changing this allocates GPU buffers; unsuitable as a per-frame governor control.
- [Active rain amount](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=21&function=577&version=engine): a bounded multiplier on supported drops.
- [ParticleUtil](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=90&class=874&version=engine): distinguishes table-based wrappers from native particle geometry functions.
- [Particle lifetime getter](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=18&function=402&version=engine).
- [SimParticleSystem](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=62&class=583&version=script): demonstrates particle geometry IDs are obtained from shape geometry, not arbitrary transform IDs.
- Installed FS25 `scripts/vehicles/specializations/FoliageBending.lua`: `mission.foliageBendingSystem:createRectangle(minX,maxX,minZ,maxZ,yOffset,node)` and `destroyObject(id)`. Existing specialization fields provide active footprint dimensions.

No older FS17/FS19/FS22 signature was accepted as evidence for FS25. A native function returning without a Lua error does not establish successful application.

## Integration contract

Load all five modules as ordinary mod source files. `FS25E_WeatherManager.install()` and `FS25E_ParticleManager.install()` must run **before the environment and effects initialize**, so valid authored values can be observed. They are transparent until a user changes a supported setting. Their wrappers retain the original function, preserve call arguments and do not remove a newer wrapper installed by another mod. Both are disabled on dedicated servers.

Call `FS25E_MaterialManager.update(dt)` and `FS25E_FoliageManager.update(dt)` from the client update loop; both throttle their work. Call each module's `restore()` when disabling Enhanced and `reset()` before mission destruction. Call `install()` again for a later mission if reset removed the hooks. Reset must happen while render entities still exist.

Each module exposes `getControls()` returning ordered records with `id`, `category`, `labelKey`, `tooltipKey`, numeric range/step when available, cost, experimental flag, `read`, `write`, `restore` and `available`. All are optional experiments and must stay outside stable automatic presets until real visual, performance and compatibility gates pass. `write(id,value,true)` checks field locks. `setLocked(id,bool)` synchronizes governor locks. Material steps are 0.001, relative weather/particle/bending steps 0.005; categorical and integer controls use step 1.

The translation additions are supplied in `work/environment_l10n.json`, with matching German and English keys. Public module UI text uses keys only.

## Implemented capabilities

| Module | Actual implementation | Scope / constraints |
| --- | --- | --- |
| Weather | Drop velocity, horizontal wind factor, turbulence strength, restitution, bounce randomness, camera velocity influence, distribution power, bounce count | Captures full valid authored native tuples, no invented baseline. Weather transitions replace baseline instead of multiplying previous output. Max 16 observed precipitation entities per property. Setter-only APIs return `FS25E_status_observedOnly`, never a claimed verified apply. |
| Particles | Density, emitter velocity inheritance, random speed, lifetime and original active-budget fraction | Max 1024 observed geometry IDs per property. Requires native getter and successful readback. Lifetime explicitly passes required `keepBlendTimes=true` on manual changes; game updates first retain authored blend timing. Integer limits are rounded. No continuous GPU buffer increases. |
| Materials | Clearcoat intensity/smoothness, three SSR components, detail smoothness, visual wetness response and three optional surface profiles | Up to eight nearby vehicles within 60 m; current vehicle preferred, also works on foot. At most 512 vehicle-list entries and 4096 nodes / 1024 material slots inspected when membership changes. Recognizes vehicle shader contract by basename; validates variation, opaque material, normal/gloss textures, porosity and parameter domains. No hardcoded map/install/vehicle paths. Unknown shaders excluded. Every write uses `shared=false` plus explicit slot, readback and private ownership. |
| Foliage | Optional additional bending rectangles based on existing active vehicle footprints; optional attached implements; width/length factor and zone budget | Default off. Max 16 local rectangles and 64 equipment visits. Restores by deleting only owned rectangles; original specialization zones untouched. No arbitrary hardware or implement dimensions. |
| Water | Full planned water control inventory with explicit asset-required status | All controls unavailable; no fake numeric adjustment, no setter calls, no claimed puddle simulation. The association API needs actual precipitation and shallow-water simulation entity IDs. |

Particle `updateAuto(speedKph,wetness,budget)` can reduce density at high speed if explicitly enabled with a manual density choice. It respects the density lock. Wetness is intentionally not used to suppress all particles because emitter types are not classified: reducing steam, exhaust or rain as if they were dust would be incorrect.

## Restore and failure behavior

Particle restore reads the current value and restores only values still owned by this mod; newer writes from other mods win. Material restore similarly checks material-slot identity and the applied parameter vector. Deleted entities are skipped. Weather lacks getters and restores the latest authored tuple observed through its wrapper; the UI must communicate this lesser certainty. Missing API, unknown entities, missing texture/parameter contracts and unobserved baselines produce localized unavailable reasons.

Material changes restore when vehicles leave the selected nearby set and on mission unload. Incoming relevant vehicles receive the selected values. Inactive rain settings can have no visible effect; restitution/randomness need bounces, camera influence needs camera movement, SSR paint controls require native SSR, and wet response requires genuine material wetness. These conditions are explained in tooltips.

### Installed shader verification

`data/shaders/vehicleShader.xml` confirms `smoothnessScale` is a float in the authored 0..10 domain; code multiplies `detailSpecular.r` by this value before material blending. The user control conservatively offers 0..2. It is labelled **detail smoothness**, not normal sharpness. The same shader declares `scratches_dirt_snow_wetness` as float4 in 0..1: W feeds `gWetnessMask`, while XYZ encode scratches/dirt/snow. `Washable:setNodeWetness` in the installed FS25 scripts updates W independently. The visual response controller tracks new authored W values and never changes gameplay `nodeData.wetness`; restore preserves newer dirt/snow/scratch components.

The shader samples `detailNormal` directly from a texture and has no `normalScale`, `microdetailStrength` or equivalent scalar. Normal enhancement therefore requires assets, not a fabricated setter. Both planned normal controls are visible but unavailable with that precise reason. Existing shader variation is validated and kept intact; switching it would risk breaking animation/UV/vehicle masks. Named surface profiles change only verified scalar material parameters, never shader variation.

## Remaining PDF scope, not silently claimed implemented

- Five named rain visual profiles (light, normal, heavy, storm look, wind-driven) atomically select velocity/wind/turbulence factors when all original tuples exist. They do not create gameplay thunderstorms. Separate storm intensity and spawn volume adaptation are not implemented. Rain density remains the root catalog's native global multiplier.
- Per-effect dust / harvesting / exhaust / steam / splash classification and wet-ground suppression are not implemented. Current particle factors apply to supported observed native emitters.
- Generic normal-map amplification, microdetail strength and shader variation switching have no safe universal scalar material contract. Compatible clearcoat/SSR, detail smoothness and visual wet response are implemented; missing normal parameters are explicitly distinguished from those real controls.
- Additional foliage zones do not increase the engine bending texture resolution and are not high-precision foliage rendering. Near/far rendering remains with native LOD controls.
- Local water needs authored render assets, a simulation setup, terrain/obstacle mapping, precipitation binding, foam and drainage behavior, ownership and real visual/performance tests. None of those assets exists in the supplied mod. GDN exposing individual functions does not make a one-call generic water system possible.
- Mirror-specific object/light budgets and surface profile overrides beyond compatible paint are not supplied by these modules.

## Test evidence

`lua work/test_environment_modules.lua`: 9 PASS mock scenarios cover original tuples, weather transitions/profiles, missing baselines, locks, particle readback failure, required lifetime arguments, authored blend timing, foreign wrappers, deleted nodes, private material writes, restoring paint/SSR components, external material changes, on-foot nearby selection, detail smoothness, wetness update/restore preserving other components, foliage cleanup and rejected asset-free water calls.

No vanilla map, mod map, 4x map, real vehicle, visual A/B, frametime or VRAM test has been run by these mocks. Required in-game status is **UNVERIFIED**, not PASS.

## Final API / lifecycle audit (2026-09-11)

- Rechecked native calls against installed `sdk/debugger/scriptBinding.xml`: rain tuples (including 4 turbulence arguments), particle lifespan `keepBlendTimes`, material `shared=false` plus explicit material slot, and foam setter `(simulationId, float)` match declared signatures. Weather remains observed-only: no native getter exists for these rain values.
- Fixed transient getter failures during particle/material restore: retain restoration records and return failure for ModuleRuntime retry. Material dynamic wetness write failures now immediately roll back the exact vector and retain a failed rollback's readback for later recovery. Material absolute profile snapshots now read native current values, not stale configured values.
- Foliage destruction rejects explicit false; attachment activation/deactivation now triggers bounded topology refresh. Runtime clears A/B suspension on mission reset/init.
- Tests: `lua work/test_environment_modules.lua` passes **10 mock scenarios**, including existing-water ownership/restore/retry/reused IDs. `lua work/test_integration_environment.lua` passes **31 assertions** with real adapters/catalog/runtime and mocked native boundaries. These are not an in-game graphics or runtime pass.

### Shallow-water feasibility and implemented useful subset

GDN [PlaceableShallowWaterSimulation](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=78&class=760&version=engine) registers existing water planes through `g_currentMission.shallowWaterSimulation:addWaterPlane` and `addAreaGeometry`; stock player, wheel and crawler code already registers obstacles. The native bindings provide foam accumulation/decay getters/setters independently of water depth.

The `waterFoam` control is now implemented (experimental, factor 0..2, step 0.001) for **existing registered native water surfaces**. Early wrappers observe exact `(simulationId, geometryId)` arguments at `shallowWaterSimulationAddWaterPlaneGeometry`, track removals and creation/reuse, then use `get/setShallowWaterSimulationFoamAccumulationRate`. Baseline is sampled before first write; every change is read back; newer foreign state wins; failed restore retains records; mission changes cannot restore an old native id. No sim object field name is guessed, no extra global sim is allocated, and no gameplay water depth changes. Availability requires a live observed surface and a functioning getter. If the stock implementation bypasses the observed Lua-native registration call, the row stays unavailable, requiring an actual game trace to establish an alternative.

[GIANTS shallow-water ground binding](https://gdn.giants-software.com/documentation_scripting_fs25.php?category=23&function=654&version=engine) requires terrain to remain alive; physical grid size and world position must match. The installed `data/maps/mapUS/textures/waterplanes.i3d` contains real oceanShader planes at fixed Riverbend world heights (approximately 41.75 to 64.638), with external `.shapes` data and mirror planes. These are not portable terrain-following puddle geometry. `data/effects/water/water.i3d` instead uses animated billboard/refraction splash particles and cannot act as a shallow-water surface. `data/shaders/oceanShader.xml` requires correctly bound simulation output and velocity textures; making a plane alone does not establish a working scene/render contract.

Consequently the other **7 water controls remain unavailable**: no supported depth-state snapshot/restore makes arbitrary accumulation/drain/source painting safe on the game's shared sim, and physical radius/grid resizing would interfere with its existing owner. A separate mod I3D plus private simulation is technically plausible using documented create/terrain/texture/update calls, but requires GIANTS Editor-authored compatible geometry/material, explicit ownership/cleanup, camera-following simulation bounds, and in-game tests for rendering, terrain conformity and cost. No such asset/prototype was generated or claimed working. The existing native foam adapter is the tested code subset; the full 30–80m puddle prototype remains unverified and incomplete.
