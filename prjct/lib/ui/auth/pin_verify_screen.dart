import 'package:flutter/material.dart';
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
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
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

    String headingText;
    String subtitleText;

    if (isTeacher) {
      headingText = 'Asatidz PIN Gate';
      subtitleText = 'Enter your 4-digit PIN to open the Teacher Dashboard';
    } else if (isParent) {
      headingText = 'Parent PIN Gate';
      subtitleText = 'Enter your 4-digit PIN to open the Parent Dashboard';
    } else {
      headingText = 'Enter 4-digit PIN';
      subtitleText = 'This unlocks settings and grown-up areas';
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
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              child: Row(
                children: [
                  _BackButton(onTap: () => _handleBack(redirect, role)),
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
                        _RoleLockHero(role: role, anim: _pulse),
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
                          child: const Text(
                            'Cancel — back to Student Hub',
                            style: TextStyle(
                              color: AppColors.teal,
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

class _RoleLockHero extends StatelessWidget {
  const _RoleLockHero({required this.role, required this.anim});

  final UserRole role;
  final Animation<double> anim;

  @override
  Widget build(BuildContext context) {
    final isLearner = role == UserRole.learner;
    final isTeacher = role == UserRole.asatidz;
    final primaryColor =
        isTeacher ? AppColors.gold : (isLearner ? AppColors.gold : AppColors.teal);

    Widget getIcon(Color color, double size) {
      if (isTeacher) return graduationCapIcon(color, size: size);
      if (isLearner) return backpackIcon(color, size: size);
      return familyIcon(color, size: size);
    }

    return SizedBox(
      width: 90,
      height: 90,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: anim,
            builder: (context, child) {
              final t = Curves.easeInOut.transform(anim.value);
              final scale = 0.92 + (0.12 * t);
              final opacity = 0.6 + (0.4 * t);
              return Opacity(
                opacity: opacity,
                child: Transform.scale(scale: scale, child: child),
              );
            },
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    primaryColor.withValues(alpha: 0.22),
                    primaryColor.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(
                color: primaryColor.withValues(alpha: 0.18),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.14),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                getIcon(primaryColor, 32),
                Positioned(
                  right: -6,
                  bottom: -6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.coral,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x26000000),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        )
                      ],
                    ),
                    child: const Icon(
                      Icons.lock_rounded,
                      color: Colors.white,
                      size: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
