# FS25 Enhanced – controls and tuning guide

FS25 Enhanced is designed around one idea: there is no single “best” graphics configuration for every player, map and computer. The standard game menu bundles many decisions into a few quality levels. This mod opens additional reachable controls so that you can decide which visual features deserve more or less of your system's available performance.

## Start with the result you want

Before moving every slider upward, decide what you actually notice while playing:

- clearer shadows close to the player or vehicle
- longer view distance and fewer visible LOD transitions
- stronger night lighting and lamp definition
- a wetter, more reflective environment
- different material and paint response
- denser atmosphere or more visible sun light shafts
- a cleaner image with fewer secondary effects

Raise the settings that support that result and leave unrelated systems at lower values or Vanilla. Maximum values are primarily useful for comparison, screenshots or testing; they are not automatically the best gameplay configuration.

## Quick quality levels and manual controls

The Low, Medium, High, Very High and Ultra levels provide starting points for the general rendering workload. They can adjust groups such as view distance, shadows, light budgets, SSAO and reflections.

They deliberately do not remove manual choice. Visual preferences such as paint response, wetness, color, field of view and lighting moods remain separate. After selecting a quality level, refine only the categories that matter to you.

## Control areas

### Shadows

Shadow settings can have a large visual and performance impact. Higher resolution and larger budgets can improve definition, especially around vehicles, buildings and lights, but distant or numerous shadow sources can become expensive. Prefer the visible area around the player before spending performance on details that are rarely noticed.

### Lights and lamps

These controls influence reachable properties of existing lights. Their effect depends on whether a vehicle, placeable or map object provides the required light, shadow, IES or scattering path. The mod cannot create missing light assets universally.

### Environment and atmosphere

Environment controls shape the existing sun, lighting mood, scattering and atmospheric paths. Some effects depend on the map's environment and the game's volumetric quality. A control may therefore be available on one map and unavailable on another.

### View distance and LOD

Longer distances can reduce visible object or vegetation transitions, but they can also increase CPU and GPU workload over a large part of the scene. Increase them gradually and evaluate the busiest farm, forest or town you normally play in.

### Materials, paint, water and wetness

Material controls operate only on compatible shaders and parameters already present in the game or asset. They preserve excluded material types where the project cannot apply a safe and predictable change. Wetness, puddle, water and reflection controls likewise depend on existing map and shader support; they do not add a new fluid or puddle simulation.

### Vegetation

Vegetation settings can affect display distance and reachable shader properties. Dense crops, forests and mod maps may react differently. Test these controls in the scene where their effect matters instead of judging them only in an empty field.

### Image, camera and mirrors

Available image controls use existing game-setting or shader paths. Upscalers, anti-aliasing and heavy resource-changing options remain in the normal game menu. Camera and mirror choices can alter both presentation and workload, so they remain independent from purely artistic effects.

## Compare, change and restore

Use **MOD / VANILLA** or **Alt+F9** to compare the current configuration with the captured original values. This is the most reliable way to judge whether a change is actually visible and useful to you.

Change one category at a time. If several settings are altered together, it becomes difficult to identify which option caused an improvement, an unwanted look or a performance problem. **Reset tab** returns only the open category, allowing the rest of the configuration to remain intact.

## Availability and hidden controls

FS25 Enhanced checks for the required engine function, game setting, shader parameter or asset path. Unavailable controls are hidden by default so the panel does not present sliders that cannot work in the current situation.

You can display unavailable controls to see the reason. Typical causes include:

- the current game version does not expose the required function,
- the map or asset does not contain the required shader or profile,
- the setting cannot be read back or restored safely,
- the option is intentionally kept in the game's main graphics menu.

## Performance expectations

FS25 Enhanced provides choices; it cannot guarantee a specific frame rate. The cost of a setting changes with resolution, map, vehicles, weather, camera position and other mods. Stable frame times are usually more useful than a short peak-FPS result.

Test settings during real gameplay and in demanding scenes. If the game becomes uneven, first reduce expensive options that contribute little to the visible scene rather than lowering every category together.

## What the mod cannot do

The project stays within reachable Lua/XML, engine-setting, shader and asset paths. It does not add a new renderer, ray tracing, binary injection, universal new reflections, new map geometry or effects for which the underlying game assets do not exist. Experimental and development documents must not be interpreted as guarantees for the current release.
