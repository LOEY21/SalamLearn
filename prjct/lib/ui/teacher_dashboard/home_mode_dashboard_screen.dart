import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/progress_record.dart';
import '../../data/repositories/class_repository.dart';
import '../../data/repositories/progress_repository.dart';
import '../../logic/teacher/home_mode_providers.dart';
import '../../logic/teacher/teacher_providers.dart';
import '../theme/app_colors.dart';
import '../widgets/child_profile_form.dart' show displayText, scaledExtent;
import '../widgets/hub_kit.dart';
import '../widgets/locked_tag.dart';
import '../widgets/soft_card.dart';
import 'teacher_dashboard_screen.dart'
    show masteryBarColor, MasteryPill, avatarColor;

/// FR-6.2B Home Mode Monitoring Dashboard — a dedicated screen kept
/// deliberately separate from the Classroom tab's Class Health Index
/// (Hot-Seat/Cast telemetry only). Everything on this screen reads
/// `home_mode_providers.dart`, which filters `isClassroomMode == false`
/// end to end, so solo Student Hub/Adventure Map play and live classroom
/// data can never mix in either direction.
///
/// Built on the hub kit's sub-page frame; an Individual/Aggregate switch
/// sits in the header. Student detail and the aggregate view split into
/// two columns from tablet-landscape widths up.
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
  String _query = '';
  bool _byStage = false;

  // Back from one student's detail returns to the student list first.
  void _goBack() {
    if (_view == _HomeModeView.individual && _selectedLearnerId != null) {
      setState(() => _selectedLearnerId = null);
      return;
    }
    context.go('/teacher?tab=1');
  }

  @override
  Widget build(BuildContext context) {
    final section = ref.watch(teacherClassControllerProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _goBack();
      },
      child: HubSubpage(
        header: HubSubpageHeader(
          title: 'Home Mode Insights',
          subtitle:
              'Solo practice at home — kept separate from classroom play.',
          onBack: _goBack,
          bottom: HubSegmented(
            labels: const ['Individual', 'Aggregate'],
            active: _view.index,
            onChanged: (i) => setState(() => _view = _HomeModeView.values[i]),
          ),
        ),
        body: section == null
            ? const HubListBody(
                children: [
                  HubEmptyState(
                    icon: Icons.home_outlined,
                    title: 'No class selected',
                    message:
                        'Create or select a class from the Classroom tab first.',
                  ),
                ],
              )
            : HubPanelRise(
                key: ValueKey('${_view}_$_selectedLearnerId'),
                child: _view == _HomeModeView.individual
                    ? _IndividualView(
                        classId: section.id,
                        selectedLearnerId: _selectedLearnerId,
                        onSelect: (id) =>
                            setState(() => _selectedLearnerId = id),
                        query: _query,
                        onQueryChanged: (q) => setState(() => _query = q),
                        byStage: _byStage,
                        onByStageChanged: (v) => setState(() => _byStage = v),
                      )
                    : _AggregateView(
                        classId: section.id,
                        byStage: _byStage,
                        onByStageChanged: (v) => setState(() => _byStage = v),
                      ),
              ),
      ),
    );
  }
}

// ------------------------------------------------------------ individual

/// Individual Progress Tracking (FR-6.2B): a searchable list of every
/// student in the class; picking one shows their longitudinal Home Mode
/// mastery per destination plus a completion history — all sourced from
/// `homeModeHistoryProvider`/`homeModeModuleSummaryProvider`, both
/// Classroom-Mode-record-free.
class _IndividualView extends ConsumerWidget {
  const _IndividualView({
    required this.classId,
    required this.selectedLearnerId,
    required this.onSelect,
    required this.query,
    required this.onQueryChanged,
    required this.byStage,
    required this.onByStageChanged,
  });

  final String classId;
  final String? selectedLearnerId;
  final ValueChanged<String?> onSelect;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final bool byStage;
  final ValueChanged<bool> onByStageChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roster = ref.watch(classRosterProvider(classId));

    if (roster.isEmpty) {
      return const HubListBody(
        children: [
          HubEmptyState(
            icon: Icons.groups_outlined,
            title: 'No students yet',
            message:
                'Enroll students into this class to see their Home Mode history.',
          ),
        ],
      );
    }

