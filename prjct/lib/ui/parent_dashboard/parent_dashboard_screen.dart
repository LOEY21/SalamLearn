import 'dart:math';

import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:lottie/lottie.dart';

import '../../data/local/hive_boxes.dart';
import '../../data/models/curriculum/curriculum_models.dart';
import '../../data/models/enrollment.dart';
import '../../data/models/assigned_module.dart';
import '../../data/remote/firestore_mirror.dart';
import '../../data/repositories/class_repository.dart';
import '../../logic/auth/session.dart';
import '../../logic/parent/analytics_providers.dart';
import '../../logic/parent/children_providers.dart';
import '../../logic/settings/settings_providers.dart';
import '../../logic/sync/sync_manager.dart';
import '../../logic/teacher/teacher_providers.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_loading_overlay.dart';
import '../widgets/email_verification_card.dart';
import '../widgets/flat_dashboard_header.dart';
import '../widgets/learner_avatar.dart';
import '../widgets/mock_icons.dart';
import '../widgets/soft_card.dart';
import '../widgets/top_tab_bar.dart';
import '../../data/repositories/progress_repository.dart';
import '../core_modules/module_registry.dart';

/// Progress-tab heading — a brand-new account has no enrolled child yet
/// (the caller falls back to the literal name 'your child' in that case),
/// so "your child's progress" reads oddly next to an empty dashboard.
/// Nudge them toward the actual next step instead.
String _progressHeading(String name) =>
    name == 'your child' ? 'Enroll your child' : "$name's progress";

/// Greeting line for the Progress screen — addresses the parent by their
/// own name (distinct from the "[Child]'s progress" heading next to it,
/// which stays about the child). Falls back to the generic greeting if
/// this account has no name on file yet (e.g. a bare PIN-only bootstrap
/// account — see `SessionNotifier.activeAccountHasEmail`'s doc).
String _parentGreeting(WidgetRef ref, {bool caps = false}) {
  final parentName = ref.read(sessionProvider.notifier).activeParentFullName;
  if (parentName == null || parentName.isEmpty) {
    return caps
        ? "ASSALAMU'ALAIKUM"
        : "Assalamu'alaikum, here's this week's summary";
  }
  return caps
      ? "ASSALAMU'ALAIKUM, ${parentName.toUpperCase()}"
      : "Assalamu'alaikum, $parentName — here's this week's summary";
}

/// Live "synced" status line shown under the header title — same wording
/// this used to render inside the (now removed) gradient hero.
String _syncStatusLabel(WidgetRef ref) {
  final lastSynced = ref.read(syncManagerProvider).lastSyncedAt;
  if (lastSynced == null) return 'Not synced yet';
  final elapsed = DateTime.now().difference(lastSynced);
  if (elapsed.inMinutes < 1) return 'Synced just now';
  if (elapsed.inMinutes < 60) return 'Synced ${elapsed.inMinutes} min ago';
  if (elapsed.inHours < 24) return 'Synced ${elapsed.inHours}h ago';
  return 'Synced ${elapsed.inDays}d ago';
}

/// Parent analytics dashboard (mockup Figure 4.4, FR-5.1/5.2/7.2).
/// Phone: gradient hero header + stacked cards + bottom nav. Wide/monitor:
/// labeled teal side rail, 4-up metric row, chart and suggestions side by
/// side. Redesigned per the approved motion-design/impeccable HTML preview
/// (dumps/parent_dashboard_redesign_mock.html): icon-chip KPI cards with
/// trend tags, a range-pill chart card, and a checklist-style suggestions
/// card in place of the old flat tiles and bullet paragraph. KPI/chart/
/// suggestions data is real (backed by `ProgressRepository`), not mocked.
class ParentDashboardScreen extends ConsumerWidget {
  const ParentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final learner = ref.watch(sessionProvider).learner;
    final name = learner?.name ?? 'your child';

    // Watches the parent's Firestore document in real time. If the admin
    // web panel deletes it, the stream emits false immediately and this
    // listener fires — showing the warning dialog without needing a page
    // reload or app restart. Uses `prev` vs `next` to fire only once:
    // after the dialog shows and navigates away, the stream auto-disposes.
    ref.listen(accountStreamProvider, (prev, next) {
      next.whenData((stillExists) async {
        if (stillExists || prev?.asData?.value == false) return;
        if (!context.mounted) return;
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            icon: const Icon(
              Icons.info_outline_rounded,
              color: AppColors.coral,
              size: 44,
            ),
            title: const Text('Account no longer available'),
            content: const Text(
              'This account was removed by an administrator. '
              'Your data will no longer sync. Please contact your school '
              'administrator if you believe this was a mistake.',
            ),
            actions: [
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        if (!context.mounted) return;
        // Navigate to a gate path first so the router redirect (triggered by
        // the logout below) doesn't land on /pin/setup — gate paths skip the
        // PIN check, so the user lands on the role picker instead.
        context.go('/roles');
        await ref.read(sessionProvider.notifier).logout();
      });
    });
    // Watches the Firestore learners collection for remote deletions (admin
    // web panel removing a child). When detected, removes from local Hive
    // and re-picks the active learner — see the provider's doc for details.
    ref.listen(learnerSyncProvider, (_, _) {});
    ref.listen(parentEnrollmentSyncProvider, (_, _) {});

    // Without this, hardware/system back had no explicit handling here,
    // so it fell through to go_router's default history-pop — silently
    // landing back on the role picker with no confirmation and, worse,
    // leaving `pinVerified` still true, so re-picking Parent skipped the
    // PIN gate entirely. Reusing the existing "Switch User?" confirmation
    // makes back press exactly as intentional as tapping that menu item.
    String? tabParam;
    try {
      tabParam = GoRouterState.of(context).uri.queryParameters['tab'];
    } catch (_) {}
    final initialTab = int.tryParse(tabParam ?? '') ?? 0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _switchUser(context, ref);
      },
      child: _PhoneLayout(name: name, initialTab: initialTab),
    );
  }
}

