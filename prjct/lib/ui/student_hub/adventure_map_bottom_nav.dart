import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/learner_avatar.dart';
import 'hub_bottom_nav.dart' show HubTab;

/// Floating rounded-pill bottom nav redesigned as a game adventure quest log —
/// features a heavy wood/gold double-frame border with corner rivets, and a
/// sliding gold-lined active medallion indicator. Active icons gently bob
/// up and down to feel "alive".
class AdventureMapBottomNav extends StatelessWidget {
  const AdventureMapBottomNav({
    super.key,
    required this.active,
    required this.onHomeTap,
    required this.onBackpackTap,
    required this.onProfileTap,
    this.learnerAvatar,
    this.showBackpackBadge = false,
  });

  final HubTab active;
  final VoidCallback onHomeTap;
  final VoidCallback onBackpackTap;
  final VoidCallback onProfileTap;

  /// The signed-in learner's own avatar — shown on the "Me" tab instead of
  /// a generic emoji so the nav reflects who's actually using the app.
  final String? learnerAvatar;

  /// Whether to show the small "something new" dot on the Backpack tab —
  /// true when a badge has been earned since the learner last opened that
  /// tab (see `seenBadgeCountProvider`).
  final bool showBackpackBadge;

  @override
  Widget build(BuildContext context) {
    final activeIndex = active.index;

    // Curated themed gradients matching each tab's personality.
    final activeGradient = switch (active) {
      HubTab.home => const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.teal, AppColors.adventureGreen],
        ),
      HubTab.backpack => const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.adventureBlue, AppColors.adventurePurple],
        ),
      HubTab.profile => const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.gold, AppColors.coral],
        ),
    };

    final activeShadowColor = switch (active) {
      HubTab.home => AppColors.teal,
      HubTab.backpack => AppColors.adventureBlue,
      HubTab.profile => AppColors.gold,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Main Bottom Nav Board Container
          Container(
            padding: const EdgeInsets.all(3.5),
            decoration: BoxDecoration(
              color: const Color(0xFF4A3A1E), // Dark wood outline frame
              borderRadius: BorderRadius.circular(32),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x334A3A1E),
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              decoration: BoxDecoration(
                color: AppColors.cream, // Warm parchment background
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: AppColors.goldSoft, width: 1.5), // Inner gold border
              ),
              child: Stack(
                children: [
                  // Sliding indicator background active medallion plate
                  Positioned.fill(
                    child: AnimatedAlign(
                      alignment: Alignment(-1.0 + activeIndex * 1.0, 0.0),
                      duration: const Duration(milliseconds: 320),
                      curve: const Cubic(0.34, 1.56, 0.64, 1.0), // Playful spring curve
                      child: FractionallySizedBox(
                        widthFactor: 0.32,
                        heightFactor: 0.95,
                        child: Container(
                          padding: const EdgeInsets.all(2.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4A3A1E), // Medallion outer frame
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: activeGradient,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.goldSoft, width: 1.0), // Inner gold frame
                              boxShadow: [
                                BoxShadow(
                                  color: activeShadowColor.withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // The interactive tabs Row
                  Row(
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
                          showBadge: showBackpackBadge,
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
                ],
              ),
            ),
          ),
          // Decorative corner rivets
          _buildCornerRivet(top: 8, left: 10),
          _buildCornerRivet(top: 8, right: 10),
          _buildCornerRivet(bottom: 8, left: 10),
          _buildCornerRivet(bottom: 8, right: 10),
        ],
      ),
    );
  }

  Widget _buildCornerRivet({double? top, double? bottom, double? left, double? right}) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.gold,
          border: Border.all(color: const Color(0xFF4A3A1E), width: 1.0),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 1,
              offset: Offset(0, 1),
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
    this.showBadge = false,
  });

  final String emoji;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final String? avatar;
  final String? iconAsset;
  final bool showBadge;

  @override
  State<_Item> createState() => _ItemState();
}

class _ItemState extends State<_Item> {
  static const _duration = Duration(milliseconds: 200);
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
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: const BoxDecoration(
            color: Colors.transparent,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: active ? 1.18 : 1.0,
                duration: _duration,
                curve: _bounce,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _icon(active, avatar, widget.iconAsset, widget.emoji),
                    if (widget.showBadge)
                      Positioned(
                        top: -2,
                        right: -4,
                        child: Container(
                          key: const Key('backpack-nav-badge-dot'),
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: AppColors.coral,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 5),
              AnimatedDefaultTextStyle(
                duration: _duration,
                style: TextStyle(
                  color: active ? Colors.white : AppColors.textMuted,
                  fontFamily: 'Outfit',
                  fontSize: 11.5,
                  fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                  letterSpacing: 0.3,
                ),
                child: Text(widget.label),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _icon(bool active, String? avatar, String? iconAsset, String emoji) {
    if (avatar != null) {
      // Sized consistently to prevent layout shifts. Visually scaled via AnimatedScale instead.
      return LearnerAvatar(avatar: avatar, size: 44);
    }
    if (iconAsset != null) {
      const size = 42.0;
      return Image.asset(
        iconAsset,
        width: size,
        height: size,
        fit: BoxFit.contain,
      );
    }
    return Text(emoji, style: TextStyle(fontSize: active ? 28 : 26));
  }
}
