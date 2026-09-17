# Core research and integration

Checked 2026-09-11 against FS25 GDN (Script/Engine v1.20.0.0), local GIANTS game scripts and installed FS25 SDK. The algorithms below are mod logic. Their mock tests do not demonstrate visual improvement or engine compatibility in a running game.

## Primary evidence

- FS25 VehicleSystem, current player vehicle and weather: https://gdn.giants-software.com/documentation_scripting_fs25.php?category=91&class=897&version=engine . GIANTS calls `g_localPlayer:getCurrentVehicle()`, `weather:getRainFallScale()`, `indoorMask:getIsIndoorAtWorldPosition(x,z)`.
- FS25 Washable, ground wetness/rain and speed: https://gdn.giants-software.com/documentation_scripting_fs25.php?category=78&class=821&version=engine . Supports `weather:getGroundWetness()` and `getRainFallScale()`.
- FS25 NightlightFlicker: https://gdn.giants-software.com/documentation_scripting_fs25.php?category=63&class=574&version=engine . Uses `environment.isSunOn`, `weather:getIsRaining()` and defines update `dt` in milliseconds.
- FS25 VehicleStateRecorder: https://gdn.giants-software.com/documentation_scripting_fs25.php?category=1&class=131&version=script . Uses `g_localPlayer:getCurrentVehicle()`.
- Installed `sdk/debugger/scriptBinding.xml`: `getCamera()` returns the currently active camera; `getWorldTranslation(node)`, `localDirectionToWorld(node,x,y,z)`, `getFovY(camera)` are node/camera reads. All optional functions and nodes are guarded.
- Local GIANTS `vehicles/specializations/Enterable.lua:1572`: `getActiveCamera()` returns `spec_enterable.activeCamera`; `vehicles/VehicleCamera.lua` uses the camera `isInside` flag. Local Player uses `getPosition()`. No guessed field `mission.controlledVehicle` takes precedence over the current FS25 local player.

## Implemented plan items

15: bounded frame ring; 1/5/30-second averages, variance, p99, one-percent-low (reciprocal of mean worst 1% frame time), spike counts, cumulative time above/below target and short-minus-long trend. Mission `dt` stays in milliseconds even below 1ms. Zero, NaN and pauses over 1s are discarded. No frame-time sample is called CPU/GPU time.

16-19: current camera pose/FOV/movement, player/current vehicle/vehicle speed, indoor mask/cab, time/rain/wetness, vehicle count, nearby discovered lights, output dimensions and map ID. Multiple observed scene tags can coexist. Importance and visual value explicitly are heuristics, not occlusion tests. Own vehicle/headlights, behind-camera objects, interaction and caller-confirmed visibility/fog are weighted separately.

20-22,43,46-49,53: 1s/5s/20s controllers. Three seconds of sustained overload are needed for reductions, eight seconds of reserve for increases. Single spikes do not trigger changes. Per-setting locks/manual state are respected. Current user profile caps default automatic distance targets. Budget subtracts a safety margin and distributes reserve among ten categories by scene. Reductions use the specified irrelevant-light-to-large-quality ordering, increases select visual benefit/cost. One change per controller tick. Scene/control adapters can supply stable policies. DRS, experimental flags and absent adapters are not silently changed.

44-45: automatic first calibration is eligible after 30s in auto mode with stable reserve. It tests only an unlocked, readable live LOD coefficient, with six seconds baseline, two seconds settling, six seconds measure and restoration. Movement, scene changes, instability, locks, setter/readback failure or external writes abort. Learned per-unit correlations store before/after, frame delta, scene, counts, variance, confidence, map/output-size/target context in modSettings/FS25_Enhanced/learnedCosts.xml. Hardware identity is explicitly unknown unless a verified provider supplies it. One noisy observation is not trusted as a measured prediction. User can manually request a calibration.

50: temporary Cinematic remembers every available writable control, applies the explicit Cinematic profile, allows module-defined `cinematicValue`, then restores the exact values on timeout, disable or exit. Values changed by another writer since entry are left alone. Restore is checked by readback. Duration defaults to 60s, bounded 1-600s. Ordinary persistent Cinematic preset remains available separately.

