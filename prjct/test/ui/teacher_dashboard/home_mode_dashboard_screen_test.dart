import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
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
    // id 1 ("Village of Salaam" in curriculum_data.dart) so
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
      ),
    );
  });

  tearDown(() async {
    await tearDownTestHive(tempDir);
  });

  testWidgets('individual view shows the accuracy ring and an adventure tile', (
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

    expect(find.text('Amira'), findsWidgets);
    expect(find.text('90%'), findsWidgets); // accuracy ring average
    expect(find.textContaining('Village of Salaam'), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
  });

  testWidgets('aggregate view shows the tinted stat blocks and a module card', (
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
    expect(find.textContaining('Village of Salaam'), findsWidgets);
    expect(find.textContaining('avg accuracy'), findsWidgets);
  });
}
