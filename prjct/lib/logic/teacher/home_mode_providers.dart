import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../data/local/hive_boxes.dart';
import '../../data/curriculum_data.dart';
import '../../data/models/curriculum/curriculum_models.dart';
import '../../data/models/progress_record.dart';
import '../../data/repositories/class_repository.dart';
import '../../data/repositories/progress_repository.dart';
import '../progress_providers.dart';
import '../parent/game_grades.dart';
import 'teacher_providers.dart';

/// FR-6.2B — Home Mode analytics live entirely separately from
/// [computeClassHealthIndex] (teacher_providers.dart, now Hot-Seat/
/// Classroom-Mode-only): every query here filters `isClassroomMode ==
/// false`, so solo Student Hub/Adventure Map play and live Cast telemetry
/// can never bleed into each other again.

/// One curriculum destination's class-wide Home Mode rollup — the
/// Aggregate Home Performance View's per-row unit. Deliberately its own
/// type (not a reuse of `ModuleHealth`) so a future change to the
/// Classroom-Mode shape can't silently change this one too.
class HomeModeAggregate {
  const HomeModeAggregate({
    required this.moduleId,
    required this.moduleName,
    required this.completionRate,
    required this.avgAccuracy,
    required this.avgErrors,
    required this.trend,
    required this.hasActivity,
  });

  final String moduleId;
  final String moduleName;
  final double completionRate;
  final double avgAccuracy;
  final double avgErrors;
  final double? trend;
  final bool hasActivity;
}

/// Pure aggregation, no Riverpod dependency — mirrors
/// `computeClassHealthIndex`'s own split so [homeModeAggregateProvider] is
/// a one-line wrapper and this stays directly unit-testable.
List<HomeModeAggregate> computeHomeModeAggregate(String classId) {
  final classes = ClassRepository();
  final progress = ProgressRepository();
  final enrollments = classes.byClassId(classId);
  final rosterSize = enrollments.length;
  final now = DateTime.now();
  final weekAgo = now.subtract(const Duration(days: 7));
  final twoWeeksAgo = now.subtract(const Duration(days: 14));

  HomeModeAggregate emptyRow(Destination destination) => HomeModeAggregate(
    moduleId: destination.id.toString(),
    moduleName: destination.name,
    completionRate: 0,
    avgAccuracy: 0,
    avgErrors: 0,
    trend: null,
    hasActivity: false,
  );

  if (rosterSize == 0) return curriculum.map(emptyRow).toList();

  // Perform a single pass over the progress records instead of querying and sorting
  // byLearnerId repeatedly for each learner (which causes heavy database scans and lag).
  final recordsByModule = <String, List<ProgressRecord>>{};
  final learnersWithActivityByModule = <String, int>{};

  final learnerIds = enrollments.map((e) => e.learnerId).toSet();
  final studentModuleRecords = <String, Map<String, List<ProgressRecord>>>{};

  final progressBox = Hive.box<ProgressRecord>(HiveBoxes.progress);
  for (final record in progressBox.values) {
    if (learnerIds.contains(record.learnerId) && !record.isClassroomMode) {
      studentModuleRecords
          .putIfAbsent(record.learnerId, () => {})
          .putIfAbsent(record.moduleId, () => [])
          .add(record);
    }
  }

  for (final learnerId in learnerIds) {
    final byModule = studentModuleRecords[learnerId];
    if (byModule == null) continue;
    byModule.forEach((moduleId, records) {
      recordsByModule.putIfAbsent(moduleId, () => []).addAll(records);
      learnersWithActivityByModule[moduleId] =
          (learnersWithActivityByModule[moduleId] ?? 0) + 1;
    });
  }

  return curriculum.map((destination) {
    final moduleId = destination.id.toString();
    final allRecords = recordsByModule[moduleId] ?? const <ProgressRecord>[];
    final learnersWithActivity = learnersWithActivityByModule[moduleId] ?? 0;

    if (allRecords.isEmpty) return emptyRow(destination);

    final completionRate = learnersWithActivity / rosterSize;
    final avgAccuracy =
        allRecords.map((r) => r.strokeAccuracyPct).reduce((a, b) => a + b) /
        allRecords.length;
    final avgErrors =
        allRecords.map((r) => r.sequencingErrors).reduce((a, b) => a + b) /
        allRecords.length;

    final thisWeek = allRecords.where((r) => r.completedAt.isAfter(weekAgo));
    final priorWeek = allRecords.where(
      (r) =>
          r.completedAt.isAfter(twoWeeksAgo) && r.completedAt.isBefore(weekAgo),
    );
    double? trend;
    if (thisWeek.isNotEmpty && priorWeek.isNotEmpty) {
      final thisWeekAvg =
          thisWeek.map((r) => r.strokeAccuracyPct).reduce((a, b) => a + b) /
          thisWeek.length;
      final priorWeekAvg =
          priorWeek.map((r) => r.strokeAccuracyPct).reduce((a, b) => a + b) /
          priorWeek.length;
      trend = thisWeekAvg - priorWeekAvg;
    }

    return HomeModeAggregate(
      moduleId: moduleId,
      moduleName: destination.name,
      completionRate: completionRate,
      avgAccuracy: avgAccuracy,
      avgErrors: avgErrors,
      trend: trend,
      hasActivity: true,
    );
  }).toList();
}

