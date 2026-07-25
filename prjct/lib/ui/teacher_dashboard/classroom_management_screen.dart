import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/class_section.dart';
import '../../logic/teacher/teacher_providers.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_loading_overlay.dart';
import '../widgets/soft_card.dart';

/// Classroom Management hub (FR-6.1) — every class the teacher owns, one
/// row each. Tapping a class *selects* it (makes it the active class,
/// under [AuthLoadingAction.switchClass]'s loading overlay) and hands off
/// to its own dedicated screen (`/teacher/classes/:classId`,
/// `ClassDetailScreen`) for actually managing its students.
///
/// Long-pressing a row enters multi-select mode (checkboxes replace the
/// chevrons, the appbar swaps to a selection toolbar with Archive/Delete
/// batch actions) — the same underlying [ClassRepository.archiveClass]/
/// [ClassRepository.deleteClass] the single-class actions on
/// `ClassDetailScreen` already use, just looped over the selection.
///
/// Flat appbar + chip row + card list, matching the approved top-tab
/// dashboard mock (dumps/classes_redesign_mock.html) rather than the old
/// teal-gradient hero.
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
        title: Text('Archive ${ids.length} class${ids.length == 1 ? '' : 'es'}?'),
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
      SnackBar(content: Text('${ids.length} class${ids.length == 1 ? '' : 'es'} archived')),
    );
  }

  Future<void> _deleteSelected() async {
    final ids = _selectedIds.toList();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete ${ids.length} class${ids.length == 1 ? '' : 'es'}?'),
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
      SnackBar(content: Text('${ids.length} class${ids.length == 1 ? '' : 'es'} deleted')),
    );
  }

  @override
  Widget build(BuildContext context) {
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
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: Column(
            children: [
              _selecting
                  ? _SelectionAppBar(
                      count: _selectedIds.length,
                      onCancel: _exitSelection,
                      onArchive: _archiveSelected,
                      onDelete: _deleteSelected,
                    )
                  : _ManagementAppBar(onBack: () => _goBack(context)),
              if (!_selecting) const _ManagementChips(),
              const Divider(height: 1, color: AppColors.creamBorder),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                  children: [
                    if (!_selecting) const _ListLabel(),
                    if (!_selecting) const SizedBox(height: 4),
                    _ClassList(
                      selecting: _selecting,
                      selectedIds: _selectedIds,
                      onLongPress: _startSelection,
                      onToggle: _toggleSelection,
                    ),
                    if (!_selecting) ...[
                      const SizedBox(height: 14),
                      const _ArchivedClassesLink(),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManagementAppBar extends StatelessWidget {
  const _ManagementAppBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 18, 4),
      child: Row(
        children: [
          Material(
            color: AppColors.neutralTint,
            borderRadius: BorderRadius.circular(11),
            child: InkWell(
              borderRadius: BorderRadius.circular(11),
              onTap: onBack,
              child: const SizedBox(
                width: 34,
                height: 34,
                child: Icon(
                  Icons.arrow_back_rounded,
                  size: 18,
                  color: AppColors.ink,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'CLASSROOM MANAGEMENT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: AppColors.textMuted,
                  ),
                ),
                Text(
                  'My Classes',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Replaces [_ManagementAppBar] while one or more classes are selected —
/// a close button to cancel the selection, a live count, and the two
/// batch actions (Archive/Delete) this feature exists for.
class _SelectionAppBar extends StatelessWidget {
  const _SelectionAppBar({
    required this.count,
    required this.onCancel,
    required this.onArchive,
    required this.onDelete,
  });

  final int count;
  final VoidCallback onCancel;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.mint,
      padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
      child: Row(
        children: [
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(11),
            child: InkWell(
              borderRadius: BorderRadius.circular(11),
              onTap: onCancel,
              child: const SizedBox(
                width: 34,
                height: 34,
                child: Icon(Icons.close_rounded, size: 18, color: AppColors.ink),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$count selected',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.tealDark,
              ),
            ),
          ),
          _SelectionActionButton(
            icon: Icons.archive_outlined,
            tooltip: 'Archive',
            onTap: onArchive,
          ),
          const SizedBox(width: 6),
          _SelectionActionButton(
            icon: Icons.delete_outline,
            tooltip: 'Delete',
            color: AppColors.danger,
            onTap: onDelete,
          ),
        ],
      ),
    );
  }
}

class _SelectionActionButton extends StatelessWidget {
  const _SelectionActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color = AppColors.tealDark,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 34,
            height: 34,
            child: Icon(icon, size: 18, color: color),
          ),
        ),
      ),
    );
  }
}

class _ManagementChips extends ConsumerWidget {
  const _ManagementChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classCount = ref.watch(teacherClassesProvider).length;
    final studentCount = ref.watch(teacherTotalStudentsProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          _HeroChip(
            icon: Icons.class_outlined,
            value: '$classCount class${classCount == 1 ? '' : 'es'}',
          ),
          _HeroChip(
            icon: Icons.groups_outlined,
            value: '$studentCount student${studentCount == 1 ? '' : 's'}',
          ),
        ],
      ),
    );
  }
}

