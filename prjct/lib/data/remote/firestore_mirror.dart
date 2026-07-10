import 'package:cloud_firestore/cloud_firestore.dart';

import '../local/hive_boxes.dart';
import '../models/assigned_module.dart';
import '../models/class_section.dart';
import '../models/consent_record.dart';
import '../models/custom_lesson.dart';
import '../models/enrollment.dart';
import '../models/learner_profile.dart';
import '../models/parent_account.dart';
import '../models/progress_record.dart';
import '../models/teacher_account.dart';

/// Non-credential profile fields pulled down for
/// [FirestoreMirror.fetchParentByFirebaseUid] — deliberately excludes
/// anything PIN/password-shaped, matching what's actually mirrored (see
/// [FirestoreMirror]'s doc).
class RemoteParentRef {
  const RemoteParentRef({
    required this.id,
    required this.fullName,
    this.mobileNumber,
    this.firebaseUid,
  });

  final String id;
  final String fullName;
  final String? mobileNumber;
  final String? firebaseUid;
}

/// See [RemoteParentRef] doc.
class RemoteTeacherRef {
  const RemoteTeacherRef({
    required this.id,
    required this.fullName,
    this.school,
    this.mobileNumber,
    this.firebaseUid,
  });

  final String id;
  final String fullName;
  final String? school;
  final String? mobileNumber;
  final String? firebaseUid;
}

/// Non-credential fields pulled down for
/// [FirestoreMirror.fetchLearnersForParent] — excludes password hash/salt
/// the same way the account refs above exclude PIN/password fields; a
/// pulled-down learner has no local credentials until re-created on this
/// device.
class RemoteLearnerRef {
  const RemoteLearnerRef({
    required this.id,
    required this.name,
    required this.age,
    required this.avatar,
    required this.gradeLevel,
    this.username,
    this.createdAt,
  });

  final String id;
  final String name;
  final int age;
  final String avatar;
  final String gradeLevel;
  final String? username;
  final DateTime? createdAt;
}

/// Fields needed to recreate a [ClassSection] locally after a cross-device
/// invitation-code join (see [FirestoreMirror.fetchClassByInvitationCode]).
class RemoteClassRef {
  const RemoteClassRef({
    required this.id,
    required this.teacherId,
    required this.name,
    required this.invitationCode,
    this.gradeLevel,
    this.section,
    this.schedule,
    this.createdAt,
  });

  final String id;
  final String teacherId;
  final String name;
  final String invitationCode;
  final String? gradeLevel;
  final String? section;
  final String? schedule;
  final DateTime? createdAt;
}

/// Pushes Hive records to Firestore, one collection per box (same names as
/// [HiveBoxes] so the mapping is 1:1). Never mirrors [ParentAccount.pinHash]
/// /`passwordHash`/salts or the equivalent Teacher/Learner credential
/// fields — those stay local-only; Firebase Auth (via
/// [FirebaseAuthGateway]) is the credential story once online, not a
/// second copy of the local hash.
class FirestoreMirror {
  FirestoreMirror({FirebaseFirestore? firestore})
    : _firestoreOverride = firestore;

  final FirebaseFirestore? _firestoreOverride;

  /// Lazy on purpose — touching `FirebaseFirestore.instance` at
  /// construction time means every consumer of [SyncManager] (which builds
  /// one of these eagerly) blows up unless `Firebase.initializeApp()` has
  /// already run, including in widget tests that never call it. Only
  /// resolve the real instance when a push is actually attempted.
  FirebaseFirestore get _db => _firestoreOverride ?? FirebaseFirestore.instance;

  Future<void> pushParent(ParentAccount account) {
    return _db.collection(HiveBoxes.parents).doc(account.id).set({
      'fullName': account.fullName,
      'email': account.email,
      'mobileNumber': account.mobileNumber,
      'createdAt': account.createdAt.toIso8601String(),
      // Security rules (Phase 9) match this against request.auth.uid —
      // null if this account registered offline (see the registration
      // comment in ParentRepository.register).
      'firebaseUid': account.firebaseUid,
    });
  }

