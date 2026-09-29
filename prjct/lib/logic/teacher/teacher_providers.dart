import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../data/curriculum_data.dart';
import '../../data/local/hive_boxes.dart';
import '../../data/models/class_section.dart';
import '../../data/models/curriculum/curriculum_models.dart';
import '../../data/models/custom_lesson.dart';
import '../../data/models/lesson_folder.dart';
import '../../data/models/progress_record.dart';
import '../../data/repositories/class_repository.dart';
import '../../data/repositories/custom_lesson_repository.dart';
import '../../data/repositories/learner_repository.dart';
import '../../data/repositories/lesson_folder_repository.dart';
import '../../data/repositories/progress_repository.dart';
import '../../data/models/enrollment.dart';
import '../../data/remote/firestore_mirror.dart';
import '../../ui/core_modules/module_registry.dart';
import '../auth/session.dart';
import '../progress_providers.dart';

String _moduleTitle(String moduleId) => assignmentTitle(moduleId);

/// Real, Hive-backed replacement for the hardcoded Ali/Yusra/Hamza roster
/// and single-class state that used to live directly in
/// `teacher_dashboard_screen.dart` (FR-6.1, FR-6.2, FR-6.3).
///
/// A teacher can own several [ClassSection]s; this tracks whichever one is
/// currently being viewed/managed (roster, homework, invitation code all
/// scope to it). The choice persists in the `settings` Hive box under
/// `activeClassId` — same pattern as the Parent side's `activeLearnerId` —
/// so it survives app restarts, defaulting to the first owned class when
/// nothing is picked yet or the stored id no longer belongs to this teacher.
class TeacherClassController extends Notifier<ClassSection?> {
  final _classes = ClassRepository();
  Box get _settings => Hive.box(HiveBoxes.settings);

  @override
  ClassSection? build() {
    final teacherId = ref.watch(
      sessionProvider.select((s) => s.activeTeacherId),
    );
    if (teacherId == null) return null;
    final owned = _classes.activeByTeacherId(teacherId);
    if (owned.isEmpty) return null;
    final activeId = _settings.get('activeClassId') as String?;
    final match = owned.where((c) => c.id == activeId);
    return match.isNotEmpty ? match.first : owned.first;
  }

  Future<void> createClass({
    required String gradeLevel,
    required String section,
    String? schedule,
  }) async {
    final teacherId = ref.read(sessionProvider).activeTeacherId;
    if (teacherId == null) return;
    final created = await _classes.create(
      teacherId: teacherId,
      gradeLevel: gradeLevel,
      section: section,
      schedule: schedule,
    );
    await _settings.put('activeClassId', created.id);
    state = created;
  }

  /// Switches which owned class the dashboard is viewing (FR-6.1 — a
  /// teacher can manage more than one class section).
  Future<void> switchClass(String classId) async {
    final teacherId = ref.read(sessionProvider).activeTeacherId;
    if (teacherId == null) return;
    // Archived classes are read-only and can never become "the active
    // class" — an archived roster shouldn't be castable or receive new
    // homework. See [ClassSection.isArchived].
    final match = _classes
        .activeByTeacherId(teacherId)
        .where((c) => c.id == classId);
    if (match.isEmpty) return;
    await _settings.put('activeClassId', classId);
    state = match.first;
  }

  /// Deletes an owned class (FR-6.1's inverse — a teacher can retire a
  /// section they created). If the deleted class was active, falls back
  /// to another owned class, or null if none remain.
  Future<void> deleteClass(String classId) async {
    final teacherId = ref.read(sessionProvider).activeTeacherId;
    if (teacherId == null) return;
    await _classes.deleteClass(classId);
    final remaining = _classes.activeByTeacherId(teacherId);
    if (remaining.isEmpty) {
      await _settings.delete('activeClassId');
      state = null;
    } else if (state?.id == classId) {
      await _settings.put('activeClassId', remaining.first.id);
      state = remaining.first;
    }
  }

  /// Archives an owned class (FR-6.1's "school year ended" retirement, see
  /// [ClassRepository.archiveClass]) — reachable from the Class Detail
  /// screen for whichever class it's showing, not just the active one. If
  /// the archived class was active, falls back to another active class, or
  /// null if none remain — same fallback contract as [deleteClass].
  Future<void> archiveClass(String classId) async {
    await _classes.archiveClass(classId);
    if (state?.id != classId) return;
    final teacherId = ref.read(sessionProvider).activeTeacherId;
    if (teacherId == null) return;
    final remaining = _classes.activeByTeacherId(teacherId);
    if (remaining.isEmpty) {
      await _settings.delete('activeClassId');
      state = null;
    } else {
      await _settings.put('activeClassId', remaining.first.id);
      state = remaining.first;
    }
  }

