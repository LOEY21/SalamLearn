import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/learner_avatar.dart';
import 'hub_bottom_nav.dart' show HubTab;

/// Floating rounded-pill bottom nav replacing `HubBottomNav`'s flat bar —
/// same `HubTab`/callback contract, only the visual container changes.
/// See the Adventure Map design spec's "BottomNav" section.
class AdventureMapBottomNav extends StatelessWidget {
  const AdventureMapBottomNav({
    super.key,
    required this.active,
    required this.onHomeTap,
    required this.onBackpackTap,
    required this.onProfileTap,
    this.learnerAvatar,
  });

  final HubTab active;
  final VoidCallback onHomeTap;
  final VoidCallback onBackpackTap;
  final VoidCallback onProfileTap;

  /// The signed-in learner's own avatar — shown on the "Me" tab instead of
  /// a generic emoji so the nav reflects who's actually using the app.
  final String? learnerAvatar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          // Parchment, not stark white — the flat white pill read as a
          // clinical system chrome floating over the painterly map. A warm
          // cream base + a hand-drawn-style border + a brown-tinted shadow
          // make the bar feel like a carved signpost belonging to the map's
          // world, matching the "You are here" / node-label plaques.
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.surface, AppColors.cream],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.creamBorder, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x3B4A3A1E),
              blurRadius: 22,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _Item(
                emoji: '🗺️',
                iconAsset: 'assets/images/adventure_map/tab_map.png',
                label: 'Home',
                active: active == HubTab.home,
                onTap: onHomeTap,
              ),
            ),
            Expanded(
              child: _Item(
                emoji: '🎒',
                iconAsset: 'assets/images/adventure_map/tab_backpack.png',
                label: 'Backpack',
                active: active == HubTab.backpack,
                onTap: onBackpackTap,
              ),
            ),
            Expanded(
              child: _Item(
                emoji: '🙂',
                avatar: learnerAvatar,
                label: 'Me',
                active: active == HubTab.profile,
                onTap: onProfileTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Item extends StatefulWidget {
  const _Item({
    required this.emoji,
    required this.label,
    required this.active,
    required this.onTap,
    this.avatar,
    this.iconAsset,
  });

  // Render priority: [avatar] (learner's own pic, Me tab) > [iconAsset]
  // (the custom cartoon PNGs the owner supplied for Home/Backpack) >
  // [emoji] (fallback if neither is set / the asset can't load).
  final String emoji;
  final String label;
  final bool active;
  final VoidCallback onTap;

  /// When set, renders the learner's own avatar instead of [emoji] — only
  /// the "Me" tab passes this.
  final String? avatar;

  /// When set, renders a bundled PNG glyph instead of [emoji].
  final String? iconAsset;

  @override
  State<_Item> createState() => _ItemState();
}

class _ItemState extends State<_Item> {
  static const _duration = Duration(milliseconds: 200);
  // Playful-archetype overshoot (motion-design spec) — but overshoot only
  // ever gets applied to *scale* below. A `BoxDecoration` tween (color/
  // gradient/shadow) can't handle a curve whose output leaves [0, 1] —
  // `Color.lerp` extrapolates past the two endpoint colors, which read as a
  // one-frame flash of an out-of-palette colour every time the active tab
  // changes. Container decoration always eases with a plain curve instead.
  static const _bounce = Cubic(0.34, 1.56, 0.64, 1.0);

  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    final avatar = widget.avatar;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: _duration,
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: BoxDecoration(
            gradient: active
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.teal, AppColors.adventureGreen],
                  )
                : null,
            color: active ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: AppColors.teal.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: active ? 1.15 : 1.0,
                duration: _duration,
                curve: _bounce,
                child: _icon(active, avatar, widget.iconAsset, widget.emoji),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: _duration,
                style: TextStyle(
                  color: active ? Colors.white : AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                ),
                child: Text(widget.label),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Render priority: learner avatar (Me) > bundled PNG (Home/Backpack) >
  // emoji fallback. Avatar is sized large (learner's face); PNG glyphs sit
  // at the icon scale of the emoji they replace.
  Widget _icon(bool active, String? avatar, String? iconAsset, String emoji) {
    if (avatar != null) {
      return LearnerAvatar(avatar: avatar, size: active ? 40 : 34);
    }
    if (iconAsset != null) {
      return Image.asset(
        iconAsset,
        width: active ? 26 : 24,
        height: active ? 26 : 24,
        fit: BoxFit.contain,
      );
    }
    return Text(emoji, style: TextStyle(fontSize: active ? 22 : 20));
  }
}
