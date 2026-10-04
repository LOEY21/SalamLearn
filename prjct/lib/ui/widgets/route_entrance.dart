import 'dart:async';

import 'package:flutter/widgets.dart';

/// Completes once the current route's entrance transition has finished
/// (straight away if it already has).
///
/// Until then the previous screen stays mounted underneath. Leaving the
/// Student Hub for a PIN screen and tapping Back before the PIN screen has
/// finished sliding in would otherwise build a new hub while the old one
/// still exists — two copies of go_router's shell (same navigator
/// GlobalKeys) and the whole app turns into a red error screen.
Future<void> routeEntranceDone(BuildContext context) {
  final animation = ModalRoute.of(context)?.animation;
  if (animation == null || animation.isCompleted) return Future.value();
  final done = Completer<void>();
  void onStatus(AnimationStatus status) {
    if (status.isCompleted || status.isDismissed) {
      animation.removeStatusListener(onStatus);
      if (!done.isCompleted) done.complete();
    }
  }

  animation.addStatusListener(onStatus);
  // One more frame so the navigator has actually disposed the old screen.
  return done.future.then((_) => WidgetsBinding.instance.endOfFrame);
}
