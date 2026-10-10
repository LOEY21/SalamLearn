import 'dart:math';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../local/hive_boxes.dart';
import '../models/assigned_module.dart';
import '../models/class_section.dart';
import '../models/enrollment.dart';
import '../remote/firestore_mirror.dart' show FirestoreMirror, RemoteClassRef;
import 'custom_lesson_repository.dart';
import 'teacher_repository.dart';

/// Hive-backed CRUD for [ClassSection], its [Enrollment] rows, and its
/// [AssignedModule] take-home assignments (FR-6.1, FR-6.3; Diagrams Figure
/// 4 "Create Class"/"Generate Invitation Code"/"Enroll Students"/"Assign
/// Learning Modules"). Enrollment and assignments live in this repository
/// rather than separate ones — both are thin, class-scoped join tables
/// with no independent lifecycle of their own.
class ClassRepository {
  Box<ClassSection> get _classes => Hive.box<ClassSection>(HiveBoxes.classes);
  Box<Enrollment> get _enrollments =>
      Hive.box<Enrollment>(HiveBoxes.enrollments);
  Box<AssignedModule> get _assignments =>
      Hive.box<AssignedModule>(HiveBoxes.assignedModules);

  static const _codeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no 0/O/1/I

  String _generateUniqueCode() {
    final random = Random.secure();
    while (true) {
      final code = List.generate(
        6,
        (_) => _codeChars[random.nextInt(_codeChars.length)],
      ).join();
      if (findByInvitationCode(code) == null) return code;
    }
  }

  Future<ClassSection> create({
    required String teacherId,
    required String gradeLevel,
    required String section,
    String? schedule,
  }) async {
    final created = ClassSection(
      id: const Uuid().v4(),
      teacherId: teacherId,
      name: '$gradeLevel - Section $section',
      invitationCode: _generateUniqueCode(),
      createdAt: DateTime.now(),
      gradeLevel: gradeLevel,
      section: section,
      schedule: schedule,
    );
    await _classes.put(created.id, created);
    // Best-effort — a parent's invitation-code join and every enrollment
    // write need the class in Firestore; offline falls back to sync.
    try {
      await FirestoreMirror().pushClass(created);
    } catch (e) {
      debugPrint('ClassRepository.create: push failed: $e');
    }
    return created;
  }

  /// Archives a class at the end of a school year (FR-6.1's retirement
  /// path, short of the hard [deleteClass]) — roster, assignments, and
  /// lesson folders all stay intact, but the class drops out of active
  /// pickers (casting, homework, [findByInvitationCode] joins) via
  /// [ClassSection.isArchived].
  Future<ClassSection> archiveClass(String classId) async {
    final section = _classes.get(classId);
    if (section == null) throw StateError('Class $classId not found');
    final updated = ClassSection(
      id: section.id,
      teacherId: section.teacherId,
      name: section.name,
      invitationCode: section.invitationCode,
      createdAt: section.createdAt,
      gradeLevel: section.gradeLevel,
      section: section.section,
      schedule: section.schedule,
      archivedAt: DateTime.now(),
    );
    await _classes.put(updated.id, updated);
    try {
      await FirestoreMirror().pushClass(updated);
    } catch (_) {
      // Best-effort — offline devices just keep the local archive.
    }
    return updated;
  }

  /// Reverses [archiveClass] — the class becomes eligible for
  /// [activeByTeacherId]/casting/homework/new enrollments again.
  Future<ClassSection> unarchiveClass(String classId) async {
    final section = _classes.get(classId);
    if (section == null) throw StateError('Class $classId not found');
    final updated = ClassSection(
      id: section.id,
      teacherId: section.teacherId,
      name: section.name,
      invitationCode: section.invitationCode,
      createdAt: section.createdAt,
      gradeLevel: section.gradeLevel,
      section: section.section,
      schedule: section.schedule,
      archivedAt: null,
    );
    await _classes.put(updated.id, updated);
    try {
      await FirestoreMirror().pushClass(updated);
    } catch (_) {
      // Best-effort — offline devices just keep the local unarchive.
    }
    return updated;
  }

