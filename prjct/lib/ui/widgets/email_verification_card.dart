import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'soft_card.dart';

/// Shows nothing for a Learner session, an account with no Firebase link
/// (registered fully offline — see `ParentRepository.register`'s doc), or
/// an already-verified email. Otherwise surfaces the verification-link
/// email `ParentRepository`/`TeacherRepository.register` already sent at
/// signup, with a resend action and a manual "I've verified" refresh
/// (Firebase Auth doesn't push `emailVerified` changes to an already-loaded
/// `User` object — it has to be re-fetched via `reload()`).
///
/// Shared between `settings_screen.dart` (Learner Hub's "Parent Settings"
/// route) and the Parent Dashboard's own `_SettingsTab` — same account,
/// same status, no reason to duplicate this widget in both places.
class EmailVerificationCard extends StatefulWidget {
  const EmailVerificationCard({super.key});

  @override
  State<EmailVerificationCard> createState() => _EmailVerificationCardState();
}

class _EmailVerificationCardState extends State<EmailVerificationCard> {
  bool _busy = false;
  bool _justSent = false;

  Future<void> _resend() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _busy = true);
    try {
      await user.sendEmailVerification();
      if (mounted) {
        setState(() => _justSent = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verification email sent — check your inbox.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not send email: $error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkVerified() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _busy = true);
    try {
      await user.reload();
      final refreshed = FirebaseAuth.instance.currentUser;
      if (mounted) {
        setState(() => _busy = false);
        if (refreshed?.emailVerified ?? false) {
          setState(() {});
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
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.emailVerified) return const SizedBox.shrink();

    return SoftCard(
      color: AppColors.goldTint,
      borderColor: AppColors.goldSoft,
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(11),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.mark_email_unread_outlined,
              size: 17,
              color: AppColors.gold,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Verify your email',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  _justSent
                      ? 'Sent to ${user.email}. Tap the link, then check again below.'
                      : 'We sent a link to ${user.email} when this account was created.',
                  style: const TextStyle(fontSize: 12, color: AppColors.ink),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.ink,
                        side: const BorderSide(color: AppColors.ink),
                      ),
                      onPressed: _busy ? null : _resend,
                      child: const Text('Resend'),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.teal,
                      ),
                      onPressed: _busy ? null : _checkVerified,
                      child: _busy
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text("I've verified"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
