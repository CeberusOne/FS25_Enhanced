# Hover-help / tooltips (v0.4.2.3)

**Branch:** `feature/hover-help-tooltips`  
**Goal:** Player-friendly explanations in Settings Dialog and Expert Live-Overlay — no API jargon.

## Settings Dialog

1. Each option’s Schema `tooltip` key is resolved via `FS25E_SettingsController.getTooltipText(fieldOrId)`.
2. On bind: set Giants `toolTipText` / `setToolTipText` when available.
3. Always update visible footer `helpText` for the focused / highlighted / clicked option (`onHighlight*` + option change).
4. Expert tab also exposes **Persist Hardware** and **Soft Apply** with dedicated `*_TOOLTIP` keys (risk-aware, no engine API names).

## Live Overlay

1. Selected row shows 1–2 lines of help under the list (truncated).
2. Prefer Schema tooltip via `settingId` or `capId` (`getHelpForSettingOrCap`).
3. Fallback: CostCatalog `notes` / `helpL10n`, then lastError.
4. Cost badges / warn tint unchanged (`docs/pro-live-hud-gui.md`).

## Adaptive honesty

EN Adaptive tooltip states clearly that Adaptive protects target FPS by adjusting **Wave-1 presets/shadows/LOD** — **not** every experimental effect. DE matches.

## Constraints

- No engine setters from GUI  
- No Giants Sliders  
- Soft-Apply / Persist remain opt-in (default off)
