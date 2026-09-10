# FS25 Enhanced — Settings-Schema (GUI-Vorbereitung)

> **Status:** Stub / Dokumentation vor Core-Andockung.  
> **Quelle:** Optimalplan P1 UI + CONFIRMED Caps (Shadows / Lighting / LOD-Foliage).  
> **Keine Runtime:** Dieses Dokument und `config/settingsSchema.stub.lua` rufen keine Core-/Governor-Interfaces auf.

---

## Zweck

Schema-getriebene Settings für die spätere GUI (Simple Auto Panel, Advanced Tabs, Live Tuning, Expert-Mode).  
Typen **nur** `bool` | `enum`. **Keine Slider.** Numerische Stufen ausschließlich als Enum-Labels.

---

## Konventionen

| Feld | Bedeutung |
|------|-----------|
| `id` | Stabiler Setting-Identifier (Lua/XML) |
| `type` | `bool` \| `enum` |
| `default` | Default-Wert |
| `options` | Nur bei `enum`: geordnete Option-IDs |
| `i18nKey` / `i18nTooltipKey` | Keys unter `FS25E_*` |
| `section` | `simple` \| `advanced` \| `live` \| `expert` |
| `expertOnly` | Wenn `true`: nur bei Expert-Mode sichtbar |
| `applyMode` | Hinweis `LIVE` / `MED` / `SLOW` (später Governor) |
| `vanillaKeyReuse` | Optional: Vanilla-i18n für Option-Labels |

### i18n-Fallback

1. Aktuelle Spielsprache (`g_i18n`)  
2. Englisch (`en`)  
3. **Nie leer** — fehlender Key → Key-Name als sichtbarer Placeholder + `Logging.warning` (Implementierung später)

Prefix aller Mod-Keys: **`FS25E_`**.

### Vanilla-Wiederverwendung (Labels)

| Verwendung | Vanilla-Keys (üblich) |
|------------|------------------------|
| On / Off | `ui_on` / `ui_off` |
| Low / Medium / High / Ultra | wo vorhanden `setting_*` Quality-Stufen; sonst eigene `FS25E_OPT_*` |
| Yes / No | `ui_yes` / `ui_no` |

Mod-spezifische Titel, Presets, FPS-Stufen und Tooltips bleiben **eigene** `FS25E_*`-Keys.

---

## Sections (Übersicht)

| Section | UI | Inhalt |
|---------|----|--------|
| `simple` | Simple Auto Panel | Mod On/Off, Preset, Target FPS, Adaptive |
| `advanced` | Advanced Tabs (später) | Shadows / Lighting / LOD-Foliage — CONFIRMED Caps |
| `live` | Live Tuning Overlay (Hotkey) | Minimal markiert; volle Optionen später |
| `expert` | Flag + Gate | Expert-Mode; Experimental ausblenden wenn off |

Zusätzlich: **Client-only**-Hinweis (Info, kein Engine-Setter).

---

## Setting-Zeilen

### Simple Auto Panel (`section: simple`)

| id | type | default | options | i18nKey | i18nTooltipKey | expertOnly | applyMode | vanillaKeyReuse |
|----|------|---------|---------|---------|----------------|------------|-----------|-----------------|
| `enabled` | bool | `true` | — | `FS25E_SETTING_ENABLED` | `FS25E_SETTING_ENABLED_TOOLTIP` | false | MED | On/Off → `ui_on`/`ui_off` |
| `preset` | enum | `balanced` | `off`, `balanced`, `quality`, `performance`, `cinematic` | `FS25E_SETTING_PRESET` | `FS25E_SETTING_PRESET_TOOLTIP` | false | SLOW | — (eigene Option-Keys) |
| `targetFps` | enum | `60` | `30`, `40`, `50`, `60`, `unlimited` | `FS25E_SETTING_TARGET_FPS` | `FS25E_SETTING_TARGET_FPS_TOOLTIP` | false | MED | — |
| `adaptive` | bool | `false` | — | `FS25E_SETTING_ADAPTIVE` | `FS25E_SETTING_ADAPTIVE_TOOLTIP` | false | MED | On/Off → `ui_on`/`ui_off` |

**Preset-Option i18n:**  
`FS25E_PRESET_OFF`, `FS25E_PRESET_BALANCED`, `FS25E_PRESET_QUALITY`, `FS25E_PRESET_PERFORMANCE`, `FS25E_PRESET_CINEMATIC`

