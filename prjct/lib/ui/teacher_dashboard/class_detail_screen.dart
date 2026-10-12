import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/class_section.dart';
import '../../data/models/learner_profile.dart';
import '../../data/remote/firestore_mirror.dart';
import '../../data/repositories/class_repository.dart';
import '../../data/repositories/learner_repository.dart';
import '../../logic/teacher/teacher_providers.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_loading_overlay.dart';
import '../widgets/child_profile_form.dart'
    show ChildFieldLabel, ChildTextField, displayText, scaledExtent;
import '../widgets/hub_kit.dart';
import '../widgets/soft_card.dart';
import 'teacher_dashboard_screen.dart'
    show ClassPassCard, MasteryPill, avatarColor, showStudentDetails;

/// Dedicated screen for managing one class's students (FR-6.1, FR-6.2) —
/// invitation code, enroll-by-Student-ID form, and full roster, all scoped to
/// this class specifically regardless of which class is currently
/// "active" on the dashboard. Reached either by tapping a class in
/// [ClassroomManagementScreen] or via the Home tab's "See all" students
/// link — `?from=home` on the route tracks the latter so the back button
/// returns to wherever the teacher actually came from instead of always
/// landing on the classroom picker.
///
/// Built on the hub kit's sub-page frame, matching the Teacher Hub; the
/// pass and enroll form sit beside the roster from tablet-landscape widths.
class ClassDetailScreen extends ConsumerStatefulWidget {
  const ClassDetailScreen({super.key, required this.classId});

  final String classId;

  @override
  ConsumerState<ClassDetailScreen> createState() => _ClassDetailScreenState();
}

class _ClassDetailScreenState extends ConsumerState<ClassDetailScreen> {
  final _studentIdC = TextEditingController();

  @override
  void dispose() {
    _studentIdC.dispose();
    super.dispose();
  }

  void _goBack() {
    // Opened on top of the class list (or the hub's "See all"): pop so it
    // slides back out the way it came in.
    if (context.canPop()) {
      context.pop();
      return;
    }
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
    await ref
        .read(teacherClassControllerProvider.notifier)
        .archiveClass(section.id);
    _refresh();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('"${section.name}" archived')));
    }
  }

  Future<void> _unarchive(ClassSection section) async {
    await ref
        .read(teacherClassControllerProvider.notifier)
        .unarchiveClass(section.id);
    _refresh();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('"${section.name}" unarchived')));
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
    await ref
        .read(teacherClassControllerProvider.notifier)
        .deleteClass(section.id);
    _refresh();
    if (mounted) {
      _goBack();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('"${section.name}" deleted')));
    }
  }

  Future<void> _enrollStudent() async {
    final studentId = _studentIdC.text.trim();
    if (normalizeStudentId(studentId).length != 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the learner\'s 8-digit Student ID'),
        ),
      );
      return;
    }
    var matches = LearnerRepository().findAllByStudentId(studentId);
    if (matches.isEmpty) {
      // Not on this device yet — the learner may have been created
      // straight in Firestore (e.g. by the admin website) and never
      // synced down here. Fall back to a remote lookup and cache any hit
      // locally so future enrolls for the same learner stay on-device.
      try {
        final remoteMatches = await FirestoreMirror().findLearnersByStudentId(
          studentId,
        );
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
      matches = LearnerRepository().findAllByStudentId(studentId);
    }
    if (matches.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No learner found with Student ID "$studentId"'),
          ),
        );
      }
      return;
    }
    if (matches.length > 1) {
      if (mounted) {
        final details = matches
            .map((m) => '${m.name} (Age ${m.age}, ${m.gradeLevel})')
            .join('; ');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Multiple learners share Student ID "$studentId": $details. Please ask the parent to confirm.',
            ),
          ),
        );
      }
      return;
    }
    final learner = matches.first;
    if (learner.id == null) return;
    if (ClassRepository().isEnrolled(
      classId: widget.classId,
      learnerId: learner.id!,
    )) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '"${learner.name}" is already enrolled in this class.',
            ),
          ),
        );
      }
      return;
    }
    try {
      await ClassRepository().enrollAndPush(
        classId: widget.classId,
        learnerId: learner.id!,
      );
    } catch (e) {
      _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$e'.contains('permission-denied')
                  ? 'Couldn\'t enroll "${learner.name}" — this phone is signed in online as a different account. Sign out, then sign back in to this teacher account with your email and password.'
                  : 'Couldn\'t enroll "${learner.name}" — check your internet connection and try again. ($e)',
            ),
          ),
        );
      }
      return;
    }
    _refresh();
    _studentIdC.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Enrolled "${learner.name}" successfully!')),
      );
    }
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
      child: section == null
          ? HubSubpage(
              header: HubSubpageHeader(title: 'Class', onBack: _goBack),
              body: const HubListBody(
                children: [
                  HubEmptyState(
                    icon: Icons.class_outlined,
                    title: 'Class not found',
                    message: 'This class no longer exists.',
                  ),
                ],
              ),
            )
          : HubSubpage(
              header: HubSubpageHeader(
                title: section.name,
                subtitle:
                    'Invitation code, enrollment and roster for this '
                    'class.',
                onBack: _goBack,
                bottom: _DetailChips(
                  section: section,
                  active: active,
                  studentCount: roster.length,
                  onMakeActive: _makeActive,
                ),
              ),
              body: HubTabBody(
                left: [
                  const HubSectionLabel('Class pass'),
                  HubStaggerFadeIn(
                    delay: const Duration(milliseconds: 40),
                    child: ClassPassCard(
                      code: section.invitationCode,
                      className: section.name,
                      archived: section.isArchived,
                    ),
                  ),
                  if (!section.isArchived) ...[
                    const SizedBox(height: 8),
                    const HubSectionLabel('Enroll a learner'),
                    HubStaggerFadeIn(
                      delay: const Duration(milliseconds: 100),
                      child: _EnrollCard(
                        studentIdController: _studentIdC,
                        onEnroll: _enrollStudent,
                      ),
                    ),
                  ],
                ],
                right: [
                  HubSectionLabel('Students · ${roster.length}'),
                  HubStaggerFadeIn(
                    delay: const Duration(milliseconds: 160),
                    child: _RosterSheet(
                      roster: roster,
                      onStudentTap: (s) => _onStudentTap(active, s),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const HubSectionLabel('Manage class'),
                  HubStaggerFadeIn(
                    delay: const Duration(milliseconds: 220),
                    child: _ManageSheet(
                      section: section,
                      onArchive: () => _archive(section),
                      onUnarchive: () => _unarchive(section),
                      onDelete: () => _deleteClass(section),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

/// Status, size and schedule chips under the header title. A class that
/// isn't active gets a "Make active" button in place of the status chip.
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
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (section.isArchived)
          const HubHeaderChip(icon: Icons.archive_outlined, label: 'Archived')
        else if (active)
          const HubHeaderChip(
            icon: Icons.check_circle_rounded,
            label: 'Active class',
          )
        else
          Material(
            color: Colors.white,
            shape: const StadiumBorder(),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: onMakeActive,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Text(
                  'Make active',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.tealDark,
                  ),
                ),
              ),
            ),
          ),
        HubHeaderChip(
          icon: Icons.groups_outlined,
          label: '$studentCount student${studentCount == 1 ? '' : 's'}',
        ),
        if (section.schedule != null && section.schedule!.isNotEmpty)
          HubHeaderChip(
            icon: Icons.schedule_outlined,
            label: section.schedule!,
          ),
      ],
    );
  }
}

