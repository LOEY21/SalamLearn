import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../data/models/enrollment.dart';
import '../../data/remote/firestore_mirror.dart';
import '../../data/repositories/class_repository.dart';
import '../../logic/auth/session.dart';
import '../../logic/parent/analytics_providers.dart';
import '../../logic/parent/children_providers.dart';
import '../../logic/settings/settings_providers.dart';
import '../../logic/sync/sync_manager.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_loading_overlay.dart';
import '../widgets/email_verification_card.dart';
import '../widgets/learner_avatar.dart';
import '../widgets/soft_card.dart';

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

    // Catches the "removed via the admin web panel" case (see
    // `verifyActiveAccountStillExists`'s doc) — a confirmed remote miss
    // already logged this device out by the time this fires, so all that's
    // left is telling the parent why and sending them to the role picker
    // instead of leaving them looking at a dashboard for an account that
    // no longer exists.
    ref.listen(accountStillExistsProvider, (_, next) {
      next.whenData((stillExists) {
        if (stillExists) return;
        showDialog<void>(
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
              'This account was removed by an administrator. Please sign in again or create a new account.',
            ),
            actions: [
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  context.go('/roles');
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      });
    });

    // Without this, hardware/system back had no explicit handling here,
    // so it fell through to go_router's default history-pop — silently
    // landing back on the role picker with no confirmation and, worse,
    // leaving `pinVerified` still true, so re-picking Parent skipped the
    // PIN gate entirely. Reusing the existing "Switch User?" confirmation
    // makes back press exactly as intentional as tapping that menu item.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _switchUser(context, ref);
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide =
              constraints.maxWidth >= 800 && constraints.maxHeight >= 550;
          return wide ? _WideLayout(name: name) : _PhoneLayout(name: name);
        },
      ),
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
  const _PhoneLayout({required this.name});

  final String name;

  @override
  ConsumerState<_PhoneLayout> createState() => _PhoneLayoutState();
}

