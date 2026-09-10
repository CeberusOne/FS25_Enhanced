# Settings API (GUI / Core facade)

**Version:** 0.3.2.0  
**Module:** `scripts/Core/SettingsAPI.lua`  
**Defaults:** `governorEnabled`, `autoApply`, `softApply`, `expertMode`, `adaptive` = **false**

## GUI may call only

| API | Purpose |
|-----|---------|
| `FS25E_SettingsAPI.get/set(key, value)` | Persistable keys via ModSettings |
| `FS25E_SettingsAPI.load/save()` | `modSettings/FS25_Enhanced/settings.xml` |
| `FS25E_SettingsAPI.selectPreset(name)` | Cache requested slots |
| `FS25E_SettingsAPI.applySelectedPreset()` | Wave-1 apply if governor enabled |
| `FS25E_SettingsAPI.setEnabled/getEnabled` | GraphicsGovernor |
| `FS25E_SettingsAPI.setAutoApply/getAutoApply` | GraphicsGovernor |
| `FS25E_SettingsAPI.setExpertMode/getExpertMode` | CapabilityRegistry gate |
| `FS25E_SettingsAPI.getActivePreset/listPresets` | Presets |

**No engine setters from GUI.** Experimental caps only when `expertMode=true`.

## Keys

`governorEnabled`, `autoApply`, `softApply`, `expertMode`, `adaptive`, `activePreset`, `targetFps`
