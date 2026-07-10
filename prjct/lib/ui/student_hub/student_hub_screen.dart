import 'dart:ui' as ui;
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../data/models/custom_lesson.dart';
import '../../logic/auth/session.dart';
import '../../logic/notifications/notification_provider.dart';
import '../../logic/recent_module_provider.dart';
import '../../logic/teacher/teacher_providers.dart';
import '../core_modules/module_registry.dart';
import '../theme/app_colors.dart';
import 'notifications_sheet.dart';
import '../widgets/learner_avatar.dart';
import '../teacher_dashboard/teacher_dashboard_screen.dart';

enum _ModuleStatus { done, inProgress, notStarted, locked }

/// Chunks [items] into consecutive pairs (a trailing odd item becomes a
/// list of one) for the module grid's two-up row layout.
List<List<T>> _pairs<T>(List<T> items) => [
  for (var i = 0; i < items.length; i += 2)
    items.sublist(i, i + 2 > items.length ? items.length : i + 2),
];

/// Student Hub Screen — mirrors the generated visual redesign mockup:
/// Glassmorphic dark green greeting header, twin stats cards (Day Streak and Progress Ring),
/// float-animated continue card, centered Bento module cards, daily-goal banner,
/// and a weekly progress shelf featuring large gold stars.
class StudentHubScreen extends ConsumerStatefulWidget {
  const StudentHubScreen({super.key});

  @override
  ConsumerState<StudentHubScreen> createState() => _StudentHubScreenState();
}

