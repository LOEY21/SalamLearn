import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
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
  });

  final HubTab active;
  final VoidCallback onHomeTap;
  final VoidCallback onBackpackTap;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x47000000),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _Item(
                emoji: '🗺️',
                label: 'Home',
                active: active == HubTab.home,
                onTap: onHomeTap,
              ),
            ),
            Expanded(
              child: _Item(
                emoji: '🎒',
                label: 'Backpack',
                active: active == HubTab.backpack,
                onTap: onBackpackTap,
              ),
            ),
            Expanded(
              child: _Item(
                emoji: '🙂',
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
  });

  // Literal emoji glyphs, not IconData — matches the approved preview's
  // `<span class="icon">🗺️</span>` etc. exactly (dumps/adventure_map_preview
  // /preview.html), rather than a Material-icon approximation.
  final String emoji;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_Item> createState() => _ItemState();
}

class _ItemState extends State<_Item> {
  static const _duration = Duration(milliseconds: 200);
  // Playful-archetype overshoot (motion-design spec) — the active tab's
  // pill/icon settle with a slight bounce rather than easing flatly in.
  static const _bounce = Cubic(0.34, 1.56, 0.64, 1.0);

  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
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
          curve: _bounce,
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
                child: Text(
                  widget.emoji,
                  style: TextStyle(fontSize: active ? 22 : 20),
                ),
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
}
