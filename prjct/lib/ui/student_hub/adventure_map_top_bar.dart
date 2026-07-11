import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../logic/learner/learner_xp_provider.dart';
import '../../logic/learner/noor_energy_provider.dart';
import '../../logic/recent_module_provider.dart';
import '../theme/app_colors.dart';

/// Pill-style stat row replacing the Learner Hub's previous plain header —
/// see the Adventure Map design spec's "TopBar" section. Shown across all
/// 4 Learner Hub tabs via `HubShell`.
class AdventureMapTopBar extends ConsumerWidget {
  const AdventureMapTopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(learnerStreakProvider);
    final xp = ref.watch(learnerXpProvider);
    final energy = ref.watch(noorEnergyProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _Pill(icon: Icons.local_fire_department, color: AppColors.coral, value: '$streak'),
          _Pill(icon: Icons.star_rounded, color: AppColors.gold, value: '$xp'),
          _Pill(
            icon: Icons.nightlight_round,
            color: AppColors.adventurePurple,
            value: '${energy.current}/${energy.maxEnergy}',
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.color, required this.value});

  final IconData icon;
  final Color color;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.creamBorder, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
        ],
      ),
    );
  }
}
