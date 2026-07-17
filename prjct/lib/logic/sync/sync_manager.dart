import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../auth/session.dart';
import '../parent/analytics_providers.dart';
import '../teacher/teacher_providers.dart';

import '../../data/local/hive_boxes.dart';
import '../../data/models/assigned_module.dart';
import '../../data/models/class_section.dart';
import '../../data/models/consent_record.dart';
import '../../data/models/custom_lesson.dart';
import '../../data/models/enrollment.dart';
import '../../data/models/learner_profile.dart';
import '../../data/models/parent_account.dart';
import '../../data/models/progress_record.dart';
import '../../data/models/teacher_account.dart';
import '../../data/remote/firestore_mirror.dart';
import '../../data/repositories/class_repository.dart';
import '../../data/repositories/consent_repository.dart';
import '../../data/repositories/custom_lesson_repository.dart';
import '../../data/repositories/learner_repository.dart';
import '../../data/repositories/parent_repository.dart';
import '../../data/repositories/progress_repository.dart';
import '../../data/repositories/teacher_repository.dart';

/// FR-7.2 — pushes every Hive box to Firestore, either on a manual "Sync
/// now" tap or automatically once Wi-Fi is detected (Diagrams Figure 2:
/// "Internet Connection Available? → Synchronize learner progress to the
/// cloud"). Hive stays the only thing the UI reads; this only ever writes
/// outward.
class SyncManager {
  SyncManager({Connectivity? connectivity, FirestoreMirror? mirror, dynamic ref})
    : _connectivity = connectivity ?? Connectivity(),
      _mirror = mirror ?? FirestoreMirror(),
      _ref = ref;

  final Connectivity _connectivity;
  final FirestoreMirror _mirror;
  final dynamic _ref;
  final _parents = ParentRepository();
  final _teachers = TeacherRepository();
  final _learners = LearnerRepository();
  final _classes = ClassRepository();
  final _progress = ProgressRepository();
  final _consents = ConsentRepository();
  final _customLessons = CustomLessonRepository();

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _syncing = false;