class _EnrollCard extends StatelessWidget {
  const _EnrollCard({
    required this.studentIdController,
    required this.onEnroll,
  });

  final TextEditingController studentIdController;
  final VoidCallback onEnroll;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      radius: 20,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ChildFieldLabel(
            'Student ID',
            helper:
                'The learner\'s account must already exist — ask the parent '
                'for the Student ID shown on their child\'s Me tab.',
          ),
          ChildTextField(
            controller: studentIdController,
            hint: 'e.g. 1234-5678',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: onEnroll,
            icon: const Icon(Icons.person_add_alt_1, size: 20),
            label: const Text('Enroll'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.ink,
              minimumSize: const Size(64, 50),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RosterSheet extends StatelessWidget {
  const _RosterSheet({required this.roster, required this.onStudentTap});

  final List<Map<String, dynamic>> roster;
  final ValueChanged<Map<String, dynamic>> onStudentTap;

  @override
  Widget build(BuildContext context) {
    if (roster.isEmpty) {
      return const HubEmptyState(
        icon: Icons.groups_outlined,
        title: 'No students enrolled yet',
        message: 'Enroll a learner with their Student ID to start.',
      );
    }
    return HubRowSheet(
      children: [
        for (final s in roster)
          _StudentRow(student: s, onTap: () => onStudentTap(s)),
      ],
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

    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Pill drops under the name when the row is narrow.
              final compact = scaledExtent(context, constraints.maxWidth) < 330;
              final pill = MasteryPill(mastery: mastery, dotted: true);
              return Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: avatarColor(mastery),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      name.isEmpty ? '?' : name[0].toUpperCase(),
                      style: displayText(17, weight: 800, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        HubFitText(
                          name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        if (compact) ...[const SizedBox(height: 6), pill],
                      ],
                    ),
                  ),
                  if (!compact) ...[const SizedBox(width: 8), pill],
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 22,
                    color: AppColors.inkSoft,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// End-of-school-year retirement (FR-6.1): archive (read-only, roster,
/// progress and lesson folders preserved, see [ClassSection.isArchived]) or
/// unarchive, and — as its own, more severe row — permanent delete
/// (`ClassRepository.deleteClass`).
class _ManageSheet extends StatelessWidget {
  const _ManageSheet({
    required this.section,
    required this.onArchive,
    required this.onUnarchive,
    required this.onDelete,
  });

  final ClassSection section;
  final VoidCallback onArchive;
  final VoidCallback onUnarchive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return HubRowSheet(
      children: [
        if (section.isArchived)
          HubActionRow(
            icon: Icons.unarchive_outlined,
            title: 'This class is archived',
            subtitle:
                'Roster and progress stay saved. Unarchive to reopen '
                'enrollment, casting, and homework for this class.',
            trailing: HubRowButton(label: 'Unarchive', onPressed: onUnarchive),
          )
        else
          HubActionRow(
            icon: Icons.archive_outlined,
            iconColor: AppColors.coral,
            title: 'Archive this class',
            subtitle:
                'Save this class for the record when the school year ends. '
                'Its roster and progress stay intact and read-only until you '
                'unarchive it.',
            trailing: HubRowButton(
              label: 'Archive',
              onPressed: onArchive,
              color: AppColors.coral,
            ),
          ),
        HubActionRow(
          icon: Icons.delete_outline,
          iconColor: AppColors.danger,
          title: 'Delete this class',
          subtitle:
              'Permanently removes the class along with its roster, progress '
              'history, assignments, and lesson folders. This can\'t be '
              'undone — archive instead if you just want to close it out.',
          trailing: HubRowButton(
            label: 'Delete',
            onPressed: onDelete,
            color: AppColors.danger,
          ),
        ),
      ],
    );
  }
}
