import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/data/models/assigned_module.dart';
import 'package:salamlearn/data/repositories/progress_repository.dart';
import 'package:salamlearn/logic/teacher/teacher_providers.dart';
import 'package:salamlearn/ui/core_modules/module_registry.dart';

import '../../test_helpers/hive_test_setup.dart';

void main() {
  late Directory tempDir;
  final gameId = allGames.first.lesson.id;
  final now = DateTime.now();

  AssignedModule assignment(DateTime due) => AssignedModule(
    id: 'a1',
    classId: 'c1',
    moduleId: gameId,
    dueDate: due,
    assignedAt: now.subtract(const Duration(days: 3)),
  );

  Future<void> finishHomework(String learnerId) =>
      ProgressRepository().writeProgress(
        learnerId: learnerId,
        moduleId: gameId,
        strokeAccuracyPct: 90,
        sequencingErrors: 0,
        timeOnTaskSeconds: 60,
        assignedByTeacher: true,
        lessonId: gameId,
      );

  setUp(() async => tempDir = await setUpTestHive());
  tearDown(() => tearDownTestHive(tempDir));

  HomeworkSubmission status(String learnerId, DateTime due) =>
      homeworkSubmission(
        ProgressRepository(),
        learnerId,
        'Kid',
        assignment(due),
      );

  test('not finished: pending without a due date, overdue once past it', () {
    final pending = status('l1', noDueDate);
    expect(pending.status, HomeworkStatus.pending);
    expect(pending.completedAt, isNull);
    expect(pending.gamesDone, 0);
    expect(pending.gamesTotal, 1);

    expect(
      status('l1', now.add(const Duration(days: 1))).status,
      HomeworkStatus.pending,
    );
    expect(
      status('l1', now.subtract(const Duration(days: 1))).status,
      HomeworkStatus.overdue,
    );
  });

  test('finished: accomplished on time, late after the due date', () async {
    await finishHomework('l1');

    final onTime = status('l1', now.add(const Duration(days: 1)));
    expect(onTime.status, HomeworkStatus.accomplished);
    expect(onTime.completedAt, isNotNull);
    expect(onTime.gamesDone, 1);
    expect(onTime.label, startsWith('Accomplished · '));

    expect(status('l1', noDueDate).status, HomeworkStatus.accomplished);
    expect(
      status('l1', now.subtract(const Duration(days: 1))).status,
      HomeworkStatus.late,
    );
  });
}
