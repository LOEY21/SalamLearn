import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';

/// "Madrasah Classic" palette (REFERENCE mockup docs §3):
/// deep teal + warm gold on a cream base — school product, not toy.
abstract final class AppColors {
  static const cream = Color(0xFFFAF6EC);
  static const teal = Color(0xFF0F6E56);
  static const gold = Color(0xFFEF9F27);
  static const coral = Color(0xFFD85A30);
  static const ink = Color(0xFF20241F);

  static const surface = Color(0xFFFFFFFF);
  static const danger = Color(0xFFDC2626);

  // Soft tints used for panels and cards — clean white/cool-neutral
  // system (top-tab dashboard redesign), matches the approved HTML mock
  // 1:1 rather than the older warm-cream Madrasah tints.
  static const mint = Color(0xFFE7F3EF); // teal-tinted panel
  static const mintBorder = Color(0xFFBFDCD2);
  static const goldTint = Color(0xFFFDF1DE);
  static const goldSoft = Color(0xFFF7C86F);
  static const mintGreen = Color(0xFF5BC4A0);
  static const coralTint = Color(0xFFFBE9E2);
  static const creamBorder = Color(0xFFECEEEC);
  static const creamDark = Color(0xFFF1EADA);
  static const textMuted = Color(0xFF7A8079);
  static const neutralTint = Color(0xFFF7F8F7);

  static const tealDark = Color(0xFF0A4F3E);

  // Adventure Map palette additions (2026-07-10 Learner Hub redesign spec).
  // Named `adventure*` to avoid colliding with the existing `mintGreen`
  // token, which is a different, already-used shade.
  static const adventureBlue = Color(0xFF72C9F8);
  static const adventurePurple = Color(0xFF6C63D6);
  static const adventureGreen = Color(0xFF5B9A1E);
}