**Target-FPS-Option i18n:**  
`FS25E_FPS_30`, `FS25E_FPS_40`, `FS25E_FPS_50`, `FS25E_FPS_60`, `FS25E_FPS_UNLIMITED`

---

### Advanced — Shadows (`section: advanced`, Gruppe Shadows)

Platzhalter spiegeln CONFIRMED Caps (`setShadowQuality`, `setMaxNumShadowLights`, `setShadowDistanceQuality`, `setAllowFoliageShadows`, …). Keine Engine-Aufrufe in diesem Stub.

| id | type | default | options | i18nKey | i18nTooltipKey | expertOnly | applyMode | vanillaKeyReuse |
|----|------|---------|---------|---------|----------------|------------|-----------|-----------------|
| `shadowQuality` | enum | `med` | `low`, `med`, `high`, `ultra` | `FS25E_SETTING_SHADOW_QUALITY` | `FS25E_SETTING_SHADOW_QUALITY_TOOLTIP` | false | SLOW | Stufen → `FS25E_OPT_*` (oder Vanilla Quality falls belegt) |
| `shadowDistance` | enum | `med` | `low`, `med`, `high`, `ultra` | `FS25E_SETTING_SHADOW_DISTANCE` | `FS25E_SETTING_SHADOW_DISTANCE_TOOLTIP` | false | SLOW | `FS25E_OPT_*` |
| `maxShadowLights` | enum | `med` | `low`, `med`, `high`, `ultra` | `FS25E_SETTING_MAX_SHADOW_LIGHTS` | `FS25E_SETTING_MAX_SHADOW_LIGHTS_TOOLTIP` | false | MED | `FS25E_OPT_*` |
| `foliageShadows` | bool | `true` | — | `FS25E_SETTING_FOLIAGE_SHADOWS` | `FS25E_SETTING_FOLIAGE_SHADOWS_TOOLTIP` | false | MED | `ui_on`/`ui_off` |

Section-Label: `FS25E_SECTION_SHADOWS`

---

### Advanced — Lighting (`section: advanced`, Gruppe Lighting)

| id | type | default | options | i18nKey | i18nTooltipKey | expertOnly | applyMode | vanillaKeyReuse |
|----|------|---------|---------|---------|----------------|------------|-----------|-----------------|
| `maxLights` | enum | `med` | `low`, `med`, `high`, `ultra` | `FS25E_SETTING_MAX_LIGHTS` | `FS25E_SETTING_MAX_LIGHTS_TOOLTIP` | false | MED | `FS25E_OPT_*` |
| `lightScattering` | enum | `med` | `off`, `low`, `med`, `high` | `FS25E_SETTING_LIGHT_SCATTERING` | `FS25E_SETTING_LIGHT_SCATTERING_TOOLTIP` | false | MED | Off → `ui_off`; Stufen `FS25E_OPT_*` |
| `shadowMerge` | bool | `true` | — | `FS25E_SETTING_SHADOW_MERGE` | `FS25E_SETTING_SHADOW_MERGE_TOOLTIP` | false | SLOW | `ui_on`/`ui_off` |

Section-Label: `FS25E_SECTION_LIGHTING`

---

### Advanced — LOD / Foliage (`section: advanced`, Gruppe LOD)

Distance-Coeffs als Enum-Stufen Low/Med/High/Ultra (keine Float-Slider). Caps: `setViewDistanceCoeff`, `setLODDistanceCoeff`, `setFoliageViewDistanceCoeff`, `setFoliageLODDistanceCoeff`, `setTerrainLODDistanceCoeff`.

| id | type | default | options | i18nKey | i18nTooltipKey | expertOnly | applyMode | vanillaKeyReuse |
|----|------|---------|---------|---------|----------------|------------|-----------|-----------------|
| `viewDistance` | enum | `med` | `low`, `med`, `high`, `ultra` | `FS25E_SETTING_VIEW_DISTANCE` | `FS25E_SETTING_VIEW_DISTANCE_TOOLTIP` | false | MED | `FS25E_OPT_*` |
| `lodDistance` | enum | `med` | `low`, `med`, `high`, `ultra` | `FS25E_SETTING_LOD_DISTANCE` | `FS25E_SETTING_LOD_DISTANCE_TOOLTIP` | false | MED | `FS25E_OPT_*` |
| `foliageViewDistance` | enum | `med` | `low`, `med`, `high`, `ultra` | `FS25E_SETTING_FOLIAGE_VIEW` | `FS25E_SETTING_FOLIAGE_VIEW_TOOLTIP` | false | MED | `FS25E_OPT_*` |
| `foliageLodDistance` | enum | `med` | `low`, `med`, `high`, `ultra` | `FS25E_SETTING_FOLIAGE_LOD` | `FS25E_SETTING_FOLIAGE_LOD_TOOLTIP` | false | MED | `FS25E_OPT_*` |
| `terrainLodDistance` | enum | `med` | `low`, `med`, `high`, `ultra` | `FS25E_SETTING_TERRAIN_LOD` | `FS25E_SETTING_TERRAIN_LOD_TOOLTIP` | false | MED | `FS25E_OPT_*` |

