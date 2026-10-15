import 'dart:math';

import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../data/remote/firestore_mirror.dart';
import '../../data/repositories/class_repository.dart';
import '../../data/repositories/progress_repository.dart';
import '../../logic/auth/session.dart';
import '../../logic/progress_providers.dart';
import '../core_modules/module_registry.dart';
import '../../logic/settings/settings_providers.dart';
import '../../logic/sync/sync_manager.dart';
import '../../logic/teacher/teacher_providers.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_loading_overlay.dart';
import '../settings/settings_screen.dart' show LanguageSettingRow;
import '../widgets/change_pin_card.dart';
import '../widgets/mock_icons.dart';
import '../widgets/account_email_card.dart';
import '../settings/account_security_screen.dart' show AccountSecurityRow;
import '../settings/change_password_screen.dart' show ChangePasswordRow;
import '../settings/personal_info_screen.dart' show PersonalInfoRow;
import '../widgets/soft_card.dart';
import '../widgets/child_profile_form.dart'
    show KhatamPatternPainter, displayText, scaledExtent;
import '../widgets/hub_kit.dart';
import '../widgets/app_time_picker.dart';

/// Live/presentation-mode toggle (FR-6.5) — not persisted; it only makes
/// sense for the duration of an active casting session, so it stays a
/// plain in-memory Notifier like before.
class ProgressionOverrideNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle(bool value) => state = value;
}

/// One icon + line in the Progression Override sheet's explainer box.
class _OverrideNote extends StatelessWidget {
  const _OverrideNote({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.teal),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.ink,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
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
String _teacherGreeting(WidgetRef ref) {
  // Watched so a name edited in Settings → Personal information shows
  // here straight away.
  ref.watch(sessionProvider);
  final name = ref.read(sessionProvider.notifier).activeTeacherFullName;
  if (name == null || name.isEmpty) return "Assalamu'alaikum";
  return "Assalamu'alaikum, $name";
}

class TeacherDashboardScreen extends ConsumerWidget {
  const TeacherDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(teacherProgressSyncProvider, (_, _) {});
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
      child: _TeacherShell(initialTab: initialTab),
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

// ---------------------------------------------------------------- shell

/// The Teacher Hub's one responsive shell (shared with the Parent Hub via
/// `hub_kit.dart`): teal header with the class name and a Home /
/// Classroom / Settings switcher, then a tab body that's one column on
/// phones and two from tablet-landscape widths up — the phone-vs-monitor
/// pairing from the mockup, as one layout that reflows instead of two
/// separate designs.
class _TeacherShell extends ConsumerStatefulWidget {
  const _TeacherShell({this.initialTab = 0});

  final int initialTab;

  @override
  ConsumerState<_TeacherShell> createState() => _TeacherShellState();
}

class _TeacherShellState extends ConsumerState<_TeacherShell>
    with SingleTickerProviderStateMixin {
  late int _currentTab = widget.initialTab;

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..forward();
  late final _greet = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.05, 0.45, curve: Curves.easeOut),
  );

  static const _tabs = <HubTab>[
    (iconPath: MockIcons.home, label: 'Home'),
    (iconPath: MockIcons.classroom, label: 'Classroom'),
    (iconPath: MockIcons.settings, label: 'Settings'),
  ];

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _switchTab(int index) {
    if (index == _currentTab) return;
    setState(() => _currentTab = index);
  }

  void _cast() {
    _playCastRipple(context);
    context.go('/cast');
  }

  @override
  Widget build(BuildContext context) {
    final activeClass = ref.watch(activeClassNameProvider);
    final studentCount = ref.watch(teacherRosterProvider).length;
    final pending = _watchTeacherPending(ref);
    final locked = pending && _currentTab != 2;

    final panel = switch (_currentTab) {
      0 => HubTabBody(
        left: const [
          HubStaggerFadeIn(delay: Duration.zero, child: _ClassPulseCard()),
          SizedBox(height: 8),
          HubStaggerFadeIn(
            delay: Duration(milliseconds: 30),
            child: _RosterSection(),
          ),
        ],
        right: [
          const SizedBox(height: 8),
          HubStaggerFadeIn(
            delay: const Duration(milliseconds: 60),
            child: _ActionColumn(onCast: _cast),
          ),
        ],
        // Room for the full tool list beside the roster on wide screens;
        // phones keep the three essentials (Hot Seat / Choral live on Cast).
        rightWhenWide: [
          HubStaggerFadeIn(
            delay: const Duration(milliseconds: 60),
            child: _ActionColumn(onCast: _cast, panelStyle: true),
          ),
        ],
      ),
      1 => const HubTabBody(
        left: [
          HubStaggerFadeIn(delay: Duration.zero, child: _ClassroomStats()),
          HubSectionLabel('Manage'),
          HubStaggerFadeIn(
            delay: Duration(milliseconds: 20),
            child: HubRowSheet(
              children: [
                _ClassManagementEntryCard(),
                _HomeModeInsightsEntryCard(),
              ],
            ),
          ),
          HubSectionLabel('Class health'),
          HubStaggerFadeIn(
            delay: Duration(milliseconds: 40),
            child: _ActiveClassHealthSection(),
          ),
          HubSectionLabel('Create a class'),
          HubStaggerFadeIn(
            delay: Duration(milliseconds: 60),
            child: _CreateClassCard(),
          ),
        ],
        right: [
          HubSectionLabel('Class pass'),
          _StampIn(
            delay: Duration(milliseconds: 280),
            child: _ActiveClassPass(),
          ),
        ],
      ),
      _ => const _SettingsTab(),
    };

    return HubShell(
      header: HubHeader(
        fade: _greet,
        leading: Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(
            color: AppColors.mint,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.school_rounded,
            size: 22,
            color: AppColors.teal,
          ),
        ),
        onLeadingTap: () => _switchTab(0),
        greeting: _teacherGreeting(ref),
        title: switch (_currentTab) {
          0 => activeClass,
          1 => 'Classroom',
          _ => 'Settings',
        },
        statusLabel: '$studentCount students synced',
        tabs: _tabs,
        activeTab: _currentTab,
        onTabChanged: _switchTab,
        onSwitchUser: () => _switchUser(context, ref),
      ),
      panelKey: ValueKey(_currentTab),
      floatingActionButton: _currentTab == 0 && !pending
          ? _CastFab(onTap: _cast)
          : null,
      panel: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Outside the lock so "Check status" stays usable.
          if (locked)
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: hubWideMaxWidth),
                child: const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: _PendingApprovalBanner(),
                ),
              ),
            ),
          Expanded(
            child: _PendingLock(locked: locked, child: panel),
          ),
        ],
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
      tooltip: 'Cast to class'.tr,
      onPressed: onTap,
      child: const Icon(Icons.cast_rounded, color: Colors.white),
    );
  }
}

/// Classroom tab's summary: how many classes and enrolled students this
/// teacher has (replaces the old full-bleed gradient masthead — the hub
/// header already carries the title now).
class _ClassroomStats extends ConsumerWidget {
  const _ClassroomStats();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classCount = ref.watch(teacherClassesProvider).length;
    final studentCount = ref.watch(teacherTotalStudentsProvider);

