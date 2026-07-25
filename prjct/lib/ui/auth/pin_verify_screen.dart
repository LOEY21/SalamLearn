import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../logic/auth/session.dart';
import '../theme/app_colors.dart';
import '../widgets/pin_pad.dart';
import '../widgets/role_icons.dart';

class PinVerifyScreen extends ConsumerStatefulWidget {
  const PinVerifyScreen({super.key});

  @override
  ConsumerState<PinVerifyScreen> createState() => _PinVerifyScreenState();
}

class _PinVerifyScreenState extends ConsumerState<PinVerifyScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  void _handleBack(String? redirect, UserRole role) {
    if (redirect != null) {
      // This screen only ever shows when an account already exists
      // (`hasPin` is true — see the router's admin gate) — there's no
      // in-progress sign-in/sign-up form to "go back into" the way
      // `pin_setup_screen.dart`'s back handler has. It can be reached
      // either straight from the role picker (account already existed on
      // this device) or via the auth hub's Sign In success, so `/roles`
      // is the one destination that's correct either way.
      if (redirect.contains('/parent') || redirect.contains('/teacher')) {
        context.go('/roles');
        return;
      }
      if (redirect.contains('/settings') || redirect.contains('/cast')) {
        ref.read(sessionProvider.notifier).selectRole(UserRole.learner);
        context.go('/profile');
        return;
      }
    }
    ref.read(sessionProvider.notifier).selectRole(UserRole.learner);
    context.go('/hub');
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(
        sessionProvider.select((s) => s.activeRole ?? UserRole.parent));
    final redirect = GoRouterState.of(context).uri.queryParameters['redirect'];

    final isTeacher = role == UserRole.asatidz;
    final isParent = role == UserRole.parent;
    final isLearner = role == UserRole.learner;
    final accentColor = (isTeacher || isLearner) ? AppColors.gold : AppColors.teal;

    String headingText;
    String subtitleText;
    String roleLabel;

    if (isTeacher) {
      headingText = 'Asatidz PIN Gate';
      subtitleText = 'Enter your 4-digit PIN to open the Teacher Dashboard';
      roleLabel = 'TEACHER GATE';
    } else if (isParent) {
      headingText = 'Parent PIN Gate';
      subtitleText = 'Enter your 4-digit PIN to open the Parent Dashboard';
      roleLabel = 'PARENT GATE';
    } else {
      headingText = 'Enter 4-digit PIN';
      subtitleText = 'This unlocks settings and grown-up areas';
      roleLabel = 'LEARNER GATE';
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBack(redirect, role);
      },
      child: Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 14, 18, 0),
              child: Row(
                children: [
                  _BackButton(onTap: () => _handleBack(redirect, role)),
                  Expanded(
                    child: Text(
                      roleLabel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 34),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 340),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        _RoleRingHero(role: role, spin: _spin),
                        const SizedBox(height: 24),
                        Text(
                          headingText,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitleText,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 28),
                        PinPad(
                          accentColor: accentColor,
                          onSubmit: (pin) {
                            final ok = ref
                                .read(sessionProvider.notifier)
                                .verifyPin(pin);
                            if (ok) {
                              context.go(redirect ??
                                  (role == UserRole.asatidz
                                      ? '/teacher'
                                      : '/parent'));
                            }
                            return ok;
                          },
                        ),
                        const SizedBox(height: 20),
                        TextButton(
                          onPressed: () => _handleBack(redirect, role),
                          child: Text(
                            'Cancel — back to Student Hub',
                            style: TextStyle(
                              color: accentColor,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.creamBorder, width: 1.4),
          ),
          child: const Icon(Icons.arrow_back, color: AppColors.ink, size: 18),
        ),
      ),
    );
  }
}

/// Rotating conic-gradient ring around a white icon disc — the ring's
/// motion is the "locked" affordance, replacing the old static pulse +
/// coral lock badge.
class _RoleRingHero extends StatelessWidget {
  const _RoleRingHero({required this.role, required this.spin});

  final UserRole role;
  final Animation<double> spin;

  @override
  Widget build(BuildContext context) {
    final isLearner = role == UserRole.learner;
    final isTeacher = role == UserRole.asatidz;
    final primaryColor =
        isTeacher ? AppColors.gold : (isLearner ? AppColors.gold : AppColors.teal);
    final primaryColor2 = isTeacher || isLearner
        ? const Color(0xFFF7C25A)
        : const Color(0xFF14A17F);

    Widget getIcon(Color color, double size) {
      if (isTeacher) return graduationCapIcon(color, size: size);
      if (isLearner) return backpackIcon(color, size: size);
      return familyIcon(color, size: size);
    }

    return SizedBox(
      width: 108,
      height: 108,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: spin,
            builder: (context, child) => Transform.rotate(
              angle: spin.value * 6.28319,
              child: child,
            ),
            child: Container(
              width: 108,
              height: 108,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: [primaryColor, primaryColor2, primaryColor],
                ),
              ),
            ),
          ),
          Container(
            width: 92,
            height: 92,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            alignment: Alignment.center,
            child: getIcon(primaryColor, 36),
          ),
        ],
      ),
    );
  }
}
