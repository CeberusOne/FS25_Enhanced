# Community-Optimierungen für FS25 Enhanced

**Recherche-Datum:** 2026-09-10  
**Kontext:** Praktische Add-ons/Patterns für `FS25_Enhaced` (Grafik-/Optimierungs-Lua-Mod, Giants Engine 10), abgestimmt auf den Umsetzungsplan und die GDN-Baseline (`/workspace/fs25-gdn-giants-engine-research.md`).  
**Methode:** Community-Quellen (GitHub-Script-Mods, Pattern-/Pitfall-Repos, GDN-Forum, Performance-Guides); APIs nur übernommen, wenn sie in der GDN-Briefing/LuaDoc v1.20.0.0 bzw. nachweisbaren Community-Mustern vorkommen. Keine erfundenen Engine-APIs.

---

## Kurzüberblick

Die Community liefert vor allem **Querschnitt-Patterns** (Settings/Save, Hook-Lifecycle, MP-Sicherheit, GUI/i18n, Logging/Debug, Spec-Injection), weniger fertige „Enhanced Graphics“-Klone. Für FS25_Enhaced sind das die wertvollsten Hebel:

1. **Restore/Hook-Cleanup** (kritisch, weil Enhanced Engine-Werte setzt)  
2. **modSettings vs. Savegame-Trennung** (Client-Grafik lokal, Farm-Presets optional savegame)  
3. **Schema-getriebene Settings + native GUI-Patterns** (Courseplay / SoilFertilizer / UAL)  
4. **Multiplayer: Grafik lokal, keine Sync-Flut** (AutoVRAM-Vorbild; Events nur für geteilte Presets)  
5. **Performance: hysterese-/Budget-Logik außerhalb jedes Frames** (Community-Update-Timer + Enhanced-Plan)  
6. **Capability-Gates + pcall** (Funktion nur aufrufen, wenn existent; Fehler isolieren)  
7. **Lokalisierung & GUI-Pitfalls** (MessageDialog, Profile `extends="fs25_*"`, keine Slider)  
8. **Konfliktvermeidung** (Utils.*-Ketten, kein doppelter Spec-Name, Keybinding-Checks)

Der Umsetzungsplan deckt Governor/Restore/i18n bereits ab; die Community ergänzt vor allem **Umsetzungsdetails und Crash-Fallen**.

---

## Empfohlene Add-ons (priorisiert)

Jede Empfehlung: **Idee → Mapping auf offizielle FS25-APIs → Risiko/Kompatibilität → Priorität**.

### HIGH

