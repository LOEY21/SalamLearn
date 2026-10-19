import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';
import '../theme/app_colors.dart';

/// The selectable mascot looks, as stored avatar ids. Each set's first id is
/// the original `boy_mascot` / `girl_mascot`, so existing learners keep a
/// valid pick.
const boyMascots = [
  'boy_mascot',
  'boy_mascot_2',
  'boy_mascot_3',
  'boy_mascot_4',
];
const girlMascots = [
  'girl_mascot',
  'girl_mascot_2',
  'girl_mascot_3',
  'girl_mascot_4',
];

/// The full-body art for a mascot avatar id ([face]: its round head-and-
/// shoulders crop), or null for a legacy emoji avatar.
String? mascotAsset(String avatar, {bool face = false}) {
  final m = RegExp(r'^(boy|girl)_mascot(?:_([234]))?$').firstMatch(avatar);
  if (m == null) return null;
  return 'assets/images/mascot_${m[1]}_${m[2] ?? 1}'
      '${face ? '_face.jpg' : '.png'}';
}

/// A reusable avatar widget that renders the mascot's round face crop or
/// falls back to emoji characters for backwards compatibility.
class LearnerAvatar extends StatelessWidget {
  const LearnerAvatar({super.key, required this.avatar, this.size = 44});

  final String avatar;
  final double size;

  @override
  Widget build(BuildContext context) {
    final assetPath = mascotAsset(avatar, face: true);
    if (assetPath != null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: AppColors.creamBorder, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipOval(
          child: Image.asset(
            assetPath,
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    // Fallback to emoji for legacy learners
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.goldTint,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(avatar, style: TextStyle(fontSize: size * 0.48)),
      ),
    );
  }
}
