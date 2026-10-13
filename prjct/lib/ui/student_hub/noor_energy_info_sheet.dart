import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../logic/learner/noor_energy_provider.dart';
import '../theme/app_colors.dart';
import 'hub_info_sheet.dart';
import 'hub_world.dart';
import 'noor_energy_resting_sheet.dart' show formatTimeUntilReset;

/// Tapping the lantern pill on `AdventureMapTopBar` opens this — explains
/// what Noor Energy is, how many lanterns are left, and when they refill.
/// Nothing here is a lever the learner can pull (no purchase/earn-more
/// mechanic exists — this app has no backend/store yet), so the sheet is
/// read-only information, not another action sheet.
void showNoorEnergyInfoSheet(BuildContext context) =>
    HubInfoSheet.show(context, const _InfoSheetContent());

class _InfoSheetContent extends ConsumerWidget {
  const _InfoSheetContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final energy = ref.watch(noorEnergyProvider);
    final resetIn = formatTimeUntilReset(DateTime.now());

    return HubInfoSheet(
      title: 'Noor Energy',
      hero: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          children: [
            for (var i = 0; i < energy.maxEnergy; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              _Lantern(lit: i < energy.current),
            ],
          ],
        ),
      ),
      chips: [
        WoodChip(label: '${energy.current} of ${energy.maxEnergy} lanterns lit'),
        WoodChip(
          label: 'Refills in $resetIn',
          icon: const Icon(
            Icons.schedule_rounded,
            size: 15,
            color: AppColors.goldSoft,
          ),
        ),
      ],
      rules: const [
        InfoRule(
          icon: Icons.map_rounded,
          color: HubWorld.goldDeep,
          title: '1 lantern = 1 adventure',
          body: 'Starting a lesson uses 1 lantern. Trying again is free!',
        ),
        InfoRule(
          icon: Icons.nightlight_round,
          color: AppColors.teal,
          title: 'They all come back',
          body: 'Every 4 hours, all 5 lanterns light up again.',
        ),
        InfoRule(
          icon: Icons.backpack_rounded,
          color: AppColors.coral,
          title: 'Out of lanterns?',
          body: 'Visit your Backpack. It never uses a lantern.',
        ),
      ],
    );
  }
}

class _Lantern extends StatelessWidget {
  const _Lantern({required this.lit});

  final bool lit;

  @override
  Widget build(BuildContext context) {
    const image = Image(
      image: AssetImage('assets/images/noor_energy_moon.png'),
      width: 44,
      height: 44,
    );
    if (!lit) return const Opacity(opacity: 0.3, child: image);
    return const GlowArt(child: image);
  }
}
