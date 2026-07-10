# Learner Hub "Adventure Map" Redesign — Phase 4 (Shell + Map UI)

**Status:** Design approved by project owner, ready for implementation planning.
**Scope:** Visual/UX redesign of the Learner Hub shell (Home/Leaderboard/Backpack/Profile) plus the Noor Energy lives system. Content-model restructuring (7 curriculum destinations replacing the current 5 modules) is tracked separately as Phase 1–2 and is a prerequisite for this phase to reach its full intended shape — this phase can ship against the *existing* 5 modules as a first cut and be re-pointed at the 7 destinations once that data model lands.

## Background

The project owner supplied two reference sources for this redesign:

1. A React/Vite wireframe (`Wireframe 0.2`) implementing a Duolingo-style scrollable "Adventure Map" for the Learner Hub — winding illustrated path connecting themed curriculum destinations, mascot avatar walking the current node, pill-style stat badges, floating rounded bottom nav.
2. A full production design-asset pack (`Designs-20260710T141643Z-2-001/Asset-Designs/`) — actual finished PNG illustrations: two candidate full map backgrounds (`bg 2.png`, `bg 3.png`), multiple icon-pack sheets (navigation, learning-activity, rewards, system/utility), 7 destination badge icons, 4 map-node-state badges (Locked/Available/Current/Completed), 12 animal avatars with 4 expression states each, 3 role character illustrations, a "Noor Energy" lantern-based lives system, splash/onboarding art, and a documented color palette + typography spec.

Because real, finished illustration assets exist for this exact screen, the implementation approach is **use the supplied bitmap assets directly** (`Image.asset`) rather than hand-painting terrain via `CustomPainter` — this was the original plan before the asset pack was found, and is now unnecessary risk.

## Goals

