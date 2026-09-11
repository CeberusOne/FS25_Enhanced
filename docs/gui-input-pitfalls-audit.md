# GUI/Input-Pitfalls-Audit — FS25_Enhanced

**Stand:** 2026-09-11 · **Ref:** `origin/main` @ v0.4.2.4 (modDesc) / `FS25_Enhanced.lua` noch **0.4.2.3**  
**Quellen:** `gui/FS25E_SettingsDialog.xml`, `scripts/UI/*`, `scripts/Core/{GraphicsGovernor,PerformanceMonitor,SceneAnalyzer,TelemetryReader}.lua`, `modDesc.xml`, UsedPlus `what-doesnt-work.md` + `gui-dialogs.md`, Community-LUADOC `MultiTextOptionElement`  
**Methode:** Nur belegte Patterns/APIs. Keine spekulativen Engine-APIs.

> Stabschef Live-MSI meldete Fixes (F9, dialogBg, MultiText-Namen, Mauscursor, dt-ms). **Abgleich gegen `main`: mehrere Fixes fehlen oder widersprechen dem Stabschef-Soll.**

---

## Fokus-Checks (Stabschef)

| # | Soll | `main` Ist | Urteil |
|---|------|------------|--------|
| 1 | MessageDialog-Container `profile="dialogBg"` (**nicht** `dialogBgBox`) | `gui/…xml` Z.10: `profile="dialogBgBox"` | **WIDERSPRUCH** |
| 2 | MultiTextOption-Kinder `name="left|right|text|title"` | Profile vorhanden, **0×** `name=` auf left/right/text/title | **WIDERSPRUCH** |
| 3 | `setShowMouseCursor` open + restore close | SettingsDialog/LiveOverlay: **keine** Aufrufe | **WIDERSPRUCH** |
| 4 | ActionEvents SYSTEM + raw `keyEvent`-Fallback F9 / Ctrl+F9 | Nur ActionEvents; Binding Ctrl+E / Ctrl+Shift+E; `keyEvent` nur Overlay-Nav (Esc/Pfeile), **kein** F9-Open | **WIDERSPRUCH** (MSI vs main) |
| 5 | Mission `update(dt)` = **Millisekunden** | Governor/PM/SceneAnalyzer: `dt * 1000` (Kommentar „seconds“); TelemetryReader addiert `dt` raw als ms | **BUG / Inkonsistenz** |

---

## Audit-Tabelle

| Fix / Pitfall | Addressed on main? | Residual risk | Recommendation |
|---------------|--------------------|---------------|----------------|
| **dialogBg vs dialogBgBox** | **Nein** — Root `id="dialogElement"` nutzt `dialogBgBox` | White-Box / Layout; UsedPlus verlangt `profile="dialogBg"` | Sofort: `profile="dialogBg"` (UsedPlus gui-dialogs). `dialogFullscreenBg` Bitmap behalten. |
| **MultiText namedComponents left/right/text/title** | **Nein** — nur Profile, keine `name=` | LUADOC `setElementsByName`: ohne `name` → Warning + Default-Elemente; Buttons/Text tot | Alle MTO-Kinder: `name="left|right|text|title"`. **Hinweis:** LUADOC bindet Header als `label` — wenn `title` nicht greift, `name="label"` prüfen (Ingame-Smoke). |
| **Slider / DialogElement / g_gui:showYesNoDialog** | **Ja** (Design+Code) — MessageDialog, MultiTextOption, kein Slider, kein `showYesNoDialog` | Regression bei neuen Dialogen | Beibehalten; YesNo nur via `YesNoDialog.show`. |
| **Custom profiles ohne extends=fs25_*** | **Ja** — nur `fs25_*` / Vanilla-Button-Profile | — | Beibehalten. |
| **loadGui lazy vs modDesc `<gui>`** | **Ja** — `FS25E_GuiLoader.ensureSettingsDialog`; kein modDesc-`<gui>` | — | Beibehalten. |
| **Mouse cursor custom dialogs** | **Nein** — kein `setShowMouseCursor` in Settings/`LiveOverlay.show|hide` | Cursor unsichtbar → Klicks „tot“ | Settings `onOpen`: speichern + `true`; `onClose`/`close`: restore. Overlay: show `true`, hide restore. |
| **ActionEvents vs raw keyEvent; F9/Ctrl+F9** | **Teilweise** — SYSTEM-Actions + `registerActionEvent`; **kein** F9-Fallback | MSI erwartet F9/Ctrl+F9; main = Ctrl+E / Ctrl+Shift+E; ActionEvents können in Menü-Kontext fehlen | ActionEvents behalten; optional `keyEvent`-Fallback F9 / Ctrl+F9 (debounce, nur isDown). Bindings in modDesc an MSI angleichen **oder** MSI auf Ctrl+E dokumentieren — Drift schließen. |
| **MP chat key conflicts / help visibility** | **Teilweise** — `setActionEventTextVisibility(eid, true)` hardcodiert | Chat-Konflikt unklar; Help immer an | UAL-Konfliktcheck; Help visibility an Feature-Gate (disabled → false). |
| **Layout anchors / content below box / neg. Y** | **Teilweise** — Content nutzt negativ-Y (korrekt); kein `anchorTopCenter` auf Panels | MSI: Layout-XML-Fix nicht auf main sichtbar | Bei Panel-Overflow `with="anchorTopCenter"` erwägen; Smoke: Inhalt in Box. |
| **ZIP vs folder mod priority** | **Dokumentiert** in modDesc — Ordner `mods/FS25_Enhanced/` | Doppel-Install ZIP+Folder → alte ZIP gewinnt oft | README/Release: Ordner only; alte ZIP löschen. |
| **dt-ms Governor Spam** | **Nein auf main** — `GraphicsGovernor`/`PerformanceMonitor`/`SceneAnalyzer`: `dtMs = dt * 1000` | Intervalle ×1000 → Fast/Medium-Spam, FPS-Werte Unsinn; TelemetryReader (dt=ms) widerspricht | **HIGH:** `dtMs = dt` (ms). Kommentar „seconds“ streichen. Einheitlich mit TelemetryReader. Smoke: Medium-Tick ~250 ms real. |
| **Version-Drift** | modDesc/VERSION `0.4.2.4` vs Lua `0.4.2.3` | Verwirrung Logs/Support | `FS25_Enhanced.VERSION` auf `0.4.2.4` angleichen. |

---

## Bereits gut auf main

- MessageDialog-Basis (nicht DialogElement), keine Slider  
- Lazy `g_gui:loadGui`  
- Profiles `extends`/`fs25_*`  
- Content negativ-Y im `fs25_dialogContentContainer`  
- ActionEvents-Unregister + Hook-Cleanup-Pfad  
- LiveOverlay: custom draw (kein GuiSlider); Esc via `keyEvent`  
- MP: Grafik client-lokal (Policy)

---

## Actionable Next (Prio)

1. **HIGH** — dt-ms: `dt * 1000` entfernen in Governor / PerformanceMonitor / SceneAnalyzer  
2. **HIGH** — `dialogBgBox` → `dialogBg`  
3. **HIGH** — MultiText `name="left|right|text|title"` (Smoke; ggf. `label`)  
4. **MED** — `setShowMouseCursor` open/restore (Settings + Overlay)  
5. **MED** — Hotkey-Drift MSI↔main schließen (F9-Fallback **oder** Binding-Doku)  
6. **LOW** — Version-String Lua = 0.4.2.4; ZIP-vs-Folder Hinweis in Smoke-Checkliste

---

*Audit-only. Keine Code-Änderung in diesem Dokument.*
