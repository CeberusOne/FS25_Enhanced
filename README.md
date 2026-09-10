# FS25_Enhanced

**Autor:** CeberusOne  
**Version:** 0.3.0.0 (Phase 2 Governor + Scene on Wave 1)

Adaptives Graphics-/Optimierungs-Mod für Farming Simulator 25 (Giants Engine 10 / Lua). Der Mod steuert Grafik- und Performance-Einstellungen über dokumentierte Engine-Setter (kein Binary-Hooking).

## Status

**v0.3 Phase 2** — Wave 1 CONFIRMED managers + Governor/Scene stubs:

- SceneAnalyzer (read-only mission/environment snapshot; Medium/Slow cadence)
- GraphicsGovernor hysteresis bands + desired preset/tier (default **disabled**, **autoApply off**)
- ProfileManager presets Performance/Balanced/Quality/Cinematic → SettingsCache requested only
- Optional console commands for manual Manager API tests (never force autoApply)
- CapabilityApplier / ShadowManager / LodGovernor from Wave 1 (session-only; auto-apply **OFF**)
- EN+DE l10n keys (`FS25E_*`)

**Not automatic:** live adaptive apply of engine setters. Governor computes desired state only unless `autoApply` is explicitly enabled later. No EXPERIMENTAL/GATED/RESTART writers; no `saveHardwareScalability` without opt-in.

## Dokumentation

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