  /// Reverses [archiveClass] — doesn't touch which class is "active" since
  /// an unarchived class doesn't automatically become current, matching
  /// how a newly-created class isn't forced active either.
  Future<void> unarchiveClass(String classId) async {
    await _classes.unarchiveClass(classId);
  }
}

final teacherClassControllerProvider =
    NotifierProvider<TeacherClassController, ClassSection?>(
      TeacherClassController.new,
    );

/// Every class the active teacher owns (FR-6.1) — backs the class
/// switcher in the Profile tab. Watches [teacherClassControllerProvider]
/// purely to force a recompute after create/switch, the same "watch
/// something that changes" trick `parentLearnersProvider` uses since Hive
/// box reads aren't natively observable by Riverpod.
final teacherClassesProvider = Provider<List<ClassSection>>((ref) {
  final teacherId = ref.watch(sessionProvider.select((s) => s.activeTeacherId));
  ref.watch(teacherClassControllerProvider);
  if (teacherId == null) return const [];
  return ClassRepository().activeByTeacherId(teacherId);
});

/// Backs the Archived Classes screen — every class the teacher has
/// archived (FR-6.1's "school year ended" retirement), read-only.
final archivedTeacherClassesProvider = Provider<List<ClassSection>>((ref) {
  final teacherId = ref.watch(sessionProvider.select((s) => s.activeTeacherId));
  ref.watch(teacherClassControllerProvider);
  if (teacherId == null) return const [];
  return ClassRepository().archivedByTeacherId(teacherId);
});

final activeClassNameProvider = Provider<String>((ref) {
  final section = ref.watch(teacherClassControllerProvider);
  return section?.name ?? 'No class yet — create one';
});

/// Total enrolled students across every class the teacher owns — backs
/// the Classroom tab's hero stat pill. Sums each owned class's roster
/// rather than reading `teacherRosterProvider` (which is scoped to just
/// the active class).
final teacherTotalStudentsProvider = Provider<int>((ref) {
  final classes = ref.watch(teacherClassesProvider);
  var total = 0;
  for (final section in classes) {
    total += ref.watch(classRosterProvider(section.id)).length;
  }
  return total;
});

final classInvitationCodeProvider = Provider<String>((ref) {
  final section = ref.watch(teacherClassControllerProvider);
  return section?.invitationCode ?? '—';
});

String _masteryFor(double accuracyPct) {
  if (accuracyPct >= 80) return 'High';
  if (accuracyPct >= 50) return 'Medium';
  return 'Needs help';
}

class RosterRefreshNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final rosterRefreshProvider = NotifierProvider<RosterRefreshNotifier, int>(
  RosterRefreshNotifier.new,
);

/// Listens to Firestore enrollment changes for the active class and syncs
/// to Hive in real time. Bumps [rosterRefreshProvider] on every change so
/// the roster UI reflects admin-web enroll/unenroll immediately.
final teacherEnrollmentSyncProvider = StreamProvider.autoDispose<void>((
  ref,
) async* {
  final section = ref.watch(teacherClassControllerProvider);
  if (section == null) {
    yield null;
    return;
  }
  final classId = section.id;
  final enrollmentsBox = Hive.box<Enrollment>(HiveBoxes.enrollments);
  final mirror = FirestoreMirror();

  final learners = LearnerRepository();

  await for (final remoteLearnerIds in mirror.watchEnrollmentsForClass(
    classId,
  )) {
    final local = enrollmentsBox.values
        .where((e) => e.classId == classId)
        .map((e) => e.learnerId)
        .toSet();

    // Add new enrollments
    for (final learnerId in remoteLearnerIds.difference(local)) {
      final key = '$classId:$learnerId';
      await enrollmentsBox.put(
        key,
        Enrollment(
          classId: classId,
          learnerId: learnerId,
          enrolledAt: DateTime.now(),
        ),
      );
      // An enrollment created directly in Firestore (e.g. the admin
      // website's own "Enroll" button) can reference a learner this
      // device has never seen — without this, classRosterProvider's
      // `learners.findById` comes back null and silently drops the
      // student from the roster despite the enrollment existing.
      if (learners.findById(learnerId) == null) {
        try {
          final remoteLearner = await mirror.fetchLearner(learnerId);
          if (remoteLearner != null) {
            await learners.saveFromRemote(
              id: remoteLearner.id,
              parentId: remoteLearner.parentId ?? '',
              name: remoteLearner.name,
              age: remoteLearner.age,
              avatar: remoteLearner.avatar,
              gradeLevel: remoteLearner.gradeLevel,
              username: remoteLearner.username,
              createdAt: remoteLearner.createdAt,
            );
          }
        } catch (_) {
          // Best-effort — offline devices just show an empty roster slot
          // until the next successful sync.
        }
      }
    }

    // Remove deleted enrollments
    for (final learnerId in local.difference(remoteLearnerIds)) {
      final key = '$classId:$learnerId';
      await enrollmentsBox.delete(key);
    }

    if (remoteLearnerIds.difference(local).isNotEmpty ||
        local.difference(remoteLearnerIds).isNotEmpty) {
      ref.read(rosterRefreshProvider.notifier).bump();
    }

    yield null;
  }
});