/// Class-wide Aggregate Home Performance View (FR-6.2B) for `classId`.
final homeModeAggregateProvider =
    Provider.family<List<HomeModeAggregate>, String>((ref, classId) {
      ref.watch(rosterRefreshProvider);
      ref.watch(progressChangesProvider);
      return computeHomeModeAggregate(classId);
    });

/// The single weakest destination with recorded activity — the "collective
/// misconception" the Aggregate view is required to surface. Null once
/// nothing has any Home Mode activity yet, or once every active module is
/// already comfortably mastered (>=70%).
HomeModeAggregate? weakestHomeModeAggregate(List<HomeModeAggregate> rows) {
  final active = rows.where((r) => r.hasActivity).toList();
  if (active.isEmpty) return null;
  active.sort((a, b) => a.avgAccuracy.compareTo(b.avgAccuracy));
  final weakest = active.first;
  return weakest.avgAccuracy < 70 ? weakest : null;
}

/// One curriculum destination's Home Mode rollup for a single learner —
/// the Individual Progress Tracking view's per-row unit.
class HomeModeModuleSummary {
  const HomeModeModuleSummary({
    required this.moduleId,
    required this.moduleName,
    required this.accuracyPct,
    required this.errorCount,
    required this.sessionCount,
  });

  final String moduleId;
  final String moduleName;
  final double accuracyPct;
  final int errorCount;
  final int sessionCount;
}

/// Resolves a `ProgressRecord.moduleId` back to its curriculum destination
/// name for display — falls back to the raw id for anything that isn't a
/// numeric destination id (there's nothing else Home Mode ever writes, but
/// this keeps history rows from crashing on unexpected data instead of
/// showing a blank name).
String destinationNameForModuleId(String moduleId) {
  final id = int.tryParse(moduleId);
  if (id == null) return moduleId;
  for (final destination in curriculum) {
    if (destination.id == id) return destination.name;
  }
  return moduleId;
}

/// Every `ProgressRecord` this learner earned outside a Cast session, most
/// recent first — the Individual view's "completion history" list.
List<ProgressRecord> homeModeHistoryFor(String learnerId) =>
    ProgressRepository()
        .byLearnerId(learnerId)
        .where((r) => !r.isClassroomMode)
        .toList();

/// Longitudinal mastery view — this learner's Home Mode records rolled up
/// per destination, weakest accuracy first (mirrors
/// `ProgressRepository.summaryByModule`'s ranking convention).
List<HomeModeModuleSummary> homeModeSummaryFor(String learnerId) {
  final byModule = <String, List<ProgressRecord>>{};
  for (final record in homeModeHistoryFor(learnerId)) {
    byModule.putIfAbsent(record.moduleId, () => []).add(record);
  }
  final summaries = byModule.entries.map((entry) {
    final records = entry.value;
    final avgAccuracy =
        records.map((r) => r.strokeAccuracyPct).reduce((a, b) => a + b) /
        records.length;
    final totalErrors = records
        .map((r) => r.sequencingErrors)
        .reduce((a, b) => a + b);
    return HomeModeModuleSummary(
      moduleId: entry.key,
      moduleName: destinationNameForModuleId(entry.key),
      accuracyPct: avgAccuracy,
      errorCount: totalErrors,
      sessionCount: records.length,
    );
  }).toList();
  summaries.sort((a, b) => a.accuracyPct.compareTo(b.accuracyPct));
  return summaries;
}

final homeModeHistoryProvider = Provider.family<List<ProgressRecord>, String>((
  ref,
  learnerId,
) {
  ref.watch(progressChangesProvider);
  return homeModeHistoryFor(learnerId);
});

final homeModeModuleSummaryProvider =
    Provider.family<List<HomeModeModuleSummary>, String>((ref, learnerId) {
      ref.watch(progressChangesProvider);
      return homeModeSummaryFor(learnerId);
    });

/// One session in Home Performance: how many students played it at home
/// and their average score (null when nobody has).
class HomeSession {
  const HomeSession({
    required this.label,
    required this.detail,
    required this.studentsPlayed,
    required this.avgAccuracy,
  });

