import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Lock hero with a slow ambient glow pulse — same badge construction as
/// consent's shield (`_ShieldBadge` in consent_screen.dart), teal instead
/// of coral, calm/trust register matching an admin PIN gate. Shared by
/// both PIN screens (setup + verify).
class LockBadge extends StatelessWidget {
  const LockBadge({super.key, required this.glow});

  final Animation<double> glow;

  @override
  Widget build(BuildContext context) {
    final pulse = CurvedAnimation(parent: glow, curve: Curves.easeInOut);
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: pulse,
              builder: (context, _) => Opacity(
                opacity: 0.5 + pulse.value * 0.4,
                child: Transform.scale(
                  scale: 0.94 + pulse.value * 0.14,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.teal.withValues(alpha: 0.16),
                          AppColors.teal.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, AppColors.creamDark],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.teal.withValues(alpha: 0.14),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.lock_outline,
                color: AppColors.teal, size: 24),
          ),
        ],
      ),
    );
  }
}
