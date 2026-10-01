import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';

import '../theme/app_colors.dart';

/// Muted lock + "Locked" pill for a stage, game or session the child
/// hasn't unlocked yet (see `isLessonUnlocked`) — used by the parent and
/// teacher progress views.
class LockedTag extends StatelessWidget {
  const LockedTag({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.creamDark,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_rounded, size: 11, color: AppColors.textMuted),
          SizedBox(width: 3),
          Text(
            'Locked',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