class _ListLabel extends StatelessWidget {
  const _ListLabel();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 2, bottom: 4),
      child: Text(
        'TAP A CLASS TO MANAGE ITS STUDENTS · LONG-PRESS TO SELECT',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

/// Flat mint-tinted pill matching the approved mock's `.hero-chip` — shared
/// by [ClassroomManagementScreen] and [ClassDetailScreen] would be nicer as
/// one widget, but each dashboard file keeps its own small copy already
/// (see `_StaggerFadeIn`), so this follows the existing convention.
class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.mintBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.tealDark),
          const SizedBox(width: 5),
          Text(
            value,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppColors.tealDark,
            ),
          ),
        ],
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
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.class_outlined, size: 40, color: AppColors.textMuted),
            SizedBox(height: 12),
            Text(
              'No classes yet',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: AppColors.ink,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Create one from the Classroom tab first.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < classes.length; i++) ...[
          _StaggerFadeIn(
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
          if (i != classes.length - 1) const SizedBox(height: 10),
        ],
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
    final borderColor = selected
        ? AppColors.teal
        : (active ? AppColors.teal : AppColors.creamBorder);

    return SoftCard(
      onTap: selecting ? onToggle : () => _open(context, ref),
      onLongPress: selecting ? null : onLongPress,
      color: selected ? AppColors.mint : AppColors.surface,
      borderColor: borderColor,
      padding: const EdgeInsets.all(14),
      radius: 16,
      child: Row(
        children: [
          if (selecting) ...[
            AnimatedScale(
              scale: 1,
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutBack,
              child: Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked,
                size: 24,
                color: selected ? AppColors.teal : AppColors.textMuted,
              ),
            ),
            const SizedBox(width: 13),
          ],
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: active ? AppColors.teal : AppColors.mint,
              borderRadius: BorderRadius.circular(13),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.groups_outlined,
              size: 22,
              color: active ? Colors.white : AppColors.teal,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${roster.length} student${roster.length == 1 ? '' : 's'}'
                  '${active ? ' · Active class' : ''}'
                  '${section.schedule != null && section.schedule!.isNotEmpty ? ' · ${section.schedule}' : ''}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (!selecting)
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textMuted,
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/teacher/classes/archived'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: AppColors.neutralTint,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.creamBorder),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.archive_outlined,
                size: 18,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Archived Classes ($archivedCount)',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Self-contained staggered entrance (fade + slide-up) — matches the
/// Classroom tab's own `_StaggerFadeIn` in `teacher_dashboard_screen.dart`
/// (each file keeps its own copy, same convention as `_FadeUp` already
/// being duplicated per-dashboard-file).
class _StaggerFadeIn extends StatefulWidget {
  const _StaggerFadeIn({required this.delay, required this.child});

  final Duration delay;
  final Widget child;

  @override
  State<_StaggerFadeIn> createState() => _StaggerFadeInState();
}

class _StaggerFadeInState extends State<_StaggerFadeIn>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );
  late final _fade = CurvedAnimation(
    parent: _c,
    curve: const Cubic(0.2, 0.7, 0.3, 1.0),
  );
  late final _slide = Tween<Offset>(
    begin: const Offset(0, 0.04),
    end: Offset.zero,
  ).animate(_fade);

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}
