# FS25_Enhanced — Wave 2 Candidates (Research Freeze)

**GDN LuaDoc:** Script/Engine **v1.20.0.0**  
**Rule:** Only exact symbols found on official GDN pages. No speculative APIs.  
**Date:** 2026-09-10  
**Scope:** Lights-spec probe, Particle budgets, GATED / ASSET_DEPENDENT shortlist, EXPERIMENTAL out-of-wave2 reminder  
**Source matrix:** `docs/capability-matrix.md` (not modified by this doc)

---

## Status legend

| Status | Meaning |
|--------|---------|
| **CONFIRMED** | Exact symbol(s) on GDN LuaDoc page(s) for v1.20.0.0 |
| **GATED** | Symbol exists; runtime `getSupports*` (or equivalent) must pass before set |
| **ASSET_DEPENDENT** | API exists; usable only when asset/scene provides required nodes/files |
| **EXPERIMENTAL** | Symbol exists; Gen-1 / Welle-1 risky — do **not** wire in wave2 |
| **UNKNOWN** | Gap in LuaDoc for live discovery / restore / applyMode |

---

## 1. Lights-Spec Probe — enumerate RealLights / PlaceableLights

### 1.1 Sources fetched

| Target | GDN URL | Result |
|--------|---------|--------|
| **Lights** (vehicle specialization) | https://gdn.giants-software.com/documentation_scripting_fs25.php?version=script&category=78&class=691 | **CONFIRMED** — full class page |
| **PlaceableLights** | https://gdn.giants-software.com/documentation_scripting_fs25.php?version=script&category=78&class=746 | **CONFIRMED** — found via Specializations sidebar (cat 78), not cat 78 index-only scrape |
| Engine Lighting (IES context) | https://gdn.giants-software.com/documentation_scripting_fs25.php?version=engine&category=11&function=206 | Cross-ref only |

### 1.2 Exact symbols — vehicle `Lights` (class 691)

| Symbol | Kind | Notes from LuaDoc source |
|--------|------|--------------------------|
| `Lights` | specialization | "Specialization providing various types of lights (regular, work, brake, reverse, beacon, turn) to vehicles" |
| `self.spec_lights` | spec table | Used throughout |
| `spec.realLights` | table | Built in `onLoad` |
| `spec.realLights.low` | nested setup | Loaded via `loadRealLightSetup(..., "vehicle.lights.realLights.low", ...)` |
| `spec.realLights.high` | nested setup | Loaded via `loadRealLightSetup(..., "vehicle.lights.realLights.high", ...)` |
| `Lights.loadRealLightSetup` | function | Fills `defaultLights`, `topLights`, `bottomLights`, `brakeLights`, `reverseLights`, `turnLightsLeft`, `turnLightsRight`, `interiorLights` via `RealLight.loadLightsFromXML` |
| `Lights.getRealLightFromNode` | function | Walks `for _, profile in pairs(spec.realLights) do for _, lights in pairs(profile) do for _, realLight in ipairs(lights) do if realLight.node == node` |
| `Lights.getStaticLightFromNode` | function | Analogous walk over `spec.staticLights` |
| `Lights.getUseHighProfile` | function | `g_gameSettings:getValue(GameSettings.SETTING.LIGHTS_PROFILE)` then `Platform.gameplay.lightsProfile`; returns `lightsProfile >= GS_PROFILE_HIGH` |
| `Lights.onLightsProfileChanged` | function | Iterates all `spec.realLights` profiles → `realLight:onLightsProfileChanged(lightsProfile)`; then `setLightsTypesMask(..., true, true)` |
| `Lights.onLoad` | lifecycle | Builds `spec.realLights.low/high`, static lights, beacons; **subscribes** `MessageType.SETTING_CHANGED[GameSettings.SETTING.LIGHTS_PROFILE]` → `onLightsProfileChanged`; also `REAL_BEACON_LIGHTS` → `onLightsRealBeaconLightChanged` |
| `Lights.onDelete` | lifecycle | Deletes shared/beacon lights, releases i3d shared loads, clears compounds/samples — **does not** explicitly wipe `spec.realLights` tables in listed source |
| `Lights.onLoadFinished` | lifecycle | `applyAdditionalActiveLightType` + `realLight:finalize()` per profile |
| `GameSettings.SETTING.LIGHTS_PROFILE` | setting key | Used in `getUseHighProfile`, `consoleCommandProfile`, message subscribe |
| `g_gameSettings:getValue` / `setValue` | globals (in source) | Console toggles LOW vs VERY_HIGH profile |
| `GS_PROFILE_HIGH`, `GS_PROFILE_LOW`, `GS_PROFILE_VERY_HIGH` | constants (in source) | Profile thresholds |
| `Lights.registerRealLightSetupXMLPath` | XML schema | Registers `vehicle.lights.realLights.low/high` paths |

