import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../data/curriculum_data.dart';
import '../../data/local/hive_boxes.dart';
import '../../data/repositories/progress_repository.dart';
import '../auth/session.dart';

/// Total XP the active learner has earned: the XP of every lesson they've
/// actually finished (only a first completion is recorded, matching how
/// the lesson player awards it). Derived from their own progress records,
/// so a new child starts at 0 and never inherits another child's XP.
/// Backs the Adventure Map top bar's stars/XP pill and the Me tab.
class LearnerXpNotifier extends Notifier<int> {
  @override
  int build() {
    final learnerId = ref.watch(sessionProvider.select((s) => s.learner?.id));
    if (learnerId == null || !Hive.isBoxOpen(HiveBoxes.progress)) return 0;
    final done = ProgressRepository().completedLessonIds(learnerId);
    return xpForLessons(done);
  }

  /// Called as a lesson finishes, just before its progress record is
  /// written, so the pill updates at once.
  void addXp(int amount) => state = state + amount;
}

/// Sum of the curriculum XP for the given finished lesson ids.
int xpForLessons(Set<String> lessonIds) => [
  for (final d in curriculum)
    for (final l in d.lessons)
      if (lessonIds.contains(l.id)) l.xp,
].fold(0, (a, b) => a + b);

final learnerXpProvider = NotifierProvider<LearnerXpNotifier, int>(
  LearnerXpNotifier.new,
);
