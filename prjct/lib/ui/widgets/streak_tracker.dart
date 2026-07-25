import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';

import '../theme/app_colors.dart';

/// Compact streak indicator (FR-3.2) as in mockup Figure 4.3:
/// flame icon + "N day streak" in warm gold.
class StreakTracker extends StatelessWidget {
  const StreakTracker({super.key, required this.streakDays});

  final int streakDays;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.local_fire_department,
            color: AppColors.gold, size: 18),
        const SizedBox(width: 4),
        Text(
          '$streakDays day streak',
          style: const TextStyle(
            color: AppColors.gold,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
