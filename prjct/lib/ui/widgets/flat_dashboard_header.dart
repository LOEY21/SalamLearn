import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'mock_icons.dart';

/// Flat white app-bar replacing the old teal gradient hero — avatar ring,
/// eyebrow/title, a live status pill, and up to two trailing icon actions.
/// Shared by the Parent and Teacher dashboard shells (top-tab redesign).
class FlatDashboardHeader extends StatelessWidget {
  const FlatDashboardHeader({
    super.key,
    required this.avatar,
    required this.eyebrow,
    required this.title,
    this.statusLabel,
    this.actions = const [],
  });

  final Widget avatar;
  final String eyebrow;
  final String title;
  final String? statusLabel;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 14, 12),
      child: Row(
        children: [
          avatar,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  eyebrow,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: AppColors.textMuted,
                  ),
                ),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: AppColors.ink,
                  ),
                ),
                if (statusLabel != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _PulsingDot(),
                      const SizedBox(width: 5),
                      Text(
                        statusLabel!,
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.teal,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          for (final action in actions) ...[const SizedBox(width: 8), action],
        ],
      ),
    );
  }
}

/// Icon button matching the mock's flat neutral square icon buttons.
class HeaderIconButton extends StatelessWidget {
  const HeaderIconButton({
    super.key,
    required this.iconPath,
    required this.onTap,
    this.tooltip,
  });

  /// Raw SVG path markup (see [MockIcons]).
  final String iconPath;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: AppColors.neutralTint,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Center(child: MockIcon(iconPath, size: 17, color: AppColors.ink)),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 1.0, end: 0.35).animate(
        CurvedAnimation(parent: _c, curve: Curves.easeInOut),
      ),
      child: Container(
        width: 5,
        height: 5,
        decoration: const BoxDecoration(
          color: AppColors.teal,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
