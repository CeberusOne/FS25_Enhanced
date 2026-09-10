# FS25_Enhanced — Release 0.4.0.0

**Status:** Gen-1 release candidate  
**Tag target:** `0.4.0.0`  
**Note:** Experimental PR [#13](https://github.com/CeberusOne/FS25_Enhanced/pull/13) may still be merging. Merge this release PR **after** #13 lands, or rebase onto `main` once #13 is in. This bump does **not** ship Experimental code itself.

## What's in (on `main`)

- **Settings API** + ModSettings persist — GUI/Core facade only ([SETTINGS_API](SETTINGS_API.md))
- **Gen-1 Settings GUI** — Simple / Advanced / Expert / Status tabs
- **Diagnostics** — CapStatus, ring log, snapshot ([diagnostics](diagnostics.md))
- **Capability hooks / registry** — Wave-1 CONFIRMED path ([CAPABILITY_HOOKS](CAPABILITY_HOOKS.md))
- Phase 2 Governor + SceneAnalyzer (desired state; apply gated)
- Soft-Apply / Expert Mode flags present; Experimental caps stay behind `expertMode`

## Defaults (all false unless user opts in)

| Key | Default |
|-----|---------|
| `enabled` | `false` |
| `autoApply` | `false` |
| `softApply` | `false` |
| `expertMode` | `false` |

No engine setters from the GUI. No auto hardware persist.

## Docs

| Doc | Path |
|-----|------|
| Settings API | [SETTINGS_API.md](SETTINGS_API.md) |
| Capability hooks | [CAPABILITY_HOOKS.md](CAPABILITY_HOOKS.md) |
| Diagnostics | [diagnostics.md](diagnostics.md) |
| Release checklist | [release-checklist-v0.4.md](release-checklist-v0.4.md) |
| Wave-1 smoke | [wave1-smoke-checklist.md](wave1-smoke-checklist.md) |

## Smoke checklist (short)

1. **Load** — SP map; mod loads; `[FS25_Enhanced]` in `log.txt`; no script crash.
2. **Defaults** — Log / settings show `enabled=false`, `autoApply=false`, `softApply=false`, `expertMode=false`.
3. **GUI** — Ctrl+E (or binding) opens Gen-1 dialog without white-box; tabs switch; no engine setters fired from UI alone.
4. **Diagnostics** — CapStatus / ring log readable (console or Status tab) without apply.
5. **Policy** — Leave Adaptive/Preset/Soft/Expert off; confirm no unintended setter traffic.
6. **Full path** — Follow [release-checklist-v0.4.md](release-checklist-v0.4.md) and [wave1-smoke-checklist.md](wave1-smoke-checklist.md) before tagging.
