import 'dart:math';

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
  Future<void> deleteClass(String classId) async {
    final enrollments = byClassId(classId);
    final assignments = _assignments.values
        .where((a) => a.classId == classId)
        .toList();
    final lessons = CustomLessonRepository().byClassId(classId);
    final mirror = FirestoreMirror();

    try {
      await mirror.deleteDoc(HiveBoxes.classes, classId);
      for (final enrollment in enrollments) {
        await mirror.deleteDoc(
          HiveBoxes.enrollments,
          '${classId}_${enrollment.learnerId}',
        );
      }
      for (final assignment in assignments) {
        await mirror.deleteDoc(HiveBoxes.assignedModules, assignment.id);
      }
      for (final lesson in lessons) {
        await mirror.deleteDoc(HiveBoxes.customLessons, lesson.id);
      }
    } catch (_) {
      // Offline, never-synced, or already gone — matching
      // deleteLearner's own best-effort remote-delete contract.
    }

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
    final assignments = _assignments.values.where(
      (a) => a.classId == classId && a.learnerId == learnerId,
    ).toList();
    for (final assignment in assignments) {
      try {
        await FirestoreMirror().deleteDoc(HiveBoxes.assignedModules, assignment.id);
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
    required DateTime dueDate,
    String? learnerId,
    int maxLevel = 3,
    int? maxLessons,
  }) async {
    final assignment = AssignedModule(
      id: const Uuid().v4(),
      classId: classId,
      learnerId: learnerId,
      moduleId: moduleId,
      dueDate: dueDate,
      assignedAt: DateTime.now(),
      maxLevel: maxLevel,
      maxLessons: maxLessons,
    );
    await _assignments.put(assignment.id, assignment);
    return assignment;
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