    final selected = roster
        .where((s) => s['learnerId'] == selectedLearnerId)
        .firstOrNull;
    if (selected == null) {
      final needle = query.trim().toLowerCase();
      final students =
          [
            for (final s in roster)
              if ((s['name'] as String).toLowerCase().contains(needle)) s,
          ]..sort(
            (a, b) => (a['name'] as String).toLowerCase().compareTo(
              (b['name'] as String).toLowerCase(),
            ),
          );

      return HubListBody(
        children: [
          TextFormField(
            initialValue: query,
            onChanged: onQueryChanged,
            textInputAction: TextInputAction.search,
            style: const TextStyle(fontSize: 15.5),
            decoration: InputDecoration(
              hintText: 'Search student'.tr,
              prefixIcon: const Icon(Icons.search_rounded, size: 22),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
                borderSide: const BorderSide(color: AppColors.creamBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
                borderSide: const BorderSide(
                  color: AppColors.creamBorder,
                  width: 1.4,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(999),
                borderSide: const BorderSide(color: AppColors.teal, width: 1.8),
              ),
            ),
          ),
          const SizedBox(height: 6),
          HubSectionLabel(
            needle.isEmpty
                ? 'All students · ${roster.length}'
                : '${students.length} of ${roster.length} students',
          ),
          if (students.isEmpty)
            SoftCard(
              radius: 18,
              padding: const EdgeInsets.all(18),
              child: Text(
                'No student matches "${query.trim()}".',
                style: const TextStyle(fontSize: 14, color: AppColors.inkSoft),
              ),
            )
          else
            for (final s in students)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _StudentListTile(
                  learnerId: s['learnerId'] as String,
                  name: s['name'] as String,
                  onTap: () => onSelect(s['learnerId'] as String),
                ),
              ),
        ],
      );
    }

    final activeId = selected['learnerId'] as String;
    final activeName = selected['name'] as String;
    final groups = ref.watch(
      homeModeLearnerGroupsProvider((activeId, byStage)),
    );

    return HubTabBody(
      left: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => onSelect(null),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('All students'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.teal,
              minimumSize: const Size(0, 44),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        HubStaggerFadeIn(
          delay: const Duration(milliseconds: 35),
          child: _StudentProfileCard(
            learnerId: activeId,
            studentName: activeName,
          ),
        ),
        const SizedBox(height: 14),
        HubStaggerFadeIn(
          delay: const Duration(milliseconds: 70),
          child: _StudentWeeklyChart(
            learnerId: activeId,
            history: ref.watch(homeModeHistoryProvider(activeId)),
          ),
        ),
      ],
      right: [
        HubStaggerFadeIn(
          delay: const Duration(milliseconds: 105),
          child: _GroupHeading(
            title: '$activeName · Progress',
            byStage: byStage,
            onChanged: onByStageChanged,
          ),
        ),
        for (final group in groups)
          HubStaggerFadeIn(
            key: ValueKey(group.name),
            delay: const Duration(milliseconds: 105),
            child: _GameSessionsCard(group: group),
          ),
        const HubStaggerFadeIn(
          delay: Duration(milliseconds: 140),
          child: HubSectionLabel('Completion history'),
        ),
        HubStaggerFadeIn(
          delay: const Duration(milliseconds: 140),
          child: _HistoryCard(learnerId: activeId),
        ),
      ],
    );
  }
}

String _masteryForAccuracy(double accuracy) => accuracy >= 80
    ? 'High'
    : accuracy >= 50
    ? 'Medium'
    : 'Needs help';

/// One student in the list: home accuracy, playtime, sessions and mastery
/// at a glance; tapping opens their full Home Mode detail.
class _StudentListTile extends ConsumerWidget {
  const _StudentListTile({
    required this.learnerId,
    required this.name,
    required this.onTap,
  });

  final String learnerId;
  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(homeModeHistoryProvider(learnerId));
    final avgAccuracy = history.isEmpty
        ? 0.0
        : history.map((r) => r.strokeAccuracyPct).reduce((a, b) => a + b) /
              history.length;
    final minutes =
        history.fold<int>(0, (sum, r) => sum + r.timeOnTaskSeconds) ~/ 60;
    final mastery = _masteryForAccuracy(avgAccuracy);