/// The real roster for one specific class — one entry per learner
/// enrolled in it, with real [ProgressRepository] telemetry. Until Module
/// 4's core learning engines exist and write [ProgressRecord]s,
/// freshly-enrolled learners correctly show 0% completion/accuracy rather
/// than fabricated numbers — that's the actual current state, not a bug.
///
/// Parameterized by `classId` (rather than always reading the "active"
/// class) so the Profile tab's per-class management cards can show every
/// owned class's students at once, not just whichever one happens to be
/// active.
final classRosterProvider = Provider.family<List<Map<String, dynamic>>, String>((
  ref,
  classId,
) {
  ref.watch(rosterRefreshProvider);
  ref.watch(progressChangesProvider);
  final classes = ClassRepository();
  final learners = LearnerRepository();
  final progress = ProgressRepository();

  final enrollments = classes.byClassId(classId);
  final allLessonIds = {
    for (final destination in curriculum)
      for (final lesson in destination.lessons) lesson.id,
  };
  final roster = <Map<String, dynamic>>[];
  for (final enrollment in enrollments) {
    final learner = learners.findById(enrollment.learnerId);
    if (learner == null) continue;
    final summary = progress.summary(enrollment.learnerId);
    final lessonsDone = progress
        .completedLessonIds(enrollment.learnerId)
        .intersection(allLessonIds)
        .length;
    final rawAssignments = classes.assignmentsFor(
      classId: classId,
      learnerId: enrollment.learnerId,
    );
    final assignments = rawAssignments
        .map(
          (a) =>
              '${_moduleTitle(a.moduleId)} (Due: ${a.dueDate.day}/${a.dueDate.month}/${a.dueDate.year})',
        )
        .toList();
    roster.add({
      'learnerId': enrollment.learnerId,
      'name': learner.name,
      // Share of curriculum lessons finished — not accuracy, which is
      // already shown as 'tracing'/mastery.
      'completion': allLessonIds.isEmpty
          ? 0.0
          : lessonsDone / allLessonIds.length,
      'tracing': '${summary.accuracyPct.round()}%',
      'activity': summary.timeOnTaskMinutes == 0
          ? 'No activity yet'
          : '${summary.timeOnTaskMinutes}m logged',
      'errorCount': summary.errorCount,
      'mastery': _masteryFor(summary.accuracyPct),
      'assignedModules': assignments,
      // Raw (moduleId, dueDate, maxLevel, maxLessons) tuples — used by the
      // learner Adventure Map to flag overdue nodes and gate level/lesson
      // access; the formatted `assignedModules` strings above are
      // display-only and stay untouched for the teacher dashboard.
      'assignedModuleDues': [
        for (final a in rawAssignments)
          (a.moduleId, a.dueDate, a.maxLevel, a.maxLessons),
      ],
    });
  }
  return roster;
});

/// The active class's roster — what the Roster tab and homework assigner
/// read. Thin wrapper over [classRosterProvider] scoped to whichever class
/// [teacherClassControllerProvider] currently has active.
final teacherRosterProvider = Provider<List<Map<String, dynamic>>>((ref) {
  final section = ref.watch(teacherClassControllerProvider);
  if (section == null) return const [];
  return ref.watch(classRosterProvider(section.id));
});