  Future<void> pushTeacher(TeacherAccount account) {
    return _db.collection(HiveBoxes.teachers).doc(account.id).set({
      'fullName': account.fullName,
      'school': account.school,
      'email': account.email,
      'firebaseUid': account.firebaseUid,
      'mobileNumber': account.mobileNumber,
      'createdAt': account.createdAt.toIso8601String(),
    });
  }

  Future<void> pushLearner(LearnerProfile learner) {
    if (learner.id == null) return Future.value();
    return _db.collection(HiveBoxes.learners).doc(learner.id).set({
      'parentId': learner.parentId,
      'name': learner.name,
      'age': learner.age,
      'avatar': learner.avatar,
      'gradeLevel': learner.gradeLevel,
      'username': learner.username,
      'createdAt': learner.createdAt?.toIso8601String(),
    });
  }

  Future<void> pushClass(ClassSection section) {
    return _db.collection(HiveBoxes.classes).doc(section.id).set({
      'teacherId': section.teacherId,
      'name': section.name,
      'invitationCode': section.invitationCode,
      'createdAt': section.createdAt.toIso8601String(),
      'schedule': section.schedule,
      'gradeLevel': section.gradeLevel,
      'section': section.section,
    });
  }

  /// FR-6.1 invitation-code join, cross-device — a parent's device only
  /// has the classes it's already seen locally (this app's "Hive is the
  /// only thing the UI reads" rule), so a class created on the *teacher's*
  /// device would never be found by `ClassRepository.findByInvitationCode`
  /// alone unless the two happen to share one Hive install. This is the
  /// fallback: query Firestore by the code itself (not by any relationship
  /// to the parent) — matching `firestore.rules`' `/classes` read rule,
  /// which is deliberately open to any signed-in account for exactly this
  /// reason, since the invitation code itself is the authorization token.
  Future<RemoteClassRef?> fetchClassByInvitationCode(String code) async {
    final snapshot = await _db
        .collection(HiveBoxes.classes)
        .where('invitationCode', isEqualTo: code)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    final doc = snapshot.docs.first;
    final data = doc.data();
    final createdAtRaw = data['createdAt'] as String?;
    return RemoteClassRef(
      id: doc.id,
      teacherId: data['teacherId'] as String? ?? '',
      name: data['name'] as String? ?? 'Class',
      invitationCode: data['invitationCode'] as String? ?? code,
      gradeLevel: data['gradeLevel'] as String?,
      section: data['section'] as String?,
      schedule: data['schedule'] as String?,
      createdAt: createdAtRaw == null ? null : DateTime.tryParse(createdAtRaw),
    );
  }

  Future<void> pushEnrollment(Enrollment enrollment) {
    final docId = '${enrollment.classId}_${enrollment.learnerId}';
    return _db.collection(HiveBoxes.enrollments).doc(docId).set({
      'classId': enrollment.classId,
      'learnerId': enrollment.learnerId,
      'enrolledAt': enrollment.enrolledAt.toIso8601String(),
    });
  }

  Future<void> pushProgress(ProgressRecord record) {
    return _db.collection(HiveBoxes.progress).doc(record.id).set({
      'learnerId': record.learnerId,
      'moduleId': record.moduleId,
      'strokeAccuracyPct': record.strokeAccuracyPct,
      'sequencingErrors': record.sequencingErrors,
      'timeOnTaskSeconds': record.timeOnTaskSeconds,
      'completedAt': record.completedAt.toIso8601String(),
      'assignedByTeacher': record.assignedByTeacher,
    });
  }

  Future<void> pushAssignedModule(AssignedModule assignment) {
    return _db.collection(HiveBoxes.assignedModules).doc(assignment.id).set({
      'classId': assignment.classId,
      'learnerId': assignment.learnerId,
      'moduleId': assignment.moduleId,
      'dueDate': assignment.dueDate.toIso8601String(),
      'assignedAt': assignment.assignedAt.toIso8601String(),
    });
  }

  Future<void> pushCustomLesson(CustomLesson lesson) {
    return _db.collection(HiveBoxes.customLessons).doc(lesson.id).set({
      'classId': lesson.classId,
      'teacherId': lesson.teacherId,
      'title': lesson.title,
      'instructions': lesson.instructions,
      'body': lesson.body,
      'createdAt': lesson.createdAt.toIso8601String(),
    });
  }

