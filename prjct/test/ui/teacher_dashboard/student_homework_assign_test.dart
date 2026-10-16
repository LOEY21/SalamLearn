import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/data/models/class_section.dart';
import 'package:salamlearn/data/repositories/class_repository.dart';
import 'package:salamlearn/data/repositories/learner_repository.dart';
import 'package:salamlearn/logic/teacher/teacher_providers.dart';
import 'package:salamlearn/ui/teacher_dashboard/teacher_dashboard_screen.dart';

import '../../test_helpers/hive_test_setup.dart';

class _FakeClass extends TeacherClassController {
  _FakeClass(this._section);
  final ClassSection _section;

  @override
  ClassSection? build() => _section;
}

void main() {
  late Directory tempDir;
  late ClassRepository classRepo;
  late ClassSection section;
  late String learnerId;

  setUp(() async {
    tempDir = await setUpTestHive();
    classRepo = ClassRepository();
    section = await classRepo.create(
      teacherId: 'teacher-1',
      gradeLevel: 'Grade 1',
      section: 'A',
    );
    final learner = await LearnerRepository().register(
      parentId: 'parent-1',
      name: 'Yusuf',
      age: 7,
      username: 'yusuf7',
      avatar: 'avatar_1',
      gradeLevel: 'Grade 1',
    );
    learnerId = learner.id!;
    await classRepo.enroll(classId: section.id, learnerId: learnerId);
  });

  tearDown(() async {
    await tearDownTestHive(tempDir);
  });

  testWidgets('Assign homework sheet assigns to a specific student', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          teacherClassControllerProvider.overrideWith(
            () => _FakeClass(section),
          ),
        ],
        child: const MaterialApp(home: TeacherDashboardScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    final assignTool = find.text('Assign homework');
    await tester.scrollUntilVisible(
      assignTool,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(assignTool.first);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Specific Student'));
    await tester.pump();
    expect(find.text('Select Student'), findsOneWidget);

    final assignBtn = find.text('Assign to Student');
    await tester.ensureVisible(assignBtn);
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(assignBtn);
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(
      classRepo.assignmentsFor(classId: section.id, learnerId: learnerId),
      hasLength(1),
    );
    expect(tester.takeException(), isNull);
  });
}