    return SoftCard(
      radius: 18,
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = scaledExtent(context, constraints.maxWidth) < 330;
          final pill = history.isEmpty ? null : MasteryPill(mastery: mastery);
          return Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: history.isEmpty
                      ? AppColors.creamDark
                      : avatarColor(mastery),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  name.isEmpty ? '?' : name[0].toUpperCase(),
                  style: displayText(18, weight: 800, color: Colors.white),
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
                        fontWeight: FontWeight.w700,
                        fontSize: 15.5,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      history.isEmpty
                          ? 'No home activity yet'
                          : '${avgAccuracy.round()}% accuracy · ${minutes}m · '
                                '${history.length} session${history.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.inkSoft,
                      ),
                    ),
                    if (compact && pill != null) ...[
                      const SizedBox(height: 6),
                      pill,
                    ],
                  ],
                ),
              ),
              if (!compact && pill != null) ...[const SizedBox(width: 8), pill],
              const Icon(
                Icons.chevron_right_rounded,
                size: 24,
                color: AppColors.inkSoft,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StudentProfileCard extends ConsumerWidget {
  const _StudentProfileCard({
    required this.learnerId,
    required this.studentName,
  });

  final String learnerId;
  final String studentName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(homeModeHistoryProvider(learnerId));
    final streak = ProgressRepository().currentStreak(learnerId);

    final totalSeconds = history.fold<int>(
      0,
      (sum, r) => sum + r.timeOnTaskSeconds.toInt(),
    );
    final playtimeMinutes = totalSeconds ~/ 60;

    final avgAccuracy = history.isEmpty
        ? 0.0
        : history.map((r) => r.strokeAccuracyPct).reduce((a, b) => a + b) /
              history.length;
    final overallMastery = _masteryForAccuracy(avgAccuracy);

    return SoftCard(
      radius: 20,
      padding: const EdgeInsets.all(18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Narrow cards / large text: the ring moves down beside the stats
          // so a long name keeps the width of the card.
          final compact = scaledExtent(context, constraints.maxWidth) < 360;
          final ring = _AccuracyRing(accuracyPct: avgAccuracy);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: avatarColor(overallMastery),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      studentName.isEmpty ? '?' : studentName[0].toUpperCase(),
                      style: displayText(22, weight: 800, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        HubFitText(studentName, style: displayText(20)),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Icon(
                              Icons.local_fire_department_rounded,
                              color: AppColors.gold,
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '$streak-day streak',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.inkSoft,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (!compact) ...[const SizedBox(width: 12), ring],
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: AppColors.creamBorder),
              const SizedBox(height: 12),
              Wrap(
                spacing: 24,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (compact) ring,
                  _HeroStat(
                    value: '${playtimeMinutes}m',
                    label: 'Home playtime',
                  ),
                  _HeroStat(
                    value: '${avgAccuracy.round()}% match',
                    label: 'Avg accuracy',
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Accuracy donut — puts the single most important number (average stroke
/// accuracy) front and center.
class _AccuracyRing extends StatelessWidget {
  const _AccuracyRing({required this.accuracyPct});

  final double accuracyPct;

  @override
  Widget build(BuildContext context) {
    const size = 64.0;
    final targetValue = (accuracyPct / 100).clamp(0.0, 1.0);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: targetValue),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutQuart,
      builder: (context, val, child) {
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  value: 1,
                  strokeWidth: 7,
                  color: AppColors.creamDark,
                ),
              ),
              SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  value: val,
                  strokeWidth: 7,
                  strokeCap: StrokeCap.round,
                  backgroundColor: Colors.transparent,
                  color: AppColors.teal,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${(val * 100).round()}%',
                    style: displayText(
                      16,
                      weight: 800,
                      color: AppColors.tealDark,
                    ),
                  ),
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
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: displayText(18, weight: 800)),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.inkSoft,
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
    final days = List.generate(
      5,
      (i) => DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: 4 - i)),
    );

    final dailySeconds = days.map((day) {
      final records = history.where((r) {
        final rDate = DateTime(
          r.completedAt.year,
          r.completedAt.month,
          r.completedAt.day,
        );
        return rDate.isAtSameMomentAs(day);
      });
      return records.isEmpty
          ? 0
          : records.map((r) => r.timeOnTaskSeconds).reduce((a, b) => a + b);
    }).toList();

    final maxVal = dailySeconds.map((s) => s).reduce((a, b) => a > b ? a : b);
    final maxScale = maxVal == 0 ? 1 : maxVal;

    final weekdayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return SoftCard(
      radius: 20,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Weekly progress', style: displayText(18)),
          const SizedBox(height: 2),
          const Text(
            'Minutes practiced per day at home',
            style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 110),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(5, (i) {
                final day = days[i];
                final seconds = dailySeconds[i];
                final minutes = seconds / 60;
                final ratio = seconds / maxScale;
                final height = (ratio * 64).clamp(6.0, 64.0);
                final isToday = i == 4;

                final targetHeight = seconds == 0 ? 6.0 : height;
                // Equal slot per day so full names ("Miyerkules") can't push
                // the row past the card; the label shrinks to its slot.
                return Expanded(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                      begin: seconds == 0 ? 6.0 : 0.0,
                      end: targetHeight,
                    ),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutQuart,
                    builder: (context, animatedHeight, child) {
                      final animatedMinutes = seconds == 0
                          ? 0
                          : (minutes * (animatedHeight / targetHeight)).round();
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              seconds == 0 ? '' : '${animatedMinutes}m',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.tealDark,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 26,
                            height: animatedHeight,
                            decoration: seconds == 0
                                ? BoxDecoration(
                                    border: Border.all(
                                      color: AppColors.creamDark,
                                      width: 1.5,
                                    ),
                                    borderRadius: BorderRadius.circular(7),
                                  )
                                : BoxDecoration(
                                    color: AppColors.teal,
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                          ),
                          const SizedBox(height: 6),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              weekdayNames[day.weekday % 7],
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: isToday
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: isToday
                                    ? AppColors.teal
                                    : AppColors.inkSoft,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                );
              }),
            ),
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
        radius: 18,
        padding: EdgeInsets.all(18),
        child: Text(
          'Nothing completed at home yet.',
          style: TextStyle(fontSize: 14, color: AppColors.inkSoft),
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
      radius: 20,
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
                    left: 16,
                    top: i == 0 ? 8 : 14,
                    bottom: 4,
                  ),
                  child: Text(
                    bucket,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                );
              },
            ),
            _HistoryRow(record: recent[i]),
            if (i != recent.length - 1 &&
                bucketFor(recent[i + 1].completedAt) ==
                    bucketFor(recent[i].completedAt))
              const Divider(
                height: 1,
                indent: 16,
                color: AppColors.creamBorder,
              ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      // Score and date drop under the name when they don't fit beside it.
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 6,
        children: [
          Text(
            moduleName,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ScoreBadge(pct: record.strokeAccuracyPct, emptyLabel: ''),
              const SizedBox(width: 10),
              Text(
                '${date.month}/${date.day}',
                style: const TextStyle(fontSize: 13, color: AppColors.inkSoft),
              ),
            ],
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
  const _AggregateView({
    required this.classId,
    required this.byStage,
    required this.onByStageChanged,
  });

  final String classId;
  final bool byStage;
  final ValueChanged<bool> onByStageChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(homeModeAggregateProvider(classId));
    final groups = ref.watch(homeModeClassGroupsProvider((classId, byStage)));
    final weakest = weakestHomeModeAggregate(rows);

    final activeRows = rows.where((r) => r.hasActivity).toList();
    final avgCompletionRate = rows.isEmpty
        ? 0.0
        : rows.map((r) => r.completionRate).reduce((a, b) => a + b) /
              rows.length;
    final playRatePct = (avgCompletionRate * 100).round();

    final avgAccuracyPct = activeRows.isEmpty
        ? 0.0
        : activeRows.map((r) => r.avgAccuracy).reduce((a, b) => a + b) /
              activeRows.length;

    final progressRepo = ProgressRepository();
    final enrollments = ClassRepository().byClassId(classId);
    int totalHomeSeconds = 0;
    for (final e in enrollments) {
      final records = progressRepo
          .byLearnerId(e.learnerId)
          .where((r) => !r.isClassroomMode);
      if (records.isNotEmpty) {
        totalHomeSeconds += records.fold<int>(
          0,
          (sum, r) => sum + r.timeOnTaskSeconds.toInt(),
        );
      }
    }
    final avgTimeMinutes = enrollments.isEmpty
        ? 0
        : (totalHomeSeconds ~/ 60) ~/ enrollments.length;

    return HubTabBody(
      left: [
        if (weakest != null) ...[
          HubStaggerFadeIn(
            delay: Duration.zero,
            child: _MisconceptionBanner(module: weakest),
          ),
          const SizedBox(height: 16),
        ],
        HubStaggerFadeIn(
          delay: const Duration(milliseconds: 35),
          child: _ClassStatsRow(
            playRatePct: playRatePct,
            avgTimeMinutes: avgTimeMinutes,
            avgAccuracyPct: avgAccuracyPct.round(),
          ),
        ),
        const SizedBox(height: 16),
        HubStaggerFadeIn(
          delay: const Duration(milliseconds: 50),
          child: _ClassActivityPeaksChart(classId: classId),
        ),
        const SizedBox(height: 8),
      ],
      right: [
        HubStaggerFadeIn(
          delay: const Duration(milliseconds: 70),
          child: _GroupHeading(
            title: 'Class progress',
            byStage: byStage,
            onChanged: onByStageChanged,
          ),
        ),
        for (final (i, group) in groups.indexed)
          HubStaggerFadeIn(
            key: ValueKey(group.name),
            delay: Duration(milliseconds: 70 + (i + 1) * 20),
            child: _GameSessionsCard(
              group: group,
              rosterSize: enrollments.length,
            ),
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
    final modify = OutlinedButton(
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Focusing next lesson plan on "${module.moduleName}" misconception',
            ),
          ),
        );
      },
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.coral,
        backgroundColor: AppColors.surface,
        minimumSize: const Size(64, 46),
        side: const BorderSide(color: AppColors.coral, width: 1.4),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
      ),
      child: const Text('Modify Lesson', textAlign: TextAlign.center),
    );
    final assign = FilledButton(
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Assigned custom practice homework for "${module.moduleName}" to class',
            ),
          ),
        );
      },
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.coral,
        foregroundColor: Colors.white,
        minimumSize: const Size(64, 46),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
      ),
      child: const Text('Assign Homework', textAlign: TextAlign.center),
    );

    return SoftCard(
      radius: 20,
      color: AppColors.coralTint,
      borderColor: AppColors.coral.withValues(alpha: 0.3),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.coral,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Class-wide misconception',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColors.coral,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(module.moduleName, style: displayText(18)),
                    const SizedBox(height: 4),
                    Text(
                      'Collective accuracy at home is currently at ${module.avgAccuracy.round()}%. Students are consistently experiencing sequencing errors.',
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              if (scaledExtent(context, constraints.maxWidth) < 400) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [modify, const SizedBox(height: 8), assign],
                );
              }
              return Row(
                children: [
                  Expanded(child: modify),
                  const SizedBox(width: 8),
                  Expanded(child: assign),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Class-wide stats: three across when there's room, one per row on narrow
/// screens / large text.
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
    final blocks = [
      _StatBlock(
        icon: Icons.play_arrow_rounded,
        label: 'Play rate',
        value: '$playRatePct%',
        color: AppColors.teal,
      ),
      _StatBlock(
        icon: Icons.schedule_rounded,
        label: 'Time / student',
        value: '${avgTimeMinutes}m',
        color: AppColors.gold,
      ),
      _StatBlock(
        icon: Icons.check_rounded,
        label: 'Avg accuracy',
        value: '$avgAccuracyPct%',
        color: AppColors.coral,
      ),
    ];
    return SoftCard(
      radius: 20,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (scaledExtent(context, constraints.maxWidth) < 360) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, b) in blocks.indexed) ...[
                  if (i > 0)
                    const Divider(height: 20, color: AppColors.creamBorder),
                  b,
                ],
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final b in blocks) Expanded(child: b)],
          );
        },
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: displayText(22, weight: 800, height: 1.1)),
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
  }
}

