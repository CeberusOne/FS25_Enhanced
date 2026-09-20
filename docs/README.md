# FS25 Enhanced documentation

This directory contains both player-facing documentation and technical development records. The files do not all describe the same release: research notes, audits and version-specific reports are retained so that technical decisions remain traceable.

For the currently published package, start with the repository [README](../README.md), the version in [`VERSION`](../VERSION) and the matching entry in the [changelog](CHANGELOG.md).

## For players

| Document | Purpose |
| --- | --- |
| [README](../README.md) | Project overview, installation, controls and boundaries |
| [User guide](USER_GUIDE.md) | How to approach the controls and build a personal configuration |
| [Known limitations](KNOWN_LIMITATIONS.md) | Engine, asset and testing limitations |
| [Compatibility](COMPATIBILITY.md) | Supported paths, safeguards and untested combinations |
| [Debug guide](DEBUG_ANLEITUNG.md) | Information to collect when reporting a problem |
| [Changelog](CHANGELOG.md) | Release and development history |

## Current technical reference

| Document | Purpose |
| --- | --- |
| [Architecture](ARCHITECTURE.md) | Main components, ownership and restore model |
| [Settings schema](settings-schema.md) | Setting definitions and metadata |
| [Engine settings](ENGINE_SETTINGS.md) | GIANTS settings used by the project |
| [Live overlay API](LIVE_OVERLAY_API.md) | Runtime panel integration |
| [Capability hooks](CAPABILITY_HOOKS.md) | Detection and application paths |
| [Localization](LOCALIZATION.md) | Language and fallback model |
| [Diagnostics](diagnostics.md) | Runtime diagnostics and logging |

## Research and verification

The research, capability matrices, probes and test documents record what was found, what is implemented in code and what still requires confirmation in the running game. Their status terms are intentional:

- **Implemented (code)** means logic exists; it is not automatically proof of visual effect.
- **In-game unverified** means a real FS25 session is still required.
- **Limited** means only part of the intended behavior is available.
- **Experimental** means the option can be unstable, asset-dependent or too costly for a normal preset.
- **Unavailable / asset-dependent** means the required game, map or material path is not present.

Relevant files include:

- [Feature matrix](FEATURE_MATRIX.md)
- [Capability matrix](capability-matrix.md)
- [API inventory](API_INVENTORY.json)
- [Core research](CORE_RESEARCH.md)
- [Environment research](ENVIRONMENT_RESEARCH.md)
- [Lighting research](LIGHTS_RESEARCH.md)
- [GDN research](gdn-research.md)
- [Test matrix](TEST_MATRIX.md) and [test results](TEST_RESULTS.md)

## Version-specific and historical documents

Files named `RELEASE_*`, `HOTFIX_*`, `PHASE*`, `WAVE*`, audit reports, feasibility studies and calibration notes document a particular development stage. They are preserved as evidence and history; they should not be read as a promise that every described function exists in the currently published ZIP.

## Project principle

FS25 Enhanced exposes reachable graphics choices; it does not claim to replace the GIANTS renderer. A control is included only when there is a defensible engine, game-setting, shader or asset path and a safe way to handle its state. The project favors transparent status reporting, reversible changes and player choice over unsupported visual promises.