/// Whole-class (not per-student) homework assignments for the active class.
final classHomeworkProvider = Provider<List<Map<String, dynamic>>>((ref) {
  final section = ref.watch(teacherClassControllerProvider);
  if (section == null) return const [];
  final classes = ClassRepository();
  return classes
      .assignmentsFor(classId: section.id, learnerId: null)
      .map(
        (a) => {
          'module': _moduleTitle(a.moduleId),
          'dueDate': '${a.dueDate.day}/${a.dueDate.month}/${a.dueDate.year}',
          'dueDateRaw': a.dueDate,
          'maxLevel': a.maxLevel,
          'maxLessons': a.maxLessons,
        },
      )
      .toList();
});

/// A class's freeform lessons (title/instructions/body), newest first —
/// backs `class_detail_screen.dart`'s "Custom Lessons" card. Plain Hive
/// read like [classRosterProvider]; callers `ref.invalidate` this after
/// create/delete since Hive box writes aren't natively observable.
final classCustomLessonsProvider = Provider.family<List<CustomLesson>, String>(
  (ref, classId) => CustomLessonRepository().byClassId(classId),
);

/// Every custom lesson across every class the given learner is enrolled
/// in — what the Student Hub's "From your teacher" section reads.
final learnerCustomLessonsProvider =
    Provider.family<List<CustomLesson>, String>((ref, learnerId) {
      final classIds = ClassRepository()
          .byLearnerId(learnerId)
          .map((e) => e.classId);
      return CustomLessonRepository().byClassIds(classIds);
    });

/// A class's saved Module Library folders (FR-6.8), most recently updated
/// first — backs `module_library_screen.dart`. Plain Hive read like
/// [classCustomLessonsProvider]; callers `ref.invalidate` this after
/// create/update/delete since Hive box writes aren't natively observable.
final classLessonFoldersProvider = Provider.family<List<LessonFolder>, String>(
  (ref, classId) => LessonFolderRepository().byClassId(classId),
);

/// The games on the Cast screen, by display name — shared with
/// `cast_games.dart` so the Class Health Index rows read exactly like the
/// game picker the teacher plays from.
const castGameNames = <ActivityType, String>{
  ActivityType.pronounce: 'Greeting Match',
  ActivityType.creationHunt: "Allah's Creation Hunt",
  ActivityType.trace: 'Magic Sand Tracer',
  ActivityType.soundDetective: 'Arabic Sound Detective',
  ActivityType.quranEtiquette: "The Qur'an Etiquette",
  ActivityType.labelMaker: 'Label Maker',
  ActivityType.ayahBuilder: 'Ayah Builder',
  ActivityType.sirahStory: 'Sirah Story',
  ActivityType.classroomHeroes: 'Classroom Heroes',
  ActivityType.taharahAdventure: 'Taharah Adventure',
  ActivityType.fivePillars: 'The Five Pillars',
  ActivityType.goodDeedTree: 'The Good Deed Tree',
};

String _castGameModuleId(ActivityType type) => 'cast_${type.name}';

/// Cast games in the order they first appear on the map, with each game's
/// icon — the same order the Cast screen lists them in.
List<(ActivityType, String)> _castGamesInOrder() {
  final seen = <ActivityType, String>{};
  for (final destination in curriculum) {
    for (final lesson in destination.lessons) {
      final activity = lesson.activities.first;
      if (castGameNames.containsKey(activity.type)) {
        seen.putIfAbsent(activity.type, () => activity.icon);
      }
    }
  }
  return [for (final e in seen.entries) (e.key, e.value)];
}

/// Which Cast game a classroom record belongs to: `cast_<game>` from the
/// Cast screen, or Magic Sand Tracer for the dashboard's letter Hot Seat
/// tracing (`hot_seat_<letter>`).
ActivityType? castGameFor(ProgressRecord record) {
  final id = record.moduleId;
  if (id.startsWith('hot_seat_')) return ActivityType.trace;
  if (!id.startsWith('cast_')) return null;
  return ActivityType.values.asNameMap()[id.substring(5)];
}

/// One Cast game's aggregated classroom telemetry (FR-6.2). Built
/// exclusively from [ProgressRecord.isClassroomMode] records — Student Hub/
/// Adventure Map solo play (`isClassroomMode: false`) never counts here,
/// since the Class Health Index exists to show a teacher what happened
/// live in class, not at home.
class ModuleHealth {
  const ModuleHealth({
    required this.moduleId,
    required this.moduleName,
    required this.completionRate,
    required this.avgAccuracy,
    required this.avgErrors,
    required this.trend,
    required this.healthIndex,
    required this.hasActivity,
    this.attemptCount = 0,
    this.studentsUp = 0,
    this.icon = '',
  });