    Widget stat(IconData icon, String value, String label) => Row(
      children: [
        Icon(icon, size: 22, color: AppColors.teal),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: displayText(26, weight: 800, height: 1.1)),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.inkSoft,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final classes = stat(
      Icons.class_outlined,
      '$classCount',
      classCount == 1 ? 'Class' : 'Classes',
    );
    final students = stat(
      Icons.groups_outlined,
      '$studentCount',
      studentCount == 1 ? 'Student' : 'Students',
    );
    return SoftCard(
      radius: 20,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Stacked on narrow screens / large text, side by side otherwise.
          if (scaledExtent(context, constraints.maxWidth) < 300) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                classes,
                const Divider(height: 24, color: AppColors.creamBorder),
                students,
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: classes),
              Container(width: 1, height: 44, color: AppColors.creamBorder),
              const SizedBox(width: 16),
              Expanded(child: students),
            ],
          );
        },
      ),
    );
  }
}

// ----------------------------------------------------------------- components

/// Home tab's students preview — only the 3 most recent, with a "See all"
/// link to the active class's full roster (`ClassDetailScreen`). Cards on
/// phones; a compact table once the column is wide enough for one.
class _RosterSection extends ConsumerWidget {
  const _RosterSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(teacherRosterProvider);
    final activeClassId = ref.watch(teacherClassControllerProvider)?.id;
    final preview = list.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HubSectionLabel(
          'Students',
          trailing: activeClassId == null
              ? null
              : TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.teal,
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  onPressed: () =>
                      context.push('/teacher/classes/$activeClassId?from=home'),
                  child: const Text('See all'),
                ),
        ),
        if (preview.isEmpty)
          const _NoStudentsCard()
        else
          LayoutBuilder(
            builder: (context, constraints) {
              if (scaledExtent(context, constraints.maxWidth) >= 520) {
                return _StudentTable(preview: preview);
              }
              return Column(
                children: [
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
            },
          ),
      ],
    );
  }
}

/// Shown in place of the roster preview when the active class has no
/// enrolled students yet — so an empty roster reads as empty, not as
/// still loading.
class _NoStudentsCard extends StatelessWidget {
  const _NoStudentsCard();

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: [
          const Icon(
            Icons.people_outline_rounded,
            size: 32,
            color: AppColors.inkSoft,
          ),
          const SizedBox(height: 10),
          Text(
            'No students in this class yet',
            textAlign: TextAlign.center,
            style: displayText(17),
          ),
          const SizedBox(height: 6),
          const Text(
            'Share your class invitation code so parents can enroll their '
            'child.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.4,
              color: AppColors.inkSoft,
            ),
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
    final pill = MasteryPill(mastery: mastery, dotted: true);
    return _PressScale(
      builder: (context, setPressed) => GestureDetector(
        onTapDown: (_) => setPressed(true),
        onTapCancel: () => setPressed(false),
        onTapUp: (_) => setPressed(false),
        onTap: () => showStudentDetails(context, ref, student),
        child: SoftCard(
          radius: 18,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Pill under the name when there's no room beside it.
              final compact = scaledExtent(context, constraints.maxWidth) < 330;
              return Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: masteryBarColor(mastery),
                        width: 2,
                      ),
                    ),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: avatarColor(mastery),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        name.isEmpty ? '?' : name[0].toUpperCase(),
                        style: displayText(
                          18,
                          weight: 800,
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
                        HubFitText(
                          name,
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$tracing tracing · active $activity',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.inkSoft,
                          ),
                        ),
                        const SizedBox(height: 7),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0.0, end: completion),
                            duration: const Duration(milliseconds: 900),
                            curve: Curves.easeOutQuart,
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
                        if (compact) ...[const SizedBox(height: 8), pill],
                      ],
                    ),
                  ),
                  if (!compact) ...[const SizedBox(width: 10), pill],
                ],
              );
            },
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
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: masteryBg(mastery),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: masteryFg(mastery),
                shape: BoxShape.circle,
              ),
            ),
            Flexible(
              child: Text(
                mastery.toUpperCase(),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                  color: AppColors.ink,
                ),
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
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: masteryFg(mastery),
        ),
      ),
    );
  }
}

/// "This class at a glance": a radial average-completion ring (real data
/// from [teacherRosterProvider]) beside mastery-tier counts. On narrow
/// screens / large text the counts move under the ring.
class _ClassPulseCard extends ConsumerWidget {
  const _ClassPulseCard();

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
    const ringSize = 124.0;

    final ring = TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: avgCompletion.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutQuart,
      builder: (context, t, _) => SizedBox(
        width: ringSize,
        height: ringSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: const Size(ringSize, ringSize),
              painter: _MasteryRingPainter(progress: t),
            ),
            Padding(
              padding: const EdgeInsets.all(ringSize * 0.2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(t * 100).round()}%',
                      style: displayText(
                        ringSize * 0.24,
                        weight: 800,
                        height: 1,
                      ),
                    ),
                    const Text(
                      'Avg. mastery',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.inkSoft,
                        fontWeight: FontWeight.w700,
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
    final chips = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MasteryCountChip(
          label: 'High mastery',
          count: counts['High']!,
          color: AppColors.teal,
        ),
        const Divider(height: 14, color: AppColors.creamBorder),
        _MasteryCountChip(
          label: 'Medium mastery',
          count: counts['Medium']!,
          color: AppColors.gold,
        ),
        const Divider(height: 14, color: AppColors.creamBorder),
        _MasteryCountChip(
          label: 'Needs help',
          count: counts['Needs help']!,
          color: AppColors.coral,
        ),
      ],
    );

    return SoftCard(
      radius: 20,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('This class at a glance', style: displayText(18)),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              if (scaledExtent(context, constraints.maxWidth) < 340) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: ring),
                    const SizedBox(height: 16),
                    chips,
                  ],
                );
              }
              return Row(
                children: [
                  ring,
                  const SizedBox(width: 22),
                  Expanded(child: chips),
                ],
              );
            },
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
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('$count', style: displayText(20, weight: 800)),
      ],
    );
  }
}

