import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// A reusable avatar widget that renders the high-quality mascot profile pictures
/// or falls back to emoji characters for backwards compatibility.
///
/// For mascot avatars, it shows the dedicated round profile-pic assets
/// (boy_avatar_profile.jpg / girl_avatar_profile.jpg) which are designed
/// specifically for use as circular profile pictures.
class LearnerAvatar extends StatelessWidget {
  const LearnerAvatar({
    super.key,
    required this.avatar,
    this.size = 44,
  });

  final String avatar;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isBoyMascot = avatar == 'boy_mascot';
    final isGirlMascot = avatar == 'girl_mascot';

    if (isBoyMascot || isGirlMascot) {
      // Use the dedicated round profile-picture assets so the face always
      // fills the circle perfectly — no cropping math needed.
      final assetPath = isBoyMascot
          ? 'assets/images/boy_avatar_profile.jpg'
          : 'assets/images/girl_avatar_profile.jpg';

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
        child: Text(
          avatar,
          style: TextStyle(fontSize: size * 0.48),
        ),
      ),
    );
  }
}