  final String moduleId;
  final String moduleName;
  final double completionRate;
  final double avgAccuracy;
  final double avgErrors;
  final double? trend;
  final int healthIndex;
  final bool hasActivity;

  /// Total classroom plays of this game across the whole roster — a
  /// student called up more than once counts once per play.
  final int attemptCount;

  /// Distinct students who've played this game on the Hot Seat at least
  /// once (the numerator behind [completionRate]).
  final int studentsUp;

  /// The game's emoji, as shown on the Cast screen.
  final String icon;
}

/// Pure aggregation, no Riverpod dependency — kept as a standalone function
/// so [classHealthIndexProvider] is a one-line wrapper and the logic itself
/// is directly unit-testable without a `ProviderContainer`.
List<ModuleHealth> computeClassHealthIndex(String classId) {
  final enrollments = ClassRepository().byClassId(classId);
  final rosterSize = enrollments.length;
  final now = DateTime.now();
  final weekAgo = now.subtract(const Duration(days: 7));
  final twoWeeksAgo = now.subtract(const Duration(days: 14));
  final games = _castGamesInOrder();

  // Single pass over the progress box instead of a byLearnerId scan per
  // learner.
  final learnerIds = enrollments.map((e) => e.learnerId).toSet();
  final recordsByGame = <ActivityType, List<ProgressRecord>>{};
  final progressBox = Hive.box<ProgressRecord>(HiveBoxes.progress);
  for (final record in progressBox.values) {
    if (!record.isClassroomMode || !learnerIds.contains(record.learnerId)) {
      continue;
    }
    final game = castGameFor(record);
    if (game != null) recordsByGame.putIfAbsent(game, () => []).add(record);
  }

  return [
    for (final (type, icon) in games)
      _gameHealth(
        moduleId: _castGameModuleId(type),
        moduleName: castGameNames[type]!,
        icon: icon,
        records: recordsByGame[type] ?? const [],
        rosterSize: rosterSize,
        weekAgo: weekAgo,
        twoWeeksAgo: twoWeeksAgo,
      ),
  ];
}

ModuleHealth _gameHealth({
  required String moduleId,
  required String moduleName,
  required String icon,
  required List<ProgressRecord> records,
  required int rosterSize,
  required DateTime weekAgo,
  required DateTime twoWeeksAgo,
}) {
  if (records.isEmpty || rosterSize == 0) {
    return ModuleHealth(
      moduleId: moduleId,
      moduleName: moduleName,
      icon: icon,
      completionRate: 0,
      avgAccuracy: 0,
      avgErrors: 0,
      trend: null,
      healthIndex: 0,
      hasActivity: false,
    );
  }

  double avg(Iterable<num> xs) => xs.reduce((a, b) => a + b) / xs.length;

  final studentsUp = records.map((r) => r.learnerId).toSet().length;
  final completionRate = studentsUp / rosterSize;
  final avgAccuracy = avg(records.map((r) => r.strokeAccuracyPct));
  final avgErrors = avg(records.map((r) => r.sequencingErrors));

  final thisWeek = records.where((r) => r.completedAt.isAfter(weekAgo));
  final priorWeek = records.where(
    (r) =>
        r.completedAt.isAfter(twoWeeksAgo) && r.completedAt.isBefore(weekAgo),
  );
  final trend = thisWeek.isNotEmpty && priorWeek.isNotEmpty
      ? avg(thisWeek.map((r) => r.strokeAccuracyPct)) -
            avg(priorWeek.map((r) => r.strokeAccuracyPct))
      : null;

  final healthIndex =
      (0.4 * completionRate * 100 +
              0.4 * avgAccuracy +
              0.2 * (100 - avgErrors * 20).clamp(0, 100))
          .clamp(0, 100)
          .round();

  return ModuleHealth(
    moduleId: moduleId,
    moduleName: moduleName,
    icon: icon,
    completionRate: completionRate,
    avgAccuracy: avgAccuracy,
    avgErrors: avgErrors,
    trend: trend,
    healthIndex: healthIndex,
    hasActivity: true,
    attemptCount: records.length,
    studentsUp: studentsUp,
  );
}

/// Class Health Index (FR-6.2) for the given classId — backs
/// `_ClassHealthSection` on the Teacher Dashboard's Classroom tab.
final classHealthIndexProvider = Provider.family<List<ModuleHealth>, String>((
  ref,
  classId,
) {
  ref.watch(rosterRefreshProvider);
  ref.watch(progressChangesProvider);
  return computeClassHealthIndex(classId);
});
