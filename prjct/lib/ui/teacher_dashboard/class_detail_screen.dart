import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/class_section.dart';
import '../../data/remote/firestore_mirror.dart';
import '../../data/repositories/class_repository.dart';
import '../../data/repositories/learner_repository.dart';
import '../../logic/teacher/teacher_providers.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_loading_overlay.dart';
import '../widgets/soft_card.dart';
import 'teacher_dashboard_screen.dart'
    show MasteryPill, avatarColor, showStudentDetails;

/// Dedicated screen for managing one class's students (FR-6.1, FR-6.2) —
/// invitation code, enroll-by-name form, and full roster, all scoped to
/// this class specifically regardless of which class is currently
/// "active" on the dashboard. Reached either by tapping a class in
/// [ClassroomManagementScreen] or via the Home tab's "See all" students
/// link — `?from=home` on the route tracks the latter so the back button
/// returns to wherever the teacher actually came from instead of always
/// landing on the classroom picker.
///
/// Flat appbar + chip row + card list, matching the approved top-tab
/// dashboard mock (dumps/classes_redesign_mock.html) rather than the old
/// teal-gradient hero and "Class Pass" ticket.
class ClassDetailScreen extends ConsumerStatefulWidget {
  const ClassDetailScreen({super.key, required this.classId});

  final String classId;