#### 1. Hook-/Restore-Lifecycle-Manager (Cleanup bei Unload/Mission-Ende)
- **Idee:** Jede `Utils.prependedFunction` / `appendedFunction` / `overwrittenFunction`-Injection und jeder Runtime-Setter speichert Original + Cleanup; bei `deleteMap` / Mission-Ende / Mod-Deaktivieren alles zurücksetzen (entspricht Plan-`RestoreManager` + Community-`HookManager`).
- **Quellen:** [FS25_SoilFertilizer DEVELOPMENT.md](https://github.com/TheCodingDad-TisonK/FS25_SoilFertilizer/blob/main/DEVELOPMENT.md) (HookManager + `registerCleanup`); [fs25-claude-skill README](https://github.com/TheCodingDad-TisonK/fs25-claude-skill) (Hook-Accumulation-Pitfall); [FS25_MarketDynamics main.lua](https://github.com/TheCodingDad-TisonK/FS25_MarketDynamics/blob/457b16e7adebcab3962c9107713be57308d36b84/main.lua).
- **API-Mapping (GDN):** `Utils.prependedFunction` / `appendedFunction` / `overwrittenFunction` ([Utils 880](https://gdn.giants-software.com/documentation_scripting_fs25.php?version=script&category=90&class=880)); Lifecycle über Mission-Hooks (`FSBaseMission.delete`, `FSCareerMissionInfo.saveToXMLFile` wie Community); Logging via `Logging.*` ([Logging 553](https://gdn.giants-software.com/documentation_scripting_fs25.php?version=script&category=58&class=553)).
- **Risiko:** Hoch bei fehlendem Cleanup (Hook-Stack bei Savegame-Reload). Mit Cleanup: mittel–niedrig.
- **Priorität:** **HIGH** — ohne das bricht Restore und Multi-Mod-Kompatibilität.

#### 2. Getrennte Persistenz: Client-`modSettings` + optionale Savegame-Presets
- **Idee:** Nutzer-/Client-Grafikprofile unter `Documents/.../modSettings/FS25_Enhaced/`; farm-/savegamebezogene Daten (falls überhaupt) separat in `savegameDirectory`. Niemals Vanilla-`game.xml`-Skalierung dauerhaft überschreiben ohne Opt-in (Plan-Restore).
- **Quellen:** [Courseplay.lua](https://github.com/Courseplay/Courseplay_FS25/blob/main/Courseplay.lua) (`modSettings/.../courseplay.xml` vs. `savegame/Courseplay.xml`); [UniversalAutoloadInstaller](https://github.com/loki79uk/FS25_UniversalAutoload/blob/ca66efc4/UniversalAutoloadInstaller.lua) (`modSettings/UniversalAutoload.xml`); AutoVRAM-Doku (lokale XML, keine Savegame-/MP-Sync).
- **API-Mapping:** `getUserProfileAppPath()`, `XMLFile.load` / `create` / `XMLSchema` (Engine XML + eBook-Muster); Save-Hook: `FSCareerMissionInfo.saveToXMLFile` prepend/append; Schema-Register analog `AIModeSelection.initSpecialization` / Vehicle savegame schema (GDN Spec-Beispiele).
- **Risiko:** Niedrig, wenn Trennung klar; mittel, wenn man versehentlich `game.xml` schreibt.
- **Priorität:** **HIGH**

#### 3. Capability-Registry mit Runtime-Existence-Checks + sanften Fallbacks
- **Idee:** Vor jedem Engine-Setter: Existenz prüfen (`type(fn)=="function"` / Capability-Status `CONFIRMED|GATED|EXPERIMENTAL`), Clamp/Sanity-Range, bei Fehler Capability auf `REJECTED` und Restore. Vorbild: AutoVRAM ruft `setTextureStreamingMemoryBudget` nur wenn exponiert; Werte clampen.
- **Quellen:** AutoVRAMOptimizer-Beschreibung ([KeilerHirsch/FS25_AutoVRAMOptimizer](https://github.com/KeilerHirsch/FS25_AutoVRAMOptimizer)); Plan-Capability-Registry; PMC/Hone zu `game.xml`-Coeffs (nicht blind hochdrehen).
- **API-Mapping:** Nur **bestätigte** GDN-/Engine-Funktionen aus Research Freeze; Setter über dokumentierte Engine/Script-APIs. Keine undokumentierten Memory-Hooks. Logging: `Logging.warning` / `Logging.error`.
- **Risiko:** Mittel (falsche Caps → visuelle Artefakte); mit Gates niedrig.
- **Priorität:** **HIGH**

#### 4. Multiplayer-Sicherheitsmodell: Grafik client-lokal, Events nur für geteilte Settings
- **Idee:** Rendering/Budget läuft pro Client lokal (kein Stream der Governor-Werte). Optional: Host-/Admin-Presets via `Event` + `g_server:broadcastEvent` (wie PrecisionFarmingSettingsEvent). Client-Join: Full-Sync nur für geteilte Daten, mit Retry.
- **Quellen:** GDN [PrecisionFarmingSettingsEvent](https://gdn.giants-software.com/documentation_scripting_fs25.php?version=script&category=29&class=335); SoilFertilizer Network-Events + `AsyncRetryHandler`; UsedPlus pitfalls (sendToServer/`g_server`-Check); Courseplay MP-Issue #1247 (schwere Sync = Join-Probleme).
- **API-Mapping:** `Event` + `readStream`/`writeStream`/`run`; `streamRead*`/`streamWrite*` (Engine Network); `g_server` / `g_client`; `NetworkUtil.readNodeObject` nur wenn Objekt-Bezug nötig (meist nicht für Grafik).
- **Risiko:** Hoch, wenn man Frame-Daten sync’t; niedrig bei „local graphics only“.
- **Priorität:** **HIGH** — `<multiplayer supported="true"/>` nur mit diesem Modell.

#### 5. Schema-getriebene Settings + InGame-Menü / Dialoge nach Giants-Patterns
- **Idee:** SettingsSchema erzeugt Defaults, XML, UI, Console-Commands; GUI über `g_gui:loadGui` / `MessageDialog` / `MultiTextOption`; Profile `extends="fs25_*"`; Live-Tuning mit Cost/Lock/ApplyMode wie Plan.
- **Quellen:** SoilFertilizer SettingsSchema; Courseplay `CpSettingsUtil` + GUI-Clone; UsedPlus [what-doesnt-work.md](https://github.com/Seamforge/FS25_UsedPlus/blob/master/FS25_AI_Coding_Reference/pitfalls/what-doesnt-work.md); UAL Global/Shop Settings-Menüs.
- **API-Mapping:** `g_gui:loadGui` / `showDialog`; `g_i18n:getText`; `g_messageCenter:subscribe(MessageType.SETTING_CHANGED[...])` für Vanilla-Settings-Reaktionen (LuaDoc-Beispiele); Input: `g_inputBinding:registerActionEvent` + Spec-`onRegisterActionEvents` (GDN AIAutomaticSteering / Forum-Thread).
- **Risiko:** GUI-Pitfalls (Slider, DialogElement) → Crash/White-Box; bei Follow-Patterns mittel–niedrig.
- **Priorität:** **HIGH**

#### 6. Performance-Monitor ohne Frame-Spam (Timer + Hysterese)
- **Idee:** Schwere Analyse nicht jedes Frame; Fast/Medium/Slow-Controller wie Plan; Community-Pattern: `updateTimer` / Intervalle, Early-Return wenn disabled; Debug-Overlay nur bei Flag.
- **Quellen:** Plan §§15–22; [TransactionLog CODESTYLE](https://github.com/rittermod/FS25_TransactionLog/blob/9ea746f212968acb8911e70b3aa06adb3d1d81a2/CODESTYLE.md) (efficient update loops); EnhancedVehicle Changelog (Performance-Optimierungen); Hone/PMC (CPU-Bottleneck → Draw-Distance/LOD teuer).
- **API-Mapping:** Mission-`update(dt)` via `Utils.appendedFunction(FSBaseMission.update, ...)`; optional `g_currentMission:addUpdateable` (in LuaDoc-Quellen erwähnt); Debug-Zeichnen: `DebugUtil.*` ([DebugUtil 211](https://gdn.giants-software.com/documentation_scripting_fs25.php?version=script&category=20&class=211)); Console: `addConsoleCommand` + Dev-Controls (`documentation_overview.php`).
- **Risiko:** Eigenes Monitoring kann CPU kosten — Intervalle/Budget zwingend.
- **Priorität:** **HIGH**

### MED

#### 7. Spec-/Type-Injection nur wo nötig; sonst Mission-Layer
- **Idee:** Enhanced ist primär Mission/Render-Control-Layer (`extraSourceFiles` + Mission-Hooks), **keine** Vehicle-Spec für globale Grafik. Spec-Injection (`TypeManager.finalizeTypes` prepend / `TypeManager.validateTypes` append / `g_vehicleTypeManager:addSpecialization`) nur für echte Fahrzeug-Features.
- **Quellen:** GDN eBook Mileage-Counter (`Utils.prependedFunction(TypeManager.finalizeTypes, ...)`); UAL `TypeManager.validateTypes` append + `injectSpecialisation`; VehicleExplorer `RegisterSpecialization.lua`; GDN-Forum [Adding specialization](https://gdn.giants-software.com/thread.php?categoryId=3&threadId=7472) (`registerEventListeners` Pflicht).
- **API-Mapping:** `SpecializationManager.addSpecialization`, `TypeManager.addSpecialization` / `finalizeTypes`, `SpecializationUtil.registerEventListener` / `hasSpecialization` ([SpecUtil 614](https://gdn.giants-software.com/documentation_scripting_fs25.php?version=script&category=77&class=614), [TypeManager 615](https://gdn.giants-software.com/documentation_scripting_fs25.php?version=script&category=77&class=615)); Spec-Storage `spec_` + `g_currentModName` (eBook).
- **Risiko:** Spec-Injection auf alle Types → Konflikte/Load-Kosten; für Enhanced meist unnötig.
- **Priorität:** **MED** (Architektur-Klarheit)

#### 8. Hotkeys / Action Events mit Konflikt-Erkennung
- **Idee:** Globale Actions für Menü/Profile/Debug; Hilfe-Menü-Texte ausblenden wenn Feature disabled (EnhancedVehicle); MP-Key-Konflikte erkennen (UAL `detectKeybindingConflicts` für CHAT vs. Mod-Key).
- **Quellen:** EnhancedVehicle Actions + Settings; UAL Keybinding-Conflict; Courseplay `PlayerInputComponent.registerGlobalPlayerActionEvents` overwrite.
- **API-Mapping:** `InputAction.*` in modDesc; `g_inputBinding:registerActionEvent` / `removeActionEvent`; Spec-Listener `onRegisterActionEvents` (GDN).
- **Risiko:** Niedrig–mittel (MP Chat-Key-Konflikte).
- **Priorität:** **MED**

#### 9. Zentralisiertes Logging + Debug-Overlay + Console-Commands
- **Idee:** Prefix `[FS25_Enhaced]` + Subsysteme; Level ERROR…TRACE; `pcall` in Hooks; Console: Toggle Debug, Dump Capabilities, Force Profile, Restore Now; Overlay nur lokalisiert.
- **Quellen:** Plan §§57–58; SoilFertilizer Logger/`SoilDebug`; paint-a-farm [fs25-scripting-mod SKILL](https://github.com/paint-a-farm/fs25-skills/blob/main/plugins/fs25-modding/skills/fs25-scripting-mod/SKILL.md); CODESTYLE Logging.
- **API-Mapping:** `Logging.info/warning/error` (nicht `Logging.fatal` außer unrecoverable); `DebugUtil.printTableRecursively` / `drawDebug*`; `addConsoleCommand` / `removeConsoleCommand`; VS Code Hot-Reload (GDN `vscode.php`).
- **Risiko:** Niedrig; zu viel Log I/O → Performance.
- **Priorität:** **MED**

#### 10. i18n-First + Vanilla-Text-Reuse + CI-Validierung
- **Idee:** Alle UI-Strings über Keys (`FS25E_*`); Fallback Sprache→en; Vanilla-Keys für On/Off/Low/… wiederverwenden; `validateLocalization.py` (Plan); 26 Sprachen wie SoilFertilizer-Praxis.
- **Quellen:** Plan §§6–11; SoilFertilizer Translations; CODESTYLE l10n; Community LUADOC / skill (l10n keys aus dataS).
- **API-Mapping:** `g_i18n:getText`; modDesc `<l10n filenamePrefix=...>` oder pro-Datei; Mod-scoped `g_i18n` (Sandbox-Hinweis in fs25-claude-skill).
- **Risiko:** Niedrig; Layout-Brüche bei langen DE/FR-Strings ohne flexible GUI.
- **Priorität:** **MED** (Plan schon HIGH — Community bestätigt Umsetzung)

#### 11. CompatibilityManager: Soft-Detection anderer Mods
- **Idee:** Bekannte Globals/Mod-Namen prüfen (`g_modIsLoaded`, `FS25_AutoDrive and ...` Pattern von Courseplay); bei Konflikt Features drosseln (z. B. kein doppeltes Draw-Distance-Tweaking mit anderen Graphics-Mods); optionale Bridges, keine harten Dependencies.
- **Quellen:** Courseplay AutoDrive-Hack; SoilFertilizer Integrations; UAL Store-Pack / Konflikt-Erkennung; Reddit-Threads zu Mod-Conflicts/`log.txt`.
- **API-Mapping:** `g_modIsLoaded` (TypeManager-LuaDoc); `g_modManager:getModByName`; defensive `_G[...]`-Checks (CODESTYLE).
- **Risiko:** Mittel (False Positives); Detection-only ist sicher.
- **Priorität:** **MED**

#### 12. Settings-UI-Details: MultiTextOption statt Slider; dynamisches loadGui
- **Idee:** Keine Slider-Widgets; Dialoge von `MessageDialog`; GUI nicht (nur) über modDesc `<gui>` registrieren, sondern lazy `g_gui:loadGui`.
- **Quellen:** UsedPlus pitfalls 3, 4, 6, 13, 14.
- **API-Mapping:** Giants GUI-Klassen laut LuaDoc GUI-Kategorie; `YesNoDialog.show` statt nicht existierendem `g_gui:showYesNoDialog`.
- **Risiko:** Niedrig bei Follow; hoch bei Ignore.
- **Priorität:** **MED**

### LOW

#### 13. Expert-/Debug-Mode in Settings (Courseplay-Vorbild)
- **Idee:** Fortgeschrittene Caps (Shadow Focus, Experimental ApplyModes) hinter Expert-Flag; SubTitles in GUI ausblenden.
- **Quellen:** Courseplay `CpSettingsUtil` `isExpertModeOnly`.
- **API-Mapping:** reine UI/Settings-Logik + `g_i18n`.
- **Priorität:** **LOW**

#### 14. Version-/Changelog-Dialog beim ersten Start nach Update
- **Idee:** `lastVersion` in modSettings; bei Versionswechsel `InfoDialog.show`.
- **Quellen:** Courseplay `showUserInformation`.
- **API-Mapping:** `InfoDialog.show`, `g_modManager:getModByName`.
- **Priorität:** **LOW**

#### 15. Console-Reset auf Defaults
- **Idee:** Command kopiert Default-XML über User-Settings (UAL `ualResetConfigurations` / AutoVRAM Datei löschen).
- **Quellen:** UAL / AutoVRAM.
- **Priorität:** **LOW**

#### 16. HUD-Position-Presets bei Overlay-Konflikten
- **Idee:** Kein Z-Order-API — Position-Presets für Debug-/Cost-HUD (SoilFertilizer).
- **API-Mapping:** Overlay/HUD draw über Mission-`draw`; keine undokumentierte Z-API behaupten.
- **Priorität:** **LOW**

#### 17. descVersion / ModHub-Hygiene
- **Idee:** Aktuelle ModHub-`descVersion` (Community: Bereich ~90–111, Templates oft 104/106 — **immer** gegen aktuelle ModHub-Guideline PDF prüfen); `<multiplayer supported="true"/>` nur wenn Modell passt.
- **Quellen:** fs25-claude-skill (descVersion-Warnung); paint-a-farm skill `descVersion="106"`; GDN ModHub PDF downloadId=124.
- **Priorität:** **LOW** (aber Release-Blocker wenn falsch)

---

## Patterns & Best Practices aus der Community

### A. Lifecycle / Hooks
| Pattern | Praxis | Enhanced-Bezug |
|--------|--------|----------------|
| Mission prepend/append | `Mission00.load`, `FSBaseMission.update/draw/delete`, `FSCareerMissionInfo.saveToXMLFile` | Core laden, Monitor, Save, Restore |
| Utils-Ketten statt Roh-Assign | `Utils.overwrittenFunction` hält Mod-Ketten | CompatibilityManager |
| Cleanup-Registry | Original speichern, `uninstallAll` | RestoreManager |
| `pcall` in Hooks | Fehler loggen, Spiel nicht crashen | Governor-Setter |

### B. Settings / Save
| Pattern | Praxis | Enhanced-Bezug |
|--------|--------|----------------|
| User vs Savegame XML | Courseplay / UAL | Profile lokal; Presets optional |
| XMLSchema + Defaults-Table | UAL iterateDefaults; CP registerXmlSchema | defaults.xml / presets.xml |
| Schema-Reihenfolge nicht ändern | SoilFertilizer | Nach Release keine Index-Umsortierung |
| Vanilla-Settings beobachten | `g_messageCenter` + `MessageType.SETTING_CHANGED` | Reaktion auf Spieler-Grafikänderungen |

### C. Specializations (nur falls benötigt)
| Pattern | Praxis | Hinweis |
|--------|--------|---------|
| `prerequisitesPresent` + `registerEventListeners` | GDN + Forum | Ohne Listener laufen `onUpdate`/`onLoad` nicht |
| Spec-Name mit Mod-Prefix | eBook / TypeManager | Doppel-Prefix durch Sandbox vermeiden |
| Injection timing | `finalizeTypes` prepend (eBook) oder `validateTypes` append (UAL) | Für Enhanced meist überflüssig |

### D. Multiplayer
| Pattern | Praxis | Enhanced-Bezug |
|--------|--------|----------------|
| Server-authoritative Gameplay | Soil / PF Events | Nur für geteilte Presets |
| Local-only Client FX | AutoVRAM | **Default für alle Render-Setter** |
| Full-Sync + Retry on join | SoilFertilizer | Falls Admin-Presets |
| Stream-Reihenfolge strikt | UsedPlus | Bei Events |

### E. GUI / Input / i18n
| Pattern | Praxis | Enhanced-Bezug |
|--------|--------|----------------|
| MessageDialog, nicht DialogElement | UsedPlus | EnhancedGraphicsMenu / Dialoge |
| MultiTextOption / Buttons statt Slider | UsedPlus | LiveTuning |
| Lazy `loadGui` | UsedPlus / UAL | gui/*.xml |
| Bottom-left / Content negativ-Y | UsedPlus | Layout |
| ActionEvents + Help-Visibility | EnhancedVehicle | Hotkeys |
| Key-Konflikt-Check MP | UAL | Chat vs. Mod |

### F. Performance / Lua 5.1
| Pattern | Praxis | Enhanced-Bezug |
|--------|--------|----------------|
| Update-Intervalle | CODESTYLE | Fast/Med/Slow Controller |
| Kein `os.time` / `goto` | UsedPlus / Soil | Timestamps über `g_currentMission.time` / environment |
| Globals cachen in Hot Paths | CODESTYLE | Monitor-Loops |
| `table.concat` statt String-`..` in Loops | CODESTYLE | Log-Batching |
| Draw-Distance/LOD teuer (CPU) | Hone / PMC | BudgetAllocator: Coeffs vorsichtig |

### G. Logging / Debug
| Pattern | Praxis | Enhanced-Bezug |
|--------|--------|----------------|
| Prefixed Logging | Plan + Soil | `[FS25_Enhaced][Governor]` |
| Debug-Flag | Viele Mods | TRACE nur wenn aktiv |
| Dev-Controls + F10 Debugger | GDN overview / vscode | Entwicklung |

---

## Quellen (URLs)

### Offiziell / Baseline
- https://gdn.giants-software.com/documentation_scripting_fs25.php  
- https://gdn.giants-software.com/documentation_scripting_fs25.php?version=script&category=90&class=880 (Utils)  
- https://gdn.giants-software.com/documentation_scripting_fs25.php?version=script&category=77&class=614 (SpecializationUtil)  
- https://gdn.giants-software.com/documentation_scripting_fs25.php?version=script&category=77&class=615 (TypeManager)  
- https://gdn.giants-software.com/documentation_scripting_fs25.php?version=script&category=58&class=553 (Logging)  
- https://gdn.giants-software.com/documentation_scripting_fs25.php?version=script&category=29&class=335 (PrecisionFarmingSettingsEvent)  
- https://gdn.giants-software.com/documentation_overview.php  
- https://gdn.giants-software.com/vscode.php  
- https://gdn.giants-software.com/forum.php  
- https://gdn.giants-software.com/thread.php?categoryId=3&threadId=7472  
- Interne Baseline: `/workspace/fs25-gdn-giants-engine-research.md`

### GitHub – Script-Mods / Patterns
- https://github.com/Courseplay/Courseplay_FS25  
- https://github.com/Courseplay/Courseplay_FS25/blob/main/Courseplay.lua  
- https://github.com/Courseplay/Courseplay_FS25/blob/773c3b8a/scripts/CpSettingsUtil.lua  
- https://github.com/Courseplay/Courseplay_FS25/issues/1247  
- https://github.com/loki79uk/FS25_UniversalAutoload/blob/ca66efc4/UniversalAutoloadInstaller.lua  
- https://github.com/TheCodingDad-TisonK/FS25_SoilFertilizer/blob/main/DEVELOPMENT.md  
- https://github.com/TheCodingDad-TisonK/FS25_MarketDynamics/blob/457b16e7adebcab3962c9107713be57308d36b84/main.lua  
- https://github.com/TheCodingDad-TisonK/fs25-claude-skill  
- https://github.com/Seamforge/FS25_UsedPlus/blob/master/FS25_AI_Coding_Reference/pitfalls/what-doesnt-work.md  
- https://github.com/Seamforge/FS25_UsedPlus/tree/master/FS25_AI_Coding_Reference/patterns  
- https://github.com/ZhooL/FS25_EnhancedVehicle  
- https://github.com/teknogeek/FS25_VehicleExplorer/blob/main/RegisterSpecialization.lua  
- https://github.com/paint-a-farm/fs25-skills/blob/main/plugins/fs25-modding/skills/fs25-scripting-mod/SKILL.md  
- https://github.com/rittermod/FS25_TransactionLog/blob/9ea746f212968acb8911e70b3aa06adb3d1d81a2/CODESTYLE.md  
- https://github.com/umbraprior/FS25-Community-LUADOC  
- https://github.com/Dukefarming/FS25-lua-scripting  
- https://github.com/KeilerHirsch/FS25_AutoVRAMOptimizer  

### Community / Guides / Foren
- https://www.pmctactical.org/forum/viewtopic.php?t=22971 (game.xml Scalability / foliageLODDistanceCoeff)  
- https://hone.gg/blog/farming-simulator-25-settings/  
- https://www.farmsimgame.com/Docs/Farming-Simulator-25/Developer-Console/  
- https://www.reddit.com/r/farmingsimulator/ / https://www.reddit.com/r/farmingsimulator25/ (Mod-Conflicts → `log.txt`, descVersion)  
- https://ls-modcompany.com/forum/ (Script-/Sync-Diskussionen, historisch)  
- https://courseplay.github.io/CourseplayHelpFS25/  

### User-Plan
- PDF Umsetzungsplan FS25_Enhaced (Attachment im Agent-Workspace)

---

## Was NICHT übernommen werden sollte (mit Grund)

1. **DLL Injection / Memory Patching / Rendergraph-/DX-Hooks** — explizit außerhalb Gen-1 des Plans; ModHub-/ToS-Risiko; nicht über öffentliche GDN-Lua-API.  
2. **Undokumentierte Engine-Symbole „erraten“** — Research Freeze: nur CONFIRMED/GIANTS_USED; Community-LUADOC/Decompile als Hinweis, nicht als stabile Public API ohne Verify.  
3. **Persistentes Überschreiben von `game.xml`-Scalability ohne Restore/Opt-in** — Community warnt vor extremen `viewDistanceCoeff`/`foliage*`-Werten (Stutter, CPU); widerspricht Plan-Restore.  
4. **Max Shadow Lights = 10 als „Fix“** — Hone meldet Engine-Bug (Quality fällt auf Medium); nicht als Enhanced-Default.  
5. **Vehicle-Spec-Injection für globale Grafik** — unnötige Kopplung an alle Vehicle-Types; Konflikte mit UAL/CP/anderen Injectors; Mission-Layer reicht.  
6. **Schwere Multiplayer-Sync des Governors** — Courseplay-Issue zeigt Join-/Sync-Probleme bei großen Sync-Lasten; Grafik gehört client-lokal.  
7. **`os.time` / `goto` / Lua-5.2+-Syntax** — Sandbox/Lua 5.1 → Load-Crash.  
8. **`DialogElement` + Slider + `g_gui:showYesNoDialog` + Custom-Profiles ohne `extends`** — UsedPlus: White-Box, stille Failures.  
9. **Direkte Funktions-Zuweisung statt `Utils.*Function`** — bricht Hook-Ketten anderer Mods.  
10. **Hooks ohne Cleanup** — Accumulation bei Reload.  
11. **`Logging.fatal` für nicht-fatale Capability-Fehler** — stoppt das Spiel (GDN Logging).  
12. **Doppeltes Mod-Prefix** (`MyMod.MyMod.Event`) — Sandbox auto-prefix (claude-skill).  
13. **modDesc `descVersion` aus veralteten Tutorials (z. B. 72/83)** — Mod erscheint ggf. gar nicht in der Liste.  
14. **Z-Order-/Deferred-Renderer-Annahmen** — FS25 exponiert das laut Community/Plan nicht öffentlich.  
15. **Random Vehicle-Packs / Gameplay-Cheat-Patterns** — außerhalb Enhanced-Scope.

---

## Abgleich mit dem Enhanced-Plan (Kurz)

| Plan-Modul | Community-Add-on |
|------------|------------------|
| RestoreManager | HookManager-Cleanup + Original-Value-Cache |
| SettingsManager / ProfileManager | modSettings + XMLSchema + Schema-driven UI |
| CompatibilityManager | Soft mod detection + Utils-Ketten |
| LocalizationManager | 26 Sprachen, Validate-Tool, Vanilla-Key-Reuse |
| PerformanceMonitor / Governor | Timer/Hysterese, kein Per-Frame-Overkill |
| Debug / Logging | Prefixed Logging, Console, Overlay-Presets |
| GUI LiveTuning | MessageDialog, MultiTextOption, lazy loadGui |
| CapabilityRegistry | Existence-check + clamp + REJECTED on failure |
| Multiplayer | Local graphics; Events nur für optionale Shared Presets |

---

*Ende des Community-Rechercheberichts. Keine APIs erfunden; Prioritäten an Enhanced Gen-1 ausgerichtet.*
