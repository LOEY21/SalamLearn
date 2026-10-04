import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../data/curriculum_data.dart';
import '../../data/local/hive_boxes.dart';
import '../../data/models/assigned_module.dart';
import '../../data/models/enrollment.dart';
import '../../data/repositories/class_repository.dart';
import '../../data/repositories/progress_repository.dart';
import '../../logic/auth/session.dart';
import '../../logic/learner/hub_tab_provider.dart';
import '../../logic/sync/sync_manager.dart';
import 'hub_bottom_nav.dart' show HubTab;
import 'package:hive_flutter/hive_flutter.dart';
import '../../logic/learner/learner_xp_provider.dart';
import '../../logic/learner/noor_energy_provider.dart';
import '../../logic/recent_module_provider.dart';
import '../core_modules/lesson_player_screen.dart';
import '../core_modules/module_registry.dart';
import '../theme/app_colors.dart';
import '../widgets/streak_tracker.dart';
import 'hub_world.dart';
import 'noor_energy_resting_sheet.dart';
import 'notifications_sheet.dart';
import '../widgets/learner_avatar.dart';

import '../../data/student_badges.dart';

// ─── Main screen ─────────────────────────────────────────────────────────────

/// The learner's own page: who they are (under the map's starry summit),
/// their real streak / XP / badge counts, homework, and the few settings
/// a child may see. Badges themselves live in the Backpack tab.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final learner = ref.watch(sessionProvider).learner;
    final streakDays = ref.watch(learnerStreakProvider);
    final xp = ref.watch(learnerXpProvider);
    final unlockedBadges = ref.watch(unlockedBadgesProvider);
    final earnedCount = allStudentBadges
        .where((b) => isBadgeUnlocked(b, unlockedBadges))
        .length;
    final name = learner?.name ?? 'friend';

    return Scaffold(
      backgroundColor: HubWorld.parchment,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _ProfileHeader(
            avatar: learner?.avatar ?? '🧒',
            name: name,
            age: learner?.age,
            gradeLevel: learner?.gradeLevel,
          ),
          Transform.translate(
            offset: const Offset(0, -30),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              // Equal-height tiles, whatever the label length.
              child: IntrinsicHeight(
                child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _StatTile(
                      icon: StreakFlame(lit: streakDays > 0, size: 30),
                      value: '$streakDays',
                      label: 'Day Streak',
                      color: AppColors.coral,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatTile(
                      icon: Image.asset(
                        'assets/images/xp_star.webp',
                        width: 30,
                        height: 30,
                        excludeFromSemantics: true,
                      ),
                      value: '$xp',
                      label: 'XP',
                      color: HubWorld.goldDeep,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatTile(
                      icon: Image.asset(
                        'assets/images/adventure_map/tab_backpack.png',
                        width: 30,
                        height: 30,
                        excludeFromSemantics: true,
                      ),
                      value: '$earnedCount',
                      label: 'Badges',
                      color: AppColors.teal,
                      onTap: () => _openBackpack(context, ref),
                    ),
                  ),
                ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 150),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MascotNote(name: name, streakDays: streakDays),
                const SizedBox(height: 24),
                const _SectionTitle('My Homework'),
                const SizedBox(height: 10),
                const _HomeworkCard(),
                const SizedBox(height: 26),
                const _SectionTitle('Settings'),
                const SizedBox(height: 10),
                _SettingRow(
                  icon: Icons.notifications_rounded,
                  label: 'Notifications',
                  sublabel: 'Manage your alerts',
                  color: AppColors.adventurePurple,
                  onTap: () => NotificationsSheet.show(context),
                ),

                const SizedBox(height: 12),
                _SettingRow(
                  icon: Icons.switch_account_rounded,
                  label: 'Switch Account',
                  sublabel: 'Requires parent PIN',
                  color: AppColors.teal,
                  trailingIcon: Icons.lock_rounded,
                  onTap: () {
                    ref
                        .read(sessionProvider.notifier)
                        .selectRole(UserRole.parent);
                    context.go('/parent?from=hub');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openBackpack(BuildContext context, WidgetRef ref) {
    final router = GoRouter.maybeOf(context);
    if (router == null) return;
    ref.read(activeHubTabIndexProvider.notifier).set(1);
    router.go('/backpack');
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.avatar,
    required this.name,
    this.age,
    this.gradeLevel,
  });

  final String avatar;
  final String name;
  final int? age;
  final String? gradeLevel;

  @override
  Widget build(BuildContext context) {
    return MapSceneHeader(
      height: 300,
      image: HubWorld.meArt,
      focusY: -0.3,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Avatar set in a gold-rimmed wooden medallion, like the nav.
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: HubWorld.wood,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.gold.withValues(alpha: 0.45),
                    blurRadius: 22,
                  ),
                ],
              ),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AppColors.goldSoft,
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: ColoredBox(
                    color: HubWorld.parchment,
                    child: LearnerAvatar(avatar: avatar, size: 96),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: hubText(30, Colors.white, height: 1.1, shadows: hubTextShadow),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                if (age != null)
                  WoodChip(
                    label: 'Age $age',
                    icon: const Icon(
                      Icons.cake_rounded,
                      size: 15,
                      color: AppColors.goldSoft,
                    ),
                  ),
                if (gradeLevel != null)
                  WoodChip(
                    label: gradeLevel!,
                    icon: const Icon(
                      Icons.school_rounded,
                      size: 15,
                      color: AppColors.goldSoft,
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

// ─── Stats ───────────────────────────────────────────────────────────────────

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    this.onTap,
  });

  final Widget icon;
  final String value;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ChunkyButton(
      onTap: onTap,
      face: Colors.white,
      edge: HubWorld.edge,
      border: AppColors.creamBorder,
      radius: 20,
      padding: const EdgeInsets.fromLTRB(6, 12, 6, 10),
      semanticLabel: '${label.tr}: $value',
      // Same content in every tile; the "opens" arrow sits in the corner so
      // a tappable tile isn't taller than the others.
      child: Stack(
        fit: StackFit.expand,
        children: [
          Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: 32, child: Center(child: icon)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: hubText(26, color, height: 1.05)),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: hubText(13, HubWorld.inkSoft, weight: 700, height: 1.15),
          ),
        ],
          ),
          if (onTap != null)
            Positioned(
              top: -4,
              right: 0,
              child: Icon(Icons.arrow_forward_rounded, size: 16, color: color),
            ),
        ],
      ),
    );
  }
}

