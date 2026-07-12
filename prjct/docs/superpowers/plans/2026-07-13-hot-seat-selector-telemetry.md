# FR-6.6 Hot Seat Selector & Telemetry Append Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Teacher Hub's "Hot Seat" tool prompts the teacher to pick a student (manual grid or randomizer wheel) before the tracing canvas opens, and appends heuristic telemetry to that student's progress history when the teacher taps Done.

**Architecture:** No new Hive box/model — reuse `ProgressRepository`/`progress` box exactly as `lesson_player_screen.dart` does. The existing `_openHotSeat` bottom sheet becomes step-driven: a new `_HotSeatSheet` (ConsumerStatefulWidget) shows `_HotSeatStudentPicker` first, then swaps to the existing `_DrawingCanvas` (extended with student params + a Done button that writes telemetry) once a student is picked. A later task adds a "Draw lots" wheel mode (`_HotSeatWheel`) as an alternate picker input.

**Tech Stack:** Flutter/Dart, Riverpod, Hive (existing `ProgressRepository`), `flutter_test`/`testWidgets`.

**Spec:** `docs/superpowers/specs/2026-07-13-hot-seat-selector-telemetry-design.md`

---

## Context for the engineer

- `lib/ui/teacher_dashboard/teacher_dashboard_screen.dart` is one large file (~4000 lines) holding every Teacher Hub widget as private (`_`-prefixed) classes. All work in Tasks 2-4 happens inside this file. Because the classes are library-private, tests can only reach them through the public `TeacherDashboardScreen` widget tree (tap text, find by type) — never `find.byType(_DrawingCanvas)` etc. from a test file.
- `teacherRosterProvider` (in `lib/logic/teacher/teacher_providers.dart`) returns `List<Map<String, dynamic>>`, one entry per enrolled student in the *active* class, each with keys `'learnerId'` and `'name'` (among others) — this is the roster the picker reads.
- `ProgressRepository().writeProgress(...)` (in `lib/data/repositories/progress_repository.dart`) is a plain class, instantiated directly — no Riverpod provider wraps it, matching how `lesson_player_screen.dart` calls it.
- `AppColors` (in `lib/ui/theme/app_colors.dart`) is the only palette to use — no new colors.
- `dart:math` is already imported at the top of `teacher_dashboard_screen.dart` (line 1), so `max`, `min`, and `Random` are available unprefixed with no new import.
- Existing test seeding pattern: `test/test_helpers/hive_test_setup.dart`'s `setUpTestHive()`/`tearDownTestHive()` bootstrap a temp-dir Hive instance with every adapter/box the app uses except `custom_lessons`/`lesson_folders` (not needed here). No existing test seeds a full teacher+class+enrolled-student scenario — Task 2 adds that seeding helper.
- **Known pre-existing issue, not in scope:** `test/widget_test.dart`'s `TeacherDashboardScreen` group (`phone layout...` / `wide layout...` tests) already fails on `master` before this plan — it asserts hardcoded text (`'Ali'`, `'Grade 1 · Section A'`) left over from before the Hive-backed migration, and no seeding happens in that test. Do not fix it as part of this plan; it's an unrelated regression. The new tests below use their own file so they aren't affected by it.

---

### Task 1: HTML/CSS mock of the "Draw lots" wheel — design checkpoint

**Files:**
- Create: `dumps/hot_seat_wheel_mock.html`

This is a visual checkpoint, not app code — per this repo's process rule, any new screen with non-trivial animation gets an HTML/CSS preview before the Flutter widget is written. **Do not proceed to Task 4 (the real `_HotSeatWheel` widget) until the user has looked at this mock and approved it**, either as-is or with requested changes (loop: adjust the HTML, re-show, repeat).

- [ ] **Step 1: Write the mock file**

