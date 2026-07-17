import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../logic/learner/noor_energy_provider.dart';
import '../theme/app_colors.dart';
import 'noor_energy_info_sheet.dart';

/// How long until the next local-midnight reset, formatted as "Xh Ym" (or
/// just "Ym" once under an hour) — the reset itself is date-string based
/// (see `NoorEnergyNotifier._todayKey`), so "midnight" is the accurate
/// moment to count down to, not an arbitrary countdown timer of our own.
String formatTimeUntilReset(DateTime now) {
  final nextMidnight = DateTime(now.year, now.month, now.day + 1);
  final remaining = nextMidnight.difference(now);
  final hours = remaining.inHours;
  final minutes = remaining.inMinutes % 60;
  if (hours <= 0) return '${minutes}m';
  return '${hours}h ${minutes}m';
}

/// Shown instead of opening a module when `NoorEnergyState.hasEnergy` is
/// false — wood-and-gold parchment treatment matching the rest of the
/// Adventure Map's game chrome (see `lesson_player_adventure_redesign_mock`
/// dump), replacing the old plain white `AlertDialog`-style sheet.
void showNoorEnergyRestingSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => const _RestingSheetContent(),
  );
}

class _RestingSheetContent extends ConsumerWidget {
  const _RestingSheetContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final energy = ref.watch(noorEnergyProvider);
    final resetIn = formatTimeUntilReset(DateTime.now());

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: const Color(0xFF4A3A1E),
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [
              BoxShadow(
                color: Color(0x334A3A1E),
                blurRadius: 24,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(27),
              border: Border.all(color: AppColors.goldSoft, width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Image(
                  image: AssetImage('assets/images/noor_energy_moon.png'),
                  width: 96,
                  height: 96,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Noor Energy is resting',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Every lantern is out for today. They\'ll light back up '
                  'with a brand new day.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textMuted,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < energy.maxEnergy; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      Opacity(
                        opacity: 0.22,
                        child: const Image(
                          image: AssetImage(
                            'assets/images/noor_energy_moon.png',
                          ),
                          width: 20,
                          height: 20,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.goldTint,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: AppColors.goldSoft, width: 1.2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        size: 14,
                        color: AppColors.gold,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Refills in $resetIn',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.gold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.teal,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Okay, I\'ll wait',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    showNoorEnergyInfoSheet(context);
                  },
                  child: const Text(
                    'Why does this happen?',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