// ─── Mascot note ─────────────────────────────────────────────────────────────

class _MascotNote extends StatelessWidget {
  const _MascotNote({required this.name, required this.streakDays});

  final String name;
  final int streakDays;

  @override
  Widget build(BuildContext context) {
    final message = switch (streakDays) {
      0 => 'Play one game today to start your streak!',
      1 => 'You learned today. Come back tomorrow to grow your streak!',
      _ => 'You have learned $streakDays days in a row. Keep it going!',
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizedBox(
          width: 72,
          height: 72,
          child: Lottie.asset(
            'assets/lottie/owl_idle.json',
            animate: hubMotionOn(context),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
                bottomLeft: Radius.circular(6),
              ),
              border: Border.all(color: AppColors.mintBorder, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Salam, $name! 👋',
                  style: hubText(17, AppColors.tealDark, height: 1.2),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: hubText(14.5, AppColors.ink, weight: 600, height: 1.3),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Section title ───────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label, style: hubText(20, HubWorld.wood, height: 1.1));
  }
}

// ─── Settings rows ───────────────────────────────────────────────────────────

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.onTap,
    this.trailingIcon = Icons.chevron_right_rounded,
  });

  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final VoidCallback onTap;
  final IconData trailingIcon;

  @override
  Widget build(BuildContext context) {
    return ChunkyButton(
      onTap: onTap,
      face: Colors.white,
      edge: HubWorld.edge,
      border: AppColors.creamBorder,
      radius: 18,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      semanticLabel: label.tr,
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 24, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: hubText(17, AppColors.ink, height: 1.15)),
                Text(
                  sublabel,
                  style: hubText(13.5, HubWorld.inkSoft, weight: 600, height: 1.2),
                ),
              ],
            ),
          ),
          Icon(trailingIcon, size: 22, color: HubWorld.inkSoft),
        ],
      ),
    );
  }
}

// ─── Homework ────────────────────────────────────────────────────────────────

/// How many assigned lessons the learner still has to play, across every
/// class they're enrolled in (a personal assignment overrides the class
/// one for the same module). `null` when nothing is assigned at all.
int? _pendingHomework(String learnerId) {
  final repo = ClassRepository();
  final assigned = <String, ({int maxLevel, int? maxLessons})>{};
  for (final e in repo.byLearnerId(learnerId)) {
    for (final a in repo.assignmentsFor(classId: e.classId, learnerId: null)) {
      assigned[a.moduleId] = (maxLevel: a.maxLevel, maxLessons: a.maxLessons);
    }
    for (final a in repo.assignmentsFor(
      classId: e.classId,
      learnerId: learnerId,
    )) {
      assigned[a.moduleId] = (maxLevel: a.maxLevel, maxLessons: a.maxLessons);
    }
  }
  if (assigned.isEmpty) return null;
  final completed = ProgressRepository().completedHomeworkLessonIds(learnerId);
  var pending = 0;
  for (final MapEntry(key: moduleId, value: a) in assigned.entries) {
    pending += assignedLessonsFor(
      moduleId,
      a.maxLevel,
      a.maxLessons,
    ).where((l) => !completed.contains(l.id)).length;
  }
  return pending;
}

