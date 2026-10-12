import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../widgets/route_entrance.dart';
import '../../logic/auth/session.dart';
import '../theme/app_colors.dart';
import '../widgets/pin_pad.dart';
import 'pin_gate_frame.dart';

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

  bool _leaving = false;

  Future<void> _handleBack(String? redirect, UserRole role) async {
    // Wait out this screen's own entrance first (see routeEntranceDone),
    // and ignore repeat taps while waiting.
    if (_leaving) return;
    _leaving = true;
    await routeEntranceDone(context);
    if (!mounted) return;
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
    final accentColor = (isTeacher || isLearner)
        ? AppColors.gold
        : AppColors.teal;

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
      child: PinGateFrame(
        role: role,
        title: headingText,
        subtitle: subtitleText,
        spin: _spin,
        heroIn: lock,
        titleIn: heading,
        subtitleIn: subhead,
        padIn: pad,
        onBack: () => _handleBack(redirect, role),
        pad: PinPad(
          key: ValueKey(confirming),
          accentColor: accentColor,
          onSubmit: (pin) {
            if (!remoteLinked && !confirming) {
              setState(() => _firstEntry = pin);
              return true;
            }
            if (!remoteLinked && pin != _firstEntry) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("PINs didn't match — try again")),
              );
              setState(() => _firstEntry = null);
              return false;
            }
            final notifier = ref.read(sessionProvider.notifier);
            final destination =
                redirect ?? (role == UserRole.asatidz ? '/teacher' : '/parent');
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
                    ).showSnackBar(SnackBar(content: Text('$error')));
                  }
                });
            return true;
          },
        ),
      ),
    );
  }
}
