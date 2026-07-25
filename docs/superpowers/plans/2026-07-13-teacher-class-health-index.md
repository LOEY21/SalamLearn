# FR-6.2 Teacher Class Health Index Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Class Health Index section to the Teacher Dashboard's Classroom tab, aggregating per-module completion rate, accuracy, trend, and sequencing-error data across all enrolled students.

**Architecture:** One new pure-Dart data provider (`classHealthIndexProvider`) in `teacher_providers.dart` computes a `ModuleHealth` list from existing `ProgressRepository`/`ClassRepository` reads — no new Hive model, no new box. One new widget (`_ClassHealthSection`) renders that list on the Classroom tab, reusing this file's existing `masteryBg`/`masteryFg`/`SoftCard` conventions.

**Tech Stack:** Flutter, Riverpod (`Provider.family`), Hive (read-only, existing boxes), `flutter_test`.

Spec: `docs/superpowers/specs/2026-07-13-teacher-class-health-index-design.md`

---

## File Structure

- Modify: `prjct/lib/logic/teacher/teacher_providers.dart` — add `ModuleHealth` class + `classHealthIndexProvider`.
- Modify: `prjct/lib/ui/teacher_dashboard/teacher_dashboard_screen.dart` — add `_ClassHealthSection` widget + wire into phone/wide Classroom tab layouts.
- Create: `prjct/test/logic/teacher/class_health_index_test.dart` — provider aggregation logic (real Hive, seeded data).
- Create: `prjct/test/ui/teacher_dashboard/class_health_section_test.dart` — widget rendering (provider override, no Hive).

---

### Task 1: `ModuleHealth` model + `classHealthIndexProvider`

**Files:**
- Modify: `prjct/lib/logic/teacher/teacher_providers.dart`
- Test: `prjct/test/logic/teacher/class_health_index_test.dart`

- [ ] **Step 1: Write the failing test**

Create `prjct/test/logic/teacher/class_health_index_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/data/curriculum_data.dart';
import 'package:salamlearn/data/repositories/class_repository.dart';
import 'package:salamlearn/data/repositories/learner_repository.dart';
import 'package:salamlearn/data/repositories/progress_repository.dart';
import 'package:salamlearn/logic/teacher/teacher_providers.dart';

import '../../test_helpers/hive_test_setup.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await setUpTestHive();
  });

  tearDown(() async {
    await tearDownTestHive(tempDir);
  });

  test('module with no records reports hasActivity false and no score', () {
    final result = computeClassHealthIndex('missing-class');

    expect(result, hasLength(curriculum.length));
    expect(result.every((m) => !m.hasActivity), isTrue);
    expect(result.every((m) => m.healthIndex == 0), isTrue);
  });

  test('completion rate counts distinct learners with >=1 record for the module', () async {
    final classes = ClassRepository();
    final learners = LearnerRepository();
    final progress = ProgressRepository();
    final moduleId = curriculum.first.id.toString();

    final section = await classes.create(
      teacherId: 't1',
      gradeLevel: 'Grade 1',
      section: 'A',
    );
    final a = await learners.register(
      parentId: 'p1',
      name: 'Learner A',
      age: 6,
      username: 'learner_a',
    );
    final b = await learners.register(
      parentId: 'p1',
      name: 'Learner B',
      age: 6,
      username: 'learner_b',
    );
    await classes.enroll(classId: section.id, learnerId: a.id);
    await classes.enroll(classId: section.id, learnerId: b.id);

    await progress.writeProgress(
      learnerId: a.id,
      moduleId: moduleId,
      strokeAccuracyPct: 90,
      sequencingErrors: 1,
      timeOnTaskSeconds: 60,
    );
    // Learner B has no records for this module.

    final result = computeClassHealthIndex(section.id);
    final moduleHealth = result.firstWhere((m) => m.moduleId == moduleId);

    expect(moduleHealth.hasActivity, isTrue);
    expect(moduleHealth.completionRate, 0.5); // 1 of 2 enrolled learners
    expect(moduleHealth.avgAccuracy, 90);
    expect(moduleHealth.avgErrors, 1);
  });

  test('health index formula weights completion, accuracy, and errors', () async {
    final classes = ClassRepository();
    final learners = LearnerRepository();
    final progress = ProgressRepository();
    final moduleId = curriculum.first.id.toString();

    final section = await classes.create(
      teacherId: 't1',
      gradeLevel: 'Grade 1',
      section: 'A',
    );
    final a = await learners.register(
      parentId: 'p1',
      name: 'Learner A',
      age: 6,
      username: 'learner_a',
    );
    await classes.enroll(classId: section.id, learnerId: a.id);
    await progress.writeProgress(
      learnerId: a.id,
      moduleId: moduleId,
      strokeAccuracyPct: 100,
      sequencingErrors: 0,
      timeOnTaskSeconds: 60,
    );

    final result = computeClassHealthIndex(section.id);
    final moduleHealth = result.firstWhere((m) => m.moduleId == moduleId);

    // completionRate=1.0, avgAccuracy=100, avgErrors=0
    // 0.4*100 + 0.4*100 + 0.2*100 = 100
    expect(moduleHealth.healthIndex, 100);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd prjct && flutter test test/logic/teacher/class_health_index_test.dart`
