import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:salamlearn/logic/localization/app_translations.dart';

import '../../logic/auth/session.dart';
import '../theme/app_colors.dart';
import '../widgets/child_profile_form.dart'
    show KhatamPatternPainter, displayText, scaledExtent;
import '../widgets/hub_kit.dart' show HubHeaderChip, fitLongestWord;
import '../widgets/role_icons.dart';

/// Shared frame for the PIN setup and PIN verify gates, in the hubs'
/// visual language: a teal Khatam-pattern panel with the role badge, title
/// and supporting line, then the keypad on the cream canvas. Phones stack
/// the panel above the keypad; tablets, desktops and landscape phones put
/// them side by side. On phones the keypad shrinks to fill the screen;
/// only very short windows fall back to scrolling.
class PinGateFrame extends StatelessWidget {
  const PinGateFrame({
    super.key,
    required this.role,
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.pad,
    required this.spin,
    this.footer = const [],
    this.heroIn,
    this.titleIn,
    this.subtitleIn,
    this.padIn,
  });

  final UserRole role;
  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final Widget pad;
  final List<Widget> footer;

  /// Drives the badge ring's slow turn — the "locked" affordance.
  final Animation<double> spin;

  /// Optional staggered entrance per part (PIN setup uses these).
  final Animation<double>? heroIn;
  final Animation<double>? titleIn;
  final Animation<double>? subtitleIn;
  final Animation<double>? padIn;

  static String _areaLabel(UserRole role) => switch (role) {
    UserRole.asatidz => 'Teacher area',
    UserRole.parent => 'Parent area',
    _ => 'Grown-ups only',
  };

  static Widget _fade(Animation<double>? a, Widget child) =>
      a == null ? child : FadeTransition(opacity: a, child: child);

  @override
  Widget build(BuildContext context) {
    Widget identity(double maxWidth) => Column(
      children: [
        _fade(
          heroIn,
          heroIn == null
              ? _RoleBadge(role: role, spin: spin)
              : ScaleTransition(
                  scale: heroIn!.drive(Tween(begin: 0.9, end: 1.0)),
                  child: _RoleBadge(role: role, spin: spin),
                ),
        ),
        const SizedBox(height: 16),
        HubHeaderChip(
          icon: Icons.lock_outline_rounded,
          label: _areaLabel(role),
        ),
        const SizedBox(height: 12),
        _fade(
          titleIn,
          Text(
            title,
            textAlign: TextAlign.center,
            style: fitLongestWord(
              context,
              title,
              displayText(26, weight: 800, color: Colors.white),
              maxWidth,
            ),
          ),
        ),
        const SizedBox(height: 6),
        _fade(
          subtitleIn,
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.5,
              height: 1.4,
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
        ),
      ],
    );

    final keypad = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _fade(padIn, pad),
        ...footer,
      ],
    );

    Widget backButton() => Align(
      alignment: Alignment.centerLeft,
      child: Tooltip(
        message: 'Back'.tr,
        child: Material(
          color: Colors.white.withValues(alpha: 0.14),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onBack,
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Icon(Icons.arrow_back_rounded, color: Colors.white),
            ),
          ),
        ),
      ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.cream,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            final sideBySide =
                scaledExtent(context, w) >= 560 && (w >= 840 || w > h);

            if (sideBySide) {
              return Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: _TealPanel(
                      rounded: false,
                      child: LayoutBuilder(
                        builder: (context, panel) => SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(12, 8, 24, 24),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: panel.maxHeight - 32,
                            ),
                            child: Column(
                              children: [
                                backButton(),
                                const SizedBox(height: 12),
                                Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 420,
                                    ),
                                    child: LayoutBuilder(
                                      builder: (context, c) =>
                                          identity(c.maxWidth),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 6,
                    child: SafeArea(
                      left: false,
                      // Scroll view spans the whole column so a drag in the
                      // margins scrolls too; the keypad stays centred.
                      child: LayoutBuilder(
                        builder: (context, side) => SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: side.maxHeight - 48,
                            ),
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 420,
                                ),
                                child: keypad,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            final panel = _TealPanel(
              rounded: true,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 24),
                // Back button sits beside the badge, not on its own row, so
                // the keypad below gets that height.
                child: Stack(
                  children: [
                    Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: LayoutBuilder(
                            builder: (context, c) => identity(c.maxWidth),
                          ),
                        ),
                      ),
                    ),
                    Positioned(top: 0, left: 0, child: backButton()),
                  ],
                ),
              ),
            );

            // The keypad shrinks into whatever room the panel leaves, so the
            // page fits the screen without scrolling. Under ~300px the keys
            // would get too small to tap, so the page scrolls instead.
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: panel),
                SliverLayoutBuilder(
                  builder: (context, c) {
                    final room =
                        c.viewportMainAxisExtent - c.precedingScrollExtent;
                    return SliverToBoxAdapter(
                      child: SafeArea(
                        top: false,
                        child: room >= 300
                            ? SizedBox(
                                height:
                                    room - MediaQuery.paddingOf(context).bottom,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    12,
                                    16,
                                    4,
                                  ),
                                  child: Center(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: keypad,
                                    ),
                                  ),
                                ),
                              )
                            : Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  24,
                                  16,
                                  24,
                                ),
                                child: Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 420,
                                    ),
                                    child: keypad,
                                  ),
                                ),
                              ),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TealPanel extends StatelessWidget {
  const _TealPanel({required this.rounded, required this.child});

  final bool rounded;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: rounded
          ? const BorderRadius.vertical(bottom: Radius.circular(28))
          : BorderRadius.zero,
      child: ColoredBox(
        color: AppColors.teal,
        child: CustomPaint(
          painter: const KhatamPatternPainter(),
          child: SafeArea(bottom: !rounded, right: false, child: child),
        ),
      ),
    );
  }
}

/// White disc with the role's icon inside a slowly turning gold ring —
/// the ring's motion is the "locked" affordance. Holds still when the
/// system asks for reduced motion.
class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role, required this.spin});

  final UserRole role;
  final Animation<double> spin;

  @override
  Widget build(BuildContext context) {
    final icon = switch (role) {
      UserRole.asatidz => graduationCapIcon(AppColors.tealDark, size: 38),
      UserRole.parent => familyIcon(AppColors.tealDark, size: 38),
      _ => backpackIcon(AppColors.tealDark, size: 38),
    };
    final ring = Container(
      width: 104,
      height: 104,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: [AppColors.gold, AppColors.goldSoft, AppColors.gold],
        ),
      ),
    );

    return SizedBox(
      width: 104,
      height: 104,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (MediaQuery.of(context).disableAnimations)
            ring
          else
            AnimatedBuilder(
              animation: spin,
              builder: (context, child) =>
                  Transform.rotate(angle: spin.value * 6.28319, child: child),
              child: ring,
            ),
          Container(
            width: 90,
            height: 90,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            alignment: Alignment.center,
            child: icon,
          ),
        ],
      ),
    );
  }
}
