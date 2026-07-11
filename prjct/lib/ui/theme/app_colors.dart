import 'package:flutter/material.dart';

/// "Madrasah Classic" palette (REFERENCE mockup docs §3):
/// deep teal + warm gold on a cream base — school product, not toy.
abstract final class AppColors {
  static const cream = Color(0xFFFAF6EC);
  static const teal = Color(0xFF0F6E56);
  static const gold = Color(0xFFEF9F27);
  static const coral = Color(0xFFD85A30);
  static const ink = Color(0xFF2C2C2A);

  static const surface = Color(0xFFFFFFFF);
  static const danger = Color(0xFFDC2626);

  // Soft tints used for panels and cards in the mockups.
  static const mint = Color(0xFFE3F0EA); // teal-tinted panel
  static const mintBorder = Color(0xFFBFDCD2);
  static const goldTint = Color(0xFFFBE3BC);
  static const goldSoft = Color(0xFFF7C86F);
  static const mintGreen = Color(0xFF5BC4A0);
  static const coralTint = Color(0xFFF7E0D6);
  static const creamBorder = Color(0xFFE7E0CE);
  static const creamDark = Color(0xFFF1EADA);
  static const textMuted = Color(0xFF6E6E68);
  static const neutralTint = Color(0xFFF4F2ED);

  static const tealDark = Color(0xFF0A4F3E);

  // Adventure Map palette additions (2026-07-10 Learner Hub redesign spec).
  // Named `adventure*` to avoid colliding with the existing `mintGreen`
  // token, which is a different, already-used shade.
  static const adventureBlue = Color(0xFF72C9F8);
  static const adventurePurple = Color(0xFF6C63D6);
  static const adventureGreen = Color(0xFF5B9A1E);
}
