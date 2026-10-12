import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../data/local/hive_boxes.dart';
import '../data/models/badge_award.dart';
import '../data/repositories/progress_repository.dart';
import 'auth/session.dart';
import 'progress_providers.dart';

class RecentModuleNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void interactWith(String moduleId) {
    state = moduleId;
  }
}

final recentModuleProvider = NotifierProvider<RecentModuleNotifier, String?>(
  RecentModuleNotifier.new,
);

/// The active learner's real day streak (0 for a new child, and back to 0
/// once a day is missed).
class LearnerStreakNotifier extends Notifier<int> {
  @override
  int build() {
    final learnerId = ref.watch(sessionProvider.select((s) => s.learner?.id));
    if (learnerId == null || !Hive.isBoxOpen(HiveBoxes.progress)) return 0;
    ref.watch(progressChangesProvider);
    return ProgressRepository().activeStreak(learnerId);
  }

  /// A lesson was just finished today: the streak that play earns (the
  /// progress write right after stores the same value).
  void increment() {
    final learnerId = ref.read(sessionProvider).learner?.id;
    if (learnerId == null || !Hive.isBoxOpen(HiveBoxes.progress)) return;
    state = ProgressRepository().streakAfterPlayingToday(learnerId);
  }
}

final learnerStreakProvider =
    NotifierProvider<LearnerStreakNotifier, int>(LearnerStreakNotifier.new);

class LearnerCompletedTodayNotifier extends Notifier<int> {
  @override
  int build() => 2;

  void increment() => state = state + 1;
}

final learnerCompletedTodayProvider =
    NotifierProvider<LearnerCompletedTodayNotifier, int>(
  LearnerCompletedTodayNotifier.new,
);

/// Badges the active learner has really earned, oldest first — saved per
/// learner as `BadgeAward`s, so a new child starts with none.
class UnlockedBadgesNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    final learnerId = ref.watch(sessionProvider.select((s) => s.learner?.id));
    if (learnerId == null || !Hive.isBoxOpen(HiveBoxes.badges)) return const [];
    ref.watch(_badgeChangesProvider);
    final awards = ProgressRepository().badgesFor(learnerId)
      ..sort((a, b) => a.earnedAt.compareTo(b.earnedAt));
    return [for (final a in awards) a.badgeId];
  }

  void unlockBadge(String badge) {
    if (state.contains(badge)) return;
    state = [...state, badge];
    final learnerId = ref.read(sessionProvider).learner?.id;
    if (learnerId != null && Hive.isBoxOpen(HiveBoxes.badges)) {
      ProgressRepository().awardBadge(learnerId, badge);
    }
  }
}

/// Emits on every badge write, including badges pulled from another device.
final _badgeChangesProvider = StreamProvider<BoxEvent>(
  (ref) => Hive.box<BadgeAward>(HiveBoxes.badges).watch(),
);

final unlockedBadgesProvider =
    NotifierProvider<UnlockedBadgesNotifier, List<String>>(
  UnlockedBadgesNotifier.new,
);

/// How many earned badges the learner has actually seen on the Backpack
/// screen — drives the "something new" dot on the bottom nav's Backpack
/// tab. `BackpackScreen` calls `markSeen` with the current earned count as
/// soon as it opens, so the dot only shows between an unlock and the next
/// visit to that tab.
class SeenBadgeCountNotifier extends Notifier<int> {
  @override
  int build() {
    // Fresh per learner: switching child shouldn't carry the last one's
    // "seen" count.
    ref.watch(sessionProvider.select((s) => s.learner?.id));
    return ref.read(unlockedBadgesProvider).length;
  }

  void markSeen(int count) {
    if (count > state) state = count;
  }
}

final seenBadgeCountProvider = NotifierProvider<SeenBadgeCountNotifier, int>(
  SeenBadgeCountNotifier.new,
);
