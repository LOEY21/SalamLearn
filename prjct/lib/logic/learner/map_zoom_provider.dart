import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How visible the floating chrome (Adventure Map's own top bar, `HubShell`'s
/// bottom nav) should be right now: `1.0` fully shown, `0.0` fully hidden.
/// `AdventureMapScreen` hides the chrome while the learner is actively
/// pinch-zooming the map, and brings it back as soon as the pinch ends
/// (when the map also eases back to its resting 1x size). `HubShell` just applies the same
/// value to its own bottom nav so both chrome layers move in lockstep.
/// Purely in-memory UI state (resets on app restart like everything else
/// pre-backend).
class MapZoomNotifier extends Notifier<double> {
  @override
  double build() => 1.0;

  void set(double value) => state = value.clamp(0.0, 1.0);
}

final mapZoomProvider = NotifierProvider<MapZoomNotifier, double>(
  MapZoomNotifier.new,
);
