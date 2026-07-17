import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/data/repositories/class_repository.dart';

import '../../test_helpers/hive_test_setup.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await setUpTestHive();
  });

  tearDown(() async {
    await tearDownTestHive(tempDir);
  });

  group('ClassRepository archiving', () {
    test('archiveClass sets isArchived and unarchiveClass reverses it', () async {
      final repo = ClassRepository();
      final section = await repo.create(
        teacherId: 'teacher-1',
        gradeLevel: 'Grade 1',
        section: 'A',
      );
      expect(section.isArchived, isFalse);

      final archived = await repo.archiveClass(section.id);
      expect(archived.isArchived, isTrue);
      expect(archived.archivedAt, isNotNull);
      expect(repo.findById(section.id)!.isArchived, isTrue);

      final unarchived = await repo.unarchiveClass(section.id);
      expect(unarchived.isArchived, isFalse);
      expect(unarchived.archivedAt, isNull);
    });

    test('activeByTeacherId excludes archived, archivedByTeacherId includes only archived', () async {
      final repo = ClassRepository();
      final active = await repo.create(
        teacherId: 'teacher-1',
        gradeLevel: 'Grade 1',
        section: 'A',
      );
      final toArchive = await repo.create(
        teacherId: 'teacher-1',
        gradeLevel: 'Grade 2',
        section: 'B',
      );
      await repo.archiveClass(toArchive.id);

      final activeList = repo.activeByTeacherId('teacher-1');
      expect(activeList.map((c) => c.id), [active.id]);

      final archivedList = repo.archivedByTeacherId('teacher-1');
      expect(archivedList.map((c) => c.id), [toArchive.id]);

      // byTeacherId stays unfiltered — the raw data-access primitive.
      expect(repo.byTeacherId('teacher-1').length, 2);
    });

    test('findByInvitationCode skips an archived class', () async {
      final repo = ClassRepository();
      final section = await repo.create(
        teacherId: 'teacher-1',
        gradeLevel: 'Grade 1',
        section: 'A',
      );
      expect(repo.findByInvitationCode(section.invitationCode)?.id, section.id);

      await repo.archiveClass(section.id);
      expect(repo.findByInvitationCode(section.invitationCode), isNull);

      await repo.unarchiveClass(section.id);
      expect(repo.findByInvitationCode(section.invitationCode)?.id, section.id);
    });
  });
}
