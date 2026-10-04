import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Immutable snapshot of the Noor Energy lives system — 5 max, one spent
/// per module opened from the Adventure Map, all refilled together at the
/// start of every 4-hour window of the local day (12am, 4am, 8am, 12pm,
/// 4pm, 8pm) rather than trickling back one at a time.
class NoorEnergyState {
  const NoorEnergyState({required this.current, required this.maxEnergy});

  final int current;
  final int maxEnergy;

  bool get hasEnergy => true;
}

class NoorEnergyNotifier extends Notifier<NoorEnergyState> {
  static const _maxEnergy = 5;
  static const refillHours = 4;

  /// Start of the next refill window after [now].
  static DateTime nextRefill(DateTime now) => DateTime(
    now.year,
    now.month,
    now.day,
    (now.hour ~/ refillHours + 1) * refillHours,
  );

  @override
  NoorEnergyState build() {
    return const NoorEnergyState(current: _maxEnergy, maxEnergy: _maxEnergy);
  }

  /// Unlimited Noor Energy mode: energy is never consumed.
  void consume() {}
}

final noorEnergyProvider =
    NotifierProvider<NoorEnergyNotifier, NoorEnergyState>(
      NoorEnergyNotifier.new,
    );