  final String label;
  final String detail;
  final int studentsPlayed;
  final double? avgAccuracy;
}

/// A game or a stage (map destination) with its sessions, rolled up from
/// Home Mode records.
class HomeProgressGroup {
  const HomeProgressGroup({
    required this.name,
    required this.icon,
    required this.sessions,
    required this.studentsPlayed,
    required this.avgAccuracy,
  });

  final String name;
  final String icon;
  final List<HomeSession> sessions;

  /// Distinct students with at least one session played.
  final int studentsPlayed;
  final double? avgAccuracy;

  int get sessionsPlayed => sessions.where((s) => s.studentsPlayed > 0).length;
}

Map<String, List<ProgressRecord>> _homeRecordsByLesson(
  Iterable<ProgressRecord> records,
) {
  final byLesson = <String, List<ProgressRecord>>{};
  for (final r in records) {
    if (!r.isClassroomMode && r.lessonId != null) {
      byLesson.putIfAbsent(r.lessonId!, () => []).add(r);
    }
  }
  return byLesson;
}

double? _avgAccuracy(Iterable<ProgressRecord> rs) => rs.isEmpty
    ? null
    : rs.map((r) => r.strokeAccuracyPct).reduce((a, b) => a + b) / rs.length;

HomeProgressGroup _group({
  required String name,
  required String icon,
  required List<(Lesson, String label, String detail)> sessions,
  required Map<String, List<ProgressRecord>> byLesson,
}) {
  final all = [for (final (lesson, _, _) in sessions) ...?byLesson[lesson.id]];
  return HomeProgressGroup(
    name: name,
    icon: icon,
    studentsPlayed: all.map((r) => r.learnerId).toSet().length,
    avgAccuracy: _avgAccuracy(all),
    sessions: [
      for (final (lesson, label, detail) in sessions)
        HomeSession(
          label: label,
          detail: detail,
          studentsPlayed: (byLesson[lesson.id] ?? const [])
              .map((r) => r.learnerId)
              .toSet()
              .length,
          avgAccuracy: _avgAccuracy(byLesson[lesson.id] ?? const []),
        ),
    ],
  );
}

String _gameName(Lesson lesson) {
  final type = lesson.activities.first.type;
  return castGameNames[type] ?? lesson.title.split(' - ').first;
}

/// The 12 games in map order, each with its sessions, from [records] —
/// one learner's history for the Individual view or the whole roster's for
/// the Aggregate view. Only records with a lessonId map to a session.
List<HomeProgressGroup> homeModeGamesFor(Iterable<ProgressRecord> records) {
  final byLesson = _homeRecordsByLesson(records);
  return [
    for (final game in curriculumGames())
      _group(
        name: castGameNames[game.type] ?? game.name,
        icon: game.icon,
        byLesson: byLesson,
        sessions: [
          for (final s in game.sessions)
            (s.lesson, sessionLabel(s.lesson), s.destination.name),
        ],
      ),
  ];
}

/// The 7 map stages (destinations), each with the sessions played there.
List<HomeProgressGroup> homeModeStagesFor(Iterable<ProgressRecord> records) {
  final byLesson = _homeRecordsByLesson(records);
  return [
    for (final (i, destination) in curriculum.indexed)
      _group(
        name: 'Stage ${i + 1}: ${destination.name}',
        icon: destination.icon,
        byLesson: byLesson,
        sessions: [
          for (final lesson in destination.lessons)
            (lesson, _gameName(lesson), sessionLabel(lesson)),
        ],
      ),
  ];
}

Iterable<ProgressRecord> _classRecords(String classId) {
  final learnerIds = {
    for (final e in ClassRepository().byClassId(classId)) e.learnerId,
  };
  return Hive.box<ProgressRecord>(
    HiveBoxes.progress,
  ).values.where((r) => learnerIds.contains(r.learnerId));
}

/// Aggregate view: every enrolled student's Home Mode records, grouped by
/// game ([byStage] false) or by map stage ([byStage] true).
final homeModeClassGroupsProvider =
    Provider.family<List<HomeProgressGroup>, (String, bool)>((ref, args) {
      final (classId, byStage) = args;
      ref.watch(rosterRefreshProvider);
      ref.watch(progressChangesProvider);
      final records = _classRecords(classId);
      return byStage ? homeModeStagesFor(records) : homeModeGamesFor(records);
    });

/// Individual view: this learner's Home Mode history, by game or by stage.
final homeModeLearnerGroupsProvider =
    Provider.family<List<HomeProgressGroup>, (String, bool)>((ref, args) {
      final (learnerId, byStage) = args;
      final history = ref.watch(homeModeHistoryProvider(learnerId));
      return byStage ? homeModeStagesFor(history) : homeModeGamesFor(history);
    });