class _StudentHubScreenState extends ConsumerState<StudentHubScreen>
    with TickerProviderStateMixin {
  final _scrollController = ScrollController();
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  );

  static const _statusByModuleId = {
    'tracing': _ModuleStatus.done,
    'flashcards': _ModuleStatus.inProgress,
    'recitation': _ModuleStatus.notStarted,
    'stories': _ModuleStatus.notStarted,
    'sorting': _ModuleStatus.notStarted,
  };

  static const _weekDayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  bool _isModuleAssigned(String moduleId, WidgetRef ref) {
    final override = ref.watch(progressionOverrideProvider);
    if (override) return true;

    final classHomeworks = ref.watch(classHomeworkProvider);
    final isClassAssigned = classHomeworks.any((hw) {
      final moduleName = hw['module'] as String? ?? '';
      return _doesModuleNameMatchId(moduleName, moduleId);
    });
    if (isClassAssigned) return true;

    final learner = ref.watch(sessionProvider).learner;
    if (learner != null) {
      final students = ref.watch(teacherRosterProvider);
      final currentStudent = students.firstWhere(
        (s) => s['learnerId'] == learner.id,
        orElse: () => <String, dynamic>{},
      );
      final studentAssigned =
          currentStudent['assignedModules'] as List<dynamic>? ?? [];
      final isStudentAssigned = studentAssigned.any((hw) {
        final moduleText = hw as String? ?? '';
        return _doesModuleNameMatchId(moduleText, moduleId);
      });
      if (isStudentAssigned) return true;
    }
    return true;
  }

  bool _doesModuleNameMatchId(String name, String id) {
    final cleanName = name.toLowerCase();
    return switch (id) {
      'tracing' => cleanName.contains('tracing') || cleanName.contains('alif'),
      'flashcards' =>
        cleanName.contains('song') ||
            cleanName.contains('practice') ||
            cleanName.contains('flashcards') ||
            cleanName.contains('sounds'),
      'recitation' =>
        cleanName.contains('recitation') ||
            cleanName.contains('pronunciation') ||
            cleanName.contains('ج') ||
            cleanName.contains('qur\'an') ||
            cleanName.contains('hadith'),
      'sorting' =>
        cleanName.contains('sequence') ||
            cleanName.contains('matcher') ||
            cleanName.contains('sort') ||
            cleanName.contains('match'),
      'stories' => cleanName.contains('stories') || cleanName.contains('story'),
      _ => false,
    };
  }

  void _showLockedDialog(BuildContext context, String moduleTitle) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.lock_outline_rounded,
          color: AppColors.coral,
          size: 44,
        ),
        title: Text('$moduleTitle is Locked'),
        content: const Text(
          'This module is not currently assigned by your teacher. Please ask your teacher or parent to assign it to you!',
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
  }

  double _progressFor(_ModuleStatus status) => switch (status) {
    _ModuleStatus.done => 1.0,
    _ModuleStatus.inProgress => 0.6,
    _ModuleStatus.notStarted => 0.0,
    _ModuleStatus.locked => 0.0,
  };

  String _cardSubtitleFor(ModuleInfo module) {
    final status = _isModuleAssigned(module.id, ref)
        ? (_statusByModuleId[module.id] ?? _ModuleStatus.notStarted)
        : _ModuleStatus.locked;
    return switch (status) {
      _ModuleStatus.done => 'All cards completed! 🎉',
      _ModuleStatus.inProgress => '2 of 5 cards left',
      _ModuleStatus.notStarted => '5 cards left',
      _ModuleStatus.locked => 'Locked by ustadzah',
    };
  }

  @override
  void initState() {
    super.initState();
    if (!WidgetsBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations) {
      _entrance.forward();
    } else {
      _entrance.value = 1;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _entrance.dispose();
    super.dispose();
  }

  Widget _staggerIn(Widget child, double start, double end) {
    final curved = CurvedAnimation(
      parent: _entrance,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: curved.drive(
          Tween(begin: const Offset(0, .06), end: Offset.zero),
        ),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final learner = ref.watch(sessionProvider).learner;
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    final streakDays = ref.watch(learnerStreakProvider);
    final todayCompleted = ref.watch(learnerCompletedTodayProvider);
    const todayGoal = 5;

    final recentModuleId = ref.watch(recentModuleProvider);
    final continueModule = recentModuleId != null
        ? coreModules.firstWhere((m) => m.id == recentModuleId)
        : coreModules.firstWhere(
            (m) => _statusByModuleId[m.id] == _ModuleStatus.inProgress,
            orElse: () => coreModules.first,
          );
    final listModules = coreModules;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: CustomPaint(
        painter: _DesertSunsetBackgroundPainter(),
        child: SafeArea(
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _staggerIn(
                      _Header(
                        avatar: learner?.avatar ?? '🧒',
                        name: learner?.name ?? 'friend',
                        unreadCount: unreadCount,
                        onBellTap: () => NotificationsSheet.show(context),
                      ),
                      0.0,
                      0.5,
                    ),
                    const SizedBox(height: 16),
                    _staggerIn(
                      _StatsRow(
                        streakDays: streakDays,
                        todayCompleted: todayCompleted,
                        todayGoal: todayGoal,
                      ),
                      0.08,
                      0.55,
                    ),
                    const SizedBox(height: 16),
                    _staggerIn(
                      _ContinueCard(
                        module: continueModule,
                        subtitle: _cardSubtitleFor(continueModule),
                        onTap: () {
                          ref
                              .read(recentModuleProvider.notifier)
                              .interactWith(continueModule.id);
                          context.go('/module/${continueModule.id}');
                        },
                      ),
                      0.16,
                      0.6,
                    ),
                    const SizedBox(height: 22),
                    _staggerIn(const _SectionHeader(), 0.2, 0.6),
                    const SizedBox(height: 12),
                    for (final rowModules in _pairs(
                      listModules.indexed.toList(),
                    ))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final (j, (i, module))
                                in rowModules.indexed) ...[
                              if (j > 0) const SizedBox(width: 12),
                              Expanded(
                                child: _staggerIn(
                                  _ModuleCard(
                                    module: module,
                                    status: _isModuleAssigned(module.id, ref)
                                        ? (_statusByModuleId[module.id] ??
                                              _ModuleStatus.notStarted)
                                        : _ModuleStatus.locked,
                                    progress: _progressFor(
                                      _isModuleAssigned(module.id, ref)
                                          ? (_statusByModuleId[module.id] ??
                                                _ModuleStatus.notStarted)
                                          : _ModuleStatus.locked,
                                    ),
                                    onTap: () {
                                      if (_isModuleAssigned(module.id, ref)) {
                                        ref
                                            .read(recentModuleProvider.notifier)
                                            .interactWith(module.id);
                                        context.go('/module/${module.id}');
                                      } else {
                                        _showLockedDialog(
                                          context,
                                          module.title,
                                        );
                                      }
                                    },
                                  ),
                                  (0.22 + i * 0.06).clamp(0.0, 1.0),
                                  (0.55 + i * 0.06).clamp(0.0, 1.0),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    if (learner?.id != null &&
                        ref
                            .watch(learnerCustomLessonsProvider(learner!.id!))
                            .isNotEmpty) ...[
                      const SizedBox(height: 18),
                      _staggerIn(
                        _CustomLessonsSection(
                          lessons: ref.watch(
                            learnerCustomLessonsProvider(learner.id!),
                          ),
                        ),
                        0.26,
                        0.64,
                      ),
                    ],
                    const SizedBox(height: 18),
                    _staggerIn(
                      _DailyGoalCard(
                        goal: todayGoal,
                        onTap: () {
                          ref
                              .read(recentModuleProvider.notifier)
                              .interactWith(continueModule.id);
                          context.go('/module/${continueModule.id}');
                        },
                      ),
                      0.3,
                      0.68,
                    ),
                    const SizedBox(height: 12),
                    _staggerIn(
                      _StreakStrip(
                        streakDays: streakDays,
                        weekDayLabels: _weekDayLabels,
                      ),
                      0.34,
                      0.72,
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.avatar,
    required this.name,
    required this.unreadCount,
    required this.onBellTap,
  });

  final String avatar;
  final String name;
  final int unreadCount;
  final VoidCallback onBellTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(
          0xDD0A4F3E,
        ), // Translucent deep green glass card from mockup
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1.5,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          LearnerAvatar(avatar: avatar, size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Assalamu'alaikum,",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  "$name!",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      color: AppColors.gold,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Your Journey Today 🕌',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Mosque outline label from mockup
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.mosque_outlined, color: Colors.white, size: 24),
              const SizedBox(height: 2),
              Text(
                'SalamLearn',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          _BellButton(unreadCount: unreadCount, onTap: onBellTap),
        ],
      ),
    );
  }
}

class _BellButton extends StatelessWidget {
  const _BellButton({required this.unreadCount, required this.onTap});

  final int unreadCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 1,
      shadowColor: const Color(0x1A2C2C2A),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.creamBorder),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Center(
                child: Icon(
                  Icons.notifications_outlined,
                  color: AppColors.teal,
                  size: 20,
                ),
              ),
              if (unreadCount > 0)
                Positioned(
                  top: 7,
                  right: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: AppColors.coral,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
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

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.streakDays,
    required this.todayCompleted,
    required this.todayGoal,
  });

  final int streakDays;
  final int todayCompleted;
  final int todayGoal;

  @override
  Widget build(BuildContext context) {
    final progressPercent = (todayCompleted / todayGoal * 100).round();
    return Row(
      children: [
        // Day Streak Card (Mockup styled)
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.creamBorder, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      'Day Streak',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink,
                      ),
                    ),
                    Icon(
                      Icons.local_fire_department_rounded,
                      color: AppColors.gold,
                      size: 16,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$streakDays',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: AppColors.ink,
                            ),
                          ),
                          Text(
                            '$streakDays Days Strong!',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Lottie.asset(
                      'assets/lottie/flame_streak.json',
                      width: 38,
                      height: 38,
                      fit: BoxFit.contain,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        // My Progress Card (Mockup styled with circular ring)
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.creamBorder, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      'My Progress',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink,
                      ),
                    ),
                    Icon(
                      Icons.track_changes_rounded,
                      color: AppColors.coral,
                      size: 16,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$progressPercent%',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              color: AppColors.ink,
                            ),
                          ),
                          const Text(
                            'Complete',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 38,
                      height: 38,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CircularProgressIndicator(
                              value: todayCompleted / todayGoal,
                              strokeWidth: 4.5,
                              backgroundColor: AppColors.creamBorder,
                              valueColor: const AlwaysStoppedAnimation(
                                AppColors.teal,
                              ),
                            ),
                          ),
                          Center(
                            child: Text(
                              '$progressPercent%',
                              style: const TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                color: AppColors.teal,
                              ),
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
      ],
    );
  }
}

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
      scale: _pressed ? 0.96 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: widget.builder(context, (v) => setState(() => _pressed = v)),
    );
  }
}

