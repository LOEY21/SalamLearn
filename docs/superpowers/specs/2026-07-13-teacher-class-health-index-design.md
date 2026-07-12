# FR-6.2: Teacher Analytics & Class Health Index

## Requirement

> The system shall provide a Teacher Dashboard that aggregates classroom-level telemetry data (collected exclusively via Classroom Mode interactions) to display group completion rates, tracing accuracy trends, and common sequencing errors across all enrolled students to determine a collective "Class Health Index" for each module.

## Known gap vs. spec wording

`ProgressRecord` has no field distinguishing Classroom Mode (cast/hot-seat) telemetry from solo Student Hub play — every write goes through `_writeProgressRecord()` in `lesson_player_screen.dart` regardless of origin. Core Education Modules are intentional placeholders (per project CLAUDE.md) with no real telemetry pipeline yet, so there is nothing to filter on either way.

Decision: index all recorded activity for enrolled students, same data source `classRosterProvider` already reads. Do not conflate with the existing `assignedByTeacher` (homework) flag — that's a different feature. Flag the gap with an inline comment at the point of computation; closing it for real would mean adding an `isClassroomMode` field to `ProgressRecord` (Hive model + adapter bump) and wiring it true from the casting/hot-seat flow — out of scope here.

"Common sequencing errors" is limited to an error-rate ranking per module (total/avg `sequencingErrors`), not a per-error-type breakdown — `ProgressRecord` only stores an aggregate error count per session, not which specific mistake occurred.

## Data layer

New provider in `lib/logic/teacher/teacher_providers.dart`:

```dart
class ModuleHealth {
  final String moduleId;       // curriculum Destination.id.toString()
  final String moduleName;     // curriculum Destination.name
  final double completionRate; // 0.0–1.0: learners with >=1 record / roster size
  final double avgAccuracy;    // 0–100, mean strokeAccuracyPct across records
  final double avgErrors;      // mean sequencingErrors per record
  final double? trend;         // this-week avg accuracy - prior-week avg accuracy; null if no prior-week data
  final int healthIndex;       // 0–100, see formula below
  final bool hasActivity;      // false => render "no activity yet" row, no fabricated score
}

final classHealthIndexProvider =
    Provider.family<List<ModuleHealth>, String>((ref, classId) { ... });
```

For each of the 7 `curriculum` destinations, pull every roster learner's `ProgressRepository().byLearnerId(learnerId)`, filter by `moduleId == destination.id.toString()`, and compute the fields above. `healthIndex` formula:

```
healthIndex = round(
  0.4 * completionRate * 100 +
  0.4 * avgAccuracy +
  0.2 * max(0, 100 - avgErrors * 20)
).clamp(0, 100)
```

Trend windows: last 7 days vs. the 7 days before that (`completedAt` cutoffs), same two-window comparison pattern the Parent Dashboard already uses for trend arrows.

Modules with zero records for the class (`hasActivity == false`) skip the formula entirely rather than showing a fabricated 0.

## UI

New `_ClassHealthSection` (`SoftCard`) in `teacher_dashboard_screen.dart`'s Classroom tab:
- Phone layout: placed under `_ClassManagementEntryCard`, above "CREATE A CLASS".
- Wide layout: left column, below `_ClassManagementEntryCard`.

One row per module (7 total, ordered by curriculum order):
- Module name
- Health-index pill — reuse `masteryBg`/`masteryFg`/threshold convention already in this file: ≥80 High (mint/teal), ≥50 Medium (gold), else Needs help (coral)
- Completion-rate mini progress bar (reuse `LinearProgressIndicator` styling from `_StudentCard`)
- Trend arrow: ↑ green if `trend > 0`, ↓ coral if `trend < 0`, — muted if `trend == null` or `0`
- Error count label ("N errors/session avg")

No-activity rows render a muted single line ("No activity yet") instead of the full row layout — mirrors `_NoStudentsCard`'s empty-state convention.

All colors/spacing/radii from `AppColors` and existing `SoftCard` padding conventions — no new tokens (per `salamlearn-design-system`).

## Testing

Widget test (`flutter-flutter-add-widget-test` convention) covering:
1. Empty roster → section shows appropriate empty state, no crash.
2. Roster with students but zero progress records → all modules show "No activity yet".
3. Roster with mixed records → correct health-index tier badge and trend arrow direction for at least one High and one Needs-help module.

Manual verification via `verify` skill flow before considering done — drive the actual Classroom tab, not just `flutter analyze`/`flutter test`.