  Future<void> pushConsent(String key, ConsentRecord record) {
    return _db.collection(HiveBoxes.consents).doc(key).set({
      'agreedAt': record.agreedAt.toIso8601String(),
    });
  }

  /// FR-7.2 "sign in on any device" — looks up a parent's non-credential
  /// profile fields once [FirebaseAuthGateway.signIn] has already verified
  /// the password against Firebase Auth. Deliberately doesn't return
  /// anything PIN/password-shaped: none of that is mirrored (see this
  /// class's doc), so the caller must have the new device choose a fresh
  /// local PIN via the normal `/pin/setup` flow.
  ///
  /// Queries by [firebaseUid], not email — Firestore rejects a query
  /// outright (not just filters its results) unless it can statically
  /// prove every possible match satisfies the security rules; a
  /// `where('email', ...)` filter can't prove that (nothing ties `email`
  /// to `request.auth.uid` in the rule), so it's always denied even for
  /// the caller's own document. Querying by the exact `firebaseUid` we
  /// just authenticated as matches the rule's `resource.data.firebaseUid
  /// == request.auth.uid` condition directly, so Firestore can verify it.
  Future<RemoteParentRef?> fetchParentByFirebaseUid(String firebaseUid) async {
    final snapshot = await _db
        .collection(HiveBoxes.parents)
        .where('firebaseUid', isEqualTo: firebaseUid)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    final doc = snapshot.docs.first;
    final data = doc.data();
    return RemoteParentRef(
      id: doc.id,
      fullName: data['fullName'] as String? ?? 'Parent',
      mobileNumber: data['mobileNumber'] as String?,
      firebaseUid: data['firebaseUid'] as String?,
    );
  }

  /// See [fetchParentByFirebaseUid] doc.
  Future<RemoteTeacherRef?> fetchTeacherByFirebaseUid(
    String firebaseUid,
  ) async {
    final snapshot = await _db
        .collection(HiveBoxes.teachers)
        .where('firebaseUid', isEqualTo: firebaseUid)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    final doc = snapshot.docs.first;
    final data = doc.data();
    return RemoteTeacherRef(
      id: doc.id,
      fullName: data['fullName'] as String? ?? 'Asatidz',
      school: data['school'] as String?,
      mobileNumber: data['mobileNumber'] as String?,
      firebaseUid: data['firebaseUid'] as String?,
    );
  }

  /// FR-7.2 "sign in on any device" — pulls every child profile belonging
  /// to [parentId] down onto a new device, so the Parent Dashboard isn't
  /// empty after signing in somewhere new. Queries by `parentId` itself
  /// (not, say, joining through the parent doc) so the query filter
  /// matches the security rule directly — see the rule file's note on
  /// `/learners/{learnerId}` for why that matters.
  Future<List<RemoteLearnerRef>> fetchLearnersForParent(String parentId) async {
    final snapshot = await _db
        .collection(HiveBoxes.learners)
        .where('parentId', isEqualTo: parentId)
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      final createdAtRaw = data['createdAt'] as String?;
      return RemoteLearnerRef(
        id: doc.id,
        name: data['name'] as String? ?? 'Learner',
        age: data['age'] as int? ?? 5,
        avatar: data['avatar'] as String? ?? '🧒',
        gradeLevel: data['gradeLevel'] as String? ?? 'Grade 1',
        username: data['username'] as String?,
        createdAt: createdAtRaw == null
            ? null
            : DateTime.tryParse(createdAtRaw),
      );
    }).toList();
  }

  /// FR-7.3 "Right to be Forgotten" — deletes a single mirrored document.
  /// [collection] is one of the `HiveBoxes` constants; [docId] must match
  /// whatever id that collection's `push*` method used (the model's own
  /// `.id` for most, but `'${classId}_${learnerId}'` for enrollments and
  /// the raw consent key for consents — see each `push*` method above).
  Future<void> deleteDoc(String collection, String docId) {
    return _db.collection(collection).doc(docId).delete();
  }
}
