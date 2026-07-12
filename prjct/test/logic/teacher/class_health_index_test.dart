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
}
