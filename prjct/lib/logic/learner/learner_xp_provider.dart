import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../data/local/hive_boxes.dart';

/// Total XP the active learner has earned, persisted under the `settings`
/// Hive box (same box `SessionNotifier` uses for `lastSyncedAt` and
/// friends) — no dedicated Hive box or typed model needed for a single
/// running integer. Backs the Adventure Map TopBar's stars/XP pill.
class LearnerXpNotifier extends Notifier<int> {
  Box<dynamic> get _settings => Hive.box<dynamic>(HiveBoxes.settings);

  @override
  int build() => _settings.get('learnerXp') as int? ?? 0;

  /// Called when a module's DFD-simulator flow reaches `finished` (see
  /// `module_placeholder_screen.dart`'s `_runDfdSimulation`).
  void addXp(int amount) {
    final next = state + amount;
    state = next;
    _settings.put('learnerXp', next);
  }
}

final learnerXpProvider = NotifierProvider<LearnerXpNotifier, int>(
  LearnerXpNotifier.new,
);
