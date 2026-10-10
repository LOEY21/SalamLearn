import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/class_section.dart';
import '../../logic/teacher/teacher_providers.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_loading_overlay.dart';
import '../widgets/child_profile_form.dart' show displayText;
import '../widgets/hub_kit.dart';
import '../widgets/soft_card.dart';

/// Classroom Management hub (FR-6.1) — every class the teacher owns, one
/// row each. Tapping a class *selects* it (makes it the active class,
/// under [AuthLoadingAction.switchClass]'s loading overlay) and hands off
/// to its own dedicated screen (`/teacher/classes/:classId`,
/// `ClassDetailScreen`) for actually managing its students.
///
/// Long-pressing a row enters multi-select mode (checkboxes replace the
/// chevrons, the header swaps to a selection bar with Archive/Delete
/// batch actions) — the same underlying [ClassRepository.archiveClass]/
/// [ClassRepository.deleteClass] the single-class actions on
/// `ClassDetailScreen` already use, just looped over the selection.
///
/// Built on the hub kit's sub-page frame, matching the Teacher Hub.
class ClassroomManagementScreen extends ConsumerStatefulWidget {
  const ClassroomManagementScreen({super.key});

  @override
  ConsumerState<ClassroomManagementScreen> createState() =>
      _ClassroomManagementScreenState();
}

class _ClassroomManagementScreenState
    extends ConsumerState<ClassroomManagementScreen> {
  final Set<String> _selectedIds = {};

  bool get _selecting => _selectedIds.isNotEmpty;

  void _goBack(BuildContext context) => context.go('/teacher?tab=1');

  void _exitSelection() => setState(_selectedIds.clear);

  void _startSelection(String classId) =>
      setState(() => _selectedIds.add(classId));

  void _toggleSelection(String classId) {
    setState(() {
      if (!_selectedIds.remove(classId)) _selectedIds.add(classId);
    });
  }

  Future<void> _archiveSelected() async {
    final ids = _selectedIds.toList();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Archive ${ids.length} class${ids.length == 1 ? '' : 'es'}?',
        ),
        content: const Text(
          'Their roster, progress, and lesson folders stay intact and '
          'read-only — no new enrollments, casting, or homework until you '
          'unarchive them.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final notifier = ref.read(teacherClassControllerProvider.notifier);
    for (final id in ids) {
      await notifier.archiveClass(id);
    }
    ref.invalidate(teacherClassesProvider);
    ref.invalidate(archivedTeacherClassesProvider);
    if (!mounted) return;
    _exitSelection();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${ids.length} class${ids.length == 1 ? '' : 'es'} archived',
        ),
      ),
    );
  }

  Future<void> _deleteSelected() async {
    final ids = _selectedIds.toList();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          'Delete ${ids.length} class${ids.length == 1 ? '' : 'es'}?',
        ),
        content: Text(
          'Their entire roster, progress history, assignments, and lesson '
          'folders will be permanently deleted. This can\'t be undone — '
          'archive instead if you just want to close ${ids.length == 1 ? 'it' : 'them'} out.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final notifier = ref.read(teacherClassControllerProvider.notifier);
    for (final id in ids) {
      await notifier.deleteClass(id);
    }
    ref.invalidate(teacherClassesProvider);
    ref.invalidate(archivedTeacherClassesProvider);
    if (!mounted) return;
    _exitSelection();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${ids.length} class${ids.length == 1 ? '' : 'es'} deleted',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final classCount = ref.watch(teacherClassesProvider).length;
    final studentCount = ref.watch(teacherTotalStudentsProvider);

    final header = _selecting
        ? HubSubpageHeader(
            title: '${_selectedIds.length} selected',
            subtitle: 'Archive or delete the selected classes.',
            backIcon: Icons.close_rounded,
            backTooltip: 'Cancel selection',
            onBack: _exitSelection,
            actions: [
              HubHeaderAction(
                icon: Icons.archive_outlined,
                tooltip: 'Archive',
                onTap: _archiveSelected,
              ),
              HubHeaderAction(
                icon: Icons.delete_outline,
                tooltip: 'Delete',
                onTap: _deleteSelected,
              ),
            ],
          )
        : HubSubpageHeader(
            title: 'My Classes',
            subtitle:
                'Tap a class to manage its students · long-press to select.',
            onBack: () => _goBack(context),
            bottom: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                HubHeaderChip(
                  icon: Icons.class_outlined,
                  label: '$classCount class${classCount == 1 ? '' : 'es'}',
                ),
                HubHeaderChip(
                  icon: Icons.groups_outlined,
                  label: '$studentCount student${studentCount == 1 ? '' : 's'}',
                ),
              ],
            ),
          );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_selecting) {
          _exitSelection();
        } else {
          _goBack(context);
        }
      },
      child: HubSubpage(
        header: header,
        body: HubListBody(
          children: [
            _ClassList(
              selecting: _selecting,
              selectedIds: _selectedIds,
              onLongPress: _startSelection,
              onToggle: _toggleSelection,
            ),
            if (!_selecting) const _ArchivedClassesLink(),
          ],
        ),
      ),
    );
  }
}

