import 'package:flutter_riverpod/flutter_riverpod.dart';

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

class LearnerStreakNotifier extends Notifier<int> {
  @override
  int build() => 5;

  void increment() => state = state + 1;
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

class UnlockedBadgesNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => ['First Steps', 'Active Learner'];

  void unlockBadge(String badge) {
    if (!state.contains(badge)) {
      state = [...state, badge];
    }
  }
}

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
  int build() => ref.read(unlockedBadgesProvider).length;

  void markSeen(int count) {
    if (count > state) state = count;
  }
}

final seenBadgeCountProvider = NotifierProvider<SeenBadgeCountNotifier, int>(
  SeenBadgeCountNotifier.new,
);
