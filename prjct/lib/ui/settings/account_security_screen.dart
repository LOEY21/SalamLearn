import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_colors.dart';
import '../widgets/delete_account_dialog.dart';
import '../widgets/hub_kit.dart';

/// Settings → Account row that opens [AccountSecurityScreen]. Shared by
/// the Parent and Teacher hubs; each passes its own account cards as
/// [children] (the Link to Cloud card and PIN accent differ per role).
class AccountSecurityRow extends StatelessWidget {
  const AccountSecurityRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return HubRowSheet(
      children: [
        HubNavRow(
          icon: Icons.shield_outlined,
          title: 'Account & security',
          subtitle: 'Personal info, password, PIN and account deletion',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => AccountSecurityScreen(children: children),
            ),
          ),
        ),
      ],
    );
  }
}

/// Everything about the signed-in parent/teacher account in one place,
/// with Delete account last.
class AccountSecurityScreen extends StatelessWidget {
  const AccountSecurityScreen({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return HubSubpage(
      header: HubSubpageHeader(
        title: 'Account & security',
        subtitle: 'Your details, sign-in and PIN.',
        onBack: () => Navigator.of(context).pop(),
      ),
      body: HubListBody(
        maxWidth: 600,
        children: [
          ...children,
          const SizedBox(height: 12),
          const HubSectionLabel('Danger zone'),
          const HubRowSheet(children: [_DeleteAccountRow()]),
        ],
      ),
    );
  }
}

class _DeleteAccountRow extends ConsumerWidget {
  const _DeleteAccountRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return HubActionRow(
      icon: Icons.delete_outline_rounded,
      iconColor: AppColors.coral,
      title: 'Delete Account',
      subtitle: 'Permanently delete your account and all its data.',
      trailing: HubRowButton(
        label: 'Delete',
        color: AppColors.coral,
        onPressed: () => showDeleteAccountDialog(context, ref),
      ),
    );
  }
}