class _MasteryRingPainter extends CustomPainter {
  _MasteryRingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - 14) / 2;
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
/// play at home never counts here, hence the "Classroom mode" scope tag.
/// Reuses [masteryBg]/[masteryFg]'s High/Medium/Needs-help thresholds.
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
    final played = modules.where((m) => m.hasActivity).toList();
    final notPlayed = modules.length - played.length;

    return SoftCard(
      radius: 20,
      onTap: () => context.push('/teacher/classes/$classId/health'),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 6,
            children: [
              Text('Class health index', style: displayText(18)),
              Container(
                padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
                decoration: BoxDecoration(
                  color: AppColors.mint,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.mintBorder),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cast_rounded, size: 13, color: AppColors.teal),
                    SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        'Classroom mode',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.tealDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Games played on the Hot Seat during live Cast sessions — not '
            'Adventure Map/Student Hub solo play.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AppColors.inkSoft,
            ),
          ),
          const SizedBox(height: 14),
          for (final module in played)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _ModuleHealthRow(
                module: module,
                tier: _tierFor(module.healthIndex),
              ),
            ),
          if (notPlayed > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                played.isEmpty
                    ? 'No games cast yet — draw a student on the Hot Seat '
                          'and pick a game to start.'
                    : '$notPlayed of ${modules.length} games not cast yet',
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  color: AppColors.inkSoft,
                ),
              ),
            ),
          const Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    'See details',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.teal,
                    ),
                  ),
                ),
                SizedBox(width: 2),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.teal,
                ),
              ],
            ),
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

  @override
  Widget build(BuildContext context) {
    final trend = module.trend;
    Widget? trendIcon;
    if (trend != null && trend > 0) {
      trendIcon = const Icon(
        Icons.arrow_upward_rounded,
        size: 18,
        color: AppColors.teal,
      );
    } else if (trend != null && trend < 0) {
      trendIcon = const Icon(
        Icons.arrow_downward_rounded,
        size: 18,
        color: AppColors.coral,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final title = Row(
              children: [
                Text(module.icon, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    module.moduleName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                      color: AppColors.ink,
                    ),
                  ),
                ),
                ?trendIcon,
              ],
            );
            final pill = MasteryPill(mastery: tier, dotted: true);
            // Pill under the name when the row is too narrow for both.
            if (scaledExtent(context, constraints.maxWidth) < 320) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [title, const SizedBox(height: 6), pill],
              );
            }
            return Row(
              children: [
                Expanded(child: title),
                const SizedBox(width: 8),
                pill,
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: module.completionRate),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutQuart,
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
        const SizedBox(height: 6),
        Text(
          '${module.avgAccuracy.round()}% avg accuracy · '
          '${module.attemptCount} play${module.attemptCount == 1 ? '' : 's'} · '
          '${module.studentsUp} student${module.studentsUp == 1 ? '' : 's'} up',
          style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
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
    if (section == null) {
      return const SoftCard(
        radius: 20,
        padding: EdgeInsets.all(20),
        child: Text(
          'Create a class to start tracking its health.',
          style: TextStyle(fontSize: 14, color: AppColors.inkSoft),
        ),
      );
    }
    return ClassHealthSection(classId: section.id);
  }
}

/// Roster preview as a table — used by [_RosterSection] when its column is
/// wide enough (tablet landscape / desktop).
class _StudentTable extends ConsumerWidget {
  const _StudentTable({required this.preview});