class _ClassActivityPeaksChart extends StatelessWidget {
  const _ClassActivityPeaksChart({required this.classId});

  final String classId;

  @override
  Widget build(BuildContext context) {
    const days = ['Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return SoftCard(
      radius: 20,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Class home peaks', style: displayText(18)),
          const SizedBox(height: 2),
          const Text(
            'Distribution of active users during the week',
            style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 16),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.easeOutQuart,
            builder: (context, val, child) {
              return SizedBox(
                height: 90,
                width: double.infinity,
                child: CustomPaint(
                  painter: _LineChartPainter(progress: val),
                  size: Size.infinite,
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final d in days)
                Expanded(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        d,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ),
                  ),
                ),
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
      final controlPoint1 = Offset(
        pPrev.dx + (pCurr.dx - pPrev.dx) / 2,
        pPrev.dy,
      );
      final controlPoint2 = Offset(
        pPrev.dx + (pCurr.dx - pPrev.dx) / 2,
        pCurr.dy,
      );
      path.cubicTo(
        controlPoint1.dx,
        controlPoint1.dy,
        controlPoint2.dx,
        controlPoint2.dy,
        pCurr.dx,
        pCurr.dy,
      );
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
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ------------------------------------------------------------------ games

/// One game or stage; tap to show its sessions. Without [rosterSize] it is
/// one student's view (their score per session); with it, the class's (how
/// many students played each session and their average).
class _GameSessionsCard extends StatefulWidget {
  const _GameSessionsCard({required this.group, this.rosterSize});

  final HomeProgressGroup group;
  final int? rosterSize;

  @override
  State<_GameSessionsCard> createState() => _GameSessionsCardState();
}

class _GameSessionsCardState extends State<_GameSessionsCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final game = widget.group;
    final roster = widget.rosterSize;
    final total = game.sessions.length;
    final progress = roster == null
        ? game.sessionsPlayed / total
        : roster == 0
        ? 0.0
        : game.studentsPlayed / roster;
    final status = game.avgAccuracy == null && game.allLocked
        ? const LockedTag()
        : _ScoreBadge(pct: game.avgAccuracy, emptyLabel: 'Not started');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.creamBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => setState(() => _open = !_open),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact =
                        scaledExtent(context, constraints.maxWidth) < 330;
                    return Row(
                      children: [
                        Opacity(
                          opacity: game.allLocked ? 0.45 : 1,
                          child: Container(
                            width: 42,
                            height: 42,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: AppColors.neutralTint,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              game.icon,
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                game.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: AppColors.ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                roster == null
                                    ? '${game.sessionsPlayed} of $total session${total == 1 ? '' : 's'} played'
                                          '${game.lockedCount > 0 && !game.allLocked ? ' · ${game.lockedCount} locked' : ''}'
                                    : '${game.studentsPlayed} of $roster student${roster == 1 ? '' : 's'} played · $total session${total == 1 ? '' : 's'}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.inkSoft,
                                ),
                              ),
                              const SizedBox(height: 7),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 6,
                                  backgroundColor: AppColors.creamDark,
                                  color: AppColors.teal,
                                ),
                              ),
                              if (compact) ...[
                                const SizedBox(height: 8),
                                status,
                              ],
                            ],
                          ),
                        ),
                        if (!compact) ...[const SizedBox(width: 10), status],
                        AnimatedRotation(
                          turns: _open ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 24,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            if (_open)
              for (final session in game.sessions)
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 10, 14, 10),
                  decoration: BoxDecoration(
                    color: session.studentsPlayed > 0
                        ? AppColors.mint.withValues(alpha: 0.35)
                        : null,
                    border: const Border(
                      top: BorderSide(color: AppColors.creamBorder),
                    ),
                  ),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 6,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            session.label,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink,
                            ),
                          ),
                          Text(
                            roster == null
                                ? session.detail
                                : '${session.detail} · ${session.studentsPlayed}/$roster played',
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ],
                      ),
                      if (session.avgAccuracy == null && session.locked)
                        const LockedTag()
                      else
                        _ScoreBadge(
                          pct: session.avgAccuracy,
                          emptyLabel: roster == null
                              ? 'Not played'
                              : 'No plays yet',
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

/// Section heading with the "12 Games | 7 Stages" switch; the switch drops
/// under the heading when both don't fit on one line.
class _GroupHeading extends StatelessWidget {
  const _GroupHeading({
    required this.title,
    required this.byStage,
    required this.onChanged,
  });

  final String title;
  final bool byStage;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget segment(String label, bool value) {
      final active = byStage == value;
      return Semantics(
        button: true,
        selected: active,
        child: GestureDetector(
          onTap: () => onChanged(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: active ? AppColors.teal : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: active ? Colors.white : AppColors.tealDark,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 8,
        children: [
          Text(title, style: displayText(17)),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.creamBorder, width: 1.4),
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
    );
  }
}

/// "86%" tinted by mastery tier, or a muted label when there's no score.
class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.pct, required this.emptyLabel});

  final double? pct;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final pct = this.pct;
    if (pct == null) {
      return Text(
        emptyLabel,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: AppColors.inkSoft,
        ),
      );
    }
    final color = masteryBarColor(_masteryForAccuracy(pct));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '${pct.round()}%',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: color == AppColors.gold ? AppColors.ink : color,
        ),
      ),
    );
  }
}