Expected: FAIL — `computeClassHealthIndex` and `classHealthIndexProvider` undefined.

- [ ] **Step 3: Implement `ModuleHealth` and `classHealthIndexProvider`**

Add to `prjct/lib/logic/teacher/teacher_providers.dart`, after the existing `classLessonFoldersProvider` at the end of the file. Add this import near the top with the other data imports:

```dart
import '../../data/curriculum_data.dart';
```

Append:

```dart
/// One module's aggregated classroom telemetry (FR-6.2). Built from every
/// enrolled learner's [ProgressRecord]s for that module — there is no
/// field on [ProgressRecord] distinguishing Classroom Mode (cast/hot-seat)
/// telemetry from solo Student Hub play, and core modules are still
/// placeholders per the project's "no real telemetry yet" scope note, so
/// this indexes all recorded activity rather than a Classroom-Mode-only
/// subset. Closing that gap for real would mean adding an
/// `isClassroomMode` field to [ProgressRecord] (Hive model + adapter bump)
/// and wiring it from the casting/hot-seat flow.
class ModuleHealth {
  const ModuleHealth({
    required this.moduleId,
    required this.moduleName,
    required this.completionRate,
    required this.avgAccuracy,
    required this.avgErrors,
    required this.trend,
    required this.healthIndex,
    required this.hasActivity,
  });

  final String moduleId;
  final String moduleName;
  final double completionRate;
  final double avgAccuracy;
  final double avgErrors;
  final double? trend;
  final int healthIndex;
  final bool hasActivity;
}

/// Pure aggregation, no Riverpod dependency — kept as a standalone function
/// so [classHealthIndexProvider] is a one-line wrapper and the logic itself
/// is directly unit-testable without a `ProviderContainer`.
List<ModuleHealth> computeClassHealthIndex(String classId) {
  final classes = ClassRepository();
  final progress = ProgressRepository();
  final enrollments = classes.byClassId(classId);
  final rosterSize = enrollments.length;
  final now = DateTime.now();
  final weekAgo = now.subtract(const Duration(days: 7));
  final twoWeeksAgo = now.subtract(const Duration(days: 14));

  return curriculum.map((destination) {
    final moduleId = destination.id.toString();

    if (rosterSize == 0) {
      return ModuleHealth(
        moduleId: moduleId,
        moduleName: destination.name,
        completionRate: 0,
        avgAccuracy: 0,
        avgErrors: 0,
        trend: null,
        healthIndex: 0,
        hasActivity: false,
      );
    }

    final allRecords = <dynamic>[];
    var learnersWithActivity = 0;
    for (final enrollment in enrollments) {
      final learnerRecords = progress
          .byLearnerId(enrollment.learnerId)
          .where((r) => r.moduleId == moduleId)
          .toList();
      if (learnerRecords.isNotEmpty) learnersWithActivity += 1;
      allRecords.addAll(learnerRecords);
    }

    if (allRecords.isEmpty) {
      return ModuleHealth(
        moduleId: moduleId,
        moduleName: destination.name,
        completionRate: 0,
        avgAccuracy: 0,
        avgErrors: 0,
        trend: null,
        healthIndex: 0,
        hasActivity: false,
      );
    }

    final completionRate = learnersWithActivity / rosterSize;
    final avgAccuracy =
        allRecords.map((r) => r.strokeAccuracyPct as double).reduce((a, b) => a + b) /
            allRecords.length;
    final avgErrors =
        allRecords.map((r) => r.sequencingErrors as int).reduce((a, b) => a + b) /
            allRecords.length;

    final thisWeek = allRecords.where((r) => (r.completedAt as DateTime).isAfter(weekAgo));
    final priorWeek = allRecords.where(
      (r) =>
          (r.completedAt as DateTime).isAfter(twoWeeksAgo) &&
          (r.completedAt as DateTime).isBefore(weekAgo),
    );
    double? trend;
    if (thisWeek.isNotEmpty && priorWeek.isNotEmpty) {
      final thisWeekAvg =
          thisWeek.map((r) => r.strokeAccuracyPct as double).reduce((a, b) => a + b) /
              thisWeek.length;
      final priorWeekAvg =
          priorWeek.map((r) => r.strokeAccuracyPct as double).reduce((a, b) => a + b) /
              priorWeek.length;
      trend = thisWeekAvg - priorWeekAvg;
    }

    final healthIndex = (0.4 * completionRate * 100 +
            0.4 * avgAccuracy +
            0.2 * (100 - avgErrors * 20).clamp(0, 100))
        .clamp(0, 100)
        .round();

    return ModuleHealth(
      moduleId: moduleId,
      moduleName: destination.name,
      completionRate: completionRate,
      avgAccuracy: avgAccuracy,
      avgErrors: avgErrors,
      trend: trend,
      healthIndex: healthIndex,
      hasActivity: true,
    );
  }).toList();
}

/// Class Health Index (FR-6.2) for the given classId — backs
/// `_ClassHealthSection` on the Teacher Dashboard's Classroom tab.
final classHealthIndexProvider = Provider.family<List<ModuleHealth>, String>(
  (ref, classId) => computeClassHealthIndex(classId),
);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd prjct && flutter test test/logic/teacher/class_health_index_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add prjct/lib/logic/teacher/teacher_providers.dart prjct/test/logic/teacher/class_health_index_test.dart
git commit -m "feat(teacher): add Class Health Index aggregation (FR-6.2)"
```

