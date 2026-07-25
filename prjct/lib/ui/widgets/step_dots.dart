import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';

import '../theme/app_colors.dart';

/// 3-dot onboarding progress indicator: completed steps gold, active step
/// a teal pill. Shared by the onboarding shell so it persists across route
/// changes and animates in place (grow/shrink/recolor) instead of fading
/// out and back in with each screen.
class StepDots extends StatelessWidget {
  const StepDots({
    super.key,
    required this.activeIndex,
    required this.count,
    this.activeColor = AppColors.teal,
  });

  final int activeIndex;
  final int count;

  /// Color of the active-step pill — coral on consent (warning theme),
  /// teal everywhere else.
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == activeIndex;
        final done = i < activeIndex;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeInOut,
            width: active ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: active
                  ? activeColor
                  : (done ? AppColors.gold : AppColors.creamDark),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }
}
