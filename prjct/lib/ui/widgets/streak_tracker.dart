import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';

import '../theme/app_colors.dart';

/// The streak flame art: lit while a streak is running, a grey smoking
/// flame at 0 days.
class StreakFlame extends StatelessWidget {
  const StreakFlame({super.key, required this.lit, required this.size});

  final bool lit;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      lit
          ? 'assets/images/badges/streak_flame_on.webp'
          : 'assets/images/badges/streak_flame_off.webp',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}

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
        StreakFlame(lit: streakDays > 0, size: 18),
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
