import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:salamlearn/logic/localization/app_translations.dart';

import '../../logic/auth/session.dart';
import '../theme/app_colors.dart';
import '../widgets/soft_card.dart';

/// Teacher verification gate (SL-TEA-01..03). A teacher who is not yet
/// approved by an admin lands here after the PIN gate instead of the
/// Asatidz dashboard; the router keeps every `/teacher*` and `/cast*` route
/// closed until [SessionNotifier.activeTeacherApproved] is true. Approval,
/// rejection, and letting a rejected teacher re-apply are all decided by an
/// admin in the web panel — this screen only reflects that status.
class TeacherPendingScreen extends ConsumerStatefulWidget {
  const TeacherPendingScreen({super.key});

  @override
  ConsumerState<TeacherPendingScreen> createState() =>
      _TeacherPendingScreenState();
}

class _TeacherPendingScreenState extends ConsumerState<TeacherPendingScreen> {
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    if (_checking) return;
    setState(() => _checking = true);
    await ref.read(sessionProvider.notifier).refreshTeacherStatus();
    if (!mounted) return;
    setState(() => _checking = false);
  }

  Future<void> _logout() async {
    context.go('/roles');
    await ref.read(sessionProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild whenever the session changes (a refresh swaps the state
    // instance) so the copy below follows the latest status.
    ref.watch(sessionProvider);
    final rejected =
        ref.read(sessionProvider.notifier).activeTeacherStatus == 'rejected';

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.cream,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: SingleChildScrollView(
                child: SoftCard(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: rejected
                              ? AppColors.coralTint
                              : AppColors.goldTint,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          rejected
                              ? Icons.block_outlined
                              : Icons.hourglass_top_rounded,
                          size: 30,
                          color: rejected ? AppColors.coral : AppColors.gold,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        rejected
                            ? 'Request not approved'
                            : 'Waiting for approval',
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        rejected
                            ? 'An administrator did not approve this teacher '
                                  'account. Please contact your administrator.'
                            : 'Your teacher account is being reviewed by an '
                                  'administrator. Teacher tools unlock once '
                                  "it's approved. Connect to the internet and "
                                  'check again.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: AppColors.textMuted,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.teal,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: _checking ? null : _check,
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
                                  'Check status',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: _logout,
                        child: const Text(
                          'Log out',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