**Active profile selection (CONFIRMED in `setLightsTypesMask` / `setTurnLightState`):**

```text
activeLightSetup = spec.realLights.low
if self:getUseHighProfile() then
  activeLightSetup = spec.realLights.high
end
-- only activeLightSetup receives lightsTypesMask; other profile gets mask 0
```

### 1.3 Exact symbols — `PlaceableLights` (class 746)

| Symbol | Kind | Notes from LuaDoc source |
|--------|------|--------------------------|
| `PlaceableLights` | specialization | "Specialization for placeables" |
| `self.spec_lights` | spec table | Same name as vehicle Lights |
| `spec.groups` | array | Light groups (`placeable.lights.group`) |
| `spec.sharedLights` | array | Shared light i3d loads |
| `spec.lightShapes` | array | Self-illum shader faces (`lightControl`) |
| `spec.realLights` | table | `{ low = {}, high = {} }` — **flat arrays** of `{ node, groupIndex }`, not vehicle nested type buckets |
| `placeable.lights.realLights.low.light` / `.high.light` | XML paths | `#node`, `#groupIndex` |
| `PlaceableLights.getUseHighProfile` | function | Same pattern as vehicle: `GameSettings.SETTING.LIGHTS_PROFILE` / `Platform.gameplay.lightsProfile`; returns `>= GS_PROFILE_HIGH` |
| `PlaceableLights.lightSetupChanged` | function | Re-applies `updateLightState` for every group |
| `PlaceableLights.updateLightState` | function | Picks `spec.realLights.low` vs `.high` via `getUseHighProfile()`; `setVisibility` on active/inactive setups; shader `lightControl` for manual groups |
| `PlaceableLights.onLoad` | lifecycle | Builds groups, shared lights, lightShapes, realLights; **subscribes** `MessageType.SETTING_CHANGED["lightsProfile"]` → `lightSetupChanged` |
| `PlaceableLights.onDelete` | lifecycle | Releases shared lights, unsubscribes message center, removes activatable/triggers |
| `PlaceableLights.onFinalizePlacement` | lifecycle | Calls `lightSetupChanged()` |
| `PlaceableLights.setGroupIsActive` | function | Toggles group + `updateLightState` + `PlaceableLightsStateEvent` |
| `PlaceableLights.registerEventListeners` | registration | `onLoad`, `onDelete`, `onWriteStream`, `onReadStream`, `onFinalizePlacement` |

**Note:** Placeable path uses message key string `"lightsProfile"` in subscribe source, while vehicle Lights uses `GameSettings.SETTING.LIGHTS_PROFILE`. Both are **CONFIRMED** as written in LuaDoc listings; do not invent a unified key beyond what each class shows.

### 1.4 Recommended enumeration path (prefer Spec over blind node scan)

**CONFIRMED preferred path for a mod probe:**

1. **Vehicles with Lights spec**
   - Guard: `vehicle.spec_lights ~= nil` (and preferably Lights functions present, e.g. `getRealLightFromNode`).
   - Enumerate: `for profileName, profile in pairs(spec.realLights) do` → `for bucketName, lights in pairs(profile) do` → `for _, realLight in ipairs(lights) do` use `realLight.node` (and any RealLight fields already on the object).
   - Lookup by node: `vehicle:getRealLightFromNode(node)` (**CONFIRMED**).
   - Profile awareness: call `vehicle:getUseHighProfile()`; treat `low` vs `high` as alternate setups (only one active for mask application).

2. **Placeables with PlaceableLights**
   - Guard: `placeable.spec_lights ~= nil` and placeable Lights API (`updateLightState` / `getUseHighProfile`).
   - Enumerate: `ipairs(spec.realLights.low)` and `ipairs(spec.realLights.high)` → `realLight.node`, `realLight.groupIndex`.
   - Also available (not RealLight engine lights): `spec.lightShapes`, `spec.sharedLights` (shader / shared assets).

3. **Avoid** blind scene/node class-id scans as the primary path — LuaDoc gives structured `spec.realLights` on both specializations.

### 1.5 Lifecycle hooks & restore implications

