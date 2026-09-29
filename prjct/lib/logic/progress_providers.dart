import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../data/local/hive_boxes.dart';
import '../data/models/progress_record.dart';
import '../data/remote/firestore_mirror.dart';
import '../data/repositories/class_repository.dart';
import '../data/repositories/progress_repository.dart';
import 'parent/children_providers.dart';
import 'teacher/teacher_providers.dart';

/// Emits on every write to the `ProgressBox` — a finished game, a Hot Seat
/// attempt, or records pulled from Firestore. Every Parent/Teacher
/// analytics provider watches this so it recomputes instead of serving
/// the numbers it cached before the learner played.
final progressChangesProvider = StreamProvider<BoxEvent>(
  (ref) => Hive.box<ProgressRecord>(HiveBoxes.progress).watch(),
);

Stream<void> _pullProgressLive(List<String> learnerIds) async* {
  final repo = ProgressRepository();
  await for (final records in FirestoreMirror().watchProgressForLearners(learnerIds)) {
    await repo.mergeRemote(records);
    yield null;
  }
}

/// Keeps the parent's children's progress pulled from Firestore in real
/// time — covers a child playing on a different device.
final parentProgressSyncProvider = StreamProvider.autoDispose<void>((ref) {
  final learnerIds = ref
      .watch(parentLearnersProvider)
      .map((l) => l.id)
      .whereType<String>()
      .toList();
  return _pullProgressLive(learnerIds);
});

/// Same as [parentProgressSyncProvider], for every learner enrolled in any
/// of the teacher's active classes.
final teacherProgressSyncProvider = StreamProvider.autoDispose<void>((ref) {
  ref.watch(rosterRefreshProvider);
  final classes = ClassRepository();
  final learnerIds = {
    for (final section in ref.watch(teacherClassesProvider))
      ...classes.byClassId(section.id).map((e) => e.learnerId),
  }.toList();
  return _pullProgressLive(learnerIds);
});
