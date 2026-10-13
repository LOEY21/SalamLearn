import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../data/local/hive_boxes.dart';
import '../../data/remote/firestore_mirror.dart';
import '../auth/session.dart';

/// Whether the signed-in learner has already seen the mascot's first-run
/// Adventure Map tutorial — persisted per-learner in the `settings` box
/// (same box/pattern as every other unstructured flag in this app) so it
/// only ever shows once, not once per app restart. Also mirrored to
/// Firestore so a learner who saw it on one device doesn't get it again
/// on another.
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
    Future.sync(
      () => FirestoreMirror().pushTutorialSeen(learnerId),
    ).catchError((Object e) => debugPrint('markSeen: push failed: $e'));
  }

  /// Checks whether another device already showed the tutorial, adopting
  /// it locally if so. Offline or slow just returns the local value.
  Future<bool> refreshFromRemote() async {
    if (state) return true;
    final learnerId = ref.read(sessionProvider).learner?.id;
    if (learnerId == null) return state;
    try {
      final seen = await FirestoreMirror()
          .fetchTutorialSeen(learnerId)
          .timeout(const Duration(seconds: 3));
      if (seen) {
        _settings.put('tutorial_seen_$learnerId', true);
        state = true;
      }
    } catch (e) {
      debugPrint('TutorialSeen: remote check failed: $e');
    }
    return state;
  }
}

final tutorialSeenProvider = NotifierProvider<TutorialSeenNotifier, bool>(
  TutorialSeenNotifier.new,
);
