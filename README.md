# FS25_Enhanced

**Autor:** CeberusOne  
**Version:** 0.4.0.0 (Gen-1 release candidate)

Adaptives Graphics-/Optimierungs-Mod für Farming Simulator 25 (Giants Engine 10 / Lua). Der Mod steuert Grafik- und Performance-Einstellungen über dokumentierte Engine-Setter (kein Binary-Hooking).

## Status

**Gen-1 release candidate (v0.4.0.0)** — Settings API, GUI, Diagnostics on `main`:

- Settings API + ModSettings persist (session defaults; no engine setters from GUI)
- Gen-1 Settings GUI (Simple / Advanced / Expert / Status)
- Diagnostics (CapStatus / ring log / getSnapshot)
- Wave 1 CONFIRMED managers + Phase 2 Governor/Scene (desired state only)
- Defaults: `enabled`, `autoApply`, `softApply`, `expertMode` = **false**
- **Experimental** capabilities remain behind `expertMode` (PR #13 may still be merging — see [docs/RELEASE_0.4.md](docs/RELEASE_0.4.md))

**Not automatic:** live adaptive apply of engine setters. Soft-Apply and Expert Mode stay off until the user opts in. No EXPERIMENTAL/GATED/RESTART writers without expert gate; no `saveHardwareScalability` without opt-in.

## Dokumentation

- [Release 0.4 notes](docs/RELEASE_0.4.md)
- [Settings API](docs/SETTINGS_API.md)
- [Capability hooks](docs/CAPABILITY_HOOKS.md)
- [Diagnostics](docs/diagnostics.md)
- [Release checklist v0.4](docs/release-checklist-v0.4.md)
- [Wave-1 smoke checklist](docs/wave1-smoke-checklist.md)
- [Phase 2 Governor + Scene](docs/PHASE2.md)
- [Wave 1 CONFIRMED wiring](docs/WAVE1.md)
- [Phase 1 notes](docs/PHASE1.md)
- [Capability matrix](docs/capability-matrix.md)
- [Settings schema (GUI prep)](docs/settings-schema.md)
- [GUI design stub](docs/gui-design.md)
- [Optimaler Plan](docs/optimal-plan.md)
- [Änderungen](docs/aenderungen.md)
- [Community-Optimierungen](docs/community-optimizations.md)
- [GDN / Giants Engine Research](docs/gdn-research.md)

## Install (dev)

Copy or symlink this folder into your FS25 `mods/` directory as `FS25_Enhanced`. Enable in the mod selection screen. Check `log.txt` for `[FS25_Enhanced]` lines on mission start/end (SceneAnalyzer / GraphicsGovernor slow ticks).