---

### Task 2: `_ClassHealthSection` widget

**Files:**
- Modify: `prjct/lib/ui/teacher_dashboard/teacher_dashboard_screen.dart`
- Test: `prjct/test/ui/teacher_dashboard/class_health_section_test.dart`

- [ ] **Step 1: Write the failing test**

Create `prjct/test/ui/teacher_dashboard/class_health_section_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/logic/teacher/teacher_providers.dart';
import 'package:salamlearn/ui/teacher_dashboard/teacher_dashboard_screen.dart';

const _classId = 'class-1';

void main() {
  testWidgets('shows "no activity yet" for a module with hasActivity false', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          classHealthIndexProvider(_classId).overrideWithValue(const [
            ModuleHealth(
              moduleId: '1',
              moduleName: 'Alif to Yaa',
              completionRate: 0,
              avgAccuracy: 0,
              avgErrors: 0,
              trend: null,
              healthIndex: 0,
              hasActivity: false,
            ),
          ]),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ClassHealthSection(classId: _classId)),
        ),
      ),
    );

    expect(find.text('Alif to Yaa'), findsOneWidget);
    expect(find.text('No activity yet'), findsOneWidget);
  });

  testWidgets('shows a High health pill and an upward trend for a healthy module', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          classHealthIndexProvider(_classId).overrideWithValue(const [
            ModuleHealth(
              moduleId: '1',
              moduleName: 'Alif to Yaa',
              completionRate: 1.0,
              avgAccuracy: 92,
              avgErrors: 0.5,
              trend: 8.0,
              healthIndex: 90,
              hasActivity: true,
            ),
          ]),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ClassHealthSection(classId: _classId)),
        ),
      ),
    );

    expect(find.text('Alif to Yaa'), findsOneWidget);
    expect(find.text('HIGH'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
  });

  testWidgets('shows a Needs help pill and a downward trend for a struggling module', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          classHealthIndexProvider(_classId).overrideWithValue(const [
            ModuleHealth(
              moduleId: '1',
              moduleName: 'Alif to Yaa',
              completionRate: 0.3,
              avgAccuracy: 40,
              avgErrors: 3,
              trend: -5.0,
              healthIndex: 30,
              hasActivity: true,
            ),
          ]),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ClassHealthSection(classId: _classId)),
        ),
      ),
    );

    expect(find.text('NEEDS HELP'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd prjct && flutter test test/ui/teacher_dashboard/class_health_section_test.dart`
Expected: FAIL — `ClassHealthSection` undefined.

- [ ] **Step 3: Implement `ClassHealthSection`**

