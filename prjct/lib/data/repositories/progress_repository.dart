import 'package:flutter/foundation.dart' show debugPrint;
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../local/hive_boxes.dart';
import '../models/badge_award.dart';
import '../models/progress_record.dart';
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
/// [BadgeAward] side-state that gets updated alongside it on
/// every completed activity (FR-3.2, FR-3.3, FR-5.1, FR-5.2, FR-6.2).
class ProgressRepository {
  Box<ProgressRecord> get _progress =>
      Hive.box<ProgressRecord>(HiveBoxes.progress);
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
    // Hive applies the put in memory at call time, so a caller reading
    // right after this (the level sheet reopening as the lesson closes)
    // already sees the lesson as completed. The streak is derived from
    // these records (see [_streak]), so it follows them to other devices.
    await _progress.put(record.id, record);
    // Push now instead of waiting for the next SyncManager run, so a
    // parent/teacher on another device sees it live. Not awaited — an
    // offline Firestore write only completes once the server acks it.
    Future.sync(
      () => FirestoreMirror().pushProgress(record),
    ).catchError((Object e) => debugPrint('writeProgress: push failed: $e'));
    return record;
  }

  /// Adds remote records this device doesn't have yet. Records never
  /// change after being written, so an existing id is always up to date.
  Future<void> mergeRemote(Iterable<ProgressRecord> records) async {
    for (final record in records) {
      if (!_progress.containsKey(record.id)) {
        await _progress.put(record.id, record);
      }
    }
  }

  List<ProgressRecord> byLearnerId(String learnerId) =>
      _progress.values.where((p) => p.learnerId == learnerId).toList()
        ..sort((a, b) => b.completedAt.compareTo(a.completedAt));

  /// Every `lessonId` this learner has finished in the Main Game (Adventure Map) —
  /// by default excludes teacher-assigned homework and classroom mode play so
  /// homework completions do not automatically mark main game map levels as done.
  Set<String> completedLessonIds(
    String learnerId, {
    bool includeAssigned = false,
  }) => _progress.values
      .where(
        (p) =>
            p.learnerId == learnerId &&
            p.lessonId != null &&
            (includeAssigned || (!p.assignedByTeacher && !p.isClassroomMode)),
      )
      .map((p) => p.lessonId!)
      .toSet();

  /// Every `lessonId` this learner has finished specifically as assigned homework.
  Set<String> completedHomeworkLessonIds(String learnerId) => _progress.values
      .where(
        (p) =>
            p.learnerId == learnerId &&
            p.lessonId != null &&
            p.assignedByTeacher &&
            !p.isClassroomMode,
      )
      .map((p) => p.lessonId!)
      .toSet();

  /// When [learnerId] finished every lesson in [lessonIds] as homework — the
  /// first completion of the last one to be finished — or null while any is
  /// still unplayed. Same "homework" filter as [completedHomeworkLessonIds],
  /// so the teacher's "Done" date matches the learner's own checklist.
  DateTime? homeworkDoneAt(String learnerId, Iterable<String> lessonIds) {
    final wanted = lessonIds.toSet();
    if (wanted.isEmpty) return null;
    final firstDone = <String, DateTime>{};
    for (final p in _progress.values) {
      final id = p.lessonId;
      if (p.learnerId != learnerId ||
          !p.assignedByTeacher ||
          p.isClassroomMode ||
          id == null ||
          !wanted.contains(id)) {
        continue;
      }
      final prev = firstDone[id];
      if (prev == null || p.completedAt.isBefore(prev)) {
        firstDone[id] = p.completedAt;
      }
    }
    if (firstDone.length < wanted.length) return null;
    return firstDone.values.reduce((a, b) => a.isAfter(b) ? a : b);
  }

  List<ProgressRecord> _sinceDays(String learnerId, int days) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return byLearnerId(
      learnerId,
    ).where((p) => p.completedAt.isAfter(cutoff)).toList();
  }

  /// FR-5.1 — accuracy %, time-on-task, and error totals over the last
  /// [days] (defaults to the last 7, matching the dashboard's "this week").
  ProgressSummary summary(String learnerId, {int days = 7}) {
    final now = DateTime.now();
    return summaryForRange(learnerId, now.subtract(Duration(days: days)), now);
  }

  /// Same rollup as [summary], but over an arbitrary `[from, to)` window —
  /// used to compare "this week" against "last week" for trend arrows.
  ProgressSummary summaryForRange(
    String learnerId,
    DateTime from,
    DateTime to,
  ) {
    final records = byLearnerId(learnerId)
        .where((p) => p.completedAt.isAfter(from) && p.completedAt.isBefore(to))
        .toList();
    if (records.isEmpty) {
      return const ProgressSummary(
        accuracyPct: 0,
        timeOnTaskMinutes: 0,
        errorCount: 0,
      );
    }
    final avgAccuracy =
        records.map((r) => r.strokeAccuracyPct).reduce((a, b) => a + b) /
        records.length;
    final totalSeconds = records
        .map((r) => r.timeOnTaskSeconds)
        .reduce((a, b) => a + b);
    final totalErrors = records
        .map((r) => r.sequencingErrors)
        .reduce((a, b) => a + b);
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
      final day = DateTime(
        r.completedAt.year,
        r.completedAt.month,
        r.completedAt.day,
      );
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
      final label = windowDays <= 7
          ? weekdayLabels[day.weekday % 7]
          : '${day.day}/${day.month}';
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
          records.map((r) => r.strokeAccuracyPct).reduce((a, b) => a + b) /
          records.length;
      final totalErrors = records
          .map((r) => r.sequencingErrors)
          .reduce((a, b) => a + b);
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
  /// Consecutive play days ending at the learner's latest play day, read
  /// from their progress records — which sync across devices, unlike a
  /// separately stored counter would.
  ({int run, DateTime? last}) _streak(String learnerId) {
    final days = {
      for (final p in _progress.values)
        if (p.learnerId == learnerId)
          DateTime(p.completedAt.year, p.completedAt.month, p.completedAt.day),
    };
    if (days.isEmpty) return (run: 0, last: null);
    final last = days.reduce((a, b) => a.isAfter(b) ? a : b);
    var run = 1;
    while (days.contains(DateTime(last.year, last.month, last.day - run))) {
      run++;
    }
    return (run: run, last: last);
  }

  int currentStreak(String learnerId) => _streak(learnerId).run;

  /// The streak a learner has right now: their run if they played today or
  /// yesterday, 0 once a day has been missed (or they never played).
  int activeStreak(String learnerId) {
    final s = _streak(learnerId);
    if (s.last == null) return 0;
    return _daysSince(s.last!) <= 1 ? s.run : 0;
  }

  /// What the streak becomes once [learnerId] plays today (same day:
  /// unchanged; next day: +1; else 1).
  int streakAfterPlayingToday(String learnerId) {
    final s = _streak(learnerId);
    if (s.last == null) return 1;
    return switch (_daysSince(s.last!)) {
      0 => s.run,
      1 => s.run + 1,
      _ => 1,
    };
  }

  static int _daysSince(DateTime date) {
    final now = DateTime.now();
    return DateTime(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime(date.year, date.month, date.day)).inDays;
  }

  Future<void> awardBadge(String learnerId, String badgeId) async {
    final key = '$learnerId:$badgeId';
    if (_badges.containsKey(key)) return;
    final award = BadgeAward(
      learnerId: learnerId,
      badgeId: badgeId,
      earnedAt: DateTime.now(),
    );
    await _badges.put(key, award);
    // Same live push as [writeProgress], so the badge shows up on the
    // learner's other devices.
    Future.sync(
      () => FirestoreMirror().pushBadge(award),
    ).catchError((Object e) => debugPrint('awardBadge: push failed: $e'));
  }

  /// Adds badges earned on another device. A badge is only ever earned
  /// once, so an existing key is already up to date.
  Future<void> mergeRemoteBadges(Iterable<BadgeAward> awards) async {
    for (final award in awards) {
      final key = '${award.learnerId}:${award.badgeId}';
      if (!_badges.containsKey(key)) await _badges.put(key, award);
    }
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
    for (final award in _badges.values) {
      await mirror.pushBadge(award);
    }
  }
}