54: user-triggered labelled benchmark records actual session samples and scene durations, mean FPS, worst-1%-mean FPS, p99, variance and spikes. Two runs can be compared. Reports explicitly say visual result NOT_TESTED and bottleneck UNKNOWN; no VRAM or CPU/GPU telemetry is fabricated. No weather, camera or gameplay state is altered.

## Integration contract

Add `Core/BudgetAllocator.lua`, `Core/CalibrationManager.lua`, `Core/BenchmarkManager.lua` before `Core/GraphicsGovernor.lua` in modDesc. Governor init/update/reset owns their lifecycle; do not additionally update them from bootstrap.

`FS25E_VisualControls.getControls()` (array or keyed table) provides controls. Each has `id`, `read()`, `write(value)`, `available()`, bounds and step. `isLocked(id)` and `apply(id,value,{automatic=true})` enforce manual overrides. ProfileManager can fall back to existing LOD/shadow managers when the adapter is not loaded. Manual slider UI must not globally disable auto mode merely to adjust one value.

Optional stable control `autoPolicy` keys: cadence FAST/MEDIUM/SLOW, min/max/step, category, visualBenefit, estimatedCostMs, reductionGroup. Valid reduction groups: irrelevantShadows, scattering, ies, particles, farShadows, foliage, lod, terrain, water, quality, drs. A control not in the known safe global list needs an explicit policy. `cinematicValue` is an explicit module-owned safe target.

UI calls: `GraphicsGovernor.startCalibration()`, `CalibrationManager.getStatus()`; `GraphicsGovernor.beginCinematic(durationMs)`, `endCinematic()`, `getCinematicStatus()`; `BenchmarkManager.start(label,durationMs)`, `finish()`, `getStatus()`, `getReport()`, `getReports()`, `compare(baselineIndex,enhancedIndex)`. Benchmark runs while Enhanced is off as well, permitting a real baseline.

## Limits requiring real engine/assets

Fog density, storm state, dense-vegetation classification, occlusion, true map rendering complexity, render-resolution/upscaler state, hardware identity and CPU/GPU/VRAM sensors are not invented. Display dimensions are not asserted to equal the internal upscaled render resolution. Discovered light count indicates candidate light sources, not a guaranteed count of illuminated shadow casters. Scene-dependent allocation has useful measured inputs but cannot know every renderer cost.

A Lua benchmark cannot certify visual differences; functional mock tests cannot pass visual, performance or compatibility gates. The requested day/night/rain/fog/cab/4x-map benchmark matrix still requires actual gameplay runs on those maps. Engine-native changes remain the responsibility of verified module adapters.

## Validation

`lua53 work/test_core_adaptive.lua`: 14 focused tests, passed. Covers ring bounds, fractional dt, three windows, one percent lows, current FS25 player/rain/cab, stale state, importance, budget/safety, reduction priority, calibration success/cancel/ownership/locks, benchmark metrics, sustained controller pressure and lock isolation, Cinematic restore.

`lua53 work/test_repairs.lua work/FS25_Enhanced`: original 9 repair regression tests passed after the core changes. These are unit/integration simulations, not in-game visual validation.

## Additional compatibility, UI and profile work

CompatibilityManager now enumerates only `g_modIsLoaded[name] == true`. An installed ModManager entry is not evidence that a mod is active. GDN FS25 TypeManager explicitly distinguishes this: https://gdn.giants-software.com/documentation_scripting_fs25.php?category=77&class=615&version=script . Utility mods are never blacklisted. Adapter checks record API presence/availability without invoking unknown native signatures. Two consecutive ownership readback mismatches pause only the affected automatic setting; writer identity remains UNKNOWN. Governor owns its 1Hz update. ModSettings target FPS validates numeric 15-240, preserves valid legacy 40/50 values, rejects NaN/Inf and updates the monitor when changed or loaded. Simple choices are 30/60/90/120; live control allows every integer.

RuntimeControls provides enabled, profile, adaptive, temporary Cinematic, target and debug-HUD controls. Configuration controls have `noGlobalRestore`, `noCinematic` and `runtimeControl` metadata. They must be excluded from a global graphics restore to avoid recursively changing governor state. Native-engine quality restoration does not silently reset UI preferences.

