import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:salamlearn/data/local/hive_boxes.dart';
import 'package:salamlearn/data/models/badge_award.dart';
import 'package:salamlearn/data/models/progress_record.dart';
import 'package:salamlearn/data/models/streak_state.dart';
import 'package:salamlearn/data/repositories/class_repository.dart';
import 'package:salamlearn/data/repositories/learner_repository.dart';
import 'package:salamlearn/data/repositories/progress_repository.dart';
import 'package:salamlearn/data/repositories/teacher_repository.dart';
import 'package:salamlearn/logic/auth/session.dart';

import '../test_helpers/hive_test_setup.dart';

/// Logic-level checks behind rows of the Functionality Test sheet
/// (SL-ONB / AUTH / PIN / TEA / LRN / RWD / OFF). These exercise the
/// session, repositories and Hive directly — no screens, no network — so
/// they prove the logic, not the UI; a device test is still needed for taps.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await setUpTestHive();
  });

  tearDown(() async {
    await tearDownTestHive(tempDir);
  });

  ProviderContainer newContainer() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  Future<SessionNotifier> registeredParent(ProviderContainer c) async {
    final n = c.read(sessionProvider.notifier);
    n.setLanguage('en');
    await n.giveConsent();
    n.stageParentRegistration(
      fullName: 'Parent One',
      email: 'parent@example.com',
      password: 'Password123',
    );
    await n.createPin('1234');
    return n;
  }

  group('Onboarding and auth', () {
    test('ONB-03/04: language and consent survive an app restart', () async {
      final first = newContainer();
      expect(first.read(sessionProvider).onboarded, isFalse);
      expect(first.read(sessionProvider).consented, isFalse);

      final n = first.read(sessionProvider.notifier);
      n.setLanguage('en');
      await n.giveConsent();

      final afterRestart = newContainer().read(sessionProvider);
      expect(afterRestart.onboarded, isTrue);
      expect(afterRestart.consented, isTrue);
    });

    test('AUTH-04: an already-registered email is reported as taken', () async {
      final c = newContainer();
      final n = await registeredParent(c);

      expect(
        n.emailTaken(role: UserRole.parent, email: 'parent@example.com'),
        isTrue,
      );
      expect(
        n.emailTaken(role: UserRole.parent, email: 'PARENT@example.com'),
        isTrue,
        reason: 'email match is case-insensitive',
      );
      expect(
        n.emailTaken(role: UserRole.parent, email: 'new@example.com'),
        isFalse,
      );
    });

    test('PIN-01/02: right PIN unlocks, wrong PIN keeps the gate closed', () async {
      final c = newContainer();
      final n = await registeredParent(c);
      n.selectRole(UserRole.parent); // resets pinVerified

      expect(n.verifyPin('0000'), isFalse);
      expect(c.read(sessionProvider).pinVerified, isFalse);

      expect(n.verifyPin('1234'), isTrue);
      expect(c.read(sessionProvider).pinVerified, isTrue);
    });

    test('AUTH-09/SET-02: logout clears the session and a restart never restores PIN access', () async {
      final c = newContainer();
      final n = await registeredParent(c);
      expect(c.read(sessionProvider).activeParentId, isNotNull);

      await n.logout();
      expect(c.read(sessionProvider).activeParentId, isNull);
      expect(c.read(sessionProvider).activeRole, isNull);
      expect(c.read(sessionProvider).pinVerified, isFalse);

      final afterRestart = newContainer().read(sessionProvider);
      expect(afterRestart.activeParentId, isNull);
      expect(afterRestart.pinVerified, isFalse);
    });

    test('SET-02: PIN is required again after a restart even without logout', () async {
      final c = newContainer();
      await registeredParent(c);
      expect(c.read(sessionProvider).pinVerified, isTrue);

      expect(newContainer().read(sessionProvider).pinVerified, isFalse);
    });
  });

  group('Teacher verification', () {
    Future<SessionNotifier> registeredTeacher(ProviderContainer c) async {
      final n = c.read(sessionProvider.notifier);
      n.setLanguage('en');
      await n.giveConsent();
      n.stageTeacherRegistration(
        fullName: 'Teacher One',
        school: 'Test School',
        email: 'teacher@example.com',
        password: 'Password123',
      );
      await n.createPin('5678');
      return n;
    }

    test('TEA-01: a new teacher is saved as pending', () async {
      final c = newContainer();
      final n = await registeredTeacher(c);

      final saved = TeacherRepository().findByEmail('teacher@example.com')!;
      expect(saved.verificationStatus, 'pending');
      expect(n.activeTeacherStatus, 'pending');
      expect(n.activeTeacherApproved, isFalse);
    });

    test('TEA-03: pending stays blocked across lock and restart', () async {
      final c = newContainer();
      final n = await registeredTeacher(c);

      n.lockAdminModules();
      expect(n.activeTeacherApproved, isFalse);

      final restarted = newContainer().read(sessionProvider.notifier);
      expect(restarted.activeTeacherApproved, isFalse);
    });

    test('TEA-02: approved teacher unlocks; rejected stays blocked; admin can send back to pending', () async {
      final c = newContainer();
      final n = await registeredTeacher(c);
      final repo = TeacherRepository();

      Future<void> setStatus(String status) async => repo.updateVerificationStatus(
        account: repo.findByEmail('teacher@example.com')!,
        status: status,
      );

      await setStatus('approved');
      expect(n.activeTeacherApproved, isTrue);

      await setStatus('rejected');
      expect(n.activeTeacherApproved, isFalse);
      expect(n.activeTeacherStatus, 'rejected');

      await setStatus('pending'); // admin lets the teacher re-apply
      expect(n.activeTeacherStatus, 'pending');
      expect(n.activeTeacherApproved, isFalse);
    });

    test('a teacher account from before verification (no status) counts as approved', () async {
      final c = newContainer();
      final n = c.read(sessionProvider.notifier);
      await TeacherRepository().createFromRemote(
        id: 'legacy-1',
        fullName: 'Legacy',
        email: 'legacy@example.com',
        password: 'Password123',
        pin: '1234',
      );
      n.selectRole(UserRole.asatidz);
      await n.signIn(
        role: UserRole.asatidz,
        email: 'legacy@example.com',
        password: 'Password123',
      );
      expect(n.activeTeacherApproved, isTrue);
    });

    test('the status survives a teacher password resync', () async {
      final c = newContainer();
      await registeredTeacher(c);
      final repo = TeacherRepository();
      final before = repo.findByEmail('teacher@example.com')!;

      await repo.updatePasswordLocally(account: before, newPassword: 'NewPassword9');

      expect(repo.findByEmail('teacher@example.com')!.verificationStatus, 'pending');
    });
  });

  group('Learner profiles and class enrollment', () {
    test('LRN-01: a created learner is saved and linked to the parent', () async {
      final c = newContainer();
      final n = await registeredParent(c);
      final parentId = c.read(sessionProvider).activeParentId!;

      final learner = await n.createLearner(
        name: 'Aisha',
        age: 6,
        username: 'aisha6',
      );

      expect(learner.parentId, parentId);
      expect(LearnerRepository().byParentId(parentId).map((l) => l.name), ['Aisha']);
      expect(c.read(sessionProvider).learner?.id, learner.id);
    });

    test('LRN-02: a taken learner username is rejected and nothing is created', () async {
      final c = newContainer();
      final n = await registeredParent(c);
      await n.createLearner(name: 'Aisha', age: 6, username: 'aisha6');

      await expectLater(
        n.createLearner(name: 'Other', age: 7, username: 'aisha6'),
        throwsStateError,
      );
      expect(
        LearnerRepository().byParentId(c.read(sessionProvider).activeParentId!),
        hasLength(1),
      );
    });

    test('LRN-03: edited learner details are saved', () async {
      final c = newContainer();
      final n = await registeredParent(c);
      final learner = await n.createLearner(name: 'Aisha', age: 6, username: 'aisha6');

      await n.updateLearnerProfile(name: 'Aisha K', age: 7, avatar: 'girl_mascot');

      final saved = LearnerRepository().findById(learner.id!)!;
      expect(saved.name, 'Aisha K');
      expect(saved.age, 7);
      expect(saved.avatar, 'girl_mascot');
      expect(saved.username, 'aisha6', reason: 'username is never edited here');
    });

    test('LRN-04/05: switching learners loads only that learner\'s data', () async {
      final c = newContainer();
      final n = await registeredParent(c);
      final a = await n.createLearner(name: 'Aisha', age: 6, username: 'aisha6');
      final b = await n.createLearner(name: 'Bilal', age: 7, username: 'bilal7');

      final progress = ProgressRepository();
      await progress.writeProgress(
        learnerId: a.id!,
        moduleId: 'm1',
        strokeAccuracyPct: 90,
        sequencingErrors: 0,
        timeOnTaskSeconds: 30,
      );

      await n.switchActiveLearner(a.id!);
      expect(c.read(sessionProvider).learner?.name, 'Aisha');
      expect(progress.byLearnerId(a.id!), hasLength(1));

      await n.switchActiveLearner(b.id!);
      expect(c.read(sessionProvider).learner?.name, 'Bilal');
      expect(progress.byLearnerId(b.id!), isEmpty);
    });

    test('LRN-06: a valid invitation code links only that learner to the class', () async {
      final classes = ClassRepository();
      final section = await classes.create(
        teacherId: 't1',
        gradeLevel: 'Grade 1',
        section: 'A',
      );

      final found = classes.findByInvitationCode(section.invitationCode);
      expect(found?.id, section.id);

      await classes.enroll(classId: section.id, learnerId: 'learner-1');
      expect(classes.isEnrolled(classId: section.id, learnerId: 'learner-1'), isTrue);
      expect(classes.isEnrolled(classId: section.id, learnerId: 'learner-2'), isFalse);
      expect(classes.byLearnerId('learner-2'), isEmpty);
    });

    test('LRN-07: unknown and archived invitation codes are rejected', () async {
      final classes = ClassRepository();
      final section = await classes.create(
        teacherId: 't1',
        gradeLevel: 'Grade 1',
        section: 'A',
      );

      expect(classes.findByInvitationCode('NOPE00'), isNull);

      await classes.archiveClass(section.id);
      expect(classes.findByInvitationCode(section.invitationCode), isNull);
      expect(classes.byLearnerId('learner-1'), isEmpty);
    });
  });

  group('Rewards and offline storage', () {
    test('RWD-03: a one-time badge is awarded once per learner', () async {
      final progress = ProgressRepository();

      await progress.awardBadge('learner-1', 'first_lesson');
      await progress.awardBadge('learner-1', 'first_lesson');
      await progress.awardBadge('learner-2', 'first_lesson');

      expect(progress.badgesFor('learner-1'), hasLength(1));
      expect(progress.badgesFor('learner-2'), hasLength(1));
    });

    test('OFF-02/03: progress is saved locally and survives closing and reopening the database', () async {
      final progress = ProgressRepository();
      await progress.writeProgress(
        learnerId: 'learner-1',
        moduleId: 'm1',
        strokeAccuracyPct: 80,
        sequencingErrors: 1,
        timeOnTaskSeconds: 45,
      );
      await progress.awardBadge('learner-1', 'first_lesson');
      expect(progress.currentStreak('learner-1'), 1);

      // Simulates closing the app and reopening it with no network involved.
      await Hive.close();
      await Hive.openBox<ProgressRecord>(HiveBoxes.progress);
      await Hive.openBox<StreakState>(HiveBoxes.streaks);
      await Hive.openBox<BadgeAward>(HiveBoxes.badges);

      final reopened = ProgressRepository();
      expect(reopened.byLearnerId('learner-1'), hasLength(1));
      expect(reopened.byLearnerId('learner-1').single.moduleId, 'm1');
      expect(reopened.currentStreak('learner-1'), 1);
      expect(reopened.badgesFor('learner-1'), hasLength(1));
    });
  });
}
