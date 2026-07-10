import 'package:flutter/material.dart';
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
/// Redesigned to match the Classroom tab's own visual language: a
/// full-bleed hero (ambient breathing blobs, fade/slide entrance) instead
/// of a plain AppBar, with the class list staggering in below it.
class ClassroomManagementScreen extends StatefulWidget {
  const ClassroomManagementScreen({super.key});

  @override
  State<ClassroomManagementScreen> createState() =>
      _ClassroomManagementScreenState();
}

class _ClassroomManagementScreenState extends State<ClassroomManagementScreen> {
  void _goBack(BuildContext context) => context.go('/teacher');

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _goBack(context);
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          bottom: false,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _ManagementHero(onBack: () => _goBack(context)),
              Transform.translate(
                offset: const Offset(0, -22),
                child: Container(
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
                  child: const _ClassList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-bleed masthead — same recipe as the Classroom tab's own hero
/// (ambient breathing blobs + fade/slide-down entrance), plus a back
/// button since this is a pushed route rather than a bottom-nav tab.
class _ManagementHero extends ConsumerStatefulWidget {
  const _ManagementHero({required this.onBack});

  final VoidCallback onBack;

  @override
  ConsumerState<_ManagementHero> createState() => _ManagementHeroState();
}

class _ManagementHeroState extends ConsumerState<_ManagementHero>
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
    final classCount = ref.watch(teacherClassesProvider).length;
    final studentCount = ref.watch(teacherTotalStudentsProvider);

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
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: FadeTransition(
                    opacity: _fade,
                    child: SlideTransition(
                      position: _slide,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'My Classes',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Tap a class to manage its students',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              _HeroChip(
                                icon: Icons.class_outlined,
                                value: '$classCount classes',
                              ),
                              const SizedBox(width: 8),
                              _HeroChip(
                                icon: Icons.groups_outlined,
                                value: '$studentCount students',
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

class _ClassList extends ConsumerWidget {
  const _ClassList();

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
            ),
          ),
          if (i != classes.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _ClassRow extends ConsumerWidget {
  const _ClassRow({required this.section, required this.active});

  final ClassSection section;
  final bool active;

  /// Selecting a class from the picker both makes it the active class
  /// (so the Roster tab, homework assigner, etc. all scope to it) and
  /// opens its dedicated management screen — with a loading overlay
  /// covering the switch so the hand-off doesn't feel like a stalled tap.
  Future<void> _select(BuildContext context, WidgetRef ref) async {
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
    final borderColor = active ? AppColors.teal : AppColors.creamBorder;

    return SoftCard(
      onTap: () => _select(context, ref),
      borderColor: borderColor,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
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
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${roster.length} student${roster.length == 1 ? '' : 's'}'
                  '${active ? ' · Active class' : ''}'
                  '${section.schedule != null && section.schedule!.isNotEmpty ? ' · ${section.schedule}' : ''}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            size: 22,
            color: AppColors.textMuted,
          ),
        ],
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