The native menu extension is a new Enhanced Graphics page inside the original InGameMenu, not a private patch into an unavailable graphics-settings frame class. The page uses GIANTS GUI profiles, four native selectors and twelve category buttons. GDN documents this extensibility expressly: https://gdn.giants-software.com/documentation_scripting_fs25.php?category=43&class=462&version=engine and the exact `TabbedMenu:addPage` contract: https://gdn.giants-software.com/documentation_scripting_fs25.php?category=43&class=491&version=engine . `Gui:loadGui(..., true)` registers a frame; `getScreenInstanceByClass(InGameMenu)` resolves the stock menu. AddPage normalization uses a 1024 reference UV rectangle for a full texture. FocusManager is restored after loading. The page persists across mission reload and is toggled via `setPageEnabled`; no private button list is overwritten. Category handoff waits for the native menu/dialog to close before showing the live overlay. Actual runtime registration status is exposed; missing APIs retain F9 fallback. Mock attachment and exact SDK-profile/focus-link checks pass, but actual displayed geometry has not been rendered by the game.

Integration order: after RuntimeControls/other providers register, call `GraphicsMenuIntegration.init`; update it each mission frame; reset before GUI teardown. Call `Governor.endCinematic` BEFORE saving ModSettings on mission deletion, then save, then disable/reset the governor, then restore/reset native/module controls. Otherwise the temporary Cinematic choice could be saved as the next session's normal profile.

Profiles now affect actual local shadow configuration, rather than only distance coefficients:

| Profile | Global/local light budget | Near map | Far map | Shadow range |
| --- | --- | --- | --- | --- |
| Performance | 4 | 512 | 256 | 60 m |
| Balanced | 6 | 1024 | 512 | 90 m |
| Quality | 8 | 2048 | 512 | 130 m |
| Cinematic | 12 | 2048 | 1024 | 160 m |

Local light relevance, IES/scattering counts and softness also vary conservatively. No global ambient multiplier or experimental water/material changes are imposed by presets. Only compatible discovered lights are touched. Missing local assets queue targets for bounded 1Hz availability checks, without repeatedly calling native setters. A successful or real failed setter is not retried indefinitely. Module and VisualControls locks both win over profile selection. ProfileManager.update is called by the governor after the temporary-Cinematic gate and before normal decisions. Local shadow/IES/scattering budgets have FAST policies, shadow range MEDIUM, map resolutions SLOW. The VisualControls automatic path must call provider.setAuto to retain module cadence.

Additional passing suites: `work/test_core_runtime.lua` (six controls plus profile scalar/lock boundary), `work/test_core_compatibility.lua` (3 cases), `work/test_core_native_menu.lua` (3 cases, plus separate SDK XML/profile/focus validation), and `work/test_core_light_profiles.lua` (2 coupled-profile/deferred-target cases). These tests still do not satisfy the plan's visual/performance/map-compatibility gates without in-game runs.


## Final lifecycle audit

The actual governor, runtime provider, visual catalog, native applier and A/B profiles are exercised together by `work/test_core_real_ab.lua` (45 assertions, native boundaries simulated). A/B preserves the exact enhanced snapshot without preset replay and blocks runtime mutations during original preview. Disabling restores native originals; selecting a preset while disabled only selects it. Disabling adaptive control cancels pending writes from earlier profiles, while a later explicit preset may enqueue its own unavailable lights. Screenshot mode prevents automatic preset replay, restores its previous values, and excludes calibration/A/B. Calibration and screenshot restores synchronize ownership readback to avoid false foreign-writer conflicts.

The simple native dialog includes exact custom FPS values from 15–240 in its local option list; it does not mutate the shared schema. UTF-8 tooltip source is retained without byte truncation. Its footer uses the installed FS25 `TextElement` profile properties `textMaxNumLines=4` and `textLayoutMode=fill`, with a 60px footer. The engine owns final wrapping/clipping; real FS25 layout remains unverified. `work/test_core_simple_menu.lua` covers 15/60/144/165/240 and full Japanese tooltip text. Source: installed FS25 `dataS/scripts/gui/elements/TextElement.lua`, `loadProfile` and `setText`; native UTF-8 text metrics: https://gdn.giants-software.com/documentation_scripting_fs25.php?category=30&function=842&version=engine .