```html
<!doctype html>
<html>
<head>
<meta charset="utf-8" />
<title>Hot Seat — Draw Lots Wheel Mock</title>
<style>
  :root {
    --teal: #0F6E56;
    --teal-dark: #0A4F3E;
    --gold: #EF9F27;
    --coral: #D85A30;
    --mint-green: #5BC4A0;
    --adventure-blue: #72C9F8;
    --adventure-purple: #6C63D6;
    --cream: #FAF6EC;
    --ink: #2C2C2A;
  }
  body {
    margin: 0;
    min-height: 100vh;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 24px;
    background: var(--cream);
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
  }
  .wheel-wrap {
    position: relative;
    width: 280px;
    height: 280px;
  }
  .pointer {
    position: absolute;
    top: -14px;
    left: 50%;
    transform: translateX(-50%);
    width: 0;
    height: 0;
    border-left: 14px solid transparent;
    border-right: 14px solid transparent;
    border-top: 22px solid var(--ink);
    z-index: 2;
  }
  .wheel {
    width: 280px;
    height: 280px;
    border-radius: 50%;
    border: 6px solid white;
    box-shadow: 0 10px 30px rgba(0,0,0,0.18);
    background: conic-gradient(
      var(--teal) 0deg 72deg,
      var(--gold) 72deg 144deg,
      var(--coral) 144deg 216deg,
      var(--mint-green) 216deg 288deg,
      var(--adventure-blue) 288deg 360deg
    );
    display: flex;
    align-items: center;
    justify-content: center;
    transition: transform 2.5s cubic-bezier(0.17, 0.67, 0.12, 0.99);
  }
  .wheel-labels {
    position: absolute;
    top: 0; left: 0; right: 0; bottom: 0;
  }
  .wheel-label {
    position: absolute;
    top: 50%;
    left: 50%;
    font-size: 13px;
    font-weight: 700;
    color: white;
    text-shadow: 0 1px 2px rgba(0,0,0,0.35);
    transform-origin: 0 0;
  }
  .hub {
    position: absolute;
    top: 50%; left: 50%;
    width: 36px; height: 36px;
    background: white;
    border-radius: 50%;
    transform: translate(-50%, -50%);
    box-shadow: 0 2px 6px rgba(0,0,0,0.2);
  }
  button {
    padding: 12px 28px;
    border-radius: 999px;
    border: none;
    background: var(--teal);
    color: white;
    font-weight: 700;
    font-size: 14px;
    cursor: pointer;
  }
  #result {
    font-size: 16px;
    font-weight: 700;
    color: var(--ink);
    min-height: 22px;
  }
</style>
</head>
<body>
  <div class="wheel-wrap">
    <div class="pointer"></div>
    <div class="wheel" id="wheel">
      <div class="wheel-labels" id="labels"></div>
      <div class="hub"></div>
    </div>
  </div>
  <button id="spin">Spin the wheel</button>
  <div id="result"></div>

<script>
  const names = ["Ali", "Yusra", "Hamza", "Amina", "Bilal"];
  const labelsEl = document.getElementById("labels");
  const segmentDeg = 360 / names.length;
  names.forEach((name, i) => {
    const el = document.createElement("div");
    el.className = "wheel-label";
    const angle = segmentDeg * i + segmentDeg / 2;
    el.style.transform = `rotate(${angle}deg) translate(90px, -6px)`;
    el.textContent = name;
    labelsEl.appendChild(el);
  });

  const wheel = document.getElementById("wheel");
  const result = document.getElementById("result");
  let currentRotation = 0;

  document.getElementById("spin").addEventListener("click", () => {
    const winnerIndex = Math.floor(Math.random() * names.length);
    // Land the pointer (fixed at top, 0deg) on the middle of the winning
    // segment: rotate so that segment's midpoint reaches 0deg, plus a few
    // extra full spins for visual flourish.
    const targetMidpoint = segmentDeg * winnerIndex + segmentDeg / 2;
    const extraSpins = 4 * 360;
    currentRotation += extraSpins + (360 - targetMidpoint) - (currentRotation % 360);
    wheel.style.transform = `rotate(${currentRotation}deg)`;
    result.textContent = "";
    setTimeout(() => {
      result.textContent = `Picked: ${names[winnerIndex]}`;
    }, 2600);
  });
</script>
</body>
</html>
```