| Hook | Vehicle Lights | PlaceableLights | Probe implication |
|------|----------------|-----------------|-------------------|
| Load | `onLoad` (+ `onLoadFinished` finalize) | `onLoad` (+ `onFinalizePlacement` → `lightSetupChanged`) | Safe to enumerate after load/finalize |
| Profile change | `onLightsProfileChanged` via `SETTING_CHANGED[LIGHTS_PROFILE]` | `lightSetupChanged` via `SETTING_CHANGED["lightsProfile"]` | **Must** re-resolve active low/high after profile change; cached node lists may still be valid but active set swaps |
| Delete | `onDelete` | `onDelete` (+ unsubscribe) | Drop all handles; nodes may be invalid |
| Restore | Not a dedicated API | Not a dedicated API | If mod mutates engine light props on `realLight.node`, cache originals at first touch; re-apply after profile change; clear on delete |

**applyMode:** **UNKNOWN** for per-light engine mutations (matrix rule: do not guess LIVE). Profile setting itself is a game setting change with message-center fan-out (**CONFIRMED** subscribe pattern).

### 1.6 Probe status summary

| Item | Status |
|------|--------|
| Vehicle `spec.realLights.low/high` structure + load path | **CONFIRMED** |
| `getRealLightFromNode` / `getUseHighProfile` / `onLightsProfileChanged` | **CONFIRMED** |
| `GameSettings.SETTING.LIGHTS_PROFILE` + `g_gameSettings` usage in Lights source | **CONFIRMED** |
| PlaceableLights class + `spec.realLights.low/high` arrays | **CONFIRMED** (class 746) |
| Placeable `lightSetupChanged` / `updateLightState` profile swap | **CONFIRMED** |
| Dedicated global registry of all RealLights in mission | **UNKNOWN** / not found — enumerate per vehicle/placeable with spec |
| Engine-side “list all lights” free function | **NOT FOUND** on Lighting cat 11 list used by matrix |

---

## 2. Particle Budgets

### 2.1 Engine Particle System (category 18)

**Category URL:** https://gdn.giants-software.com/documentation_scripting_fs25.php?version=engine&category=18

| API | Fn id | Signature (LuaDoc) | Status |
|-----|-------|--------------------|--------|
| `setEmitCountScale` | 414 | `setEmitCountScale(entityId particleSystemId, float countScale)` | **CONFIRMED** |
| `getEmitCountScale` | 393 | `getEmitCountScale(entityId particleSystemId)` → `float countScale` | **CONFIRMED** |
| `setMaxNumOfParticles` | 420 | `setMaxNumOfParticles(entityId particleSystemId, integer maxNumParticles)` | **CONFIRMED** |
| `getMaxNumOfParticles` | 398 | `getMaxNumOfParticles(entityId particleSystemId)` → `integer maxNumParticles` | **CONFIRMED** |

**Doc note (repeated on these pages):**  
> The particleSystemId can be retrieved by using `getGeometry()` on the shape/node

That is the **only** official discovery hint on the Engine Particle System pages for obtaining `particleSystemId`.

### 2.2 Script helper layer — `ParticleUtil` (Utils cat 90, class 874)

| API | Signature (LuaDoc) | Status |
|-----|--------------------|--------|
| `ParticleUtil.setEmitCountScale` | `(table particleSystem, float scale)` | **CONFIRMED** — table wrapper, not raw entityId |
| `ParticleUtil.setMaxNumOfParticlesToEmitScale` | `(table particleSystem, number scale)` | **CONFIRMED** — **different name** from Engine `setMaxNumOfParticles` |
| `ParticleUtil.setEmittingState` | `(table particleSystem, boolean state, ...)` | **CONFIRMED** |
| `ParticleUtil.loadParticleSystemFromNode` | `(entityId rootNode, table particleSystem, ...)` | **CONFIRMED** |
| `ParticleUtil.copyParticleSystem` | returns `entityId currentPS` | **CONFIRMED** |

### 2.3 Specialization mentioning particles — `WorkParticles` (cat 78, class 834)

| Symbol | Status | Relevance |
|--------|--------|-----------|
| `WorkParticles` | **CONFIRMED** | "Specialization for adding various particles to vehicles while working" |
| `self.spec_workParticles` | **CONFIRMED** | Client-side tables: `particles`, `particleAnimations`, `effects` |
| `spec.particles` → `particle.mappings` | **CONFIRMED** | Each mapping has `particleSystem` (table), `particleNode`, `node`, `groundRefNode` |
| `ParticleUtil.loadParticleSystemFromNode(mapping.particleNode, mapping.particleSystem, ...)` | **CONFIRMED** in `groundParticleI3DLoaded` | Fills table from node |
| `ParticleUtil.setEmittingState(mapping.particleSystem, ...)` | **CONFIRMED** in update path | Toggle emit |
| Direct Engine `setEmitCountScale` / `setMaxNumOfParticles` in WorkParticles source | **NOT FOUND** in listed WorkParticles methods | Budget scaling would be mod-side |

