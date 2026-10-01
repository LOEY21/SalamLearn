import 'dart:io';

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
import 'package:salamlearn/logic/teacher/teacher_providers.dart';
import 'package:salamlearn/ui/teacher_dashboard/home_mode_dashboard_screen.dart';

import '../../test_helpers/hive_test_setup.dart';

/// Overrides the Notifier itself (not just the provider) so the real
/// Hive-backed `TeacherClassController.build` never runs — same pattern
/// `module_library_screen_test.dart` uses.
class _FakeTeacherClassController extends TeacherClassController {
  _FakeTeacherClassController(this._section);
  final ClassSection? _section;

  @override
  ClassSection? build() => _section;
}

void main() {
  late Directory tempDir;
  late ClassSection section;
  const learnerId = 'learner-1';

  setUp(() async {
    tempDir = await setUpTestHive();

    section = ClassSection(
      id: 'class-1',
      teacherId: 'teacher-1',
      name: 'Grade 1 - Section A',
      invitationCode: 'ABC123',
      createdAt: DateTime(2026, 1, 1),
    );
    await Hive.box<ClassSection>(HiveBoxes.classes).put(section.id, section);

    await Hive.box<LearnerProfile>(HiveBoxes.learners).put(
      learnerId,
      LearnerProfile(id: learnerId, name: 'Amira', age: 6),
    );

    await Hive.box<Enrollment>(HiveBoxes.enrollments).put(
      '${section.id}:$learnerId',
      Enrollment(
        classId: section.id,
        learnerId: learnerId,
        enrolledAt: DateTime(2026, 1, 2),
      ),
    );

    final progress = Hive.box<ProgressRecord>(HiveBoxes.progress);
    final now = DateTime.now();
    // Real home-mode (isClassroomMode: false) records against destination
    // id 1 ("Welcome to Madrasah" in curriculum_data.dart) so
    // homeModeModuleSummaryProvider/homeModeAggregateProvider have
    // non-empty rows to render.
    await progress.put(
      'r1',
      ProgressRecord(
        id: 'r1',
        learnerId: learnerId,
        moduleId: '1',
        strokeAccuracyPct: 92,
        sequencingErrors: 0,
        timeOnTaskSeconds: 300,
        completedAt: now,
        lessonId: curriculum.first.lessons.first.id,
      ),
    );
    await progress.put(
      'r2',
      ProgressRecord(
        id: 'r2',
        learnerId: learnerId,
        moduleId: '1',
        strokeAccuracyPct: 88,
        sequencingErrors: 1,
        timeOnTaskSeconds: 240,
        completedAt: now.subtract(const Duration(days: 1)),
        lessonId: curriculum.first.lessons.first.id,
      ),
    );
  });

  tearDown(() async {
    await tearDownTestHive(tempDir);
  });

  testWidgets('individual view shows the accuracy ring and games with sessions', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          teacherClassControllerProvider.overrideWith(
            () => _FakeTeacherClassController(section),
          ),
        ],
        child: const MaterialApp(home: HomeModeDashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Opens on the list of all students; tapping one shows their detail.
    expect(find.text('ALL STUDENTS · 1'), findsOneWidget);
    expect(find.textContaining('90% accuracy'), findsOneWidget);
    await tester.tap(find.text('Amira'));
    await tester.pumpAndSettle();

    expect(find.text('All students'), findsOneWidget);
    expect(find.text('90%'), findsWidgets); // accuracy ring average
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    // Games list: tapping a game shows its sessions with this student's score.
    expect(find.text('Amira · PROGRESS'), findsOneWidget);
    await tester.ensureVisible(find.text('Greeting Match'));
    await tester.tap(find.text('Greeting Match'));
    await tester.pumpAndSettle();
    expect(find.text('Session 1'), findsOneWidget);
    expect(find.text('Session 2'), findsOneWidget);
    // Session 2 sits in a later stage Amira hasn't unlocked yet.
    expect(find.text('Not played'), findsNothing);
    expect(find.text('Locked'), findsWidgets);

    // Same progress grouped by the 7 map stages instead.
    await tester.scrollUntilVisible(
      find.text('7 Stages'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('7 Stages'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Stage 1: Welcome to Madrasah'));
    await tester.tap(find.text('Stage 1: Welcome to Madrasah'));
    await tester.pumpAndSettle();
    expect(find.textContaining('1 of 5 sessions played · '), findsOneWidget);

    // The top-bar back arrow returns to the list before leaving the screen.
    await tester.tap(find.byIcon(Icons.arrow_back_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text('ALL STUDENTS · 1'), findsOneWidget);
  });

  testWidgets('searching filters the student list', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          teacherClassControllerProvider.overrideWith(
            () => _FakeTeacherClassController(section),
          ),
        ],
        child: const MaterialApp(home: HomeModeDashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'ami');
    await tester.pumpAndSettle();
    expect(find.text('Amira'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('Amira'), findsNothing);
    expect(find.text('No student matches "zzz".'), findsOneWidget);
  });

  testWidgets('aggregate view shows the tinted stat blocks and games with sessions', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          teacherClassControllerProvider.overrideWith(
            () => _FakeTeacherClassController(section),
          ),
        ],
        child: const MaterialApp(home: HomeModeDashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Aggregate'));
    await tester.pumpAndSettle();

    expect(find.text('PLAY RATE'), findsOneWidget);
    expect(find.text('AVG ACCURACY'), findsOneWidget);
    expect(find.text('CLASS PROGRESS'), findsOneWidget);
    expect(find.text('1 of 1 student played · 2 sessions'), findsOneWidget);

    await tester.ensureVisible(find.text('Greeting Match'));
    await tester.tap(find.text('Greeting Match'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Madrasah · 1/1 played'), findsOneWidget);
    expect(find.text('No plays yet'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('7 Stages'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('7 Stages'));
    await tester.pumpAndSettle();
    expect(find.text('Stage 1: Welcome to Madrasah'), findsOneWidget);
    expect(find.text('1 of 1 student played · 5 sessions'), findsOneWidget);
  });
}
