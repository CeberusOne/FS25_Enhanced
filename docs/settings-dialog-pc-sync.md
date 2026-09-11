# Settings Dialog — PC sync (v0.4.2.6)

Live MSI folder was ahead of `main` for GUI layout. This sync brings GitHub in line.

## Fixed vs Research audit #31
- `profile="dialogBg"` (not `dialogBgBox`)
- MultiTextOption children `name="left|right|text|title"`
- Profiles `fs25ePanel` / `fs25eMultiText` / `fs25eHint` with `anchorTopCenter`
- `setShowMouseCursor(true)` on open + restore on close
- `fs25eCloseSettings` console helper
- Hotkeys: F9 = Settings, Ctrl+F9 / Shift+F9 = Live Overlay (plus Ctrl+E)
- Live Overlay Expert button sets **both** `expertMode` + `liveTuningEnabled`

## Residual risks after Save-Reload
- Advanced list still dense; may need paging if a FS25 UI scale overflows
- ActionEvent SYSTEM bindings can stay silent — keyEvent F9 fallback is intentional
- Soft-Apply still optional for opening overlay