  final List<Map<String, dynamic>> preview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SoftCard(
      radius: 20,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: DataTable(
          columnSpacing: 16,
          horizontalMargin: 18,
          showCheckboxColumn: false,
          headingTextStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: AppColors.inkSoft,
          ),
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
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  DataCell(
                    SizedBox(
                      width: 72,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(
                            begin: 0.0,
                            end: s['completion'] as double,
                          ),
                          duration: const Duration(milliseconds: 900),
                          curve: Curves.easeOutQuart,
                          builder: (context, val, child) {
                            return LinearProgressIndicator(
                              value: val,
                              minHeight: 6,
                              backgroundColor: AppColors.creamDark,
                              color: masteryBarColor(s['mastery'] as String),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      s['tracing'] as String,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  DataCell(MasteryPill(mastery: s['mastery'] as String)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Bottom-sheet frame for the class tools: white rounded top with a drag
/// handle and display-face title; scrolls when taller than ~90% of the
/// screen and lifts above the keyboard. A Material surface so list tiles
/// inside can paint their ink ripples.
class _TeacherSheet extends StatelessWidget {
  const _TeacherSheet({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: Material(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppColors.creamBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(title, style: displayText(21, weight: 800)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionColumn extends ConsumerWidget {
  const _ActionColumn({required this.onCast, this.panelStyle = false});

  final VoidCallback onCast;

  /// The full six-tool list (wide layouts); phones show three.
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
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _TeacherSheet(
        title: 'Choral Controller (Talqeen)',
        subtitle: 'Trigger repeat-after-me audio loops class-wide.',
        child: _ChoralPlayer(),
      ),
    );
  }

  void _openOverride(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) => Consumer(
        builder: (context, ref, child) {
          final isOverriding = ref.watch(progressionOverrideProvider);
          return _TeacherSheet(
            title: 'Progression Override Settings',
            subtitle:
                'Normally a learner unlocks each Adventure Map stage by '
                'finishing the one before it, or when you assign it as '
                'homework. Turn this on to open every stage at once — handy '
                'when presenting a later lesson to the whole class.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.neutralTint,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.creamBorder),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _OverrideNote(
                        icon: Icons.lock_open_rounded,
                        text:
                            'When ON: every stage on the Adventure Map is open, and overdue homework badges are hidden.',
                      ),
                      SizedBox(height: 10),
                      _OverrideNote(
                        icon: Icons.save_outlined,
                        text:
                            "Students' saved progress, stars and badges don't change — turning it OFF puts the normal locks back.",
                      ),
                      SizedBox(height: 10),
                      _OverrideNote(
                        icon: Icons.tablet_mac_rounded,
                        text:
                            'Applies only to the Learner Hub opened on this device. It does not reach students on their own phones or tablets.',
                      ),
                      SizedBox(height: 10),
                      _OverrideNote(
                        icon: Icons.restart_alt_rounded,
                        text: 'Turns itself OFF when the app is closed.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Bypass Progression Constraints',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text(
                    'Unlock every Adventure Map stage',
                    style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
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
      builder: (context) => const _TeacherSheet(
        title: 'Assign Homework',
        subtitle: 'Assign specific learning modules to class roster.',
        child: _HomeworkAssigner(),
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
            String detail,
            Color color,
            VoidCallback onTap,
          })
        >[
          (
            icon: Icons.add_task_rounded,
            label: 'Assign homework',
            detail: 'Whole class or one student',
            color: AppColors.teal,
            onTap: () => _openHomework(context),
          ),
          if (panelStyle) ...[
            (
              icon: Icons.airline_seat_recline_normal_rounded,
              label: 'Hot seat',
              detail: 'Pick a student to trace on this device',
              color: AppColors.gold,
              onTap: () => _openHotSeat(context),
            ),
            (
              icon: Icons.record_voice_over_rounded,
              label: 'Choral controller',
              detail: 'Repeat-after-me audio for the class',
              color: AppColors.coral,
              onTap: () => _openChoral(context),
            ),
          ],
          (
            icon: Icons.lock_open_rounded,
            label: 'Progression override',
            detail: 'Open every Adventure Map stage',
            color: AppColors.teal,
            onTap: () => _openOverride(context, ref),
          ),
          (
            icon: Icons.grid_view_rounded,
            label: 'Module library',
            detail: 'Browse lessons and build folders',
            color: AppColors.teal,
            onTap: () => context.push('/teacher/module-library'),
          ),
          if (panelStyle)
            (
              icon: Icons.campaign_rounded,
              label: 'Cast Greeting Match',
              detail: 'Play the greeting game on the big screen',
              color: AppColors.coral,
              onTap: () => context.push('/cast-greeting-match'),
            ),
        ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HubSectionLabel(panelStyle ? 'Class tools' : 'Quick actions'),
        HubRowSheet(
          children: [
            for (final s in specs)
              HubNavRow(
                icon: s.icon,
                iconColor: s.color,
                title: s.label,
                subtitle: s.detail,
                onTap: s.onTap,
              ),
          ],
        ),
      ],
    );
  }
}

/// Subtle press-down scale for tappable cards.
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
      scale: _pressed ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: widget.builder(context, (v) => setState(() => _pressed = v)),
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
  String _selectedModule = allGames.first.lesson.id;

  @override
  Widget build(BuildContext context) {
    // Find the latest state of this student from the provider
    final students = ref.watch(teacherRosterProvider);
    final currentStudent = students.firstWhere(
      (s) => s['name'] == widget.student['name'],
      orElse: () => widget.student,
    );

    final assigned = currentStudent['assignedModules'] as List<dynamic>? ?? [];
    final assignedDetails =
        currentStudent['assignmentsDetail'] as List<dynamic>? ?? [];
    final name = currentStudent['name'] as String;
    final mastery = currentStudent['mastery'] as String;
    final studentId = currentStudent['studentId'] as String?;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: MediaQuery.sizeOf(context).width < 400 ? 12 : 20,
        vertical: 24,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 680),
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              ColoredBox(
                color: AppColors.teal,
                child: CustomPaint(
                  painter: const KhatamPatternPainter(),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 8, 18),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            name.isEmpty ? '?' : name[0].toUpperCase(),
                            style: displayText(
                              20,
                              weight: 800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              LayoutBuilder(
                                builder: (context, box) => Text(
                                  name,
                                  style: fitLongestWord(
                                    context,
                                    name,
                                    displayText(20, color: Colors.white),
                                    box.maxWidth,
                                  ),
                                ),
                              ),
                              if (studentId != null)
                                Text(
                                  'Student ID: $studentId',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withValues(alpha: 0.85),
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  mastery.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 13,
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
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Progress stat strip — 2 per row, 1 when narrow.
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final stats = [
                            _DialogStat(
                              icon: Icons.gesture_rounded,
                              value: '${currentStudent['tracing']}',
                              label: 'Tracing',
                            ),
                            _DialogStat(
                              icon: Icons.check_circle_outline_rounded,
                              value:
                                  '${(currentStudent['completion'] * 100).round()}%',
                              label: 'Completion',
                            ),
                          ];
                          final recent = _DialogStat(
                            icon: Icons.access_time_rounded,
                            value: '${currentStudent['activity']}',
                            label: 'Recent activity',
                          );
                          if (scaledExtent(context, constraints.maxWidth) <
                              300) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                stats[0],
                                const SizedBox(height: 8),
                                stats[1],
                                const SizedBox(height: 8),
                                recent,
                              ],
                            );
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: stats[0]),
                                  const SizedBox(width: 8),
                                  Expanded(child: stats[1]),
                                ],
                              ),
                              const SizedBox(height: 8),
                              recent,
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      SoftCard(
                        radius: 18,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.add_task_rounded,
                                  size: 20,
                                  color: AppColors.teal,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Assign Learning Module',
                                    style: displayText(17),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _GameSessionPicker(
                              lessonId: _selectedModule,
                              onChanged: (v) =>
                                  setState(() => _selectedModule = v),
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: () {
                                final classId = ref
                                    .read(teacherClassControllerProvider)
                                    ?.id;
                                if (classId == null) return;
                                ClassRepository()
                                    .assignModule(
                                      classId: classId,
                                      learnerId:
                                          currentStudent['learnerId'] as String,
                                      moduleId: _selectedModule,
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
                                      'Assigned "${assignmentTitle(_selectedModule)}" to $name',
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.add_task, size: 18),
                              label: Text('Assign to $name'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.gold,
                                foregroundColor: AppColors.ink,
                                minimumSize: const Size(64, 48),
                                shape: const StadiumBorder(),
                                textStyle: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (assigned.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              const Divider(
                                height: 1,
                                color: AppColors.creamBorder,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Assigned (${assigned.length})',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink,
                                ),
                              ),
                              const SizedBox(height: 6),
                              if (assignedDetails.isNotEmpty)
                                for (final item in assignedDetails)
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.assignment_turned_in,
                                        size: 18,
                                        color: AppColors.teal,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _SubmissionLine(
                                          title: item['module'] as String,
                                          submission:
                                              item['submission']
                                                  as HomeworkSubmission,
                                          dueDate: item['dueDate'] as String?,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          size: 20,
                                          color: AppColors.teal,
                                        ),
                                        tooltip: 'Edit Assignment',
                                        onPressed: () => _editStudentAssignment(
                                          item as Map<String, dynamic>,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          size: 20,
                                          color: AppColors.coral,
                                        ),
                                        tooltip: 'Delete Assignment',
                                        onPressed: () =>
                                            _deleteStudentAssignment(
                                              item as Map<String, dynamic>,
                                            ),
                                      ),
                                    ],
                                  )
                              else
                                for (final item in assigned)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.assignment_turned_in,
                                          size: 18,
                                          color: AppColors.teal,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            item as String,
                                            style: const TextStyle(
                                              fontSize: 13.5,
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
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 16, 14),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: AppColors.creamBorder)),
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
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
                        size: 18,
                      ),
                      label: const Text(
                        'Remove',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.coral,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.teal,
                        minimumSize: const Size(96, 46),
                        shape: const StadiumBorder(),
                      ),
                      child: const Text('Close'),
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

  Future<void> _editStudentAssignment(Map<String, dynamic> item) async {
    final assignmentId = item['id'] as String?;
    if (assignmentId == null) return;
    final initialModuleId =
        item['moduleId'] as String? ?? allGames.first.lesson.id;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => _EditHomeworkDialog(
        title: 'Edit Student Assignment',
        initialModuleId: initialModuleId,
        onSave: (newModuleId) async {
          await ClassRepository().updateAssignment(
            id: assignmentId,
            moduleId: newModuleId,
          );
          ref.invalidate(teacherRosterProvider);
          final classId = ref.read(teacherClassControllerProvider)?.id;
          if (classId != null) {
            ref.invalidate(classRosterProvider(classId));
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Updated assignment to "${assignmentTitle(newModuleId)}"',
                ),
              ),
            );
          }
        },
      ),
    );
  }

  Future<void> _deleteStudentAssignment(Map<String, dynamic> item) async {
    final assignmentId = item['id'] as String?;
    if (assignmentId == null) return;
    final moduleName = item['module'] as String? ?? 'assignment';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        icon: const Icon(
          Icons.delete_outline_rounded,
          color: AppColors.coral,
          size: 36,
        ),
        title: const Text('Delete Assignment?'),
        content: Text(
          'Are you sure you want to remove the assignment for "$moduleName"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.coral),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ClassRepository().deleteAssignment(assignmentId);
      ref.invalidate(teacherRosterProvider);
      final classId = ref.read(teacherClassControllerProvider)?.id;
      if (classId != null) {
        ref.invalidate(classRosterProvider(classId));
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Removed "$moduleName"')));
      }
    }
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
      if (ClassRepository().byLearnerId(studentId).isEmpty) {
        FirestoreMirror(
          teacher: true,
        ).revokeTeacherAccess(studentId).catchError((Object _) {});
      }

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
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.teal),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: displayText(18, weight: 800, height: 1.1)),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.tealDark,
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
    return HubRowSheet(
      children: [
        HubActionRow(
          icon: Icons.add_circle_outline_rounded,
          iconColor: AppColors.gold,
          title: 'Create a Class',
          subtitle: 'Set up a new section for this term.',
          trailing: HubRowButton(
            label: 'New class',
            color: AppColors.ink,
            onPressed: () => _showCreateClassSheet(context),
          ),
        ),
      ],
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
    Widget label(String text, {bool required = false}) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text.rich(
        TextSpan(
          text: text,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
          children: [
            if (required)
              const TextSpan(
                text: ' *',
                style: TextStyle(color: AppColors.danger),
              ),
          ],
        ),
      ),
    );
    InputDecoration field(String hint) => InputDecoration(
      hintText: hint.tr,
      filled: true,
      fillColor: AppColors.neutralTint,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.creamBorder, width: 1.4),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.creamBorder, width: 1.4),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.teal, width: 1.8),
      ),
    );
    final timeButtonStyle = OutlinedButton.styleFrom(
      foregroundColor: AppColors.ink,
      minimumSize: const Size(64, 48),
      side: const BorderSide(color: AppColors.creamBorder, width: 1.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
    );
    final gradeField = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        label('Grade Level', required: true),
        TextField(controller: _gradeLevelC, decoration: field('e.g. Grade 1')),
      ],
    );
    final sectionField = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        label('Section', required: true),
        TextField(controller: _sectionC, decoration: field('e.g. A')),
      ],
    );
    final startButton = OutlinedButton.icon(
      onPressed: () => _pickTime(isStart: true),
      icon: const Icon(Icons.access_time_rounded, size: 18),
      label: Text(_startTime == null ? 'Start time' : _formatTime(_startTime!)),
      style: timeButtonStyle,
    );
    final endButton = OutlinedButton.icon(
      onPressed: () => _pickTime(isStart: false),
      icon: const Icon(Icons.access_time_rounded, size: 18),
      label: Text(_endTime == null ? 'End time' : _formatTime(_endTime!)),
      style: timeButtonStyle,
    );

    return _TeacherSheet(
      title: 'Create a Class',
      subtitle: 'Set up a new section for this term.',
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Paired fields side by side when there's room, stacked on
          // narrow screens or with large text.
          final stacked = scaledExtent(context, constraints.maxWidth) < 340;
          Widget pair(Widget a, Widget b) => stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [a, const SizedBox(height: 12), b],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: a),
                    const SizedBox(width: 12),
                    Expanded(child: b),
                  ],
                );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              pair(gradeField, sectionField),
              const SizedBox(height: 18),
              label('Schedule (optional)'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < _weekdayLabels.length; i++)
                    ChoiceChip(
                      label: Text(_weekdayLabels[i]),
                      selected: _selectedWeekdays.contains(i),
                      showCheckmark: false,
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          _selectedWeekdays.add(i);
                        } else {
                          _selectedWeekdays.remove(i);
                        }
                      }),
                      labelStyle: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: _selectedWeekdays.contains(i)
                            ? Colors.white
                            : AppColors.ink,
                      ),
                      selectedColor: AppColors.teal,
                      backgroundColor: Colors.white,
                      side: BorderSide(
                        color: _selectedWeekdays.contains(i)
                            ? AppColors.teal
                            : AppColors.creamBorder,
                      ),
                      shape: const StadiumBorder(),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              pair(startButton, endButton),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _createClass,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create Class'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.ink,
                  minimumSize: const Size(64, 52),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Entry row (Classroom tab) into the dedicated `/teacher/classes` screen —