  void startWatching() {
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      if (results.isNotEmpty && !results.contains(ConnectivityResult.none)) {
        syncNow();
      }
    });
  }

  /// Pushes every box. Re-entrant calls while a sync is already running are
  /// ignored rather than queued — a second "Sync now" tap mid-sync is a
  /// no-op, not a stacked retry.
  ///
  /// Each collection's push is isolated — one collection throwing (a
  /// permission-denied on an account that isn't Firebase-linked yet, a
  /// network drop partway through) doesn't stop the rest from getting
  /// their own attempt. `lastSyncedAt` still only updates if every
  /// collection succeeded, and the first error (if any) is rethrown after
  /// all six have had their turn, so the UI's "Sync failed" message still
  /// reflects a real problem instead of silently swallowing it.
  Future<void> syncNow() async {
    if (_syncing) return;
    final connectivity = await _connectivity.checkConnectivity();
    if (connectivity.isEmpty || connectivity.contains(ConnectivityResult.none)) {
      throw Exception('No internet access, can\'t sync.');
    }
    _syncing = true;
    try {
      Object? firstError;
      Future<void> attempt(Future<void> Function() action) async {
        try {
          await action();
        } catch (e) {
          firstError ??= e;
        }
      }

      await attempt(() => _parents.pushAll(_mirror));
      await attempt(() => _teachers.pushAll(_mirror));
      await attempt(() => _learners.pushAll(_mirror));
      await attempt(() => _classes.pushAll(_mirror));
      await attempt(() => _progress.pushAll(_mirror));
      await attempt(() => _consents.pushAll(_mirror));
      await attempt(() => _customLessons.pushAll(_mirror));

      // Pull teacher-specific data (enrollments/learners) from Firestore if signed in as Asatidz
      final session = _ref?.read(sessionProvider);
      if (session != null && session.activeRole == UserRole.asatidz && session.activeTeacherId != null) {
        await attempt(() => _pullTeacherData(session.activeTeacherId!));
      }

      // Pull learner-specific assignments and progress if signed in as
      // Parent/Learner — progress covers the case where the learner played
      // on a different device than the one viewing the parent dashboard.
      if (session != null && session.learner != null) {
        await attempt(() => _pullLearnerAssignments(session.learner!.id));
        await attempt(() => _pullProgressForLearner(session.learner!.id));
        _ref?.read(parentProgressRefreshProvider.notifier).bump();
      }

      if (firstError != null) throw firstError!;

      await Hive.box<dynamic>(
        HiveBoxes.settings,
      ).put('lastSyncedAt', DateTime.now().toIso8601String());

      // Refresh the teacher roster UI
      _ref?.read(rosterRefreshProvider.notifier).bump();
    } finally {
      _syncing = false;
    }
  }

  Future<void> _pullTeacherData(String teacherId) async {
    try {
      final remoteClasses = await _mirror.fetchClassesForTeacher(teacherId);
      for (final remote in remoteClasses) {
        final local = _classes.findById(remote.id);
        if (local == null) {
          await _classes.saveFromRemote(remote);
        }
      }
    } catch (e) {
      debugPrint('SyncManager: pulling remote classes failed: $e');
    }

    final classes = _classes.byTeacherId(teacherId);
    for (final section in classes) {
      try {
        final remoteEnrollments = await _mirror.fetchEnrollmentsForClass(section.id);
        for (final remoteEnrollment in remoteEnrollments) {
          // Save enrollment locally
          await _classes.enroll(
            classId: remoteEnrollment.classId,
            learnerId: remoteEnrollment.learnerId,
          );
          // Pull learner profile if missing locally
          final localLearner = _learners.findById(remoteEnrollment.learnerId);
          if (localLearner == null) {
            final remoteLearner = await _mirror.fetchLearner(remoteEnrollment.learnerId);
            if (remoteLearner != null) {
              await _learners.saveFromRemote(
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
          }
          await _pullProgressForLearner(remoteEnrollment.learnerId);
        }
      } catch (e) {
        debugPrint('SyncManager: pulling teacher class ${section.id} data failed: $e');
      }
    }
  }

  /// Pulls [learnerId]'s progress records down from Firestore into the
  /// local Hive box — the read side of `_progress.pushAll` above. Existing
  /// local records win on id conflicts (a record already here was either
  /// written on this device or already pulled), so this only ever adds
  /// what's missing.
  Future<void> _pullProgressForLearner(String learnerId) async {
    try {
      final remoteRecords = await _mirror.fetchProgressForLearner(learnerId);
      final box = Hive.box<ProgressRecord>(HiveBoxes.progress);
      for (final record in remoteRecords) {
        if (!box.containsKey(record.id)) {
          await box.put(record.id, record);
        }
      }
    } catch (e) {
      debugPrint('SyncManager: pulling progress for $learnerId failed: $e');
    }
  }

  Future<void> _pullLearnerAssignments(String learnerId) async {
    try {
      final enrollments = _classes.byLearnerId(learnerId);
      final enrolledClassIds = enrollments.map((e) => e.classId).toSet();
      
      final assignmentsBox = Hive.box<AssignedModule>(HiveBoxes.assignedModules);

      for (final classId in enrolledClassIds) {
        // Fetch class-wide assignments from Firestore
        final remoteClassAssignments = await _mirror.fetchAssignmentsForClass(classId);
        // Fetch personal assignments from Firestore
        final remotePersonalAssignments = await _mirror.fetchAssignmentsForLearner(learnerId);

        // Delete local assignments for this class/learner that are not in remote to keep them in sync
        final localAssignments = assignmentsBox.values
            .where((a) => a.classId == classId && (a.learnerId == null || a.learnerId == learnerId))
            .toList();

        final remoteIds = [...remoteClassAssignments, ...remotePersonalAssignments].map((a) => a.id).toSet();

        for (final local in localAssignments) {
          if (!remoteIds.contains(local.id)) {
            await assignmentsBox.delete(local.id);
          }
        }

        // Save remote assignments locally
        for (final remote in [...remoteClassAssignments, ...remotePersonalAssignments]) {
          await assignmentsBox.put(remote.id, remote);
        }
      }
    } catch (e) {
      debugPrint('SyncManager: pulling learner assignments failed: $e');
    }
  }

  DateTime? get lastSyncedAt {
    final raw =
        Hive.box<dynamic>(HiveBoxes.settings).get('lastSyncedAt') as String?;
    return raw == null ? null : DateTime.tryParse(raw);
  }

  /// FR-7.3 "Right to be Forgotten" — deletes every mirrored Firestore
  /// document before the local Hive erase runs (`SessionNotifier.eraseAll`
  /// calls this first, since it needs the ids while they still exist
  /// locally). Best-effort per document: if offline, or a document was
  /// never actually synced, that single delete just fails silently and
  /// the rest still proceed — local erasure isn't allowed to be blocked
  /// by network availability, matching the rest of this app's FR-2.1
  /// offline-first stance. Anything that was never synced to Firestore in
  /// the first place has nothing there to delete anyway.
  Future<void> eraseRemoteData() async {
    Future<void> tryDelete(String collection, String docId) async {
      try {
        await _mirror.deleteDoc(collection, docId);
      } catch (_) {
        // Offline, never-synced, or already gone — nothing to do.
      }
    }

    for (final id in Hive.box<ParentAccount>(HiveBoxes.parents).keys) {
      await tryDelete(HiveBoxes.parents, id as String);
    }
    for (final id in Hive.box<TeacherAccount>(HiveBoxes.teachers).keys) {
      await tryDelete(HiveBoxes.teachers, id as String);
    }
    for (final id in Hive.box<LearnerProfile>(HiveBoxes.learners).keys) {
      await tryDelete(HiveBoxes.learners, id as String);
    }
    for (final id in Hive.box<ClassSection>(HiveBoxes.classes).keys) {
      await tryDelete(HiveBoxes.classes, id as String);
    }
    for (final e in Hive.box<Enrollment>(HiveBoxes.enrollments).values) {
      await tryDelete(HiveBoxes.enrollments, '${e.classId}_${e.learnerId}');
    }
    for (final id in Hive.box<ProgressRecord>(HiveBoxes.progress).keys) {
      await tryDelete(HiveBoxes.progress, id as String);
    }
    for (final id in Hive.box<AssignedModule>(HiveBoxes.assignedModules).keys) {
      await tryDelete(HiveBoxes.assignedModules, id as String);
    }
    for (final id in Hive.box<CustomLesson>(HiveBoxes.customLessons).keys) {
      await tryDelete(HiveBoxes.customLessons, id as String);
    }
    for (final id in Hive.box<ConsentRecord>(HiveBoxes.consents).keys) {
      await tryDelete(HiveBoxes.consents, id as String);
    }
  }

  void dispose() => _subscription?.cancel();
}

final syncManagerProvider = Provider<SyncManager>((ref) {
  final manager = SyncManager(ref: ref);
  manager.startWatching();
  ref.onDispose(manager.dispose);
  return manager;
});