class _ContinueCard extends StatefulWidget {
  const _ContinueCard({
    required this.module,
    required this.subtitle,
    required this.onTap,
  });

  final ModuleInfo module;
  final String subtitle;
  final VoidCallback onTap;

  @override
  State<_ContinueCard> createState() => _ContinueCardState();
}

class _ContinueCardState extends State<_ContinueCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _mascotFloatController;

  @override
  void initState() {
    super.initState();
    _mascotFloatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (kIsWeb || !Platform.environment.containsKey('FLUTTER_TEST')) {
      _mascotFloatController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _mascotFloatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final illustration = widget.module.illustrationAsset;
    return _PressScale(
      builder: (context, setPressed) => Material(
        color: AppColors.teal,
        borderRadius: BorderRadius.circular(26),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          onHighlightChanged: setPressed,
          child: Stack(
            children: [
              const Positioned(
                right: -60,
                top: -70,
                child: _ContinueBlob(size: 170, color: Color(0x14FFFFFF)),
              ),
              const Positioned(
                left: -45,
                bottom: -55,
                child: _ContinueBlob(size: 130, color: Color(0x0FFFFFFF)),
              ),

              const Positioned(
                right: 78,
                top: 58,
                child: Text(
                  '✦',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ),
              const Positioned(
                right: 48,
                top: 86,
                child: Text(
                  '✦',
                  style: TextStyle(fontSize: 10, color: Colors.white70),
                ),
              ),
              if (illustration != null)
                Positioned(
                  right: -15,
                  bottom: -15,
                  child: AnimatedBuilder(
                    animation: _mascotFloatController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, -8 * _mascotFloatController.value),
                        child: child,
                      );
                    },
                    child: Image.asset(
                      illustration,
                      width: 220,
                      fit: BoxFit.contain,
                      cacheWidth: (220 * MediaQuery.devicePixelRatioOf(context))
                          .round(),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.star_rounded,
                                color: Colors.white,
                                size: 13,
                              ),
                              SizedBox(width: 5),
                              Text(
                                'CONTINUE LEARNING',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.module.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: const TextStyle(
                        color: Color(0xBFFFFFFF),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1F000000),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text(
                            'Continue Lesson',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: AppColors.tealDark,
                              fontSize: 13,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: 16,
                            color: AppColors.tealDark,
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
      ),
    );
  }
}

class _ContinueBlob extends StatelessWidget {
  const _ContinueBlob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(
          child: Text(
            'Your Learning Modules',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.ink,
            ),
          ),
        ),
        SizedBox(width: 8),
        Text(
          'View all',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: AppColors.teal,
          ),
        ),
      ],
    );
  }
}