  @override
  ConsumerState<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends ConsumerState<ClassDetailScreen> {
  final _firstNameC = TextEditingController();
  final _middleNameC = TextEditingController();
  final _lastNameC = TextEditingController();

  @override
  void dispose() {
    _firstNameC.dispose();
    _middleNameC.dispose();
    _lastNameC.dispose();
    super.dispose();
  }

  void _goBack() {
    final fromHome =
        GoRouterState.of(context).uri.queryParameters['from'] == 'home';
    context.go(fromHome ? '/teacher' : '/teacher/classes');
  }

  void _refresh() {
    ref.invalidate(classRosterProvider(widget.classId));
    ref.invalidate(teacherClassesProvider);
    ref.invalidate(archivedTeacherClassesProvider);
    ref.invalidate(teacherRosterProvider);
  }

  Future<void> _archive(ClassSection section) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Archive this class?'),
        content: Text(
          '"${section.name}" will move to Archived Classes. Its roster, '
          'progress, and lesson folders stay intact and read-only — no new '
          'enrollments, casting, or homework until you unarchive it.',
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
    await ref.read(teacherClassControllerProvider.notifier).archiveClass(section.id);
    _refresh();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${section.name}" archived')),
      );
    }
  }

  Future<void> _unarchive(ClassSection section) async {
    await ref
        .read(teacherClassControllerProvider.notifier)
        .unarchiveClass(section.id);
    _refresh();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${section.name}" unarchived')),
      );
    }
  }

  Future<void> _deleteClass(ClassSection section) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this class?'),
        content: Text(
          '"${section.name}" and its entire roster, progress history, '
          'assignments, and lesson folders will be permanently deleted. '
          'This can\'t be undone — archive it instead if you want to keep '
          'the record.',
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
    await ref.read(teacherClassControllerProvider.notifier).deleteClass(section.id);
    _refresh();
    if (mounted) {
      _goBack();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${section.name}" deleted')),
      );
    }
  }

  Future<void> _enrollStudent() async {
    final first = _firstNameC.text.trim();
    final middle = _middleNameC.text.trim();
    final last = _lastNameC.text.trim();
    if (first.isEmpty || last.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the learner\'s first and last name'),
        ),
      );
      return;
    }
    // Learner profiles only ever store one plain `name` field (set by the
    // parent at `learner-setup`) — there's no first/middle/last split in
    // the data model to match against, so this just joins the three fields
    // back into the same "First Middle Last" shape and matches that,
    // exactly as if the teacher had typed one combined name field.
    final name = [first, middle, last].where((s) => s.isNotEmpty).join(' ');
    var matches = LearnerRepository().findAllByName(name);
    if (matches.isEmpty) {
      // Not on this device yet — the learner may have been created
      // straight in Firestore (e.g. by the admin website) and never
      // synced down here. Fall back to a remote lookup and cache any hit
      // locally so future enrolls for the same learner stay on-device.
      try {
        final remoteMatches = await FirestoreMirror().findLearnersByName(name);
        for (final remote in remoteMatches) {
          await LearnerRepository().saveFromRemote(
            id: remote.id,
            parentId: remote.parentId ?? '',
            name: remote.name,
            age: remote.age,
            avatar: remote.avatar,
            gradeLevel: remote.gradeLevel,
            username: remote.username,
            createdAt: remote.createdAt,
          );
        }
      } catch (_) {
        // Best-effort — offline devices just keep the "no learner found" path.
      }
      matches = LearnerRepository().findAllByName(name);
    }
    if (matches.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No learner found named "$name"')));
      }
      return;
    }
    if (matches.length > 1) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Multiple learners named "$name" found — ask the parent to confirm.',
            ),
          ),
        );
      }
      return;
    }
    final learner = matches.first;
    if (learner.id == null) return;
    ClassRepository()
        .enroll(classId: widget.classId, learnerId: learner.id!)
        .then((_) {
          _refresh();
          _firstNameC.clear();
          _middleNameC.clear();
          _lastNameC.clear();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Enrolled "${learner.name}" successfully!'),
              ),
            );
          }
        });
  }

  Future<void> _onStudentTap(bool active, Map<String, dynamic> student) async {
    if (!active) {
      await ref
          .read(teacherClassControllerProvider.notifier)
          .switchClass(widget.classId);
    }
    if (mounted) showStudentDetails(context, ref, student);
  }

  Future<void> _makeActive() async {
    await runWithAuthLoadingOverlay(
      AuthLoadingAction.switchClass,
      () => ref
          .read(teacherClassControllerProvider.notifier)
          .switchClass(widget.classId),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watches both lists (not just [teacherClassesProvider], which excludes
    // archived classes) so this screen keeps working after the class it's
    // showing gets archived instead of reporting "no longer exists".
    final classes = [
      ...ref.watch(teacherClassesProvider),
      ...ref.watch(archivedTeacherClassesProvider),
    ];
    final section = classes.where((c) => c.id == widget.classId).firstOrNull;
    final activeId = ref.watch(teacherClassControllerProvider)?.id;
    final active = widget.classId == activeId;
    final roster = ref.watch(classRosterProvider(widget.classId));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: section == null
              ? Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: _goBack,
                      ),
                    ),
                    const Expanded(
                      child: Center(
                        child: Text(
                          'This class no longer exists.',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    _DetailAppBar(section: section, onBack: _goBack),
                    _DetailChips(
                      section: section,
                      active: active,
                      studentCount: roster.length,
                      onMakeActive: _makeActive,
                    ),
                    const Divider(height: 1, color: AppColors.creamBorder),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                        children: [
                          _StaggerFadeIn(
                            delay: const Duration(milliseconds: 40),
                            child: _InviteCodeCard(section: section),
                          ),
                          const SizedBox(height: 14),
                          if (!section.isArchived) ...[
                            _StaggerFadeIn(
                              delay: const Duration(milliseconds: 100),
                              child: _EnrollCard(
                                firstNameController: _firstNameC,
                                middleNameController: _middleNameC,
                                lastNameController: _lastNameC,
                                onEnroll: _enrollStudent,
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],
                          _StaggerFadeIn(
                            delay: const Duration(milliseconds: 160),
                            child: _RosterCard(
                              roster: roster,
                              onStudentTap: (s) => _onStudentTap(active, s),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _StaggerFadeIn(
                            delay: const Duration(milliseconds: 220),
                            child: _ArchiveCard(
                              section: section,
                              onArchive: () => _archive(section),
                              onUnarchive: () => _unarchive(section),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _StaggerFadeIn(
                            delay: const Duration(milliseconds: 280),
                            child: _DeleteClassCard(
                              onDelete: () => _deleteClass(section),
                            ),
                          ),
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

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class _DetailAppBar extends StatelessWidget {
  const _DetailAppBar({required this.section, required this.onBack});

  final ClassSection section;
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'CLASS DETAIL',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: AppColors.textMuted,
                  ),
                ),
                Text(
                  section.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
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

class _DetailChips extends StatelessWidget {
  const _DetailChips({
    required this.section,
    required this.active,
    required this.studentCount,
    required this.onMakeActive,
  });

  final ClassSection section;
  final bool active;
  final int studentCount;
  final VoidCallback onMakeActive;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          if (section.isArchived)
            const _HeroChip(
              icon: Icons.archive_outlined,
              value: 'Archived',
              tint: AppColors.neutralTint,
              fg: AppColors.textMuted,
              border: AppColors.creamBorder,
            )
          else if (active)
            const _HeroChip(
              icon: Icons.check_circle_rounded,
              value: 'Active class',
              tint: AppColors.goldTint,
              fg: Color(0xFF8A5A12),
              border: AppColors.gold,
            )
          else
            _MakeActiveChip(onTap: onMakeActive),
          _HeroChip(
            icon: Icons.groups_outlined,
            value:
                '$studentCount student${studentCount == 1 ? '' : 's'}',
          ),
          if (section.schedule != null && section.schedule!.isNotEmpty)
            _HeroChip(
              icon: Icons.schedule_outlined,
              value: section.schedule!,
            ),
        ],
      ),
    );
  }
}

class _MakeActiveChip extends StatelessWidget {
  const _MakeActiveChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.neutralTint,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.creamBorder),
          ),
          child: const Text(
            'Make Active',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

/// Flat tinted pill matching the approved mock's `.hero-chip` — shared
/// shape with [ClassroomManagementScreen]'s own copy, each file keeping
/// its own small widget per this codebase's existing convention.
class _HeroChip extends StatelessWidget {
  const _HeroChip({
    required this.icon,
    required this.value,
    this.tint = AppColors.mint,
    this.fg = AppColors.tealDark,
    this.border = AppColors.mintBorder,
  });

  final IconData icon;
  final String value;
  final Color tint;
  final Color fg;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 5),
          Text(
            value,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// Invitation code "Class Pass" ticket — same teal-gradient card with
/// punched notches and a dashed perforation as the Classroom tab's own
/// invitation-code card (`_ClassPassCard` in `teacher_dashboard_screen.dart`),
/// so the two screens show one consistent design for the same concept.
class _InviteCodeCard extends StatefulWidget {
  const _InviteCodeCard({
    required this.section,
    this.notchColor = AppColors.surface,
  });

  final ClassSection section;

  /// Color of the two punched notches — must match whatever surface sits
  /// behind this card or the "cut" illusion breaks.
  final Color notchColor;

  @override
  State<_InviteCodeCard> createState() => _InviteCodeCardState();
}

class _InviteCodeCardState extends State<_InviteCodeCard> {
  bool _copied = false;

  Future<void> _copyCode() async {
    await Clipboard.setData(ClipboardData(text: widget.section.invitationCode));
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.teal, AppColors.tealDark],
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.teal.withValues(alpha: 0.35),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.confirmation_num_outlined,
                        size: 15,
                        color: AppColors.goldSoft,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'INVITATION CODE',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                  Flexible(
                    child: Text(
                      widget.section.name,
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _DashedDivider(color: Colors.white.withValues(alpha: 0.25)),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  widget.section.invitationCode,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 5,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (widget.section.isArchived)
                Row(
                  children: [
                    Icon(
                      Icons.archive_outlined,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Archived — this code no longer works',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Share with parents to enroll',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.65),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedScale(
                      scale: _copied ? 1.06 : 1.0,
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOut,
                      child: OutlinedButton.icon(
                        onPressed: _copied ? null : _copyCode,
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: Icon(
                            _copied ? Icons.check_rounded : Icons.copy_rounded,
                            key: ValueKey(_copied),
                            size: 14,
                          ),
                        ),
                        label: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: Text(
                            _copied ? 'Copied' : 'Copy',
                            key: ValueKey(_copied),
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor:
                              (_copied ? AppColors.gold : Colors.white)
                                  .withValues(alpha: _copied ? 0.9 : 0.1),
                          side: BorderSide(
                            color: Colors.white.withValues(
                              alpha: _copied ? 0.6 : 0.3,
                            ),
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          textStyle: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        // The two punched notches, positioned at the perforation line —
        // small circles matching the surrounding background color so they
        // read as cut-outs rather than decoration sitting on top.
        Positioned(left: -11, top: 39, child: _PassNotch(color: widget.notchColor)),
        Positioned(right: -11, top: 39, child: _PassNotch(color: widget.notchColor)),
      ],
    );
  }
}

class _PassNotch extends StatelessWidget {
  const _PassNotch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// Fake dashed rule (Flutter has no built-in dashed border) — a row of
/// short filled segments sized to fill whatever width it's given. Matches
/// the Classroom tab's own `_DashedDivider`.
class _DashedDivider extends StatelessWidget {
  const _DashedDivider({required this.color});

  final Color color;

  static const _dashWidth = 6.0;
  static const _gap = 5.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = (constraints.maxWidth / (_dashWidth + _gap)).floor();
        return SizedBox(
          height: 1.6,
          child: Row(
            children: [
              for (var i = 0; i < count; i++)
                Padding(
                  padding: EdgeInsets.only(right: i == count - 1 ? 0 : _gap),
                  child: Container(
                    width: _dashWidth,
                    height: 1.6,
                    color: color,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _EnrollCard extends StatelessWidget {
  const _EnrollCard({
    required this.firstNameController,
    required this.middleNameController,
    required this.lastNameController,
    required this.onEnroll,
  });

  final TextEditingController firstNameController;
  final TextEditingController middleNameController;
  final TextEditingController lastNameController;
  final VoidCallback onEnroll;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ENROLL EXISTING LEARNER',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'The learner\'s account must already exist — ask the parent for their child\'s full name.',
            style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: firstNameController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Amir',
                    labelText: 'First Name',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: middleNameController,
                  decoration: const InputDecoration(
                    hintText: 'Optional',
                    labelText: 'Middle Name',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: lastNameController,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Ali',
                    labelText: 'Last Name',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onEnroll,
              icon: const Icon(Icons.person_add_alt_1, size: 16),
              label: const Text('Enroll'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RosterCard extends StatelessWidget {
  const _RosterCard({required this.roster, required this.onStudentTap});

  final List<Map<String, dynamic>> roster;
  final ValueChanged<Map<String, dynamic>> onStudentTap;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'STUDENTS (${roster.length})',
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 10),
          if (roster.isEmpty)
            const Text(
              'No students enrolled yet.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            )
          else
            for (final s in roster) ...[
              _StudentRow(student: s, onTap: () => onStudentTap(s)),
              if (s != roster.last) const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({required this.student, required this.onTap});

  final Map<String, dynamic> student;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = student['name'] as String;
    final mastery = student['mastery'] as String;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.creamBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: avatarColor(mastery),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  name.isEmpty ? '?' : name[0].toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ),
              MasteryPill(mastery: mastery, dotted: true),
            ],
          ),
        ),
      ),
    );
  }
}

/// End-of-school-year retirement action (FR-6.1) — archives an owned class
/// (read-only, roster/progress/lesson-folders preserved, see
/// [ClassSection.isArchived]) or reverses it.
class _ArchiveCard extends StatelessWidget {
  const _ArchiveCard({
    required this.section,
    required this.onArchive,
    required this.onUnarchive,
  });

  final ClassSection section;
  final VoidCallback onArchive;
  final VoidCallback onUnarchive;

  @override
  Widget build(BuildContext context) {
    if (section.isArchived) {
      return SoftCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This class is archived',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Roster and progress stay saved. Unarchive to reopen '
              'enrollment, casting, and homework for this class.',
              style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onUnarchive,
                icon: const Icon(Icons.unarchive_outlined, size: 16),
                label: const Text('Unarchive Class'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.teal,
                  side: const BorderSide(color: AppColors.teal),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SoftCard(
      color: AppColors.coralTint,
      borderColor: const Color(0xFFF0C4B0),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Archive this class',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Save this class for the record when the school year ends. '
            'Its roster and progress stay intact and read-only until you '
            'unarchive it.',
            style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onArchive,
              icon: const Icon(Icons.archive_outlined, size: 16),
              label: const Text('Archive Class'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.coral,
                side: const BorderSide(color: AppColors.coral),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Permanent, irreversible retirement — unlike [_ArchiveCard], deletes the
/// class's roster, progress, assignments, and lesson folders outright
/// (`ClassRepository.deleteClass`). Kept as its own card below Archive so
/// the two "I'm done with this class" options read as distinct severities
/// rather than one action with a checkbox.
class _DeleteClassCard extends StatelessWidget {
  const _DeleteClassCard({required this.onDelete});

  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      color: AppColors.coralTint,
      borderColor: AppColors.danger,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Delete this class',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: AppColors.danger,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Permanently removes the class along with its roster, progress '
            'history, assignments, and lesson folders. This can\'t be '
            'undone — archive instead if you just want to close it out.',
            style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, size: 16),
              label: const Text('Delete Class'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Self-contained staggered entrance (fade + slide-up) — matches the
/// Classroom tab's own `_StaggerFadeIn`.
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