In `prjct/lib/ui/teacher_dashboard/teacher_dashboard_screen.dart`, add this widget after `_ClassPulseCard`'s closing brace (after the `_MasteryRingPainter` class, before `_StudentTable`, so it sits alongside the other Classroom/Home aggregate-stat widgets):

```dart
/// Class Health Index (FR-6.2) — one row per curriculum module showing
/// group completion rate, average tracing accuracy, week-over-week trend,
/// and average sequencing errors, rolled into a single health-tier pill.
/// Reuses [masteryBg]/[masteryFg]'s existing High/Medium/Needs-help
/// thresholds rather than inventing new colors.
class ClassHealthSection extends ConsumerWidget {
  const ClassHealthSection({super.key, required this.classId});

  final String classId;

  static String _tierFor(int healthIndex) {
    if (healthIndex >= 80) return 'High';
    if (healthIndex >= 50) return 'Medium';
    return 'Needs help';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modules = ref.watch(classHealthIndexProvider(classId));

    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CLASS HEALTH INDEX',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          for (final module in modules)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ModuleHealthRow(module: module, tier: _tierFor(module.healthIndex)),
            ),
        ],
      ),
    );
  }
}

class _ModuleHealthRow extends StatelessWidget {
  const _ModuleHealthRow({required this.module, required this.tier});

  final ModuleHealth module;
  final String tier;

  @override
  Widget build(BuildContext context) {
    if (!module.hasActivity) {
      return Row(
        children: [
          Expanded(
            child: Text(
              module.moduleName,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          const Text(
            'No activity yet',
            style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
          ),
        ],
      );
    }

    final trend = module.trend;
    Widget trendIcon = const SizedBox(width: 16);
    if (trend != null && trend > 0) {
      trendIcon = const Icon(
        Icons.arrow_upward_rounded,
        size: 16,
        color: AppColors.teal,
      );
    } else if (trend != null && trend < 0) {
      trendIcon = const Icon(
        Icons.arrow_downward_rounded,
        size: 16,
        color: AppColors.coral,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                module.moduleName,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
            trendIcon,
            const SizedBox(width: 6),
            MasteryPill(mastery: tier, dotted: true),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: module.completionRate,
            minHeight: 6,
            backgroundColor: AppColors.creamDark,
            color: masteryBarColor(tier),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${(module.completionRate * 100).round()}% complete · '
          '${module.avgAccuracy.round()}% avg accuracy · '
          '${module.avgErrors.toStringAsFixed(1)} errors/session',
          style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd prjct && flutter test test/ui/teacher_dashboard/class_health_section_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add prjct/lib/ui/teacher_dashboard/teacher_dashboard_screen.dart prjct/test/ui/teacher_dashboard/class_health_section_test.dart
git commit -m "feat(teacher): add ClassHealthSection widget (FR-6.2)"
```

---

### Task 3: Wire `ClassHealthSection` into the Classroom tab (phone + wide)

**Files:**
- Modify: `prjct/lib/ui/teacher_dashboard/teacher_dashboard_screen.dart`

- [ ] **Step 1: Add to the phone layout's Classroom tab**

In `_PhoneLayoutState.build`, tab index `1` (Classroom), the current children list (around what was originally line 351-370) reads:

```dart
                        const _SectionLabel('MANAGE'),
                        const SizedBox(height: 10),
                        const _StaggerFadeIn(
                          delay: Duration(milliseconds: 60),
                          child: _ClassManagementEntryCard(),
                        ),
                        const SizedBox(height: 22),
                        const _SectionLabel('CREATE A CLASS'),
```

Insert a new section between the `_ClassManagementEntryCard` stagger-fade and the `_SectionLabel('CREATE A CLASS')`. Since `ClassHealthSection` needs the active `classId` (a `ConsumerWidget` read, not available in this `const` list), replace that block with:

```dart
                        const _SectionLabel('MANAGE'),
                        const SizedBox(height: 10),
                        const _StaggerFadeIn(
                          delay: Duration(milliseconds: 60),
                          child: _ClassManagementEntryCard(),
                        ),
                        const SizedBox(height: 22),
                        const _SectionLabel('CLASS HEALTH'),
                        const SizedBox(height: 10),
                        const _StaggerFadeIn(
                          delay: Duration(milliseconds: 120),
                          child: _ActiveClassHealthSection(),
                        ),
                        const SizedBox(height: 22),
                        const _SectionLabel('CREATE A CLASS'),
```

