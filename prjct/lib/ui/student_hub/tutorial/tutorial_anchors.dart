import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One [GlobalKey] per real widget the mascot tutorial spotlights — the
/// Noor Energy and streak pills (`AdventureMapTopBar`), the learner's own
/// map avatar and current map node (`AdventureMapScreen`), and the
/// Backpack nav tab (`AdventureMapBottomNav`). Each owning widget attaches
/// its key once; [MascotTutorialOverlay] reads `currentContext` off these
/// to measure real screen rects instead of hardcoding coordinates.
///
/// Kept alive for the app's lifetime (default `Provider`, not
/// `autoDispose`) — the Learner Hub's `IndexedStack` branches never
/// rebuild after their first mount, so the same keys stay valid for as
/// long as the hub is open.
class TutorialAnchors {
  final streakPillKey = GlobalKey();
  final energyPillKey = GlobalKey();
  final mapAvatarKey = GlobalKey();
  final currentNodeKey = GlobalKey();
  final backpackTabKey = GlobalKey();
}

final tutorialAnchorsProvider = Provider<TutorialAnchors>(
  (ref) => TutorialAnchors(),
);
