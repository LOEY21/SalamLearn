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
    );
    await _progress.put(record.id, record);
    await _bumpStreak(learnerId);
    return record;
  }

  List<ProgressRecord> byLearnerId(String learnerId) =>
      _progress.values.where((p) => p.learnerId == learnerId).toList()
        ..sort((a, b) => b.completedAt.compareTo(a.completedAt));

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

  /// FR-5.1 weekly activity chart — one normalized (0.0–1.0) value per of
  /// the last 7 calendar days, keyed by single-letter weekday label.
  Map<String, double> weeklyChartData(String learnerId, {int windowDays = 7}) {
    final records = _sinceDays(learnerId, windowDays);
    final secondsByDay = <DateTime, int>{};
    for (final r in records) {
      final day = DateTime(r.completedAt.year, r.completedAt.month, r.completedAt.day);
      secondsByDay[day] = (secondsByDay[day] ?? 0) + r.timeOnTaskSeconds;
    }
    final maxSeconds = secondsByDay.values.isEmpty
        ? 1
        : secondsByDay.values.reduce((a, b) => a > b ? a : b);

    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final today = DateTime.now();
    final result = <String, double>{};
    for (var i = windowDays - 1; i >= 0; i--) {
      final day = DateTime(today.year, today.month, today.day).subtract(Duration(days: i));
      final label = labels[day.weekday - 1];
      final value = (secondsByDay[day] ?? 0) / maxSeconds;
      result[label] = value.clamp(0.0, 1.0);
    }
    return result;
  }

  /// FR-5.2 — curriculum-aligned practice prompts, generated from whichever
  /// module has accumulated the most sequencing errors recently. Falls back
  /// to a generic prompt when there isn't enough history yet.
  List<String> latestSuggestions(String learnerId, {int maxSuggestions = 3}) {
    final records = _sinceDays(learnerId, 14);
    if (records.isEmpty) {
      return const ['Complete a few lessons to unlock personalized practice suggestions.'];
    }
    final errorsByModule = <String, int>{};
    for (final r in records) {
      errorsByModule[r.moduleId] = (errorsByModule[r.moduleId] ?? 0) + r.sequencingErrors;
    }
    final ranked = errorsByModule.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (ranked.isEmpty) {
      return const ['Great work — no recent weak points detected. Keep up the streak!'];
    }
    return ranked
        .take(maxSuggestions)
        .map((e) => 'Practice "${e.key}" together — ${e.value} recent errors logged.')
        .toList();
  }

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
