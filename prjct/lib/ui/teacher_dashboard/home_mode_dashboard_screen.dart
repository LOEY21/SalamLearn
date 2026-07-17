import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/progress_record.dart';
import '../../data/repositories/class_repository.dart';
import '../../data/repositories/progress_repository.dart';
import '../../logic/teacher/home_mode_providers.dart';
import '../../logic/teacher/teacher_providers.dart';
import '../theme/app_colors.dart';
import '../widgets/soft_card.dart';
import 'teacher_dashboard_screen.dart' show masteryBarColor, MasteryPill, avatarColor;

/// FR-6.2B Home Mode Monitoring Dashboard — a dedicated screen kept
/// deliberately separate from the Classroom tab's Class Health Index
/// (Hot-Seat/Cast telemetry only). Everything on this screen reads
/// `home_mode_providers.dart`, which filters `isClassroomMode == false`
/// end to end, so solo Student Hub/Adventure Map play and live classroom
/// data can never mix in either direction.
///
/// Same flat-appbar + hero-chip visual language as
/// `ClassroomManagementScreen`/`ClassDetailScreen` — a segmented
/// Individual/Aggregate toggle stands in for those screens' chip row.
class HomeModeDashboardScreen extends ConsumerStatefulWidget {
  const HomeModeDashboardScreen({super.key});

  @override
  ConsumerState<HomeModeDashboardScreen> createState() =>
      _HomeModeDashboardScreenState();
}

enum _HomeModeView { individual, aggregate }

