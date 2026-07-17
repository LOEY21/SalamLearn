import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../local/hive_boxes.dart';
import '../models/badge_award.dart';
import '../models/progress_record.dart';
import '../models/streak_state.dart';
import '../remote/firestore_mirror.dart';

/// FR-5.1 rollup: accuracy/time-on-task/error totals over a window.
class ProgressSummary {
  const ProgressSummary({
    required this.accuracyPct,
    required this.timeOnTaskMinutes,
    required this.errorCount,
  });

  final double accuracyPct;
  final int timeOnTaskMinutes;
  final int errorCount;
}

/// One day's normalized activity value plus its axis label, as returned by
/// [ProgressRepository.weeklyChartData].
class ChartPoint {
  const ChartPoint(this.label, this.value);

  final String label;
  final double value;
}

/// Per-`moduleId` (adventure/destination) rollup — backs the Parent
/// Dashboard's per-adventure breakdown, distinct from [ProgressSummary]'s
/// whole-learner aggregate.
class ModuleSummary {
  const ModuleSummary({
    required this.moduleId,
    required this.accuracyPct,
    required this.errorCount,
    required this.sessionCount,
  });

  final String moduleId;
  final double accuracyPct;
  final int errorCount;
  final int sessionCount;
}

/// Hive-backed CRUD for [ProgressRecord] (the SRS's `ProgressBox`) plus the
/// [StreakState]/[BadgeAward] side-state that gets updated alongside it on
/// every completed activity (FR-3.2, FR-3.3, FR-5.1, FR-5.2, FR-6.2).
class ProgressRepository {
  Box<ProgressRecord> get _progress => Hive.box<ProgressRecord>(HiveBoxes.progress);
  Box<StreakState> get _streaks => Hive.box<StreakState>(HiveBoxes.streaks);
  Box<BadgeAward> get _badges => Hive.box<BadgeAward>(HiveBoxes.badges);

  Future<ProgressRecord> writeProgress({
    required String learnerId,
    required String moduleId,
    required double strokeAccuracyPct,
    required int sequencingErrors,
    required int timeOnTaskSeconds,
    bool assignedByTeacher = false,
    String? lessonId,
    bool isClassroomMode = false,
  }) async {
    final record = ProgressRecord(
      id: const Uuid().v4(),
      learnerId: learnerId,
      moduleId: moduleId,
      strokeAccuracyPct: strokeAccuracyPct,
      sequencingErrors: sequencingErrors,
      timeOnTaskSeconds: timeOnTaskSeconds,
      completedAt: DateTime.now(),
      assignedByTeacher: assignedByTeacher,
      lessonId: lessonId,
      isClassroomMode: isClassroomMode,
    );
    await _progress.put(record.id, record);
    await _bumpStreak(learnerId);
    return record;
  }

  List<ProgressRecord> byLearnerId(String learnerId) =>
      _progress.values.where((p) => p.learnerId == learnerId).toList()
        ..sort((a, b) => b.completedAt.compareTo(a.completedAt));

  /// Every `lessonId` this learner has finished, across all destinations —
  /// feeds the Adventure Map's real per-lesson/per-level unlock gating in
  /// `destination_levels_sheet.dart` (replaces the previous hardcoded empty
  /// placeholder set).
  Set<String> completedLessonIds(String learnerId) => _progress.values
      .where((p) => p.learnerId == learnerId && p.lessonId != null)
      .map((p) => p.lessonId!)
      .toSet();