/// full per-class roster management (FR-6.1, FR-6.2) lives there, since
/// listing every class's entire roster doesn't fit a scrolling tab.
class _ClassManagementEntryCard extends ConsumerWidget {
  const _ClassManagementEntryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classCount = ref.watch(teacherClassesProvider).length;
    return HubNavRow(
      icon: Icons.groups_outlined,
      title: 'Classroom Management',
      subtitle: classCount == 0
          ? 'No classes yet'
          : '$classCount class${classCount == 1 ? '' : 'es'} · manage students',
      // Pushed over the hub, so Back slides it off again (see
      // ClassroomManagementScreen._goBack).
      onTap: () => context.push('/teacher/classes'),
    );
  }
}

/// Entry row into [HomeModeDashboardScreen] (FR-6.2B) — solo Student Hub/
/// Adventure Map practice at home, kept separate from [ClassHealthSection]
/// since that section is Classroom-Mode-only by design.
class _HomeModeInsightsEntryCard extends StatelessWidget {
  const _HomeModeInsightsEntryCard();

  @override
  Widget build(BuildContext context) {
    return HubNavRow(
      icon: Icons.home_outlined,
      iconColor: AppColors.gold,
      title: 'Home Mode Insights',
      subtitle: 'View longitudinal tracking & collective mastery trends',
      onTap: () => context.push('/teacher/home-progress'),
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
/// [ClassPassCard] for whichever class is active on the dashboard.
class _ActiveClassPass extends ConsumerWidget {
  const _ActiveClassPass();

  @override
  Widget build(BuildContext context, WidgetRef ref) => ClassPassCard(
    code: ref.watch(classInvitationCodeProvider),
    className: ref.watch(activeClassNameProvider),
    notchColor: AppColors.cream,
  );
}

/// Invitation-code "Class Pass" ticket — shared by the Classroom tab and
/// `ClassDetailScreen` so the same concept looks the same everywhere.
class ClassPassCard extends StatefulWidget {
  const ClassPassCard({
    super.key,
    required this.code,
    required this.className,
    this.archived = false,
    this.notchColor = AppColors.cream,
  });

  final String code;
  final String className;

  /// Archived classes keep the code on record but it no longer enrolls
  /// anyone, so the Copy action gives way to a note.
  final bool archived;

  /// Color of the two punched notches — must match whatever surface sits
  /// behind this card or the "cut" illusion breaks.
  final Color notchColor;

  @override
  State<ClassPassCard> createState() => _ClassPassCardState();
}

class _ClassPassCardState extends State<ClassPassCard> {
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
    final code = widget.code;
    final className = widget.className;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: ColoredBox(
            color: AppColors.teal,
            child: CustomPaint(
              painter: const KhatamPatternPainter(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 40,
                      child: Row(
                        children: [
                          const Icon(
                            Icons.confirmation_num_outlined,
                            size: 18,
                            color: AppColors.goldSoft,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Invitation code',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    _DashedDivider(color: Colors.white.withValues(alpha: 0.3)),
                    const SizedBox(height: 16),
                    Text(
                      className,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.88),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Scales down rather than breaking the code across lines.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        code,
                        maxLines: 1,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (widget.archived)
                      Row(
                        children: [
                          Icon(
                            Icons.archive_outlined,
                            size: 18,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Archived — this code no longer works',
                              style: TextStyle(
                                fontSize: 13.5,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          Text(
                            'Share with parents to enroll',
                            style: TextStyle(
                              fontSize: 13.5,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                          AnimatedScale(
                            scale: _copied ? 1.06 : 1.0,
                            duration: const Duration(milliseconds: 160),
                            curve: Curves.easeOut,
                            child: OutlinedButton.icon(
                              onPressed: _copied ? null : () => _copyCode(code),
                              icon: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 180),
                                child: Icon(
                                  _copied
                                      ? Icons.check_rounded
                                      : Icons.copy_rounded,
                                  key: ValueKey(_copied),
                                  size: 16,
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
                                disabledForegroundColor: AppColors.ink,
                                backgroundColor: _copied
                                    ? AppColors.gold
                                    : Colors.white.withValues(alpha: 0.12),
                                side: BorderSide(
                                  color: Colors.white.withValues(
                                    alpha: _copied ? 0.6 : 0.35,
                                  ),
                                ),
                                minimumSize: const Size(64, 44),
                                shape: const StadiumBorder(),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // The two punched notches, positioned at the perforation line —
        // small circles matching the surrounding background color so they
        // read as cut-outs rather than decoration sitting on top.
        Positioned(left: -11, top: 54, child: _PassNotch(color: notchColor)),
        Positioned(right: -11, top: 54, child: _PassNotch(color: notchColor)),
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("Saved to $name's progress")));
  }

  @override
  Widget build(BuildContext context) {
    final roster = ref.watch(teacherRosterProvider);
    final pickedName = _pickedName;
    return _TeacherSheet(
      title: pickedName == null
          ? 'Hot Seat Tracing Mode'
          : 'Hot Seat: $pickedName',
      subtitle: pickedName == null
          ? 'Pick which student is up before launching the tracing canvas.'
          : 'Enables the student to trace letters directly on this device.',
      child: pickedName == null
          ? _HotSeatStudentPicker(roster: roster, onPicked: _pick)
          : _DrawingCanvas(
              learnerId: _pickedLearnerId!,
              studentName: pickedName,
              onSaved: _onSaved,
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

  Widget _modeButton(String label, bool selected, VoidCallback? onPressed) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: selected ? AppColors.mint : null,
        foregroundColor: AppColors.tealDark,
        minimumSize: const Size(64, 48),
        side: BorderSide(
          color: selected ? AppColors.teal : AppColors.creamBorder,
          width: 1.4,
        ),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
      ),
      child: Text(label, textAlign: TextAlign.center),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.roster.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'No students enrolled yet — enroll students first.',
          style: TextStyle(fontSize: 14, color: AppColors.inkSoft),
        ),
      );
    }

    // Disabled mid-spin — switching away would unmount the wheel and
    // silently drop the in-flight pick.
    final manual = _modeButton(
      'Pick manually',
      !_drawLots,
      _wheelSpinning ? null : () => setState(() => _drawLots = false),
    );
    final lots = _modeButton(
      'Draw lots',
      _drawLots,
      _wheelSpinning ? null : () => setState(() => _drawLots = true),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            if (scaledExtent(context, constraints.maxWidth) < 300) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [manual, const SizedBox(height: 8), lots],
              );
            }
            return Row(
              children: [
                Expanded(child: manual),
                const SizedBox(width: 8),
                Expanded(child: lots),
              ],
            );
          },
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
                Material(
                  color: AppColors.neutralTint,
                  shape: const StadiumBorder(
                    side: BorderSide(color: AppColors.creamBorder),
                  ),
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: () => widget.onPicked(
                      student['learnerId'] as String,
                      student['name'] as String,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Text(
                          student['name'] as String,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
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
    final targetTurns = 4 + 1 - (segmentTurns * winnerIndex + segmentTurns / 2);

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
                  return Transform.rotate(angle: turns * 2 * pi, child: child);
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
    if (labels.isEmpty) return;

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

      // Radial divider line
      final linePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.4)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        center,
        Offset(
          center.dx + cos(startAngle) * radius,
          center.dy + sin(startAngle) * radius,
        ),
        linePaint,
      );

      // Draw text rotated radially along the segment bisector
      final labelAngle = startAngle + segmentAngle / 2;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(labelAngle);

      final maxTextWidth = radius * 0.62;
      final fontSize = labels.length > 12
          ? 9.5
          : (labels.length > 6 ? 10.5 : 12.0);
      final painter = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            shadows: const [
              Shadow(
                color: Colors.black45,
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        ellipsis: '…',
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxTextWidth);

      // Start text after the center hub with safe padding from the rim
      final startX = radius * 0.22 + (maxTextWidth - painter.width) / 2;
      painter.paint(canvas, Offset(startX, -painter.height / 2));
      canvas.restore();
    }

    // Outer wheel border
    final rimPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius - 2, rimPaint);

    // Center hub circle
    final hubRadius = radius * 0.16;
    final hubPaint = Paint()..color = Colors.white;
    canvas.drawCircle(center, hubRadius, hubPaint);
    final hubRimPaint = Paint()
      ..color = AppColors.creamBorder
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, hubRadius, hubRimPaint);
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
                                    const Flexible(
                                      child: Text(
                                        'Talqeen active',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: AppColors.teal,
                                          fontWeight: FontWeight.bold,
                                        ),
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
                              fontSize: 12.5,
                              color: AppColors.inkSoft,
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
  String _selectedModule = allGames.first.lesson.id;
  String _assigneeType = 'class'; // 'class' or 'student'
  String? _selectedStudent;
  DateTime? _dueAt;

  /// Date first, then time — defaults to 11:59 PM so "due that day" stays
  /// the easy choice.
  Future<void> _pickDueDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final date = await showDatePicker(
      context: context,
      initialDate: _dueAt ?? today.add(const Duration(days: 7)),
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      helpText: 'Due date',
    );
    if (date == null || !mounted) return;
    final time = await showAppTimePicker(
      context: context,
      initialTime: _dueAt == null
          ? const TimeOfDay(hour: 23, minute: 59)
          : TimeOfDay.fromDateTime(_dueAt!),
      label: 'Due time',
    );
    if (time == null) return;
    setState(
      () => _dueAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final homeworks = ref.watch(classHomeworkProvider);
    final students = ref.watch(teacherRosterProvider);

    // Default to the first student name if not set
    if (_selectedStudent == null && students.isNotEmpty) {
      _selectedStudent = students.first['learnerId'] as String;
    }

    Widget assignee(String value, String label) => RadioListTile<String>(
      title: Text(
        label,
        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
      ),
      value: value,
      groupValue: _assigneeType,
      contentPadding: EdgeInsets.zero,
      onChanged: (v) {
        if (v != null) setState(() => _assigneeType = v);
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GameSessionPicker(
          lessonId: _selectedModule,
          onChanged: (v) => setState(() => _selectedModule = v),
        ),
        const SizedBox(height: 12),
        // Assignee: side by side when there's room, stacked when narrow.
        LayoutBuilder(
          builder: (context, constraints) {
            final whole = assignee('class', 'Whole Class');
            final one = assignee('student', 'Specific Student');
            if (scaledExtent(context, constraints.maxWidth) < 380) {
              return Column(children: [whole, one]);
            }
            return Row(
              children: [
                Expanded(child: whole),
                Expanded(child: one),
              ],
            );
          },
        ),
        if (_assigneeType == 'student' && students.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Select Student',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ),
          DropdownButtonFormField<String>(
            initialValue: _selectedStudent,
            isExpanded: true,
            itemHeight: null,
            decoration: _pickerDecoration(),
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
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.teal,
                  minimumSize: const Size(64, 46),
                  shape: const StadiumBorder(),
                  side: const BorderSide(color: AppColors.mintBorder),
                ),
                onPressed: _pickDueDate,
                icon: const Icon(Icons.event_rounded, size: 20),
                label: Text(
                  _dueAt == null
                      ? 'Due date (optional)'
                      : 'Due date: ${formatDateTime(_dueAt!)}',
                ),
              ),
            ),
            if (_dueAt != null)
              IconButton(
                tooltip: 'Remove due date',
                icon: const Icon(Icons.close_rounded, color: AppColors.inkSoft),
                onPressed: () => setState(() => _dueAt = null),
              ),
          ],
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.teal,
            minimumSize: const Size(64, 50),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          onPressed: () {
            final classId = ref.read(teacherClassControllerProvider)?.id;
            if (classId == null) return;

            if (_assigneeType == 'class') {
              ClassRepository()
                  .assignModule(
                    classId: classId,
                    moduleId: _selectedModule,
                    dueDate: _dueAt,
                  )
                  .then((_) => ref.invalidate(classHomeworkProvider));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Assigned "${assignmentTitle(_selectedModule)}" to class!',
                  ),
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
                    dueDate: _dueAt,
                  )
                  .then((_) {
                    ref.invalidate(teacherRosterProvider);
                    ref.invalidate(classRosterProvider(classId));
                  });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Assigned "${assignmentTitle(_selectedModule)}" to $studentName!',
                  ),
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
          const SizedBox(height: 20),
          Text('Active class homework', style: displayText(17)),
          const SizedBox(height: 8),
          for (final hw in homeworks)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SoftCard(
                radius: 16,
                padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                child: Row(
                  children: [
                    const Icon(
                      Icons.assignment_rounded,
                      size: 22,
                      color: AppColors.teal,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => _showSubmissions(context, hw),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              hw['module'] as String,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                            Text(
                              hw['dueDate'] == null
                                  ? 'No due date'
                                  : 'Due date: ${hw['dueDate']}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.inkSoft,
                              ),
                            ),
                            if ((hw['doneLabel'] as String).isNotEmpty)
                              Text(
                                hw['doneLabel'] as String,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.inkSoft,
                                ),
                              ),
                            const Text(
                              'View submissions',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.teal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.edit_outlined,
                        size: 20,
                        color: AppColors.teal,
                      ),
                      tooltip: 'Edit module',
                      onPressed: () => _showEditHomework(context, hw),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        size: 20,
                        color: AppColors.coral,
                      ),
                      tooltip: 'Delete homework',
                      onPressed: () => _confirmDeleteHomework(context, hw),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }

  void _showSubmissions(BuildContext context, Map<String, dynamic> hw) {
    // Students who still owe work first.
    const order = [
      HomeworkStatus.overdue,
      HomeworkStatus.pending,
      HomeworkStatus.late,
      HomeworkStatus.accomplished,
    ];
    final submissions = [...hw['submissions'] as List<HomeworkSubmission>]
      ..sort(
        (a, b) => order.indexOf(a.status).compareTo(order.indexOf(b.status)),
      );
    final assignedAt = hw['assignedAt'] as DateTime;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TeacherSheet(
        title: hw['module'] as String,
        subtitle: [
          'Assigned on ${formatDate(assignedAt)}',
          hw['dueDate'] == null ? 'No due date' : 'Due date: ${hw['dueDate']}',
        ].join(' · '),
        child: submissions.isEmpty
            ? const Text(
                'No students in this class yet',
                style: TextStyle(fontSize: 14, color: AppColors.inkSoft),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final s in submissions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SoftCard(
                        radius: 14,
                        padding: const EdgeInsets.all(12),
                        child: _SubmissionLine(title: s.name, submission: s),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Future<void> _showEditHomework(
    BuildContext context,
    Map<String, dynamic> hw,
  ) async {
    final assignmentId = hw['id'] as String?;
    if (assignmentId == null) return;
    final initialModuleId =
        hw['moduleId'] as String? ?? allGames.first.lesson.id;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => _EditHomeworkDialog(
        title: 'Edit Class Homework',
        initialModuleId: initialModuleId,
        onSave: (newModuleId) async {
          await ClassRepository().updateAssignment(
            id: assignmentId,
            moduleId: newModuleId,
          );
          ref.invalidate(classHomeworkProvider);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Updated homework to "${assignmentTitle(newModuleId)}"',
                ),
              ),
            );
          }
        },
      ),
    );
  }

  Future<void> _confirmDeleteHomework(
    BuildContext context,
    Map<String, dynamic> hw,
  ) async {
    final assignmentId = hw['id'] as String?;
    if (assignmentId == null) return;
    final moduleTitle = hw['module'] as String? ?? 'this module';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        icon: const Icon(
          Icons.delete_outline_rounded,
          color: AppColors.coral,
          size: 36,
        ),
        title: const Text('Delete Homework?'),
        content: Text(
          'Are you sure you want to remove the homework assignment for "$moduleTitle"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.coral),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ClassRepository().deleteAssignment(assignmentId);
      ref.invalidate(classHomeworkProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Removed "$moduleTitle" from homework')),
        );
      }
    }
  }
}

/// A homework row: [title], a status chip (Accomplished / Late / Pending /
/// Overdue), and when it was finished or how far along it is.
class _SubmissionLine extends StatelessWidget {
  const _SubmissionLine({
    required this.title,
    required this.submission,
    this.dueDate,
  });

  final String title;
  final HomeworkSubmission submission;
  final String? dueDate;

  @override
  Widget build(BuildContext context) {
    final s = submission;
    final (fg, bg) = switch (s.status) {
      HomeworkStatus.accomplished => (AppColors.teal, AppColors.mint),
      HomeworkStatus.late => (const Color(0xFF9A5B0B), AppColors.goldTint),
      HomeworkStatus.pending => (AppColors.inkSoft, AppColors.neutralTint),
      HomeworkStatus.overdue => (AppColors.coral, AppColors.coralTint),
    };
    final detail = [
      s.isDone
          ? 'Completed on ${formatDateTime(s.completedAt!)}'
          : '${s.gamesDone} of ${s.gamesTotal} game${s.gamesTotal == 1 ? '' : 's'} done',
      if (dueDate != null) 'Due date: $dueDate',
    ].join(' · ');
    return Column(
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
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                s.status.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: fg,
                ),
              ),
            ),
            Text(
              detail,
              style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft),
            ),
          ],
        ),
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

    // Same three groups as the Parent Hub's Settings: Account & security
    // (its sub-page holds the account cards and Delete account), sound &
    // language, then one divided sheet for sync / log out.
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
              _TeacherLinkFirebaseCard(),
              SizedBox(height: 12),
              ChangePinCard(accentColor: AppColors.gold),
              SizedBox(height: 12),
              ChangePasswordRow(),
            ],
          ),
        ),
      ],
      right: [
        const HubStaggerFadeIn(
          delay: Duration(milliseconds: 80),
          child: HubSectionLabel('Sound & language'),
        ),
        HubStaggerFadeIn(
          delay: const Duration(milliseconds: 95),
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
          delay: Duration(milliseconds: 110),
          child: SoftCard(
            radius: 20,
            padding: EdgeInsets.all(6),
            child: LanguageSettingRow(),
          ),
        ),
        const SizedBox(height: 12),
        const HubStaggerFadeIn(
          delay: Duration(milliseconds: 125),
          child: HubSectionLabel('Data & session'),
        ),
        HubStaggerFadeIn(
          delay: const Duration(milliseconds: 140),
          child: HubRowSheet(
            children: [
              const _SyncCard(),
              HubActionRow(
                icon: Icons.logout_rounded,
                iconColor: AppColors.inkSoft,
                title: 'Exit Settings',
                subtitle: 'Exit settings and lock admin areas',
                trailing: HubRowButton(
                  label: 'Logout',
                  color: AppColors.danger,
                  onPressed: () => _confirmLogout(context, ref),
                ),
              ),
            ],
          ),
        ),
      ],
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
                Flexible(child: Text('Link to Cloud', style: displayText(18))),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'This account isn\'t linked to the cloud yet, so your classes '
              'won\'t show up in the admin website until you link it. '
              'Re-enter your password to link it.',
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
              decoration: _pickerDecoration(hint: 'Account password'),
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

/// Filled field decoration shared by this file's dropdowns and inputs
/// (labels sit above the field, not floating inside it — floating labels
/// get cut off with "…" at large text sizes).
InputDecoration _pickerDecoration({String? hint}) {
  OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: color, width: width),
  );
  return InputDecoration(
    hintText: hint?.tr,
    filled: true,
    fillColor: AppColors.neutralTint,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: border(AppColors.creamBorder, 1.4),
    enabledBorder: border(AppColors.creamBorder, 1.4),
    focusedBorder: border(AppColors.teal, 1.8),
  );
}

