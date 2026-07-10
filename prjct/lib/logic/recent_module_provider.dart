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
