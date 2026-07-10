import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/class_section.dart';
import '../../data/models/custom_lesson.dart';
import '../../data/repositories/class_repository.dart';
import '../../data/repositories/custom_lesson_repository.dart';
import '../../data/repositories/learner_repository.dart';
import '../../logic/auth/session.dart';
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
/// Redesigned to match the Classroom tab's own visual language: full-bleed
/// hero, ambient breathing blobs, staggered card entrance, and the same
/// stamped "Class Pass" ticket for the invitation code.
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
    ref.invalidate(teacherRosterProvider);
  }

  Future<void> _openCreateLessonDialog(String teacherId) async {
    final titleC = TextEditingController();
    final instructionsC = TextEditingController();
    final bodyC = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New Custom Lesson'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: titleC,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'e.g. Practicing Wudu at home',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: instructionsC,
                decoration: const InputDecoration(
                  labelText: 'Instructions',
                  hintText: 'What should the learner do?',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bodyC,
                decoration: const InputDecoration(
                  labelText: 'Lesson content',
                  hintText: 'Write the lesson text here...',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 6,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (titleC.text.trim().isEmpty || bodyC.text.trim().isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a title and lesson content'),
                  ),
                );
                return;
              }
              Navigator.of(dialogContext).pop(true);
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (created == true) {
      await CustomLessonRepository().create(
        classId: widget.classId,
        teacherId: teacherId,
        title: titleC.text.trim(),
        instructions: instructionsC.text.trim(),
        body: bodyC.text.trim(),
      );
      ref.invalidate(classCustomLessonsProvider(widget.classId));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Lesson created!')));
      }
    }
  }

  Future<void> _deleteLesson(CustomLesson lesson) async {
    await CustomLessonRepository().delete(lesson.id);
    ref.invalidate(classCustomLessonsProvider(widget.classId));
  }

  Future<void> _regenerateCode(ClassSection section) async {
    await ClassRepository().regenerateInvitationCode(section);
    _refresh();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New invitation code generated!')),
      );
    }
  }

  void _enrollStudent() {
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
    final matches = LearnerRepository().findAllByName(name);
    if (matches.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No learner found named "$name"')));
      return;
    }
    if (matches.length > 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Multiple learners named "$name" found — ask the parent to confirm.',
          ),
        ),
      );
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
    final classes = ref.watch(teacherClassesProvider);
    final section = classes.where((c) => c.id == widget.classId).firstOrNull;
    final activeId = ref.watch(teacherClassControllerProvider)?.id;
    final active = widget.classId == activeId;
    final roster = ref.watch(classRosterProvider(widget.classId));
    final lessons = ref.watch(classCustomLessonsProvider(widget.classId));
    final teacherId = ref.watch(sessionProvider).activeTeacherId;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: section == null
            ? SafeArea(
                child: Column(
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
                ),
              )
            : SafeArea(
                bottom: false,
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _DetailHero(
                      section: section,
                      active: active,
                      studentCount: roster.length,
                      onBack: _goBack,
                      onMakeActive: _makeActive,
                    ),
                    Transform.translate(
                      offset: const Offset(0, -22),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 22, 16, 28),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _StampIn(
                              delay: const Duration(milliseconds: 60),
                              child: _ClassPassTicket(
                                section: section,
                                onRegenerate: () => _regenerateCode(section),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _StaggerFadeIn(
                              delay: const Duration(milliseconds: 160),
                              child: _EnrollCard(
                                firstNameController: _firstNameC,
                                middleNameController: _middleNameC,
                                lastNameController: _lastNameC,
                                onEnroll: _enrollStudent,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _StaggerFadeIn(
                              delay: const Duration(milliseconds: 200),
                              child: _CustomLessonsCard(
                                lessons: lessons,
                                onCreate: teacherId == null
                                    ? null
                                    : () => _openCreateLessonDialog(teacherId),
                                onDelete: _deleteLesson,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _StaggerFadeIn(
                              delay: const Duration(milliseconds: 240),
                              child: _RosterCard(
                                roster: roster,
                                onStudentTap: (s) => _onStudentTap(active, s),
                              ),
                            ),
                          ],
                        ),
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

/// Full-bleed masthead — same recipe as the Classroom tab's own hero
/// (ambient breathing blobs + fade/slide-down entrance), plus a back
/// button and an active/make-active chip since this is a pushed route.
class _DetailHero extends StatefulWidget {
  const _DetailHero({
    required this.section,
    required this.active,
    required this.studentCount,
    required this.onBack,
    required this.onMakeActive,
  });

  final ClassSection section;
  final bool active;
  final int studentCount;
  final VoidCallback onBack;
  final VoidCallback onMakeActive;

  @override
  State<_DetailHero> createState() => _DetailHeroState();
}

class _DetailHeroState extends State<_DetailHero>
    with TickerProviderStateMixin {
  late final _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  )..forward();

  late final _breathe = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat(reverse: true);

  late final _fade = CurvedAnimation(parent: _entrance, curve: Curves.easeOut);
  late final _slide = Tween<Offset>(
    begin: const Offset(0, -0.12),
    end: Offset.zero,
  ).animate(_fade);

  @override
  void dispose() {
    _entrance.dispose();
    _breathe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 8, 20, 46),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.teal, AppColors.tealDark],
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedBuilder(
              animation: _breathe,
              builder: (context, child) {
                final t = Curves.easeInOut.transform(_breathe.value);
                return Positioned(
                  top: -95 + (6 * t),
                  right: -50,
                  child: Opacity(
                    opacity: 0.05 + (0.03 * t),
                    child: Container(
                      width: 190,
                      height: 190,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              },
            ),
            AnimatedBuilder(
              animation: _breathe,
              builder: (context, child) {
                final t = Curves.easeInOut.transform(_breathe.value);
                return Positioned(
                  bottom: -70 - (5 * t),
                  left: -36,
                  child: Opacity(
                    opacity: 0.08 + (0.04 * t),
                    child: Container(
                      width: 130,
                      height: 130,
                      decoration: const BoxDecoration(
                        color: AppColors.gold,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              },
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: widget.onBack,
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    if (widget.active)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                            SizedBox(width: 5),
                            Text(
                              'Active class',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      OutlinedButton(
                        onPressed: widget.onMakeActive,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                        ),
                        child: const Text('Make Active'),
                      ),
                    const SizedBox(width: 4),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8, right: 8),
                  child: FadeTransition(
                    opacity: _fade,
                    child: SlideTransition(
                      position: _slide,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.section.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _HeroChip(
                                icon: Icons.groups_outlined,
                                value:
                                    '${widget.studentCount} student${widget.studentCount == 1 ? '' : 's'}',
                              ),
                              if (widget.section.schedule != null &&
                                  widget.section.schedule!.isNotEmpty)
                                _HeroChip(
                                  icon: Icons.schedule_outlined,
                                  value: widget.section.schedule!,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.goldSoft),
          const SizedBox(width: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// The signature "Class Pass" ticket — same treatment as the Classroom
/// tab's own invitation-code card (dashed perforation, punched notches,
/// monospace code) but scoped to whichever specific class this screen is
/// showing rather than always the "active" one.
class _ClassPassTicket extends StatefulWidget {
  const _ClassPassTicket({required this.section, required this.onRegenerate});

  final ClassSection section;
  final VoidCallback onRegenerate;

  @override
  State<_ClassPassTicket> createState() => _ClassPassTicketState();
}

class _ClassPassTicketState extends State<_ClassPassTicket> {
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
                  TextButton.icon(
                    onPressed: widget.onRegenerate,
                    icon: const Icon(
                      Icons.refresh_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'New',
                      style: TextStyle(color: Colors.white, fontSize: 11.5),
                    ),
                    style: TextButton.styleFrom(
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
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
        Positioned(
          left: -11,
          top: 39,
          child: _PassNotch(color: AppColors.surface),
        ),
        Positioned(
          right: -11,
          top: 39,
          child: _PassNotch(color: AppColors.surface),
        ),
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

class _CustomLessonsCard extends StatelessWidget {
  const _CustomLessonsCard({
    required this.lessons,
    required this.onCreate,
    required this.onDelete,
  });

  final List<CustomLesson> lessons;
  final VoidCallback? onCreate;
  final ValueChanged<CustomLesson> onDelete;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'CUSTOM LESSONS',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('New Lesson'),
                style: TextButton.styleFrom(foregroundColor: AppColors.teal),
              ),
            ],
          ),
          if (lessons.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No custom lessons yet — write one for this class to appear in every enrolled learner\'s Student Hub.',
                style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
              ),
            )
          else
            for (final lesson in lessons)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.creamBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.menu_book_outlined,
                        size: 18,
                        color: AppColors.gold,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lesson.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            if (lesson.instructions.isNotEmpty)
                              Text(
                                lesson.instructions,
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
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: AppColors.danger,
                        ),
                        onPressed: () => onDelete(lesson),
                        tooltip: 'Delete lesson',
                      ),
                    ],
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
    duration: const Duration(milliseconds: 380),
  );
  late final _fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
  late final _slide = Tween<Offset>(
    begin: const Offset(0, 0.12),
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

/// The Class Pass's entrance — a "stamp" settle (scale + slight rotation
/// easing to rest) matching the Classroom tab's own signature moment.
class _StampIn extends StatefulWidget {
  const _StampIn({required this.delay, required this.child});

  final Duration delay;
  final Widget child;

  @override
  State<_StampIn> createState() => _StampInState();
}

class _StampInState extends State<_StampIn>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 480),
  );
  late final _curve = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);

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
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, child) {
        final t = _curve.value;
        return Opacity(
          opacity: t,
          child: Transform.rotate(
            angle: (1 - t) * -0.05,
            child: Transform.scale(scale: 0.9 + (0.1 * t), child: child),
          ),
        );
      },
      child: widget.child,
    );
  }
}
