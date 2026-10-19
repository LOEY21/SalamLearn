import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:salamlearn/logic/localization/app_translations.dart';

import '../../logic/auth/session.dart';
import '../theme/app_colors.dart';
import 'soft_card.dart';

/// "Email address" card for the parent/teacher Settings tabs — the email
/// the active account registered with. Renders nothing for an account
/// without one (pre-email local accounts). Teachers also see their
/// admin-generated Employee ID above it, once one is assigned.
class AccountEmailCard extends ConsumerWidget {
  const AccountEmailCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final notifier = ref.read(sessionProvider.notifier);
    final email = notifier.activeAccountEmail;
    if (email == null || email.isEmpty) return const SizedBox.shrink();
    final employeeId = session.activeRole == UserRole.asatidz
        ? notifier.activeTeacherEmployeeId
        : null;

    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (employeeId != null) ...[
            _AccountRow(
              icon: Icons.badge_outlined,
              label: 'Employee ID',
              value: employeeId,
            ),
            const SizedBox(height: 12),
          ],
          _AccountRow(
            icon: Icons.mail_outline_rounded,
            label: 'Email address',
            value: email,
          ),
        ],
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppColors.mint,
            borderRadius: BorderRadius.circular(11),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 17, color: AppColors.teal),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