class _ClassList extends ConsumerWidget {
  const _ClassList({
    required this.selecting,
    required this.selectedIds,
    required this.onLongPress,
    required this.onToggle,
  });

  final bool selecting;
  final Set<String> selectedIds;
  final ValueChanged<String> onLongPress;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classes = ref.watch(teacherClassesProvider);
    final activeId = ref.watch(teacherClassControllerProvider)?.id;

    if (classes.isEmpty) {
      return const HubEmptyState(
        icon: Icons.class_outlined,
        title: 'No classes yet',
        message: 'Create one from the Classroom tab first.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < classes.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: HubStaggerFadeIn(
              delay: Duration(milliseconds: 40 + (i * 60).clamp(0, 300)),
              child: _ClassRow(
                section: classes[i],
                active: classes[i].id == activeId,
                selecting: selecting,
                selected: selectedIds.contains(classes[i].id),
                onLongPress: () => onLongPress(classes[i].id),
                onToggle: () => onToggle(classes[i].id),
              ),
            ),
          ),
      ],
    );
  }
}

class _ClassRow extends ConsumerWidget {
  const _ClassRow({
    required this.section,
    required this.active,
    required this.selecting,
    required this.selected,
    required this.onLongPress,
    required this.onToggle,
  });

  final ClassSection section;
  final bool active;
  final bool selecting;
  final bool selected;
  final VoidCallback onLongPress;
  final VoidCallback onToggle;

  /// Selecting a class from the picker both makes it the active class
  /// (so the Roster tab, homework assigner, etc. all scope to it) and
  /// opens its dedicated management screen — with a loading overlay
  /// covering the switch so the hand-off doesn't feel like a stalled tap.
  Future<void> _open(BuildContext context, WidgetRef ref) async {
    if (!active) {
      await runWithAuthLoadingOverlay(
        AuthLoadingAction.switchClass,
        () => ref
            .read(teacherClassControllerProvider.notifier)
            .switchClass(section.id),
      );
    }
    if (context.mounted) context.go('/teacher/classes/${section.id}');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roster = ref.watch(classRosterProvider(section.id));
    final schedule = section.schedule;
    final meta = [
      '${roster.length} student${roster.length == 1 ? '' : 's'}',
      if (schedule != null && schedule.isNotEmpty) schedule,
    ].join(' · ');

    return SoftCard(
      radius: 20,
      onTap: selecting ? onToggle : () => _open(context, ref),
      onLongPress: selecting ? null : onLongPress,
      color: selected ? AppColors.mint : AppColors.surface,
      borderColor: selected || active ? AppColors.teal : AppColors.creamBorder,
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Row(
        children: [
          if (selecting) ...[
            Icon(
              selected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked,
              size: 26,
              color: selected ? AppColors.teal : AppColors.inkSoft,
            ),
            const SizedBox(width: 12),
          ],
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: active ? AppColors.teal : AppColors.mint,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.groups_outlined,
              size: 23,
              color: active ? Colors.white : AppColors.teal,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(
                  builder: (context, box) => Text(
                    section.name,
                    style: fitLongestWord(
                      context,
                      section.name,
                      displayText(18),
                      box.maxWidth,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  meta,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkSoft,
                  ),
                ),
                if (active) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.mint,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'Active class',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: AppColors.tealDark,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!selecting)
            const Icon(
              Icons.chevron_right_rounded,
              size: 24,
              color: AppColors.inkSoft,
            ),
        ],
      ),
    );
  }
}

/// Link to [ArchivedClassesScreen] — only shown once the teacher has at
/// least one archived class, so a teacher who's never archived anything
/// never sees an empty-state link cluttering the bottom of their list.
class _ArchivedClassesLink extends ConsumerWidget {
  const _ArchivedClassesLink();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archivedCount = ref.watch(archivedTeacherClassesProvider).length;
    if (archivedCount == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: HubRowSheet(
        children: [
          HubNavRow(
            icon: Icons.archive_outlined,
            iconColor: AppColors.inkSoft,
            title: 'Archived Classes ($archivedCount)',
            subtitle: 'Read-only — unarchive to use again',
            onTap: () => context.push('/teacher/classes/archived'),
          ),
        ],
      ),
    );
  }
}