Then add this small wrapper widget (reads the active class from `teacherClassControllerProvider` so `ClassHealthSection` itself stays a plain `classId`-in widget, reusable later from `class_detail_screen.dart` if wanted) right after the `ClassHealthSection`/`_ModuleHealthRow` classes added in Task 2:

```dart
/// Resolves the currently-active class before handing off to
/// [ClassHealthSection] — kept separate so [ClassHealthSection] itself
/// only depends on a plain `classId`, not the active-class provider.
class _ActiveClassHealthSection extends ConsumerWidget {
  const _ActiveClassHealthSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = ref.watch(teacherClassControllerProvider);
    if (section == null) return const SizedBox.shrink();
    return ClassHealthSection(classId: section.id);
  }
}
```

- [ ] **Step 2: Add to the wide layout's Classroom tab**

In `_WideLayoutState.build`, tab index `1` (Classroom), the current left-column children list reads:

```dart
                                  children: const [
                                    _StaggerFadeIn(
                                      delay: Duration(milliseconds: 60),
                                      child: _ClassManagementEntryCard(),
                                    ),
                                    SizedBox(height: 16),
                                    _SectionLabel('CREATE A CLASS'),
                                    SizedBox(height: 10),
                                    _StaggerFadeIn(
                                      delay: Duration(milliseconds: 160),
                                      child: _CreateClassCard(),
                                    ),
                                  ],
```

Replace with:

```dart
                                  children: const [
                                    _StaggerFadeIn(
                                      delay: Duration(milliseconds: 60),
                                      child: _ClassManagementEntryCard(),
                                    ),
                                    SizedBox(height: 16),
                                    _SectionLabel('CLASS HEALTH'),
                                    SizedBox(height: 10),
                                    _StaggerFadeIn(
                                      delay: Duration(milliseconds: 120),
                                      child: _ActiveClassHealthSection(),
                                    ),
                                    SizedBox(height: 16),
                                    _SectionLabel('CREATE A CLASS'),
                                    SizedBox(height: 10),
                                    _StaggerFadeIn(
                                      delay: Duration(milliseconds: 160),
                                      child: _CreateClassCard(),
                                    ),
                                  ],
```

- [ ] **Step 3: Run the full test suite**

Run: `cd prjct && flutter test`
Expected: All tests PASS, including the two new files from Tasks 1-2.

- [ ] **Step 4: Run analyze**

Run: `cd prjct && flutter analyze`
Expected: No new issues.

- [ ] **Step 5: Commit**

```bash
git add prjct/lib/ui/teacher_dashboard/teacher_dashboard_screen.dart
git commit -m "feat(teacher): wire Class Health Index into Classroom tab (FR-6.2)"
```

---

### Task 4: Manual verification

- [ ] **Step 1: Run the app**

Follow the `run` skill to launch the app (Chrome or an emulator/device, whichever this repo's project skill already targets).

- [ ] **Step 2: Drive the flow**

1. Sign in / create a teacher account, create a class (or use an existing seeded one).
2. Enroll at least one learner via the invitation code flow (or use an existing enrolled learner).
3. Play through a lesson in the Student Hub as that learner so a `ProgressRecord` gets written for at least one module.
4. Return to the Teacher Dashboard → Classroom tab.
5. Confirm the "CLASS HEALTH" section appears with 7 module rows, the module just played shows a real completion/accuracy/error line and a health-tier pill, and the other 6 modules show "No activity yet".
6. Resize the window past 800px width (or open on a tablet-sized viewport) and confirm the same section renders correctly in the wide layout's left column.

- [ ] **Step 3: Confirm no regressions**

Check the Home tab's `_ClassPulseCard` and roster preview still render as before (unaffected by this change) and that switching classes (if the teacher owns more than one) updates the Class Health Index to the newly active class's data.

---

## Self-Review Notes

- **Spec coverage:** completion rate (Task 1 formula), accuracy trend (Task 1 `trend` field + Task 2 arrow), sequencing errors (Task 1 `avgErrors` + Task 2 label), Class Health Index (Task 1 `healthIndex` formula + Task 2 pill), placement on Classroom tab (Task 3, both layouts), known Classroom-Mode-tagging gap (documented inline in the `ModuleHealth` doc comment) — all covered.
- **No placeholders:** every step has complete, runnable code.
- **Type consistency:** `ModuleHealth` fields (`moduleId`, `moduleName`, `completionRate`, `avgAccuracy`, `avgErrors`, `trend`, `healthIndex`, `hasActivity`) are identical across Task 1's definition, Task 1's tests, Task 2's widget, and Task 2's tests.
