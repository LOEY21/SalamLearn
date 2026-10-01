import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/data/curriculum_data.dart';
import 'package:salamlearn/logic/learner/unlock_rules.dart';

void main() {
  final stage1 = curriculum[0];
  final stage2 = curriculum[1];
  final stage1Done = {for (final l in stage1.lessons) l.id};

  test('stage 1 is open, stage 2 opens once stage 1 is complete', () {
    expect(isStageUnlocked(null, stage1, const {}), isTrue);
    expect(isStageUnlocked(null, stage2, const {}), isFalse);
    expect(isStageUnlocked(null, stage2, stage1Done), isTrue);
  });

  test('lessons unlock in order, level by level', () {
    final lessons = stage1.lessons;
    final perLevel = (lessons.length / 3).ceil();

    expect(isLessonUnlocked(null, stage1, lessons[0], const {}), isTrue);
    expect(isLessonUnlocked(null, stage1, lessons[1], const {}), isFalse);
    expect(
      isLessonUnlocked(null, stage1, lessons[1], {lessons[0].id}),
      isTrue,
    );
    // First lesson of level 2 needs all of level 1.
    final level1Done = {for (final l in lessons.take(perLevel)) l.id};
    expect(
      isLessonUnlocked(null, stage1, lessons[perLevel], {lessons[0].id}),
      perLevel == 1,
    );
    expect(
      isLessonUnlocked(null, stage1, lessons[perLevel], level1Done),
      isTrue,
    );
    // Nothing in a locked stage is playable.
    expect(
      isLessonUnlocked(null, stage2, stage2.lessons.first, const {}),
      isFalse,
    );
  });
}
