# Settings API (GUI / Core facade)

**Version:** 0.3.2.0  
**Modules:** `SettingsAPI.lua` + `ModSettings.lua`  
**Defaults:** `enabled`, `autoApply`, `softApply`, `expertMode`, `adaptive` = **false**

## GUI contract

GUI calls only:
- `FS25E_ModSettings.get/set` (or `FS25E_SettingsAPI.get/set`)
- `FS25E_ProfileManager.selectPreset` (+ `SettingsAPI.applySelectedPreset` when applying)
- `FS25E_GraphicsGovernor.setEnabled` / `setAutoApply` (or SettingsAPI wrappers)

**No engine setters from GUI.**

## Key aliases

| GUI key | Alias |
|---------|-------|
| `enabled` | `governorEnabled` |
| `preset` | `activePreset` |

Also: `autoApply`, `softApply`, `expertMode`, `adaptive`, `targetFps`, plus GUI visual option keys from Gen-1 schema.

## Docs

See `CAPABILITY_HOOKS.md` for APPLIED/REJECTED/SKIPPED listeners.
