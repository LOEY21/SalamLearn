import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/data/models/badge_award.dart';
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

  test(
    'homework completion is kept separate from main game map completion',
    () async {
      final repo = ProgressRepository();

      // Complete a lesson as homework (assignedByTeacher = true)
      await repo.writeProgress(
        learnerId: 'learner-1',
        moduleId: '1',
        strokeAccuracyPct: 95,
        sequencingErrors: 0,
        timeOnTaskSeconds: 45,
        lessonId: 'hw-lesson-1',
        assignedByTeacher: true,
      );

      // Complete a lesson in main game map (assignedByTeacher = false)
      await repo.writeProgress(
        learnerId: 'learner-1',
        moduleId: '1',
        strokeAccuracyPct: 90,
        sequencingErrors: 1,
        timeOnTaskSeconds: 60,
        lessonId: 'main-map-lesson-1',
        assignedByTeacher: false,
      );

      // Main game map should ONLY have main-map-lesson-1
      expect(repo.completedLessonIds('learner-1'), {'main-map-lesson-1'});

      // Homework should ONLY have hw-lesson-1
      expect(repo.completedHomeworkLessonIds('learner-1'), {'hw-lesson-1'});

      // Including assigned returns both
      expect(repo.completedLessonIds('learner-1', includeAssigned: true), {
        'hw-lesson-1',
        'main-map-lesson-1',
      });
    },
  );

  test(
    'streak comes from progress records synced from another device',
    () async {
      final repo = ProgressRepository();
      final now = DateTime.now();
      ProgressRecord played(String id, int daysAgo) => ProgressRecord(
        id: id,
        learnerId: 'kid',
        moduleId: '1',
        strokeAccuracyPct: 90,
        sequencingErrors: 0,
        timeOnTaskSeconds: 30,
        completedAt: DateTime(now.year, now.month, now.day - daysAgo, 12),
      );

      expect(repo.currentStreak('kid'), 0);
      await repo.mergeRemote([
        played('a', 1),
        played('b', 2),
        played('c', 2),
        played('d', 4),
      ]);
      expect(repo.currentStreak('kid'), 2);
      expect(repo.activeStreak('kid'), 2);
      expect(repo.streakAfterPlayingToday('kid'), 3);

      await repo.mergeRemote([played('e', 0)]);
      expect(repo.activeStreak('kid'), 3);
    },
  );

  test('badges from another device merge without duplicating', () async {
    final repo = ProgressRepository();
    await repo.awardBadge('kid', 'First Steps Badge');
    await repo.mergeRemoteBadges([
      BadgeAward(
        learnerId: 'kid',
        badgeId: 'First Steps Badge',
        earnedAt: DateTime(2026),
      ),
      BadgeAward(
        learnerId: 'kid',
        badgeId: 'Curious Spark Badge (3-Day Streak)',
        earnedAt: DateTime(2026),
      ),
    ]);
    expect(repo.badgesFor('kid').map((b) => b.badgeId).toSet(), {
      'First Steps Badge',
      'Curious Spark Badge (3-Day Streak)',
    });
    expect(repo.badgesFor('kid'), hasLength(2));
  });
}