/// Redesigned Centered Bento Module Card from visual mockup
class _ModuleCard extends StatelessWidget {
  const _ModuleCard({
    required this.module,
    required this.status,
    required this.progress,
    required this.onTap,
  });

  final ModuleInfo module;
  final _ModuleStatus status;
  final double progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final locked = status == _ModuleStatus.locked;

    return _PressScale(
      builder: (context, setPressed) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: locked ? null : onTap,
          onHighlightChanged: locked ? null : setPressed,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: locked ? AppColors.creamBorder : module.color,
                width: 3.0, // Solid colored border from mockup
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x06000000),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Opacity(
              opacity: locked ? .55 : 1,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Circular Icon Chip
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: module.color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: locked
                        ? const Icon(
                            Icons.lock_outline_rounded,
                            size: 22,
                            color: AppColors.textMuted,
                          )
                        : Icon(module.icon, size: 24, color: module.color),
                  ),
                  const SizedBox(height: 12),
                  // Centered Title
                  Text(
                    module.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: AppColors.ink,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  // Centered Subtitle Description
                  Text(
                    module.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      height: 1.3,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  // Progress indicator line along bottom of chip
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 5,
                            backgroundColor: AppColors.creamBorder,
                            valueColor: AlwaysStoppedAnimation(module.color),
                          ),
                        ),
                      ),
                      if (progress >= 1.0) ...[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.check_circle_rounded,
                          color: module.color,
                          size: 14,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Freeform lessons the learner's teacher(s) wrote, shown between the core
/// module grid and the daily-goal banner. Hidden entirely when empty (the
/// `if` guard at the call site) rather than showing an empty-state card —
/// most learners will never have one, so a permanent "nothing here yet"
/// panel would just be visual noise on every hub visit.
class _CustomLessonsSection extends StatelessWidget {
  const _CustomLessonsSection({required this.lessons});

  final List<CustomLesson> lessons;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'From Your Teacher',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 10),
        for (final lesson in lessons)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => context.go('/custom-lesson/${lesson.id}'),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.creamBorder, width: 1.4),
                ),
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
                        Icons.menu_book_outlined,
                        color: AppColors.gold,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        lesson.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DailyGoalCard extends StatelessWidget {
  const _DailyGoalCard({required this.goal, required this.onTap});

  final int goal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.mint,
        border: Border.all(color: AppColors.mintBorder, width: 1.5),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.track_changes_rounded,
              size: 18,
              color: AppColors.teal,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Daily Goal',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                  ),
                ),
                Text(
                  'Complete $goal cards today',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: onTap,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.teal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            child: const Text("Let's go!"),
          ),
        ],
      ),
    );
  }
}