Section-Label: `FS25E_SECTION_LOD`

---

### Live Tuning (`section: live`) — minimal

Später Hotkey-Overlay; hier nur Section-Marker + Platzhalter.

| id | type | default | options | i18nKey | i18nTooltipKey | expertOnly | applyMode | vanillaKeyReuse |
|----|------|---------|---------|---------|----------------|------------|-----------|-----------------|
| `liveTuningEnabled` | bool | `false` | — | `FS25E_SETTING_LIVE_TUNING` | `FS25E_SETTING_LIVE_TUNING_TOOLTIP` | false | LIVE | `ui_on`/`ui_off` |

Titel / Hotkey-Hinweis: `FS25E_LIVE_TUNING_TITLE`, `FS25E_HOTKEY_LIVE_TUNING`

---

### Expert & Meta (`section: expert` / Info)

| id | type | default | options | i18nKey | i18nTooltipKey | expertOnly | applyMode | vanillaKeyReuse |
|----|------|---------|---------|---------|----------------|------------|-----------|-----------------|
| `expertMode` | bool | `false` | — | `FS25E_EXPERT_MODE` | `FS25E_EXPERT_MODE_TOOLTIP` | false | LIVE | `ui_on`/`ui_off` |
| `clientOnlyHint` | bool (display-only info) | `true` | — | `FS25E_CLIENT_ONLY_HINT` | `FS25E_CLIENT_ONLY_HINT_TOOLTIP` | false | — | — |

`expertMode` default **off** → Experimental-Caps (Shadow Focus, Fast Shadow Update, Water/Materials/…) bleiben ausgeblendet bis Expert an.

---

## Gemeinsame Enum-Option-Keys (Qualität)

| Option-ID | i18nKey |
|-----------|---------|
| `low` | `FS25E_OPT_LOW` |
| `med` | `FS25E_OPT_MED` |
| `high` | `FS25E_OPT_HIGH` |
| `ultra` | `FS25E_OPT_ULTRA` |
| `off` (wo als Stufe) | `FS25E_OPT_OFF` bzw. Preset: `FS25E_PRESET_OFF` |

---

## Warnungen / System-Texte (kein Setting-Wert)

| Key | Verwendung |
|-----|------------|
| `FS25E_WARN_EXTREME_COST` | Tooltip/Dialog bei Ultra/Cinematic-Kosten |
| `FS25E_KEY_CONFLICT` | MP/Hotkey-Konflikt-Hinweis |
| `FS25E_MOD_NAME` | Mod-Anzeigename |
| `FS25E_SETTINGS_TITLE` | Dialogtitel |
| `FS25E_SETTINGS_SIMPLE` | Simple-Tab/Panel |
| `FS25E_SETTINGS_ADVANCED` | Advanced-Tab |

---

## applyMode-Hinweise (Schema → später Governor)

| Mode | Bedeutung (Doku) |
|------|------------------|
| `LIVE` | Sofort / nächster Frame; Live-Tuning geeignet |
| `MED` | Innerhalb weniger Frames / Medium-Controller |
| `SLOW` | Langsamer Reapply / Merge / Quality-Wechsel; ggf. spürbare Verzögerung |

Kein Runtime-Binding in diesem Liefergegenstand.

---

## Verboten

- Slider-Typen / kontinuierliche Int-/Float-Widgets  
- Int als freier Zahlenwert (nur Enum-Stufen)  
- Custom GUI-Profiles ohne `extends="fs25_*"`  
- Andocken an Core/Governor bevor Interfaces stehen  

Siehe auch: `docs/gui-design.md`, Stub `config/settingsSchema.stub.lua`.
