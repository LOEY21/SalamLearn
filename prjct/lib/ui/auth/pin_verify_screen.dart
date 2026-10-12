import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../widgets/route_entrance.dart';
import '../../logic/auth/session.dart';
import '../theme/app_colors.dart';
import '../widgets/pin_pad.dart';
import 'forgot_pin_sheet.dart';
import 'pin_gate_frame.dart';

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

  bool _leaving = false;

  Future<void> _handleBack(String? redirect, UserRole role) async {
    // Wait out this screen's own entrance first (see routeEntranceDone),
    // and ignore repeat taps while waiting.
    if (_leaving) return;
    _leaving = true;
    await routeEntranceDone(context);
    if (!mounted) return;
    if (redirect != null) {
      // This screen only ever shows when an account already exists
      // (`hasPin` is true — see the router's admin gate) — there's no
      // in-progress sign-in/sign-up form to "go back into" the way
      // `pin_setup_screen.dart`'s back handler has. It can be reached
      // either straight from the role picker (account already existed on
      // this device) or via the auth hub's Sign In success, so `/roles`
      // is the one destination that's correct either way.
      // Learner Hub's "Switch Account" — backing out hands the device
      // back to the child.
      if (redirect.contains('from=hub') ||
          redirect.contains('/settings') ||
          redirect.contains('/cast')) {
        ref.read(sessionProvider.notifier).selectRole(UserRole.learner);
        context.go('/profile');
        return;
      }
      if (redirect.contains('/parent') || redirect.contains('/teacher')) {
        // Opened on top of the role picker: pop so this screen slides back
        // out the way it came in, revealing the picker underneath.
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/roles');
        }
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
    final redirect = GoRouterState.of(context).uri.queryParameters['redirect'];

    final isTeacher = role == UserRole.asatidz;
    final isParent = role == UserRole.parent;
    final isLearner = role == UserRole.learner;
    final accentColor = (isTeacher || isLearner)
        ? AppColors.gold
        : AppColors.teal;

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
      child: PinGateFrame(
        role: role,
        title: headingText,
        subtitle: subtitleText,
        spin: _spin,
        onBack: () => _handleBack(redirect, role),
        pad: PinPad(
          accentColor: accentColor,
          onSubmit: (pin) {
            final ok = ref.read(sessionProvider.notifier).verifyPin(pin);
            if (ok) {
              context.go(
                redirect ?? (role == UserRole.asatidz ? '/teacher' : '/parent'),
              );
            }
            return ok;
          },
        ),
        footer: [
          if (!isLearner)
            TextButton(
              key: const ValueKey('forgot-pin'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.inkSoft,
                minimumSize: const Size(0, 48),
              ),
              onPressed: () async {
                final done = await showForgotPinSheet(
                  context,
                  accentColor: accentColor,
                );
                if (done && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'PIN updated. Enter your new PIN to continue.',
                      ),
                    ),
                  );
                }
              },
              child: const Text(
                'Forgot PIN?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.tealDark,
              minimumSize: const Size(0, 48),
            ),
            onPressed: () => _handleBack(redirect, role),
            child: const Text(
              'Cancel — back to Student Hub',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
