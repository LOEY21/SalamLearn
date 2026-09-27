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
/// time this screen mounts; the parent must tap "I've verified" after
/// clicking it to continue to `/pin/setup` — no auto-advance, no skip. Teacher registration
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
  String? _sendError;
  bool _checking = false;
  bool _navigated = false;
  int _cooldown = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    _send(isResend: false);
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldown = 30);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  void _goBack() => context.go('/auth?step=signup');

  Future<void> _send({bool isResend = true}) async {
    setState(() {
      _sending = true;
      _sendError = null;
    });
    final error = await ref
        .read(sessionProvider.notifier)
        .beginParentEmailVerification();
    if (!mounted) return;
    setState(() {
      _sending = false;
      _sendError = error;
    });
    if (error == null && isResend) _startCooldown();
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
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.cream,
        body: SafeArea(
          child: Stack(
            children: [
              Padding(
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
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.cream,
                            border: Border.all(color: AppColors.creamBorder),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.email_outlined,
                                size: 16,
                                color: AppColors.teal,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  email,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.ink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _sending
                              ? 'Sending a verification link to this email...'
                              : _sendError != null
                              ? _sendError!
                              : 'We sent a verification link to this email. Tap it, then come back here.',
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
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
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
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: _cooldown > 0 ? null : () => _send(),
                            child: Text(
                              _cooldown > 0
                                  ? 'Resend email in ${_cooldown}s'
                                  : 'Resend email',
                              style: TextStyle(
                                color: _cooldown > 0
                                    ? AppColors.textMuted
                                    : AppColors.teal,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                left: 12,
                child: IconButton(
                  onPressed: _goBack,
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.ink,
                    side: const BorderSide(color: AppColors.creamBorder),
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
