# FS25 Enhanced — GUI-Design (Vorbereitung)

> **Status:** Design-Doku vor voller Implementierung. Volle GUI erst nach Core-Signal.  
> **Sprache:** Deutsch.  
> **Bezug:** `docs/settings-schema.md`, `config/settingsSchema.stub.lua`, `l10n/l10n_*.xml`.

---

## Ziel & Scope

**Ziel:** Schema, l10n und UI-Kontrakt so vorbereiten, dass Simple Settings, Advanced Tabs und Live Tuning später ohne Slider-Fallen und ohne Core-Kopplung gebaut werden können.

**In Scope (jetzt):**
- Settings-Schema + Key-Liste `FS25E_*`
- EN/DE-Lokalisierung
- Screen-/Widget-/Hotkey-Plan
- Explizite Verbote (UsedPlus White-Box-Fallen)

**Out of Scope (jetzt):**
- Governor-Logik, Engine-Setter, Capability-Hooks
- Core-Andockung / SettingsCache-Apply
- Volle Advanced-Tabs- und Live-Tuning-Implementierung
- Experimental-Caps (hinter Expert-Mode; erst später)

---

## Screens

| Screen | Wann | Inhalt |
|--------|------|--------|
| **Simple Settings Dialog** | Frühe GUI-Phase | Mod On/Off, Preset, Target FPS, Adaptive; Client-only-Hinweis |
| **Advanced Tabs** | Später | Gruppen Shadows / Lighting / LOD-Foliage — nur CONFIRMED Caps aus Schema |
| **Live Tuning Overlay/Dialog** | Später (Hotkey) | LIVE-ApplyMode Caps; Lock/Auto-Anzeige minimal; Section im Schema schon markiert |

Expert-Mode-Flag steuert Sichtbarkeit experimenteller Caps (default off).

---

## Technik (Giants-Patterns)

- **Basis:** `MessageDialog` (nicht `DialogElement`)
- **Optionen:** `MultiTextOption` + Buttons — **keine Slider**
- **Laden:** lazy `g_gui:loadGui` (nicht nur modDesc-`<gui>`-Blindregistrierung)
- **Profiles:** immer `extends="fs25_*"` (kein Custom-Profile ohne extends)
- **Bestätigung:** `YesNoDialog.show` — **nicht** `g_gui:showYesNoDialog` (existiert so nicht / pitfall)
- **Texte:** `g_i18n:getText("FS25E_…")` mit Fallback Sprache → `en` → nie leer (siehe Schema)
- **Vanilla-Reuse:** On/Off wo üblich über `ui_on` / `ui_off`; eigene Labels für Mod-Spezifisches

---

## Explizit verboten

| Verboten | Grund |
|----------|--------|
| Slider-Widgets | Crash-/Layout-Fallen (UsedPlus) |
| `DialogElement` als Basis | White-Box / instabil |
| Custom GUI-Profiles ohne `extends="fs25_*"` | White-Box |
| Freie Int-/Float-Eingaben | Schema erlaubt nur bool \| enum-Stufen |
| Governor-/Engine-Aufrufe aus GUI-Stubs | Core-Interfaces fehlen noch |

---

## Mapping Schema → UI-Widgets

| Schema-Feld | Widget | Bemerkung |
|-------------|--------|-----------|
| `type = bool` | MultiTextOption (2) oder Toggle-Buttons | Labels via `ui_on`/`ui_off` oder Setting-Text |
| `type = enum` | MultiTextOption | `options` + `optionI18nKeys` |
| `section = simple` | Simple Dialog / erster Tab | Sofort sichtbar |
| `section = advanced` + `group` | Advanced Tab / SubTitle | Shadows, Lighting, LOD |
| `section = live` | Live-Tuning Overlay | Minimal bis Core |
| `section = expert` / `expertOnly` | Nur wenn `expertMode` | Experimental ausblenden |
| `applyMode` | Badge/Hinweis optional | LIVE/MED/SLOW — Anzeige später |
| `displayOnly` (Client-Hint) | Statischer Infotext | Kein Setter |
| Extreme Ultra/Cinematic | Tooltip `FS25E_WARN_EXTREME_COST` | Optional YesNo vor Apply |

Widget-IDs in GUI-XML später an Schema-`id` koppeln (1:1 Naming empfohlen).

---

## Hotkeys (geplant, modDesc)

```xml
<actions>
    <action name="FS25E_TOGGLE_LIVE_TUNING" />
    <action name="FS25E_OPEN_SETTINGS" />
</actions>
<!-- inputBinding + l10n action display texts später -->
```

| Action | Zweck | i18n |
|--------|-------|------|
| `FS25E_TOGGLE_LIVE_TUNING` | Live-Tuning Overlay | `FS25E_HOTKEY_LIVE_TUNING` |
| `FS25E_OPEN_SETTINGS` | Simple/Advanced Settings | `FS25E_SETTINGS_TITLE` |

**Runtime (später):**
- `g_inputBinding:registerActionEvent` / Spec-`onRegisterActionEvents` wo nötig
- Help-Visibility wie EnhancedVehicle-Pattern
- **MP Key-Konflikt-Check** (UAL-Vorbild); Nutzerhinweis `FS25E_KEY_CONFLICT`

Keine ActionEvents in diesem Liefergegenstand verdrahten.

---

## Expert-Mode

- Setting `expertMode` default **off**
- Experimental-Caps (Shadow Focus, Fast Shadow Update, Water/Materials/Reflections, …) erst sichtbar wenn Expert an **und** Capability ≥ freigegeben
- Simple/Advanced-CONFIRMED bleiben ohne Expert nutzbar

---

## Offene Punkte (Research)

1. Welcher FS25-**Settings-Frame-Hook** ist robustesten? (`InGameMenu`-Page vs. eigener Dialog vs. `Utils.overwrittenFunction` auf Frame-Load)
2. Persistenzort Mod-Presets ohne Nebenwirkungen auf `saveHardwareScalability`
3. Ob Simple Panel als eigener `MessageDialog` oder integrierte Menu-Page startet (Alpha: Dialog reicht)
4. Exakte Vanilla-Quality-Keys für Low/Med/High falls wiederverwendbar (sonst `FS25E_OPT_*` behalten)

---

## Liefergegenstände dieser Vorbereitung

| Datei | Rolle |
|-------|--------|
| `docs/settings-schema.md` | Dokumentiertes Schema + Key-Liste |
| `config/settingsSchema.stub.lua` | Reine Daten-Tabelle (nicht andocken) |
| `l10n/l10n_en.xml` / `l10n/l10n_de.xml` | EN+DE Texte |
| `docs/gui-design.md` | Dieses Dokument |
