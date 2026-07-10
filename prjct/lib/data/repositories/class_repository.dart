import 'dart:math';

import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../local/hive_boxes.dart';
import '../models/assigned_module.dart';
import '../models/class_section.dart';
import '../models/enrollment.dart';
import '../remote/firestore_mirror.dart';

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

  Future<ClassSection> regenerateInvitationCode(ClassSection section) async {
    final updated = ClassSection(
      id: section.id,
      teacherId: section.teacherId,
      name: section.name,
      invitationCode: _generateUniqueCode(),
      createdAt: section.createdAt,
      gradeLevel: section.gradeLevel,
      section: section.section,
      schedule: section.schedule,
    );
    await _classes.put(updated.id, updated);
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
    );
    await _classes.put(section.id, section);
    return section;
  }

  ClassSection? findById(String id) => _classes.get(id);

  ClassSection? findByInvitationCode(String code) {
    for (final section in _classes.values) {
      if (section.invitationCode == code) return section;
    }
    return null;
  }

  List<ClassSection> byTeacherId(String teacherId) =>
      _classes.values.where((c) => c.teacherId == teacherId).toList();

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
  }) async {
    final assignment = AssignedModule(
      id: const Uuid().v4(),
      classId: classId,
      learnerId: learnerId,
      moduleId: moduleId,
      dueDate: dueDate,
      assignedAt: DateTime.now(),
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
  Future<void> pushAll(FirestoreMirror mirror) async {
    for (final section in _classes.values) {
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
