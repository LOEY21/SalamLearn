import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';

import 'package:salamlearn/data/local/hive_boxes.dart';
import 'package:salamlearn/data/repositories/class_repository.dart';
import 'package:salamlearn/data/repositories/learner_repository.dart';
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

/// `TeacherDashboardScreen`'s `_ClassroomHero` runs a perpetual ambient
/// "breathing" animation (`..repeat(reverse: true)`) once real teacher/class
/// data is loaded — `pumpAndSettle()` waits forever on an animation that
/// never settles. Pump a fixed number of frames instead, long enough for
/// one-shot entrance/transition animations (sheet open, hero entrance) to
/// finish.
Future<void> _pumpSettled(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

/// Pumps `TeacherDashboardScreen` the way it actually needs to be hosted:
/// - Real `GoRouter`, not a bare `MaterialApp(home: ...)` — the screen reads
///   `GoRouterState.of(context)` directly in `build()` (for the `?tab=`
///   query param), which throws without a real router ancestor.
/// - A phone-sized surface (`400x800`, matching this app's own
///   `widget_test.dart` convention) — the default test surface is too short
///   for the Classroom tab's Class Tools panel, causing a RenderFlex
///   overflow that flutter_test treats as a test failure.
Future<void> _pumpTeacherDashboard(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(430, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final router = GoRouter(
    initialLocation: '/teacher',
    routes: [
      GoRoute(path: '/teacher', builder: (_, _) => const TeacherDashboardScreen()),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(child: MaterialApp.router(routerConfig: router)),
  );
  await _pumpSettled(tester);
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
      // The seed helper does real Hive writes + a Random.secure()-backed
      // password hash — calling it directly inside a testWidgets body (not
      // setUp) deadlocks under this binding's test zone. `runAsync` runs it
      // on the real event loop instead, matching Flutter's documented fix
      // for genuine async/IO work inside a widget test body.
      await tester.runAsync(_seedTeacherWithOneStudent);

      await _pumpTeacherDashboard(tester);

      await tester.tap(find.text('Hot seat').first);
      await _pumpSettled(tester);

      // "Amir Ali" appears twice once the sheet is open: once in the
      // dashboard's own student roster behind the sheet, once in the
      // picker grid — the sheet's copy is the later one in the tree
      // (bottom sheets mount via the root Overlay, after the page body).
      expect(find.text('Amir Ali'), findsNWidgets(2));
      expect(find.text('Done'), findsNothing);

      await tester.tap(find.text('Amir Ali').last);
      await _pumpSettled(tester);

      // The canvas step's Done button doesn't exist until Task 3 — this
      // task only proves the picker successfully hands off to the canvas.
      expect(find.text('Hot Seat: Amir Ali'), findsOneWidget);
      expect(find.text('Clear Canvas'), findsOneWidget);
    });
  });
}
