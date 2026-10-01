import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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

  test(
    'a finished lesson reads as completed before the write is awaited',
    () async {
      final repo = ProgressRepository();
      // The lesson player closes and reopens the level sheet in the same
      // frame it calls writeProgress, without awaiting it.
      final pending = repo.writeProgress(
        learnerId: 'kid',
        moduleId: '1',
        strokeAccuracyPct: 90,
        sequencingErrors: 0,
        timeOnTaskSeconds: 30,
        lessonId: 'dest1-s1',
      );
      expect(repo.completedLessonIds('kid'), {'dest1-s1'});
      await pending;
    },
  );
}
