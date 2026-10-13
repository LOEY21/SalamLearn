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
import '../../data/models/progress_record.dart';
import '../../data/remote/firestore_mirror.dart';
import '../../data/repositories/class_repository.dart';
import '../../logic/auth/session.dart';
import '../../logic/learner/unlock_rules.dart';
import '../../logic/parent/analytics_providers.dart';
import '../../logic/parent/children_providers.dart';
import '../../logic/parent/game_grades.dart';
import '../../logic/progress_providers.dart';
import '../../logic/settings/settings_providers.dart';
import '../../logic/sync/sync_manager.dart';
import '../../logic/teacher/teacher_providers.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_loading_overlay.dart';
import '../widgets/child_profile_form.dart';
import '../widgets/hub_kit.dart';
import '../settings/settings_screen.dart' show LanguageSettingRow;
import '../widgets/change_pin_card.dart';
import '../widgets/email_verification_card.dart';
import '../widgets/learner_avatar.dart';
import '../widgets/locked_tag.dart';
import '../widgets/mock_icons.dart';
import '../widgets/account_email_card.dart';
import '../settings/account_security_screen.dart' show AccountSecurityRow;
import '../settings/change_password_screen.dart' show ChangePasswordRow;
import '../settings/personal_info_screen.dart' show PersonalInfoRow;
import '../widgets/soft_card.dart';
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
String _parentGreeting(WidgetRef ref) {
  // Watched so a name edited in Settings → Personal information shows
  // here straight away.
  ref.watch(sessionProvider);
  final parentName = ref.read(sessionProvider.notifier).activeParentFullName;
  if (parentName == null || parentName.isEmpty) return "Assalamu'alaikum";
  return "Assalamu'alaikum, $parentName";
}

/// Header title per tab — the Progress tab keeps the child-focused heading,
/// the other two name what the tab is for instead of repeating it.
String _tabHeading(int tab, String name) => switch (tab) {
  0 => _progressHeading(name),
  1 => 'Family & profile',
  _ => 'Settings',
};

/// Display face for the Parent Hub's headings and numbers — shared with
/// the child profile forms (see `child_profile_form.dart`).
const _display = displayText;

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
    ref.listen(parentProgressSyncProvider, (_, _) {});

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

  static const _tabs = <HubTab>[
    (iconPath: MockIcons.progress, label: 'Progress'),
    (iconPath: MockIcons.profile, label: 'Profile'),
    (iconPath: MockIcons.settings, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final learner = ref.watch(sessionProvider.select((s) => s.learner));

    return HubShell(
      header: HubHeader(
        fade: greet,
        leading: LearnerAvatar(avatar: learner?.avatar ?? '🧒', size: 42),
        onLeadingTap: () => _switchTab(0),
        greeting: _parentGreeting(ref),
        title: _tabHeading(_currentTab, widget.name),
        statusLabel: _syncStatusLabel(ref),
        tabs: _tabs,
        activeTab: _currentTab,
        onTabChanged: _switchTab,
        onSwitchUser: () => _switchUser(context, ref),
      ),
      panelKey: ValueKey(_currentTab),
      panel: switch (_currentTab) {
        0 => HubTabBody(
          left: [
            _JoinClassReminder(onJoin: () => _switchTab(1)),
            const HubStaggerFadeIn(delay: Duration.zero, child: _KpiFocusRow()),
            const SizedBox(height: 16),
            const HubStaggerFadeIn(
              delay: Duration(milliseconds: 35),
              child: _PracticeNote(),
            ),
          ],
          right: const [
            HubStaggerFadeIn(
              delay: Duration(milliseconds: 70),
              child: _AdventureBreakdownCard(),
            ),
            SizedBox(height: 16),
            HubStaggerFadeIn(
              delay: Duration(milliseconds: 105),
              child: _TrendChartCard(),
            ),
          ],
        ),
        1 => HubTabBody(
          left: [
            HubStaggerFadeIn(
              delay: Duration.zero,
              child: _ChildSwitcher(onSwitched: () => _switchTab(0)),
            ),
            const HubStaggerFadeIn(
              delay: Duration(milliseconds: 30),
              child: _NoProfileEmptyState(),
            ),
            const HubStaggerFadeIn(
              delay: Duration(milliseconds: 50),
              child: _ManageProfileCard(),
            ),
            const _UnlinkedLearnersCard(),
          ],
          right: const [
            HubStaggerFadeIn(
              delay: Duration(milliseconds: 80),
              child: _ClassSection(),
            ),
            HubStaggerFadeIn(
              delay: Duration(milliseconds: 110),
              child: HubSectionLabel('More for your family'),
            ),
            HubStaggerFadeIn(
              delay: Duration(milliseconds: 130),
              child: SoftCard(
                radius: 20,
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    _CreateNewProfileCard(),
                    HubRowDivider(),
                    _SyncProfileCard(),
                  ],
                ),
              ),
            ),
          ],
        ),
        _ => const _SettingsTab(),
      },
    );
  }
}