- Replace the Home tab's module grid with a scrollable illustrated Adventure Map using the supplied background art.
- Replace TopBar and BottomNav across all 4 Learner Hub tabs with the pill-stat / floating-nav visual language shown in both references.
- Add a mascot avatar (reuse the app's existing owl mascot, not the wireframe's turtle, for brand consistency) that marks the learner's current position on the map.
- Add the Noor Energy lives system (5 max, depletes per activity attempt, "resting" cooldown state) as a new gameplay constraint.
- Add a points/XP system, awarded on module completion, backing the TopBar's stars pill.
- Adopt the asset pack's typography (Fredoka Bold, Baloo 2 SemiBold, Cairo for Arabic, Nunito Regular) for Learner-facing screens only — Parent/Teacher keep the current app font.
- Ship against the current 5 core modules as map nodes (Tracing/Sounds/Qur'an & Hadith/Stories/Sort & Match) — not the 7-destination curriculum, which is a separate, larger content-authoring phase.

## Non-goals (this phase)

- Restructuring the curriculum data model into 7 destinations with real lesson content (tracked as Phases 1–2 of the overall initiative).
- Building the 5 activity-type engines (Flashcard/Quiz/Match/Sort/Story) against new content — the existing module screens are reused as-is; only the entry point (map node tap → `/module/:id`) changes.
- Parent/Teacher-facing UI changes.
- Any change to the animal-avatar picker in Learner Setup/Profile (the 12-avatar asset exists but adopting it there is a separate, smaller follow-up, not bundled into this phase).

## Assets

Source: `Designs-20260710T141643Z-2-001/Asset-Designs/`. Files to be copied into `prjct/assets/images/adventure_map/` (new subfolder) before implementation:

- `bg 2.png` — **selected** as the map background (over `bg 3.png`). It has no text baked in, which is more flexible: destination-name labels are rendered as separate Flutter `Text` overlays at each of the 5 node positions actually in use, instead of being locked into the image at all 7 illustrated spots.
- Map node-state badges (Locked/Available/Current/Completed), per-module accent icons, Noor Energy lantern states, and a handful of decorations (~15–20 icons total) — **redrawn as Flutter vector icons** (`CustomPainter` or bundled SVGs) rather than sliced from the reference sheets. The sheets are composite reference layouts, not individually exportable files, and the actual footprint needed for this phase is small enough that redrawing is faster and easier to maintain than an asset-extraction pass.
- Activity-type icons (Flashcard/Quiz/Story/Tracing/Match/Sort/Listen/Read) for the module-open transition and Backpack tab — same redraw-as-vector approach.
- UI button styles (Primary/Secondary/Tertiary/Disabled) as a reference for updated `SoftCard`/button treatments on Learner screens.

## Data model additions

Two small, additive Hive-backed pieces of new state — both local-only for this phase (Firestore mirroring can follow the same best-effort pattern used elsewhere once these prove out):

### `LearnerXpState` (new, Hive-backed via `settings` box or a small new box)
- `totalXp: int`
- Incremented by a fixed amount (e.g. +50) whenever a module's existing "Validate & Submit" DFD-simulator flow reaches `finished` — same hook point that already increments `learnerStreakProvider`/`learnerCompletedTodayProvider` in `module_placeholder_screen.dart`.
- Backs the TopBar's stars/XP pill.

### `NoorEnergyState` (new, Hive-backed)
- `current: int` (0–5), `maxEnergy: int` (5), `lastDepletedAt: DateTime?`, `restingUntil: DateTime?`
- Depletes by 1 each time a learner *starts* an activity (not per-question — matches the asset pack's "Noor Energy is resting" framing, i.e. a session-level cost, not a per-mistake cost, to avoid punishing learning attempts too harshly for young kids).
- Recovers fully at the next local-calendar-day boundary (simplest rule to reason about and explain to a child — "come back tomorrow" — rather than a mid-session countdown timer). Treated as a placeholder default, easy to change to a partial-hourly-recovery model later without touching anything downstream of `NoorEnergyState`.
- When `current == 0`: module-open taps show a "Noor Energy is resting" sheet (matching the asset pack's illustration) instead of opening the module; the sheet shows time-until-next-recovery.
- Parent/Teacher accounts are unaffected — this only gates the Learner's own module access.

## Visual structure

### Adventure Map (Home tab)
- Vertically scrollable `SingleChildScrollView`/`CustomScrollView` over the chosen background PNG, same long-portrait aspect approach as the wireframe (`MAP_W`/`MAP_H` fixed canvas, background image scaled to fill it).
- 5 node positions (one per existing module) hand-placed to align with the background art's illustrated destinations, using the same state-badge system (Locked/Available/Current/Completed) from the asset pack.
- Node tap: unlocked → `context.go('/module/:id')` (unchanged downstream behavior); locked → existing locked-dialog, restyled to match the new visual language.
- Owl mascot avatar (reusing `owl_idle.json`) positioned at the current node, with the same gentle bob + "You are here!" speech-bubble treatment as the wireframe, restyled with the new asset pack's UI-panel look.
- Auto-scrolls to center the current node on first load.

### TopBar (all 4 tabs)
- Pill-style stat badges: 🔥 streak, ⭐ XP total, Noor Energy lanterns (mini row of up to 5), replacing the current header.
- Avatar button (top-left) — existing behavior (opens Profile/switches out) unchanged.

### BottomNav (all 4 tabs)
- Floating rounded pill nav bar, same 4 destinations (`/hub`, `/leaderboard`, `/backpack`, `/profile`) already wired via `HubShell`'s `StatefulShellRoute` — only the visual container changes, not the routing structure.

### Backpack / Leaderboard / Profile tabs
- Restyled to match the new visual language (rounded cards, new palette accents, new typography) — content/data unchanged, this is a visual pass only.

## Typography

Register Fredoka (bold weights for headings/stats), Baloo 2 (SemiBold, secondary headings), Nunito (body text), and Cairo (Arabic script text) as **bundled font assets** (not the `google_fonts` package's network-fetch-on-first-use behavior) — this app is offline-first, and a blank-font flash on a learner's first offline launch would be a real regression. Scoped via a new `learnerTextTheme` in `app_theme.dart`, applied only within the Learner Hub's route subtree — Parent/Teacher dashboards keep the current theme untouched.

## Color palette additions

New tokens to add to `AppColors` (additive, nothing existing removed/renamed):
- `skyBlue = Color(0xFF72C9F8)`
- `purple = Color(0xFF6C63D6)`
- `mintGreenAlt = Color(0xFF5B9A1E)` (distinct from existing `mintGreen = #5BC4A0` — naming needs disambiguation during implementation, e.g. `adventureGreen`)

## Motion

- Owl mascot: continuous gentle bob loop (existing Lottie asset, no new animation work).
- Current node: pulsing glow ring (matches wireframe's `boxShadow` pulse treatment, translated to a Flutter `AnimatedContainer`/`AnimationController` loop).
- Road/path fill: as modules complete, the connecting path segment animates from "todo" to "completed" styling.
- Scroll: standard native scroll physics, no custom parallax in this phase (flagged as a possible future enhancement, not required for approval).
- All motion follows the Learner Hub's existing "Playful" register (established this session: 150–300ms typical, `Curves.easeOutBack` overshoot on entrances) — the ambient 2600ms breathing rhythm used app-wide stays for any persistent glow/pulse effects.

## Process requirements (per this repo's standing rules)

- An HTML/CSS preview of the Adventure Map (via the `motion-design` skill) must be built and shown for the project owner's approval **before** any Dart code is written — this is a new screen with non-trivial animation, which triggers that standing rule.
- `hallmark` (anti-AI-slop) check and `impeccable` (UX polish) pass before calling any redesigned screen done.
- `flutter-flutter-add-widget-test` for new/materially-changed widgets.
- `verify` skill drive-through on a running emulator before considering the phase complete — this redesign has no meaningful test-only surface, it must be visually driven.

## Testing

- Widget test for the new Adventure Map node-tap → locked-dialog / module-navigation behavior (mirrors existing `_isModuleAssigned` gating logic, just a new visual entry point).
- Widget test for Noor Energy depletion/resting-sheet trigger.
- Manual verification on-device: full Home → node tap → module → complete → XP/energy update → back to map loop, plus BottomNav navigation across all 4 tabs, on both phone and any available tablet/wide viewport (this app's dashboards split phone/wide layouts as a standing convention — confirm whether the Learner Hub needs the same split, since it hasn't had one before now).
