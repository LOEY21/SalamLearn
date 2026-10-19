import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../data/local/hive_boxes.dart';
import '../auth/session.dart';

/// Immutable snapshot of the Noor Energy lives system — 5 max, one spent
/// per new lesson finished. Spent lanterns relight one at a time, one
/// every 24 minutes, so an empty row is full again after 2 hours.
class NoorEnergyState {
  const NoorEnergyState({
    required this.current,
    required this.maxEnergy,
    this.nextLanternAt,
  });

  final int current;
  final int maxEnergy;

  /// When the next spent lantern relights; null while the row is full.
  final DateTime? nextLanternAt;

  bool get hasEnergy => current > 0;
}

class NoorEnergyNotifier extends Notifier<NoorEnergyState> {
  static const _maxEnergy = 5;
  static const perLantern = Duration(minutes: 24);

  /// Swappable in tests.
  static DateTime Function() clock = DateTime.now;

  Box<dynamic> get _settings => Hive.box<dynamic>(HiveBoxes.settings);
  Timer? _timer;

  /// Each learner keeps their own lanterns, so a new child starts full and
  /// never inherits another child's spent ones on a shared device.
  String? _learnerId;
  String get _currentKey => 'noorEnergyCurrent_$_learnerId';
  String get _nextKey => 'noorEnergyNextAt_$_learnerId';

  @override
  NoorEnergyState build() {
    _learnerId = ref.watch(sessionProvider.select((s) => s.learner?.id));
    _timer?.cancel();
    ref.onDispose(() => _timer?.cancel());
    if (_learnerId == null) {
      return const NoorEnergyState(current: _maxEnergy, maxEnergy: _maxEnergy);
    }
    final stamp = _settings.get(_nextKey) as int?;
    return _settle(
      _settings.get(_currentKey) as int? ?? _maxEnergy,
      stamp == null ? null : DateTime.fromMillisecondsSinceEpoch(stamp),
    );
  }

  /// Relights every lantern whose 24 minutes have passed, saves the result
  /// and arms a timer for the next one while the app stays open.
  NoorEnergyState _settle(int current, DateTime? nextAt) {
    final now = clock();
    while (nextAt != null && current < _maxEnergy && !now.isBefore(nextAt)) {
      current++;
      nextAt = current < _maxEnergy ? nextAt.add(perLantern) : null;
    }
    if (current >= _maxEnergy) nextAt = null;
    _settings.put(_currentKey, current);
    if (nextAt == null) {
      _settings.delete(_nextKey);
    } else {
      _settings.put(_nextKey, nextAt.millisecondsSinceEpoch);
      _timer?.cancel();
      final at = nextAt;
      _timer = Timer(at.difference(now), () {
        state = _settle(state.current, at);
      });
    }
    return NoorEnergyState(
      current: current,
      maxEnergy: _maxEnergy,
      nextLanternAt: nextAt,
    );
  }

  /// Called by the lesson player when a new lesson is finished — a
  /// session-level cost, not a per-question one.
  void consume() {
    if (_learnerId == null || state.current <= 0) return;
    // A full row starts its 24-minute clock now; otherwise the lantern
    // already relighting keeps its time.
    state = _settle(
      state.current - 1,
      state.nextLanternAt ?? clock().add(perLantern),
    );
  }
}

final noorEnergyProvider =
    NotifierProvider<NoorEnergyNotifier, NoorEnergyState>(
      NoorEnergyNotifier.new,
    );
