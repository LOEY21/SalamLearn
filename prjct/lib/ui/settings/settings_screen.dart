import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../logic/auth/session.dart';
import '../../logic/settings/settings_providers.dart';
import '../../logic/sync/sync_manager.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_loading_overlay.dart';
import '../widgets/email_verification_card.dart';
import '../widgets/soft_card.dart';

/// Settings & data lifecycle screen. Redesigned to feel premium and visually identical to the Parent settings tab.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volumes = ref.watch(volumeProvider);
    final volumeNotifier = ref.read(volumeProvider.notifier);
    final activeRole = ref.watch(sessionProvider).activeRole;

    final fromHub =
        GoRouterState.of(context).uri.queryParameters['from'] == 'hub';
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.teal, AppColors.tealDark],
                    ),
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: const BoxDecoration(
                          color: Colors.white24,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.tune_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'App Settings',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Configure sound volumes and local data',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SoftCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: AppColors.mint,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.volume_up_rounded,
                              size: 17,
                              color: AppColors.teal,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Sound & Voice',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _VolumeSlider(
                        icon: Icons.music_note_outlined,
                        label: 'Background Music',
                        value: volumes.background,
                        onChanged: volumeNotifier.setBackground,
                      ),
                      const SizedBox(height: 14),
                      _VolumeSlider(
                        icon: Icons.notifications_none,
                        label: 'UI Sound Effects',
                        value: volumes.effects,
                        onChanged: volumeNotifier.setEffects,
                      ),
                      const SizedBox(height: 14),
                      _VolumeSlider(
                        icon: Icons.mic_none,
                        label: 'Pronunciation Voice',
                        value: volumes.voice,
                        onChanged: volumeNotifier.setVoice,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const EmailVerificationCard(),
                const SizedBox(height: 14),
                const _SyncCard(),
                const SizedBox(height: 14),
                const _SwitchAccountCard(),
                const SizedBox(height: 14),
                const _EraseCard(),
              ],
            ),
          ),
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
    return Column(
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
        const SizedBox(height: 4),
        Slider(
          value: value,
          min: 0.0,
          max: 1.0,
          activeColor: AppColors.teal,
          inactiveColor: AppColors.creamBorder,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _SyncCard extends ConsumerStatefulWidget {
  const _SyncCard();

  @override
  ConsumerState<_SyncCard> createState() => _SyncCardState();
}

class _SyncCardState extends ConsumerState<_SyncCard> {
  bool _syncing = false;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      color: AppColors.mint,
      borderColor: AppColors.mintBorder,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sync Now', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                const Text(
                  'Sync local device progress with cloud servers.',
                  style: TextStyle(fontSize: 12, color: AppColors.tealDark),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.teal,
              side: const BorderSide(color: AppColors.teal),
            ),
            icon: _syncing
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      color: AppColors.teal,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.sync, size: 16),
            label: Text(_syncing ? 'Syncing...' : 'Sync'),
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Sync failed: $error')),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _syncing = false);
                    }
                  },
          ),
        ],
      ),
    );
  }
}

class _SwitchAccountCard extends ConsumerWidget {
  const _SwitchAccountCard();

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
              _SwitchAccountRow(
                icon: Icons.family_restroom_outlined,
                label: 'Parent / Guardian',
                onTap: () => goTo(UserRole.parent, '/parent'),
              ),
            if (hasParent && hasTeacher) const SizedBox(height: 10),
            if (hasTeacher)
              _SwitchAccountRow(
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
    return SoftCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Switch Account',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Jump to another parent or teacher account on this device.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.teal,
              side: const BorderSide(color: AppColors.teal),
            ),
            onPressed: () => _showSwitchAccountSheet(context, ref),
            icon: const Icon(Icons.switch_account_outlined, size: 16),
            label: const Text('Switch'),
          ),
        ],
      ),
    );
  }
}

class _SwitchAccountRow extends StatelessWidget {
  const _SwitchAccountRow({
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

class _EraseCard extends ConsumerWidget {
  const _EraseCard();

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
    return SoftCard(
      color: AppColors.coralTint,
      borderColor: AppColors.coral,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Erase Local Data',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Permanently delete all stored profiles and progress data.',
                  style: TextStyle(fontSize: 12, color: AppColors.ink),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.coral,
              side: const BorderSide(color: AppColors.coral),
            ),
            onPressed: () => _confirmErase(context, ref),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
