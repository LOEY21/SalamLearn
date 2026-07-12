# FR-6.6: Hot Seat Selector & Telemetry Append

## Requirement

- The Teacher Hub's "Hot Seat" tool shall prompt the teacher to select an active student profile before launching the interactive tracing canvas.
- Selection supports two modes: **Manual** (tap a name in a scrollable grid) and **Randomized** (a spinning "draw lots" wheel).
- On completion (teacher taps Done), the resulting telemetry (stroke accuracy, error count, time-on-task) is appended chronologically to a local record tied to that student ID, preserving prior attempts.

## Current state

`teacher_dashboard_screen.dart`'s `_ActionColumn._openHotSeat` opens a bottom sheet straight into `_DrawingCanvas` — a letter-scribble mock with no student selection and no save/completion action. This is the gap FR-6.6 closes.

`lib/data/repositories/progress_repository.dart`'s `ProgressRepository` + `ProgressRecord` (Hive box `progress`) already is FR-6.6's "ClassroomAssessmentBox": `writeProgress()` appends a new record keyed by `learnerId`; `byLearnerId()` returns every record for that student sorted newest-first (the learning-curve history). No new box or model — reuse this exactly as `lesson_player_screen.dart` does for real curriculum activities.

## Design

### Data flow

1. Teacher taps "Hot seat" on the dashboard → bottom sheet opens on the **picker step**.
2. Picker step shows `teacherRosterProvider`'s roster (active class) as a scrollable grid of name chips, plus a "Draw lots" toggle that reveals `_HotSeatWheel`.
3. Teacher either taps a name, or spins the wheel; the wheel's landing segment resolves to a `learnerId` the same way a tap would.
4. Sheet swaps (`AnimatedSwitcher`) to the **canvas step**: existing `_DrawingCanvas`, now header-tagged with the picked student's name. A `Stopwatch` starts the moment this step mounts.
5. Teacher lets the student trace, taps **Done** (new button, doesn't exist today).
6. Heuristic telemetry is computed from `_DrawingCanvas`'s own `_points` (see below) and written via `ProgressRepository().writeProgress(learnerId: ..., moduleId: 'hot_seat_<letter>', strokeAccuracyPct: ..., sequencingErrors: ..., timeOnTaskSeconds: ..., assignedByTeacher: true)`.
7. Snackbar confirms ("Saved to <Name>'s progress"), sheet closes.

### Telemetry heuristic (Done button)

No real handwriting-recognition engine exists (matches this app's standing convention that core tracing/module engines are placeholders). Rather than fabricate fixed numbers, derive values from the actual stroke data already captured in `_DrawingCanvas._points` (a `List<Offset?>`, `null` marking a pen lift):

- `timeOnTaskSeconds` — real, from the step's `Stopwatch`.
- `sequencingErrors` — `max(strokeSegmentCount - 1, 0)`, where `strokeSegmentCount` is the number of `null`-separated point runs (proxy: more pen lifts than one continuous stroke = more "sequencing" trouble).
- `strokeAccuracyPct` — the drawn points' bounding-box area as a percentage of the canvas area, clamped 0–100 (proxy: fuller/more deliberate coverage scores higher; empty or a single dot scores near 0).

Mark this block with a `ponytail:` comment: known ceiling is "not real handwriting recognition"; upgrade path is swapping in a real scoring pass if/when a real tracing engine module is built.

### New widgets

- `_HotSeatStudentPicker` — stateful, holds roster grid + mode toggle (Manual/Draw lots). Empty roster → "No students enrolled — enroll students first" message, wheel disabled.
- `_HotSeatWheel` — spinning segmented wheel (`AnimationController`, `Curves.easeOutCubic` or similar decelerating curve, ~2.5s), one segment per roster student, fixed pointer, resolves to a random `learnerId` on settle. Non-trivial new animation → per this repo's process rule, an HTML/CSS mock goes in `dumps/` for sign-off before the Dart is written (motion-design skill).

### Existing widgets touched

- `_ActionColumn._openHotSeat` — sheet body becomes step-driven (picker → canvas) instead of jumping straight to `_DrawingCanvas`.
- `_DrawingCanvas` — gains: constructor param for the picked student (id + display name), a `Stopwatch`, and a Done button wired to the write-and-close flow above.

### Testing

One widget test (`flutter-flutter-add-widget-test` convention): open Hot Seat → tap a roster name → land on canvas step → tap Done → assert `ProgressRepository().byLearnerId(learnerId)` has exactly one new record with `assignedByTeacher == true` and `moduleId` starting with `hot_seat_`. Wheel-path selection isn't separately tested (animation timing) — manual-path coverage exercises the same downstream write.

### Out of scope

- Casting the canvas to the student's own device — FR-6.6 and the existing UI copy ("traces letters directly on the teacher's device") both scope this to the host/teacher device only.
- Real handwriting/stroke-accuracy scoring — explicit placeholder per this app's "no game logic, no real telemetry" convention for core module engines; the heuristic above is the documented stand-in.
- Multi-class switch inside the picker — picker is scoped to the active class only, matching every other Class Tools action.
- Re-opening the picker for a second volunteer without leaving the sheet — Done closes the sheet; teacher re-taps "Hot seat" for the next student.