class _HomeModeDashboardScreenState
    extends ConsumerState<HomeModeDashboardScreen> {
  _HomeModeView _view = _HomeModeView.individual;
  String? _selectedLearnerId;

  void _goBack() => context.go('/teacher?tab=1');

  @override
  Widget build(BuildContext context) {
    final section = ref.watch(teacherClassControllerProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: Column(
            children: [
              _HomeModeAppBar(onBack: _goBack),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
                child: _ViewToggle(
                  view: _view,
                  onChanged: (v) => setState(() => _view = v),
                ),
              ),
              const Divider(height: 1, color: AppColors.creamBorder),
              Expanded(
                child: section == null
                    ? const _NoClassState()
                    : _PanelRise(
                        key: ValueKey('${_view}_${_selectedLearnerId}'),
                        child: _view == _HomeModeView.individual
                            ? _IndividualView(
                                classId: section.id,
                                selectedLearnerId: _selectedLearnerId,
                                onSelect: (id) =>
                                    setState(() => _selectedLearnerId = id),
                              )
                            : _AggregateView(classId: section.id),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeModeAppBar extends StatelessWidget {
  const _HomeModeAppBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 18, 4),
      child: Row(
        children: [
          Material(
            color: AppColors.neutralTint,
            borderRadius: BorderRadius.circular(11),
            child: InkWell(
              borderRadius: BorderRadius.circular(11),
              onTap: onBack,
              child: const SizedBox(
                width: 34,
                height: 34,
                child: Icon(
                  Icons.arrow_back_rounded,
                  size: 18,
                  color: AppColors.ink,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'HOME MODE INSIGHTS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: AppColors.textMuted,
                  ),
                ),
                Text(
                  'Home Performance',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: AppColors.ink,
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

/// Pill toggle matching `RoleTabs`' teal-outline/teal-fill treatment
/// (`ui/auth/role_tabs.dart`) rather than a Material `SegmentedButton`, so
/// this screen reads as the same design system as the PIN gate and every
/// other hand-styled control in the app.
class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.view, required this.onChanged});

  final _HomeModeView view;
  final ValueChanged<_HomeModeView> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.teal, width: 1.2),
      ),
      child: Row(
        children: [
          _segment(_HomeModeView.individual, 'Individual'),
          _segment(_HomeModeView.aggregate, 'Aggregate'),
        ],
      ),
    );
  }

  Widget _segment(_HomeModeView value, String label) {
    final active = view == value;
    final color = active ? Colors.white : AppColors.teal;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: active ? AppColors.teal : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NoClassState extends StatelessWidget {
  const _NoClassState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.home_outlined, size: 40, color: AppColors.textMuted),
            SizedBox(height: 12),
            Text(
              'No class selected',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: AppColors.ink,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Create or select a class from the Classroom tab first.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ individual

/// Individual Progress Tracking (FR-6.2B): pick a student, see their
/// longitudinal Home Mode mastery per destination plus a completion
/// history — all sourced from `homeModeHistoryProvider`/
/// `homeModeModuleSummaryProvider`, both Classroom-Mode-record-free.
class _IndividualView extends ConsumerWidget {
  const _IndividualView({
    required this.classId,
    required this.selectedLearnerId,
    required this.onSelect,
  });

  final String classId;
  final String? selectedLearnerId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roster = ref.watch(classRosterProvider(classId));

    if (roster.isEmpty) {
      return const _EmptyBody(
        icon: Icons.groups_outlined,
        title: 'No students yet',
        message: 'Enroll students into this class to see their Home Mode history.',
      );
    }

    final activeId = selectedLearnerId ?? roster.first['learnerId'] as String;
    final activeName = roster.firstWhere(
      (s) => s['learnerId'] == activeId,
      orElse: () => roster.first,
    )['name'] as String;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      children: [
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: roster.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final student = roster[i];
              final id = student['learnerId'] as String;
              final name = student['name'] as String;
              final active = id == activeId;
              final mastery = student['mastery'] as String? ?? 'Needs help';
              final initial = name.isEmpty ? '?' : name[0].toUpperCase();

              return GestureDetector(
                onTap: () => onSelect(id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: active ? AppColors.teal : AppColors.neutralTint,
                    borderRadius: BorderRadius.circular(19),
                    border: Border.all(
                      color: active ? AppColors.teal : AppColors.creamBorder,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: active ? Colors.white24 : avatarColor(mastery),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initial,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: active ? Colors.white : AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        _StaggerFadeIn(
          delay: const Duration(milliseconds: 35),
          child: _StudentProfileCard(learnerId: activeId, studentName: activeName),
        ),
        const SizedBox(height: 14),
        _StaggerFadeIn(
          delay: const Duration(milliseconds: 70),
          child: _StudentWeeklyChart(
            learnerId: activeId,
            history: ref.watch(homeModeHistoryProvider(activeId)),
          ),
        ),
        const SizedBox(height: 18),
        _StaggerFadeIn(
          delay: const Duration(milliseconds: 105),
          child: Text(
            '$activeName · MASTERY BY ADVENTURE',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: AppColors.textMuted,
            ),
          ),
        ),
        const SizedBox(height: 10),
        _StaggerFadeIn(
          delay: const Duration(milliseconds: 105),
          child: _IndividualMasteryCard(learnerId: activeId),
        ),
        const SizedBox(height: 22),
        const _StaggerFadeIn(
          delay: Duration(milliseconds: 140),
          child: Text(
            'COMPLETION HISTORY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: AppColors.textMuted,
            ),
          ),
        ),
        const SizedBox(height: 10),
        _StaggerFadeIn(
          delay: const Duration(milliseconds: 140),
          child: _HistoryCard(learnerId: activeId),
        ),
      ],
    );
  }
}

class _StudentProfileCard extends ConsumerWidget {
  const _StudentProfileCard({required this.learnerId, required this.studentName});

  final String learnerId;
  final String studentName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(homeModeHistoryProvider(learnerId));
    final streak = ProgressRepository().currentStreak(learnerId);

    final totalSeconds = history.fold<int>(0, (sum, r) => sum + r.timeOnTaskSeconds.toInt());
    final playtimeMinutes = totalSeconds ~/ 60;

    final avgAccuracy = history.isEmpty
        ? 0.0
        : history.map((r) => r.strokeAccuracyPct).reduce((a, b) => a + b) /
            history.length;

    String overallMastery = 'Needs help';
    if (avgAccuracy >= 80) {
      overallMastery = 'High';
    } else if (avgAccuracy >= 50) {
      overallMastery = 'Medium';
    }

    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: avatarColor(overallMastery),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  studentName.isEmpty ? '?' : studentName[0].toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      studentName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          Icons.local_fire_department_rounded,
                          color: AppColors.gold,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$streak-day streak',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _AccuracyRing(accuracyPct: avgAccuracy),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.creamBorder),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _HeroStat(
                  value: '${playtimeMinutes}m',
                  label: 'HOME PLAYTIME',
                ),
              ),
              Expanded(
                child: _HeroStat(
                  value: '${avgAccuracy.round()}% match',
                  label: 'AVG ACCURACY',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Accuracy donut replacing the old two flat mint/gold stat boxes — puts
/// the single most important number (average stroke accuracy) front and
/// center as a ring rather than buried in a label/value pair.
class _AccuracyRing extends StatelessWidget {
  const _AccuracyRing({required this.accuracyPct});

  final double accuracyPct;

  @override
  Widget build(BuildContext context) {
    final targetValue = (accuracyPct / 100).clamp(0.0, 1.0);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: targetValue),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, val, child) {
        return SizedBox(
          width: 56,
          height: 56,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const SizedBox(
                width: 56,
                height: 56,
                child: CircularProgressIndicator(
                  value: 1,
                  strokeWidth: 6,
                  color: AppColors.creamDark,
                ),
              ),
              SizedBox(
                width: 56,
                height: 56,
                child: CircularProgressIndicator(
                  value: val,
                  strokeWidth: 6,
                  strokeCap: StrokeCap.round,
                  backgroundColor: Colors.transparent,
                  color: AppColors.teal,
                ),
              ),
              Text(
                '${(val * 100).round()}%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.tealDark,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class _StudentWeeklyChart extends StatelessWidget {
  const _StudentWeeklyChart({required this.learnerId, required this.history});

  final String learnerId;
  final List<ProgressRecord> history;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = List.generate(5, (i) => DateTime(now.year, now.month, now.day).subtract(Duration(days: 4 - i)));
    
    final dailySeconds = days.map((day) {
      final records = history.where((r) {
        final rDate = DateTime(r.completedAt.year, r.completedAt.month, r.completedAt.day);
        return rDate.isAtSameMomentAs(day);
      });
      return records.isEmpty ? 0 : records.map((r) => r.timeOnTaskSeconds).reduce((a, b) => a + b);
    }).toList();

    final maxVal = dailySeconds.map((s) => s).reduce((a, b) => a > b ? a : b);
    final maxScale = maxVal == 0 ? 1 : maxVal;

    final weekdayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WEEKLY PROGRESS',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMuted,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Minutes practiced per day at home',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Icon(
                Icons.bar_chart_rounded,
                color: AppColors.teal,
                size: 16,
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 102,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(5, (i) {
                final day = days[i];
                final seconds = dailySeconds[i];
                final minutes = seconds / 60;
                final ratio = seconds / maxScale;
                final height = (ratio * 60).clamp(6.0, 60.0);
                final isToday = i == 4;

                final targetHeight = seconds == 0 ? 6.0 : height;
                return TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: seconds == 0 ? 6.0 : 0.0, end: targetHeight),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, animatedHeight, child) {
                    final animatedMinutes = seconds == 0 ? 0 : (minutes * (animatedHeight / targetHeight)).round();
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          seconds == 0 ? '' : '${animatedMinutes}m',
                          style: const TextStyle(
                            fontSize: 8.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.tealDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 24,
                          height: animatedHeight,
                          decoration: seconds == 0
                              ? BoxDecoration(
                                  border: Border.all(
                                    color: AppColors.creamDark,
                                    width: 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                )
                              : BoxDecoration(
                                  color: AppColors.teal,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          weekdayNames[day.weekday % 7],
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: isToday ? AppColors.teal : AppColors.textMuted,
                          ),
                        ),
                      ],
                    );
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal ring-tile scroller — replaces the old vertical list so a
/// class's worth of destinations reads as a scannable strip rather than a
/// stacked report, matching the redesign mock's adventure-tile layout.
class _IndividualMasteryCard extends ConsumerWidget {
  const _IndividualMasteryCard({required this.learnerId});

  final String learnerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modules = ref.watch(homeModeModuleSummaryProvider(learnerId));

    if (modules.isEmpty) {
      return const SoftCard(
        child: Text(
          'No Home Mode activity recorded yet.',
          style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
        ),
      );
    }

    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: modules.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) => _AdventureTile(module: modules[i]),
      ),
    );
  }
}

class _AdventureTile extends StatelessWidget {
  const _AdventureTile({required this.module});

  final HomeModeModuleSummary module;

  static String _tierFor(double accuracyPct) {
    if (accuracyPct >= 80) return 'High';
    if (accuracyPct >= 50) return 'Medium';
    return 'Needs help';
  }

  @override
  Widget build(BuildContext context) {
    final tier = _tierFor(module.accuracyPct);
    return Container(
      width: 104,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.neutralTint,
        border: Border.all(color: AppColors.creamBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: (module.accuracyPct / 100).clamp(0.0, 1.0)),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, val, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    const SizedBox(
                      width: 44,
                      height: 44,
                      child: CircularProgressIndicator(
                        value: 1,
                        strokeWidth: 5,
                        color: AppColors.creamDark,
                      ),
                    ),
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: CircularProgressIndicator(
                        value: val,
                        strokeWidth: 5,
                        strokeCap: StrokeCap.round,
                        backgroundColor: Colors.transparent,
                        color: masteryBarColor(tier),
                      ),
                    ),
                    Text(
                      '${(val * 100).round()}%',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            module.moduleName,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, height: 1.2),
          ),
          const SizedBox(height: 3),
          Text(
            '${module.sessionCount} session${module.sessionCount == 1 ? '' : 's'}',
            style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends ConsumerWidget {
  const _HistoryCard({required this.learnerId});

  final String learnerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(homeModeHistoryProvider(learnerId));

    if (history.isEmpty) {
      return const SoftCard(
        child: Text(
          'Nothing completed at home yet.',
          style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
        ),
      );
    }

    final recent = history.take(12).toList();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekAgo = today.subtract(const Duration(days: 7));

    String bucketFor(DateTime date) {
      final day = DateTime(date.year, date.month, date.day);
      if (day.isAtSameMomentAs(today)) return 'Today';
      if (day.isAfter(weekAgo)) return 'This week';
      return 'Earlier';
    }

    String? lastBucket;

    return SoftCard(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < recent.length; i++) ...[
            Builder(
              builder: (context) {
                final bucket = bucketFor(recent[i].completedAt);
                final showHeader = bucket != lastBucket;
                lastBucket = bucket;
                if (!showHeader) return const SizedBox.shrink();
                return Padding(
                  padding: EdgeInsets.only(
                    left: 12,
                    top: i == 0 ? 8 : 12,
                    bottom: 4,
                  ),
                  child: Text(
                    bucket.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                );
              },
            ),
            _HistoryRow(record: recent[i]),
            if (i != recent.length - 1 &&
                bucketFor(recent[i + 1].completedAt) == bucketFor(recent[i].completedAt))
              const Divider(height: 1, color: AppColors.creamBorder),
          ],
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.record});

  final ProgressRecord record;

  @override
  Widget build(BuildContext context) {
    final date = record.completedAt;
    final moduleName = destinationNameForModuleId(record.moduleId);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(right: 10),
            decoration: const BoxDecoration(
              color: AppColors.mintGreen,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Text(
              moduleName,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.mint,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${record.strokeAccuracyPct.round()}%',
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: AppColors.tealDark,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${date.month}/${date.day}',
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- aggregate

/// Aggregate Home Performance View (FR-6.2B): class-wide mastery trend per
/// destination, plus a misconception banner for whichever module the class
/// is collectively weakest in.
class _AggregateView extends ConsumerWidget {
  const _AggregateView({required this.classId});

  final String classId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(homeModeAggregateProvider(classId));
    final weakest = weakestHomeModeAggregate(rows);

    final activeRows = rows.where((r) => r.hasActivity).toList();
    final avgCompletionRate = rows.isEmpty ? 0.0 : rows.map((r) => r.completionRate).reduce((a, b) => a + b) / rows.length;
    final playRatePct = (avgCompletionRate * 100).round();

    final avgAccuracyPct = activeRows.isEmpty
        ? 0.0
        : activeRows.map((r) => r.avgAccuracy).reduce((a, b) => a + b) / activeRows.length;

    final progressRepo = ProgressRepository();
    final enrollments = ClassRepository().byClassId(classId);
    int totalHomeSeconds = 0;
    for (final e in enrollments) {
      final records = progressRepo.byLearnerId(e.learnerId).where((r) => !r.isClassroomMode);
      if (records.isNotEmpty) {
        totalHomeSeconds += records.fold<int>(0, (sum, r) => sum + r.timeOnTaskSeconds.toInt());
      }
    }
    final avgTimeMinutes = enrollments.isEmpty ? 0 : (totalHomeSeconds ~/ 60) ~/ enrollments.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
      children: [
        if (weakest != null) ...[
          _StaggerFadeIn(
            delay: Duration.zero,
            child: _MisconceptionBanner(module: weakest),
          ),
          const SizedBox(height: 16),
        ],
        _StaggerFadeIn(
          delay: const Duration(milliseconds: 35),
          child: _ClassStatsRow(
            playRatePct: playRatePct,
            avgTimeMinutes: avgTimeMinutes,
            avgAccuracyPct: avgAccuracyPct.round(),
          ),
        ),
        const SizedBox(height: 16),
        const _StaggerFadeIn(
          delay: Duration(milliseconds: 70),
          child: Text(
            'COLLECTIVE MASTERY TRENDS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: AppColors.textMuted,
            ),
          ),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < rows.length; i++)
          _StaggerFadeIn(
            delay: Duration(milliseconds: 70 + (i + 1) * 20),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _AggregateRow(module: rows[i]),
            ),
          ),
        const SizedBox(height: 6),
        _StaggerFadeIn(
          delay: Duration(milliseconds: 90 + (rows.length + 1) * 20),
          child: _ClassActivityPeaksChart(classId: classId),
        ),
      ],
    );
  }
}

class _MisconceptionBanner extends StatelessWidget {
  const _MisconceptionBanner({required this.module});

  final HomeModeAggregate module;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      color: AppColors.coralTint,
      borderColor: const Color(0x33D85A30),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.coral.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.coral,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CLASS-WIDE MISCONCEPTION',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: AppColors.coral,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      module.moduleName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Collective accuracy at home is currently at ${module.avgAccuracy.round()}%. Students are consistently experiencing sequencing errors.',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Focusing next lesson plan on "${module.moduleName}" misconception'),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.coral,
                    side: const BorderSide(color: Color(0x33D85A30)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  child: const Text('Modify Lesson'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Assigned custom practice homework for "${module.moduleName}" to class'),
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.coral,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  child: const Text('Assign Homework'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Three flat tinted stat blocks — same idiom as the dashboard's
/// `_MasteryCountChip` (tinted bg, accent-colored value) rather than a
/// solid gradient block, so this reads as part of the same teacher hub
/// as `ClassHealthDetailScreen`/`ClassroomManagementScreen` instead of a
/// one-off hero banner.
class _ClassStatsRow extends StatelessWidget {
  const _ClassStatsRow({
    required this.playRatePct,
    required this.avgTimeMinutes,
    required this.avgAccuracyPct,
  });

  final int playRatePct;
  final int avgTimeMinutes;
  final int avgAccuracyPct;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatBlock(
            icon: Icons.play_arrow_rounded,
            label: 'PLAY RATE',
            value: '$playRatePct%',
            color: AppColors.teal,
            bg: AppColors.mint,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatBlock(
            icon: Icons.schedule_rounded,
            label: 'TIME / STUDENT',
            value: '${avgTimeMinutes}m',
            color: const Color(0xFF8A5A12),
            bg: AppColors.goldTint,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatBlock(
            icon: Icons.check_rounded,
            label: 'AVG ACCURACY',
            value: '$avgAccuracyPct%',
            color: AppColors.coral,
            bg: AppColors.coralTint,
          ),
        ),
      ],
    );
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.bg,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassActivityPeaksChart extends StatelessWidget {
  const _ClassActivityPeaksChart({required this.classId});

  final String classId;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CLASS HOME PEAKS',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMuted,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Distribution of active users during the week',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Icon(
                Icons.timeline_rounded,
                color: AppColors.teal,
                size: 16,
              ),
            ],
          ),
          const SizedBox(height: 16),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeOutCubic,
            builder: (context, val, child) {
              return SizedBox(
                height: 80,
                width: double.infinity,
                child: CustomPaint(
                  painter: _LineChartPainter(progress: val),
                  size: Size.infinite,
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Text('Wed', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
              Text('Thu', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
              Text('Fri', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
              Text('Sat', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
              Text('Sun', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final points = [
      Offset(size.width * 0.1, size.height * 0.6),
      Offset(size.width * 0.3, size.height * 0.5),
      Offset(size.width * 0.5, size.height * 0.2),
      Offset(size.width * 0.7, size.height * 0.4),
      Offset(size.width * 0.9, size.height * 0.1),
    ];

    // 1. Solid horizontal gridlines behind the curve.
    final gridPaint = Paint()
      ..color = AppColors.creamBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (var i = 1; i <= 3; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final reveal = progress.clamp(0.0, 1.0);
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * reveal, size.height + 40));

    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      final pPrev = points[i - 1];
      final pCurr = points[i];
      final controlPoint1 = Offset(pPrev.dx + (pCurr.dx - pPrev.dx) / 2, pPrev.dy);
      final controlPoint2 = Offset(pPrev.dx + (pCurr.dx - pPrev.dx) / 2, pCurr.dy);
      path.cubicTo(controlPoint1.dx, controlPoint1.dy, controlPoint2.dx, controlPoint2.dy, pCurr.dx, pCurr.dy);
    }

    final strokePaint = Paint()
      ..color = AppColors.teal
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final fillPath = Path.from(path)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();

    final fillPaint = Paint()
      ..color = AppColors.teal.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, strokePaint);

    final dotPaint = Paint()
      ..color = AppColors.teal
      ..style = PaintingStyle.fill;

    final glowPaint = Paint()
      ..color = AppColors.teal.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;

    final last = points.last;
    canvas.drawCircle(last, 9, glowPaint);
    canvas.drawCircle(last, 5, dotPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) => oldDelegate.progress != progress;
}

class _AggregateRow extends StatelessWidget {
  const _AggregateRow({required this.module});

  final HomeModeAggregate module;

  static String _tierFor(double accuracyPct) {
    if (accuracyPct >= 80) return 'High';
    if (accuracyPct >= 50) return 'Medium';
    return 'Needs help';
  }

  @override
  Widget build(BuildContext context) {
    if (!module.hasActivity) {
      return SoftCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                module.moduleName,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
              ),
            ),
            const Text(
              'No activity yet',
              style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    final tier = _tierFor(module.avgAccuracy);
    final trend = module.trend;
    String? trendLabel;
    Color? trendColor;
    if (trend != null && trend != 0) {
      final sign = trend > 0 ? '+' : '';
      trendLabel = '$sign${trend.toStringAsFixed(1)} pts vs. last week';
      trendColor = trend > 0 ? AppColors.teal : AppColors.coral;
    }

    // Mastery-colored rail — same treatment as `ClassHealthDetailScreen`'s
    // module cards, so the two class-analytics screens read as one family.
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.creamBorder),
          borderRadius: BorderRadius.circular(16),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: masteryBarColor(tier)),
              Expanded(
                child: Container(
                  color: AppColors.surface,
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              module.moduleName,
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                            ),
                          ),
                          MasteryPill(mastery: tier),
                        ],
                      ),
                      const SizedBox(height: 10),
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
                      const SizedBox(height: 6),
                      Text(
                        '${(module.completionRate * 100).round()}% of class played at home · '
                        '${module.avgAccuracy.round()}% avg accuracy · '
                        '${module.avgErrors.toStringAsFixed(1)} errors/session',
                        style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                      ),
                      if (trendLabel != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              trend! > 0
                                  ? Icons.arrow_upward_rounded
                                  : Icons.arrow_downward_rounded,
                              size: 14,
                              color: trendColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              trendLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: trendColor,
                              ),
                            ),
                          ],
                        ),
                      ],
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

class _EmptyBody extends StatelessWidget {
  const _EmptyBody({required this.icon, required this.title, required this.message});

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}

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

class _StaggerFadeIn extends StatefulWidget {
  const _StaggerFadeIn({super.key, required this.delay, required this.child});

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
