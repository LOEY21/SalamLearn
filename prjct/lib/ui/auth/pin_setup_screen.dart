import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';
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

  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
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
      if (status == AnimationStatus.completed) _spin.repeat();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    _spin.dispose();
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
    final isLearner = role == UserRole.learner;
    final accentColor = (isTeacher || isLearner) ? AppColors.gold : AppColors.teal;
    final roleLabel = isTeacher
        ? 'TEACHER GATE'
        : (isParent ? 'PARENT GATE' : 'LEARNER GATE');

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
                          FadeTransition(
                            opacity: lock,
                            child: ScaleTransition(
                              scale: lock.drive(Tween(begin: 0.9, end: 1.0)),
                              child: _RoleRingHero(role: role, spin: _spin),
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
                              accentColor: accentColor,
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

/// Rotating conic-gradient ring around a white icon disc — the ring's
/// motion is the "locked" affordance, replacing the old static glow +
/// coral lock badge.
class _RoleRingHero extends StatelessWidget {
  const _RoleRingHero({required this.role, required this.spin});

  final UserRole role;
  final Animation<double> spin;

  @override
  Widget build(BuildContext context) {
    final isLearner = role == UserRole.learner;
    final isTeacher = role == UserRole.asatidz;
    final primaryColor = isTeacher
        ? AppColors.gold
        : (isLearner ? AppColors.gold : AppColors.teal);
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
