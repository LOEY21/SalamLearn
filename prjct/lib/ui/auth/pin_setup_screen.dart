import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../logic/auth/session.dart';
import '../theme/app_colors.dart';
import '../widgets/pin_pad.dart';
import '../widgets/role_icons.dart';

class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen>
    with TickerProviderStateMixin {
  String? _firstEntry;

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  Animation<double> _in(double start, double end) {
    return CurvedAnimation(
      parent: _c,
      curve: Interval(start, end, curve: Curves.easeOut),
    );
  }

  late final lock = _in(0.0, 0.4);
  late final heading = _in(0.12, 0.48);
  late final subhead = _in(0.20, 0.56);
  late final pad = _in(0.28, 0.68);

  // Captured once at mount, not recomputed on every build — `createPin()`
  // clears the notifier's underlying `_pendingParent`/`_pendingTeacher` as
  // its very first synchronous step, *before* the async account creation
  // finishes. The state change at the end of `createPin()` still triggers
  // a router-driven rebuild of this (still-mounted) screen a moment before
  // the `.then()` callback below navigates away, and re-reading
  // `pendingIsRemoteLinked` live at that point would find it already
  // false — flashing the heading back to "Create Parent PIN" for one
  // frame. Reading it once here keeps the heading stable for this
  // screen's whole lifetime regardless of that mid-flight clear.
  late final bool _remoteLinked = ref
      .read(sessionProvider.notifier)
      .pendingIsRemoteLinked;

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((status) {
      if (status == AnimationStatus.completed) _glow.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    _glow.dispose();
    super.dispose();
  }

  void _handleBack(String? redirect, UserRole role) {
    if (redirect != null) {
      if (redirect.contains('/parent') || redirect.contains('/teacher')) {
        ref.read(sessionProvider.notifier).selectRole(role);
        context.go('/auth');
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
      sessionProvider.select((s) => s.activeRole ?? UserRole.parent),
    );
    // Identity is already proven (email + password just verified against
    // Firebase Auth) — this PIN is only "pick this device's local unlock
    // code", so skip the enter-then-confirm double entry a from-scratch
    // account needs as a typo safety net. See `_remoteLinked`'s doc for
    // why this reads that captured-at-mount field, not a live getter.
    final remoteLinked = _remoteLinked;
    final confirming = !remoteLinked && _firstEntry != null;
    final redirect = GoRouterState.of(context).uri.queryParameters['redirect'];

    final isTeacher = role == UserRole.asatidz;
    final isParent = role == UserRole.parent;

    String headingText;
    String subtitleText;

    if (remoteLinked) {
      // Still PIN *creation* — this is always a brand-new device (that's
      // the only way `remoteLinked` gets set, via the cross-device
      // sign-in/activation paths), so there is no existing local PIN to
      // "enter" yet. Only the enter-then-confirm double-typing is skipped
      // here (identity is already proven via password), not PIN creation
      // itself — the heading must say so, or it reads like the PIN-verify
      // screen and confuses anyone who's never set a device PIN before.
      headingText = isTeacher ? 'Set your Asatidz PIN' : 'Set your Parent PIN';
      subtitleText = isTeacher
          ? 'Choose a 4-digit PIN to lock the Teacher Dashboard on this device'
          : 'Choose a 4-digit PIN to lock the Parent Dashboard on this device';
    } else if (confirming) {
      headingText = 'Confirm your PIN';
      subtitleText = 'Enter the same PIN once more';
    } else {
      if (isTeacher) {
        headingText = 'Create Asatidz PIN';
        subtitleText = 'This locks the Teacher Dashboard and classroom tools';
      } else if (isParent) {
        headingText = 'Create Parent PIN';
        subtitleText = 'This locks the Parent Dashboard and settings';
      } else {
        headingText = 'Create a 4-digit PIN';
        subtitleText = 'This locks settings and grown-up areas';
      }
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
                          FadeTransition(
                            opacity: lock,
                            child: ScaleTransition(
                              scale: lock.drive(Tween(begin: 0.9, end: 1.0)),
                              child: _RoleLockHero(role: role, anim: _glow),
                            ),
                          ),
                          const SizedBox(height: 24),
                          FadeTransition(
                            opacity: heading,
                            child: Text(
                              headingText,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          FadeTransition(
                            opacity: subhead,
                            child: Text(
                              subtitleText,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          FadeTransition(
                            opacity: pad,
                            child: PinPad(
                              key: ValueKey(confirming),
                              onSubmit: (pin) {
                                if (!remoteLinked && !confirming) {
                                  setState(() => _firstEntry = pin);
                                  return true;
                                }
                                if (!remoteLinked && pin != _firstEntry) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "PINs didn't match — try again",
                                      ),
                                    ),
                                  );
                                  setState(() => _firstEntry = null);
                                  return false;
                                }
                                final notifier = ref.read(
                                  sessionProvider.notifier,
                                );
                                final destination =
                                    redirect ??
                                    (role == UserRole.asatidz
                                        ? '/teacher'
                                        : '/parent');
                                notifier
                                    .createPin(pin)
                                    .then((_) {
                                      if (context.mounted) {
                                        context.go(destination);
                                      }
                                    })
                                    .catchError((Object error) {
                                      if (context.mounted) {
                                        setState(() => _firstEntry = null);
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(content: Text('$error')),
                                        );
                                      }
                                    });
                                return true;
                              },
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
    final primaryColor = isTeacher
        ? AppColors.gold
        : (isLearner ? AppColors.gold : AppColors.teal);

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
                        ),
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
