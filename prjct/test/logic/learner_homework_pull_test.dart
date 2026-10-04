import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/data/models/assigned_module.dart';
import 'package:salamlearn/data/models/enrollment.dart';
import 'package:salamlearn/data/remote/firestore_mirror.dart';
import 'package:salamlearn/data/repositories/class_repository.dart';
import 'package:salamlearn/logic/sync/sync_manager.dart';

import '../test_helpers/hive_test_setup.dart';

/// Firestore as the learner's device sees it: enrolled in one class (only
/// recorded remotely, e.g. the teacher enrolled them from their own phone)
/// with one personal assignment there.
class _FakeMirror extends FirestoreMirror {
  final assignment = AssignedModule(
    id: 'a1',
    classId: 'c1',
    learnerId: 'L1',
    moduleId: 'dest1-s2',
    dueDate: DateTime(2026, 10, 4),
    assignedAt: DateTime(2026, 10, 2),
  );

  @override
  Future<List<Enrollment>> fetchEnrollmentsForLearner(String learnerId) async =>
      [Enrollment(classId: 'c1', learnerId: learnerId, enrolledAt: DateTime(2026))];

  @override
  Future<List<AssignedModule>> fetchAssignmentsForClass(String classId) async =>
      [];

  @override
  Future<List<AssignedModule>> fetchAssignmentsForLearner(
    String learnerId,
  ) async => [assignment];
}

void main() {
  late Directory dir;
  setUp(() async => dir = await setUpTestHive());
  tearDown(() async => tearDownTestHive(dir));

  test('pulls a remote-only enrollment and its homework to the hub', () async {
    final repo = ClassRepository();
    expect(repo.byLearnerId('L1'), isEmpty);

    await SyncManager(mirror: _FakeMirror()).pullLearnerHomework('L1');

    expect(repo.byLearnerId('L1').map((e) => e.classId), ['c1']);
    expect(
      repo.assignmentsFor(classId: 'c1', learnerId: 'L1').map((a) => a.id),
      ['a1'],
    );
  });
}