  /// FR-6.1 invitation-code join, cross-device — mirrors
  /// `LearnerRepository.saveFromRemote`'s pattern exactly: reuses the
  /// cloud doc's id (so this device's later syncs update the same
  /// Firestore document rather than creating a duplicate class) and just
  /// writes it straight into this device's own `classes` box, same as if
  /// the teacher had created it here.
  Future<ClassSection> saveFromRemote(RemoteClassRef remote) async {
    final section = ClassSection(
      id: remote.id,
      teacherId: remote.teacherId,
      name: remote.name,
      invitationCode: remote.invitationCode,
      createdAt: remote.createdAt ?? DateTime.now(),
      gradeLevel: remote.gradeLevel,
      section: remote.section,
      schedule: remote.schedule,
      archivedAt: remote.archivedAt,
    );
    await _classes.put(section.id, section);
    return section;
  }

  ClassSection? findById(String id) => _classes.get(id);

  /// Skips archived classes — an old invitation code silently stops
  /// resolving once the teacher archives the class (FR-6.1's "school year
  /// ended" retirement, see [archiveClass]).
  ClassSection? findByInvitationCode(String code) {
    for (final section in _classes.values) {
      if (section.invitationCode == code && !section.isArchived) {
        return section;
      }
    }
    return null;
  }

  /// Every class the teacher owns, active or archived — the raw data
  /// primitive used by sync and the Archived Classes screen. UI pickers
  /// (My Classes list, class switcher, active-class auto-select) should use
  /// [activeByTeacherId] instead so an archived class never becomes the
  /// current one.
  List<ClassSection> byTeacherId(String teacherId) =>
      _classes.values.where((c) => c.teacherId == teacherId).toList();

  List<ClassSection> activeByTeacherId(String teacherId) =>
      byTeacherId(teacherId).where((c) => !c.isArchived).toList();

  List<ClassSection> archivedByTeacherId(String teacherId) =>
      byTeacherId(teacherId).where((c) => c.isArchived).toList();

  /// Deletes a class the teacher created, along with its enrollments,
  /// assignments, and custom lessons — both the local Hive records and
  /// their mirrored Firestore docs (best-effort, same "delete remote
  /// before local, swallow failure" contract as
  /// `SessionNotifier.deleteLearner`; offline devices just skip the
  /// remote half and stay locally deleted).
  ///
  /// Children go first: `firestore.rules` authorizes enrollment/assignment
  /// deletes by looking up the class doc, so deleting the class first made
  /// every later delete fail — students stayed enrolled online. Each delete
  /// is its own best-effort attempt. If the class doc itself can't be
  /// deleted (offline, wrong session), its id is kept in
  /// [pendingClassDeletes] so sync neither pulls it back nor forgets to
  /// retry ([retryPendingClassDeletes]).
  Future<void> deleteClass(String classId) async {
    final enrollments = byClassId(classId);
    final assignments = _assignments.values
        .where((a) => a.classId == classId)
        .toList();
    final lessons = CustomLessonRepository().byClassId(classId);

    await _addPendingClassDelete(classId);
    await _deleteClassRemote(
      classId,
      learnerIds: enrollments.map((e) => e.learnerId),
      assignmentIds: assignments.map((a) => a.id),
      lessonIds: lessons.map((l) => l.id),
    );

    await _classes.delete(classId);
    for (final enrollment in enrollments) {
      await _enrollments.delete('$classId:${enrollment.learnerId}');
    }
    for (final assignment in assignments) {
      await _assignments.delete(assignment.id);
    }
    for (final lesson in lessons) {
      await CustomLessonRepository().delete(lesson.id);
    }
  }

  Box<dynamic> get _settings => Hive.box<dynamic>(HiveBoxes.settings);

  /// Classes deleted on this device whose Firestore doc may still exist.
  Set<String> get pendingClassDeletes =>
      ((_settings.get('pendingClassDeletes') as List?) ?? const [])
          .cast<String>()
          .toSet();

  Future<void> _addPendingClassDelete(String classId) =>
      _settings.put('pendingClassDeletes', [...pendingClassDeletes, classId]);

