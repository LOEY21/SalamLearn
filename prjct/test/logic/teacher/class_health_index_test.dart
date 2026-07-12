import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:salamlearn/data/curriculum_data.dart';
import 'package:salamlearn/data/local/hive_boxes.dart';
import 'package:salamlearn/data/models/progress_record.dart';
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
    await classes.enroll(classId: section.id, learnerId: a.id!);
    await classes.enroll(classId: section.id, learnerId: b.id!);

    await progress.writeProgress(
      learnerId: a.id!,
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
    await classes.enroll(classId: section.id, learnerId: a.id!);
    await progress.writeProgress(
      learnerId: a.id!,
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

  test('enrolled roster with zero records for a module reports hasActivity false', () async {
    final classes = ClassRepository();
    final learners = LearnerRepository();
    final progress = ProgressRepository();
    final moduleId = curriculum.first.id.toString();
    final otherModuleId = curriculum[1].id.toString();

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
    await classes.enroll(classId: section.id, learnerId: a.id!);
    // Learner has activity, but only in a different module.
    await progress.writeProgress(
      learnerId: a.id!,
      moduleId: otherModuleId,
      strokeAccuracyPct: 80,
      sequencingErrors: 0,
      timeOnTaskSeconds: 60,
    );

    final result = computeClassHealthIndex(section.id);
    final moduleHealth = result.firstWhere((m) => m.moduleId == moduleId);

    expect(moduleHealth.hasActivity, isFalse);
    expect(moduleHealth.healthIndex, 0);
  });

  test('trend compares this-week vs prior-week average accuracy', () async {
    final classes = ClassRepository();
    final learners = LearnerRepository();
    final moduleId = curriculum.first.id.toString();
    final progressBox = Hive.box<ProgressRecord>(HiveBoxes.progress);

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
    await classes.enroll(classId: section.id, learnerId: a.id!);

    final now = DateTime.now();
    final thisWeekRecord = ProgressRecord(
      id: 'this-week',
      learnerId: a.id!,
      moduleId: moduleId,
      strokeAccuracyPct: 90,
      sequencingErrors: 0,
      timeOnTaskSeconds: 60,
      completedAt: now.subtract(const Duration(days: 3)),
    );
    final priorWeekRecord = ProgressRecord(
      id: 'prior-week',
      learnerId: a.id!,
      moduleId: moduleId,
      strokeAccuracyPct: 70,
      sequencingErrors: 0,
      timeOnTaskSeconds: 60,
      completedAt: now.subtract(const Duration(days: 10)),
    );
    await progressBox.put(thisWeekRecord.id, thisWeekRecord);
    await progressBox.put(priorWeekRecord.id, priorWeekRecord);

    final result = computeClassHealthIndex(section.id);
    final moduleHealth = result.firstWhere((m) => m.moduleId == moduleId);

    expect(moduleHealth.trend, 20); // 90 - 70

    // Only this-week data present -> trend is null (no prior-week baseline).
    await progressBox.delete(priorWeekRecord.id);
    final resultOnlyThisWeek = computeClassHealthIndex(section.id);
    final moduleHealthOnlyThisWeek =
        resultOnlyThisWeek.firstWhere((m) => m.moduleId == moduleId);
    expect(moduleHealthOnlyThisWeek.trend, isNull);
  });
}
