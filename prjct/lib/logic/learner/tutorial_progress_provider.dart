import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../data/local/hive_boxes.dart';
import '../auth/session.dart';

/// Whether the signed-in learner has already seen the mascot's first-run
/// Adventure Map tutorial — persisted per-learner in the `settings` box
/// (same box/pattern as every other unstructured flag in this app) so it
/// only ever shows once, not once per app restart.
class TutorialSeenNotifier extends Notifier<bool> {
  Box<dynamic> get _settings => Hive.box<dynamic>(HiveBoxes.settings);

  @override
  bool build() {
    final learnerId = ref.watch(sessionProvider.select((s) => s.learner?.id));
    if (learnerId == null) return true;
    return _settings.get('tutorial_seen_$learnerId', defaultValue: false)
        as bool;
  }

  void markSeen() {
    final learnerId = ref.read(sessionProvider).learner?.id;
    if (learnerId == null) return;
    _settings.put('tutorial_seen_$learnerId', true);
    state = true;
  }
}

final tutorialSeenProvider =
    NotifierProvider<TutorialSeenNotifier, bool>(TutorialSeenNotifier.new);