  /// Deletes the class's remote children, then the class doc. Clears the
  /// pending marker only once the class doc is confirmed gone.
  Future<void> _deleteClassRemote(
    String classId, {
    Iterable<String> learnerIds = const [],
    Iterable<String> assignmentIds = const [],
    Iterable<String> lessonIds = const [],
  }) async {
    final mirror = FirestoreMirror();
    Future<bool> attempt(String collection, String id) async {
      try {
        await mirror.deleteDoc(collection, id);
        return true;
      } catch (e) {
        debugPrint('ClassRepository.deleteClass: $collection/$id failed: $e');
        return false;
      }
    }

    for (final learnerId in learnerIds) {
      await attempt(HiveBoxes.enrollments, '${classId}_$learnerId');
    }
    for (final id in assignmentIds) {
      await attempt(HiveBoxes.assignedModules, id);
    }
    for (final id in lessonIds) {
      await attempt(HiveBoxes.customLessons, id);
    }
    if (await attempt(HiveBoxes.classes, classId)) {
      await _settings.put(
        'pendingClassDeletes',
        (pendingClassDeletes..remove(classId)).toList(),
      );
    }
  }

  /// Called by sync: finishes class deletes that failed earlier. Local
  /// copies are already gone, so remote enrollments are looked up first.
  Future<void> retryPendingClassDeletes() async {
    for (final classId in pendingClassDeletes) {
      // Already gone online (e.g. removed by the admin) — a second delete
      // would be refused by the rules, so just drop the marker.
      if (!await FirestoreMirror().docExists(HiveBoxes.classes, classId)) {
        await _settings.put(
          'pendingClassDeletes',
          (pendingClassDeletes..remove(classId)).toList(),
        );
        continue;
      }
      var learnerIds = const <String>[];
      var assignmentIds = const <String>[];
      try {
        final mirror = FirestoreMirror();
        learnerIds = (await mirror.fetchEnrollmentsForClass(
          classId,
        )).map((e) => e.learnerId).toList();
        assignmentIds = (await mirror.fetchAssignmentsForClass(
          classId,
        )).map((a) => a.id).toList();
      } catch (_) {
        // Offline — the class-doc attempt below fails too and stays pending.
      }
      await _deleteClassRemote(
        classId,
        learnerIds: learnerIds,
        assignmentIds: assignmentIds,
      );
    }
  }

  Future<Enrollment> enroll({
    required String classId,
    required String learnerId,
  }) async {
    final key = '$classId:$learnerId';
    final existing = _enrollments.get(key);
    if (existing != null) return existing;
    final enrollment = Enrollment(
      classId: classId,
      learnerId: learnerId,
      enrolledAt: DateTime.now(),
    );
    await _enrollments.put(key, enrollment);
    return enrollment;
  }

  Future<void> unenroll({
    required String classId,
    required String learnerId,
  }) async {
    final localKey = '$classId:$learnerId';
    final remoteDocId = '${classId}_${learnerId}';

    // Best-effort remote deletion
    try {
      final mirror = FirestoreMirror();
      await mirror.deleteDoc(HiveBoxes.enrollments, remoteDocId);
    } catch (_) {
      // Best-effort
    }

    await _enrollments.delete(localKey);

    // Also delete any assignments for this specific learner in this class
    final assignments = _assignments.values
        .where((a) => a.classId == classId && a.learnerId == learnerId)
        .toList();
    for (final assignment in assignments) {
      try {
        await FirestoreMirror().deleteDoc(
          HiveBoxes.assignedModules,
          assignment.id,
        );
      } catch (_) {}
      await _assignments.delete(assignment.id);
    }
  }

  bool isEnrolled({required String classId, required String learnerId}) =>
      _enrollments.containsKey('$classId:$learnerId');

  List<Enrollment> byClassId(String classId) =>
      _enrollments.values.where((e) => e.classId == classId).toList();

  List<Enrollment> byLearnerId(String learnerId) =>
      _enrollments.values.where((e) => e.learnerId == learnerId).toList();

  /// FR-6.3 — assigns a module to either one learner ([learnerId] set) or
  /// the whole class ([learnerId] null).
  Future<AssignedModule> assignModule({
    required String classId,
    required String moduleId,
    DateTime? dueDate,
    String? learnerId,
    int maxLevel = 3,
    int? maxLessons,
  }) async {
    final assignment = AssignedModule(
      id: const Uuid().v4(),
      classId: classId,
      learnerId: learnerId,
      moduleId: moduleId,
      dueDate: dueDate ?? noDueDate,
      assignedAt: DateTime.now(),
      maxLevel: maxLevel,
      maxLessons: maxLessons,
    );
    await _assignments.put(assignment.id, assignment);
    // Best-effort — uploads right away so the learner's device can pull it
    // without waiting for the teacher to tap Sync; the next full sync
    // retries if this fails (e.g. offline).
    try {
      await FirestoreMirror().pushAssignedModule(assignment);
    } catch (e) {
      debugPrint('ClassRepository.assignModule: push failed: $e');
    }
    return assignment;
  }

