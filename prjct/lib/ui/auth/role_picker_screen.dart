import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../logic/auth/session.dart';
import '../theme/app_colors.dart';
import '../widgets/role_icons.dart';

/// Entry gate for parent and teacher accounts. Children enter the Learner Hub
/// through a profile created inside the parent's dashboard. The shared
/// Parent/Teacher PIN gate (mockup Figure 4.2) was redesigned per
/// the approved motion-design/ui-ux-pro-max HTML preview: the real app
/// logo as the hero mark, role-specific icons (backpack / family /
/// graduation cap), and a Corporate-personality staggered card entrance.
class RolePickerScreen extends ConsumerStatefulWidget {
  const RolePickerScreen({super.key});

  @override
  ConsumerState<RolePickerScreen> createState() => _RolePickerScreenState();
}

class _RolePickerScreenState extends ConsumerState<RolePickerScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  Animation<double> _in(
    double start,
    double end, {
    Curve curve = Curves.easeOut,
  }) {
    return CurvedAnimation(
      parent: _c,
      curve: Interval(start, end, curve: curve),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(sessionProvider.notifier);

    void pick(UserRole role) {
      notifier.selectRole(role);
      // An account for this role already exists on this device (created
      // here before, or pulled down via cross-device sign-in) — go
      // straight to its dashboard path and let the router's admin gate
      // send it to `/pin/verify` (just the PIN) instead of routing
      // through the full sign-up/sign-in hub again, which would wrongly
      // ask for email + password on a device that's already signed in.
      final hasPin = ref.read(sessionProvider).hasPin;
      if (hasPin) {
        context.go(role == UserRole.asatidz ? '/teacher' : '/parent');
      } else {
        context.go('/auth');
      }
    }

    final mark = _in(0.10, 0.45, curve: Curves.easeOutBack);
    final heading = _in(0.18, 0.42);
    final subhead = _in(0.22, 0.46);
    final card1 = _in(0.30, 0.55);
    final card2 = _in(0.36, 0.62);

    // Without this, hardware/system back had no handling here at all —
    // this app navigates exclusively via `context.go()` (never `.push()`),
    // so there's no real Navigator back-stack for an unhandled back press
    // to pop, and it fell straight through to exiting the app. `/consent`
    // is this screen's actual predecessor in the onboarding order enforced
    // by the router's redirect chain (get-started → language → consent →
    // roles), so that's where back goes regardless of whether this screen
    // was reached via first-time onboarding or via a later logout/switch-
    // user/erase flow.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) context.go('/consent');
      },
      child: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(26, 34, 26, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: FadeTransition(
                opacity: mark,
                child: ScaleTransition(
                  scale: mark.drive(Tween(begin: 0.8, end: 1.0)),
                  child: Container(
                    width: 100,
                    height: 100,
                    padding: const EdgeInsets.all(10),
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
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/logo.png',
                        cacheWidth: 200,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _FadeUp(
              animation: heading,
              child: const Text(
                "Who's using SalamLearn?",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
            ),
            const SizedBox(height: 6),
            _FadeUp(
              animation: subhead,
              child: const Text(
                'Choose an account to continue',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: AppColors.textMuted),
              ),
            ),
            const SizedBox(height: 28),
            _FadeUp(
              animation: card1,
              child: _RoleCard(
                badgeColor: AppColors.mint,
                icon: familyIcon,
                iconColor: AppColors.teal,
                title: 'Parent / Guardian',
                subtitle: 'Add children and track their progress',
                tagIcon: Icons.lock_outline_rounded,
                tagText: 'Requires PIN',
                onTap: () => pick(UserRole.parent),
              ),
            ),
            const SizedBox(height: 14),
            _FadeUp(
              animation: card2,
              child: _RoleCard(
                badgeColor: AppColors.mint,
                icon: graduationCapIcon,
                iconColor: AppColors.teal,
                title: 'Asatidz (Teacher)',
                subtitle: 'Classes, casting & assignments',
                tagIcon: Icons.lock_outline_rounded,
                tagText: 'Requires PIN',
                onTap: () => pick(UserRole.asatidz),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

/// Fades and slides its child upward as [animation] runs 0→1.
class _FadeUp extends StatelessWidget {
  const _FadeUp({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, c) => Transform.translate(
          offset: Offset(0, (1 - animation.value) * 14),
          child: c,
        ),
        child: child,
      ),
    );
  }
}

/// Tappable role-selection card: colored icon badge, title/subtitle, a
/// small info pill (age range or PIN requirement), and a chevron.
class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.badgeColor,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.tagIcon,
    required this.tagText,
    required this.onTap,
  });

  final Color badgeColor;
  final Widget Function(Color color, {double size}) icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final IconData tagIcon;
  final String tagText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: AppColors.creamBorder,
              width: 1.6,
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: icon(iconColor, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMuted,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.creamDark,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            tagIcon,
                            size: 13,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              tagText,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMuted,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 24,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
