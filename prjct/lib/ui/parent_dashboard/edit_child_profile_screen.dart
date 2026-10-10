import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/learner_profile.dart';
import '../../logic/auth/session.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_loading_overlay.dart';
import '../widgets/child_profile_form.dart';

/// Dedicated "Edit Child Profile" screen — split out of the Manage Profile
/// tab's inline card into its own route so editing a child isn't competing
/// for space with the child switcher, class-join section, and everything
/// else on that tab. Reached from the Manage Profile tab's compact entry
/// card; edits whichever learner is currently active (same as the card it
/// replaced), so switch children first via the tab's switcher if editing
/// a different one.
///
/// Built from the shared child-form kit (same look as Create Child
/// Profile). One column on phones; details beside companion + danger zone
/// from tablet-landscape widths up.
class EditChildProfileScreen extends ConsumerStatefulWidget {
  const EditChildProfileScreen({super.key});

  @override
  ConsumerState<EditChildProfileScreen> createState() =>
      _EditChildProfileScreenState();
}

class _EditChildProfileScreenState
    extends ConsumerState<EditChildProfileScreen> {
  final _nameC = TextEditingController();
  final _usernameC = TextEditingController();
  late int _age;
  late String _avatar;
  String? _grade;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _syncFrom(ref.read(sessionProvider).learner);
  }

  /// Repopulates the form from whichever learner is active at mount —
  /// this screen is only ever reached for one specific child at a time
  /// (unlike the old inline card, which had to resync on every switch
  /// since it stayed mounted underneath the switcher).
  void _syncFrom(LearnerProfile? p) {
    _nameC.text = p?.name ?? '';
    _age = p?.age ?? 7;
    _avatar = p?.avatar ?? 'boy_mascot';
    _grade = p?.gradeLevel ?? 'Grade 1';
    _usernameC.text = p?.username ?? '';
  }

  @override
  void dispose() {
    _nameC.dispose();
    _usernameC.dispose();
    super.dispose();
  }

  void _goBack() => context.go('/parent');

  Future<void> _save(LearnerProfile learner) async {
    final name = _nameC.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a name')));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(sessionProvider.notifier)
          .updateLearnerProfile(
            name: name,
            age: _age,
            avatar: _avatar,
            gradeLevel: (_grade ?? '').trim(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _confirmDelete(LearnerProfile learner) {
    final learnerId = learner.id;
    if (learnerId == null) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: AppColors.coral,
          size: 40,
        ),
        title: Text('Delete ${learner.name}\'s profile?'),
        content: const Text(
          'This permanently removes this child\'s profile and all their '
          'progress. This cannot be undone.',
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
              // Full-screen "Deleting profile…" while it's removed (held for
              // at least a beat so it never just flickers), then land on
              // the Parent Dashboard's Profile tab.
              final messenger = ScaffoldMessenger.of(context);
              final router = GoRouter.of(context);
              await runWithAuthLoadingOverlay(
                AuthLoadingAction.deleteChild,
                () =>
                    ref.read(sessionProvider.notifier).deleteLearner(learnerId),
              );
              router.go('/parent?tab=1');
              messenger.showSnackBar(
                SnackBar(
                  content: Text('${learner.name}\'s profile was deleted'),
                ),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _detailsSection() {
    return ChildFormSection(
      title: 'Details',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ChildFieldLabel('Full name'),
          ChildTextField(
            controller: _nameC,
            hint: 'e.g. Nurhana Ali',
            textCapitalization: TextCapitalization.words,
            wrap: true,
          ),
          const SizedBox(height: 16),
          const ChildFieldLabel('Grade level'),
          GradePicker(
            value: _grade,
            onChanged: (v) => setState(() => _grade = v),
          ),
          const SizedBox(height: 18),
          ChildFieldLabel(
            'Age',
            trailing: Text(
              '$_age years old',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.teal,
              ),
            ),
          ),
          AgePicker(age: _age, onChanged: (a) => setState(() => _age = a)),
          const SizedBox(height: 18),
          // Read-only: saving never stored a changed username (the profile
          // update takes name, age, avatar and grade only), so an editable
          // box here would silently discard edits.
          const ChildFieldLabel(
            'Username',
            helper: "Set when the profile was created — it can't be changed.",
          ),
          ChildTextField(controller: _usernameC, readOnly: true),
        ],
      ),
    );
  }

  Widget _companionSection() {
    return ChildFormSection(
      title: 'Learning companion',
      child: CompanionPicker(
        avatar: _avatar,
        compact: true,
        onChanged: (a) => setState(() => _avatar = a),
      ),
    );
  }

  Widget _dangerSection(LearnerProfile learner) {
    return ChildFormSection(
      title: 'Danger zone',
      titleColor: AppColors.coral,
      color: AppColors.coralTint,
      borderColor: AppColors.coral.withValues(alpha: 0.3),
      subtitle:
          'Permanently delete ${learner.name}\'s profile and progress. '
          'This cannot be undone.',
      child: Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.coral,
            backgroundColor: AppColors.surface,
            minimumSize: const Size(64, 48),
            side: const BorderSide(color: AppColors.coral, width: 1.4),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          icon: const Icon(Icons.delete_outline_rounded, size: 18),
          label: const Text('Delete Child Profile'),
          onPressed: () => _confirmDelete(learner),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final learner = ref.watch(sessionProvider.select((s) => s.learner));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _goBack();
      },
      child: ChildFormScaffold(
        header: ChildFormHeader(
          title: 'Edit child profile',
          subtitle: learner == null
              ? 'No child profile selected.'
              : 'Update ${learner.name}\'s details and companion.',
          avatar: learner == null ? null : _avatar,
          onBack: _goBack,
        ),
        body: learner == null
            ? const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    'No child profile selected.',
                    style: TextStyle(color: AppColors.inkSoft, fontSize: 15),
                  ),
                ),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 840;
                  final side = wide
                      ? ((constraints.maxWidth - 1120) / 2).clamp(24.0, 9999.0)
                      : ((constraints.maxWidth - 600) / 2).clamp(16.0, 9999.0);
                  final padding = EdgeInsets.fromLTRB(side, 20, side, 24);
                  if (!wide) {
                    return Padding(
                      padding: padding,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _detailsSection(),
                          const SizedBox(height: 16),
                          _companionSection(),
                          const SizedBox(height: 16),
                          _dangerSection(learner),
                        ],
                      ),
                    );
                  }
                  return Padding(
                    padding: padding,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _detailsSection()),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _companionSection(),
                              const SizedBox(height: 16),
                              _dangerSection(learner),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
        bottomBar: learner == null
            ? null
            : ChildFormBottomBar(
                children: [
                  ChildFormButton(
                    label: 'Cancel',
                    primary: false,
                    onPressed: _goBack,
                  ),
                  ChildFormButton(
                    label: 'Save Changes',
                    busy: _saving,
                    onPressed: () => _save(learner),
                  ),
                ],
              ),
      ),
    );
  }
}
