import 'dart:math';

import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData, SystemUiOverlayStyle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../data/repositories/class_repository.dart';
import '../../data/repositories/progress_repository.dart';
import '../../logic/auth/session.dart';
import '../../logic/settings/settings_providers.dart';
import '../../logic/sync/sync_manager.dart';
import '../../logic/teacher/teacher_providers.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_loading_overlay.dart';
import '../widgets/flat_dashboard_header.dart';
import '../widgets/mock_icons.dart';
import '../widgets/soft_card.dart';
import '../widgets/top_tab_bar.dart';
import '../widgets/app_time_picker.dart';

/// Live/presentation-mode toggle (FR-6.5) — not persisted; it only makes
/// sense for the duration of an active casting session, so it stays a
/// plain in-memory Notifier like before.
class ProgressionOverrideNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle(bool value) => state = value;
}

final progressionOverrideProvider =
    NotifierProvider<ProgressionOverrideNotifier, bool>(
      ProgressionOverrideNotifier.new,
    );

/// Greeting line for the Teacher Home tab — addresses the Asatidz by their
/// own name, same pattern as the Parent Dashboard's Progress-screen
/// greeting (`_parentGreeting` in `parent_dashboard_screen.dart`). Falls
/// back to the generic greeting for a bare PIN-only bootstrap account with
/// no name on file yet.
String _teacherGreeting(WidgetRef ref, {bool caps = false}) {
  final name = ref.read(sessionProvider.notifier).activeTeacherFullName;
  if (name == null || name.isEmpty) {
    return caps
        ? "TODAY'S PROGRESS"
        : "Assalamu'alaikum, here's your class progress summary";
  }
  return caps
      ? "ASSALAMU'ALAIKUM, ${name.toUpperCase()}"
      : "Assalamu'alaikum, $name — here's your class progress summary";
}

class TeacherDashboardScreen extends ConsumerWidget {
  const TeacherDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watches the teacher's Firestore document in real time. If the admin
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
        context.go('/roles');
        await ref.read(sessionProvider.notifier).logout();
      });
    });

    // See the matching comment in `parent_dashboard_screen.dart`'s
    // `ParentDashboardScreen.build` — same "no PopScope here fell through
    // to go_router's default history-pop, silently landing on the role
    // picker with `pinVerified` still true" bug.
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide =
              constraints.maxWidth >= 800 && constraints.maxHeight >= 550;
          return wide
              ? _WideLayout(initialTab: initialTab)
              : _PhoneLayout(initialTab: initialTab);
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

/// Broadcast-ripple confirmation played over whichever "Cast to class"
/// control was tapped (hero icon, wide-layout button, or the action-column
/// button) — a real feedback beat for a real action, not decoration for its
/// own sake. Falls back to a plain Flutter-drawn ripple if the Lottie asset
/// fails to parse, so a malformed animation can't take the button down.
void _playCastRipple(BuildContext context) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  var removed = false;
  void safeRemove() {
    if (removed) return;
    removed = true;
    entry.remove();
  }

  entry = OverlayEntry(
    builder: (context) => IgnorePointer(
      child: Center(
        child: SizedBox(
          width: 180,
          height: 180,
          child: Lottie.asset(
            'assets/lottie/cast_ripple.json',
            repeat: false,
            errorBuilder: (context, error, stackTrace) =>
                const _FallbackRipple(),
            onLoaded: (composition) {
              Future.delayed(composition.duration, safeRemove);
            },
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  // Safety net in case onLoaded never fires (e.g. the errorBuilder path).
  Future.delayed(const Duration(milliseconds: 1200), safeRemove);
}

class _FallbackRipple extends StatelessWidget {
  const _FallbackRipple();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOut,
      builder: (context, t, _) => Opacity(
        opacity: 1 - t,
        child: Container(
          width: 40 + 140 * t,
          height: 40 + 140 * t,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.teal, width: 6),
          ),
        ),
      ),
    );
  }
}

Color masteryBg(String mastery) => switch (mastery) {
  'High' => AppColors.mint,
  'Medium' => AppColors.goldTint,
  _ => AppColors.coralTint,
};

Color masteryFg(String mastery) => switch (mastery) {
  'High' => AppColors.tealDark,
  'Medium' => const Color(0xFF8A5A12),
  _ => AppColors.coral,
};

Color masteryBarColor(String mastery) => switch (mastery) {
  'High' => AppColors.teal,
  'Medium' => AppColors.gold,
  _ => AppColors.coral,
};

Color avatarColor(String mastery) => switch (mastery) {
  'High' => AppColors.mintGreen,
  'Medium' => AppColors.goldSoft,
  _ => AppColors.coral,
};

// ---------------------------------------------------------------- phone

