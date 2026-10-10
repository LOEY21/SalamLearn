import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:salamlearn/data/local/hive_boxes.dart';
import 'package:salamlearn/data/models/progress_record.dart';
import 'package:salamlearn/data/repositories/progress_repository.dart';

import '../../test_helpers/hive_test_setup.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await setUpTestHive();
  });

  tearDown(() async {
    await tearDownTestHive(tempDir);
  });

  Future<void> play(String lessonId, DateTime at, {bool homework = true}) =>
      Hive.box<ProgressRecord>(HiveBoxes.progress).put(
        '$lessonId-$at-$homework',
        ProgressRecord(
          id: '$lessonId-$at-$homework',
          learnerId: 'kid',
          moduleId: 'm',
          strokeAccuracyPct: 90,
          sequencingErrors: 0,
          timeOnTaskSeconds: 60,
          completedAt: at,
          assignedByTeacher: homework,
          lessonId: lessonId,
        ),
      );

  test('homeworkDoneAt waits for every lesson, then uses the last first-finish', () async {
    final repo = ProgressRepository();
    await play('a', DateTime(2026, 10, 1));
    await play('b', DateTime(2026, 10, 3), homework: false);
    expect(repo.homeworkDoneAt('kid', ['a', 'b']), isNull);

    await play('b', DateTime(2026, 10, 4));
    await play('a', DateTime(2026, 10, 9)); // replay doesn't move the date
    expect(repo.homeworkDoneAt('kid', ['a', 'b']), DateTime(2026, 10, 4));
  });
}