/// Fires whenever local enrollments or assignments change — e.g. when
/// [learnerHomeworkPullProvider]'s pull lands — so homework UI rebuilds
/// with what was just downloaded instead of what was there at first build.
Listenable _homeworkBoxes() => Listenable.merge([
  Hive.box<AssignedModule>(HiveBoxes.assignedModules).listenable(),
  Hive.box<Enrollment>(HiveBoxes.enrollments).listenable(),
]);

/// Pulls the learner's homework while [ref]'s widget is showing, and again
/// every time the learner switches back to the Me tab (it stays mounted
/// under the hub's IndexedStack, so it never rebuilds on its own).
void _watchHomeworkPull(WidgetRef ref, String? learnerId) {
  if (learnerId == null) return;
  ref.watch(learnerHomeworkPullProvider(learnerId));
  ref.listen(activeHubTabIndexProvider, (prev, next) {
    if (next == HubTab.profile.index && prev != next) {
      ref.invalidate(learnerHomeworkPullProvider(learnerId));
    }
  });
}

class _HomeworkCard extends ConsumerWidget {
  const _HomeworkCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final learnerId = ref.watch(sessionProvider).learner?.id;
    _watchHomeworkPull(ref, learnerId);
    return ListenableBuilder(
      listenable: _homeworkBoxes(),
      builder: (context, _) => _buildCard(context, learnerId),
    );
  }

  Widget _buildCard(BuildContext context, String? learnerId) {
    final pending = learnerId == null ? null : _pendingHomework(learnerId);
    final hasWork = pending != null && pending > 0;

    final subtitle = pending == null
        ? 'No homework yet'
        : hasWork
        ? '$pending pending game${pending == 1 ? '' : 's'} to play'
        : 'All homework completed! 🎉';

    return ChunkyButton(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const AssignedHomeworkScreen()),
      ),
      face: hasWork ? AppColors.adventurePurple : Colors.white,
      edge: hasWork ? HubWorld.purpleDeep : HubWorld.edge,
      border: hasWork ? null : AppColors.creamBorder,
      radius: 22,
      padding: const EdgeInsets.all(14),
      semanticLabel: 'Assigned Homework'.tr,
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: hasWork
                  ? Colors.white.withValues(alpha: 0.18)
                  : const Color(0xFFE8E4FF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.menu_book_rounded,
              size: 30,
              color: hasWork ? Colors.white : AppColors.adventurePurple,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Assigned Homework',
                  style: hubText(
                    18,
                    hasWork ? Colors.white : AppColors.ink,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: hubText(
                    14,
                    hasWork ? const Color(0xFFEDEBFF) : AppColors.teal,
                    weight: 650,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (hasWork)
            Container(
              constraints: const BoxConstraints(minWidth: 40),
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: Colors.white, width: 2.5),
              ),
              child: Text('$pending', style: hubText(18, HubWorld.wood)),
            )
          else
            const Icon(
              Icons.chevron_right_rounded,
              size: 24,
              color: HubWorld.inkSoft,
            ),
        ],
      ),
    );
  }
}