  List<ProgressRecord> _sinceDays(String learnerId, int days) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return byLearnerId(learnerId).where((p) => p.completedAt.isAfter(cutoff)).toList();
  }

  /// FR-5.1 — accuracy %, time-on-task, and error totals over the last
  /// [days] (defaults to the last 7, matching the dashboard's "this week").
  ProgressSummary summary(String learnerId, {int days = 7}) {
    final now = DateTime.now();
    return summaryForRange(learnerId, now.subtract(Duration(days: days)), now);
  }

  /// Same rollup as [summary], but over an arbitrary `[from, to)` window —
  /// used to compare "this week" against "last week" for trend arrows.
  ProgressSummary summaryForRange(String learnerId, DateTime from, DateTime to) {
    final records = byLearnerId(learnerId)
        .where((p) => p.completedAt.isAfter(from) && p.completedAt.isBefore(to))
        .toList();
    if (records.isEmpty) {
      return const ProgressSummary(accuracyPct: 0, timeOnTaskMinutes: 0, errorCount: 0);
    }
    final avgAccuracy =
        records.map((r) => r.strokeAccuracyPct).reduce((a, b) => a + b) / records.length;
    final totalSeconds = records.map((r) => r.timeOnTaskSeconds).reduce((a, b) => a + b);
    final totalErrors = records.map((r) => r.sequencingErrors).reduce((a, b) => a + b);
    return ProgressSummary(
      accuracyPct: avgAccuracy,
      timeOnTaskMinutes: totalSeconds ~/ 60,
      errorCount: totalErrors,
    );
  }

  /// FR-5.1 activity chart — one normalized (0.0–1.0) value per calendar day,
  /// oldest first. For a 7-day window this is always the current Sun–Sat
  /// week (not a rolling "last 7 days"), so the chart consistently starts
  /// on Sunday. Longer windows (30-day/Term) stay a rolling last-[windowDays]
  /// window ending today. Returns an ordered list (not a
  /// `Map<String, double>`) because a weekday-name key collides once
  /// [windowDays] exceeds 7 — e.g. two different Mondays would overwrite
  /// each other. Label is a short weekday ("Mon") for a 7-day window, else
  /// "d/M" so 30-day/Term charts stay unambiguous.
  List<ChartPoint> weeklyChartData(String learnerId, {int windowDays = 7}) {
    final records = _sinceDays(learnerId, windowDays);
    final secondsByDay = <DateTime, int>{};
    for (final r in records) {
      final day = DateTime(r.completedAt.year, r.completedAt.month, r.completedAt.day);
      secondsByDay[day] = (secondsByDay[day] ?? 0) + r.timeOnTaskSeconds;
    }
    final maxSeconds = secondsByDay.values.isEmpty
        ? 1
        : secondsByDay.values.reduce((a, b) => a > b ? a : b);

    const weekdayLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    // DateTime.weekday: Mon=1..Sun=7 — days since the most recent Sunday.
    final daysSinceSunday = todayDate.weekday % 7;
    final windowStart = windowDays <= 7
        ? todayDate.subtract(Duration(days: daysSinceSunday))
        : todayDate.subtract(Duration(days: windowDays - 1));

    final result = <ChartPoint>[];
    for (var i = 0; i < windowDays; i++) {
      final day = windowStart.add(Duration(days: i));
      final label = windowDays <= 7 ? weekdayLabels[day.weekday % 7] : '${day.day}/${day.month}';
      final value = (secondsByDay[day] ?? 0) / maxSeconds;
      result.add(ChartPoint(label, value.clamp(0.0, 1.0)));
    }
    return result;
  }

  /// FR-5.1 per-adventure breakdown — one [ModuleSummary] per `moduleId`
  /// (destination id) the learner has recorded activity in over the last
  /// [days], ranked weakest-accuracy-first by the caller.
  List<ModuleSummary> summaryByModule(String learnerId, {int days = 7}) {
    final byModule = <String, List<ProgressRecord>>{};
    for (final r in _sinceDays(learnerId, days)) {
      byModule.putIfAbsent(r.moduleId, () => []).add(r);
    }
    return byModule.entries.map((entry) {
      final records = entry.value;
      final avgAccuracy =
          records.map((r) => r.strokeAccuracyPct).reduce((a, b) => a + b) / records.length;
      final totalErrors = records.map((r) => r.sequencingErrors).reduce((a, b) => a + b);
      return ModuleSummary(
        moduleId: entry.key,
        accuracyPct: avgAccuracy,
        errorCount: totalErrors,
        sessionCount: records.length,
      );
    }).toList();
  }

  /// FR-5.2 — curriculum-aligned practice prompts, generated from whichever
  /// module has accumulated the most sequencing errors recently. Falls back
  /// to a generic prompt when there isn't enough history yet.
Future<void> _bumpStreak(String learnerId) async {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final existing = _streaks.get(learnerId);
    if (existing == null) {
      await _streaks.put(learnerId, StreakState(
        learnerId: learnerId,
        currentStreak: 1,
        lastPlayedDate: todayDate,
      ));
      return;
    }
    final lastDate = DateTime(
      existing.lastPlayedDate.year,
      existing.lastPlayedDate.month,
      existing.lastPlayedDate.day,
    );
    if (lastDate == todayDate) return; // already counted today
    final isConsecutive = todayDate.difference(lastDate).inDays == 1;
    await _streaks.put(learnerId, StreakState(
      learnerId: learnerId,
      currentStreak: isConsecutive ? existing.currentStreak + 1 : 1,
      lastPlayedDate: todayDate,
    ));
  }

  int currentStreak(String learnerId) => _streaks.get(learnerId)?.currentStreak ?? 0;

  Future<void> awardBadge(String learnerId, String badgeId) async {
    final key = '$learnerId:$badgeId';
    if (_badges.containsKey(key)) return;
    await _badges.put(key, BadgeAward(
      learnerId: learnerId,
      badgeId: badgeId,
      earnedAt: DateTime.now(),
    ));
  }

  List<BadgeAward> badgesFor(String learnerId) =>
      _badges.values.where((b) => b.learnerId == learnerId).toList();

  /// Pushes every locally-stored progress record to Firestore (FR-7.2
  /// sync, matching the SRS's "SyncManager reads the ProgressBox and
  /// pushes the telemetry data to Firebase" data-flow step).
  Future<void> pushAll(FirestoreMirror mirror) async {
    for (final record in _progress.values) {
      await mirror.pushProgress(record);
    }
  }
}
