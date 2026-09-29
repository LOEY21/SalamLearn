import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:salamlearn/logic/localization/app_translations.dart';

import '../../logic/auth/session.dart';
import '../theme/app_colors.dart';
import 'auth_loading_overlay.dart';

/// Settings "Delete account" (Parent, Teacher, and /settings) — warns,
/// asks for the account password, then deletes the account.
Future<void> showDeleteAccountDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final notifier = ref.read(sessionProvider.notifier);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => const _DeleteAccountDialog(),
  );
  if (confirmed != true || !context.mounted) return;
  // Navigate off the admin-gated route BEFORE the account is cleared — see
  // auth_loading_overlay.dart's doc on `showAuthLoadingOverlay`.
  context.go('/');
  await runWithAuthLoadingOverlay(
    AuthLoadingAction.erase,
    notifier.deleteAccount,
  );
}

class _DeleteAccountDialog extends ConsumerStatefulWidget {
  const _DeleteAccountDialog();

  @override
  ConsumerState<_DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<_DeleteAccountDialog> {
  final _password = TextEditingController();
  bool _checking = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_password.text.isEmpty) {
      setState(() => _error = 'Enter your password'.tr);
      return;
    }
    setState(() {
      _checking = true;
      _error = null;
    });
    final result = await ref
        .read(sessionProvider.notifier)
        .confirmAccountPassword(_password.text);
    if (!mounted) return;
    if (result == DeleteAccountCheck.ok) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _checking = false;
      _error = result == DeleteAccountCheck.noInternet
          ? 'No internet connection. Connect and try again.'.tr
          : 'Incorrect password'.tr;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(
        Icons.warning_amber_rounded,
        color: AppColors.coral,
        size: 40,
      ),
      title: const Text('Delete your account?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This permanently deletes your account, its profiles, and all '
            'progress. This cannot be undone.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _password,
            obscureText: true,
            autofocus: true,
            enabled: !_checking,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Account password'.tr,
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _checking ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.coral),
          onPressed: _checking ? null : _submit,
          child: _checking
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Delete account'),
        ),
      ],
    );
  }
}