class AssignedHomeworkScreen extends ConsumerWidget {
  const AssignedHomeworkScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final learner = ref.watch(sessionProvider).learner;
    if (learner == null) {
      return const Scaffold(
        body: Center(child: Text('No active profile')),
      );
    }
    final learnerId = learner.id;
    if (learnerId == null) {
      return const Scaffold(
        body: Center(child: Text('No active profile ID')),
      );
    }
    _watchHomeworkPull(ref, learnerId);
    return ListenableBuilder(
      listenable: _homeworkBoxes(),
      builder: (context, _) => _buildScreen(context, ref, learnerId),
    );
  }

  Widget _buildScreen(BuildContext context, WidgetRef ref, String learnerId) {
    final enrollments = ClassRepository().byLearnerId(learnerId);
    final enrolledClassIds = enrollments.map((e) => e.classId).toSet();

    final List<Map<String, dynamic>> assignedList = [];

    for (final classId in enrolledClassIds) {
      final classAssignments = ClassRepository().assignmentsFor(classId: classId, learnerId: null);
      for (final a in classAssignments) {
        assignedList.add({
          'moduleId': a.moduleId,
          'maxLevel': a.maxLevel,
          'maxLessons': a.maxLessons,
          'assignedBy': 'Class Homework',
        });
      }
      final personalAssignments = ClassRepository().assignmentsFor(classId: classId, learnerId: learnerId);
      for (final a in personalAssignments) {
        final existingIdx = assignedList.indexWhere((m) => m['moduleId'] == a.moduleId);
        if (existingIdx != -1) {
          assignedList[existingIdx] = {
            'moduleId': a.moduleId,
            'maxLevel': a.maxLevel,
            'maxLessons': a.maxLessons,
            'assignedBy': 'Personal Assignment',
          };
        } else {
          assignedList.add({
            'moduleId': a.moduleId,
            'maxLevel': a.maxLevel,
            'maxLessons': a.maxLessons,
            'assignedBy': 'Personal Assignment',
          });
        }
      }
    }

    return Scaffold(
      backgroundColor: AppColors.neutralTint,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.ink),
        ),
        title: const Text(
          'Assigned Homework',
          style: TextStyle(
            color: AppColors.ink,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.creamBorder),
        ),
      ),
      body: SafeArea(
        child: assignedList.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '🎉',
                      style: TextStyle(fontSize: 48),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'No homework assigned!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Check back later for new tasks from your teacher.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(18),
                itemCount: assignedList.length,
                itemBuilder: (context, index) {
                  final assignment = assignedList[index];
                  final moduleId = assignment['moduleId'] as String;
                  final maxLevel = assignment['maxLevel'] as int;
                  final maxLessons = assignment['maxLessons'] as int?;

                  final module =
                      moduleForAssignment(moduleId) ?? coreModules.first;
                  final dest = curriculum.firstWhere(
                    (d) => d.id == module.destinationId,
                    orElse: () => curriculum.first,
                  );
                  final assignedLessons =
                      assignedLessonsFor(moduleId, maxLevel, maxLessons);
                  final lessons = dest.lessons;
                  final perLevel = (lessons.length / 3).ceil();
                  final levelsList = [
                    lessons.take(perLevel).toList(),
                    lessons.skip(perLevel).take(perLevel).toList(),
                    lessons.skip(perLevel * 2).toList(),
                  ].where((group) => group.isNotEmpty).toList();

                  final completedLessons =
                      ProgressRepository().completedHomeworkLessonIds(learnerId);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    color: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: const BorderSide(color: AppColors.creamBorder, width: 2),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: module.color.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(module.icon, color: module.color, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      assignmentTitle(moduleId),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      assignment['assignedBy'] as String,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Divider(height: 1, color: AppColors.creamBorder),
                          const SizedBox(height: 14),
                          if (assignedLessons.isEmpty)
                            const Text(
                              'No specific games assigned.',
                              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                            )
                          else
                            ...assignedLessons.map((lesson) {
                              final done = completedLessons.contains(lesson.id);

                              // Find which level this lesson belongs to
                              var levelName = 'Beginner';
                              for (var li = 0; li < levelsList.length; li++) {
                                if (levelsList[li].any((l) => l.id == lesson.id)) {
                                  levelName = switch (li) {
                                    0 => 'Beginner',
                                    1 => 'Practice',
                                    _ => 'Mastery',
                                  };
                                  break;
                                }
                              }

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: InkWell(
                                  onTap: () {
                                    // Same Noor Energy rule as the map: none
                                    // left blocks every game, finished ones
                                    // too; otherwise only a new one costs 1.
                                    if (!ref.read(noorEnergyProvider).hasEnergy) {
                                      showNoorEnergyRestingSheet(context);
                                      return;
                                    }
                                    if (!done) {
                                      ref.read(noorEnergyProvider.notifier).consume();
                                    }
                                    ref.read(recentModuleProvider.notifier).interactWith(module.id);
                                    Navigator.of(context, rootNavigator: true).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => LessonPlayerScreen(
                                          lesson: lesson,
                                          destinationId: dest.id,
                                          assignedByTeacher: true,
                                          onClose: () {
                                            Navigator.of(context, rootNavigator: true).pop();
                                            // Re-trigger rebuild
                                            ref.invalidate(sessionProvider);
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: AppColors.neutralTint,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 34,
                                          height: 34,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: done ? AppColors.mint : Colors.white,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Text(
                                            done ? '✓' : lesson.icon,
                                            style: TextStyle(
                                              fontSize: done ? 14 : 18,
                                              fontWeight: done ? FontWeight.bold : null,
                                              color: done ? AppColors.adventureGreen : null,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                lesson.title,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w700,
                                                  color: done ? AppColors.textMuted : AppColors.ink,
                                                  decoration: done ? TextDecoration.lineThrough : null,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                levelName,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.textMuted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          done ? Icons.check_circle_rounded : Icons.play_arrow_rounded,
                                          color: done ? AppColors.adventureGreen : AppColors.adventureBlue,
                                          size: 22,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

// Removed old _AssignedHomeworkSection class.
