import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:salamlearn/logic/localization/app_translations.dart';

import '../../logic/auth/session.dart';
import '../auth/auth_choice_screen.dart'
    show PasswordRequirements, passwordRules;
import '../widgets/child_profile_form.dart'
    show ChildFieldLabel, ChildFormBottomBar, ChildFormButton, ChildTextField;
import '../widgets/hub_kit.dart';
import '../widgets/soft_card.dart';
import 'personal_info_screen.dart' show SettingsFieldError;

/// Settings → Account row that opens [ChangePasswordScreen]. Shared by the
/// Parent and Teacher hubs; hidden for a PIN-only account, which has no
/// password to change.
class ChangePasswordRow extends ConsumerWidget {
  const ChangePasswordRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(sessionProvider);
    if (!ref.read(sessionProvider.notifier).activeAccountHasEmail) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: HubRowSheet(
        children: [
          HubNavRow(
            icon: Icons.password_rounded,
            title: 'Change password',
            subtitle: 'Update the password you sign in with',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ChangePasswordScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Current password, new password, confirm. A cloud-linked account needs
/// internet — the new password is set on Firebase Auth before this device,
/// so every device keeps accepting the same one.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _currentC = TextEditingController();
  final _newC = TextEditingController();
  final _confirmC = TextEditingController();

  String? _currentError;
  String? _newError;
  String? _confirmError;
  bool _saving = false;

  @override
  void dispose() {
    _currentC.dispose();
    _newC.dispose();
    _confirmC.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final current = _currentC.text;
    final next = _newC.text;
    setState(() {
      _currentError = current.isEmpty ? 'Enter your current password' : null;
      _newError = !passwordRules.every((r) => r.$2(next))
          ? 'Password doesn\'t meet the requirements below'
          : next == current
          ? 'Choose a password different from your current one'
          : null;
      _confirmError = _confirmC.text != next ? 'Passwords do not match' : null;
    });
    if (_currentError != null || _newError != null || _confirmError != null) {
      return;
    }

    setState(() => _saving = true);
    final result = await ref
        .read(sessionProvider.notifier)
        .changePassword(current: current, next: next);
    if (!mounted) return;
    setState(() => _saving = false);

    final messenger = ScaffoldMessenger.of(context);
    switch (result) {
      case ChangePasswordResult.ok:
        Navigator.of(context).pop();
        messenger.showSnackBar(
          const SnackBar(content: Text('Password changed successfully')),
        );
      case ChangePasswordResult.wrongPassword:
        setState(() => _currentError = 'Incorrect password. Try again.');
      case ChangePasswordResult.noInternet:
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Connect to the internet to change your password'),
          ),
        );
      case ChangePasswordResult.failed:
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Couldn\'t change your password. Try again.'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return HubSubpage(
      header: HubSubpageHeader(
        title: 'Change password',
        subtitle: 'Use it the next time you sign in.',
        onBack: () => Navigator.of(context).pop(),
      ),
      bottomBar: ChildFormBottomBar(
        children: [
          ChildFormButton(
            label: 'Change password',
            icon: Icons.check_rounded,
            busy: _saving,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: HubListBody(
        maxWidth: 600,
        children: [
          SoftCard(
            radius: 20,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const ChildFieldLabel('Current password'),
                ChildTextField(
                  controller: _currentC,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  onChanged: (_) {
                    if (_currentError != null) {
                      setState(() => _currentError = null);
                    }
                  },
                ),
                SettingsFieldError(_currentError),
                const SizedBox(height: 16),
                const ChildFieldLabel('New password'),
                ChildTextField(
                  controller: _newC,
                  obscureText: true,
                  autofillHints: const [AutofillHints.newPassword],
                  onChanged: (_) => setState(() => _newError = null),
                ),
                SettingsFieldError(_newError),
                const SizedBox(height: 10),
                PasswordRequirements(password: _newC.text),
                const SizedBox(height: 16),
                const ChildFieldLabel('Confirm new password'),
                ChildTextField(
                  controller: _confirmC,
                  obscureText: true,
                  autofillHints: const [AutofillHints.newPassword],
                  onChanged: (_) {
                    if (_confirmError != null) {
                      setState(() => _confirmError = null);
                    }
                  },
                ),
                SettingsFieldError(_confirmError),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
