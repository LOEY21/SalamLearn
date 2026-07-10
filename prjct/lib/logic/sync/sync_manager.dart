import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

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
  SyncManager({Connectivity? connectivity, FirestoreMirror? mirror})
    : _connectivity = connectivity ?? Connectivity(),
      _mirror = mirror ?? FirestoreMirror();

  final Connectivity _connectivity;
  final FirestoreMirror _mirror;
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
    _syncing = true;
    try {
      Object? firstError;
      Future<void> attempt(Future<void> Function() push) async {
        try {
          await push();
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

      if (firstError != null) throw firstError!;

      await Hive.box<dynamic>(
        HiveBoxes.settings,
      ).put('lastSyncedAt', DateTime.now().toIso8601String());
    } finally {
      _syncing = false;
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
  final manager = SyncManager();
  manager.startWatching();
  ref.onDispose(manager.dispose);
  return manager;
});
