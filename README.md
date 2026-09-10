# FS25_Enhanced

**Autor:** CeberusOne  
**Version:** 0.4.2.1

Adaptives Graphics-/Optimierungs-Mod für Farming Simulator 25 (Giants Engine 10 / Lua). Der Mod steuert Grafik- und Performance-Einstellungen über dokumentierte Engine-Setter (kein Binary-Hooking).

## Status

**v0.4.2.1** — GUI + Wave 1 + Expert/Pro overlays:

- Settings GUI tabs (Simple / Advanced / Expert / Status)
- Wave-1 CONFIRMED managers (CapabilityApplier, ShadowManager, LodGovernor) + Governor/Scene
- Expert live overlay with custom bars (session via SettingsCache)
- Pro HUD: FPS/frametime + sidecar DISCONNECTED when telemetry absent
- Diagnostics (CapStatus / ring log)
- Experimental caps gated behind expertMode; Soft-Apply / persist-HW opt-in
- Adaptive / autoApply **default off** — no live engine apply until explicitly enabled
- EN+DE l10n keys (`FS25E_*`)

**Multiplayer:** client-local only (graphics values are not network-synced).

**Not automatic:** live adaptive apply of engine setters unless `autoApply` / Soft-Apply is enabled. No `saveHardwareScalability` without opt-in.

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