- [ ] **Step 2: Show the user**

Tell the user the mock is at `dumps/hot_seat_wheel_mock.html` and ask them to open it in a browser (or use the `browser` skill to screenshot it) and confirm the wheel look/feel before continuing to Task 4. Manual-picker and Done-button work (Tasks 2-3) doesn't depend on this approval and can proceed in parallel/first.

- [ ] **Step 3: Commit**

```bash
git add dumps/hot_seat_wheel_mock.html
git commit -m "Add HTML mock of Hot Seat draw-lots wheel for design sign-off"
```

---

### Task 2: Manual student picker, wired into the Hot Seat sheet

**Files:**
- Modify: `lib/ui/teacher_dashboard/teacher_dashboard_screen.dart:1587-1621` (replace `_openHotSeat`'s body)
- Modify: `lib/ui/teacher_dashboard/teacher_dashboard_screen.dart:1-16` (add import)
- Create: `test/ui/teacher_dashboard/hot_seat_test.dart`

- [ ] **Step 1: Write the failing test**

Create `test/ui/teacher_dashboard/hot_seat_test.dart`:

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:salamlearn/data/local/hive_boxes.dart';
import 'package:salamlearn/data/repositories/class_repository.dart';
import 'package:salamlearn/data/repositories/learner_repository.dart';
import 'package:salamlearn/data/repositories/progress_repository.dart';
import 'package:salamlearn/data/repositories/teacher_repository.dart';
import 'package:salamlearn/ui/teacher_dashboard/teacher_dashboard_screen.dart';

import '../../test_helpers/hive_test_setup.dart';

class _Seed {
  const _Seed({
    required this.teacherId,
    required this.classId,
    required this.learnerId,
  });

  final String teacherId;
  final String classId;
  final String learnerId;
}

Future<_Seed> _seedTeacherWithOneStudent() async {
  final teacher = await TeacherRepository().register(
    fullName: 'Ms. Amina',
    school: 'Test Madrasah',
    email: 'amina@example.com',
    password: 'correct horse',
    pin: '1234',
  );
  final section = await ClassRepository().create(
    teacherId: teacher.id,
    gradeLevel: 'Grade 1',
    section: 'A',
  );
  final learner = await LearnerRepository().register(
    parentId: 'test-parent',
    name: 'Amir Ali',
    age: 7,
    username: 'amir_hotseat_test',
  );
  await ClassRepository().enroll(
    classId: section.id,
    learnerId: learner.id!,
  );
  await Hive.box(HiveBoxes.settings).put('activeTeacherId', teacher.id);
  return _Seed(teacherId: teacher.id, classId: section.id, learnerId: learner.id!);
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await setUpTestHive();
  });

  tearDown(() async {
    await tearDownTestHive(tempDir);
  });

  group('Hot Seat', () {
    testWidgets('picker shows the active class roster and advances to the canvas on tap', (
      tester,
    ) async {
      await _seedTeacherWithOneStudent();

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: TeacherDashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Hot seat').first);
      await tester.pumpAndSettle();

      expect(find.text('Amir Ali'), findsOneWidget);
      expect(find.text('Done'), findsNothing);

      await tester.tap(find.text('Amir Ali'));
      await tester.pumpAndSettle();

      expect(find.text('Hot Seat: Amir Ali'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ui/teacher_dashboard/hot_seat_test.dart`
Expected: FAIL — `find.text('Amir Ali')` finds nothing (picker doesn't exist yet; today's sheet jumps straight to the tracing canvas with no roster).

- [ ] **Step 3: Add the import**

In `lib/ui/teacher_dashboard/teacher_dashboard_screen.dart`, after the existing `import '../../data/repositories/class_repository.dart';` (line 9), add:

```dart
import '../../data/repositories/progress_repository.dart';
```

- [ ] **Step 4: Replace `_openHotSeat` and add the picker/sheet widgets**

Replace the whole `_openHotSeat` method (currently `lib/ui/teacher_dashboard/teacher_dashboard_screen.dart:1587-1621`):

```dart
  void _openHotSeat(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _HotSeatSheet(),
    );
  }
```

Then add these two new classes directly after the closing brace of `_ActionColumn` (`lib/ui/teacher_dashboard/teacher_dashboard_screen.dart`, right before the `class _DrawingCanvas` definition — currently around line 3468):

```dart
/// FR-6.6 — the Hot Seat bottom sheet's content. Step-driven: shows
/// [_HotSeatStudentPicker] first (reading the active class's roster off
/// [teacherRosterProvider]), then swaps to [_DrawingCanvas] once a student
/// is picked, matching the design spec's "picker step → canvas step" flow.
class _HotSeatSheet extends ConsumerStatefulWidget {
  const _HotSeatSheet();

  @override
  ConsumerState<_HotSeatSheet> createState() => _HotSeatSheetState();
}

class _HotSeatSheetState extends ConsumerState<_HotSeatSheet> {
  String? _pickedLearnerId;
  String? _pickedName;

  void _pick(String learnerId, String name) {
    setState(() {
      _pickedLearnerId = learnerId;
      _pickedName = name;
    });
  }

  void _onSaved(String name) {
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Saved to $name's progress")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roster = ref.watch(teacherRosterProvider);
    final pickedName = _pickedName;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            pickedName == null ? 'Hot Seat Tracing Mode' : 'Hot Seat: $pickedName',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            pickedName == null
                ? 'Pick which student is up before launching the tracing canvas.'
                : "Enables the student to trace letters directly on this device.",
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          if (pickedName == null)
            _HotSeatStudentPicker(roster: roster, onPicked: _pick)
          else
            _DrawingCanvas(
              learnerId: _pickedLearnerId!,
              studentName: pickedName,
              onSaved: _onSaved,
            ),
        ],
      ),
    );
  }
}

/// FR-6.6 manual selection — a scrollable grid of the active class's
/// students; tapping one hands the (learnerId, name) pair straight to
/// [onPicked]. The "Draw lots" wheel mode is added in a later task.
class _HotSeatStudentPicker extends StatelessWidget {
  const _HotSeatStudentPicker({required this.roster, required this.onPicked});

  final List<Map<String, dynamic>> roster;
  final void Function(String learnerId, String name) onPicked;

  @override
  Widget build(BuildContext context) {
    if (roster.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'No students enrolled yet — enroll students first.',
          style: TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final student in roster)
          InkWell(
            onTap: () => onPicked(
              student['learnerId'] as String,
              student['name'] as String,
            ),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.neutralTint,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.creamBorder),
              ),
              child: Text(
                student['name'] as String,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
```

- [ ] **Step 5: Update `_DrawingCanvas`'s constructor so the file compiles**

`_DrawingCanvas` doesn't take parameters yet — Task 3 does the full rewrite, but this task's code already calls it with `learnerId`/`studentName`/`onSaved`. For this task, just change the constructor declaration (leave the rest of the class untouched — Task 3 fills in the body):

Find (`lib/ui/teacher_dashboard/teacher_dashboard_screen.dart`, currently around line 3468-3469):

```dart
class _DrawingCanvas extends StatefulWidget {
  const _DrawingCanvas();
```

Replace with:

```dart
class _DrawingCanvas extends StatefulWidget {
  const _DrawingCanvas({
    required this.learnerId,
    required this.studentName,
    required this.onSaved,
  });

  final String learnerId;
  final String studentName;
  final ValueChanged<String> onSaved;
```

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/ui/teacher_dashboard/hot_seat_test.dart`
Expected: PASS

- [ ] **Step 7: Run full analyze to catch anything else**

Run: `flutter analyze lib/ui/teacher_dashboard/teacher_dashboard_screen.dart`
Expected: `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add lib/ui/teacher_dashboard/teacher_dashboard_screen.dart test/ui/teacher_dashboard/hot_seat_test.dart
git commit -m "Add Hot Seat manual student picker (FR-6.6)"
```

---

### Task 3: Heuristic telemetry + Done button on the tracing canvas

**Files:**
- Modify: `lib/ui/teacher_dashboard/teacher_dashboard_screen.dart` (`_DrawingCanvasState`, currently around line 3475-3559)
- Modify: `test/ui/teacher_dashboard/hot_seat_test.dart`

- [ ] **Step 1: Write the failing test**

Add to the `group('Hot Seat', ...)` block in `test/ui/teacher_dashboard/hot_seat_test.dart`, after the existing test:

```dart
    testWidgets('Done writes a progress record for the picked student and closes the sheet', (
      tester,
    ) async {
      final seed = await _seedTeacherWithOneStudent();

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: TeacherDashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Hot seat').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Amir Ali'));
      await tester.pumpAndSettle();

      // A short drag on the tracing canvas, so the heuristic has real
      // stroke data to compute from.
      await tester.dragFrom(
        tester.getCenter(find.byType(AspectRatio)),
        const Offset(60, 0),
      );
      await tester.pump();

      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      final records = ProgressRepository().byLearnerId(seed.learnerId);
      expect(records, hasLength(1));
      expect(records.first.assignedByTeacher, isTrue);
      expect(records.first.moduleId, startsWith('hot_seat_'));

      // Sheet closed and confirmation shown.
      expect(find.text('Done'), findsNothing);
      expect(find.textContaining("Saved to Amir Ali's progress"), findsOneWidget);
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ui/teacher_dashboard/hot_seat_test.dart`
Expected: FAIL — no `Done` button exists yet on the canvas, so `find.text('Done')` before the tap already finds nothing and the tap step throws.

- [ ] **Step 3: Rewrite `_DrawingCanvasState`**

Replace the whole `_DrawingCanvasState` class body (currently `lib/ui/teacher_dashboard/teacher_dashboard_screen.dart:3475-3559`, i.e. everything from `class _DrawingCanvasState extends State<_DrawingCanvas> {` through its closing `}` right before `class _SketchPainter`):

```dart
class _DrawingCanvasState extends State<_DrawingCanvas> {
  final List<Offset?> _points = [];
  String _selectedLetter = 'ج';
  final _canvasKey = GlobalKey();
  final Stopwatch _stopwatch = Stopwatch()..start();

  static const _letterGlyphs = {'ا': 'ا', 'ب': 'ب', 'ج': 'ج', 'د': 'د'};

  @override
  void dispose() {
    _stopwatch.stop();
    super.dispose();
  }

  /// ponytail: heuristic telemetry — no real handwriting-recognition
  /// engine exists yet (matches this app's placeholder-module convention
  /// for core learning engines). `sequencingErrors` is the pen-lift count
  /// (more separate strokes than one continuous letter = more trouble);
  /// `strokeAccuracyPct` is the drawn strokes' bounding-box coverage of the
  /// canvas. Upgrade path: swap in a real stroke-scoring pass once a real
  /// tracing engine module exists.
  Future<void> _finishAttempt() async {
    final segments = <List<Offset>>[];
    var current = <Offset>[];
    for (final point in _points) {
      if (point == null) {
        if (current.isNotEmpty) segments.add(current);
        current = [];
      } else {
        current.add(point);
      }
    }
    if (current.isNotEmpty) segments.add(current);

    final sequencingErrors = segments.isEmpty ? 0 : segments.length - 1;

    var accuracy = 0.0;
    final allPoints = segments.expand((s) => s).toList();
    if (allPoints.isNotEmpty) {
      final minX = allPoints.map((p) => p.dx).reduce(min);
      final maxX = allPoints.map((p) => p.dx).reduce(max);
      final minY = allPoints.map((p) => p.dy).reduce(min);
      final maxY = allPoints.map((p) => p.dy).reduce(max);
      final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
      final canvasArea = box == null ? 1.0 : box.size.width * box.size.height;
      final coverage = ((maxX - minX) * (maxY - minY)) / canvasArea;
      accuracy = (coverage * 100).clamp(0.0, 100.0);
    }

    await ProgressRepository().writeProgress(
      learnerId: widget.learnerId,
      moduleId: 'hot_seat_$_selectedLetter',
      strokeAccuracyPct: accuracy,
      sequencingErrors: sequencingErrors,
      timeOnTaskSeconds: _stopwatch.elapsed.inSeconds,
      assignedByTeacher: true,
    );

    if (mounted) widget.onSaved(widget.studentName);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            DropdownButton<String>(
              value: _selectedLetter,
              items: _letterGlyphs.keys
                  .map(
                    (k) => DropdownMenuItem(value: k, child: Text('Letter $k')),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _selectedLetter = v;
                    _points.clear();
                  });
                }
              },
            ),
            TextButton.icon(
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear Canvas'),
              onPressed: () => setState(() => _points.clear()),
            ),
          ],
        ),
        const SizedBox(height: 10),
        AspectRatio(
          aspectRatio: 1.4,
          child: Container(
            key: _canvasKey,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.creamBorder, width: 2),
            ),
            child: Stack(
              children: [
                Center(
                  child: Text(
                    _selectedLetter,
                    style: TextStyle(
                      fontSize: 130,
                      fontWeight: FontWeight.w100,
                      color: Colors.grey.shade200,
                    ),
                  ),
                ),
                GestureDetector(
                  onPanUpdate: (details) {
                    RenderBox renderBox =
                        context.findRenderObject() as RenderBox;
                    setState(() {
                      _points.add(
                        renderBox.globalToLocal(details.globalPosition),
                      );
                    });
                  },
                  onPanEnd: (details) {
                    setState(() {
                      _points.add(null);
                    });
                  },
                  child: CustomPaint(
                    painter: _SketchPainter(_points),
                    size: Size.infinite,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _finishAttempt,
            icon: const Icon(Icons.check_circle_outline_rounded),
            label: const Text('Done'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.teal,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/ui/teacher_dashboard/hot_seat_test.dart`
Expected: PASS (both tests)

- [ ] **Step 5: Run full analyze**

Run: `flutter analyze lib/ui/teacher_dashboard/teacher_dashboard_screen.dart`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/ui/teacher_dashboard/teacher_dashboard_screen.dart test/ui/teacher_dashboard/hot_seat_test.dart
git commit -m "Append heuristic telemetry on Hot Seat Done (FR-6.6)"
```

---

### Task 4: "Draw lots" wheel mode

**Only start this task once the user has approved (or approved-with-changes-applied-to) the Task 1 HTML mock.**

**Files:**
- Modify: `lib/ui/teacher_dashboard/teacher_dashboard_screen.dart` (`_HotSeatStudentPicker`)
- Modify: `test/ui/teacher_dashboard/hot_seat_test.dart`

- [ ] **Step 1: Write the failing test**

Add to `test/ui/teacher_dashboard/hot_seat_test.dart`'s `group('Hot Seat', ...)`:

```dart
    testWidgets('draw lots spins the wheel and advances to the canvas with a picked student', (
      tester,
    ) async {
      await _seedTeacherWithOneStudent();

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: TeacherDashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Hot seat').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Draw lots'));
      await tester.pump();
      expect(find.text('Spin the wheel'), findsOneWidget);

      await tester.tap(find.text('Spin the wheel'));
      // The wheel's spin animation runs ~2.5s (matches the approved mock).
      await tester.pump(const Duration(milliseconds: 2600));
      await tester.pumpAndSettle();

      expect(find.text('Hot Seat: Amir Ali'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });
```

(With a single-student roster the wheel's outcome is deterministic — there's only one name to land on — so this test doesn't need to stub `Random`.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/ui/teacher_dashboard/hot_seat_test.dart`
Expected: FAIL — no "Draw lots" toggle or wheel exists yet.

- [ ] **Step 3: Add the toggle + wheel to `_HotSeatStudentPicker`**

Replace the whole `_HotSeatStudentPicker` class (added in Task 2) with a stateful version that adds the manual/wheel toggle:

```dart
/// FR-6.6 student selection — either tap a name (manual) or spin
/// [_HotSeatWheel] (randomized "draw lots"); both resolve to the same
/// (learnerId, name) handoff via [onPicked].
class _HotSeatStudentPicker extends StatefulWidget {
  const _HotSeatStudentPicker({required this.roster, required this.onPicked});

  final List<Map<String, dynamic>> roster;
  final void Function(String learnerId, String name) onPicked;

  @override
  State<_HotSeatStudentPicker> createState() => _HotSeatStudentPickerState();
}

class _HotSeatStudentPickerState extends State<_HotSeatStudentPicker> {
  bool _drawLots = false;

  @override
  Widget build(BuildContext context) {
    if (widget.roster.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'No students enrolled yet — enroll students first.',
          style: TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _drawLots = false),
                style: OutlinedButton.styleFrom(
                  backgroundColor: _drawLots ? null : AppColors.mint,
                  foregroundColor: AppColors.teal,
                ),
                child: const Text('Pick manually'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _drawLots = true),
                style: OutlinedButton.styleFrom(
                  backgroundColor: _drawLots ? AppColors.mint : null,
                  foregroundColor: AppColors.teal,
                ),
                child: const Text('Draw lots'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_drawLots)
          _HotSeatWheel(roster: widget.roster, onPicked: widget.onPicked)
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final student in widget.roster)
                InkWell(
                  onTap: () => widget.onPicked(
                    student['learnerId'] as String,
                    student['name'] as String,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.neutralTint,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.creamBorder),
                    ),
                    child: Text(
                      student['name'] as String,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
```

- [ ] **Step 4: Add the `_HotSeatWheel` widget**

Add this new class directly after `_HotSeatStudentPickerState` (same file):

```dart
/// FR-6.6 randomized selection — a segmented spinning wheel (one segment
/// per roster student) matching the approved `dumps/hot_seat_wheel_mock.html`
/// mock: a fixed AnimationController spin with a decelerating curve,
/// landing on a random student.
class _HotSeatWheel extends StatefulWidget {
  const _HotSeatWheel({required this.roster, required this.onPicked});

  final List<Map<String, dynamic>> roster;
  final void Function(String learnerId, String name) onPicked;

  @override
  State<_HotSeatWheel> createState() => _HotSeatWheelState();
}

class _HotSeatWheelState extends State<_HotSeatWheel>
    with SingleTickerProviderStateMixin {
  static const _segmentColors = [
    AppColors.teal,
    AppColors.gold,
    AppColors.coral,
    AppColors.mintGreen,
    AppColors.adventureBlue,
    AppColors.adventurePurple,
  ];

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2500),
  );
  late final Animation<double> _spin = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  bool _spinning = false;
  double _restingTurns = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _spinWheel() {
    if (_spinning || widget.roster.isEmpty) return;
    final winnerIndex = Random().nextInt(widget.roster.length);
    final segmentTurns = 1 / widget.roster.length;
    // Land the pointer (fixed at the top) on the middle of the winning
    // segment, plus a few extra full turns for visual flourish.
    final targetTurns =
        4 + 1 - (segmentTurns * winnerIndex + segmentTurns / 2);

    setState(() => _spinning = true);
    _controller.reset();
    // ponytail: pointer-landing angle is an approximation (rotation-direction
    // math isn't pixel-verified against the painter's arc-drawing convention)
    // — functionally correct (onPicked always fires with the true winnerIndex
    // below, independent of the visual angle), cosmetic-only ceiling. Upgrade
    // path: verify/tune against a real device screenshot if the landing looks
    // visually off.
    _spinTween = Tween<double>(begin: _restingTurns, end: _restingTurns + targetTurns);
    _controller.forward().whenComplete(() {
      if (!mounted) return;
      setState(() {
        _spinning = false;
        _restingTurns = (_restingTurns + targetTurns) % 1;
      });
      final winner = widget.roster[winnerIndex];
      widget.onPicked(winner['learnerId'] as String, winner['name'] as String);
    });
  }

  Tween<double> _spinTween = Tween<double>(begin: 0, end: 0);

  @override
  Widget build(BuildContext context) {
    final roster = widget.roster;

    return Column(
      children: [
        SizedBox(
          width: 240,
          height: 240,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _spin,
                builder: (context, child) {
                  final turns = _spinTween.evaluate(_spin);
                  return Transform.rotate(
                    angle: turns * 2 * pi,
                    child: child,
                  );
                },
                child: CustomPaint(
                  size: const Size(240, 240),
                  painter: _WheelPainter(
                    labels: roster.map((s) => s['name'] as String).toList(),
                    colors: _segmentColors,
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_drop_down_rounded,
                size: 40,
                color: AppColors.ink,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _spinning ? null : _spinWheel,
          style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
          child: Text(_spinning ? 'Spinning…' : 'Spin the wheel'),
        ),
      ],
    );
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter({required this.labels, required this.colors});

  final List<String> labels;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final segmentAngle = 2 * pi / labels.length;

    for (var i = 0; i < labels.length; i++) {
      final paint = Paint()..color = colors[i % colors.length];
      final startAngle = -pi / 2 + segmentAngle * i;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        segmentAngle,
        true,
        paint,
      );

      final labelAngle = startAngle + segmentAngle / 2;
      final labelOffset = Offset(
        center.dx + cos(labelAngle) * radius * 0.62,
        center.dy + sin(labelAngle) * radius * 0.62,
      );
      final painter = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        labelOffset - Offset(painter.width / 2, painter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) =>
      oldDelegate.labels != labels;
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/ui/teacher_dashboard/hot_seat_test.dart`
Expected: PASS (all four tests)

- [ ] **Step 6: Run full analyze**

Run: `flutter analyze lib/ui/teacher_dashboard/teacher_dashboard_screen.dart`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add lib/ui/teacher_dashboard/teacher_dashboard_screen.dart test/ui/teacher_dashboard/hot_seat_test.dart
git commit -m "Add Hot Seat draw-lots wheel (FR-6.6)"
```

---

### Task 5: Final verification

**Files:** none (verification only)

- [ ] **Step 1: Run the new test file in isolation**

Run: `flutter test test/ui/teacher_dashboard/hot_seat_test.dart`
Expected: `+4: All tests passed!`

- [ ] **Step 2: Run full analyze**

Run: `flutter analyze`
Expected: `No issues found!` (pre-existing issues elsewhere in the repo, if any, are not introduced by this change — if `flutter analyze` reports something outside `teacher_dashboard_screen.dart`/`hot_seat_test.dart`, confirm it already existed on `master` before this plan and don't fix it here.)

- [ ] **Step 3: Run the full test suite and confirm no new failures**

Run: `flutter test`
Expected: the pre-existing `TeacherDashboardScreen` failures noted in "Context for the engineer" above are still the only `TeacherDashboardScreen`-related failures (unchanged from `master`); nothing that was passing before now fails.

- [ ] **Step 4: Drive it manually per this repo's `verify` skill**

Use the `run` skill to launch the app, sign in as a teacher with at least one enrolled student, open the Classroom tab, tap "Hot seat", and confirm: the roster grid appears, tapping a name opens the tracing canvas with that name in the header, drawing something and tapping Done shows the "Saved to ...'s progress" snackbar and closes the sheet, and "Draw lots" spins and lands on a name that also opens the canvas correctly.
