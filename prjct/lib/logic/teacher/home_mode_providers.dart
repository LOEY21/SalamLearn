import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../data/local/hive_boxes.dart';
import '../../data/curriculum_data.dart';
import '../../data/models/curriculum/curriculum_models.dart';
import '../../data/models/progress_record.dart';
import '../../data/repositories/class_repository.dart';
import '../../data/repositories/progress_repository.dart';

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
    Provider.family<List<HomeModeAggregate>, String>(
      (ref, classId) => computeHomeModeAggregate(classId),
    );

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
List<ProgressRecord> homeModeHistoryFor(String learnerId) => ProgressRepository()
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
    final totalErrors =
        records.map((r) => r.sequencingErrors).reduce((a, b) => a + b);
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

final homeModeHistoryProvider =
    Provider.family<List<ProgressRecord>, String>(
      (ref, learnerId) => homeModeHistoryFor(learnerId),
    );

final homeModeModuleSummaryProvider =
    Provider.family<List<HomeModeModuleSummary>, String>(
      (ref, learnerId) => homeModeSummaryFor(learnerId),
    );