/// Two-step "Assign Learning Module" picker: pick one of the Student Hub's
/// games, then one of that game's sessions. [lessonId] is the selected
/// session (a curriculum lesson id) — what gets stored on the assignment.
/// Long game/session names wrap inside the field instead of being cut.
class _GameSessionPicker extends StatelessWidget {
  const _GameSessionPicker({required this.lessonId, required this.onChanged});

  final String lessonId;
  final ValueChanged<String> onChanged;

  static const _labelStyle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );

  @override
  Widget build(BuildContext context) {
    final currentLesson = resolveLessonForId(lessonId);
    final game = gameNameOf(currentLesson);
    final sessions = gameSessions[game] ?? [currentLesson];
    final selectedLessonId = sessions.any((l) => l.id == lessonId)
        ? lessonId
        : currentLesson.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text('Select Game', style: _labelStyle),
        ),
        DropdownButtonFormField<String>(
          initialValue: gameSessions.containsKey(game)
              ? game
              : gameSessions.keys.first,
          isExpanded: true,
          itemHeight: null,
          decoration: _pickerDecoration(),
          items: [
            for (final name in gameSessions.keys)
              DropdownMenuItem(value: name, child: Text(name)),
          ],
          onChanged: (v) {
            if (v != null && v != game) {
              final newGameSessions = gameSessions[v];
              if (newGameSessions != null && newGameSessions.isNotEmpty) {
                onChanged(newGameSessions.first.id);
              }
            }
          },
        ),
        const SizedBox(height: 12),
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text('Select Session', style: _labelStyle),
        ),
        DropdownButtonFormField<String>(
          // Rebuilt per game so it resets to the new game's first session.
          key: ValueKey(game),
          initialValue: selectedLessonId,
          isExpanded: true,
          itemHeight: null,
          decoration: _pickerDecoration(),
          items: [
            for (final lesson in sessions)
              DropdownMenuItem(
                value: lesson.id,
                child: Text(sessionLabelOf(lesson)),
              ),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ],
    );
  }
}

