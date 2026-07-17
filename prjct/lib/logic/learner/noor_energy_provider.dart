import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../data/local/hive_boxes.dart';

/// Immutable snapshot of the Noor Energy lives system — 5 max, one spent
/// per module opened from the Adventure Map, refilled once per calendar
/// day (see the design spec's "Data model additions" section for why a
/// full-daily-reset rule was chosen over hourly partial recovery).
class NoorEnergyState {
  const NoorEnergyState({required this.current, required this.maxEnergy});

  final int current;
  final int maxEnergy;

  bool get hasEnergy => current > 0;
}

class NoorEnergyNotifier extends Notifier<NoorEnergyState> {
  static const _maxEnergy = 5;

  // TEMP DEBUG (owner request 2026-07-12): unlimited energy for testing
  // every level across all 7 destinations. Flip back to `false` to restore
  // normal 5-lantern gating — no other change needed.
  static const _debugInfiniteEnergy = true;

  Box<dynamic> get _settings => Hive.box<dynamic>(HiveBoxes.settings);

  String get _todayKey {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  @override
  NoorEnergyState build() {
    if (_debugInfiniteEnergy) {
      return const NoorEnergyState(current: _maxEnergy, maxEnergy: _maxEnergy);
    }
    final lastReset = _settings.get('noorEnergyLastResetDate') as String?;
    if (lastReset != _todayKey) {
      // A new day (or first-ever launch) — refill and stamp today's date.
      _settings.put('noorEnergyCurrent', _maxEnergy);
      _settings.put('noorEnergyLastResetDate', _todayKey);
      return const NoorEnergyState(current: _maxEnergy, maxEnergy: _maxEnergy);
    }
    final current = _settings.get('noorEnergyCurrent') as int? ?? _maxEnergy;
    return NoorEnergyState(current: current, maxEnergy: _maxEnergy);
  }

  /// Will be called when the learner taps an unlocked Adventure Map node,
  /// before navigating into the module — that wiring is a later task, not
  /// yet implemented. A session-level cost per the spec, not a per-question
  /// cost.
  void consume() {
    if (_debugInfiniteEnergy) return;
    if (state.current <= 0) return;
    final next = state.current - 1;
    state = NoorEnergyState(current: next, maxEnergy: state.maxEnergy);
    _settings.put('noorEnergyCurrent', next);
  }
}

final noorEnergyProvider =
    NotifierProvider<NoorEnergyNotifier, NoorEnergyState>(
      NoorEnergyNotifier.new,
    );
