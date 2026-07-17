import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../data/models/class_section.dart';
import '../../data/models/enrollment.dart';
import '../../data/models/learner_profile.dart';
import '../../data/repositories/class_repository.dart';
import '../../data/repositories/learner_repository.dart';
import '../../data/remote/firestore_mirror.dart';
import '../../data/local/hive_boxes.dart';
import '../auth/session.dart';

/// Every learner the active parent has created (FR-2.3) — a parent isn't
/// limited to one child. The Manage Profile tab's child switcher reads
/// this to let the parent pick which child's dashboard (KPIs, streak,
/// suggestions — all already scoped by learner id since Phase 8) is
/// currently showing.
final parentLearnersProvider = Provider<List<LearnerProfile>>((ref) {
  final parentId = ref.watch(sessionProvider.select((s) => s.activeParentId));
  // `LearnerRepository().byParentId(...)` reads straight out of Hive, which
  // Riverpod has no way to observe on its own — without watching something
  // that actually changes when the roster does, this provider would cache
  // its first result forever (a real bug: adding a 2nd/3rd child never
  // changed activeParentId, so the newly-created sibling silently never
  // showed up anywhere reading this provider). Watching the active
  // learner's id forces a recompute on every create/switch/edit, which
  // covers every path that currently mutates the roster. Also watches
  // `learnerSyncProvider` so remote deletions (admin web panel) trigger a
  // re-read from Hive regardless of which learner was removed.
  ref.watch(sessionProvider.select((s) => s.learner?.id));
  ref.watch(learnerSyncProvider);
  if (parentId == null) return const [];
  return LearnerRepository().byParentId(parentId);
});

/// Bumped by [refreshLearnerClass] after a successful class-code join —
/// see [parentLearnersProvider]'s doc for why a manual "something changed"
/// signal is needed at all: `ClassRepository`'s Hive reads aren't natively
/// observable, and unlike the roster above, joining a class doesn't touch
/// `sessionProvider` at all, so nothing else would trigger a recompute.
class _ClassRefreshTick extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final _classRefreshProvider = NotifierProvider<_ClassRefreshTick, int>(_ClassRefreshTick.new);

/// The class a specific learner is currently enrolled in (Manage Profile
/// tab's "Class" section, FR-6.1's invitation-code join) — `null` if not
/// enrolled in any class yet. Takes the first match if a learner somehow
/// ended up in more than one (the data model doesn't enforce exclusivity,
/// but the join UI only ever adds one at a time in the common case).
final learnerClassProvider = Provider.family<ClassSection?, String>((ref, learnerId) {
  ref.watch(_classRefreshProvider);
  final enrollments = ClassRepository().byLearnerId(learnerId);
  if (enrollments.isEmpty) return null;
  return ClassRepository().findById(enrollments.first.classId);
});

/// Call after successfully joining a class via invitation code, so every
/// widget reading [learnerClassProvider] recomputes.
void refreshLearnerClass(WidgetRef ref) => ref.read(_classRefreshProvider.notifier).bump();

/// Listens to Firestore enrollment changes for the parent's learners and
/// syncs to Hive in real time. Bumps [_classRefreshProvider] on every change
/// so the parent dashboard reflects admin-web enroll/unenroll immediately.
final parentEnrollmentSyncProvider = StreamProvider.autoDispose<void>((ref) async* {
  final learners = ref.watch(parentLearnersProvider);
  final learnerIds = learners.map((l) => l.id).whereType<String>().toList();
  if (learnerIds.isEmpty) return;

  final enrollmentsBox = Hive.box<Enrollment>(HiveBoxes.enrollments);
  await for (final remoteIds in FirestoreMirror().watchEnrollmentsForLearners(learnerIds)) {
    final local = enrollmentsBox.values
        .where((e) => learnerIds.contains(e.learnerId))
        .map((e) => '${e.classId}_${e.learnerId}')
        .toSet();

    final added = remoteIds.difference(local);
    final removed = local.difference(remoteIds);

    for (final docId in added) {
      final parts = docId.split('_');
      if (parts.length < 2) continue;
      final classId = parts.sublist(0, parts.length - 1).join('_');
      final learnerId = parts.last;
      final key = '$classId:$learnerId';
      if (enrollmentsBox.get(key) != null) continue;
      await enrollmentsBox.put(
        key,
        Enrollment(classId: classId, learnerId: learnerId, enrolledAt: DateTime.now()),
      );
    }

    for (final docId in removed) {
      final parts = docId.split('_');
      if (parts.length < 2) continue;
      final classId = parts.sublist(0, parts.length - 1).join('_');
      final learnerId = parts.last;
      await enrollmentsBox.delete('$classId:$learnerId');
    }

    if (added.isNotEmpty || removed.isNotEmpty) {
      ref.read(_classRefreshProvider.notifier).bump();
    }

    yield null;
  }
});
