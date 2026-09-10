# FS25_Enhanced

**Autor:** CeberusOne  
**Version:** 0.1.0.0 (Phase 1 / PoC Core)

Adaptives Graphics-/Optimierungs-Mod für Farming Simulator 25 (Giants Engine 10 / Lua). Der Mod steuert Grafik- und Performance-Einstellungen über dokumentierte Engine-Setter (kein Binary-Hooking).

## Status

**v0.1 skeleton / PoC Core** — loadable mod skeleton with:

- Mission lifecycle (`load` / `update` / `delete`) — NO-OP-safe
- HookManager + RestoreManager (vanilla restore path)
- CapabilityRegistry stub (`config/capabilityProfiles.xml`)
- SettingsCache + SettingsSchema defaults (for later GUI)
- ModSettings path stub (`modSettings/FS25_Enhanced/`)
- dt-based PerformanceMonitor (no `getFps`)
- GraphicsGovernor Fast/Medium/Slow + hysteresis **stubs only**
- EN+DE l10n keys (`FS25E_*`)

**Not wired yet:** live engine graphics setters (`setShadow*`, `setLight*`, `set*DistanceCoeff`, `setRain*`, quality writers). Blocked until Research Freeze. See [docs/PHASE1.md](docs/PHASE1.md).

## Dokumentation

- [Phase 1 notes](docs/PHASE1.md)
- [Settings schema (GUI prep)](docs/settings-schema.md)
- [GUI design stub](docs/gui-design.md)
- [Optimaler Plan](docs/optimal-plan.md)
- [Änderungen](docs/aenderungen.md)
- [Community-Optimierungen](docs/community-optimizations.md)
- [GDN / Giants Engine Research](docs/gdn-research.md)

## Install (dev)

Copy or symlink this folder into your FS25 `mods/` directory as `FS25_Enhanced`. Enable in the mod selection screen. Check `log.txt` for `[FS25_Enhanced]` lines on mission start/end.
