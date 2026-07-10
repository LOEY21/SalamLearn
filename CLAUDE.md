# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repo layout

The Flutter app lives entirely under `prjct/` — treat that as the project root for all Flutter/Dart commands (`cd prjct` first). The repo root also contains unrelated clutter directories (`skills/`, `public-apis/`, `awesome-design-skills/`, `lottie-android/`, `dumps/`) — these are not part of the app, ignore them unless explicitly asked.

`REFERENCE/` holds two capstone-supplied PDFs (`SalamLearn_HighFidelity_Mockup_Documentation.pdf`, `SalamLearn_Wireframe_Documentation.pdf`) — these are the **authoritative visual spec** for screens/colors/copy. When redesigning or adding a screen, check these first rather than inventing new layout.

`Assets/` holds the original brand source files (`Color Pallete.png`, `SalamLearn Logo.png`).

## Commands (run from `prjct/`)

- `flutter pub get` — install deps
- `flutter analyze` — lint (uses `flutter_lints` via `analysis_options.yaml`)
- `flutter test` — run all tests; single file: `flutter test test/widget_test.dart`
- `flutter run` — run on connected device/emulator
- `dart run flutter_launcher_icons` — regenerate launcher icons after changing `assets/images/icon_fullbleed.png` / `icon_adaptive_fg.png` or the `flutter_launcher_icons:` block in `pubspec.yaml`

## Project context

SalamLearn: offline-first Islamic education app for Muslim children ages 5–11 (Grade 1, Philippine Refined Elementary Madrasah Curriculum/ALIVE). BSIT capstone project. Three roles sharing one app binary:

- **Learner (Child)** — locked to Student Hub + core modules only, no settings/admin access, no back-exit from hub.
- **Parent/Guardian** — 4-digit PIN gate, analytics dashboard, full CRUD over child profile/consent/data.
- **Asatidz/Teacher** — 4-digit PIN gate, class dashboard, classroom casting.

**No backend yet — this is a hard, explicit, standing constraint from the project owner.** Firebase/Hive are intentionally not wired in. All auth/consent/profile state lives in-memory only via Riverpod (`lib/logic/auth/session.dart`), resets on app restart, and accepts any well-formed input (e.g. `verifyPin` just checks length == 4). Do not add real persistence or auth without being asked — when a future integration point exists, it's marked with a `FIREBASE/HIVE PLUG POINT` comment describing what will replace the in-memory stub.

Core Education Modules (tracing engine, pronunciation flashcards, Qur'an/Hadith playback, Sirah storyboard, Fiqh drag-match) and the Parent Analytics Dashboard are **intentional placeholders** — no game logic, no real telemetry. This matches the mockup doc's own scope-exclusion note, not an oversight.

## Architecture

- **State**: Riverpod (`flutter_riverpod`), `Notifier`/`NotifierProvider` for mutable state (`sessionProvider`), `FutureProvider` for one-shot async (`launchChecksProvider`). No StatefulWidget-only state for anything cross-screen.
- **Routing**: `go_router`, single `routerProvider` in `lib/logic/router/app_router.dart`. All access control is centralized in one `redirect` callback — role gating and PIN gating are *not* checked ad hoc inside screens. When adding a route, decide whether it belongs in `gatePaths` (pre-onboarding/pre-consent flow) or `adminPaths` (requires PIN verification) and wire it into that callback, not into individual widgets.
- **Onboarding order is enforced by the redirect chain**: splash (`/`) → language (`/language`) → consent (`/consent`) → role picker (`/roles`) → role-specific setup. A learner can never reach `adminPaths`; admin paths always fall back to `/pin/verify` or `/pin/setup` if `pinVerified` is false. Selecting a new role always resets `pinVerified`.
- **Theme**: single source of truth in `lib/ui/theme/app_colors.dart` ("Madrasah Classic" palette — cream/teal/gold/coral/ink) and `lib/ui/theme/app_theme.dart`. Don't hardcode colors in screens; reference `AppColors`.
- **Responsive dashboards**: Parent and Teacher dashboards (`lib/ui/parent_dashboard/`, `lib/ui/teacher_dashboard/`) use `LayoutBuilder` with a `constraints.maxWidth >= 800` split between a phone layout and a wide/tablet layout showing the same data — this mirrors the mockup doc's explicit phone-vs-monitor figure pairing, not two separate designs.
- **Reusable building blocks**: `SoftCard` (tinted bordered panel, `lib/ui/widgets/soft_card.dart`) is the base unit most screens compose with rather than raw `Container`/`Card`. `PinPad` and `RoleTabs` are shared across the two PIN screens.
- **Data shapes**: `lib/data/models/` (`learner_profile.dart`, `consent_record.dart`, `pin_credential.dart`) are plain in-memory model classes — no `fromJson`/`toJson`, no persistence, consumed directly by `session.dart` and settings/onboarding providers.
- **`FR-x.x` comments**: scattered through logic files (e.g. `onboarding_checks.dart`, `settings_providers.dart`) reference functional-requirement IDs from the capstone spec. Preserve these tags when touching that code — they're the traceability link back to the requirements doc, not arbitrary labels.

## Process notes from the project owner

- New screens with any non-trivial animation get an HTML/CSS preview first (see `motion-design` skill) for approval before Flutter code is written — do not skip straight to Dart for animated onboarding-style screens unless told to.
- Redesigns must match `REFERENCE/` mockups exactly (colors, component shapes, even wording like "Lesson content area (module design pending)") rather than introducing a new visual direction.

## Skills to auto-invoke in this repo

Apply these without waiting to be asked, whenever the matching situation comes up:

- `motion-design` — any new screen with non-trivial animation, before writing Dart (see process note above).
- `flutter-flutter-fix-layout-issues` — whenever a change produces overflow/unbounded-height/layout errors.
- `flutter-flutter-build-responsive-layout` — whenever touching `parent_dashboard/` or `teacher_dashboard/`, since both already split phone vs. `>=800`-wide layouts and any new content must extend both branches.
- `flutter-flutter-add-widget-test` — after adding or materially changing a widget under `lib/ui/`.
- `verify` — before considering any non-trivial code change (product source, not test/doc-only) done; drive the actual flow, don't rely on `flutter analyze`/`flutter test` alone.
- `run` — when asked to run, start, or screenshot the app.
- `hallmark` — anti-AI-slop check on any new or redesigned screen, before calling it done; catches generic/templated visuals that drift from the `REFERENCE/` mockups.
- `impeccable` — any UI/UX critique, polish, or redesign pass (hierarchy, spacing, typography, states) on screens under `lib/ui/`.