### 2.4 What is UNKNOWN about discovering emitter IDs in a live mission

| Question | Finding |
|----------|---------|
| Global “list all particle systems” engine API | **NOT FOUND** on Particle System category list |
| How `getGeometry(shape/node)` maps to WorkParticles `mapping.particleSystem` table fields | **UNKNOWN** in LuaDoc — Engine docs say use `getGeometry` on shape/node; ParticleUtil APIs take a **table**; no documented field name bridging table → entityId on WorkParticles page |
| Mission-wide enumeration without walking vehicles/effects | **UNKNOWN** |
| Safe restore defaults for max particle counts | Getters exist (`getEmitCountScale`, `getMaxNumOfParticles`) — **CONFIRMED**; still need per-id cache policy |

### 2.5 Recommended Gate

| Tier | What | Gate |
|------|------|------|
| **CONFIRMED API** | `setEmitCountScale` / `getEmitCountScale` / `setMaxNumOfParticles` / `getMaxNumOfParticles` on a known `particleSystemId` | Call only when `particleSystemId` already obtained via documented `getGeometry(node)` (or ParticleUtil table APIs when holding a WorkParticles/Effect `particleSystem` table) |
| **EXPERIMENTAL discovery** | Blind node walk + `getGeometry` hoping for particle geometries; scraping arbitrary vehicles’ `spec_workParticles` without lifecycle ownership | Allowed for **research probes only** — not Welle-1 wiring; must tolerate nil/0 geometry and unsubscribe on delete |

**Wave2 stance:** Document budgets as **CONFIRMED setters/getters + EXPERIMENTAL discovery**. Do not promote mission-wide particle budget automation until discovery path is proven in a controlled probe.

---

## 3. GATED + ASSET_DEPENDENT shortlist (from capability-matrix)

> **NOT for Welle-1.** Wave2 candidates only after Core promotion criteria below.

### 3.1 GATED (matrix status)

| capabilityId | apiName | Paired support check | Matrix notes | When Core may promote | Required runtime checks |
|--------------|---------|----------------------|--------------|----------------------|-------------------------|
| `ssr-quality` | `setScreenSpaceReflectionsQuality` | `getSupportsScreenSpaceReflectionsQuality` | SettingsModel `addManagedSettings` | After Welle-1 LIVE/RELOAD smoke on CONFIRMED SettingsModel writers; UI toggle behind support gate | `getSupportsScreenSpaceReflectionsQuality()` must be true before set; read back via `getScreenSpaceReflectionsQuality`; respect `needsRestartToApplyChanges` if set |
| `supports-ssr-quality` | `getSupportsScreenSpaceReflectionsQuality` | (gate only) | SettingsModel | Ship with SSR setter as prerequisite helper | N/A (read-only gate) |
| `atmosphere-quality` | `setAtmosphereQuality` | `getSupportsAtmosphereQuality` | SettingsModel | Same as SSR | `getSupportsAtmosphereQuality()` before set; getter verify |
| `supports-atmosphere-quality` | `getSupportsAtmosphereQuality` | (gate only) | SettingsModel | With atmosphere setter | N/A |
| `drs-quality` | `setDRSQuality` | `getSupportsDRSQuality` | SettingsModel | Same as SSR | `getSupportsDRSQuality()` before set; getter verify |
| `supports-drs-quality` | `getSupportsDRSQuality` | (gate only) | SettingsModel | With DRS setter | N/A |

**Shared GATED rules (from matrix + SettingsModel URL):**

- Source: https://gdn.giants-software.com/documentation_scripting_fs25.php?version=script&category=43&class=486  
- `applyMode`: **UNKNOWN** (except do not assume LIVE)  
- `restoreStrategy`: **YES** for the three setters  
- Promotion blocker: hardware/OS may report unsupported — Core must skip silently or show disabled UI, never call set when support is false

### 3.2 ASSET_DEPENDENT (matrix status)

| capabilityId | apiName | GDN | Why asset-dependent | When Core may promote | Required runtime checks |
|--------------|---------|-----|---------------------|----------------------|-------------------------|
| `light-ies-profile` | `setLightIESProfile` | Engine Lighting fn=206 — *“Set IES Light profile as a path to a *.ies file.”* | Needs valid `lightId` + existing `*.ies` path | After Lights-spec probe proves stable `realLight.node` → light entity mapping; ship IES files or resolve vanilla paths | `lightId` valid; file path exists; prefer getter `getLightIESProfile` before/after; restore previous path |
| `light-ies-cone-angle` | `getLightConeAngleFromIESProfile` | Engine Lighting fn=183 | IES-derived; no setter | Companion read-only to IES profile | Valid IES/light context |
| `foliage-bending-create` | `createFoliageBendingRectangle` | Engine Foliage fn=77 | Needs `foliageBendingSystemId`, rectangle params, `centerTransformid`; destroy via `destroyFoliageBendingObject` | Only if mod owns transforms and foliage bending system handle from scene | Non-nil system id; store `rectangleId`; always destroy on cleanup; optional `get/setFoliageBendingRectangleAttributes` |

