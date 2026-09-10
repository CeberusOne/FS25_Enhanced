# FS25_Enhanced

**Autor:** CeberusOne  
**Version:** 0.2.0.0 (Wave 1 CONFIRMED setters)

Adaptives Graphics-/Optimierungs-Mod für Farming Simulator 25 (Giants Engine 10 / Lua). Der Mod steuert Grafik- und Performance-Einstellungen über dokumentierte Engine-Setter (kein Binary-Hooking).

## Status

**v0.2 Wave 1 CONFIRMED** — builds on Phase 1 skeleton:

- CapabilityRegistry loads Wave-1 profiles from XML (+ Lua fallback)
- CapabilityApplier: session-only apply/restore for CONFIRMED caps (`pcall`, reject on fail)
- ShadowManager + LodGovernor manager APIs (auto-apply **OFF**)
- RestoreManager invokes manager/applier restore on deleteMap (no `saveHardwareScalability`)
- GraphicsGovernor: `wave1 registered, auto-apply off`
- EN+DE l10n keys (`FS25E_*`)

**Excluded:** EXPERIMENTAL (`setShadowFocusBox`, `setFastShadowUpdate`, `setRainShallowWaterSimulation`), GATED SSR/Atmosphere/DRS, `setTerrainQuality` (RESTART), `saveHardwareScalability` / `applyPerformanceClass`. See [docs/WAVE1.md](docs/WAVE1.md).

## Dokumentation

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

Copy or symlink this folder into your FS25 `mods/` directory as `FS25_Enhanced`. Enable in the mod selection screen. Check `log.txt` for `[FS25_Enhanced]` lines on mission start/end.
