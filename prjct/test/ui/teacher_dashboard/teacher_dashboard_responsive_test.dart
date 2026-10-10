import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:salamlearn/data/curriculum_data.dart';
import 'package:salamlearn/data/local/hive_boxes.dart';
import 'package:salamlearn/data/models/class_section.dart';
import 'package:salamlearn/data/models/enrollment.dart';
import 'package:salamlearn/data/models/learner_profile.dart';
import 'package:salamlearn/data/models/progress_record.dart';
import 'package:salamlearn/logic/auth/session.dart';
import 'package:salamlearn/logic/progress_providers.dart';
import 'package:salamlearn/logic/teacher/teacher_providers.dart';
import 'package:salamlearn/ui/teacher_dashboard/teacher_dashboard_screen.dart';

import '../../test_helpers/hive_test_setup.dart';
import '../../test_helpers/responsive_harness.dart';

/// Overrides the Notifier itself so the real Hive-backed
/// `TeacherClassController.build` (which needs a signed-in teacher) never
/// runs — same pattern `home_mode_dashboard_screen_test.dart` uses.
class _FakeTeacherClassController extends TeacherClassController {
  _FakeTeacherClassController(this._section);
  final ClassSection? _section;

  @override
  ClassSection? build() => _section;
}

/// Teacher Hub (Home, Classroom, Settings, student details, homework sheet)
/// at every window size and text scale: no overflow, no word broken
/// mid-word, every part reachable by scrolling.
void main() {
  late Directory tempDir;
  late ClassSection section;
  late ProviderContainer container;

  setUpAll(() async {
    await loadRealFonts();
    // Settings shows shared account cards that read FirebaseAuth.
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() async {
    tempDir = await setUpTestHive();
    // Deliberately long class and student names.
    section = ClassSection(
      id: 'class-1',
      teacherId: 'teacher-1',
      name: 'Grade 1 - Section Al-Fatihah',
      invitationCode: 'ABC123',
      createdAt: DateTime(2026, 1, 1),
    );
    await Hive.box<ClassSection>(HiveBoxes.classes).put(section.id, section);
    final students = {
      'ali': ('Muhammad Abdurrahman Al-Farouqi', 92.0),
      'hamza': ('Hamza', 64.0),
      'zara': ('Zara', 40.0),
    };
    final now = DateTime.now();
    for (final MapEntry(key: id, value: (name, accuracy)) in students.entries) {
      await Hive.box<LearnerProfile>(
        HiveBoxes.learners,
      ).put(id, LearnerProfile(id: id, name: name, age: 6));
      await Hive.box<Enrollment>(HiveBoxes.enrollments).put(
        '${section.id}:$id',
        Enrollment(
          classId: section.id,
          learnerId: id,
          enrolledAt: DateTime(2026, 1, 2),
        ),
      );
      await Hive.box<ProgressRecord>(HiveBoxes.progress).put(
        'p-$id',
        ProgressRecord(
          id: 'p-$id',
          learnerId: id,
          moduleId: '${curriculum.first.id}',
          strokeAccuracyPct: accuracy,
          sequencingErrors: 1,
          timeOnTaskSeconds: 300,
          completedAt: now,
          lessonId: curriculum.first.lessons.first.id,
        ),
      );
    }
    container = ProviderContainer(
      overrides: [
        teacherClassControllerProvider.overrideWith(
          () => _FakeTeacherClassController(section),
        ),
        accountStreamProvider.overrideWith((ref) => Stream.value(true)),
        teacherProgressSyncProvider.overrideWith((ref) => const Stream.empty()),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await tearDownTestHive(tempDir);
  });

  Future<void> pumpAt(WidgetTester tester, Size size, double scale) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          key: UniqueKey(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const TeacherDashboardScreen(),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> openTab(WidgetTester tester, String label) async {
    // Short windows scroll the header (and its tabs) away; bring it back.
    final tab = find.text(label);
    await scrollUntilFound(tester, tab, towardsTop: true);
    await tester.tap(tab.first);
    await settle(tester);
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  for (final scale in responsiveTextScales) {
    testWidgets('Home, Classroom and Settings fit at every size, '
        'text x$scale', (tester) async {
      for (final size in responsiveSizes) {
        final label = '${size.width.toInt()}x${size.height.toInt()} @ x$scale';
        await pumpAt(tester, size, scale);
        expect(
          find.text('Grade 1 - Section Al-Fatihah'),
          findsWidgets,
          reason: label,
        );
        await scrollThroughChecking(tester, 'Home $label');

        await openTab(tester, 'Classroom');
        await scrollThroughChecking(tester, 'Classroom $label');

        await openTab(tester, 'Settings');
        await scrollThroughChecking(tester, 'Settings $label');
      }
      await finish(tester);
    });

    testWidgets('student details and homework sheet fit, text x$scale', (
      tester,
    ) async {
      for (final size in [
        responsiveSizes[0],
        responsiveSizes[2],
        responsiveSizes[5],
        responsiveSizes[7],
      ]) {
        final label = '${size.width.toInt()}x${size.height.toInt()} @ x$scale';

        await pumpAt(tester, size, scale);
        await tapToOpen(
          tester,
          find.text('Hamza'),
          find.text('Assign Learning Module'),
          reason: 'Student details $label',
        );
        await scrollThroughChecking(
          tester,
          'Student details $label',
          dragAt: 0.5,
        );

        await pumpAt(tester, size, scale);
        await tapToOpen(
          tester,
          find.text('Assign homework'),
          find.text('Assign to Class'),
          reason: 'Homework sheet $label',
        );
        await scrollThroughChecking(
          tester,
          'Homework sheet $label',
          dragAt: 0.8,
        );
      }
      await finish(tester);
    });
  }
}