**Related Foliage cat 6 symbols (CONFIRMED on category page, matrix partially lists create):**

- `destroyFoliageBendingObject`
- `getFoliageBendingRectangleAttributes`
- `setFoliageBendingRectangleAttributes`
- `setFoliageBendingSystem`
- `addFoliageTypeFromXML`

### 3.3 EXPERIMENTAL — out of wave2 wiring

Do **not** wire these in wave2 feature modules (research/docs only; matrix already marks EXPERIMENTAL):

| capabilityId | apiName | GDN | Risk note (matrix) |
|--------------|---------|-----|---------------------|
| `shadow-focus-box` | `setShadowFocusBox` | Rendering fn=641 | “Set active shadow focus box”; shapeId or 0 to reset — Gen-1 risky |
| `fast-shadow-update` | `setFastShadowUpdate` | Rendering fn=633 | “Set fast shadow update for camera”; true=fast, false=far shadows — Gen-1 risky |
| `rain-shallow-water-simulation` | `setRainShallowWaterSimulation` | Precipitation fn=590 | Ties rain to shallow-water sim — Gen-1 experimental coupling |

Plus particle **EXPERIMENTAL discovery** (section 2.5): no mission-wide emitter harvest in production paths.

---

## 4. Wave2 candidate packaging (docs-only freeze)

| Track | Contents | Welle-1? | Wave2 docs action |
|-------|----------|----------|-------------------|
| A — Lights probe | Spec enumeration of RealLights (vehicle + placeable) | No | Spec-first probe design (this doc §1) |
| B — Particle budgets | Engine setters/getters; gated discovery | No | API confirmed; discovery EXPERIMENTAL (§2) |
| C — GATED quality | SSR / Atmosphere / DRS + `getSupports*` | No | Promote only behind support checks (§3.1) |
| D — ASSET_DEPENDENT | IES + foliage bending | No | Needs assets + owned ids (§3.2) |
| E — EXPERIMENTAL | FocusBox / FastShadowUpdate / RainShallowWater | No | Explicitly **out of wave2 wiring** (§3.3) |

---

## 5. Symbols / pages NOT found (gaps)

| Sought | Result |
|--------|--------|
| PlaceableLights under wrong assumption “category 78 scrape without class” | Index-only URL 422; **found** at **class=746** via Specializations sidebar |
| Mission-global RealLight registry | **NOT FOUND** |
| Engine free-function to list particle systems | **NOT FOUND** |
| WorkParticles documenting `getGeometry` bridge to Engine particleSystemId | **NOT FOUND** (0 hits on class page) |
| ParticleUtil field schema (`particleSystem.geometry` etc.) | **NOT FOUND** on ParticleUtil page — table treated opaquely |
| Unified `onLightsProfileChanged` on PlaceableLights | **NOT FOUND** — placeable uses `lightSetupChanged` instead |
| `applyMode` LIVE/RELOAD for GATED SettingsModel quality writers | Still **UNKNOWN** per matrix |

---

## 6. URL quick index (v1.20.0.0)

| Topic | URL |
|-------|-----|
| Lights (vehicle) | `...?version=script&category=78&class=691` |
| PlaceableLights | `...?version=script&category=78&class=746` |
| WorkParticles | `...?version=script&category=78&class=834` |
| ParticleUtil | `...?version=script&category=90&class=874` |
| SettingsModel | `...?version=script&category=43&class=486` |
| Engine Particle System | `...?version=engine&category=18` |
| `setEmitCountScale` | `...?version=engine&category=18&function=414` |
| `getEmitCountScale` | `...?version=engine&category=18&function=393` |
| `setMaxNumOfParticles` | `...?version=engine&category=18&function=420` |
| `getMaxNumOfParticles` | `...?version=engine&category=18&function=398` |
| Engine Foliage | `...?version=engine&category=6` |
| `setLightIESProfile` | `...?version=engine&category=11&function=206` |
| `setShadowFocusBox` | `...?version=engine&category=22&function=641` |
| `setFastShadowUpdate` | `...?version=engine&category=22&function=633` |
| `setRainShallowWaterSimulation` | `...?version=engine&category=21&function=590` |
