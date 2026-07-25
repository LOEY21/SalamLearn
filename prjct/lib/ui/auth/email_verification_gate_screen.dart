import 'dart:async';

import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../logic/auth/session.dart';
import '../theme/app_colors.dart';
import '../widgets/soft_card.dart';

/// Parent-only pre-PIN gate (FR-2.1/2.3, Figure 5) — sits between the
/// sign-up form and PIN setup. `SessionNotifier.beginParentEmailVerification`
/// already created the Firebase user and sent its verification link by the
/// time this screen mounts; this just waits for the parent to actually
/// click it, then hands off to `/pin/setup`. Teacher registration
/// deliberately skips this screen entirely (goes straight from the sign-up
/// form to PIN setup, unchanged) — this gate is Parent-only by request.
class EmailVerificationGateScreen extends ConsumerStatefulWidget {
  const EmailVerificationGateScreen({super.key, required this.redirectTarget});

  final String redirectTarget;

  @override
  ConsumerState<EmailVerificationGateScreen> createState() =>
      _EmailVerificationGateScreenState();
}

class _EmailVerificationGateScreenState
    extends ConsumerState<EmailVerificationGateScreen> {
  bool _sending = true;
  bool _sendFailed = false;
  bool _checking = false;
  Timer? _pollTimer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _send();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _sendFailed = false;
    });
    final ok = await ref
        .read(sessionProvider.notifier)
        .beginParentEmailVerification();
    if (!mounted) return;
    setState(() {
      _sending = false;
      _sendFailed = !ok;
    });
    // Once the link has actually been sent, poll in the background so
    // tapping it in Gmail (often the same device, switching back to this
    // app) advances the screen on its own — the "I've verified" button
    // stays as a manual fallback for whenever polling hasn't caught up yet.
    if (ok) _startPolling();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _pollOnce());
  }

  /// Silent variant of [_checkVerified] — no snackbar on a "not yet"
  /// result, since this fires automatically every few seconds and a
  /// recurring "not verified yet" toast would just be noise.
  Future<void> _pollOnce() async {
    if (_navigated || !mounted) return;
    final verified = await ref
        .read(sessionProvider.notifier)
        .refreshParentEmailVerified();
    if (!mounted || _navigated) return;
    if (verified) {
      _pollTimer?.cancel();
      _continueToPin();
    }
  }

  void _continueToPin() {
    if (_navigated) return;
    _navigated = true;
    context.go(
      '/pin/setup?redirect=${Uri.encodeComponent(widget.redirectTarget)}',
    );
  }

  Future<void> _checkVerified() async {
    setState(() => _checking = true);
    final verified = await ref
        .read(sessionProvider.notifier)
        .refreshParentEmailVerified();
    if (!mounted) return;
    setState(() => _checking = false);
    if (verified) {
      _continueToPin();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Not verified yet — check your inbox and tap the link.",
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final email =
        ref.watch(sessionProvider.notifier).pendingParentEmail ?? 'your email';

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.cream,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: SoftCard(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.goldTint,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.mark_email_read_outlined,
                        size: 30,
                        color: AppColors.gold,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Verify your email',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _sending
                          ? 'Sending a verification link to $email...'
                          : _sendFailed
                          ? "Couldn't reach the server to send it — you may be offline."
                          : 'We sent a verification link to $email. Tap it, then come back here.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: AppColors.textMuted,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_sending)
                      const CircularProgressIndicator(color: AppColors.teal)
                    else ...[
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.teal,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: _checking ? null : _checkVerified,
                          child: _checking
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  "I've verified",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: _send,
                        child: const Text(
                          'Resend email',
                          style: TextStyle(color: AppColors.teal),
                        ),
                      ),
                      if (_sendFailed) ...[
                        const SizedBox(height: 4),
                        TextButton(
                          onPressed: _continueToPin,
                          child: const Text(
                            'Continue without verifying',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
