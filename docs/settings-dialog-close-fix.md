# Settings Dialog close stuck (v0.4.2.7)

## Symptom
After opening Settings once (F9), OK/Back/Esc appeared to do nothing — fullscreen dimmer stayed; game felt stuck. Workaround: `fs25eCloseSettings`.

## Root cause
`FS25E_SettingsDialog:close()` preferred `MessageDialog.close(self)` and treated **pcall success** as “closed”. That call can no-op without error for dialogs opened via `g_gui:showDialog`, so `closeDialogByName` / `changeScreen(nil)` never ran. Cursor restore was also incomplete on `main`.

## Fix
1. Always run Gui stack dismiss first (`closeDialogByName`, `closeDialog`, `changeScreen(nil)`), then MessageDialog/super close — never gate earlier steps on pcall.
2. Nuclear `showGui("")` if dialog name still current.
3. `onOpen` save + force mouse cursor; `onClose`/`close` restore.
4. F9 toggles close when dialog already visible.
5. Console `fs25eCloseSettings` runs the same multi-path dismiss.

## Files
- `scripts/UI/FS25E_SettingsDialog.lua`
- `scripts/UI/FS25E_Input.lua`
- `scripts/Core/ConsoleCommands.lua` (`closeSettings` only)

## Also in this PR (user follow-ups)
- Live Overlay: ASCII bars `#`/`-` (no █/░ font warnings); mouse cursor on show/hide
- F9 toggle close + Esc closes Settings when visible
- Dual-key: `expertRainShallowWater` aliases to `rainShallowWater` (ModSettings + Controller mirror)
- Honest rain tooltips + Overlay SKIPPED Soft-Apply hint