class _PhoneLayout extends ConsumerStatefulWidget {
  const _PhoneLayout({this.initialTab = 0});

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
    duration: const Duration(milliseconds: 800),
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
    TopTabItem(iconPath: MockIcons.home, label: 'Home'),
    TopTabItem(iconPath: MockIcons.classroom, label: 'Classroom'),
    TopTabItem(iconPath: MockIcons.settings, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final activeClass = ref.watch(activeClassNameProvider);
    final formattedName = activeClass.replaceAll('Section ', '');
    final studentCount = ref.watch(teacherRosterProvider).length;

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
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.mint,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.teal, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.school_rounded,
                        size: 18,
                        color: AppColors.teal,
                      ),
                    ),
                  ),
                  eyebrow: formattedName,
                  title: 'Class overview',
                  statusLabel: '$studentCount students synced',
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
                child: Stack(
                  children: [
                    _PanelRise(
                      key: ValueKey(_currentTab),
                      child: switch (_currentTab) {
                    0 => ListView(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                      children: [
                        const _StaggerFadeIn(
                          delay: Duration.zero,
                          child: _ClassPulseCard(),
                        ),
                        const SizedBox(height: 16),
                        const _StaggerFadeIn(
                          delay: Duration(milliseconds: 30),
                          child: _RosterSection(),
                        ),
                        const SizedBox(height: 16),
                        _StaggerFadeIn(
                          delay: const Duration(milliseconds: 60),
                          child: _ActionColumn(
                            onCast: () {
                              _playCastRipple(context);
                              context.go('/cast');
                            },
                          ),
                        ),
                      ],
                    ),
                    1 => ListView(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
                      children: [
                        const _SectionLabel('MANAGE'),
                        const SizedBox(height: 10),
                        const _StaggerFadeIn(
                          delay: Duration.zero,
                          child: _ClassManagementEntryCard(),
                        ),
                        const SizedBox(height: 10),
                        const _StaggerFadeIn(
                          delay: Duration(milliseconds: 10),
                          child: _HomeModeInsightsEntryCard(),
                        ),
                        const SizedBox(height: 22),
                        const _SectionLabel('CLASS HEALTH'),
                        const SizedBox(height: 10),
                        const _StaggerFadeIn(
                          delay: Duration(milliseconds: 20),
                          child: _ActiveClassHealthSection(),
                        ),
                        const SizedBox(height: 22),
                        const _SectionLabel('CREATE A CLASS'),
                        const SizedBox(height: 10),
                        const _StaggerFadeIn(
                          delay: Duration(milliseconds: 30),
                          child: _CreateClassCard(),
                        ),
                        const SizedBox(height: 22),
                        const _SectionLabel('CLASS PASS'),
                        const SizedBox(height: 10),
                        const _StampIn(
                          delay: Duration(milliseconds: 280),
                          child: _ClassPassCard(),
                        ),
                      ],
                    ),
                    _ => const _SettingsTab(),
                  },
                    ),
                    if (_currentTab == 0)
                      Positioned(
                        right: 18,
                        bottom: 18,
                        child: _CastFab(
                          onTap: () {
                            _playCastRipple(context);
                            context.go('/cast');
                          },
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

class _CastFab extends StatelessWidget {
  const _CastFab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'teacher_cast_fab',
      backgroundColor: AppColors.teal,
      tooltip: 'Cast to class',
      onPressed: onTap,
      child: const Icon(Icons.cast_rounded, color: Colors.white),
    );
  }
}


// ----------------------------------------------------------------- wide

class _WideLayout extends ConsumerStatefulWidget {
  const _WideLayout({this.initialTab = 0});

  final int initialTab;

  @override
  ConsumerState<_WideLayout> createState() => _WideLayoutState();
}

class _WideLayoutState extends ConsumerState<_WideLayout>
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

  @override
  Widget build(BuildContext context) {
    final activeClass = ref.watch(activeClassNameProvider);

    return Scaffold(
      backgroundColor: AppColors.neutralTint,
      body: Row(
        children: [
          _SideRail(activeTab: _currentTab, onTabChanged: _switchTab),
          Expanded(
            child: SafeArea(
              child: _PanelRise(
                key: ValueKey(_currentTab),
                child: switch (_currentTab) {
                  0 => Padding(
                    padding: const EdgeInsets.all(26),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    activeClass,
                                    style: const TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _teacherGreeting(ref),
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
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
                            const SizedBox(width: 10),
                            OutlinedButton.icon(
                              onPressed: () {
                                _playCastRipple(context);
                                context.go('/cast');
                              },
                              icon: const Icon(Icons.cast, size: 18),
                              label: const Text('Cast to class'),
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
                        const _StaggerFadeIn(
                          delay: Duration.zero,
                          child: _ClassPulseCard(wide: true),
                        ),
                        const SizedBox(height: 20),
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: _StaggerFadeIn(
                                  delay: const Duration(milliseconds: 30),
                                  child: const _StudentTable(),
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                flex: 2,
                                child: _StaggerFadeIn(
                                  delay: const Duration(milliseconds: 30),
                                  child: _ActionColumn(
                                    onCast: () {
                                      _playCastRipple(context);
                                      context.go('/cast');
                                    },
                                    panelStyle: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  1 => SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _ClassroomHero(wide: true),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(30, 24, 30, 30),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 6,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: const [
                                    _StaggerFadeIn(
                                      delay: Duration(milliseconds: 60),
                                      child: _ClassManagementEntryCard(),
                                    ),
                                    SizedBox(height: 16),
                                    _SectionLabel('CLASS HEALTH'),
                                    SizedBox(height: 10),
                                    _StaggerFadeIn(
                                      delay: Duration(milliseconds: 120),
                                      child: _ActiveClassHealthSection(),
                                    ),
                                    SizedBox(height: 10),
                                    _StaggerFadeIn(
                                      delay: Duration(milliseconds: 140),
                                      child: _HomeModeInsightsEntryCard(),
                                    ),
                                    SizedBox(height: 16),
                                    _SectionLabel('CREATE A CLASS'),
                                    SizedBox(height: 10),
                                    _StaggerFadeIn(
                                      delay: Duration(milliseconds: 160),
                                      child: _CreateClassCard(),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 20),
                              const Expanded(
                                flex: 5,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _SectionLabel('CLASS PASS'),
                                    SizedBox(height: 10),
                                    _StampIn(
                                      delay: Duration(milliseconds: 280),
                                      child: _ClassPassCard(
                                        notchColor: AppColors.neutralTint,
                                      ),
                                    ),
                                  ],
                                ),
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
              child: const Icon(Icons.school, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 22),
            _RailItem(
              icon: Icons.groups_outlined,
              label: 'Home',
              active: activeTab == 0,
              onTap: () => onTabChanged(0),
            ),
            const SizedBox(height: 6),
            _RailItem(
              icon: Icons.assignment_ind_outlined,
              label: 'Classroom',
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
    final color = active ? Colors.white : Colors.white60;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 72,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? Colors.white12 : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
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

// ----------------------------------------------------------------- components

/// Tab-panel entrance used by the top-tab shell — Parent Hub's per-panel
/// "rise" (fade + slide-up), sped up for this hub (100ms vs Parent's 200ms).
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
    duration: const Duration(milliseconds: 60),
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

/// Home tab's students preview — only the 3 most recent, with a
/// "See all" link to the active class's full roster (`ClassDetailScreen`),
/// since the complete student list now lives on the Classroom tab/screens
/// rather than duplicated here.
class _RosterSection extends ConsumerWidget {
  const _RosterSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(teacherRosterProvider);
    final activeClassId = ref.watch(teacherClassControllerProvider)?.id;
    final preview = list.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'STUDENTS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: AppColors.textMuted,
              ),
            ),
            if (activeClassId != null)
              TextButton(
                onPressed: () =>
                    context.go('/teacher/classes/$activeClassId?from=home'),
                child: const Text('See all'),
              ),
          ],
        ),
        const SizedBox(height: 4),
        if (preview.isEmpty)
          const _NoStudentsCard()
        else
          for (final s in preview)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _StudentCard(
                student: s,
                name: s['name'] as String,
                completion: s['completion'] as double,
                tracing: s['tracing'] as String,
                activity: s['activity'] as String,
                mastery: s['mastery'] as String,
              ),
            ),
      ],
    );
  }
}

/// Shown in place of the roster preview when the active class has no
/// enrolled students yet — without this, `_RosterSection` just rendered
/// the "STUDENTS" header over blank space, giving no indication of
/// whether the roster was empty or just still loading.
class _NoStudentsCard extends StatelessWidget {
  const _NoStudentsCard();

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        children: [
          const Icon(
            Icons.people_outline_rounded,
            size: 28,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 10),
          const Text(
            'No students in this class yet',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 6),
          const Text(
            'Share your class invitation code so parents can enroll their '
            'child.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _StudentCard extends ConsumerWidget {
  const _StudentCard({
    required this.student,
    required this.name,
    required this.completion,
    required this.tracing,
    required this.activity,
    required this.mastery,
  });

  final Map<String, dynamic> student;
  final String name;
  final double completion;
  final String tracing;
  final String activity;
  final String mastery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _PressScale(
      builder: (context, setPressed) => GestureDetector(
        onTapDown: (_) => setPressed(true),
        onTapCancel: () => setPressed(false),
        onTapUp: (_) => setPressed(false),
        onTap: () => showStudentDetails(context, ref, student),
        child: SoftCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: masteryBarColor(mastery), width: 2),
                ),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: avatarColor(mastery),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    name[0].toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: Theme.of(context).textTheme.bodyLarge),
                    const SizedBox(height: 3),
                    Text(
                      '$tracing tracing · active $activity',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: completion),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOutCubic,
                        builder: (context, val, child) {
                          return LinearProgressIndicator(
                            value: val,
                            minHeight: 6,
                            backgroundColor: AppColors.creamDark,
                            color: masteryBarColor(mastery),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              MasteryPill(mastery: mastery, dotted: true),
            ],
          ),
        ),
      ),
    );
  }
}

class MasteryPill extends StatelessWidget {
  const MasteryPill({super.key, required this.mastery, this.dotted = false});

  final String mastery;
  final bool dotted;

  @override
  Widget build(BuildContext context) {
    if (dotted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: masteryBg(mastery),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: masteryFg(mastery),
                shape: BoxShape.circle,
              ),
            ),
            Text(
              mastery.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: masteryBg(mastery),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        mastery,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: masteryFg(mastery),
        ),
      ),
    );
  }
}

/// Focal class-health metric replacing the old flat 4-box stat row: a
/// radial avg-mastery ring (real data from [teacherRosterProvider], same
/// average the old row computed) plus mastery-tier count chips — used on
/// both phone (new placement, directly under the hero) and wide (replacing
/// the old row in the same slot).
class _ClassPulseCard extends ConsumerWidget {
  const _ClassPulseCard({this.wide = false});

  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(teacherRosterProvider);
    final avgCompletion = list.isEmpty
        ? 0.0
        : list.map((s) => s['completion'] as double).reduce((a, b) => a + b) /
              list.length;
    final counts = {
      for (final m in ['High', 'Medium', 'Needs help'])
        m: list.where((s) => s['mastery'] == m).length,
    };
    final ringSize = wide ? 128.0 : 96.0;

    return SoftCard(
      padding: EdgeInsets.all(wide ? 20 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: avgCompletion.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, t, _) => SizedBox(
              width: ringSize,
              height: ringSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: Size(ringSize, ringSize),
                    painter: _MasteryRingPainter(progress: t),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(t * 100).round()}%',
                        style: TextStyle(
                          fontSize: ringSize * 0.22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        'Avg. mastery',
                        style: TextStyle(
                          fontSize: ringSize * 0.09,
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: wide ? 24 : 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _MasteryCountChip(
                  label: 'High mastery',
                  count: counts['High']!,
                  color: AppColors.teal,
                  bg: AppColors.mint,
                ),
                const SizedBox(height: 8),
                _MasteryCountChip(
                  label: 'Medium mastery',
                  count: counts['Medium']!,
                  color: const Color(0xFF8A5A12),
                  bg: AppColors.goldTint,
                ),
                const SizedBox(height: 8),
                _MasteryCountChip(
                  label: 'Needs help',
                  count: counts['Needs help']!,
                  color: AppColors.coral,
                  bg: AppColors.coralTint,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MasteryCountChip extends StatelessWidget {
  const _MasteryCountChip({
    required this.label,
    required this.count,
    required this.color,
    required this.bg,
  });

  final String label;
  final int count;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MasteryRingPainter extends CustomPainter {
  _MasteryRingPainter({required this.progress});

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
  bool shouldRepaint(covariant _MasteryRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Class Health Index (FR-6.2) — one row per Hot Seat letter showing
/// how many students were called up, average tracing accuracy,
/// week-over-week trend, rolled into a single health-tier pill. Scoped
/// exclusively to `isClassroomMode` telemetry (Hot Seat/Choral) per
/// `dumps/class-health-index-fix.html` — solo Student Hub/Adventure Map
/// play at home never counts here, hence the "CLASSROOM MODE" scope tag
/// (see `dumps/teacher-classroom-mobile.html`). Reuses [masteryBg]/
/// [masteryFg]'s existing High/Medium/Needs-help thresholds rather than
/// inventing new colors.
class ClassHealthSection extends ConsumerWidget {
  const ClassHealthSection({super.key, required this.classId});

  final String classId;

  static String _tierFor(int healthIndex) {
    if (healthIndex >= 80) return 'High';
    if (healthIndex >= 50) return 'Medium';
    return 'Needs help';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modules = ref.watch(classHealthIndexProvider(classId));

    return SoftCard(
      onTap: () => context.push('/teacher/classes/$classId/health'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Expanded(
                child: Text(
                  'CLASS HEALTH INDEX',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(6, 3, 8, 3),
                decoration: BoxDecoration(
                  color: AppColors.mint,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.mintBorder),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cast_rounded, size: 10, color: AppColors.teal),
                    SizedBox(width: 5),
                    Text(
                      'CLASSROOM MODE',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        color: AppColors.teal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Hot Seat tracing attempts from live Cast sessions — not '
            'Adventure Map/Student Hub solo play.',
            style: TextStyle(fontSize: 10.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          for (final module in modules)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ModuleHealthRow(
                module: module,
                tier: _tierFor(module.healthIndex),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'See details',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.teal,
                ),
              ),
              const SizedBox(width: 2),
              const Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: AppColors.teal,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModuleHealthRow extends StatelessWidget {
  const _ModuleHealthRow({required this.module, required this.tier});

  final ModuleHealth module;
  final String tier;

  /// The Hot Seat letter itself, recovered from `hot_seat_<letter>` — kept
  /// derived rather than a new [ModuleHealth] field since the moduleId
  /// already carries it and nothing else needs the letter in isolation.
  String get _letterGlyph => module.moduleId.replaceFirst('hot_seat_', '');

  @override
  Widget build(BuildContext context) {
    if (!module.hasActivity) {
      return Row(
        children: [
          Text(
            _letterGlyph,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.tealDark,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              module.moduleName,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          const Text(
            'Not cast yet this week',
            style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
          ),
        ],
      );
    }

    final trend = module.trend;
    Widget trendIcon = const SizedBox(width: 16);
    if (trend != null && trend > 0) {
      trendIcon = const Icon(
        Icons.arrow_upward_rounded,
        size: 16,
        color: AppColors.teal,
      );
    } else if (trend != null && trend < 0) {
      trendIcon = const Icon(
        Icons.arrow_downward_rounded,
        size: 16,
        color: AppColors.coral,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              _letterGlyph,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.tealDark,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                module.moduleName,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
            trendIcon,
            const SizedBox(width: 6),
            MasteryPill(mastery: tier, dotted: true),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: module.completionRate),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (context, val, child) {
              return LinearProgressIndicator(
                value: val,
                minHeight: 6,
                backgroundColor: AppColors.creamDark,
                color: masteryBarColor(tier),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${module.avgAccuracy.round()}% avg stroke accuracy · '
          '${module.attemptCount} attempt${module.attemptCount == 1 ? '' : 's'} · '
          '${module.studentsUp} student${module.studentsUp == 1 ? '' : 's'} up',
          style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

/// Resolves the currently-active class before handing off to
/// [ClassHealthSection] — kept separate so [ClassHealthSection] itself
/// only depends on a plain `classId`, not the active-class provider.
class _ActiveClassHealthSection extends ConsumerWidget {
  const _ActiveClassHealthSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = ref.watch(teacherClassControllerProvider);
    if (section == null) return const SizedBox.shrink();
    return ClassHealthSection(classId: section.id);
  }
}

/// Home tab's students preview (wide layout) — only the 3 most
/// recent, with a "See all" link to the active class's full roster.
class _StudentTable extends ConsumerWidget {
  const _StudentTable();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(teacherRosterProvider);
    final activeClassId = ref.watch(teacherClassControllerProvider)?.id;
    final preview = list.take(3).toList();

    return SoftCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Student roster',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (activeClassId != null)
                  TextButton(
                    onPressed: () =>
                        context.go('/teacher/classes/$activeClassId?from=home'),
                    child: const Text('See all'),
                  ),
              ],
            ),
          ),
          if (preview.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 20),
              child: _NoStudentsCard(),
            )
          else
            DataTable(
              columnSpacing: 14,
              horizontalMargin: 16,
              showCheckboxColumn: false,
              columns: const [
                DataColumn(label: Text('Name')),
                DataColumn(label: Text('Completion')),
                DataColumn(label: Text('Tracing')),
                DataColumn(label: Text('Mastery')),
              ],
              rows: [
                for (final s in preview)
                  DataRow(
                    onSelectChanged: (_) => showStudentDetails(context, ref, s),
                    cells: [
                      DataCell(
                        Text(
                          s['name'] as String,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 70,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween<double>(
                                begin: 0.0,
                                end: s['completion'] as double,
                              ),
                              duration: const Duration(milliseconds: 900),
                              curve: Curves.easeOutCubic,
                              builder: (context, val, child) {
                                return LinearProgressIndicator(
                                  value: val,
                                  minHeight: 5,
                                  backgroundColor: AppColors.creamDark,
                                  color: masteryBarColor(s['mastery'] as String),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      DataCell(Text(s['tracing'] as String)),
                      DataCell(MasteryPill(mastery: s['mastery'] as String)),
                    ],
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ActionColumn extends ConsumerWidget {
  const _ActionColumn({required this.onCast, this.panelStyle = false});

  final VoidCallback onCast;
  final bool panelStyle;

  void _openHotSeat(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _HotSeatSheet(),
    );
  }

  void _openChoral(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            Text(
              'Choral Controller (Talqeen)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.ink,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Trigger repeat-after-me audio loops class-wide.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            SizedBox(height: 16),
            _ChoralPlayer(),
          ],
        ),
      ),
    );
  }

  void _openOverride(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) => Consumer(
        builder: (context, ref, child) {
          final isOverriding = ref.watch(progressionOverrideProvider);
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Progression Override Settings',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Allows student to access presentation mode elements even if locked.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
                const SizedBox(height: 20),
                SwitchListTile.adaptive(
                  title: const Text(
                    'Bypass Progression Constraints',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Allow class-wide access to presentation modules',
                  ),
                  value: isOverriding,
                  onChanged: (val) {
                    ref.read(progressionOverrideProvider.notifier).toggle(val);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Progression lock override: ${val ? "ON" : "OFF"}',
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openHomework(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: const [
              Text(
                'Assign Homework',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Assign specific learning modules to class roster.',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
              SizedBox(height: 16),
              _HomeworkAssigner(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final specs =
        <
          ({
            IconData icon,
            String label,
            Color color,
            Color bg,
            VoidCallback onTap,
          })
        >[
          (
            icon: Icons.add_task_rounded,
            label: 'Assign homework',
            color: AppColors.teal,
            bg: AppColors.mint,
            onTap: () => _openHomework(context),
          ),
          (
            icon: Icons.airline_seat_recline_normal_rounded,
            label: 'Hot seat',
            color: AppColors.gold,
            bg: AppColors.goldTint,
            onTap: () => _openHotSeat(context),
          ),
          (
            icon: Icons.record_voice_over_rounded,
            label: 'Choral controller',
            color: AppColors.coral,
            bg: AppColors.coralTint,
            onTap: () => _openChoral(context),
          ),
          (
            icon: Icons.lock_outline_rounded,
            label: 'Progression override',
            color: AppColors.mintGreen,
            bg: AppColors.mint,
            onTap: () => _openOverride(context, ref),
          ),
          (
            icon: Icons.view_module_rounded,
            label: 'Module library',
            color: AppColors.coral,
            bg: AppColors.coralTint,
            onTap: () => context.push('/teacher/module-library'),
          ),
          (
            icon: Icons.campaign_rounded,
            label: 'Cast Greeting Match',
            color: AppColors.teal,
            bg: AppColors.mint,
            onTap: () => context.push('/cast-greeting-match'),
          ),
        ];

    if (panelStyle) {
      return SoftCard(
        color: AppColors.surface,
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CLASS TOOLS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 10),
              for (final (i, s) in specs.indexed)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: i == specs.length - 1 ? 0 : 10,
                  ),
                  child: _ActionTile(
                    icon: s.icon,
                    label: s.label,
                    color: s.color,
                    iconBg: s.bg,
                    onTap: s.onTap,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              Icon(Icons.bolt_rounded, size: 14, color: AppColors.textMuted),
              SizedBox(width: 4),
              Text(
                'QUICK ACTIONS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        _ActionRowTile(
          icon: const MockIcon(
            MockIcons.homework,
            size: 18,
            color: AppColors.teal,
          ),
          label: 'Assign homework',
          onTap: () => _openHomework(context),
        ),
        const SizedBox(height: 10),
        _ActionRowTile(
          icon: const MockIcon(
            MockIcons.lock,
            size: 18,
            color: AppColors.teal,
          ),
          label: 'Progression override',
          onTap: () => _openOverride(context, ref),
        ),
        const SizedBox(height: 10),
        _ActionRowTile(
          icon: const Icon(
            Icons.grid_view_rounded,
            size: 18,
            color: AppColors.teal,
          ),
          label: 'Module library',
          onTap: () => context.push('/teacher/module-library'),
        ),
      ],
    );
  }
}

class _ActionRowTile extends StatelessWidget {
  const _ActionRowTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Widget icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _PressScale(
      builder: (context, setPressed) => GestureDetector(
        onTapDown: (_) => setPressed(true),
        onTapCancel: () => setPressed(false),
        onTapUp: (_) => setPressed(false),
        onTap: onTap,
        child: SoftCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.neutralTint,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: icon,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Same fade/slide-in-scale "_PressScale" pattern used by the Student Hub's
/// continue card — kept as a small per-file copy rather than a shared
/// widget, matching this codebase's existing convention (see `_FadeUp`/
/// `_Blob`, also duplicated per dashboard file).
class _PressScale extends StatefulWidget {
  const _PressScale({required this.builder});

  final Widget Function(BuildContext context, ValueChanged<bool> setPressed)
  builder;

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: widget.builder(context, (v) => setState(() => _pressed = v)),
    );
  }
}

/// List-row tool tile (used in the wide side panel) with a tinted icon
/// chip — rotates mint/gold/coral/mint per the design system's icon-chip
/// convention instead of a single monochrome icon for every row.
class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.iconBg,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color iconBg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _PressScale(
      builder: (context, setPressed) => GestureDetector(
        onTapDown: (_) => setPressed(true),
        onTapCancel: () => setPressed(false),
        onTapUp: (_) => setPressed(false),
        onTap: onTap,
        child: SoftCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 17, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
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

/// Icon-forward grid tile (phone Home tab) — a 2x2 grid replaces the old
/// vertical tool list for a more scannable, less list-heavy composition,
/// with the same tinted icon chip + press-scale feedback as [_ActionTile].
class _ActionGridTile extends StatelessWidget {
  const _ActionGridTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.iconBg,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color iconBg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _PressScale(
      builder: (context, setPressed) => GestureDetector(
        onTapDown: (_) => setPressed(true),
        onTapCancel: () => setPressed(false),
        onTapUp: (_) => setPressed(false),
        onTap: onTap,
        child: SoftCard(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 19, color: color),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void showStudentDetails(
  BuildContext context,
  WidgetRef ref,
  Map<String, dynamic> student,
) {
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Student details',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (dialogContext, animation, secondaryAnimation) =>
        StudentDetailsDialog(student: student),
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

class StudentDetailsDialog extends ConsumerStatefulWidget {
  const StudentDetailsDialog({super.key, required this.student});
  final Map<String, dynamic> student;

  @override
  ConsumerState<StudentDetailsDialog> createState() =>
      StudentDetailsDialogState();
}

class StudentDetailsDialogState extends ConsumerState<StudentDetailsDialog> {
  late final TextEditingController _feedbackC;
  String _selectedModule = 'Letters Tracing (Alif to Kha)';
  DateTime _dueDate = DateTime.now().add(const Duration(days: 3));

  final _modules = [
    'Letters Tracing (Alif to Kha)',
    'Alphabet Song Practice',
    'Pronunciation of Letter ج',
    'Wudhu Sequence Matcher',
  ];

  @override
  void initState() {
    super.initState();
    _feedbackC = TextEditingController(text: widget.student['feedback'] ?? '');
  }

  @override
  void dispose() {
    _feedbackC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Find the latest state of this student from the provider
    final students = ref.watch(teacherRosterProvider);
    final currentStudent = students.firstWhere(
      (s) => s['name'] == widget.student['name'],
      orElse: () => widget.student,
    );

    final assigned = currentStudent['assignedModules'] as List<dynamic>? ?? [];
    final name = currentStudent['name'] as String;
    final mastery = currentStudent['mastery'] as String;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 640),
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
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Colors.white24,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        name.isEmpty ? '?' : name[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              mastery.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                                color: Colors.white,
                              ),
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
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Progress stat strip
                      Row(
                        children: [
                          Expanded(
                            child: _DialogStat(
                              icon: Icons.gesture_rounded,
                              value: '${currentStudent['tracing']}',
                              label: 'Tracing',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _DialogStat(
                              icon: Icons.check_circle_outline_rounded,
                              value:
                                  '${(currentStudent['completion'] * 100).round()}%',
                              label: 'Completion',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _DialogStat(
                        icon: Icons.access_time_rounded,
                        value: '${currentStudent['activity']}',
                        label: 'Recent activity',
                        wide: true,
                      ),

                      const SizedBox(height: 18),
                      SoftCard(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.add_task_rounded,
                                  size: 16,
                                  color: AppColors.teal,
                                ),
                                SizedBox(width: 7),
                                Text(
                                  'Assign Learning Module',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedModule,
                              decoration: const InputDecoration(
                                labelText: 'Select Module',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              items: _modules
                                  .map(
                                    (m) => DropdownMenuItem(
                                      value: m,
                                      child: Text(
                                        m,
                                        style: const TextStyle(fontSize: 12.5),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _selectedModule = v);
                                }
                              },
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.event_outlined,
                                      size: 14,
                                      color: AppColors.textMuted,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      '${_dueDate.day}/${_dueDate.month}/${_dueDate.year}',
                                      style: const TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                TextButton(
                                  onPressed: () async {
                                    final d = await showDatePicker(
                                      context: context,
                                      initialDate: _dueDate,
                                      firstDate: DateTime.now(),
                                      lastDate: DateTime.now().add(
                                        const Duration(days: 30),
                                      ),
                                    );
                                    if (d != null) setState(() => _dueDate = d);
                                  },
                                  child: const Text('Change Date'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () {
                                  final classId = ref
                                      .read(teacherClassControllerProvider)
                                      ?.id;
                                  if (classId == null) return;
                                  ClassRepository()
                                      .assignModule(
                                        classId: classId,
                                        learnerId:
                                            currentStudent['learnerId']
                                                as String,
                                        moduleId: _selectedModule,
                                        dueDate: _dueDate,
                                      )
                                      .then((_) {
                                        ref.invalidate(teacherRosterProvider);
                                        ref.invalidate(
                                          classRosterProvider(classId),
                                        );
                                      });

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Assigned "$_selectedModule" to $name',
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.add_task, size: 16),
                                label: Text('Assign to $name'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.gold,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                            if (assigned.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              const Divider(
                                height: 1,
                                color: AppColors.creamBorder,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'ASSIGNED (${assigned.length})',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              for (final item in assigned)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 5),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.assignment_turned_in,
                                        size: 14,
                                        color: AppColors.teal,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          item as String,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.ink,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),
                      SoftCard(
                        color: AppColors.neutralTint,
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.rate_review_outlined,
                                  size: 16,
                                  color: AppColors.teal,
                                ),
                                SizedBox(width: 7),
                                Text(
                                  'Teacher Assessment & Feedback',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _feedbackC,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                hintText:
                                    'Leave custom feedback or study notes for parents...',
                                filled: true,
                                fillColor: AppColors.surface,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 18, 16),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.creamBorder)),
                ),
                child: Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => _confirmRemoveFromClass(
                        context,
                        currentStudent['learnerId'] as String,
                        name,
                      ),
                      icon: const Icon(
                        Icons.person_remove_rounded,
                        color: AppColors.coral,
                        size: 16,
                      ),
                      label: const Text(
                        'Remove',
                        style: TextStyle(
                          color: AppColors.coral,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () {
                        ref
                            .read(teacherFeedbackProvider.notifier)
                            .setFeedback(
                              currentStudent['learnerId'] as String,
                              _feedbackC.text.trim(),
                            );
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Feedback saved successfully!'),
                          ),
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.teal,
                      ),
                      child: const Text('Save Feedback'),
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

  Future<void> _confirmRemoveFromClass(
    BuildContext context,
    String studentId,
    String studentName,
  ) async {
    final classId = ref.read(teacherClassControllerProvider)?.id;
    if (classId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: AppColors.coral,
          size: 40,
        ),
        title: const Text('Remove Student?'),
        content: Text(
          'Are you sure you want to remove "$studentName" from this class?\n\n'
          'Their homework assignments for this class will also be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.coral,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove Student'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      // Pop the details dialog first
      Navigator.of(context).pop();

      await ClassRepository().unenroll(classId: classId, learnerId: studentId);

      // Invalidate providers so the roster updates instantly
      ref.invalidate(teacherRosterProvider);
      ref.invalidate(classRosterProvider(classId));
      ref.read(rosterRefreshProvider.notifier).bump();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Removed $studentName from class')),
        );
      }
    }
  }
}

class _DialogStat extends StatelessWidget {
  const _DialogStat({
    required this.icon,
    required this.value,
    required this.label,
    this.wide = false,
  });

  final IconData icon;
  final String value;
  final String label;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: wide ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.teal),
          const SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                  height: 1,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Full-bleed masthead for the Classroom tab (approved redesign:
/// `dumps/teacher_classroom_redesign_mock.html`) — edge-to-edge gradient
/// banner with inline stat pills instead of a separate boxed KPI row.
/// [wide] widens the bottom padding/stat row to match the wide layout's
/// hero, which fills the whole main pane next to the side rail rather
/// than a phone-width column.
/// Full-bleed masthead — now with an ambient ["breathing" blob] layer
/// behind the content (matches the splash screen's own breathing-halo
/// pattern for cross-app consistency) plus a fade+slide-down entrance for
/// the masthead and a staggered fade+slide-up for the stat pills, so the
/// tab feels alive rather than a flat static banner.
class _ClassroomHero extends ConsumerStatefulWidget {
  const _ClassroomHero({this.wide = false});

  final bool wide;

  @override
  ConsumerState<_ClassroomHero> createState() => _ClassroomHeroState();
}

class _ClassroomHeroState extends ConsumerState<_ClassroomHero>
    with TickerProviderStateMixin {
  late final _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  )..forward();

  late final _breathe = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat(reverse: true);

  late final _titleFade = CurvedAnimation(
    parent: _entrance,
    curve: const Interval(0, 0.6, curve: Curves.easeOut),
  );
  late final _titleSlide = Tween<Offset>(
    begin: const Offset(0, -0.12),
    end: Offset.zero,
  ).animate(_titleFade);

  late final _statsFade = CurvedAnimation(
    parent: _entrance,
    curve: const Interval(0.35, 1, curve: Curves.easeOut),
  );
  late final _statsSlide = Tween<Offset>(
    begin: const Offset(0, 0.25),
    end: Offset.zero,
  ).animate(_statsFade);

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
            // Ambient layer: two soft breathing blobs, echoing the
            // HTML mock's hero::before/::after glows.
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
                FadeTransition(
                  opacity: _titleFade,
                  child: SlideTransition(
                    position: _titleSlide,
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
                            Icons.class_rounded,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Class Administration',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Manage rosters, codes & enrollment',
                                style: TextStyle(
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
                const SizedBox(height: 18),
                FadeTransition(
                  opacity: _statsFade,
                  child: SlideTransition(
                    position: _statsSlide,
                    child: Row(
                      children: [
                        Expanded(
                          child: _HeroStat(
                            icon: Icons.class_outlined,
                            value: '$classCount',
                            label: 'CLASSES',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _HeroStat(
                            icon: Icons.groups_outlined,
                            value: '$studentCount',
                            label: 'STUDENTS',
                          ),
                        ),
                        if (wide) const Spacer(flex: 2),
                      ],
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

class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.goldSoft),
          const SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.65),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
        color: AppColors.textMuted,
      ),
    );
  }
}

/// Self-contained staggered entrance (fade + slide-up) for a section that
/// doesn't share the tab's own `AnimationController` — each replays fresh
/// every time the Classroom tab is switched into, since the widget tree
/// underneath the tab switch is torn down and rebuilt on every visit.
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
    duration: const Duration(milliseconds: 140),
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
/// easing to rest) rather than a plain slide, since this is the redesign's
/// signature moment and deserves a more theatrical entrance than the
/// sections around it.
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

class _CreateClassCard extends StatelessWidget {
  const _CreateClassCard();

  void _showCreateClassSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _CreateClassSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      onTap: () => _showCreateClassSheet(context),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.goldTint,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.add_rounded,
              size: 24,
              color: AppColors.gold,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create a Class',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14.5,
                    color: AppColors.ink,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Set up a new section for this term.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FilledButton(
            onPressed: () => _showCreateClassSheet(context),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'New class',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const _weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

class _CreateClassSheet extends ConsumerStatefulWidget {
  const _CreateClassSheet();

  @override
  ConsumerState<_CreateClassSheet> createState() => _CreateClassSheetState();
}

class _CreateClassSheetState extends ConsumerState<_CreateClassSheet> {
  final _gradeLevelC = TextEditingController();
  final _sectionC = TextEditingController();
  final Set<int> _selectedWeekdays = {};
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  @override
  void dispose() {
    _gradeLevelC.dispose();
    _sectionC.dispose();
    super.dispose();
  }

  String _formatTime(TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showAppTimePicker(
      context: context,
      initialTime: (isStart ? _startTime : _endTime) ?? TimeOfDay.now(),
      label: isStart ? 'Start time' : 'End time',
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
  }

  String? _composeSchedule() {
    final days = _selectedWeekdays.toList()..sort();
    final dayPart = days.map((i) => _weekdayLabels[i]).join('/');
    final String timePart;
    if (_startTime != null && _endTime != null) {
      timePart = '${_formatTime(_startTime!)}–${_formatTime(_endTime!)}';
    } else if (_startTime != null) {
      timePart = _formatTime(_startTime!);
    } else {
      timePart = '';
    }
    if (dayPart.isEmpty && timePart.isEmpty) return null;
    if (dayPart.isEmpty) return timePart;
    if (timePart.isEmpty) return dayPart;
    return '$dayPart, $timePart';
  }

  Future<void> _createClass() async {
    final gradeLevel = _gradeLevelC.text.trim();
    final section = _sectionC.text.trim();
    if (gradeLevel.isEmpty || section.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter grade level and section')),
      );
      return;
    }

    await ref
        .read(teacherClassControllerProvider.notifier)
        .createClass(
          gradeLevel: gradeLevel,
          section: section,
          schedule: _composeSchedule(),
        );

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Class "$gradeLevel - Section $section" created successfully!',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.center,
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.creamBorder,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const Text(
              'Create a Class',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Set up a new section for this term.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _gradeLevelC,
                    decoration: const InputDecoration(
                      hintText: 'Grade 1',
                      labelText: 'Grade Level',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _sectionC,
                    decoration: const InputDecoration(
                      hintText: 'Section B',
                      labelText: 'Section',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Schedule (optional)',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < _weekdayLabels.length; i++)
                  ChoiceChip(
                    label: Text(_weekdayLabels[i]),
                    selected: _selectedWeekdays.contains(i),
                    onSelected: (selected) => setState(() {
                      if (selected) {
                        _selectedWeekdays.add(i);
                      } else {
                        _selectedWeekdays.remove(i);
                      }
                    }),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _selectedWeekdays.contains(i)
                          ? Colors.white
                          : AppColors.textMuted,
                    ),
                    selectedColor: AppColors.teal,
                    backgroundColor: Colors.white,
                    side: BorderSide(
                      color: _selectedWeekdays.contains(i)
                          ? AppColors.teal
                          : AppColors.creamBorder,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickTime(isStart: true),
                    icon: const Icon(Icons.access_time_rounded, size: 16),
                    label: Text(
                      _startTime == null ? 'Start time' : _formatTime(_startTime!),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.ink,
                      side: const BorderSide(color: AppColors.creamBorder),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickTime(isStart: false),
                    icon: const Icon(Icons.access_time_rounded, size: 16),
                    label: Text(
                      _endTime == null ? 'End time' : _formatTime(_endTime!),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.ink,
                      side: const BorderSide(color: AppColors.creamBorder),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _createClass,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create Class'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact entry card in the Profile tab that hands off to the dedicated
/// `/teacher/classes` screen — full per-class roster management (FR-6.1,
/// FR-6.2) lives there now, not inline here, since listing every class's
/// entire student roster doesn't fit comfortably in a scrolling profile tab.
class _ClassManagementEntryCard extends ConsumerWidget {
  const _ClassManagementEntryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classCount = ref.watch(teacherClassesProvider).length;

    return SoftCard(
      onTap: () => context.go('/teacher/classes'),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.mint,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.groups_outlined,
              size: 20,
              color: AppColors.teal,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Classroom Management',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  classCount == 0
                      ? 'No classes yet'
                      : '$classCount class${classCount == 1 ? '' : 'es'} · manage students',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textMuted,
                  ),
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

/// Entry point to [HomeModeDashboardScreen] (FR-6.2B) — solo Student Hub/
/// Adventure Map practice at home, kept as its own card rather than folded
/// into [ClassHealthSection] since that section is Classroom-Mode-only by
/// design (see that screen's doc comment).
class _HomeModeInsightsEntryCard extends StatelessWidget {
  const _HomeModeInsightsEntryCard();

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      onTap: () => context.push('/teacher/home-progress'),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.goldTint,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.home_outlined,
              size: 20,
              color: AppColors.gold,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Home Mode Insights',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: AppColors.ink,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'View longitudinal tracking & collective mastery trends',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textMuted,
                  ),
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

/// Signature element of the redesign (`dumps/teacher_classroom_redesign_mock.html`):
/// the invitation code as a stamped "Class Pass" ticket — dashed
/// perforation with punched notches, since sharing this code is the one
/// action that most characterizes this screen. Enrollment itself happens
/// on the dedicated Classroom Management screens
/// (`ClassroomManagementScreen`/`ClassDetailScreen`); this card is purely
/// for reading/copying the active class's code.
class _ClassPassCard extends ConsumerStatefulWidget {
  const _ClassPassCard({this.notchColor = AppColors.surface});

  /// Color of the two punched notches — must match whatever surface sits
  /// behind this card (white content sheet on phone, `neutralTint` on the
  /// wide layout's main pane) or the "cut" illusion breaks.
  final Color notchColor;

  @override
  ConsumerState<_ClassPassCard> createState() => _ClassPassCardState();
}

class _ClassPassCardState extends ConsumerState<_ClassPassCard> {
  bool _copied = false;

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final notchColor = widget.notchColor;
    final code = ref.watch(classInvitationCodeProvider);
    final className = ref.watch(activeClassNameProvider);

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
                      className,
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
                  code,
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
                      onPressed: _copied ? null : () => _copyCode(code),
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
        Positioned(left: -11, top: 39, child: _PassNotch(color: notchColor)),
        Positioned(right: -11, top: 39, child: _PassNotch(color: notchColor)),
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
/// short filled segments sized to fill whatever width it's given.
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

/// FR-6.6 — the Hot Seat bottom sheet's content. Step-driven: shows
/// [_HotSeatStudentPicker] first (reading the active class's roster off
/// [teacherRosterProvider]), then swaps to [_DrawingCanvas] once a student
/// is picked, matching the design spec's "picker step → canvas step" flow.
class _HotSeatSheet extends ConsumerStatefulWidget {
  const _HotSeatSheet();

  @override
  ConsumerState<_HotSeatSheet> createState() => _HotSeatSheetState();
}

class _HotSeatSheetState extends ConsumerState<_HotSeatSheet> {
  String? _pickedLearnerId;
  String? _pickedName;

  void _pick(String learnerId, String name) {
    setState(() {
      _pickedLearnerId = learnerId;
      _pickedName = name;
    });
  }

  void _onSaved(String name) {
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Saved to $name's progress")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final roster = ref.watch(teacherRosterProvider);
    final pickedName = _pickedName;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            pickedName == null ? 'Hot Seat Tracing Mode' : 'Hot Seat: $pickedName',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            pickedName == null
                ? 'Pick which student is up before launching the tracing canvas.'
                : "Enables the student to trace letters directly on this device.",
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          if (pickedName == null)
            _HotSeatStudentPicker(roster: roster, onPicked: _pick)
          else
            _DrawingCanvas(
              learnerId: _pickedLearnerId!,
              studentName: pickedName,
              onSaved: _onSaved,
            ),
        ],
      ),
    );
  }
}

/// FR-6.6 student selection — either tap a name (manual) or spin
/// [_HotSeatWheel] (randomized "draw lots"); both resolve to the same
/// (learnerId, name) handoff via [onPicked].
class _HotSeatStudentPicker extends StatefulWidget {
  const _HotSeatStudentPicker({required this.roster, required this.onPicked});

  final List<Map<String, dynamic>> roster;
  final void Function(String learnerId, String name) onPicked;

  @override
  State<_HotSeatStudentPicker> createState() => _HotSeatStudentPickerState();
}

class _HotSeatStudentPickerState extends State<_HotSeatStudentPicker> {
  bool _drawLots = false;
  bool _wheelSpinning = false;

  @override
  Widget build(BuildContext context) {
    if (widget.roster.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'No students enrolled yet — enroll students first.',
          style: TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                // Disabled mid-spin — switching away would unmount the
                // wheel and silently drop the in-flight pick.
                onPressed: _wheelSpinning
                    ? null
                    : () => setState(() => _drawLots = false),
                style: OutlinedButton.styleFrom(
                  backgroundColor: _drawLots ? null : AppColors.mint,
                  foregroundColor: AppColors.teal,
                ),
                child: const Text('Pick manually'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: _wheelSpinning
                    ? null
                    : () => setState(() => _drawLots = true),
                style: OutlinedButton.styleFrom(
                  backgroundColor: _drawLots ? AppColors.mint : null,
                  foregroundColor: AppColors.teal,
                ),
                child: const Text('Draw lots'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_drawLots)
          _HotSeatWheel(
            roster: widget.roster,
            onPicked: widget.onPicked,
            onSpinningChanged: (spinning) =>
                setState(() => _wheelSpinning = spinning),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final student in widget.roster)
                InkWell(
                  onTap: () => widget.onPicked(
                    student['learnerId'] as String,
                    student['name'] as String,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.neutralTint,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.creamBorder),
                    ),
                    child: Text(
                      student['name'] as String,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// FR-6.6 randomized selection — a segmented spinning wheel (one segment
/// per roster student) matching the approved `dumps/hot_seat_wheel_mock.html`
/// mock: a fixed AnimationController spin with a decelerating curve,
/// landing on a random student.
class _HotSeatWheel extends StatefulWidget {
  const _HotSeatWheel({
    required this.roster,
    required this.onPicked,
    required this.onSpinningChanged,
  });

  final List<Map<String, dynamic>> roster;
  final void Function(String learnerId, String name) onPicked;
  final ValueChanged<bool> onSpinningChanged;

  @override
  State<_HotSeatWheel> createState() => _HotSeatWheelState();
}

class _HotSeatWheelState extends State<_HotSeatWheel>
    with SingleTickerProviderStateMixin {
  static const _segmentColors = [
    AppColors.teal,
    AppColors.gold,
    AppColors.coral,
    AppColors.mintGreen,
    AppColors.adventureBlue,
    AppColors.adventurePurple,
  ];

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2500),
  );
  late final Animation<double> _spin = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  bool _spinning = false;
  double _restingTurns = 0;
  Tween<double> _spinTween = Tween<double>(begin: 0, end: 0);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _spinWheel() {
    if (_spinning || widget.roster.isEmpty) return;
    // Captured once at spin start — the parent disables the manual/wheel
    // toggle while spinning, but the roster itself could still change
    // (a student unenrolled mid-spin); indexing this captured copy instead
    // of re-reading `widget.roster` in `whenComplete` keeps `winnerIndex`
    // valid regardless.
    final roster = widget.roster;
    final winnerIndex = Random().nextInt(roster.length);
    final segmentTurns = 1 / roster.length;
    // Land the pointer (fixed at the top) on the middle of the winning
    // segment, plus a few extra full turns for visual flourish.
    final targetTurns =
        4 + 1 - (segmentTurns * winnerIndex + segmentTurns / 2);

    setState(() => _spinning = true);
    widget.onSpinningChanged(true);
    _controller.reset();
    _spinTween = Tween<double>(
      begin: _restingTurns,
      end: _restingTurns + targetTurns,
    );
    _controller.forward().whenComplete(() {
      if (!mounted) return;
      setState(() {
        _spinning = false;
        _restingTurns = (_restingTurns + targetTurns) % 1;
      });
      widget.onSpinningChanged(false);
      final winner = roster[winnerIndex];
      widget.onPicked(winner['learnerId'] as String, winner['name'] as String);
    });
  }

  @override
  Widget build(BuildContext context) {
    final roster = widget.roster;

    return Column(
      children: [
        SizedBox(
          width: 240,
          height: 240,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _spin,
                builder: (context, child) {
                  final turns = _spinTween.evaluate(_spin);
                  return Transform.rotate(
                    angle: turns * 2 * pi,
                    child: child,
                  );
                },
                child: CustomPaint(
                  size: const Size(240, 240),
                  painter: _WheelPainter(
                    labels: roster.map((s) => s['name'] as String).toList(),
                    colors: _segmentColors,
                  ),
                ),
              ),
              // Fixed pointer at the top edge, matching the approved mock's
              // `.pointer` (positioned above the wheel, pointing down at
              // whichever segment lands under it) — not centered on the hub.
              const Positioned(
                top: -18,
                child: Icon(
                  Icons.arrow_drop_down_rounded,
                  size: 40,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _spinning ? null : _spinWheel,
          style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
          child: Text(_spinning ? 'Spinning…' : 'Spin the wheel'),
        ),
      ],
    );
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter({required this.labels, required this.colors});

  final List<String> labels;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final segmentAngle = 2 * pi / labels.length;

    for (var i = 0; i < labels.length; i++) {
      final paint = Paint()..color = colors[i % colors.length];
      final startAngle = -pi / 2 + segmentAngle * i;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        segmentAngle,
        true,
        paint,
      );

      final labelAngle = startAngle + segmentAngle / 2;
      final labelOffset = Offset(
        center.dx + cos(labelAngle) * radius * 0.62,
        center.dy + sin(labelAngle) * radius * 0.62,
      );
      final painter = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(
        canvas,
        labelOffset - Offset(painter.width / 2, painter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) =>
      oldDelegate.labels != labels;
}

class _DrawingCanvas extends StatefulWidget {
  const _DrawingCanvas({
    required this.learnerId,
    required this.studentName,
    required this.onSaved,
  });

  final String learnerId;
  final String studentName;
  final ValueChanged<String> onSaved;

  @override
  State<_DrawingCanvas> createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends State<_DrawingCanvas> {
  final List<Offset?> _points = [];
  String _selectedLetter = 'ج';
  final _canvasKey = GlobalKey();
  final Stopwatch _stopwatch = Stopwatch()..start();

  static const _letterGlyphs = {'ا': 'ا', 'ب': 'ب', 'ج': 'ج', 'د': 'د'};

  @override
  void dispose() {
    _stopwatch.stop();
    super.dispose();
  }

  /// Heuristic telemetry — no real handwriting-recognition engine exists
  /// yet (matches this app's placeholder-module convention for core
  /// learning engines). `sequencingErrors` is the pen-lift count (more
  /// separate strokes than one continuous letter = more trouble);
  /// `strokeAccuracyPct` is the drawn strokes' bounding-box coverage of the
  /// canvas. Upgrade path: swap in a real stroke-scoring pass once a real
  /// tracing engine module exists.
  Future<void> _finishAttempt() async {
    final segments = <List<Offset>>[];
    var current = <Offset>[];
    for (final point in _points) {
      if (point == null) {
        if (current.isNotEmpty) segments.add(current);
        current = [];
      } else {
        current.add(point);
      }
    }
    if (current.isNotEmpty) segments.add(current);

    final sequencingErrors = segments.isEmpty ? 0 : segments.length - 1;

    var accuracy = 0.0;
    final allPoints = segments.expand((s) => s).toList();
    if (allPoints.isNotEmpty) {
      final minX = allPoints.map((p) => p.dx).reduce(min);
      final maxX = allPoints.map((p) => p.dx).reduce(max);
      final minY = allPoints.map((p) => p.dy).reduce(min);
      final maxY = allPoints.map((p) => p.dy).reduce(max);
      final box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
      final canvasArea = box == null ? 0.0 : box.size.width * box.size.height;
      // Guard against a zero-area RenderBox (unmeasured/mid-resize frame)
      // producing NaN — 0/0 isn't caught by clamp() the way Infinity is.
      final coverage = canvasArea <= 0
          ? 0.0
          : ((maxX - minX) * (maxY - minY)) / canvasArea;
      accuracy = (coverage * 100).clamp(0.0, 100.0);
    }

    await ProgressRepository().writeProgress(
      learnerId: widget.learnerId,
      moduleId: 'hot_seat_$_selectedLetter',
      strokeAccuracyPct: accuracy,
      sequencingErrors: sequencingErrors,
      timeOnTaskSeconds: _stopwatch.elapsed.inSeconds,
      assignedByTeacher: true,
    );

    if (mounted) widget.onSaved(widget.studentName);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            DropdownButton<String>(
              value: _selectedLetter,
              items: _letterGlyphs.keys
                  .map(
                    (k) => DropdownMenuItem(value: k, child: Text('Letter $k')),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() {
                    _selectedLetter = v;
                    _points.clear();
                  });
                }
              },
            ),
            TextButton.icon(
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear Canvas'),
              onPressed: () => setState(() => _points.clear()),
            ),
          ],
        ),
        const SizedBox(height: 10),
        AspectRatio(
          aspectRatio: 1.4,
          child: Container(
            key: _canvasKey,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.creamBorder, width: 2),
            ),
            child: Stack(
              children: [
                Center(
                  child: Text(
                    _selectedLetter,
                    style: TextStyle(
                      fontSize: 130,
                      fontWeight: FontWeight.w100,
                      color: Colors.grey.shade200,
                    ),
                  ),
                ),
                GestureDetector(
                  onPanUpdate: (details) {
                    RenderBox renderBox =
                        context.findRenderObject() as RenderBox;
                    setState(() {
                      _points.add(
                        renderBox.globalToLocal(details.globalPosition),
                      );
                    });
                  },
                  onPanEnd: (details) {
                    setState(() {
                      _points.add(null);
                    });
                  },
                  child: CustomPaint(
                    painter: _SketchPainter(_points),
                    size: Size.infinite,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _finishAttempt,
            icon: const Icon(Icons.check_circle_outline_rounded),
            label: const Text('Done'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.teal,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _SketchPainter extends CustomPainter {
  final List<Offset?> points;
  _SketchPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.teal
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 6.0;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _ChoralPlayer extends StatefulWidget {
  const _ChoralPlayer();

  @override
  State<_ChoralPlayer> createState() => _ChoralPlayerState();
}

class _ChoralPlayerState extends State<_ChoralPlayer>
    with SingleTickerProviderStateMixin {
  String? _playingItem;
  late final AnimationController _waveController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  void _togglePlay(String item) {
    if (_playingItem == item) {
      setState(() {
        _playingItem = null;
        _waveController.stop();
      });
    } else {
      setState(() {
        _playingItem = item;
        _waveController.repeat(reverse: true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      'Arabic Alphabet Recitation',
      'Surah Al-Fatihah (Choral)',
      'Wudhu Steps Repetition',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SoftCard(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    style: IconButton.styleFrom(
                      backgroundColor: _playingItem == item
                          ? AppColors.gold
                          : AppColors.neutralTint,
                      foregroundColor: _playingItem == item
                          ? AppColors.ink
                          : AppColors.teal,
                    ),
                    icon: Icon(
                      _playingItem == item
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                    onPressed: () => _togglePlay(item),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                          ),
                        ),
                        if (_playingItem == item)
                          AnimatedBuilder(
                            animation: _waveController,
                            builder: (context, child) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Row(
                                  children: [
                                    for (int i = 0; i < 8; i++)
                                      Container(
                                        width: 3,
                                        height:
                                            4 +
                                            (16 *
                                                (0.3 +
                                                    0.7 *
                                                        (i % 2 == 0
                                                            ? _waveController
                                                                  .value
                                                            : (1.0 -
                                                                  _waveController
                                                                      .value)))),
                                        margin: const EdgeInsets.only(right: 3),
                                        decoration: BoxDecoration(
                                          color: AppColors.teal,
                                          borderRadius: BorderRadius.circular(
                                            99,
                                          ),
                                        ),
                                      ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Talqeen active',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: AppColors.teal,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          )
                        else
                          const Text(
                            'Click to play choral loop',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
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
    );
  }
}

class _HomeworkAssigner extends ConsumerStatefulWidget {
  const _HomeworkAssigner();

  @override
  ConsumerState<_HomeworkAssigner> createState() => _HomeworkAssignerState();
}

class _HomeworkAssignerState extends ConsumerState<_HomeworkAssigner> {
  String _selectedModule = 'Letters Tracing (Alif to Kha)';
  DateTime _dueDate = DateTime.now().add(const Duration(days: 3));
  String _assigneeType = 'class'; // 'class' or 'student'
  String? _selectedStudent;

  final _modules = [
    'Letters Tracing (Alif to Kha)',
    'Alphabet Song Practice',
    'Pronunciation of Letter ج',
    'Wudhu Sequence Matcher',
  ];

  @override
  Widget build(BuildContext context) {
    final homeworks = ref.watch(classHomeworkProvider);
    final students = ref.watch(teacherRosterProvider);

    // Default to the first student name if not set
    if (_selectedStudent == null && students.isNotEmpty) {
      _selectedStudent = students.first['learnerId'] as String;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          value: _selectedModule,
          decoration: const InputDecoration(
            labelText: 'Select Learning Module',
            border: OutlineInputBorder(),
          ),
          items: _modules
              .map((m) => DropdownMenuItem(value: m, child: Text(m)))
              .toList(),
          onChanged: (v) {
            if (v != null) setState(() => _selectedModule = v);
          },
        ),
        const SizedBox(height: 12),
        // Radio choices for Assignee
        Row(
          children: [
            Expanded(
              child: RadioListTile<String>(
                title: const Text(
                  'Whole Class',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                value: 'class',
                groupValue: _assigneeType,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) {
                  if (v != null) setState(() => _assigneeType = v);
                },
              ),
            ),
            Expanded(
              child: RadioListTile<String>(
                title: const Text(
                  'Specific Student',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                value: 'student',
                groupValue: _assigneeType,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) {
                  if (v != null) setState(() => _assigneeType = v);
                },
              ),
            ),
          ],
        ),
        if (_assigneeType == 'student' && students.isNotEmpty) ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedStudent,
            decoration: const InputDecoration(
              labelText: 'Select Student',
              border: OutlineInputBorder(),
            ),
            items: students
                .map(
                  (s) => DropdownMenuItem(
                    value: s['learnerId'] as String,
                    child: Text(s['name'] as String),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _selectedStudent = v);
            },
          ),
        ],
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Due Date: ${_dueDate.day}/${_dueDate.month}/${_dueDate.year}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            ElevatedButton(
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _dueDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 30)),
                );
                if (d != null) setState(() => _dueDate = d);
              },
              child: const Text('Change Date'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () {
            final classId = ref.read(teacherClassControllerProvider)?.id;
            if (classId == null) return;

            if (_assigneeType == 'class') {
              ClassRepository()
                  .assignModule(
                    classId: classId,
                    moduleId: _selectedModule,
                    dueDate: _dueDate,
                  )
                  .then((_) => ref.invalidate(classHomeworkProvider));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Assigned "$_selectedModule" to class!'),
                ),
              );
            } else if (_selectedStudent case final learnerId?) {
              final studentName =
                  students.firstWhere(
                        (s) => s['learnerId'] == learnerId,
                      )['name']
                      as String;
              ClassRepository()
                  .assignModule(
                    classId: classId,
                    learnerId: learnerId,
                    moduleId: _selectedModule,
                    dueDate: _dueDate,
                  )
                  .then((_) {
                    ref.invalidate(teacherRosterProvider);
                    ref.invalidate(classRosterProvider(classId));
                  });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Assigned "$_selectedModule" to $studentName!'),
                ),
              );
            }
          },
          icon: const Icon(Icons.add_task),
          label: Text(
            _assigneeType == 'class' ? 'Assign to Class' : 'Assign to Student',
          ),
        ),
        if (homeworks.isNotEmpty) ...[
          const SizedBox(height: 18),
          const Text(
            'ACTIVE CLASS HOMEWORK',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          for (final hw in homeworks)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SoftCard(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.assignment_rounded, color: AppColors.teal),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hw['module'] as String,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'Due date: ${hw['dueDate']}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
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
      ],
    );
  }
}

class _SettingsTab extends ConsumerWidget {
  const _SettingsTab();

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
          'Are you sure you want to log out? You will need to sign in with your email and password again to access the Teacher Dashboard next time.',
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
              // Navigate off this admin-gated route BEFORE logout() clears
              // the account — otherwise go_router's refreshListenable reacts
              // to that state change while still on `/teacher`, transiently
              // redirecting to `/pin/setup` (see auth_loading_overlay.dart's
              // doc on `showAuthLoadingOverlay`).
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
    final volumes = ref.watch(volumeProvider);
    final volumeNotifier = ref.read(volumeProvider.notifier);

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
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
                        size: 18,
                        color: AppColors.teal,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Sound & Voice',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.ink,
                      ),
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
          delay: Duration(milliseconds: 145),
          child: _TeacherLinkFirebaseCard(),
        ),
        const SizedBox(height: 14),
        const _StaggerFadeIn(
          delay: Duration(milliseconds: 180),
          child: _EraseCard(),
        ),
        const SizedBox(height: 14),
        _StaggerFadeIn(
          delay: const Duration(milliseconds: 250),
          child: SoftCard(
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
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.coral,
                    side: const BorderSide(color: AppColors.coral, width: 1.2),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => _confirmLogout(context, ref),
                  child: const Text(
                    'Logout',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Full-bleed settings masthead — same recipe as `_ClassroomHero`
/// (ambient breathing blobs + fade/slide-down entrance) so both tabs
/// share one visual language instead of Settings being a lone boxed card.
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
                Icon(icon, size: 18, color: AppColors.textMuted),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
            Text(
              _getVolumeLabel(value),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.teal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4.0,
            activeTrackColor: AppColors.teal,
            inactiveTrackColor: Colors.grey.shade200,
            thumbColor: AppColors.teal,
            overlayColor: AppColors.teal.withOpacity(0.12),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8.0),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16.0),
          ),
          child: Slider(
            value: value,
            min: 0.0,
            max: 1.0,
            onChanged: onChanged,
          ),
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
      color: AppColors.surface,
      borderColor: AppColors.creamBorder,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.mint,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.sync_rounded,
              size: 22,
              color: AppColors.teal,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sync Now',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                ),
                const SizedBox(height: 4),
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
              side: const BorderSide(color: AppColors.teal, width: 1.2),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
                : const Icon(Icons.sync_rounded, size: 16),
            label: Text(
              _syncing ? 'Syncing...' : 'Sync',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
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

/// Teacher-side counterpart to `parent_dashboard_screen.dart`'s
/// `_LinkFirebaseCard` — same reason for existing (an account registered
/// offline, or whose signup call failed at the time, has no `firebaseUid`
/// yet, so `firestore.rules`' `ownsTeacherDoc` check fails and *nothing*
/// this teacher owns — not just their own doc, but every class they
/// create too — can ever reach Firestore via "Sync now" until this runs).
/// The Teacher Dashboard never had this card until now, unlike the Parent
/// Dashboard; that gap was the actual reason a newly created class could
/// tap "Sync" successfully (per-collection account skips swallow an
/// unlinked *teacher* doc push) while silently never showing up in the
/// admin website (nothing skips the *class* push the same way — see
/// `ClassRepository.pushAll`'s doc).
class _TeacherLinkFirebaseCard extends ConsumerStatefulWidget {
  const _TeacherLinkFirebaseCard();

  @override
  ConsumerState<_TeacherLinkFirebaseCard> createState() =>
      _TeacherLinkFirebaseCardState();
}

class _TeacherLinkFirebaseCardState
    extends ConsumerState<_TeacherLinkFirebaseCard> {
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
    // No email/password on this account (a bare PIN-only bootstrap — same
    // "nothing to link" case `parent_dashboard_screen.dart`'s card guards
    // against) means there's nothing to retry; such an account is
    // local-device-only by design until it's replaced with a real
    // admin-provisioned sign-in.
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
            'This account isn\'t linked to the cloud yet, so your classes '
            'won\'t show up in the admin website until you link it. '
            'Re-enter your password to link it.',
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
              // See the matching comment on the Logout button's onPressed
              // in this file — navigate off `/teacher` before eraseAll()
              // clears the account, not after.
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
      color: AppColors.surface,
      borderColor: AppColors.creamBorder,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.coralTint,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.delete_outline_rounded,
              size: 22,
              color: AppColors.coral,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Erase Local Data',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                ),
                const SizedBox(height: 4),
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
              side: const BorderSide(color: AppColors.coral, width: 1.2),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => _confirmErase(context, ref),
            child: const Text(
              'Delete',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