class _EditHomeworkDialog extends StatefulWidget {
  const _EditHomeworkDialog({
    required this.title,
    required this.initialModuleId,
    required this.onSave,
  });

  final String title;
  final String initialModuleId;
  final Future<void> Function(String newModuleId) onSave;

  @override
  State<_EditHomeworkDialog> createState() => _EditHomeworkDialogState();
}

class _EditHomeworkDialogState extends State<_EditHomeworkDialog> {
  late String _selectedModule = resolveLessonForId(widget.initialModuleId).id;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: MediaQuery.sizeOf(context).width < 400 ? 12 : 20,
        vertical: 24,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Icon(
                        Icons.edit_note_rounded,
                        color: AppColors.teal,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(widget.title, style: displayText(20))),
                    IconButton(
                      tooltip: 'Close'.tr,
                      icon: const Icon(Icons.close_rounded, size: 22),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Change Module / Session',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.inkSoft,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _GameSessionPicker(
                        lessonId: _selectedModule,
                        onChanged: (v) => setState(() => _selectedModule = v),
                      ),
                      const SizedBox(height: 20),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          TextButton(
                            onPressed: _saving
                                ? null
                                : () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.teal,
                              minimumSize: const Size(96, 46),
                              shape: const StadiumBorder(),
                            ),
                            onPressed: _saving
                                ? null
                                : () async {
                                    setState(() => _saving = true);
                                    await widget.onSave(_selectedModule);
                                    if (mounted) Navigator.of(context).pop();
                                  },
                            child: _saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Save Changes'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------ pending approval

/// Teacher verification (SL-TEA-03): true while an admin hasn't approved this
/// teacher yet. Watching the session means approval (a status refresh swaps
/// the state instance) unlocks the dashboard without a restart.
bool _watchTeacherPending(WidgetRef ref) {
  ref.watch(sessionProvider);
  return ref.read(sessionProvider.notifier).activeTeacherStatus == 'pending';
}

/// In-dashboard notice for a teacher still awaiting admin approval. Checks
/// the server once on open, same as the full-screen pending gate does.
class _PendingApprovalBanner extends ConsumerStatefulWidget {
  const _PendingApprovalBanner();

