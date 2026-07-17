import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How visible the floating chrome (Adventure Map's own top bar, `HubShell`'s
/// bottom nav) should be right now: `1.0` fully shown, `0.0` fully hidden.
/// `AdventureMapScreen` drives this from its own pinch-zoom state — zooming
/// the map in *or* out (either direction) clears the chrome out of the way
/// so the learner has an unobstructed view while actively pinching, and it
/// reappears once they're back at rest. `HubShell` just applies the same
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
