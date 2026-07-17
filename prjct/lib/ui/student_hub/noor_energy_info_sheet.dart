import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../logic/learner/noor_energy_provider.dart';
import '../theme/app_colors.dart';
import 'noor_energy_resting_sheet.dart' show formatTimeUntilReset;

/// Tapping the lantern pill on `AdventureMapTopBar` opens this — explains
/// what Noor Energy is, how many lanterns are left, and when they refill.
/// Nothing here is a lever the learner can pull (no purchase/earn-more
/// mechanic exists — this app has no backend/store yet), so the sheet is
/// read-only information, not another action sheet.
void showNoorEnergyInfoSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (sheetContext) => const _InfoSheetContent(),
  );
}

class _InfoSheetContent extends ConsumerWidget {
  const _InfoSheetContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final energy = ref.watch(noorEnergyProvider);
    final used = energy.maxEnergy - energy.current;
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
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(27),
              border: Border.all(color: AppColors.goldSoft, width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.goldTint,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: AppColors.goldSoft,
                          width: 1.2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: const Image(
                        image: AssetImage('assets/images/noor_energy_moon.png'),
                        width: 20,
                        height: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Noor Energy',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: AppColors.neutralTint,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Lantern row + used/left counters.
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.mint,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.mintBorder),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < energy.maxEnergy; i++) ...[
                            if (i > 0) const SizedBox(width: 8),
                            Opacity(
                              opacity: i < energy.current ? 1 : 0.2,
                              child: const Image(
                                image: AssetImage(
                                  'assets/images/noor_energy_moon.png',
                                ),
                                width: 24,
                                height: 24,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _Stat(
                            label: 'Lit now',
                            value: '${energy.current}',
                            color: AppColors.teal,
                          ),
                          _Stat(
                            label: 'Used today',
                            value: '$used',
                            color: AppColors.coral,
                          ),
                          _Stat(
                            label: 'Refills in',
                            value: resetIn,
                            color: AppColors.gold,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                _InfoRow(
                  icon: Icons.map_outlined,
                  title: 'One lantern per adventure',
                  body:
                      'Starting a module from the map spends 1 lantern for '
                      'that whole session — extra tries inside the same '
                      'lesson are free.',
                ),
                const SizedBox(height: 10),
                _InfoRow(
                  icon: Icons.nightlight_round,
                  title: 'All 5 refill together',
                  body:
                      'Lanterns don\'t trickle back one at a time — they '
                      'all relight at once when a new day starts.',
                ),
                const SizedBox(height: 10),
                _InfoRow(
                  icon: Icons.auto_stories_rounded,
                  title: 'Out of lanterns?',
                  body:
                      'Revisit the Backpack to replay earned badges and '
                      'stickers — that never costs energy.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          margin: const EdgeInsets.only(top: 1),
          decoration: BoxDecoration(
            color: AppColors.creamDark,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 15, color: AppColors.teal),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                body,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textMuted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