  @override
  ConsumerState<_PendingApprovalBanner> createState() =>
      _PendingApprovalBannerState();
}

class _PendingApprovalBannerState
    extends ConsumerState<_PendingApprovalBanner> {
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    if (_checking) return;
    setState(() => _checking = true);
    await ref.read(sessionProvider.notifier).refreshTeacherStatus();
    if (!mounted) return;
    setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      color: AppColors.goldTint,
      borderColor: AppColors.goldSoft,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.hourglass_top_rounded,
            size: 26,
            color: AppColors.gold,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Waiting for approval',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "An administrator is reviewing your teacher account. "
                  "Classes and teacher tools unlock once it's approved.",
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    minimumSize: const Size(0, 44),
                  ),
                  onPressed: _checking ? null : _check,
                  child: _checking
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Check status',
                          style: TextStyle(fontWeight: FontWeight.bold),
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

/// Dims a dashboard tab and blocks taps, focus and screen-reader actions on
/// it while the teacher is pending. The router separately keeps every other
/// /teacher and /cast route closed, so this only has to cover the tabs.
class _PendingLock extends StatelessWidget {
  const _PendingLock({required this.locked, required this.child});

  final bool locked;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!locked) return child;
    return IgnorePointer(
      child: ExcludeFocus(
        child: ExcludeSemantics(child: Opacity(opacity: 0.4, child: child)),
      ),
    );
  }
}