  /// Updates an existing take-home module assignment (module, level cap).
  Future<AssignedModule?> updateAssignment({
    required String id,
    required String moduleId,
    DateTime? dueDate,
    int? maxLevel,
    int? maxLessons,
  }) async {
    final existing = _assignments.get(id);
    if (existing == null) return null;
    final updated = AssignedModule(
      id: existing.id,
      classId: existing.classId,
      learnerId: existing.learnerId,
      moduleId: moduleId,
      dueDate: dueDate ?? existing.dueDate,
      assignedAt: existing.assignedAt,
      maxLevel: maxLevel ?? existing.maxLevel,
      maxLessons: maxLessons ?? existing.maxLessons,
    );
    await _assignments.put(updated.id, updated);
    try {
      await FirestoreMirror().pushAssignedModule(updated);
    } catch (e) {
      debugPrint('ClassRepository.updateAssignment: push failed: $e');
    }
    return updated;
  }

  /// Deletes a take-home module assignment from both local Hive and remote Firestore.
  Future<void> deleteAssignment(String assignmentId) async {
    try {
      await FirestoreMirror().deleteDoc(
        HiveBoxes.assignedModules,
        assignmentId,
      );
    } catch (_) {}
    await _assignments.delete(assignmentId);
  }

  /// Enrolls a learner and uploads the enrollment right away. Firestore is
  /// the source of truth for rosters — the live enrollment listeners on
  /// both the teacher and parent side delete any local enrollment that
  /// isn't there, so a local-only enrollment silently disappears (and
  /// takes the learner's homework with it).
  ///
  /// The class is pushed first: [create] is local-only, and
  /// `firestore.rules` checks enrollment writes against the class doc, so
  /// an enroll into a not-yet-synced class was being rejected. On failure
  /// the local enrollment is rolled back and the error rethrown, so the
  /// teacher sees it instead of a fake success that vanishes on restart.
  Future<void> enrollAndPush({
    required String classId,
    required String learnerId,
  }) async {
    final enrollment = await enroll(classId: classId, learnerId: learnerId);
    final mirror = FirestoreMirror();
    try {
      final section = _classes.get(classId);
      if (section != null) await mirror.pushClass(section);
      await mirror.pushEnrollment(enrollment);
    } catch (e) {
      debugPrint('ClassRepository.enrollAndPush: push failed: $e');
      await _enrollments.delete('$classId:$learnerId');
      rethrow;
    }
  }

  /// Assignments for a class, optionally filtered to one learner (pass
  /// `learnerId: null` explicitly to get only whole-class assignments).
  List<AssignedModule> assignmentsFor({
    required String classId,
    String? learnerId,
  }) {
    return _assignments.values
        .where((a) => a.classId == classId && a.learnerId == learnerId)
        .toList();
  }

  /// Pushes every locally-stored class, enrollment, and assignment to
  /// Firestore (FR-7.2 sync).
  ///
  /// Skips a class whose owning teacher isn't Firebase-linked yet
  /// (`firebaseUid == null`) — same "nothing to push for this account yet"
  /// guard `ParentRepository.pushAll`/`TeacherRepository.pushAll` already
  /// use, just applied here too. `firestore.rules`' `ownsTeacherDoc` check
  /// would reject the write anyway since there's no matching Firestore
  /// teacher doc to compare against, but *unconditionally* attempting it
  /// (the previous behavior) turned an expected "not linked yet" state
  /// into a `permission-denied` that `SyncManager.syncNow` surfaces as
  /// "Sync failed" — masking whatever the *first* real error was, since
  /// only one error is reported per sync pass.
  Future<void> pushAll(FirestoreMirror mirror) async {
    final teachers = TeacherRepository();
    for (final section in _classes.values) {
      if (teachers.findById(section.teacherId)?.firebaseUid == null) continue;
      await mirror.pushClass(section);
    }
    for (final enrollment in _enrollments.values) {
      await mirror.pushEnrollment(enrollment);
    }
    for (final assignment in _assignments.values) {
      await mirror.pushAssignedModule(assignment);
    }
  }
}