class _PhoneLayoutState extends ConsumerState<_PhoneLayout>
    with SingleTickerProviderStateMixin {
  int _currentTab = 0;

  // Same tab-switch treatment as the Learner Hub's `HubShell`: fade the
  // outgoing tab out, swap content, fade the new one in — a soft crossfade
  // instead of an instant cut.
  static const _fadeDuration = Duration(milliseconds: 140);
  double _opacity = 1;

  void _switchTab(int index) {
    if (index == _currentTab) return;
    setState(() => _opacity = 0);
    Future.delayed(_fadeDuration, () {
      if (mounted) {
        setState(() {
          _currentTab = index;
          _opacity = 1;
        });
      }
    });
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
  late final kpi = _in(0.28, 0.62);
  late final chart = _in(0.42, 0.78);
  late final suggest = _in(0.55, 0.9);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        bottom: false,
        child: AnimatedOpacity(
          duration: _fadeDuration,
          curve: Curves.easeOut,
          opacity: _opacity,
          child: switch (_currentTab) {
            0 => ListView(
              padding: EdgeInsets.zero,
              children: [
                _DashboardHero(
                  name: widget.name,
                  animation: greet,
                  onSwitchUser: () => _switchUser(context, ref),
                ),
                Transform.translate(
                  offset: const Offset(0, -26),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _FadeUp(animation: kpi, child: const _KpiFocusRow()),
                        const SizedBox(height: 14),
                        _FadeUp(
                          animation: chart,
                          child: const _TrendChartCard(),
                        ),
                        const SizedBox(height: 14),
                        _FadeUp(
                          animation: suggest,
                          child: const _SuggestionCarousel(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            1 => ListView(
              padding: EdgeInsets.zero,
              children: [
                const _ProfileHero(),
                Transform.translate(
                  offset: const Offset(0, -22),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(18, 22, 18, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _StaggerFadeIn(
                          delay: const Duration(milliseconds: 40),
                          child: _ChildSwitcher(
                            onSwitched: () => _switchTab(0),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const _StaggerFadeIn(
                          delay: Duration(milliseconds: 70),
                          child: _NoProfileEmptyState(),
                        ),
                        const SizedBox(height: 14),
                        const _StaggerFadeIn(
                          delay: Duration(milliseconds: 100),
                          child: _ManageProfileCard(),
                        ),
                        const SizedBox(height: 14),
                        const _StaggerFadeIn(
                          delay: Duration(milliseconds: 160),
                          child: _ClassSection(),
                        ),
                        const SizedBox(height: 14),
                        const _StaggerFadeIn(
                          delay: Duration(milliseconds: 220),
                          child: _CreateNewProfileCard(),
                        ),
                        const SizedBox(height: 14),
                        const _StaggerFadeIn(
                          delay: Duration(milliseconds: 280),
                          child: _SyncProfileCard(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            _ => const _SettingsTab(),
          },
        ),
      ),
      bottomNavigationBar: _ParentBottomNav(
        activeTab: _currentTab,
        onTabChanged: _switchTab,
      ),
    );
  }
}

class _ParentBottomNav extends StatelessWidget {
  const _ParentBottomNav({required this.activeTab, required this.onTabChanged});

  final int activeTab;
  final ValueChanged<int> onTabChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.creamBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavTab(
                icon: Icons.bar_chart_rounded,
                label: 'Progress',
                active: activeTab == 0,
                onTap: () => onTabChanged(0),
              ),
              _NavTab(
                icon: Icons.assignment_ind_outlined,
                label: 'Manage Profile',
                active: activeTab == 1,
                onTap: () => onTabChanged(1),
              ),
              _NavTab(
                icon: Icons.settings_outlined,
                label: 'Settings',
                active: activeTab == 2,
                onTap: () => onTabChanged(2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  const _NavTab({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.teal : AppColors.textMuted;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: active ? AppColors.mint : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WideLayout extends ConsumerStatefulWidget {
  const _WideLayout({required this.name});

  final String name;

  @override
  ConsumerState<_WideLayout> createState() => _WideLayoutState();
}

class _WideLayoutState extends ConsumerState<_WideLayout>
    with SingleTickerProviderStateMixin {
  int _currentTab = 0;

  // Same tab-switch treatment as the Learner Hub's `HubShell`: fade the
  // outgoing tab out, swap content, fade the new one in.
  static const _fadeDuration = Duration(milliseconds: 140);
  double _opacity = 1;

  void _switchTab(int index) {
    if (index == _currentTab) return;
    setState(() => _opacity = 0);
    Future.delayed(_fadeDuration, () {
      if (mounted) {
        setState(() {
          _currentTab = index;
          _opacity = 1;
        });
      }
    });
  }

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  )..forward();

  Animation<double> _in(double start, double end) {
    return CurvedAnimation(
      parent: _c,
      curve: Interval(start, end, curve: Curves.easeOut),
    );
  }

  late final kpi = _in(0.05, 0.45);
  late final row = _in(0.3, 0.72);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.neutralTint,
      body: Row(
        children: [
          _SideRail(activeTab: _currentTab, onTabChanged: _switchTab),
          Expanded(
            child: SafeArea(
              child: AnimatedOpacity(
                duration: _fadeDuration,
                curve: Curves.easeOut,
                opacity: _opacity,
                child: switch (_currentTab) {
                  0 => Padding(
                    padding: const EdgeInsets.all(26),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "${widget.name}'s progress",
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineMedium,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _parentGreeting(ref),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            OutlinedButton.icon(
                              onPressed: () => _switchUser(context, ref),
                              icon: const Icon(
                                Icons.people_outline_rounded,
                                size: 18,
                              ),
                              label: const Text('Switch user'),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: AppColors.creamBorder,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        _FadeUp(
                          animation: kpi,
                          child: const _KpiFocusRow(wide: true),
                        ),
                        const SizedBox(height: 20),
                        Expanded(
                          child: _FadeUp(
                            animation: row,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Expanded(flex: 3, child: _TrendChartCard()),
                                SizedBox(width: 20),
                                Expanded(
                                  flex: 2,
                                  child: _SuggestionCarousel(wide: true),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  1 => SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _ProfileHero(wide: true),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(30, 24, 30, 30),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _ChildSwitcher(onSwitched: () => _switchTab(0)),
                              const SizedBox(height: 20),
                              const _NoProfileEmptyState(),
                              const SizedBox(height: 20),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Expanded(child: _ManageProfileCard()),
                                  const SizedBox(width: 20),
                                  Expanded(
                                    child: Column(
                                      children: const [
                                        _ClassSection(),
                                        SizedBox(height: 14),
                                        _CreateNewProfileCard(),
                                        SizedBox(height: 14),
                                        _SyncProfileCard(),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _ => const _SettingsTab(),
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SideRail extends StatelessWidget {
  const _SideRail({required this.activeTab, required this.onTabChanged});

  final int activeTab;
  final ValueChanged<int> onTabChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.teal, AppColors.tealDark],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.favorite, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 22),
            _RailItem(
              icon: Icons.bar_chart_rounded,
              label: 'Progress',
              active: activeTab == 0,
              onTap: () => onTabChanged(0),
            ),
            const SizedBox(height: 6),
            _RailItem(
              icon: Icons.assignment_ind_outlined,
              label: 'Profile',
              active: activeTab == 1,
              onTap: () => onTabChanged(1),
            ),
            const Spacer(),
            _RailItem(
              icon: Icons.settings_outlined,
              label: 'Settings',
              active: activeTab == 2,
              onTap: () => onTabChanged(2),
            ),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  const _RailItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 64,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: active ? Colors.white.withValues(alpha: 0.16) : null,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 19,
                color: active ? Colors.white : Colors.white70,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-bleed masthead for the Manage Profile tab — same recipe as the
/// Teacher Dashboard's `_ClassroomHero`/`_SettingsHero` (ambient breathing
/// blobs + fade/slide-down entrance) so this tab isn't a lone boxed card
/// sitting in padding while Progress/Settings get the full-bleed treatment.
class _ProfileHero extends ConsumerStatefulWidget {
  const _ProfileHero({this.wide = false});

  final bool wide;

  @override
  ConsumerState<_ProfileHero> createState() => _ProfileHeroState();
}

class _ProfileHeroState extends ConsumerState<_ProfileHero>
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
    final learner = ref.watch(sessionProvider).learner;
    final wide = widget.wide;

    return ClipRect(
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(wide ? 30 : 20, 20, wide ? 30 : 20, 46),
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
            FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: Row(
                  children: [
                    LearnerAvatar(avatar: learner?.avatar ?? '➕', size: 54),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            learner?.name ?? 'No learner yet',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            learner == null
                                ? 'Add a child profile to get started'
                                : 'Age ${learner.age} • ${learner.gradeLevel}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
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
    refreshLearnerClass(ref);
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
                color: AppColors.mint,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.mintBorder),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.school_outlined,
                    color: AppColors.teal,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${learner.name} is enrolled in ${section.name}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Enter a new invitation code below to join a different class.',
              style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
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
                child: _Input(controller: _codeC, hint: 'e.g. 7K3PQR'),
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

class _Input extends StatelessWidget {
  const _Input({required this.controller, required this.hint});
  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
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
          borderSide: const BorderSide(color: AppColors.teal, width: 1.4),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------- hero

/// Gradient hero header: greeting, avatar initial, sync icon and a live
/// "synced" status pill. Replaces the old flat AppBar on the phone layout.
class _DashboardHero extends ConsumerStatefulWidget {
  const _DashboardHero({
    required this.name,
    required this.animation,
    required this.onSwitchUser,
  });

  final String name;
  final Animation<double> animation;
  final VoidCallback onSwitchUser;

  @override
  ConsumerState<_DashboardHero> createState() => _DashboardHeroState();
}

class _DashboardHeroState extends ConsumerState<_DashboardHero>
    with SingleTickerProviderStateMixin {
  // Ambient layer: slow breathing pulse on the hero's background blobs —
  // matches the Classroom tab/Settings/Classroom-Management heroes' own
  // breathing treatment (2600ms, same duration as the splash screen's
  // halo) so every full-bleed hero in the app shares one motion language
  // instead of this tab's blobs being the one static exception.
  late final _breathe = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _breathe.dispose();
    super.dispose();
  }

  String _syncStatusLabel(WidgetRef ref) {
    final lastSynced = ref.read(syncManagerProvider).lastSyncedAt;
    if (lastSynced == null) return 'Not synced yet';
    final elapsed = DateTime.now().difference(lastSynced);
    if (elapsed.inMinutes < 1) return 'Synced just now';
    if (elapsed.inMinutes < 60) return 'Synced ${elapsed.inMinutes} min ago';
    if (elapsed.inHours < 24) return 'Synced ${elapsed.inHours}h ago';
    return 'Synced ${elapsed.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: widget.animation,
      child: ClipRect(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 56),
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
              // Ambient blobs — now breathing (opacity + gentle drift)
              // instead of static, matching the HTML preview's
              // `.hero::before`/`::after` intent more fully.
              AnimatedBuilder(
                animation: _breathe,
                builder: (context, child) {
                  final t = Curves.easeInOut.transform(_breathe.value);
                  return Positioned(
                    top: -90 + (6 * t),
                    right: -50,
                    child: Opacity(
                      opacity: 0.04 + (0.03 * t),
                      child: const _Blob(size: 180, color: Colors.white),
                    ),
                  );
                },
              ),
              AnimatedBuilder(
                animation: _breathe,
                builder: (context, child) {
                  final t = Curves.easeInOut.transform(_breathe.value);
                  return Positioned(
                    bottom: -60 - (5 * t),
                    left: -30,
                    child: Opacity(
                      opacity: 0.07 + (0.05 * t),
                      child: const _Blob(size: 120, color: AppColors.gold),
                    ),
                  );
                },
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.goldTint,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.35),
                            width: 2,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          widget.name.isNotEmpty
                              ? widget.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.tealDark,
                          ),
                        ),
                      ),
                      const Spacer(),
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: widget.onSwitchUser,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.people_outline_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _parentGreeting(ref, caps: true),
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "${widget.name}'s progress",
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.13),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.goldSoft,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _syncStatusLabel(ref),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
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
      ),
    );
  }
}

/// Soft translucent circle used for ambient depth behind hero content.
class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

// ------------------------------------------------------------- shared

/// Fades and slides its child upward as [animation] runs 0→1.
class _FadeUp extends StatelessWidget {
  const _FadeUp({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, c) => Transform.translate(
          offset: Offset(0, (1 - animation.value) * 16),
          child: c,
        ),
        child: child,
      ),
    );
  }
}

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
                child: Column(
                  children: [
                    _StatPill(
                      icon: Icons.schedule_rounded,
                      iconBg: AppColors.goldTint,
                      iconColor: AppColors.gold,
                      value: '${kpis.timeOnTaskMinutes}m',
                      label: 'Time on task',
                      trend: kpis.timeOnTaskTrend.text,
                      trendUp: kpis.timeOnTaskTrend.up,
                    ),
                    const SizedBox(height: 10),
                    _StatPill(
                      icon: Icons.error_outline_rounded,
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
            ],
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
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.trend,
    required this.trendUp,
  });

  final IconData icon;
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
            child: Icon(icon, size: 17, color: iconColor),
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

/// Smooth draw-in line chart replacing the bar chart — tap or drag to scrub
/// between days; the floating bubble reads real per-day activity level from
/// [parentWeeklyChartProvider] (no invented numbers).
class _TrendChartCard extends ConsumerStatefulWidget {
  const _TrendChartCard();

  @override
  ConsumerState<_TrendChartCard> createState() => _TrendChartCardState();
}

class _TrendChartCardState extends ConsumerState<_TrendChartCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _draw = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..forward();
  int? _selected;

  @override
  void dispose() {
    _draw.dispose();
    super.dispose();
  }

  void _selectNearest(double dx, double step, int n) {
    if (n == 0) return;
    final i = step == 0 ? 0 : (dx / step).round().clamp(0, n - 1);
    if (i != _selected) setState(() => _selected = i);
  }

  @override
  Widget build(BuildContext context) {
    final chartData = ref.watch(parentWeeklyChartProvider);
    final entries = chartData.entries.toList();
    final selected = _selected ?? (entries.isEmpty ? null : entries.length - 1);

    return SoftCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  'Weekly activity',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(width: 8),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.mint,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  'This week',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.tealDark,
                  ),
                ),
              ),
            ],
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
                const height = 140.0;
                const topPad = 30.0;
                const bottomPad = 20.0;
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

                return GestureDetector(
                  onTapDown: (d) => _selectNearest(d.localPosition.dx, dx, n),
                  onPanUpdate: (d) => _selectNearest(d.localPosition.dx, dx, n),
                  child: AnimatedBuilder(
                    animation: _draw,
                    builder: (context, _) {
                      return SizedBox(
                        width: width,
                        height: height,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CustomPaint(
                              size: Size(width, height),
                              painter: _TrendPainter(
                                points: points,
                                progress: _draw.value,
                                selectedIndex: selected,
                                bottom: height - bottomPad,
                              ),
                            ),
                            for (final (i, e) in entries.indexed)
                              Positioned(
                                left: points[i].dx - 12,
                                top: height - bottomPad + 4,
                                width: 24,
                                child: Text(
                                  e.key,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: selected == i
                                        ? AppColors.teal
                                        : AppColors.textMuted,
                                  ),
                                ),
                              ),
                            if (selected != null && _draw.isCompleted)
                              Positioned(
                                left: (points[selected].dx - 30).clamp(
                                  0,
                                  width - 60,
                                ),
                                top: (points[selected].dy - 38).clamp(
                                  -8,
                                  height,
                                ),
                                child: _ChartTooltip(
                                  label: entries[selected].key,
                                  pct: (values[selected] * 100).round(),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _ChartTooltip extends StatelessWidget {
  const _ChartTooltip({required this.label, required this.pct});

  final String label;
  final int pct;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.tealDark,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        '$label · $pct% activity',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.points,
    required this.progress,
    required this.selectedIndex,
    required this.bottom,
  });

  final List<Offset> points;
  final double progress;
  final int? selectedIndex;
  final double bottom;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final midX = (prev.dx + curr.dx) / 2;
      path.cubicTo(midX, prev.dy, midX, curr.dy, curr.dx, curr.dy);
    }

    final reveal = progress.clamp(0.0, 1.0);
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * reveal, size.height + 40));

    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, bottom)
      ..lineTo(points.first.dx, bottom)
      ..close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.gold.withValues(alpha: 0.28),
          AppColors.gold.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);
    canvas.restore();

    for (var i = 0; i < points.length; i++) {
      if (points[i].dx > size.width * reveal + 0.5) continue;
      final isSelected = i == selectedIndex;
      canvas.drawCircle(
        points[i],
        isSelected ? 6 : 3.5,
        Paint()..color = isSelected ? AppColors.tealDark : Colors.white,
      );
      canvas.drawCircle(
        points[i],
        isSelected ? 6 : 3.5,
        Paint()
          ..color = AppColors.gold
          ..style = PaintingStyle.stroke
          ..strokeWidth = isSelected ? 2.5 : 2,
      );
    }

    if (selectedIndex != null && selectedIndex! < points.length) {
      final p = points[selectedIndex!];
      final dash = Paint()
        ..color = AppColors.creamBorder
        ..strokeWidth = 1.5;
      var y = p.dy + 8;
      while (y < bottom) {
        canvas.drawLine(Offset(p.dx, y), Offset(p.dx, y + 4), dash);
        y += 8;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.points != points;
}

/// Swipeable suggestion cards (replacing the flat checklist) — tapping a
/// card marks it reviewed in-memory, mirroring the ephemeral, no-persistence
/// state pattern used elsewhere in this session (FR-5.2 data is still real).
class _SuggestionCarousel extends ConsumerStatefulWidget {
  const _SuggestionCarousel({this.wide = false});

  final bool wide;

  @override
  ConsumerState<_SuggestionCarousel> createState() =>
      _SuggestionCarouselState();
}

class _SuggestionCarouselState extends ConsumerState<_SuggestionCarousel>
    with SingleTickerProviderStateMixin {
  final Set<int> _reviewed = {};
  late final PageController _controller = PageController(
    viewportFraction: widget.wide ? 0.62 : 0.86,
  );
  late final _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat(reverse: true);
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(parentSuggestionsProvider);
    final allReviewed = items.isNotEmpty && _reviewed.length == items.length;
    final progress = items.isEmpty ? 0.0 : _reviewed.length / items.length;

    return SoftCard(
      color: AppColors.neutralTint,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 30,
                height: 30,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // Ambient layer: a slow breathing glow behind the badge,
                    // same 2600ms rhythm as the hero's blobs elsewhere on
                    // this dashboard — reads as "this card is alive/waiting"
                    // rather than a static icon.
                    AnimatedBuilder(
                      animation: _glow,
                      builder: (context, child) {
                        final t = Curves.easeInOut.transform(_glow.value);
                        return Opacity(
                          opacity: 0.18 + t * 0.22,
                          child: Transform.scale(
                            scale: 1 + t * 0.3,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: AppColors.gold,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: AppColors.goldTint,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.lightbulb_outline_rounded,
                        size: 16,
                        color: AppColors.gold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  'Practice recommended',
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(width: 8),
              const Spacer(),
              if (items.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: allReviewed ? AppColors.mint : Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: allReviewed
                          ? AppColors.mintBorder
                          : AppColors.creamBorder,
                    ),
                  ),
                  child: Text(
                    '${_reviewed.length}/${items.length}',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: allReviewed
                          ? AppColors.tealDark
                          : AppColors.textMuted,
                    ),
                  ),
                ),
            ],
          ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                builder: (context, t, _) => LinearProgressIndicator(
                  value: t,
                  minHeight: 5,
                  backgroundColor: AppColors.creamBorder,
                  valueColor: AlwaysStoppedAnimation(
                    allReviewed ? AppColors.teal : AppColors.gold,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          if (items.isEmpty)
            const Text(
              'Complete a few lessons to unlock personalized practice suggestions.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
            )
          else
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child),
              ),
              child: allReviewed
                  ? _AllCaughtUpPanel(
                      key: const ValueKey('celebrate'),
                      wide: widget.wide,
                    )
                  : Column(
                      key: const ValueKey('carousel'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: widget.wide ? 132 : 118,
                          child: PageView.builder(
                            controller: _controller,
                            itemCount: items.length,
                            onPageChanged: (i) => setState(() => _page = i),
                            itemBuilder: (context, i) => AnimatedBuilder(
                              animation: _controller,
                              builder: (context, child) {
                                // Depth parallax: the centered card sits at
                                // full scale, neighbors shrink slightly as
                                // they scroll off — reads as a physical
                                // stack of cards rather than a flat swap.
                                var page = i.toDouble();
                                if (_controller.hasClients &&
                                    _controller.position.haveDimensions) {
                                  page = _controller.page ?? i.toDouble();
                                }
                                final delta = (page - i).abs().clamp(0.0, 1.0);
                                final scale = 1 - (delta * 0.1);
                                return Transform.scale(
                                  scale: scale,
                                  child: Opacity(
                                    opacity: 1 - (delta * 0.35),
                                    child: child,
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                child: _SuggestionCard(
                                  text: items[i],
                                  reviewed: _reviewed.contains(i),
                                  onTap: () => setState(() {
                                    if (!_reviewed.remove(i)) {
                                      _reviewed.add(i);
                                    }
                                  }),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (items.length > 1) ...[
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              for (var i = 0; i < items.length; i++)
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 3,
                                  ),
                                  width: _page == i ? 16 : 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    // Encodes review state, not just position —
                                    // a reviewed card stays teal even after
                                    // scrolling past it.
                                    color: _reviewed.contains(i)
                                        ? AppColors.teal
                                        : (_page == i
                                              ? AppColors.gold
                                              : AppColors.creamBorder),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
            ),
        ],
      ),
    );
  }
}

/// Shown once every suggestion in this batch has been tapped reviewed —
/// swaps in for the carousel via the parent's `AnimatedSwitcher` and plays
/// a one-shot confetti/checkmark Lottie (fresh widget instance each time
/// this state is entered, so `repeat: false` never needs a manual replay
/// trigger — matches the one-shot ethos of `_KpiFocusRow`'s milestone burst).
class _AllCaughtUpPanel extends StatelessWidget {
  const _AllCaughtUpPanel({super.key, required this.wide});

  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          SizedBox(
            width: wide ? 108 : 88,
            height: wide ? 108 : 88,
            child: Lottie.asset(
              'assets/lottie/practice_complete.json',
              repeat: false,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            "All caught up — masha'Allah!",
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "You've reviewed every suggestion in this batch.",
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

/// Which core module a suggestion string belongs to, inferred from its own
/// wording — grounds the card's icon/accent in the app's real curriculum
/// taxonomy (tracing / pronunciation / Qur'an & Hadith / Sirah / Fiqh)
/// instead of every suggestion looking visually identical.
class _SuggestionMeta {
  const _SuggestionMeta(this.label, this.icon, this.color, this.tint);

  final String label;
  final IconData icon;
  final Color color;
  final Color tint;
}

_SuggestionMeta _suggestionMeta(String text) {
  final t = text.toLowerCase();
  if (t.contains('trac') || t.contains('alif') || t.contains('letter')) {
    return const _SuggestionMeta(
      'Tracing',
      Icons.draw_outlined,
      AppColors.teal,
      AppColors.mint,
    );
  }
  if (t.contains('sound') || t.contains('pronunc') || t.contains('flashcard')) {
    return const _SuggestionMeta(
      'Pronunciation',
      Icons.volume_up_outlined,
      AppColors.gold,
      AppColors.goldTint,
    );
  }
  if (t.contains('qur') || t.contains('hadith') || t.contains('recit')) {
    return const _SuggestionMeta(
      "Qur'an & Hadith",
      Icons.menu_book_outlined,
      AppColors.coral,
      AppColors.coralTint,
    );
  }
  if (t.contains('sirah') || t.contains('story') || t.contains('prophet')) {
    return const _SuggestionMeta(
      'Sirah',
      Icons.auto_stories_rounded,
      AppColors.tealDark,
      AppColors.mint,
    );
  }
  if (t.contains('fiqh') ||
      t.contains('wudu') ||
      t.contains('salah') ||
      t.contains('prayer')) {
    return const _SuggestionMeta(
      'Fiqh',
      Icons.extension_outlined,
      AppColors.mintGreen,
      AppColors.mint,
    );
  }
  return const _SuggestionMeta(
    'Practice',
    Icons.lightbulb_outline_rounded,
    AppColors.gold,
    AppColors.goldTint,
  );
}

class _SuggestionCard extends StatefulWidget {
  const _SuggestionCard({
    required this.text,
    required this.reviewed,
    required this.onTap,
  });

  final String text;
  final bool reviewed;
  final VoidCallback onTap;

  @override
  State<_SuggestionCard> createState() => _SuggestionCardState();
}

class _SuggestionCardState extends State<_SuggestionCard>
    with SingleTickerProviderStateMixin {
  late final _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  @override
  void didUpdateWidget(covariant _SuggestionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.reviewed && widget.reviewed) {
      _pop.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final meta = _suggestionMeta(widget.text);
    final reviewed = widget.reviewed;
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: reviewed ? AppColors.mintBorder : AppColors.creamBorder,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: meta.tint,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  alignment: Alignment.center,
                  child: Icon(meta.icon, size: 13, color: meta.color),
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    meta.label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                      color: meta.color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Text(
                widget.text,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: reviewed ? AppColors.textMuted : AppColors.ink,
                  decoration: reviewed ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            const SizedBox(height: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 7),
              decoration: BoxDecoration(
                color: reviewed ? AppColors.teal : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: reviewed ? AppColors.teal : AppColors.creamBorder,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ScaleTransition(
                    scale: reviewed
                        ? CurvedAnimation(
                            parent: _pop,
                            curve: Curves.easeOutBack,
                          )
                        : const AlwaysStoppedAnimation(1.0),
                    child: Icon(
                      reviewed
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked,
                      size: 15,
                      color: reviewed ? Colors.white : AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    reviewed ? 'Practiced' : 'Mark practiced',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: reviewed ? Colors.white : AppColors.textMuted,
                    ),
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

class _SettingsTab extends ConsumerWidget {
  const _SettingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final volumes = ref.watch(volumeProvider);
    final volumeNotifier = ref.read(volumeProvider.notifier);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        const _SettingsHero(
          title: 'Dashboard Settings',
          subtitle: 'Configure sound volumes and local data',
        ),
        Transform.translate(
          offset: const Offset(0, -22),
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StaggerFadeIn(
                  delay: const Duration(milliseconds: 40),
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
                const SizedBox(height: 14),
                const _StaggerFadeIn(
                  delay: Duration(milliseconds: 110),
                  child: _SyncCard(),
                ),
                const SizedBox(height: 14),
                const _StaggerFadeIn(
                  delay: Duration(milliseconds: 135),
                  child: EmailVerificationCard(),
                ),
                const SizedBox(height: 14),
                const _StaggerFadeIn(
                  delay: Duration(milliseconds: 160),
                  child: _LinkFirebaseCard(),
                ),
                const SizedBox(height: 14),
                const _StaggerFadeIn(
                  delay: Duration(milliseconds: 210),
                  child: _EraseCard(),
                ),
                const SizedBox(height: 14),
                const _StaggerFadeIn(
                  delay: Duration(milliseconds: 260),
                  child: _ExitSettingsCard(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Full-bleed settings masthead — same recipe as the Progress tab's own
/// hero (ambient breathing blobs + fade/slide-down entrance) so Settings
/// isn't a lone boxed card floating on a plain background.
class _SettingsHero extends StatefulWidget {
  const _SettingsHero({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  State<_SettingsHero> createState() => _SettingsHeroState();
}

class _SettingsHeroState extends State<_SettingsHero>
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
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 46),
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
            FadeTransition(
              opacity: _fade,
              child: SlideTransition(
                position: _slide,
                child: Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.tune_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.subtitle,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
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
      color: AppColors.mint,
      borderColor: AppColors.mintBorder,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Sync Now', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                const Text(
                  'Sync local device progress with cloud servers.',
                  style: TextStyle(fontSize: 12, color: AppColors.tealDark),
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
      color: AppColors.coralTint,
      borderColor: AppColors.coral,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Erase Local Data',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                const Text(
                  'Permanently delete all stored profiles and progress data.',
                  style: TextStyle(fontSize: 12, color: AppColors.ink),
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