void _switchUser(BuildContext context, WidgetRef ref) {
  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Switch User?'),
      content: const Text(
        'Are you sure you want to switch user? This will lock the current session and return to the role select screen.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
          onPressed: () {
            ref.read(sessionProvider.notifier).lockAdminModules();
            Navigator.of(dialogContext).pop();
            context.go('/roles');
          },
          child: const Text('Switch'),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------- phone

class _PhoneLayout extends ConsumerStatefulWidget {
  const _PhoneLayout({required this.name, this.initialTab = 0});

  final String name;
  final int initialTab;

  @override
  ConsumerState<_PhoneLayout> createState() => _PhoneLayoutState();
}

class _PhoneLayoutState extends ConsumerState<_PhoneLayout>
    with SingleTickerProviderStateMixin {
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _currentTab = widget.initialTab;
  }

  void _switchTab(int index) {
    if (index == _currentTab) return;
    setState(() => _currentTab = index);
  }

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  Animation<double> _in(double start, double end) {
    return CurvedAnimation(
      parent: _c,
      curve: Interval(start, end, curve: Curves.easeOut),
    );
  }

  late final greet = _in(0.05, 0.45);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static const _tabs = [
    TopTabItem(iconPath: MockIcons.progress, label: 'Progress'),
    TopTabItem(iconPath: MockIcons.profile, label: 'Profile'),
    TopTabItem(iconPath: MockIcons.settings, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final learner = ref.watch(sessionProvider.select((s) => s.learner));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: Column(
            children: [
              FadeTransition(
                opacity: greet,
                child: FlatDashboardHeader(
                  avatar: GestureDetector(
                    onTap: () => _switchTab(0),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.teal, width: 1.5),
                      ),
                      child: LearnerAvatar(
                        avatar: learner?.avatar ?? '🧒',
                        size: 34,
                      ),
                    ),
                  ),
                  eyebrow: _parentGreeting(ref, caps: true),
                  title: _progressHeading(widget.name),
                  statusLabel: _syncStatusLabel(ref),
                  actions: [
                    HeaderIconButton(
                      iconPath: MockIcons.swap,
                      tooltip: 'Switch user',
                      onTap: () => _switchUser(context, ref),
                    ),
                  ],
                ),
              ),
              TopTabBar(
                items: _tabs,
                activeIndex: _currentTab,
                onChanged: _switchTab,
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: _PanelRise(
                      key: ValueKey(_currentTab),
                      child: switch (_currentTab) {
                        0 => ListView(
                          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                          children: [
                            const _StaggerFadeIn(
                              delay: Duration.zero,
                              child: _KpiFocusRow(),
                            ),
                            const SizedBox(height: 14),
                            const _StaggerFadeIn(
                              delay: Duration(milliseconds: 35),
                              child: _TrendChartCard(),
                            ),
                            const SizedBox(height: 14),
                            const _StaggerFadeIn(
                              delay: Duration(milliseconds: 70),
                              child: _AdventureBreakdownCard(),
                            ),
                          ],
                        ),
                        1 => ListView(
                          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                          children: [
                            _StaggerFadeIn(
                              delay: const Duration(milliseconds: 25),
                              child: _ChildSwitcher(
                                onSwitched: () => _switchTab(0),
                              ),
                            ),
                            const SizedBox(height: 14),
                            const _StaggerFadeIn(
                              delay: Duration(milliseconds: 40),
                              child: _NoProfileEmptyState(),
                            ),
                            const SizedBox(height: 14),
                            const _StaggerFadeIn(
                              delay: Duration(milliseconds: 60),
                              child: _ManageProfileCard(),
                            ),
                            const SizedBox(height: 14),
                            const _StaggerFadeIn(
                              delay: Duration(milliseconds: 95),
                              child: _ClassSection(),
                            ),
                            const SizedBox(height: 14),
                            const _StaggerFadeIn(
                              delay: Duration(milliseconds: 130),
                              child: _CreateNewProfileCard(),
                            ),
                            const SizedBox(height: 14),
                            const _StaggerFadeIn(
                              delay: Duration(milliseconds: 165),
                              child: _SyncProfileCard(),
                            ),
                          ],
                        ),
                        _ => const _SettingsTab(),
                      },
                    ),
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

/// Lets a parent with more than one child switch which one's dashboard
/// (KPIs, streak, suggestions below, plus the "Edit Child Profile" form)
/// is currently active. Hidden entirely when there's zero or one child —
/// nothing to switch between yet.
class _ChildSwitcher extends ConsumerWidget {
  const _ChildSwitcher({required this.onSwitched});

  /// Called once the switch (and its loading overlay) finishes — the
  /// caller uses this to jump back to the Progress/analytics tab, so the
  /// parent immediately sees the newly-active child's data instead of
  /// staying on the Manage Profile tab this switcher lives on.
  final VoidCallback onSwitched;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final children = ref.watch(parentLearnersProvider);
    if (children.length < 2) return const SizedBox.shrink();

    final activeId = ref.watch(sessionProvider.select((s) => s.learner?.id));

    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: children.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final child = children[index];
          final isActive = child.id == activeId;
          return GestureDetector(
            onTap: child.id == null || isActive
                ? null
                : () async {
                    await runWithAuthLoadingOverlay(
                      AuthLoadingAction.switchProfile,
                      () => ref
                          .read(sessionProvider.notifier)
                          .switchActiveLearner(child.id!),
                    );
                    onSwitched();
                  },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 72,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
              decoration: BoxDecoration(
                color: isActive ? AppColors.goldTint : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isActive ? AppColors.gold : AppColors.creamBorder,
                  width: isActive ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  LearnerAvatar(avatar: child.avatar, size: 36),
                  const SizedBox(height: 4),
                  Text(
                    child.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                      color: isActive
                          ? const Color(0xFF8A5A12)
                          : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Illustrated prompt shown only when no learner profile exists yet —
/// self-hiding like `_ManageProfileCard`/`_ClassSection` below, so the
/// Manage Profile tab isn't just a bare hero + "Add Child Profile" button
/// with nothing explaining why the rest of the tab (class join, sync) is
/// empty until a profile exists.
class _NoProfileEmptyState extends ConsumerWidget {
  const _NoProfileEmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final learner = ref.watch(sessionProvider.select((s) => s.learner));
    if (learner != null) return const SizedBox.shrink();

    return SoftCard(
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
      child: Column(
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: Lottie.asset('assets/lottie/add_profile.json'),
          ),
          const SizedBox(height: 6),
          Text(
            'No child profile yet',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          const Text(
            "Add your child's profile below to start tracking their "
            'learning journey.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

/// Compact entry point into [EditChildProfileScreen] — the actual editing
/// form (and its Danger Zone/delete action) now lives on its own route
/// instead of competing for space inline on this tab with the child
/// switcher and class-join section.
class _ManageProfileCard extends ConsumerWidget {
  const _ManageProfileCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final learner = ref.watch(sessionProvider.select((s) => s.learner));
    // Nothing to edit yet on a fresh account — the "Create New Profile"
    // card below is the only relevant action until a learner exists.
    if (learner == null) {
      return const SizedBox.shrink();
    }
    return SoftCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          LearnerAvatar(avatar: learner.avatar, size: 48),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edit Child Profile',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  '${learner.name} · Age ${learner.age} · ${learner.gradeLevel}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.teal,
              side: const BorderSide(color: AppColors.creamBorder),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => context.go('/parent/edit-child'),
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }
}

/// FR-6.1's invitation-code join, from the parent's side — a teacher
/// generates a class + 6-character code on their own dashboard
/// (`teacher_dashboard_screen.dart`'s "Class invitation code" card) and
/// shares it out of band; the parent enters it here, once per child, to
/// enroll that specific learner. Both roles read/write the same local
/// Hive `classes`/`enrollments` boxes (this app's "one binary, three
/// roles" model), so no network round trip is needed for this to work.
class _ClassSection extends ConsumerStatefulWidget {
  const _ClassSection();

  @override
  ConsumerState<_ClassSection> createState() => _ClassSectionState();
}

class _ClassSectionState extends ConsumerState<_ClassSection> {
  final _codeC = TextEditingController();
  bool _joining = false;

  @override
  void dispose() {
    _codeC.dispose();
    super.dispose();
  }

  Future<void> _join(String learnerId) async {
    final code = _codeC.text.trim().toUpperCase();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the class invitation code')),
      );
      return;
    }

    setState(() => _joining = true);
    final classes = ClassRepository();
    var section = classes.findByInvitationCode(code);

    // Not on this device yet — the common real case, since the teacher who
    // generated this code almost always did it on their own separate
    // device/install, not this one. Fall back to Firestore (best-effort:
    // offline, or an account never linked to Firebase, just falls through
    // to the same "invalid code" message below rather than a confusing
    // network error).
    if (section == null) {
      try {
        final remote = await FirestoreMirror().fetchClassByInvitationCode(code);
        if (remote != null) {
          section = await classes.saveFromRemote(remote);
        }
      } catch (e) {
        debugPrint('_ClassSection._join: remote lookup failed: $e');
      }
    }

    if (section == null) {
      if (mounted) {
        setState(() => _joining = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid invitation code')),
        );
      }
      return;
    }

    await classes.enroll(classId: section.id, learnerId: learnerId);
    // Best-effort — mirrors the enrollment up so the teacher's own device
    // sees this child on their roster next time they sync, without
    // blocking the join itself if offline.
    try {
      await FirestoreMirror().pushEnrollment(
        Enrollment(
          classId: section.id,
          learnerId: learnerId,
          enrolledAt: DateTime.now(),
        ),
      );
    } catch (e) {
      debugPrint('_ClassSection._join: enrollment push failed: $e');
    }

    // Pull assignments for the joined class section from Firestore immediately
    try {
      final remoteClassAssignments = await FirestoreMirror()
          .fetchAssignmentsForClass(section.id);
      final remotePersonalAssignments = await FirestoreMirror()
          .fetchAssignmentsForLearner(learnerId);
      final assignmentsBox = Hive.box<AssignedModule>(
        HiveBoxes.assignedModules,
      );
      for (final remote in [
        ...remoteClassAssignments,
        ...remotePersonalAssignments,
      ]) {
        await assignmentsBox.put(remote.id, remote);
      }
    } catch (e) {
      debugPrint('_ClassSection._join: pulling assignments failed: $e');
    }
    refreshLearnerClass(ref);
    ref.read(rosterRefreshProvider.notifier).bump();
    _codeC.clear();
    if (mounted) {
      setState(() => _joining = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Joined ${section.name}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final learner = ref.watch(sessionProvider.select((s) => s.learner));
    final learnerId = learner?.id;
    // Nothing to enroll — mirrors `_ManageProfileCard`'s own guard.
    if (learner == null || learnerId == null) {
      return const SizedBox.shrink();
    }
    final section = ref.watch(learnerClassProvider(learnerId));

    return SoftCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Class', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          if (section != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: section.isArchived
                    ? AppColors.neutralTint
                    : AppColors.mint,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: section.isArchived
                      ? AppColors.creamBorder
                      : AppColors.mintBorder,
                ),
              ),
              child: Row(
                children: [
                  section.isArchived
                      ? const Icon(
                          Icons.archive_outlined,
                          color: AppColors.textMuted,
                          size: 18,
                        )
                      : const MockIcon(
                          MockIcons.classBadge,
                          color: AppColors.teal,
                          size: 18,
                        ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      section.isArchived
                          ? "${section.name} has been archived by the teacher"
                          : '${learner.name} is enrolled in ${section.name}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: section.isArchived
                            ? AppColors.textMuted
                            : AppColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              section.isArchived
                  ? 'This class is no longer active. Enter a new invitation '
                        'code below to join a different class.'
                  : 'Enter a new invitation code below to join a different class.',
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textMuted,
              ),
            ),
          ] else ...[
            const Text(
              "Not in a class yet. Enter the invitation code your child's "
              'teacher shared with you.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _Input(controller: _codeC, label: 'Invitation code'),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: 42,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _joining ? null : () => _join(learnerId),
                  child: _joining
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Join'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CreateNewProfileCard extends StatelessWidget {
  const _CreateNewProfileCard();

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Create New Profile',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          const Text(
            'Set up a new learning journey for another child on this device.',
            style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.ink,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add Child Profile'),
            onPressed: () => context.go('/learner-setup?from=parent'),
          ),
        ],
      ),
    );
  }
}

class _SyncProfileCard extends ConsumerStatefulWidget {
  const _SyncProfileCard();

  @override
  ConsumerState<_SyncProfileCard> createState() => _SyncProfileCardState();
}

class _SyncProfileCardState extends ConsumerState<_SyncProfileCard> {
  bool _syncing = false;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      color: AppColors.mint,
      borderColor: AppColors.mintBorder,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Synchronize Data',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          const Text(
            'Backup and sync progress data with the cloud server.',
            style: TextStyle(fontSize: 12.5, color: AppColors.tealDark),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: _syncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.sync, size: 18),
            label: Text(_syncing ? 'Syncing...' : 'Sync Profile Data'),
            onPressed: _syncing
                ? null
                : () async {
                    setState(() => _syncing = true);
                    try {
                      await ref.read(syncManagerProvider).syncNow();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Profile progress synchronized!'),
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

class _Input extends StatefulWidget {
  const _Input({required this.controller, required this.label});
  final TextEditingController controller;
  final String label;

  @override
  State<_Input> createState() => _InputState();
}

class _InputState extends State<_Input> {
  final _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _focused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: AppColors.teal.withValues(alpha: 0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        decoration: InputDecoration(
          label: Text(widget.label),
          labelStyle: const TextStyle(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w700,
          ),
          floatingLabelStyle: const TextStyle(
            color: AppColors.teal,
            fontWeight: FontWeight.w700,
          ),
          filled: true,
          fillColor: AppColors.neutralTint,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.creamBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.creamBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.teal, width: 1.6),
          ),
        ),
      ),
    );
  }
}
// ------------------------------------------------------------- shared

/// Radial accuracy dial + stacked time/error stat pills — replaces the flat
/// 2x2 KPI grid with one focal metric (streak surfaces as a tappable badge
/// notched onto the dial, not its own tile).
class _KpiFocusRow extends ConsumerStatefulWidget {
  const _KpiFocusRow({this.wide = false});

  final bool wide;

  @override
  ConsumerState<_KpiFocusRow> createState() => _KpiFocusRowState();
}

class _KpiFocusRowState extends ConsumerState<_KpiFocusRow>
    with SingleTickerProviderStateMixin {
  bool _showMilestone = false;

  // One-shot reward burst (Lottie) — plays only when the parent *taps* to
  // reveal the milestone caption, never loops on its own. Matches the
  // motion-design "Success State" pattern (primary: pop, secondary:
  // particle burst, ~700-800ms) and the UX guideline against continuous
  // decorative animation: this fires once per tap, not on a timer.
  late final _burstController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );

  @override
  void dispose() {
    _burstController.dispose();
    super.dispose();
  }

  void _onDialTap() {
    final wasShowing = _showMilestone;
    setState(() => _showMilestone = !_showMilestone);
    if (!wasShowing) _burstController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final kpis = ref.watch(parentKpiProvider);
    final dialSize = widget.wide ? 168.0 : 128.0;
    final nextMilestone = ((kpis.streak ~/ 5) + 1) * 5;
    final daysToGo = nextMilestone - kpis.streak;

    return SoftCard(
      padding: EdgeInsets.all(widget.wide ? 22 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _onDialTap,
                child: SizedBox(
                  width: dialSize,
                  height: dialSize,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      _AccuracyDial(
                        size: dialSize,
                        accuracyPct: kpis.accuracyPct,
                        streak: kpis.streak,
                      ),
                      IgnorePointer(
                        child: SizedBox(
                          width: dialSize * 1.7,
                          height: dialSize * 1.7,
                          child: Lottie.asset(
                            'assets/lottie/milestone_burst.json',
                            controller: _burstController,
                            onLoaded: (composition) {
                              _burstController.duration = composition.duration;
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: widget.wide ? 26 : 16),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _showProgressDetailsDialog(context, ref),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Column(
                      children: [
                        _StatPill(
                          iconPath: MockIcons.clock,
                          iconBg: AppColors.goldTint,
                          iconColor: AppColors.gold,
                          value: '${kpis.timeOnTaskMinutes}m',
                          label: 'Time on task',
                          trend: kpis.timeOnTaskTrend.text,
                          trendUp: kpis.timeOnTaskTrend.up,
                        ),
                        const SizedBox(height: 10),
                        _StatPill(
                          iconPath: MockIcons.warningTriangle,
                          iconBg: AppColors.coralTint,
                          iconColor: AppColors.coral,
                          value: '${kpis.errorCount}',
                          label: 'Errors',
                          trend: kpis.errorTrend.text,
                          trendUp: kpis.errorTrend.up,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              onPressed: () => _showProgressDetailsDialog(context, ref),
              icon: const Icon(
                Icons.analytics_outlined,
                size: 16,
                color: AppColors.teal,
              ),
              label: const Text(
                'View Detailed Progress Report',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.teal,
                ),
              ),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: !_showMilestone || kpis.streak == 0
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.mint,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        daysToGo <= 0
                            ? "Milestone reached — masha'Allah!"
                            : '$daysToGo more day${daysToGo == 1 ? '' : 's'} to unlock the $nextMilestone-day streak badge.',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.tealDark,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.iconPath,
    required this.iconBg,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.trend,
    required this.trendUp,
  });

  final String iconPath;
  final Color iconBg;
  final Color iconColor;
  final String value;
  final String label;
  final String trend;
  final bool trendUp;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.neutralTint,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: MockIcon(iconPath, size: 15, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(label, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
          if (trend.isNotEmpty)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                MockIcon(
                  trendUp ? MockIcons.trendUp : MockIcons.trendDown,
                  size: 10,
                  color: trendUp ? AppColors.teal : AppColors.coral,
                ),
                const SizedBox(width: 2),
                Text(
                  trend,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: trendUp ? AppColors.teal : AppColors.coral,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Telemetry Visualization component's per-adventure breakdown (FR-5.1) —
/// a ring-per-adventure grid (weakest accuracy first) plus, when the
/// Mediation Prompts Engine (FR-5.2) has flagged a real weak point, a
/// single "practice this at home" prescription for that adventure below.
class _AdventureBreakdownCard extends ConsumerWidget {
  const _AdventureBreakdownCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adventures = ref.watch(parentAdventureBreakdownProvider);
    final mediation = ref.watch(parentMediationPromptProvider);

    return SoftCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Adventures this week',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 2),
          const Text(
            'Progress by adventure, weakest first.',
            style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),
          if (adventures.isEmpty)
            const Text(
              'Complete a lesson in the Learner Hub to see per-adventure progress here.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
            )
          else
            Column(
              children: [
                for (final progress in adventures) ...[
                  _AdventureRingCard(progress: progress),
                  if (progress != adventures.last) const SizedBox(height: 8),
                ],
              ],
            ),
          if (mediation != null) ...[
            const SizedBox(height: 14),
            _MediationCard(prompt: mediation),
          ],
        ],
      ),
    );
  }
}

class _AdventureRingCard extends StatelessWidget {
  const _AdventureRingCard({required this.progress});

  final AdventureProgress progress;

  @override
  Widget build(BuildContext context) {
    final weak = progress.accuracyPct < 60;
    final ringColor = weak ? AppColors.coral : AppColors.teal;
    final pct = (progress.accuracyPct / 100).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.creamBorder),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: pct),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, t, _) => CircularProgressIndicator(
                    value: t,
                    strokeWidth: 5,
                    backgroundColor: AppColors.mint,
                    valueColor: AlwaysStoppedAnimation(ringColor),
                  ),
                ),
                Text(
                  '${progress.accuracyPct.round()}%',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: ringColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  progress.destination.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${progress.errorCount} error${progress.errorCount == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: pct),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (context, t, _) => LinearProgressIndicator(
                      value: t,
                      minHeight: 4,
                      backgroundColor: AppColors.mint,
                      valueColor: AlwaysStoppedAnimation(ringColor),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (weak) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.coralTint,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'NEEDS REVIEW',
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.coral,
                ),
              ),
            ),
          ],
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => _AdventureDetailScreen(progress: progress),
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'See detail',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: ringColor,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(Icons.chevron_right, size: 14, color: ringColor),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One tier of a destination's lessons — mirrors the 3-way split
/// `DestinationLevelsSheet._levels` uses in the Learner Hub (perLevel =
/// ceil(lessons.length / 3)), so the parent-facing level names/grouping
/// match what the child actually sees when playing.
class _AdventureLevelMeta {
  const _AdventureLevelMeta(this.stars, this.label, this.color, this.tint);
  final String stars;
  final String label;
  final Color color;
  final Color tint;
}

const _adventureLevelMeta = [
  _AdventureLevelMeta('⭐', 'Beginner', AppColors.teal, AppColors.mint),
  _AdventureLevelMeta('⭐⭐', 'Practice', AppColors.gold, AppColors.goldTint),
  _AdventureLevelMeta('⭐⭐⭐', 'Mastery', AppColors.coral, AppColors.coralTint),
];

List<List<Lesson>> _splitIntoLevels(List<Lesson> lessons) {
  final perLevel = (lessons.length / 3).ceil();
  return [
    lessons.take(perLevel).toList(),
    lessons.skip(perLevel).take(perLevel).toList(),
    lessons.skip(perLevel * 2).toList(),
  ].where((group) => group.isNotEmpty).toList();
}

/// Sequential level unlock, same rule `DestinationLevelsSheet` uses in the
/// Learner Hub: the whole destination must not be locked, level 0 is always
/// open, and every level after that opens once the previous one's lessons
/// are all completed. Doesn't account for a teacher's per-lesson
/// `maxLevel`/`maxLessons` assignment cap (that lives in a different data
/// source not wired into the parent dashboard) — this is the learner's own
/// unlock progress, which is what a parent is checking here.
bool _isLevelUnlocked(
  Destination destination,
  List<List<Lesson>> levels,
  int levelIndex,
  Set<String> completedLessons,
) {
  if (destination.state == DestinationState.locked) return false;
  if (levelIndex == 0) return true;
  final previous = levels[levelIndex - 1];
  return previous.every((l) => completedLessons.contains(l.id));
}

/// Comprehensive drill-down for one adventure — every level, and every game
/// inside every level, real curriculum data (`AdventureProgress.destination
/// .lessons[].activities[]`) with a real Done/Not-yet chip sourced from
/// [parentCompletedLessonsProvider]. Its own screen (pushed from "Adventures
/// this week") rather than a dialog — there's enough content (a header, a
/// hero stat block, and a scrolling list of levels/games) that it reads
/// better with full-screen room than squeezed into a `Dialog`.
class _AdventureDetailScreen extends ConsumerWidget {
  const _AdventureDetailScreen({required this.progress});

  final AdventureProgress progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completedLessons = ref.watch(parentCompletedLessonsProvider);
    final destination = progress.destination;
    final levels = _splitIntoLevels(destination.lessons);
    final totalLessons = destination.lessons.length;
    final doneLessons = destination.lessons
        .where((l) => completedLessons.contains(l.id))
        .length;
    final completionPct = totalLessons == 0
        ? 0
        : (doneLessons / totalLessons * 100).round();

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(4, 10, 18, 4),
              color: Colors.white,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.coralTint,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      destination.icon,
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ADVENTURE DETAIL',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: AppColors.textMuted,
                            ),
                          ),
                          Text(
                            destination.name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Redesigned Floating Stats Hero Card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.creamBorder),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0C20241F),
                    blurRadius: 30,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 76,
                    height: 76,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween(
                            begin: 0,
                            end: totalLessons == 0
                                ? 0
                                : doneLessons / totalLessons,
                          ),
                          duration: const Duration(milliseconds: 700),
                          curve: Curves.easeOutCubic,
                          builder: (context, t, _) => SizedBox(
                            width: 76,
                            height: 76,
                            child: CircularProgressIndicator(
                              value: t,
                              strokeWidth: 6,
                              backgroundColor: AppColors.mint,
                              valueColor: const AlwaysStoppedAnimation(
                                AppColors.teal,
                              ),
                            ),
                          ),
                        ),
                        Text(
                          '$completionPct%',
                          style: const TextStyle(
                            fontFamily: 'Outfit',
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: AppColors.teal,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _DetailStatRow(
                          value: '$doneLessons/$totalLessons',
                          label: 'lessons done',
                        ),
                        const SizedBox(height: 8),
                        _DetailStatRow(
                          value: '${progress.accuracyPct.round()}%',
                          label: 'accuracy',
                        ),
                        const SizedBox(height: 8),
                        _DetailStatRow(
                          value: '${progress.errorCount}',
                          label: 'errors logged',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Caveat footnote banner
            Container(
              margin: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.goldTint,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.goldSoft.withValues(alpha: 0.25),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ℹ️', style: TextStyle(fontSize: 12)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Tracked per lesson, not per game — every game a lesson "
                      "contains is listed for reference.",
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Levels
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: Column(
                  children: [
                    for (var li = 0; li < levels.length; li++) ...[
                      if (li > 0) const SizedBox(height: 16),
                      _AdventureLevelSection(
                        meta: _adventureLevelMeta[li < 2 ? li : 2],
                        lessons: levels[li],
                        completedLessons: completedLessons,
                        unlocked: _isLevelUnlocked(
                          destination,
                          levels,
                          li,
                          completedLessons,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailStatRow extends StatelessWidget {
  const _DetailStatRow({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Outfit',
            fontWeight: FontWeight.w800,
            fontSize: 17,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _AdventureLevelSection extends StatefulWidget {
  const _AdventureLevelSection({
    required this.meta,
    required this.lessons,
    required this.completedLessons,
    required this.unlocked,
  });

  final _AdventureLevelMeta meta;
  final List<Lesson> lessons;
  final Set<String> completedLessons;
  final bool unlocked;

  @override
  State<_AdventureLevelSection> createState() => _AdventureLevelSectionState();
}

class _AdventureLevelSectionState extends State<_AdventureLevelSection> {
  bool _isCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final done = widget.lessons
        .where((l) => widget.completedLessons.contains(l.id))
        .length;
    return Opacity(
      opacity: widget.unlocked ? 1 : 0.55,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.creamBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: widget.unlocked
                  ? () => setState(() => _isCollapsed = !_isCollapsed)
                  : null,
              child: Container(
                color: widget.meta.tint,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.meta.stars,
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            widget.meta.label,
                            style: TextStyle(
                              fontFamily: 'Fredoka',
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              color: widget.meta.color,
                            ),
                          ),
                        ),
                        if (!widget.unlocked)
                          const Icon(
                            Icons.lock,
                            size: 13,
                            color: AppColors.textMuted,
                          )
                        else ...[
                          Text(
                            '$done/${widget.lessons.length}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(width: 6),
                          AnimatedRotation(
                            turns: _isCollapsed ? -0.25 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              Icons.keyboard_arrow_down,
                              size: 16,
                              color: widget.meta.color,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 7),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(
                          begin: 0,
                          end: !widget.unlocked || widget.lessons.isEmpty
                              ? 0
                              : done / widget.lessons.length,
                        ),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutCubic,
                        builder: (context, t, _) => LinearProgressIndicator(
                          value: t,
                          minHeight: 5,
                          backgroundColor: Colors.black.withValues(alpha: 0.08),
                          valueColor: AlwaysStoppedAnimation(widget.meta.color),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!widget.unlocked)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                child: Row(
                  children: [
                    Icon(Icons.lock, size: 14, color: AppColors.textMuted),
                    SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Locked — finish the level above to unlock this one.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else if (!_isCollapsed)
              for (final lesson in widget.lessons)
                for (final activity in lesson.activities)
                  _AdventureGameRow(
                    lesson: lesson,
                    activity: activity,
                    done: widget.completedLessons.contains(lesson.id),
                  ),
          ],
        ),
      ),
    );
  }
}

/// Parent-friendly label for an [ActivityType] — the raw enum name
/// (`quranSync`, `fiqhDrag`) is camelCase code, not something to show a
/// parent.
String _activityTypeLabel(ActivityType type) => switch (type) {
  ActivityType.trace => 'Letter Tracing',
  ActivityType.pronounce => 'Pronunciation',
  ActivityType.quranSync => "Qur'an Sync",
  ActivityType.story => 'Story',
  ActivityType.fiqhDrag => 'Fiqh Match',
  ActivityType.quiz => 'Quiz',
  ActivityType.harakatPop => 'Harakat Pop',
  ActivityType.ayahBuilder => 'Ayah Builder',
  ActivityType.creationHunt => "Allah's Creation Hunt",
  ActivityType.classroomHeroes => 'Classroom Heroes',
  ActivityType.sirahStory => 'Sirah Story',
  ActivityType.quranEtiquette => "Qur'an Etiquette",
  ActivityType.fivePillars => 'The Five Pillars',
  ActivityType.goodDeedTree => 'The Good Deed Tree',
  ActivityType.taharahAdventure => 'Taharah Adventure',
};

class _AdventureGameRow extends StatelessWidget {
  const _AdventureGameRow({
    required this.lesson,
    required this.activity,
    required this.done,
  });

  final Lesson lesson;
  final Activity activity;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: done ? AppColors.mint.withValues(alpha: 0.5) : null,
        border: const Border(top: BorderSide(color: AppColors.creamBorder)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(activity.icon, style: const TextStyle(fontSize: 15)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${_activityTypeLabel(activity.type)} · +${activity.xp}xp',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (done)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.teal,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check, size: 10, color: Colors.white),
                  SizedBox(width: 3),
                  Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.creamBorder),
              ),
              child: const Text(
                'Not started',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MediationCard extends StatelessWidget {
  const _MediationCard({required this.prompt});

  final MediationPrompt prompt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.mintBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🖊️', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "This week's practice routine — ${prompt.destination.name}",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.tealDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            prompt.routine,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.tealDark,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated radial accuracy dial with a tappable streak badge notched onto
/// its top-right edge (tap toggles the milestone caption in [_KpiFocusRow]).
class _AccuracyDial extends StatelessWidget {
  const _AccuracyDial({
    required this.size,
    required this.accuracyPct,
    required this.streak,
  });

  final double size;
  final double accuracyPct;
  final int streak;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: (accuracyPct / 100).clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, t, _) => CustomPaint(
              size: Size(size, size),
              painter: _DialPainter(progress: t),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${accuracyPct.round()}%',
                style: TextStyle(
                  fontSize: size * 0.22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                'Accuracy',
                style: TextStyle(
                  fontSize: size * 0.09,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (streak > 0)
            Positioned(
              top: -4,
              right: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.bolt_rounded,
                      size: 12,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '$streak',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
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

class _DialPainter extends CustomPainter {
  _DialPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - 12) / 2;
    final track = Paint()
      ..color = AppColors.mint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);

    if (progress > 0) {
      final fill = Paint()
        ..shader = SweepGradient(
          startAngle: -pi / 2,
          endAngle: -pi / 2 + 2 * pi,
          colors: const [AppColors.teal, AppColors.gold, AppColors.teal],
          transform: const GradientRotation(-pi / 2),
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        2 * pi * progress,
        false,
        fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DialPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Draw-in line chart matching the approved top-tab mock exactly: grid +
/// gradient area fill + a teal line that draws itself in on every reveal
/// (fresh [_draw] controller each time this tab remounts), reading real
/// per-day activity from [parentWeeklyChartProvider] (no invented numbers).
class _TrendChartCard extends ConsumerStatefulWidget {
  const _TrendChartCard();

  @override
  ConsumerState<_TrendChartCard> createState() => _TrendChartCardState();
}

class _TrendChartCardState extends ConsumerState<_TrendChartCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _draw = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  )..forward();
  int _range = 0;

  static const _ranges = ['7 days', '30 days', 'Term'];
  // ponytail: "Term" has no curriculum-defined length yet, so it's
  // approximated as a 90-day window. Swap in the real academic-term length
  // once that's modeled.
  static const _rangeWindowDays = [7, 30, 90];

  @override
  void dispose() {
    _draw.dispose();
    super.dispose();
  }

  void _selectRange(int i) {
    if (i == _range) return;
    setState(() => _range = i);
    _draw
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    final chartData = ref.watch(
      parentWeeklyChartProvider(_rangeWindowDays[_range]),
    );
    final entries = chartData;

    return SoftCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const MockIcon(MockIcons.trend, size: 16, color: AppColors.teal),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  'Weekly trend',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          const Text(
            'Time spent playing, day by day',
            style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final (i, label) in _ranges.indexed) ...[
                if (i > 0) const SizedBox(width: 6),
                _RangePill(
                  label: label,
                  active: i == _range,
                  onTap: () => _selectRange(i),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: Column(
                  children: [
                    SizedBox(
                      width: 96,
                      height: 72,
                      child: Lottie.asset(
                        'assets/lottie/empty_chart.json',
                        repeat: true,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'No activity yet this week',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                const height = 116.0;
                const topPad = 20.0;
                const bottomPad = 8.0;
                final width = constraints.maxWidth;
                final values = entries.map((e) => e.value).toList();
                final n = values.length;
                final dx = n > 1 ? width / (n - 1) : 0.0;
                final points = [
                  for (var i = 0; i < n; i++)
                    Offset(
                      i * dx,
                      topPad + (1 - values[i]) * (height - topPad - bottomPad),
                    ),
                ];

                // Thin to at most 7 labels so a 30-day/Term window doesn't
                // crowd the axis — always keep the first and last day.
                const maxLabels = 7;
                final step = n > maxLabels ? (n / maxLabels).ceil() : 1;
                final labelIndices = <int>{
                  for (var i = 0; i < n; i += step) i,
                  if (n > 0) n - 1,
                }.toList()..sort();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedBuilder(
                      animation: _draw,
                      builder: (context, _) {
                        return CustomPaint(
                          size: Size(width, height),
                          painter: _TrendPainter(
                            points: points,
                            progress: _draw.value,
                            bottom: height - bottomPad,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 14,
                      width: width,
                      child: Stack(
                        children: [
                          for (final i in labelIndices)
                            Positioned(
                              left: (points[i].dx - 14).clamp(0.0, width - 28),
                              width: 28,
                              child: Text(
                                entries[i].label,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _RangePill extends StatelessWidget {
  const _RangePill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.teal : AppColors.neutralTint,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

/// Grid + gradient area fill + drawn line — matches the approved top-tab
/// mock's chart exactly (`.chart-grid` / `.chart-area` / `.chart-line`).
class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.points,
    required this.progress,
    required this.bottom,
  });

  final List<Offset> points;
  final double progress;
  final double bottom;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    // 1. Solid horizontal gridlines behind the curve.
    final gridPaint = Paint()
      ..color = AppColors.creamBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (var i = 1; i <= 3; i++) {
      final y = bottom * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 2. Straight-segment line (mock uses a plain polyline, not a spline).
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    final reveal = progress.clamp(0.0, 1.0);
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * reveal, size.height + 40));

    // 3. Gradient area fill, fading from the line down to the baseline.
    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, bottom)
      ..lineTo(points.first.dx, bottom)
      ..close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.teal.withValues(alpha: 0.16),
          AppColors.teal.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    // 4. The line itself.
    final linePaint = Paint()
      ..color = AppColors.teal
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.points != points;
}

class _SettingsTab extends ConsumerWidget {
  const _SettingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volumes = ref.watch(volumeProvider);
    final volumeNotifier = ref.read(volumeProvider.notifier);

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StaggerFadeIn(
              delay: const Duration(milliseconds: 25),
              child: SoftCard(
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
            ),
            const SizedBox(height: 20),
            const _StaggerFadeIn(
              delay: Duration(milliseconds: 65),
              child: _SyncCard(),
            ),
            const SizedBox(height: 20),
            const _StaggerFadeIn(
              delay: Duration(milliseconds: 80),
              child: EmailVerificationCard(),
            ),
            const SizedBox(height: 20),
            const _StaggerFadeIn(
              delay: Duration(milliseconds: 95),
              child: _LinkFirebaseCard(),
            ),
            const SizedBox(height: 20),
            const _StaggerFadeIn(
              delay: Duration(milliseconds: 125),
              child: _EraseCard(),
            ),
            const SizedBox(height: 20),
            const _StaggerFadeIn(
              delay: Duration(milliseconds: 155),
              child: _ExitSettingsCard(),
            ),
          ],
        ),
      ],
    );
  }
}

/// Tab-panel entrance used by the top-tab shell — matches the mock's
/// per-panel "rise" (fade + slide-up, 320ms, cubic-bezier(.2,.7,.3,1)).
/// Deliberately does NOT crossfade with the outgoing panel the way
/// `AnimatedSwitcher` does: when [Widget.key] changes (new tab selected),
/// the old panel's Element is disposed and removed from the tree
/// immediately — normal Flutter rebuild semantics, no exit transition —
/// and only the new panel plays this one-shot entrance. That's what the
/// mock does too (`panel.hidden = true` on the old one, then the new one
/// gets its `rise` animation) — an `AnimatedSwitcher` here would keep both
/// panels visible and overlapping for the transition's duration instead.
class _PanelRise extends StatefulWidget {
  const _PanelRise({super.key, required this.child});

  final Widget child;

  @override
  State<_PanelRise> createState() => _PanelRiseState();
}

class _PanelRiseState extends State<_PanelRise>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  )..forward();
  late final _curved = CurvedAnimation(
    parent: _c,
    curve: const Cubic(0.2, 0.7, 0.3, 1.0),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.03),
          end: Offset.zero,
        ).animate(_curved),
        child: widget.child,
      ),
    );
  }
}

/// Self-contained staggered entrance (fade + slide-up) — mirrors the
/// Teacher Dashboard's own `_StaggerFadeIn` (each file keeps its own copy,
/// same convention as `_FadeUp` already being duplicated per-dashboard-file).
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

/// Shown only when the active parent account registered without a
/// Firebase Auth link (offline registration, or the signup call failed
/// at the time — see `ParentRepository.register` doc). Lets the parent
/// re-enter their password to retry it, since the plaintext password is
/// never stored and can't be recovered any other way. Lives in the
/// Parent Dashboard's own Settings tab specifically — not the shared
/// `settings_screen.dart` reachable from the Student Hub, since linking
/// to the cloud is a parent/teacher-account concept, not a learner one.
class _LinkFirebaseCard extends ConsumerStatefulWidget {
  const _LinkFirebaseCard();

  @override
  ConsumerState<_LinkFirebaseCard> createState() => _LinkFirebaseCardState();
}

class _LinkFirebaseCardState extends ConsumerState<_LinkFirebaseCard> {
  final _passwordC = TextEditingController();
  bool _linking = false;
  bool _linked = false;
  bool _hasEmail = false;

  @override
  void initState() {
    super.initState();
    final notifier = ref.read(sessionProvider.notifier);
    _linked = notifier.activeAccountLinkedToFirebase;
    _hasEmail = notifier.activeAccountHasEmail;
  }

  @override
  void dispose() {
    _passwordC.dispose();
    super.dispose();
  }

  Future<void> _link() async {
    final password = _passwordC.text;
    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your account password')),
      );
      return;
    }
    setState(() => _linking = true);
    try {
      await ref
          .read(sessionProvider.notifier)
          .linkActiveAccountToFirebase(password);
      if (mounted) {
        setState(() {
          _linked = true;
          _linking = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Linked to cloud — sync now works for this account.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _linking = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Link failed: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // No email/password on this account (a bare PIN-only bootstrap — see
    // `activeAccountHasEmail`'s doc) means there's nothing to link; showing
    // this card would only ever produce "Incorrect password" no matter
    // what's typed in, since `verifyPassword` can never succeed against a
    // null hash.
    if (_linked || !_hasEmail) return const SizedBox.shrink();
    return SoftCard(
      color: AppColors.goldTint,
      borderColor: AppColors.goldSoft,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Link to Cloud', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          const Text(
            'This account isn\'t linked to the cloud yet, so "Sync now" '
            'won\'t work until you link it. Re-enter your password to link it.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordC,
            obscureText: true,
            decoration: const InputDecoration(
              hintText: 'Account password',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _linking ? null : _link,
              icon: _linking
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.link, size: 16),
              label: Text(_linking ? 'Linking...' : 'Link to Cloud'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
            ),
          ),
        ],
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
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.mint,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.sync_rounded,
              size: 18,
              color: AppColors.teal,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sync Now', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 2),
                const Text(
                  'Sync local device progress with cloud servers.',
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
              // the account — otherwise go_router's refreshListenable reacts
              // to that state change while still on `/parent`, transiently
              // redirecting to `/pin/setup` (see auth_loading_overlay.dart's
              // doc on `showAuthLoadingOverlay`).
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
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.coralTint,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.delete_outline_rounded,
              size: 18,
              color: AppColors.coral,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Erase Local Data',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 2),
                const Text(
                  'Permanently delete all stored profiles and progress data.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
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

class _ExitSettingsCard extends ConsumerWidget {
  const _ExitSettingsCard();

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: AppColors.coral,
          size: 40,
        ),
        title: const Text('Log out?'),
        content: const Text(
          'Are you sure you want to log out? You will need to sign in with your email and password again to access the Parent Dashboard next time.',
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
              // See the matching comment on the Erase button above.
              context.go('/roles');
              await runWithAuthLoadingOverlay(
                AuthLoadingAction.logout,
                () => ref.read(sessionProvider.notifier).logout(),
              );
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SoftCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: AppColors.coralTint,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.logout_rounded,
              color: AppColors.coral,
              size: 18,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Exit Settings',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
                Text(
                  'Exit settings and lock admin areas',
                  style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.coral,
              side: const BorderSide(color: AppColors.coral),
            ),
            onPressed: () => _confirmLogout(context, ref),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- progress details dialog

void _showProgressDetailsDialog(BuildContext context, WidgetRef ref) {
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Learning Progress Details',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (dialogContext, animation, secondaryAnimation) =>
        const _ParentStudentProgressDetailsDialog(),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _ParentStudentProgressDetailsDialog extends ConsumerWidget {
  const _ParentStudentProgressDetailsDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final learner = ref.watch(sessionProvider.select((s) => s.learner));
    final learnerId = learner?.id;
    final learnerName = learner?.name ?? 'your child';
    final learnerAvatar = learner?.avatar ?? '👦';
    final kpis = ref.watch(parentKpiProvider);

    if (learnerId == null) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'No active profile found. Please select a child profile.',
          ),
        ),
      );
    }

    final repo = ProgressRepository();
    final records = repo.byLearnerId(learnerId);
    final moduleSummaries = repo.summaryByModule(learnerId);

    String formatDate(DateTime dt) {
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      final minute = dt.minute.toString().padLeft(2, '0');
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year} $hour:$minute $ampm';
    }

    String getModuleTitle(String moduleId) {
      try {
        return coreModules.firstWhere((m) => m.id == moduleId).title;
      } catch (_) {
        return moduleId;
      }
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 680),
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.teal, AppColors.tealDark],
                  ),
                ),
                child: Row(
                  children: [
                    LearnerAvatar(avatar: learnerAvatar, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            learnerName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Learning Progress Report',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              // Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Overview Stats Row
                      Row(
                        children: [
                          Expanded(
                            child: _buildOverviewTile(
                              icon: Icons.check_circle_outline_rounded,
                              value: '${kpis.accuracyPct.round()}%',
                              label: 'Avg. Accuracy',
                              color: AppColors.teal,
                              bg: AppColors.mint,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildOverviewTile(
                              icon: Icons.error_outline_rounded,
                              value: '${kpis.errorCount}',
                              label: 'Total Errors',
                              color: AppColors.coral,
                              bg: AppColors.coralTint,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildOverviewTile(
                              icon: Icons.schedule_rounded,
                              value: '${kpis.timeOnTaskMinutes}m',
                              label: 'Time on Task',
                              color: AppColors.gold,
                              bg: AppColors.goldTint,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildOverviewTile(
                              icon: Icons.local_fire_department_rounded,
                              value: '${kpis.streak}d',
                              label: 'Active Streak',
                              color: Colors.orange,
                              bg: Colors.orange.withOpacity(0.1),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),

                      // Section: Adventure Mastery
                      const Text(
                        'ADVENTURE MASTERY',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textMuted,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (moduleSummaries.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.neutralTint,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'No adventure history yet.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                        )
                      else
                        ...moduleSummaries.map((mod) {
                          final title = getModuleTitle(mod.moduleId);
                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 8),
                            color: AppColors.neutralTint,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          title,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.ink,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '${mod.sessionCount} session${mod.sessionCount == 1 ? '' : 's'}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textMuted,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            99,
                                          ),
                                          child: TweenAnimationBuilder<double>(
                                            tween: Tween<double>(
                                              begin: 0.0,
                                              end: mod.accuracyPct / 100.0,
                                            ),
                                            duration: const Duration(
                                              milliseconds: 900,
                                            ),
                                            curve: Curves.easeOutCubic,
                                            builder: (context, val, child) {
                                              return LinearProgressIndicator(
                                                value: val,
                                                backgroundColor:
                                                    Colors.grey.shade200,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(
                                                      mod.accuracyPct >= 80
                                                          ? AppColors.teal
                                                          : (mod.accuracyPct >=
                                                                    60
                                                                ? AppColors.gold
                                                                : AppColors
                                                                      .coral),
                                                    ),
                                                minHeight: 6,
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        '${mod.accuracyPct.round()}% accuracy',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: mod.accuracyPct >= 80
                                              ? AppColors.tealDark
                                              : (mod.accuracyPct >= 60
                                                    ? AppColors.gold
                                                    : AppColors.coral),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (mod.errorCount > 0) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '${mod.errorCount} sequencing error${mod.errorCount == 1 ? '' : 's'} logged',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.coral,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }),
                      const SizedBox(height: 22),

                      // Section: Recent Activity
                      const Text(
                        'RECENT LESSONS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textMuted,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (records.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.neutralTint,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'No activities logged yet.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                        )
                      else
                        ...records.take(15).map((rec) {
                          final title = getModuleTitle(rec.moduleId);
                          final timeStr = formatDate(rec.completedAt);
                          final durationMin = (rec.timeOnTaskSeconds / 60.0)
                              .toStringAsFixed(1);
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.neutralTint,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.creamBorder.withOpacity(0.5),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        title,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.ink,
                                        ),
                                      ),
                                    ),
                                    if (rec.assignedByTeacher)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.teal.withOpacity(
                                            0.12,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: const Text(
                                          'HOMEWORK',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.tealDark,
                                            letterSpacing: 0.3,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      timeStr,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                    Text(
                                      '${durationMin}m on task',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 12, thickness: 0.5),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.check_circle_outline_rounded,
                                          size: 13,
                                          color: rec.strokeAccuracyPct >= 80
                                              ? AppColors.teal
                                              : (rec.strokeAccuracyPct >= 60
                                                    ? AppColors.gold
                                                    : AppColors.coral),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Accuracy: ${rec.strokeAccuracyPct.round()}%',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: rec.strokeAccuracyPct >= 80
                                                ? AppColors.tealDark
                                                : (rec.strokeAccuracyPct >= 60
                                                      ? AppColors.gold
                                                      : AppColors.coral),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.error_outline_rounded,
                                          size: 13,
                                          color: rec.sequencingErrors > 0
                                              ? AppColors.coral
                                              : AppColors.teal,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Errors: ${rec.sequencingErrors}',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700,
                                            color: rec.sequencingErrors > 0
                                                ? AppColors.coral
                                                : AppColors.tealDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
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

  Widget _buildOverviewTile({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required Color bg,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white24,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppColors.ink,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w600,
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
