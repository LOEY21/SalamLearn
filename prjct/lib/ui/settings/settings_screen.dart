import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/learner_profile.dart';
import '../../logic/auth/session.dart';
import '../../logic/settings/settings_providers.dart';
import '../../logic/sync/sync_manager.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_loading_overlay.dart';
import '../widgets/email_verification_card.dart';
import '../widgets/soft_card.dart';

/// Settings & data lifecycle screen — reached either from the Student Hub
/// (behind the parent-PIN gate, `?from=hub`) or directly as a parent/teacher
/// dashboard route. Approved redesign mock: dumps/settings_redesign_mock.html
/// — identity strip replaces the decorative gradient hero, Sync/Switch
/// account collapse into one list card, and Erase gets a visually distinct
/// "danger zone" instead of matching every other card's weight.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volumes = ref.watch(volumeProvider);
    final volumeNotifier = ref.read(volumeProvider.notifier);
    final session = ref.watch(sessionProvider);
    final activeRole = session.activeRole;

    bool fromHub = false;
    try {
      fromHub = GoRouterState.of(context).uri.queryParameters['from'] == 'hub';
    } catch (_) {}
    final backRoute = fromHub
        ? '/hub'
        : switch (activeRole) {
            UserRole.parent => '/parent',
            UserRole.asatidz => '/teacher',
            UserRole.learner || null => '/hub',
          };
    final backLabel = fromHub
        ? 'Back to Student Hub'
        : switch (activeRole) {
            UserRole.parent => 'Back to Parent Dashboard',
            UserRole.asatidz => 'Back to Teacher Dashboard',
            UserRole.learner || null => 'Back to Student Hub',
          };

    void goBack() {
      if (fromHub) {
        ref.read(sessionProvider.notifier).selectRole(UserRole.learner);
      }
      context.go(backRoute);
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) goBack();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: AppColors.ink,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: backLabel,
            onPressed: goBack,
          ),
          title: const Text('Settings'),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _IdentityStrip(
                    fromHub: fromHub,
                    activeRole: activeRole,
                    learner: session.learner,
                  ),
                ),
                _SectionLabel('Sound & Voice'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SoftCard(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        _VolumeSlider(
                          icon: Icons.music_note_outlined,
                          label: 'Background Music',
                          value: volumes.background,
                          onChanged: volumeNotifier.setBackground,
                        ),
                        const Divider(height: 1, color: AppColors.creamBorder),
                        _VolumeSlider(
                          icon: Icons.notifications_none,
                          label: 'UI Sound Effects',
                          value: volumes.effects,
                          onChanged: volumeNotifier.setEffects,
                        ),
                        const Divider(height: 1, color: AppColors.creamBorder),
                        _VolumeSlider(
                          icon: Icons.mic_none,
                          label: 'Pronunciation Voice',
                          value: volumes.voice,
                          onChanged: volumeNotifier.setVoice,
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: EmailVerificationCard(),
                ),
                _SectionLabel('Account & Data'),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: SoftCard(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [_SyncRow(), _SwitchAccountRow()],
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 22, 20, 0),
                  child: _DangerZone(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IdentityStrip extends StatelessWidget {
  const _IdentityStrip({
    required this.fromHub,
    required this.activeRole,
    required this.learner,
  });

  final bool fromHub;
  final UserRole? activeRole;
  final LearnerProfile? learner;

  @override
  Widget build(BuildContext context) {
    final String title;
    final String subtitle;
    final String badge;
    final String initial;

    final activeLearner = learner;
    if (fromHub && activeLearner != null) {
      title = '${activeLearner.name} · ${activeLearner.gradeLevel}';
      subtitle = 'Parent PIN verified';
      badge = 'PARENT MODE';
      initial = activeLearner.name.isNotEmpty
          ? activeLearner.name[0].toUpperCase()
          : '?';
    } else if (activeRole == UserRole.asatidz) {
      title = 'Teacher settings';
      subtitle = 'PIN verified on this device';
      badge = 'TEACHER MODE';
      initial = 'T';
    } else {
      title = 'Parent settings';
      subtitle = 'PIN verified on this device';
      badge = 'PARENT MODE';
      initial = 'P';
    }

    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.mintBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.teal, AppColors.tealDark],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.tealDark,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.mintBorder),
            ),
            child: Text(
              badge,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
                color: AppColors.teal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

class _VolumeSlider extends StatelessWidget {
  const _VolumeSlider({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  String _getVolumeLabel(double v) {
    if (v == 0.0) return 'Muted';
    if (v < 0.25) return 'Quiet';
    if (v < 0.5) return 'Soft';
    if (v < 0.75) return 'Medium';
    if (v < 0.9) return 'Loud';
    return 'Max';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(icon, size: 16, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
              Text(
                _getVolumeLabel(value),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.teal,
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: 0.0,
            max: 1.0,
            activeColor: AppColors.teal,
            inactiveColor: AppColors.creamBorder,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
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
                      title,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _SyncRow extends ConsumerStatefulWidget {
  const _SyncRow();

  @override
  ConsumerState<_SyncRow> createState() => _SyncRowState();
}

class _SyncRowState extends ConsumerState<_SyncRow> {
  bool _syncing = false;

  @override
  Widget build(BuildContext context) {
    return _SettingsRow(
      icon: Icons.sync,
      title: 'Sync now',
      subtitle: 'Sync local device progress with cloud servers',
      trailing: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.teal,
          side: const BorderSide(color: AppColors.teal),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          minimumSize: Size.zero,
        ),
        onPressed: _syncing
            ? null
            : () async {
                setState(() => _syncing = true);
                try {
                  await ref.read(syncManagerProvider).syncNow();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Sync completed successfully!'),
                      ),
                    );
                  }
                } catch (error) {
                  if (mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Sync failed: $error')));
                  }
                } finally {
                  if (mounted) setState(() => _syncing = false);
                }
              },
        child: _syncing
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  color: AppColors.teal,
                  strokeWidth: 2,
                ),
              )
            : const Text('Sync', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class _SwitchAccountRow extends ConsumerWidget {
  const _SwitchAccountRow();

  /// Jumps straight to whichever grown-up dashboard already has an account
  /// on this device — skips the role picker and the Sign Up/Sign In hub
  /// screens entirely (both of those are for a *fresh* account; a device
  /// that's already registered a parent/teacher shouldn't have to walk
  /// through them again just to switch). The router's own redirect
  /// (`app_router.dart`) still requires the PIN before actually reaching
  /// `/parent`/`/teacher` — that's the real security gate, not this sheet.
  void _showSwitchAccountSheet(BuildContext context, WidgetRef ref) {
    final session = ref.read(sessionProvider);
    final hasParent = session.activeParentId != null;
    final hasTeacher = session.activeTeacherId != null;

    if (!hasParent && !hasTeacher) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No parent or teacher account exists on this device yet.',
          ),
        ),
      );
      return;
    }

    void goTo(UserRole role, String path) {
      ref.read(sessionProvider.notifier).selectRole(role);
      Navigator.of(context).pop();
      context.go(path);
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Switch account',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "You'll still need that account's PIN.",
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            if (hasParent)
              _SwitchAccountSheetRow(
                icon: Icons.family_restroom_outlined,
                label: 'Parent / Guardian',
                onTap: () => goTo(UserRole.parent, '/parent'),
              ),
            if (hasParent && hasTeacher) const SizedBox(height: 10),
            if (hasTeacher)
              _SwitchAccountSheetRow(
                icon: Icons.school_outlined,
                label: 'Asatidz (Teacher)',
                onTap: () => goTo(UserRole.asatidz, '/teacher'),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SettingsRow(
      icon: Icons.switch_account_outlined,
      title: 'Switch account',
      subtitle: 'Jump to another parent or teacher profile',
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textMuted,
      ),
      onTap: () => _showSwitchAccountSheet(context, ref),
    );
  }
}

class _SwitchAccountSheetRow extends StatelessWidget {
  const _SwitchAccountSheetRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.creamBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.mint,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 16, color: AppColors.teal),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Visually distinct from the rest of the settings list on purpose — a
/// dashed coral border + eyebrow label so an irreversible action doesn't
/// carry the same visual weight as "Sync now".
class _DangerZone extends ConsumerWidget {
  const _DangerZone();

  void _confirmErase(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: AppColors.coral,
          size: 40,
        ),
        title: const Text('Erase everything?'),
        content: const Text(
          'This removes the learner profile, consent record, PIN, and all '
          'progress from this device. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.coral),
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              if (!context.mounted) return;
              // Navigate off this admin-gated route BEFORE eraseAll() clears
              // the account — see auth_loading_overlay.dart's doc on
              // `showAuthLoadingOverlay` for why the ordering matters.
              context.go('/');
              await runWithAuthLoadingOverlay(
                AuthLoadingAction.erase,
                () => ref.read(sessionProvider.notifier).eraseAll(),
              );
            },
            child: const Text('Erase'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.coralTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.coral, width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.coral),
              const SizedBox(width: 6),
              const Text(
                'DANGER ZONE',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: AppColors.coral,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Erase local data',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Deletes this learner, PIN, and all progress from this device. Cannot be undone.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.coral.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.coral,
                  side: const BorderSide(color: AppColors.coral),
                ),
                onPressed: () => _confirmErase(context, ref),
                child: const Text('Erase'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
