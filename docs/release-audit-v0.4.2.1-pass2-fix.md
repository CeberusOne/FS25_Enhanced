# Release audit v0.4.2.1 — pass2 fix

HIGH blockers addressed on branch `fix/release-0.4.2.1-metadata-l10n`:

1. **Version alignment**
   - `FS25_Enhanced.VERSION` → `0.4.2.1`
   - `scripts/FS25_Enhanced.lua` already had `FS25_Enhanced.VERSION = "0.4.2.1"`
   - `modDesc.xml` `<version>` already `0.4.2.1`; description bumped from v0.3.3.0 copy to v0.4.2.1 features

2. **README** bumped from 0.3.0.0 → 0.4.2.1 with concise feature list (GUI tabs, Wave-1, Expert live overlay, Pro HUD, diagnostics, expert gating, adaptive/autoApply off, MP client-local).

3. **Missing schema l10n** added to `l10n/l10n_en.xml` and `l10n/l10n_de.xml`:
   - `FS25E_SETTING_EXPERT_SOFT_APPLY`
   - `FS25E_SETTING_PERSIST_HW`
   - `FS25E_WARN_PERSIST_HW`
   - `FS25E_SETTING_EXPERT_SHADOW_FOCUS_BOX`
   - `FS25E_SETTING_EXPERT_FAST_SHADOW_UPDATE`
   - `FS25E_SETTING_EXPERT_RAIN_SHALLOW`
   - `FS25E_SETTING_EXPERT_SSR`
   - `FS25E_SETTING_EXPERT_ATMOSPHERE`
   - `FS25E_SETTING_EXPERT_DRS`
   - `FS25E_SETTING_EXPERT_RAIN_SUITE`

Schema reuses these keys as `tooltip` (no separate `*_TOOLTIP` entries required for this set).