const _scaledWidth = scaledExtent;

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const HubSectionLabel('Your children'),
        // Wraps onto extra lines rather than scrolling sideways, so every
        // child is visible at once on any width.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final child in children)
              Builder(
                builder: (context) {
                  final isActive = child.id == activeId;
                  return Material(
                    color: isActive ? AppColors.teal : AppColors.surface,
                    shape: StadiumBorder(
                      side: BorderSide(
                        color: isActive
                            ? AppColors.teal
                            : AppColors.creamBorder,
                      ),
                    ),
                    child: InkWell(
                      customBorder: const StadiumBorder(),
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
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(6, 6, 16, 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            LearnerAvatar(avatar: child.avatar, size: 38),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                child.name,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: isActive
                                      ? Colors.white
                                      : AppColors.ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
        const SizedBox(height: 16),
      ],
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SoftCard(
        radius: 20,
        padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 24),
        child: Column(
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: Lottie.asset('assets/lottie/add_profile.json'),
            ),
            const SizedBox(height: 6),
            Text('No child profile yet', style: _display(20)),
            const SizedBox(height: 6),
            const Text(
              "Add your child's profile below to start tracking their "
              'learning journey.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.inkSoft,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ),
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
    // Once the child is in an active class, the profile is locked to the
    // teacher's roster — an archived class frees it up again.
    final section = learner.id == null
        ? null
        : ref.watch(learnerClassProvider(learner.id!));
    final enrolled = section != null && !section.isArchived;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SoftCard(
        radius: 20,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final small = _scaledWidth(context, constraints.maxWidth) < 300;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: AppColors.goldTint,
                        shape: BoxShape.circle,
                      ),
                      child: LearnerAvatar(
                        avatar: learner.avatar,
                        size: small ? 46 : 60,
                      ),
                    ),
                    SizedBox(width: small ? 12 : 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          LayoutBuilder(
                            builder: (context, nameBox) => Text(
                              learner.name,
                              style: fitLongestWord(
                                context,
                                learner.name,
                                _display(small ? 20 : 24, weight: 800),
                                nameBox.maxWidth,
                              ),
                            ),
                          ),
                          Text(
                            'Child profile · Age ${learner.age} · ${learner.gradeLevel}',
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: AppColors.inkSoft,
                            ),
                          ),
                          // Under the name rather than beside it, so a long
                          // name never has to share its line with a button.
                          if (!enrolled)
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.teal,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 0,
                                  vertical: 4,
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              onPressed: () => context.go('/parent/edit-child'),
                              icon: const Icon(Icons.edit_outlined, size: 17),
                              label: const Text('Edit'),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
            // The ID a teacher asks for to enroll this child.
            if (learner.studentId != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
                decoration: BoxDecoration(
                  color: AppColors.neutralTint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Student ID',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.inkSoft,
                            ),
                          ),
                          HubFitText(
                            learner.studentId!,
                            style: _display(
                              18,
                              weight: 700,
                            ).copyWith(letterSpacing: 1.2),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copy Student ID'.tr,
                      iconSize: 18,
                      color: AppColors.teal,
                      icon: const Icon(Icons.copy_rounded),
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: learner.studentId!),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Student ID copied')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.ink,
              ),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Open Learner Hub'),
              onPressed: () {
                ref.read(sessionProvider.notifier).selectRole(UserRole.learner);
                context.go('/hub');
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Lets a parent explicitly attach profiles saved by the old standalone
/// Learner signup flow on this device.
class _UnlinkedLearnersCard extends ConsumerWidget {
  const _UnlinkedLearnersCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(unlinkedLearnersProvider);
    if (profiles.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SoftCard(
        radius: 20,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Existing child profiles', style: _display(18)),
            const SizedBox(height: 4),
            const Text(
              'Add a child profile saved on this device to your account.',
              style: TextStyle(fontSize: 13.5, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 12),
            for (final profile in profiles)
              if (profile.id != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      LearnerAvatar(avatar: profile.avatar, size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          profile.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: const Text('Add child to your account?'),
                              content: Text(
                                '${profile.name} and their learning progress '
                                'will be linked to your parent account.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.pop(dialogContext, true),
                                  child: const Text('Add child'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed != true || !context.mounted) return;
                          try {
                            await ref
                                .read(sessionProvider.notifier)
                                .attachUnlinkedLearner(profile.id!);
                          } catch (error) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(
                                context,
                              ).showSnackBar(SnackBar(content: Text('$error')));
                            }
                          }
                        },
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

/// Progress-tab nudge while the selected child has no class: their games
/// are still saved (progress belongs to the child, not a class), but no
/// teacher can follow along until a class code is entered on the Profile
/// tab's [_ClassSection].
class _JoinClassReminder extends ConsumerWidget {
  const _JoinClassReminder({required this.onJoin});

  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final learnerId = ref.watch(sessionProvider.select((s) => s.learner?.id));
    if (learnerId == null) return const SizedBox.shrink();
    final section = ref.watch(learnerClassProvider(learnerId));
    if (section != null && !section.isArchived) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SoftCard(
        key: const ValueKey('join-class-reminder'),
        radius: 20,
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const MockIcon(
              MockIcons.classBadge,
              color: AppColors.teal,
              size: 26,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Not in a class yet', style: _display(16)),
                  const SizedBox(height: 4),
                  const Text(
                    "Games played are still saved. Join your child's class "
                    'so their teacher can follow their progress too.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.teal,
                foregroundColor: Colors.white,
                minimumSize: const Size(72, 44),
              ),
              onPressed: onJoin,
              child: const Text('Join'),
            ),
          ],
        ),
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SoftCard(
        radius: 20,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Class', style: _display(18)),
            const SizedBox(height: 10),
            if (section != null) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: section.isArchived
                      ? AppColors.neutralTint
                      : AppColors.mint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    section.isArchived
                        ? const Icon(
                            Icons.archive_outlined,
                            color: AppColors.inkSoft,
                            size: 20,
                          )
                        : const MockIcon(
                            MockIcons.classBadge,
                            color: AppColors.teal,
                            size: 20,
                          ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        section.isArchived
                            ? "${section.name} has been archived by the teacher"
                            : '${learner.name} is enrolled in ${section.name}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: section.isArchived
                              ? AppColors.inkSoft
                              : AppColors.tealDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (section.isArchived) ...[
                const SizedBox(height: 10),
                const Text(
                  'This class is no longer active. Enter a new invitation '
                  'code below to join a different class.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ] else ...[
              const Text(
                "Not in a class yet. Enter the invitation code your child's "
                'teacher shared with you.',
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  color: AppColors.inkSoft,
                ),
              ),
            ],
            if (section == null || section.isArchived) ...[
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final joinButton = ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.teal,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(72, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
                  );
                  final input = _Input(
                    controller: _codeC,
                    label: 'Invitation code',
                  );
                  // Field and button side by side when there's room; stacked
                  // full-width on narrow screens or with large text.
                  if (_scaledWidth(context, constraints.maxWidth) < 280) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [input, const SizedBox(height: 10), joinButton],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: input),
                      const SizedBox(width: 10),
                      joinButton,
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CreateNewProfileCard extends StatelessWidget {
  const _CreateNewProfileCard();

  @override
  Widget build(BuildContext context) {
    return HubActionRow(
      icon: Icons.person_add_alt_1_rounded,
      iconColor: AppColors.gold,
      title: 'Create New Profile',
      subtitle:
          'Set up a new learning journey for another child on this device.',
      trailing: HubRowButton(
        label: 'Add',
        onPressed: () => context.go('/learner-setup?from=parent'),
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
    return HubActionRow(
      icon: Icons.cloud_sync_outlined,
      title: 'Synchronize Data',
      subtitle: 'Backup and sync progress data with the cloud server.',
      trailing: HubRowButton(
        label: 'Sync',
        busy: _syncing,
        onPressed: () async {
          setState(() => _syncing = true);
          try {
            await ref.read(syncManagerProvider).syncNow();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Profile progress synchronized!')),
              );
            }
          } catch (error) {
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Sync failed: $error')));
            }
          } finally {
            if (mounted) setState(() => _syncing = false);
          }
        },
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
        borderRadius: BorderRadius.circular(12),
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
            color: AppColors.inkSoft,
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
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.creamBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.creamBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.teal, width: 1.6),
          ),
        ),
      ),
    );
  }
}
// ------------------------------------------------------------- shared

class _KpiFocusRow extends ConsumerStatefulWidget {
  const _KpiFocusRow();

  @override
  ConsumerState<_KpiFocusRow> createState() => _KpiFocusRowState();
}

/// "This week at a glance" sheet: the accuracy dial as the one focal
/// number (streak notched onto it), time and errors as a ruled list beside
/// it, and the full-report link as the sheet's footer row.
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
    const dialSize = 132.0;
    final nextMilestone = ((kpis.streak ~/ 5) + 1) * 5;
    final daysToGo = nextMilestone - kpis.streak;

    return SoftCard(
      radius: 20,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Text('This week at a glance', style: _display(18)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 20, 18),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final dial = Semantics(
                  button: true,
                  label: 'Show streak milestone',
                  child: GestureDetector(
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
                            child: ListenableBuilder(
                              listenable: _burstController,
                              builder: (context, child) => Visibility(
                                visible: _burstController.isAnimating,
                                maintainState: true,
                                child: child!,
                              ),
                              child: SizedBox(
                                width: dialSize * 1.7,
                                height: dialSize * 1.7,
                                child: Lottie.asset(
                                  'assets/lottie/milestone_burst.json',
                                  controller: _burstController,
                                  onLoaded: (composition) {
                                    _burstController.duration =
                                        composition.duration;
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
                final stats = [
                  _StatPill(
                    iconPath: MockIcons.clock,
                    iconColor: AppColors.gold,
                    value: '${kpis.timeOnTaskMinutes}m',
                    label: 'Time on task',
                    trend: kpis.timeOnTaskTrend.text,
                    trendUp: kpis.timeOnTaskTrend.up,
                  ),
                  _StatPill(
                    iconPath: MockIcons.warningTriangle,
                    iconColor: AppColors.coral,
                    value: '${kpis.errorCount}',
                    label: 'Errors',
                    trend: kpis.errorTrend.text,
                    trendUp: kpis.errorTrend.up,
                  ),
                ];
                Widget tappable(Widget child) => GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _showProgressDetailsDialog(context, ref),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: child,
                  ),
                );
                // Narrow (small phone or large text): dial on top, the two
                // stats side by side underneath, so neither gets squeezed.
                if (_scaledWidth(context, constraints.maxWidth) < 340) {
                  return Column(
                    children: [
                      Center(child: dial),
                      const SizedBox(height: 16),
                      tappable(
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: stats[0]),
                            const SizedBox(width: 16),
                            Expanded(child: stats[1]),
                          ],
                        ),
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    dial,
                    const SizedBox(width: 18),
                    Expanded(
                      child: tappable(
                        Column(
                          children: [
                            stats[0],
                            const Divider(
                              height: 20,
                              color: AppColors.creamBorder,
                            ),
                            stats[1],
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutQuart,
            alignment: Alignment.topCenter,
            child: !_showMilestone || kpis.streak == 0
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.goldTint,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        daysToGo <= 0
                            ? "Milestone reached — masha'Allah!"
                            : '$daysToGo more day${daysToGo == 1 ? '' : 's'} to unlock the $nextMilestone-day streak badge.',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                  ),
          ),
          const Divider(height: 1, color: AppColors.creamBorder),
          InkWell(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(20),
            ),
            onTap: () => _showProgressDetailsDialog(context, ref),
            child: const Padding(
              padding: EdgeInsets.fromLTRB(20, 15, 16, 15),
              child: Row(
                children: [
                  Icon(Icons.insights_rounded, size: 20, color: AppColors.teal),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'View Detailed Progress Report',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.teal,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: AppColors.teal,
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

/// One ruled line of the glance sheet: small colored icon + label above,
/// the value in the display face, and the week-over-week trend on the right.
class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.iconPath,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.trend,
    required this.trendUp,
  });

  final String iconPath;
  final Color iconColor;
  final String value;
  final String label;
  final String trend;
  final bool trendUp;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  MockIcon(iconPath, size: 14, color: iconColor),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              // Wrap: the trend drops under the value when there's no room
              // beside it, instead of squeezing the label.
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  Text(value, style: _display(26, weight: 800, height: 1.1)),
                  if (trend.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          MockIcon(
                            trendUp ? MockIcons.trendUp : MockIcons.trendDown,
                            size: 12,
                            color: trendUp ? AppColors.teal : AppColors.coral,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            trend,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: trendUp ? AppColors.teal : AppColors.coral,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// FR-5.2's Mediation Prompts Engine output, promoted to its own note right
/// under the glance sheet — it's the one actionable thing on this tab, so
/// it shouldn't sit at the bottom of the adventure list. Self-hiding when
/// nothing has been flagged yet.
class _PracticeNote extends ConsumerWidget {
  const _PracticeNote();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mediation = ref.watch(parentMediationPromptProvider);
    if (mediation == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _MediationCard(prompt: mediation),
    );
  }
}

/// Telemetry Visualization component's per-adventure breakdown (FR-5.1) —
/// one divided list (weakest accuracy first), each row opening that
/// adventure's full detail screen.
class _AdventureBreakdownCard extends ConsumerWidget {
  const _AdventureBreakdownCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final adventures = ref.watch(parentAdventureBreakdownProvider);

    return SoftCard(
      radius: 20,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Adventures this week', style: _display(18)),
                const SizedBox(height: 2),
                const Text(
                  'Progress by adventure, weakest first.',
                  style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
          if (adventures.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Text(
                'Complete a lesson in the Learner Hub to see per-adventure progress here.',
                style: TextStyle(
                  color: AppColors.inkSoft,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            )
          else ...[
            const SizedBox(height: 6),
            for (final (i, progress) in adventures.indexed) ...[
              if (i > 0) const HubRowDivider(),
              _AdventureRingCard(
                progress: progress,
                isLast: i == adventures.length - 1,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _AdventureRingCard extends StatelessWidget {
  const _AdventureRingCard({required this.progress, required this.isLast});

  final AdventureProgress progress;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final weak = progress.accuracyPct < 60;
    final color = weak ? AppColors.coral : AppColors.teal;
    final pct = (progress.accuracyPct / 100).clamp(0.0, 1.0);
    final errors =
        '${progress.errorCount} error${progress.errorCount == 1 ? '' : 's'}';
    return InkWell(
      borderRadius: isLast
          ? const BorderRadius.vertical(bottom: Radius.circular(20))
          : null,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _AdventureDetailScreen(progress: progress),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = _scaledWidth(context, constraints.maxWidth) < 300;
            final percent = '${progress.accuracyPct.round()}%';
            return Row(
              children: [
                if (!compact) ...[
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: weak ? AppColors.coralTint : AppColors.mint,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      progress.destination.icon,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Expanded(
                            child: Text(
                              progress.destination.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                          if (!compact) ...[
                            const SizedBox(width: 8),
                            Text(
                              percent,
                              style: _display(17, weight: 800, color: color),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: pct),
                          duration: const Duration(milliseconds: 700),
                          curve: Curves.easeOutQuart,
                          builder: (context, t, _) => LinearProgressIndicator(
                            value: t,
                            minHeight: 6,
                            backgroundColor: weak
                                ? AppColors.coralTint
                                : AppColors.mint,
                            valueColor: AlwaysStoppedAnimation(color),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        [
                          if (compact) percent,
                          weak
                              ? 'Needs review · $errors'
                              : '$errors · See detail',
                        ].join(' · '),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: weak ? FontWeight.w700 : FontWeight.w500,
                          color: weak ? AppColors.coral : AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
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
/// Learner Hub: the stage must be unlocked ([isStageUnlocked]), level 0 is always
/// open, and every level after that opens once the previous one's lessons
/// are all completed. Doesn't account for a teacher's per-lesson
/// `maxLevel`/`maxLessons` assignment cap (that lives in a different data
/// source not wired into the parent dashboard) — this is the learner's own
/// unlock progress, which is what a parent is checking here.
bool _isLevelUnlocked(
  String? learnerId,
  Destination destination,
  List<List<Lesson>> levels,
  int levelIndex,
  Set<String> completedLessons,
) {
  return true;
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
    final results = ref.watch(parentGameResultsProvider);
    final learnerName =
        ref.watch(sessionProvider.select((s) => s.learner?.name)) ??
        'Your child';
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
                          Text(destination.name, style: _display(21)),
                          const Text(
                            'Adventure detail',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                child: Column(
                  children: [
                    // Summary card
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
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
                                    fontFamily: 'Baloo2Var',
                                    fontVariations: [
                                      FontVariation('wght', 800),
                                    ],
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
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.goldTint,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.goldSoft.withValues(alpha: 0.25),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.touch_app_outlined,
                            size: 18,
                            color: AppColors.inkSoft,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Tap a finished game to see its grade, what it '
                              'practises, and feedback.',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: AppColors.inkSoft,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Levels
                    for (var li = 0; li < levels.length; li++) ...[
                      if (li > 0) const SizedBox(height: 16),
                      _AdventureLevelSection(
                        meta: _adventureLevelMeta[li < 2 ? li : 2],
                        lessons: levels[li],
                        completedLessons: completedLessons,
                        results: results,
                        learnerName: learnerName,
                        lockedMessage: li == 0
                            ? 'Locked — finish the stage before this one to unlock it.'
                            : 'Locked — finish the level above to unlock this one.',
                        unlocked: _isLevelUnlocked(
                          ref.watch(
                            sessionProvider.select((s) => s.learner?.id),
                          ),
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
    // Wrap: the label drops under the number when they don't fit side by
    // side (narrow phone / large text) instead of breaking the word.
    return Wrap(
      spacing: 6,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: 'Baloo2Var',
            fontVariations: [FontVariation('wght', 800)],
            fontWeight: FontWeight.w800,
            fontSize: 17,
            color: AppColors.ink,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: AppColors.inkSoft,
            ),
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
    required this.results,
    required this.learnerName,
    required this.unlocked,
    required this.lockedMessage,
  });

  final _AdventureLevelMeta meta;
  final List<Lesson> lessons;
  final Set<String> completedLessons;
  final Map<String, ProgressRecord> results;
  final String learnerName;
  final bool unlocked;
  final String lockedMessage;

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
                              fontFamily: 'Baloo2Var',
                              fontVariations: [FontVariation('wght', 700)],
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
                            color: AppColors.inkSoft,
                          )
                        else ...[
                          Text(
                            '$done/${widget.lessons.length}',
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.inkSoft,
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
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock, size: 14, color: AppColors.inkSoft),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        widget.lockedMessage,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.inkSoft,
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
                    record: widget.results[lesson.id],
                    learnerName: widget.learnerName,
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
  ActivityType.trace => 'Magic Sand Tracer',
  ActivityType.pronounce => 'The Greeting Match',
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
  ActivityType.labelMaker => 'Label Maker',
  ActivityType.soundDetective => 'Sound Detective',
};

class _AdventureGameRow extends StatelessWidget {
  const _AdventureGameRow({
    required this.lesson,
    required this.activity,
    required this.done,
    required this.record,
    required this.learnerName,
  });

  final Lesson lesson;
  final Activity activity;
  final bool done;
  final ProgressRecord? record;
  final String learnerName;

  @override
  Widget build(BuildContext context) {
    final record = this.record;
    return InkWell(
      onTap: record == null
          ? null
          : () => _showGameReport(
              context,
              title: activity.title,
              icon: activity.icon,
              type: activity.type,
              record: record,
              learnerName: learnerName,
            ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: done ? AppColors.mint.withValues(alpha: 0.5) : null,
          border: const Border(top: BorderSide(color: AppColors.creamBorder)),
        ),
        child: _RowWithStatus(
          leading: Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(activity.icon, style: const TextStyle(fontSize: 15)),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                activity.title,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                record == null
                    ? '${_activityTypeLabel(activity.type)} · +${activity.xp}xp'
                    : '${_activityTypeLabel(activity.type)} · Tap for feedback',
                style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
              ),
            ],
          ),
          trailingIcon: record == null
              ? null
              : const Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: AppColors.inkSoft,
                ),
          status: record != null
              ? _GradeChip(scorePct: record.strokeAccuracyPct)
              : done
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.teal,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check, size: 12, color: Colors.white),
                      SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          'Done',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.creamBorder),
                  ),
                  child: const Text(
                    'Not started',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

/// A list row's text plus a trailing status chip (grade, Done, Locked…).
/// The chip sits on the right when there's room, and drops under the text
/// on narrow screens or with large system text, so the title never gets
/// squeezed into mid-word breaks.
class _RowWithStatus extends StatelessWidget {
  const _RowWithStatus({
    required this.body,
    required this.status,
    this.leading,
    this.trailingIcon,
  });

  final Widget? leading;
  final Widget body;
  final Widget status;
  final Widget? trailingIcon;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = _scaledWidth(context, constraints.maxWidth) < 330;
        return Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 10)],
            Expanded(
              child: compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [body, const SizedBox(height: 6), status],
                    )
                  : body,
            ),
            if (!compact) ...[
              const SizedBox(width: 8),
              Flexible(child: status),
            ],
            ?trailingIcon,
          ],
        );
      },
    );
  }
}

/// Equal-width tiles that fit as many per row as [minTileWidth] (scaled
/// by the system text size) allows — 3 or 2 across on most phones, 1 on
/// the narrowest screens or with very large text.
class _AdaptiveTiles extends StatelessWidget {
  const _AdaptiveTiles({required this.children, required this.minTileWidth});

  final List<Widget> children;
  final double minTileWidth;

  @override
  Widget build(BuildContext context) {
    const gap = 8.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 3.0);
        final perRow =
            ((constraints.maxWidth + gap) / (minTileWidth * scale + gap))
                .floor()
                .clamp(1, children.length);
        final width = (constraints.maxWidth - gap * (perRow - 1)) / perRow;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

// ------------------------------------------------------------- per-game grades

Color _gradeColor(GradeBand band) => switch (band) {
  GradeBand.outstanding || GradeBand.verySatisfactory => AppColors.teal,
  GradeBand.satisfactory || GradeBand.fairlySatisfactory => AppColors.gold,
  GradeBand.needsPractice => AppColors.coral,
};

Color _gradeTint(GradeBand band) => switch (band) {
  GradeBand.outstanding || GradeBand.verySatisfactory => AppColors.mint,
  GradeBand.satisfactory || GradeBand.fairlySatisfactory => AppColors.goldTint,
  GradeBand.needsPractice => AppColors.coralTint,
};

const _monthNames = [
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

String _shortDate(DateTime dt) =>
    '${_monthNames[dt.month - 1]} ${dt.day}, ${dt.year}';

/// "92% · Outstanding" pill, colored by grade.
class _GradeChip extends StatelessWidget {
  const _GradeChip({required this.scorePct});

  final double scorePct;

  @override
  Widget build(BuildContext context) {
    final band = GradeBand.forScore(scorePct);
    final color = _gradeColor(band);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _gradeTint(band),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: HubFitText(
        '${scorePct.round()}% · ${band.label}',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color:
              band == GradeBand.satisfactory ||
                  band == GradeBand.fairlySatisfactory
              ? AppColors.ink
              : color,
        ),
      ),
    );
  }
}

/// Full report for one game attempt: score + grade, mistakes, time, date,
/// what the game practises, written feedback, and a home tip. [type] is
/// null for classroom Hot Seat records, which aren't a curriculum game.
void _showGameReport(
  BuildContext context, {
  required String title,
  required String icon,
  required ActivityType? type,
  required ProgressRecord record,
  required String learnerName,
  String? subtitle,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _GameReportSheet(
      title: title,
      icon: icon,
      type: type,
      record: record,
      learnerName: learnerName,
      subtitle: subtitle,
    ),
  );
}

class _GameReportSheet extends StatelessWidget {
  const _GameReportSheet({
    required this.title,
    required this.icon,
    required this.type,
    required this.record,
    required this.learnerName,
    this.subtitle,
  });

  final String title;
  final String icon;
  final ActivityType? type;
  final ProgressRecord record;
  final String learnerName;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final score = record.strokeAccuracyPct;
    final band = GradeBand.forScore(score);
    final color = _gradeColor(band);
    final type = this.type;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.creamBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.cream,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(icon, style: const TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'Baloo2Var',
                          fontVariations: [FontVariation('wght', 700)],
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        subtitle ??
                            (type == null
                                ? 'Classroom activity'
                                : _activityTypeLabel(type)),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Score + grade
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _gradeTint(band),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 72,
                          height: 72,
                          child: CircularProgressIndicator(
                            value: (score / 100).clamp(0.0, 1.0),
                            strokeWidth: 6,
                            backgroundColor: Colors.white,
                            valueColor: AlwaysStoppedAnimation(color),
                          ),
                        ),
                        Text(
                          '${score.round()}%',
                          style: const TextStyle(
                            fontFamily: 'Baloo2Var',
                            fontVariations: [FontVariation('wght', 800)],
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                            color: AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Grade',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.inkSoft,
                          ),
                        ),
                        Text(
                          band.label,
                          style: const TextStyle(
                            fontFamily: 'Baloo2Var',
                            fontVariations: [FontVariation('wght', 700)],
                            fontWeight: FontWeight.w700,
                            fontSize: 19,
                            color: AppColors.ink,
                          ),
                        ),
                        Text(
                          'Score ${score.round()} out of 100',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _AdaptiveTiles(
              minTileWidth: 104,
              children: [
                _ReportStat(
                  label: 'Mistakes',
                  value: '${record.sequencingErrors}',
                ),
                _ReportStat(
                  label: 'Time spent',
                  value: formatDuration(record.timeOnTaskSeconds),
                ),
                _ReportStat(
                  label: 'Played on',
                  value: _shortDate(record.completedAt),
                ),
              ],
            ),
            if (record.assignedByTeacher) ...[
              const SizedBox(height: 8),
              const Text(
                'Assigned by the teacher.',
                style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
              ),
            ],
            if (type != null) ...[
              const SizedBox(height: 16),
              _ReportSection(
                heading: 'What this game practises',
                body: gameSkill(type),
              ),
            ],
            const SizedBox(height: 12),
            _ReportSection(
              heading: 'Feedback',
              body: gameFeedback(
                scorePct: score,
                mistakes: record.sequencingErrors,
                name: learnerName,
              ),
              tint: _gradeTint(band),
            ),
            if (type != null) ...[
              const SizedBox(height: 12),
              _ReportSection(
                heading: 'Try at home',
                body: gameHomeTip(type),
                tint: AppColors.cream,
              ),
            ],
            const SizedBox(height: 16),
            _GradeScaleLegend(current: band),
          ],
        ),
      ),
    );
  }
}

class _ReportStat extends StatelessWidget {
  const _ReportStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.creamBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontFamily: 'Baloo2Var',
              fontVariations: [FontVariation('wght', 800)],
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: AppColors.ink,
            ),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }
}

class _ReportSection extends StatelessWidget {
  const _ReportSection({
    required this.heading,
    required this.body,
    this.tint = Colors.white,
  });

  final String heading;
  final String body;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.creamBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// The five-band scale, with [current] highlighted when given.
class _GradeScaleLegend extends StatelessWidget {
  const _GradeScaleLegend({this.current});

  final GradeBand? current;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.creamBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How grades work',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          for (final band in GradeBand.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _gradeColor(band),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: HubFitText(
                      band.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: band == current
                            ? FontWeight.w800
                            : FontWeight.w500,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  Text(
                    band.range,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: band == current
                          ? FontWeight.w800
                          : FontWeight.w500,
                      color: AppColors.inkSoft,
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

/// One game in the progress report: how many of its sessions are played
/// and their average grade; expands to list every session.
class _GameGroupCard extends StatefulWidget {
  const _GameGroupCard({
    super.key,
    required this.game,
    required this.results,
    required this.learnerName,
    required this.isLocked,
  });

  final GameGroup game;
  final Map<String, ProgressRecord> results;
  final String learnerName;
  final bool Function(Lesson lesson, Destination destination) isLocked;

  @override
  State<_GameGroupCard> createState() => _GameGroupCardState();
}

class _GameGroupCardState extends State<_GameGroupCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final played = [
      for (final s in game.sessions)
        if (widget.results[s.lesson.id] case final r?) r,
    ];
    final total = game.sessions.length;
    final lockedCount = game.sessions
        .where((s) => widget.isLocked(s.lesson, s.destination))
        .length;
    final allLocked = lockedCount == total;
    final average = played.isEmpty
        ? null
        : played.map((r) => r.strokeAccuracyPct).reduce((a, b) => a + b) /
              played.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.creamBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _RowWithStatus(
                leading: Opacity(
                  opacity: allLocked ? 0.45 : 1,
                  child: Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.cream,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      game.icon,
                      style: const TextStyle(fontSize: 19),
                    ),
                  ),
                ),
                body: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      game.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${played.length} of $total session${total == 1 ? '' : 's'} played'
                      '${lockedCount > 0 && !allLocked ? ' · $lockedCount locked' : ''}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.inkSoft,
                      ),
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: played.length / total,
                        minHeight: 4,
                        backgroundColor: AppColors.mint,
                        valueColor: const AlwaysStoppedAnimation(
                          AppColors.teal,
                        ),
                      ),
                    ),
                  ],
                ),
                status: average != null
                    ? _GradeChip(scorePct: average)
                    : allLocked
                    ? const LockedTag()
                    : const Text(
                        'Not started',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.inkSoft,
                        ),
                      ),
                trailingIcon: AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.keyboard_arrow_down,
                    size: 20,
                    color: AppColors.inkSoft,
                  ),
                ),
              ),
            ),
          ),
          if (_open)
            for (final session in game.sessions)
              _SessionRow(
                game: game,
                lesson: session.lesson,
                destination: session.destination,
                record: widget.results[session.lesson.id],
                learnerName: widget.learnerName,
                locked: widget.isLocked(session.lesson, session.destination),
              ),
        ],
      ),
    );
  }
}

/// The report's progress list, switchable between the 12 games and the 7
/// map stages; each card opens to its sessions.
class _ProgressGroupsSection extends StatefulWidget {
  const _ProgressGroupsSection({
    required this.results,
    required this.learnerName,
    required this.isLocked,
  });

  final Map<String, ProgressRecord> results;
  final String learnerName;
  final bool Function(Lesson lesson, Destination destination) isLocked;

  @override
  State<_ProgressGroupsSection> createState() => _ProgressGroupsSectionState();
}

class _ProgressGroupsSectionState extends State<_ProgressGroupsSection> {
  bool _byStage = false;

  @override
  Widget build(BuildContext context) {
    Widget segment(String label, bool value) {
      final active = _byStage == value;
      return GestureDetector(
        onTap: () => setState(() => _byStage = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: active ? AppColors.teal : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : AppColors.teal,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Wrap: the Games/Stages toggle drops below the heading when the
        // dialog is too narrow for both on one line.
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Text(
              _byStage ? 'Progress by stage' : 'Progress by game',
              style: _display(17),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.teal, width: 1.2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    segment('12 Games', false),
                    segment('7 Stages', true),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _byStage
              ? 'Tap a stage to see its sessions, then tap a session for '
                    'its full grade and feedback.'
              : 'Tap a game to see its sessions, then tap a session for '
                    'its full grade and feedback.',
          style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
        ),
        const SizedBox(height: 8),
        for (final group in _byStage ? curriculumStages() : curriculumGames())
          _GameGroupCard(
            key: ValueKey(group.name),
            game: group,
            results: widget.results,
            learnerName: widget.learnerName,
            isLocked: widget.isLocked,
          ),
      ],
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({
    required this.game,
    required this.lesson,
    required this.destination,
    required this.record,
    required this.learnerName,
    required this.locked,
  });

  final GameGroup game;
  final Lesson lesson;
  final Destination destination;
  final ProgressRecord? record;
  final String learnerName;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final record = this.record;
    final session = sessionLabel(lesson);
    final gameName = gameNameOf(lesson);
    // By game: "Session 1 (Forest)" over its stage; by stage: the game over
    // its session.
    final label = game.isStage ? gameName : session;
    final detail = game.isStage ? session : destination.name;
    return InkWell(
      onTap: record == null
          ? null
          : () => _showGameReport(
              context,
              title: gameName,
              subtitle: '$session · ${destination.name}',
              icon: lesson.activities.first.icon,
              type: lesson.activities.first.type,
              record: record,
              learnerName: learnerName,
            ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        decoration: BoxDecoration(
          color: record == null ? null : AppColors.mint.withValues(alpha: 0.35),
          border: const Border(top: BorderSide(color: AppColors.creamBorder)),
        ),
        child: _RowWithStatus(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              Text(
                detail,
                style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
              ),
            ],
          ),
          status: record != null
              ? _GradeChip(scorePct: record.strokeAccuracyPct)
              : locked
              ? const LockedTag()
              : const Text(
                  'Not played yet',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkSoft,
                  ),
                ),
          trailingIcon: record == null
              ? null
              : const Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: AppColors.inkSoft,
                ),
        ),
      ),
    );
  }
}

/// One game's row in the progress report: title, grade, and the first
/// line of feedback. Tapping opens the full [_GameReportSheet].
class _GameResultCard extends StatelessWidget {
  const _GameResultCard({
    required this.title,
    required this.icon,
    required this.subtitle,
    required this.type,
    required this.record,
    required this.learnerName,
  });

  final String title;
  final String icon;
  final String subtitle;
  final ActivityType? type;
  final ProgressRecord record;
  final String learnerName;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showGameReport(
            context,
            title: title,
            icon: icon,
            type: type,
            record: record,
            learnerName: learnerName,
          ),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.creamBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RowWithStatus(
                  leading: Text(icon, style: const TextStyle(fontSize: 20)),
                  body: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                  status: _GradeChip(scorePct: record.strokeAccuracyPct),
                ),
                const SizedBox(height: 8),
                Text(
                  gameFeedback(
                    scorePct: record.strokeAccuracyPct,
                    mistakes: record.sequencingErrors,
                    name: learnerName,
                  ),
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (record.assignedByTeacher)
                      const Text(
                        'HOMEWORK',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.tealDark,
                          letterSpacing: 0.3,
                        ),
                      ),
                    const Spacer(),
                    const Flexible(
                      child: Text(
                        'See full report',
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.teal,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      size: 14,
                      color: AppColors.teal,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
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
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: AppColors.goldTint,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.goldSoft.withValues(alpha: 0.6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.home_rounded, size: 22, color: AppColors.coral),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Try this at home', style: _display(17)),
                const SizedBox(height: 2),
                Text(
                  "This week's practice routine — ${prompt.destination.name}",
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.inkSoft,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  prompt.routine,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.ink,
                    height: 1.45,
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
            curve: Curves.easeOutQuart,
            builder: (context, t, _) => CustomPaint(
              size: Size(size, size),
              painter: _DialPainter(progress: t),
            ),
          ),
          // Kept inside the ring at any text scale.
          SizedBox(
            width: size * 0.64,
            height: size * 0.5,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${accuracyPct.round()}%',
                    style: _display(size * 0.25, weight: 800, height: 1),
                  ),
                  Text(
                    'Accuracy',
                    style: TextStyle(
                      fontSize: size * 0.1,
                      color: AppColors.inkSoft,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (streak > 0)
            Positioned(
              top: -2,
              right: -8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.surface, width: 2.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.local_fire_department_rounded,
                      size: 14,
                      color: AppColors.ink,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '$streak',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
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
    final radius = (size.shortestSide - 14) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final track = Paint()
      ..color = AppColors.mint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12;
    canvas.drawCircle(center, radius, track);

    if (progress > 0) {
      final fill = Paint()
        ..color = AppColors.teal
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, -pi / 2, 2 * pi * progress, false, fill);
    }
  }

  @override
  bool shouldRepaint(covariant _DialPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Draw-in line chart: grid + soft area fill + a teal line that draws
/// itself in on every reveal (fresh [_draw] controller each time this tab
/// remounts), reading real per-day activity from [parentWeeklyChartProvider]
/// (no invented numbers). The latest day gets a ringed end-point dot.
class _TrendChartCard extends ConsumerStatefulWidget {
  const _TrendChartCard();

  @override
  ConsumerState<_TrendChartCard> createState() => _TrendChartCardState();
}

class _TrendChartCardState extends ConsumerState<_TrendChartCard>
    with SingleTickerProviderStateMixin {
  // Created in initState, not lazily: an empty chart never touches it, and
  // first creating a controller inside dispose() throws mid-unmount.
  late final AnimationController _draw;
  int _range = 0;

  @override
  void initState() {
    super.initState();
    _draw = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
  }

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
      radius: 20,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Weekly trend', style: _display(18)),
          const SizedBox(height: 2),
          const Text(
            'Time spent playing, day by day',
            style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.neutralTint,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.creamBorder),
            ),
            child: Row(
              children: [
                for (final (i, label) in _ranges.indexed)
                  Expanded(
                    child: _RangePill(
                      label: label,
                      active: i == _range,
                      onTap: () => _selectRange(i),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
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
                        repeat: false,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'No activity yet this week',
                      style: TextStyle(color: AppColors.inkSoft, fontSize: 14),
                    ),
                  ],
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                const height = 128.0;
                const topPad = 20.0;
                const bottomPad = 8.0;
                const edge = 6.0;
                final width = constraints.maxWidth;
                final values = entries.map((e) => e.value).toList();
                final n = values.length;
                final dx = n > 1 ? (width - edge * 2) / (n - 1) : 0.0;
                final points = [
                  for (var i = 0; i < n; i++)
                    Offset(
                      edge + i * dx,
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
                // Each label gets the gap to its neighbour (not a fixed 28px)
                // so full day names fit, shrinking only on very narrow charts.
                final slotW = (dx * step).clamp(30.0, 64.0).clamp(0.0, width);

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
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 16,
                      width: width,
                      child: Stack(
                        children: [
                          for (final i in labelIndices)
                            Positioned(
                              left: (points[i].dx - slotW / 2).clamp(
                                0.0,
                                width - slotW,
                              ),
                              width: slotW,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  entries[i].label,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: i == n - 1
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                                    color: i == n - 1
                                        ? AppColors.teal
                                        : AppColors.inkSoft,
                                  ),
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
    return Semantics(
      button: true,
      selected: active,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutQuart,
        decoration: BoxDecoration(
          color: active ? AppColors.teal : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: active ? Colors.white : AppColors.inkSoft,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Grid + soft area fill + drawn polyline, with a ringed dot on the most
/// recent day once the line has drawn all the way in.
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

    // 1. Dashed horizontal gridlines behind the curve.
    final gridPaint = Paint()
      ..color = AppColors.creamBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    for (var i = 1; i <= 3; i++) {
      final y = bottom * i / 4;
      for (var x = 0.0; x < size.width; x += 8) {
        canvas.drawLine(Offset(x, y), Offset(x + 4, y), gridPaint);
      }
    }
    canvas.drawLine(Offset(0, bottom), Offset(size.width, bottom), gridPaint);

    // 2. Straight-segment line.
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    final reveal = progress.clamp(0.0, 1.0);
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * reveal, size.height + 40));

    // 3. Area fill, fading from the line down to the baseline.
    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, bottom)
      ..lineTo(points.first.dx, bottom)
      ..close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.teal.withValues(alpha: 0.18),
          AppColors.teal.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    // 4. The line itself.
    final linePaint = Paint()
      ..color = AppColors.teal
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);
    canvas.restore();

    // 5. End-point marker for the latest day.
    if (reveal >= 1) {
      final last = points.last;
      canvas.drawCircle(last, 6.5, Paint()..color = AppColors.surface);
      canvas.drawCircle(
        last,
        6.5,
        Paint()
          ..color = AppColors.teal
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.points != points;
}

/// Settings grouped into three labeled sections on the cream canvas —
/// one Account & security row (its sub-page holds the account cards and
/// Delete account), sound and language, then a divided sheet for sync /
/// log out.
class _SettingsTab extends ConsumerWidget {
  const _SettingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volumes = ref.watch(volumeProvider);
    final volumeNotifier = ref.read(volumeProvider.notifier);

    return HubTabBody(
      left: const [
        HubStaggerFadeIn(
          delay: Duration.zero,
          child: HubSectionLabel('Account'),
        ),
        HubStaggerFadeIn(
          delay: Duration(milliseconds: 10),
          child: AccountSecurityRow(
            children: [
              PersonalInfoRow(),
              AccountEmailCard(),
              SizedBox(height: 12),
              EmailVerificationCard(),
              _LinkFirebaseCard(),
              SizedBox(height: 12),
              ChangePinCard(),
              SizedBox(height: 12),
              ChangePasswordRow(),
            ],
          ),
        ),
      ],
      right: [
        const HubStaggerFadeIn(
          delay: Duration(milliseconds: 85),
          child: HubSectionLabel('Sound & language'),
        ),
        HubStaggerFadeIn(
          delay: const Duration(milliseconds: 100),
          child: SoftCard(
            radius: 20,
            padding: const EdgeInsets.fromLTRB(20, 18, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _VolumeSlider(
                  icon: Icons.music_note_outlined,
                  label: 'Background Music',
                  value: volumes.background,
                  onChanged: volumeNotifier.setBackground,
                ),
                const SizedBox(height: 6),
                _VolumeSlider(
                  icon: Icons.notifications_none,
                  label: 'UI Sound Effects',
                  value: volumes.effects,
                  onChanged: volumeNotifier.setEffects,
                ),
                const SizedBox(height: 6),
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
        const SizedBox(height: 12),
        const HubStaggerFadeIn(
          delay: Duration(milliseconds: 115),
          child: SoftCard(
            radius: 20,
            padding: EdgeInsets.all(6),
            child: LanguageSettingRow(),
          ),
        ),
        const SizedBox(height: 12),
        const HubStaggerFadeIn(
          delay: Duration(milliseconds: 130),
          child: HubSectionLabel('Data & session'),
        ),
        const HubStaggerFadeIn(
          delay: Duration(milliseconds: 145),
          child: SoftCard(
            radius: 20,
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                _SyncCard(),
                HubRowDivider(),
                _ExitSettingsCard(),
              ],
            ),
          ),
        ),
      ],
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
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SoftCard(
        radius: 20,
        color: AppColors.goldTint,
        borderColor: AppColors.goldSoft.withValues(alpha: 0.6),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.cloud_off_rounded,
                  size: 22,
                  color: AppColors.coral,
                ),
                const SizedBox(width: 10),
                Flexible(child: Text('Link to Cloud', style: _display(18))),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'This account isn\'t linked to the cloud yet, so "Sync now" '
              'won\'t work until you link it. Re-enter your password to link it.',
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: AppColors.inkSoft,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _passwordC,
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'Account password'.tr,
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.creamBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.creamBorder),
                ),
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
        // Wrap: the level chip drops under the label when both don't fit
        // on one line (narrow phone / large text).
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: AppColors.teal),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: value == 0 ? AppColors.neutralTint : AppColors.mint,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _getVolumeLabel(value),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: value == 0 ? AppColors.inkSoft : AppColors.tealDark,
                ),
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: 0.0,
          max: 1.0,
          activeColor: AppColors.teal,
          inactiveColor: AppColors.mint,
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
    return HubActionRow(
      icon: Icons.sync_rounded,
      title: 'Sync Now',
      subtitle: 'Sync local device progress with cloud servers.',
      trailing: HubRowButton(
        label: _syncing ? 'Syncing...' : 'Sync',
        busy: _syncing,
        onPressed: () async {
          setState(() => _syncing = true);
          try {
            await ref.read(syncManagerProvider).syncNow();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sync completed successfully!')),
              );
            }
          } catch (error) {
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Sync failed: $error')));
            }
          } finally {
            if (mounted) setState(() => _syncing = false);
          }
        },
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
    return HubActionRow(
      icon: Icons.logout_rounded,
      iconColor: AppColors.inkSoft,
      title: 'Exit Settings',
      subtitle: 'Exit settings and lock admin areas',
      trailing: HubRowButton(
        label: 'Logout',
        color: AppColors.danger,
        onPressed: () => _confirmLogout(context, ref),
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
    final results = ref.watch(parentGameResultsProvider);
    final classroomRecords = records.where((r) => r.isClassroomMode).toList();
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

    String getModuleTitle(String moduleId) => assignmentTitle(moduleId);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: MediaQuery.sizeOf(context).width < 400 ? 12 : 20,
        vertical: 24,
      ),
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
                decoration: const BoxDecoration(color: AppColors.teal),
                child: CustomPaint(
                  painter: const KhatamPatternPainter(),
                  child: Row(
                    children: [
                      LearnerAvatar(avatar: learnerAvatar, size: 40),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LayoutBuilder(
                              builder: (context, box) => Text(
                                learnerName,
                                style: fitLongestWord(
                                  context,
                                  learnerName,
                                  _display(20, color: Colors.white),
                                  box.maxWidth,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Learning Progress Report',
                              style: TextStyle(
                                color: Color(0xE6FFFFFF),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close'.tr,
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Overview stats: 2 per row, 1 when narrow.
                      _AdaptiveTiles(
                        minTileWidth: 150,
                        children: [
                          _buildOverviewTile(
                            icon: Icons.check_circle_outline_rounded,
                            value: '${kpis.accuracyPct.round()}%',
                            label: 'Avg. Accuracy',
                            color: AppColors.teal,
                            bg: AppColors.mint,
                          ),
                          _buildOverviewTile(
                            icon: Icons.error_outline_rounded,
                            value: '${kpis.errorCount}',
                            label: 'Total Errors',
                            color: AppColors.coral,
                            bg: AppColors.coralTint,
                          ),
                          _buildOverviewTile(
                            icon: Icons.schedule_rounded,
                            value: '${kpis.timeOnTaskMinutes}m',
                            label: 'Time on Task',
                            color: AppColors.gold,
                            bg: AppColors.goldTint,
                          ),
                          _buildOverviewTile(
                            icon: Icons.local_fire_department_rounded,
                            value: '${kpis.streak}d',
                            label: 'Active Streak',
                            color: AppColors.coral,
                            bg: AppColors.goldTint,
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),

                      // Section: Adventure Mastery
                      Text('Adventure mastery', style: _display(17)),
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
                              color: AppColors.inkSoft,
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
                                  Wrap(
                                    alignment: WrapAlignment.spaceBetween,
                                    spacing: 8,
                                    runSpacing: 2,
                                    children: [
                                      Text(
                                        title,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.ink,
                                        ),
                                      ),
                                      Text(
                                        '${mod.sessionCount} session${mod.sessionCount == 1 ? '' : 's'}',
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          color: AppColors.inkSoft,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(99),
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
                                                  AlwaysStoppedAnimation<Color>(
                                                    mod.accuracyPct >= 80
                                                        ? AppColors.teal
                                                        : (mod.accuracyPct >= 60
                                                              ? AppColors.gold
                                                              : AppColors
                                                                    .coral),
                                                  ),
                                              minHeight: 6,
                                            );
                                          },
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        '${mod.accuracyPct.round()}% · ${GradeBand.forScore(mod.accuracyPct).label}',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          // Gold text fails contrast on
                                          // white; ink carries the middle band.
                                          color: mod.accuracyPct >= 80
                                              ? AppColors.tealDark
                                              : (mod.accuracyPct >= 60
                                                    ? AppColors.ink
                                                    : AppColors.coral),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (mod.errorCount > 0) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      '${mod.errorCount} mistake${mod.errorCount == 1 ? '' : 's'} this week',
                                      style: const TextStyle(
                                        fontSize: 12.5,
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

                      // Section: every game or stage, each with its sessions
                      _ProgressGroupsSection(
                        results: results,
                        learnerName: learner?.name ?? 'Your child',
                        isLocked: (lesson, destination) => !isLessonUnlocked(
                          learnerId,
                          destination,
                          lesson,
                          ref.watch(parentCompletedLessonsProvider),
                        ),
                      ),
                      if (classroomRecords.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text('Classroom activities', style: _display(17)),
                        const SizedBox(height: 8),
                        for (final rec in classroomRecords.take(10))
                          _GameResultCard(
                            title: rec.moduleId.startsWith('hot_seat_')
                                ? 'Hot Seat tracing: ${rec.moduleId.substring(9)}'
                                : castGameNames[castGameFor(rec)] ??
                                      'Classroom game',
                            icon: '🏫',
                            subtitle:
                                'In class · ${formatDate(rec.completedAt)}',
                            type: rec.moduleId.startsWith('cast_')
                                ? castGameFor(rec)
                                : null,
                            record: rec,
                            learnerName: learner?.name ?? 'Your child',
                          ),
                      ],
                      const SizedBox(height: 14),
                      const _GradeScaleLegend(),
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
          Icon(icon, size: 22, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: _display(20, weight: 800)),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.inkSoft,
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