/// Redesigned Weekly Progress Shelf Card from visual mockup
class _StreakStrip extends StatelessWidget {
  const _StreakStrip({required this.streakDays, required this.weekDayLabels});

  final int streakDays;
  final List<String> weekDayLabels;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.creamBorder, width: 2),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Weekly Progress',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final (i, label) in weekDayLabels.indexed)
                _DayChip(label: label, done: i < streakDays),
            ],
          ),
        ],
      ),
    );
  }
}

/// Redesigned circular gold star day chip with labels underneath from mockup
class _DayChip extends StatelessWidget {
  const _DayChip({required this.label, required this.done});

  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: done ? const Color(0xFFFFF0D4) : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: done ? AppColors.gold : AppColors.creamBorder,
              width: 2,
            ),
            boxShadow: done
                ? const [
                    BoxShadow(
                      color: Color(0x22EF9F27),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.star_rounded,
            color: done ? AppColors.gold : AppColors.creamBorder,
            size: 20,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }
}

class _DesertSunsetBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // 1. Sky Sunset Gradient
    final skyPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, 0),
        Offset(0, size.height),
        [
          const Color(0xFFFEE8C0), // sunset orange-yellow
          const Color(0xFFFFF7E6), // warm yellow-cream
          AppColors.cream,
        ],
        [0.0, 0.5, 1.0],
      );
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), skyPaint);

    // 2. A warm sun in the background
    final sunPaint = Paint()
      ..color = const Color(0xFFFFE5B4).withValues(alpha: 0.7);
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.12),
      48,
      sunPaint,
    );

    final sunInnerPaint = Paint()
      ..color = const Color(0xFFFFF0D4).withValues(alpha: 0.9);
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.12),
      30,
      sunInnerPaint,
    );

    // 3. Clouds in the sky
    final cloudPaint = Paint()..color = Colors.white.withValues(alpha: 0.55);
    _drawCloud(
      canvas,
      Offset(size.width * 0.18, size.height * 0.08),
      24,
      cloudPaint,
    );
    _drawCloud(
      canvas,
      Offset(size.width * 0.62, size.height * 0.06),
      18,
      cloudPaint,
    );

    // 4. Soft Sand Hills at the bottom
    final hillPaint1 = Paint()..color = const Color(0xFFF4EBD7);
    final path1 = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, size.height * 0.78)
      ..quadraticBezierTo(
        size.width * 0.35,
        size.height * 0.74,
        size.width * 0.65,
        size.height * 0.8,
      )
      ..quadraticBezierTo(
        size.width * 0.85,
        size.height * 0.84,
        size.width,
        size.height * 0.76,
      )
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path1, hillPaint1);

    final hillPaint2 = Paint()..color = const Color(0xFFEADFC9);
    final path2 = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, size.height * 0.86)
      ..quadraticBezierTo(
        size.width * 0.25,
        size.height * 0.88,
        size.width * 0.52,
        size.height * 0.83,
      )
      ..quadraticBezierTo(
        size.width * 0.78,
        size.height * 0.78,
        size.width,
        size.height * 0.85,
      )
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path2, hillPaint2);
  }

  void _drawCloud(Canvas canvas, Offset center, double radius, Paint paint) {
    canvas.drawCircle(center, radius, paint);
    canvas.drawCircle(
      Offset(center.dx - radius * 0.6, center.dy),
      radius * 0.7,
      paint,
    );
    canvas.drawCircle(
      Offset(center.dx + radius * 0.6, center.dy),
      radius * 0.7,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
