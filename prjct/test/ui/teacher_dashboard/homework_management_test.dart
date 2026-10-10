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
  late LearnerRepository learnerRepo;
  late ClassSection section;

  setUp(() async {
    tempDir = await setUpTestHive();
    classRepo = ClassRepository();
    learnerRepo = LearnerRepository();
    section = await classRepo.create(
      teacherId: 'teacher-1',
      gradeLevel: 'Grade 1',
      section: 'A',
    );
  });

  tearDown(() async {
    await tearDownTestHive(tempDir);
  });

  test(
    'classHomeworkProvider reflects assignment creation, updates, and deletion',
    () async {
      final initialDue = DateTime(2026, 10, 15);
      final assignment = await classRepo.assignModule(
        classId: section.id,
        moduleId: 'alphabet_intro',
        dueDate: initialDue,
      );

      final container = ProviderContainer(
        overrides: [
          teacherClassControllerProvider.overrideWith(
            () => _FakeClass(section),
          ),
        ],
      );
      addTearDown(container.dispose);

      // 1. Initial read
      var homeworks = container.read(classHomeworkProvider);
      expect(homeworks.length, 1);
      expect(homeworks.first['id'], assignment.id);
      expect(homeworks.first['moduleId'], 'alphabet_intro');
      expect(homeworks.first['dueDateRaw'], initialDue);

      // 2. Update assignment module & due date
      final newDue = DateTime(2026, 11, 1);
      final updated = await classRepo.updateAssignment(
        id: assignment.id,
        moduleId: 'wudhu_steps',
        dueDate: newDue,
      );

      expect(updated, isNotNull);
      expect(updated!.moduleId, 'wudhu_steps');
      expect(updated.dueDate, newDue);

      container.invalidate(classHomeworkProvider);
      homeworks = container.read(classHomeworkProvider);
      expect(homeworks.length, 1);
      expect(homeworks.first['moduleId'], 'wudhu_steps');
      expect(homeworks.first['dueDateRaw'], newDue);

      // 3. Delete assignment
      await classRepo.deleteAssignment(assignment.id);
      container.invalidate(classHomeworkProvider);
      homeworks = container.read(classHomeworkProvider);
      expect(homeworks, isEmpty);
    },
  );

  test(
    'classRosterProvider includes assignmentsDetail for individual student assignments',
    () async {
      final learner = await learnerRepo.register(
        parentId: 'parent-1',
        name: 'Yusuf',
        age: 7,
        username: 'yusuf7',
        avatar: 'avatar_1',
        gradeLevel: 'Grade 1',
      );
      await classRepo.enroll(classId: section.id, learnerId: learner.id!);

      final initialDue = DateTime(2026, 10, 12);
      final assignment = await classRepo.assignModule(
        classId: section.id,
        learnerId: learner.id!,
        moduleId: 'alphabet_intro',
        dueDate: initialDue,
      );

      final container = ProviderContainer(
        overrides: [
          teacherClassControllerProvider.overrideWith(
            () => _FakeClass(section),
          ),
        ],
      );
      addTearDown(container.dispose);

      var roster = container.read(classRosterProvider(section.id));
      expect(roster.length, 1);
      final details =
          roster.first['assignmentsDetail'] as List<Map<String, dynamic>>;
      expect(details.length, 1);
      expect(details.first['id'], assignment.id);
      expect(details.first['moduleId'], 'alphabet_intro');
      expect(details.first['dueDateRaw'], initialDue);

      // Update student assignment
      final newDue = DateTime(2026, 10, 25);
      await classRepo.updateAssignment(
        id: assignment.id,
        moduleId: 'daily_duas',
        dueDate: newDue,
      );

      container.invalidate(classRosterProvider(section.id));
      roster = container.read(classRosterProvider(section.id));
      final updatedDetails =
          roster.first['assignmentsDetail'] as List<Map<String, dynamic>>;
      expect(updatedDetails.first['moduleId'], 'daily_duas');
      expect(updatedDetails.first['dueDateRaw'], newDue);

      // Delete student assignment
      await classRepo.deleteAssignment(assignment.id);
      container.invalidate(classRosterProvider(section.id));
      roster = container.read(classRosterProvider(section.id));
      final emptyDetails =
          roster.first['assignmentsDetail'] as List<Map<String, dynamic>>;
      expect(emptyDetails, isEmpty);
    },
  );

  testWidgets(
    'editing active homework with destination slug village-of-salaam opens dialog without crash',
    (tester) async {
      // Real Hive file I/O — inside testWidgets it must run outside the fake
      // test clock, or the write never completes and the test hangs.
      await tester.runAsync(
        () => classRepo.assignModule(
          classId: section.id,
          moduleId: 'village-of-salaam',
          dueDate: DateTime.now().add(const Duration(days: 3)),
        ),
      );

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

      // Class homework is listed inside the "Assign homework" sheet, opened
      // from the Home tab's class tools (there's no separate Homework tab).
      // The Home list builds lazily, so scroll the tool into existence first.
      final assignTool = find.text('Assign homework');
      await tester.scrollUntilVisible(
        assignTool,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(assignTool.first);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final editBtn = find.byTooltip('Edit module');
      expect(editBtn, findsOneWidget);

      await tester.ensureVisible(editBtn);
      await tester.tap(editBtn);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Edit Class Homework'), findsOneWidget);
      expect(find.text('Change Module / Session'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
