import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:salamlearn/logic/auth/session.dart';
import 'package:salamlearn/logic/connectivity/internet_access.dart';
import 'package:salamlearn/ui/auth/consent_screen.dart';
import 'package:salamlearn/ui/auth/role_picker_screen.dart';
import 'package:salamlearn/ui/onboarding/get_started_screen.dart';
import 'package:salamlearn/ui/parent_dashboard/parent_dashboard_screen.dart';
import 'package:salamlearn/ui/student_hub/backpack_screen.dart';
import 'package:salamlearn/ui/student_hub/profile_screen.dart';
import 'package:salamlearn/ui/teacher_dashboard/teacher_dashboard_screen.dart';
import 'package:salamlearn/ui/widgets/pin_pad.dart';
import 'package:salamlearn/ui/widgets/streak_tracker.dart';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive/hive.dart';
import 'package:salamlearn/data/curriculum_data.dart';
import 'package:salamlearn/data/local/hive_boxes.dart';
import 'package:salamlearn/data/models/class_section.dart';
import 'package:salamlearn/data/models/learner_profile.dart';
import 'package:salamlearn/data/models/progress_record.dart';
import 'package:salamlearn/logic/progress_providers.dart';
import 'package:salamlearn/data/models/enrollment.dart';
import 'package:salamlearn/data/remote/firestore_mirror.dart';
import 'package:salamlearn/data/repositories/class_repository.dart';
import 'package:salamlearn/data/repositories/learner_repository.dart';
import 'package:salamlearn/data/repositories/teacher_repository.dart';
import 'package:salamlearn/logic/sync/sync_manager.dart';
import 'package:salamlearn/logic/teacher/teacher_providers.dart';

import 'test_helpers/hive_test_setup.dart';

void main() {
  // Every screen in this suite now reads through session.dart into real
  // Hive-backed repositories (Phase 4-8 of the backend plan) — a temp-dir
  // Hive instance has to be live for the whole file, not just the
  // SessionNotifier group, or any screen touching a repository/provider
  // throws `HiveError: Box not found`.
  late Directory tempDir;

  setUp(() async {
    tempDir = await setUpTestHive();
  });

  tearDown(() async {
    await tearDownTestHive(tempDir);
  });

  ProviderContainer onlineContainer() => ProviderContainer(
    overrides: [internetAccessProvider.overrideWithValue(() async => true)],
  );

  group('SessionNotifier', () {
    for (final role in [UserRole.parent, UserRole.asatidz]) {
      test(
        '$role cannot create an account offline and can retry online',
        () async {
          var online = false;
          final container = ProviderContainer(
            overrides: [
              internetAccessProvider.overrideWithValue(() async => online),
            ],
          );
          addTearDown(container.dispose);
          final notifier = container.read(sessionProvider.notifier);
          if (role == UserRole.parent) {
            notifier.stageParentRegistration(
              fullName: 'Parent Test',
              email: 'parent@example.com',
              password: 'Password123',
            );
          } else {
            notifier.stageTeacherRegistration(
              fullName: 'Teacher Test',
              school: 'School',
              email: 'teacher@example.com',
              password: 'Password123',
            );
          }

          await expectLater(
            notifier.createPin('1234'),
            throwsA(isA<AccountCreationOfflineException>()),
          );
          expect(container.read(sessionProvider).hasPin, isFalse);
          online = true;
          await notifier.createPin('1234');
          expect(container.read(sessionProvider).hasPin, isTrue);
        },
      );
    }

    test(
      'child profile is not saved offline and can be created online',
      () async {
        var online = true;
        final container = ProviderContainer(
          overrides: [
            internetAccessProvider.overrideWithValue(() async => online),
          ],
        );
        addTearDown(container.dispose);
        final notifier = container.read(sessionProvider.notifier);
        notifier.selectRole(UserRole.parent);
        await notifier.createPin('1234');

        online = false;
        await expectLater(
          notifier.createLearner(name: 'Amina', age: 8, username: 'amina'),
          throwsA(isA<AccountCreationOfflineException>()),
        );
        expect(LearnerRepository().findByUsername('amina'), isNull);
        online = true;
        final child = await notifier.createLearner(
          name: 'Amina',
          age: 8,
          username: 'amina',
        );
        expect(child.parentId, container.read(sessionProvider).activeParentId);
      },
    );

    test('learner profiles require an active parent account', () async {
      final container = onlineContainer();
      addTearDown(container.dispose);
      final notifier = container.read(sessionProvider.notifier);

      await expectLater(
        notifier.createLearner(name: 'Amir', age: 7, username: 'amir'),
        throwsStateError,
      );
      expect(LearnerRepository().findByUsername('amir'), isNull);
    });

    test(
      'parent can attach an existing unlinked learner without losing its id',
      () async {
        final orphan = await LearnerRepository().register(
          parentId: '',
          name: 'Amina',
          age: 8,
          username: 'amina_old',
        );
        final container = onlineContainer();
        addTearDown(container.dispose);
        final notifier = container.read(sessionProvider.notifier);
        notifier.selectRole(UserRole.parent);
        await expectLater(
          notifier.attachUnlinkedLearner(orphan.id!),
          throwsStateError,
        );
        await notifier.createPin('1234');
        final parentId = container.read(sessionProvider).activeParentId!;

        await notifier.attachUnlinkedLearner(orphan.id!);

        final linked = LearnerRepository().findById(orphan.id!);
        expect(linked?.id, orphan.id);
        expect(linked?.parentId, parentId);
        expect(container.read(sessionProvider).learner?.id, orphan.id);
      },
    );

    test('role guard state: learner never gains pin verification', () async {
      final container = onlineContainer();
      addTearDown(container.dispose);
      final notifier = container.read(sessionProvider.notifier);

      notifier.setLanguage('en');
      await notifier.giveConsent();
      notifier.selectRole(UserRole.learner);

      final state = container.read(sessionProvider);
      expect(state.activeRole, UserRole.learner);
      expect(state.pinVerified, isFalse);
    });

    test('selecting a role resets pin verification', () async {
      final container = onlineContainer();
      addTearDown(container.dispose);
      final notifier = container.read(sessionProvider.notifier);
      notifier.selectRole(UserRole.parent);

      await notifier.createPin('1234');
      expect(container.read(sessionProvider).pinVerified, isTrue);

      notifier.selectRole(UserRole.parent);
      expect(container.read(sessionProvider).pinVerified, isFalse);
    });

    test('verifyPin rejects when no account exists yet', () async {
      final container = onlineContainer();
      addTearDown(container.dispose);
      final notifier = container.read(sessionProvider.notifier);

      expect(notifier.verifyPin('1234'), isFalse);
      expect(container.read(sessionProvider).pinVerified, isFalse);
    });

    test('delete account asks for the account password', () async {
      final container = onlineContainer();
      addTearDown(container.dispose);
      final notifier = container.read(sessionProvider.notifier);

      notifier.stageParentRegistration(
        fullName: 'Aisha',
        email: 'aisha@example.com',
        password: 'Secret#123',
      );
      await notifier.createPin('1234');

      expect(
        await notifier.confirmAccountPassword('wrong'),
        DeleteAccountCheck.wrongPassword,
      );
      expect(
        await notifier.confirmAccountPassword('Secret#123'),
        DeleteAccountCheck.ok,
      );
    });

    test('deleteAccount clears learner, consent, and pin (FR-7.3)', () async {
      final container = onlineContainer();
      addTearDown(container.dispose);
      final notifier = container.read(sessionProvider.notifier);

      notifier.setLanguage('fil');
      await notifier.giveConsent();
      notifier.selectRole(UserRole.parent);
      await notifier.createPin('1234');
      await notifier.createLearner(
        name: 'Amir',
        age: 7,
        username: 'amir_test',
        password: 'password123',
      );

      await notifier.deleteAccount();
      final state = container.read(sessionProvider);
      expect(state.learner, isNull);
      expect(state.consent, isNull);
      expect(state.hasPin, isFalse);
      expect(state.languageCode, isNull);
    });

    test(
      'added child is preserved and restored after logout and login',
      () async {
        final container = onlineContainer();
        addTearDown(container.dispose);
        final notifier = container.read(sessionProvider.notifier);

        notifier.setLanguage('en');
        await notifier.giveConsent();

        // Stage registration and setup parent account
        notifier.stageParentRegistration(
          fullName: 'Parent Test',
          email: 'parent@example.com',
          password: 'Password123',
        );
        await notifier.createPin('1234');

        // Verify parent is logged in
        var state = container.read(sessionProvider);
        expect(state.activeParentId, isNotNull);

        // Create a learner
        await notifier.createLearner(
          name: 'Amir',
          age: 7,
          username: 'amir_test',
          avatar: 'boy_mascot',
          gradeLevel: 'Grade 1',
        );

        state = container.read(sessionProvider);
        expect(state.learner, isNotNull);
        expect(state.learner?.name, 'Amir');
        final learnerId = state.learner?.id;

        // Logout
        await notifier.logout();
        state = container.read(sessionProvider);
        expect(state.activeParentId, isNull);
        expect(state.learner, isNull);

        // Log back in
        final result = await notifier.signIn(
          role: UserRole.parent,
          email: 'parent@example.com',
          password: 'Password123',
        );
        expect(result, SignInResult.success);

        state = container.read(sessionProvider);
        expect(state.activeParentId, isNotNull);
        expect(state.learner, isNotNull);
        expect(state.learner?.id, learnerId);
        expect(state.learner?.name, 'Amir');
      },
    );

    test('logging out one role keeps the other role signed in', () async {
      final container = onlineContainer();
      addTearDown(container.dispose);
      final notifier = container.read(sessionProvider.notifier);

      notifier.setLanguage('en');
      await notifier.giveConsent();
      notifier.stageParentRegistration(
        fullName: 'Parent Test',
        email: 'parent@example.com',
        password: 'Password123',
      );
      await notifier.createPin('1234');
      notifier.stageTeacherRegistration(
        fullName: 'Teacher Test',
        school: 'School',
        email: 'teacher@example.com',
        password: 'Password123',
      );
      await notifier.createPin('5678');

      var state = container.read(sessionProvider);
      final parentId = state.activeParentId;
      final teacherId = state.activeTeacherId;
      expect(parentId, isNotNull);
      expect(teacherId, isNotNull);

      await notifier.logout();
      state = container.read(sessionProvider);
      expect(state.activeTeacherId, isNull);
      expect(state.activeParentId, parentId);

      notifier.selectRole(UserRole.parent);
      await notifier.logout();
      state = container.read(sessionProvider);
      expect(state.activeParentId, isNull);
    });

    test(
      'previously selected child is preserved and restored after logout and login',
      () async {
        final container = onlineContainer();
        addTearDown(container.dispose);
        final notifier = container.read(sessionProvider.notifier);

        notifier.setLanguage('en');
        await notifier.giveConsent();

        // Stage registration and setup parent account
        notifier.stageParentRegistration(
          fullName: 'Parent Test',
          email: 'parent@example.com',
          password: 'Password123',
        );
        await notifier.createPin('1234');

        // Create first learner (Amir)
        await notifier.createLearner(
          name: 'Amir',
          age: 7,
          username: 'amir_test',
          avatar: 'boy_mascot',
          gradeLevel: 'Grade 1',
        );

        // Create second learner (Zara)
        final zara = await notifier.createLearner(
          name: 'Zara',
          age: 6,
          username: 'zara_test',
          avatar: 'girl_mascot',
          gradeLevel: 'Grade 1',
        );

        // Select Zara as active learner
        await notifier.switchActiveLearner(zara.id!);

        var state = container.read(sessionProvider);
        expect(state.learner?.name, 'Zara');
        final lastSelectedLearnerId = state.learner?.id;

        // Logout
        await notifier.logout();
        state = container.read(sessionProvider);
        expect(state.learner, isNull);

        // Log back in
        final result = await notifier.signIn(
          role: UserRole.parent,
          email: 'parent@example.com',
          password: 'Password123',
        );
        expect(result, SignInResult.success);

        state = container.read(sessionProvider);
        expect(state.learner, isNotNull);
        expect(state.learner?.id, lastSelectedLearnerId);
        expect(state.learner?.name, 'Zara');
      },
    );

    test(
      'teacher sync pulls new remote enrollments and learner profiles',
      () async {
        final container = onlineContainer();
        addTearDown(container.dispose);
        final sessionNotifier = container.read(sessionProvider.notifier);

        sessionNotifier.setLanguage('en');
        await sessionNotifier.giveConsent();

        // Create a teacher account and a class locally
        sessionNotifier.stageTeacherRegistration(
          fullName: 'Teacher Test',
          school: 'Test School',
          email: 'teacher@example.com',
          password: 'Password123',
        );
        await sessionNotifier.createPin('5678');

        await container
            .read(teacherClassControllerProvider.notifier)
            .createClass(gradeLevel: 'Grade 1', section: 'A');

        final activeClass = container.read(teacherClassControllerProvider);
        expect(activeClass, isNotNull);
        final classId = activeClass!.id;

        // Ensure local roster is initially empty
        var roster = container.read(classRosterProvider(classId));
        expect(roster, isEmpty);

        // Setup fake remote enrollment and learner
        const studentId = 'student-uuid-123';
        final remoteEnrollment = Enrollment(
          classId: classId,
          learnerId: studentId,
          enrolledAt: DateTime.now(),
        );
        const remoteLearner = RemoteLearnerRef(
          id: studentId,
          name: 'Remote Student',
          age: 8,
          avatar: 'girl_mascot',
          gradeLevel: 'Grade 2',
          parentId: 'parent-uuid-456',
        );

        final fakeMirror = _FakeFirestoreMirror(
          enrollments: [remoteEnrollment],
          learners: {studentId: remoteLearner},
        );

        // Create SyncManager with fake connectivity and mirror
        final syncManager = SyncManager(
          connectivity: _FakeConnectivity(),
          mirror: fakeMirror,
          ref: container,
        );

        // Run sync!
        await syncManager.syncNow();

        // Verify the enrollment and learner profile were pulled and saved locally
        final classRepo = ClassRepository();
        expect(
          classRepo.isEnrolled(classId: classId, learnerId: studentId),
          isTrue,
        );

        final learnerRepo = LearnerRepository();
        final localLearner = learnerRepo.findById(studentId);
        expect(localLearner, isNotNull);
        expect(localLearner?.name, 'Remote Student');
        expect(localLearner?.age, 8);

        // Verify that the classRosterProvider refreshed and now shows the student
        roster = container.read(classRosterProvider(classId));
        expect(roster, hasLength(1));
        expect(roster.first['name'], 'Remote Student');
      },
    );

    test(
      'new teacher starts pending and only becomes approved via status update',
      () async {
        final container = onlineContainer();
        addTearDown(container.dispose);
        final notifier = container.read(sessionProvider.notifier);

        notifier.setLanguage('en');
        await notifier.giveConsent();
        notifier.stageTeacherRegistration(
          fullName: 'Pending Teacher',
          school: 'Test School',
          email: 'pending@example.com',
          password: 'Password123',
        );
        await notifier.createPin('5678');

        expect(notifier.activeTeacherStatus, 'pending');
        expect(notifier.activeTeacherApproved, isFalse);

        final repo = TeacherRepository();
        final account = repo.findByEmail('pending@example.com')!;
        await repo.updateVerificationStatus(
          account: account,
          status: 'approved',
        );
        expect(notifier.activeTeacherApproved, isTrue);
      },
    );

    test(
      'teacher account without a status (pre-verification) counts as approved',
      () async {
        final container = onlineContainer();
        addTearDown(container.dispose);
        final notifier = container.read(sessionProvider.notifier);

        final legacy = await TeacherRepository().createFromRemote(
          id: 'legacy-1',
          fullName: 'Legacy Teacher',
          email: 'legacy@example.com',
          password: 'Password123',
          pin: '1234',
        );
        notifier.selectRole(UserRole.asatidz);
        await notifier.signIn(
          role: UserRole.asatidz,
          email: 'legacy@example.com',
          password: 'Password123',
        );

        expect(legacy.verificationStatus, isNull);
        expect(notifier.activeTeacherApproved, isTrue);
      },
    );

    test('teacher can unenroll/remove student from class', () async {
      final container = onlineContainer();
      addTearDown(container.dispose);
      final sessionNotifier = container.read(sessionProvider.notifier);

      sessionNotifier.setLanguage('en');
      await sessionNotifier.giveConsent();

      // Create teacher and class
      sessionNotifier.stageTeacherRegistration(
        fullName: 'Teacher Test',
        school: 'Test School',
        email: 'teacher@example.com',
        password: 'Password123',
      );
      await sessionNotifier.createPin('5678');

      await container
          .read(teacherClassControllerProvider.notifier)
          .createClass(gradeLevel: 'Grade 1', section: 'A');

      final activeClass = container.read(teacherClassControllerProvider);
      final classId = activeClass!.id;

      // Enroll a student
      const studentId = 'student-uuid-999';
      final classRepo = ClassRepository();
      await classRepo.enroll(classId: classId, learnerId: studentId);

      // Save learner profile locally
      final learnerRepo = LearnerRepository();
      await learnerRepo.saveFromRemote(
        id: studentId,
        parentId: 'parent-1',
        name: 'Zara Test',
        age: 6,
        avatar: 'girl_mascot',
        gradeLevel: 'Grade 1',
      );

      // Verify enrolled and in roster initially
      expect(
        classRepo.isEnrolled(classId: classId, learnerId: studentId),
        isTrue,
      );
      var roster = container.read(classRosterProvider(classId));
      expect(roster, hasLength(1));
      expect(roster.first['name'], 'Zara Test');

      // Assign a module to this student
      await classRepo.assignModule(
        classId: classId,
        learnerId: studentId,
        moduleId: 'Letters Tracing (Alif to Kha)',
        dueDate: DateTime.now().add(const Duration(days: 3)),
      );
      expect(
        classRepo.assignmentsFor(classId: classId, learnerId: studentId),
        isNotEmpty,
      );

      // Unenroll the student!
      await classRepo.unenroll(classId: classId, learnerId: studentId);

      // Verify unenrollment cleared both enrollment and student's assignments in this class
      expect(
        classRepo.isEnrolled(classId: classId, learnerId: studentId),
        isFalse,
      );
      expect(
        classRepo.assignmentsFor(classId: classId, learnerId: studentId),
        isEmpty,
      );

      // Verify that roster refreshed to be empty
      container.read(rosterRefreshProvider.notifier).bump();
      roster = container.read(classRosterProvider(classId));
      expect(roster, isEmpty);
    });
  });

  testWidgets('role picker offers parent and teacher accounts only', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: RolePickerScreen())),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Parent / Guardian'), findsOneWidget);
    expect(find.text('Asatidz (Teacher)'), findsOneWidget);
    expect(find.text('Learner'), findsNothing);
  });

  group('PinPad', () {
    testWidgets('records a digit on press before release', (tester) async {
      String? submitted;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PinPad(
              onSubmit: (pin) {
                submitted = pin;
                return true;
              },
            ),
          ),
        ),
      );

      for (final digit in ['1', '2', '3', '4']) {
        final press = await tester.startGesture(
          tester.getCenter(find.text(digit)),
        );
        await tester.pump();
        expect(find.text('\u2022'), findsNWidgets(int.parse(digit)));
        if (digit == '4') expect(submitted, '1234');
        await press.up();
        await tester.pump();
      }
      expect(submitted, '1234');
    });

    testWidgets('submits after 4 digits', (tester) async {
      String? submitted;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PinPad(
              onSubmit: (pin) {
                submitted = pin;
                return true;
              },
            ),
          ),
        ),
      );

      for (final digit in ['1', '2', '3', '4']) {
        await tester.tap(find.text(digit));
        await tester.pump();
      }
      expect(submitted, '1234');
    });

    testWidgets('backspace removes the last digit', (tester) async {
      String? submitted;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PinPad(
              onSubmit: (pin) {
                submitted = pin;
                return true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('1'));
      await tester.tap(find.text('2'));
      await tester.tap(find.byIcon(Icons.backspace_outlined));
      for (final digit in ['3', '4', '5']) {
        await tester.tap(find.text(digit));
        await tester.pump();
      }
      expect(submitted, '1345');
    });
  });

  group('StreakTracker', () {
    testWidgets('renders streak count with flame icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: StreakTracker(streakDays: 5))),
      );

      expect(find.text('5 day streak'), findsOneWidget);
      final flame = tester.widget<StreakFlame>(find.byType(StreakFlame));
      expect(flame.lit, isTrue);
    });

    testWidgets('shows the unlit flame at 0 days', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: StreakTracker(streakDays: 0))),
      );

      final flame = tester.widget<StreakFlame>(find.byType(StreakFlame));
      expect(flame.lit, isFalse);
    });
  });

  group('GetStartedScreen', () {
    testWidgets('fits on a short-height phone without overflowing', (
      tester,
    ) async {
      // iPhone SE-class height minus room for a hosting shell's app/nav
      // chrome — the fixed 340px hero + 76px gap this screen used to have
      // would hard-overflow here.
      await tester.binding.setSurfaceSize(const Size(360, 560));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: GetStartedScreen())),
      );
      await tester.pump(const Duration(milliseconds: 1300));

      expect(find.text("Let's get started"), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('fits on a tall tablet-ish screen too', (tester) async {
      await tester.binding.setSurfaceSize(const Size(420, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: GetStartedScreen())),
      );
      await tester.pump(const Duration(milliseconds: 1300));

      expect(find.text("Let's get started"), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('ConsentScreen', () {
    testWidgets(
      'renders the full 8-section policy and enables "I agree" on consent',
      (tester) async {
        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: ConsentScreen())),
        );
        await tester.pump(const Duration(milliseconds: 850));

        for (final title in const [
          'Personal data we collect',
          'Purpose of processing',
          'Storage and security',
          'Data sharing',
          'Data retention',
          'Your rights',
          "Children's privacy",
          'Contact us',
        ]) {
          expect(find.text(title), findsOneWidget);
        }
        expect(find.textContaining('privacy@salamlearn.app'), findsOneWidget);
        expect(find.text('Last updated: September 2026'), findsOneWidget);

        final agreeButton = find.widgetWithText(FilledButton, 'I agree');
        expect(
          tester.widget<FilledButton>(agreeButton).onPressed,
          isNull,
          reason: '"I agree" starts disabled until the consent row is tapped',
        );

        final consentText = find.text(
          'I have read and understood this form, and I consent to '
          "the collection and processing of my child's personal "
          'data as described above.',
        );
        await tester.ensureVisible(consentText);
        await tester.pump();
        await tester.tap(consentText);
        await tester.pump();

        expect(tester.widget<FilledButton>(agreeButton).onPressed, isNotNull);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('ProfileScreen', () {
    testWidgets('shows the settings rows, with Switch Account behind the '
        'parent PIN', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: ProfileScreen())),
      );
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.notifications_rounded), findsOneWidget);
      expect(find.text('Switch Account'), findsOneWidget);
      expect(find.text('Requires parent PIN'), findsOneWidget);
    });
  });

  group('BackpackScreen', () {
    testWidgets('shows the badge count and locked badges on the shelves', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: BackpackScreen())),
      );
      await tester.pump();

      expect(find.textContaining('of 16 badges earned'), findsOneWidget);
      expect(find.text('Locked'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('ParentDashboardScreen', () {
    testWidgets('phone: teal header, glance sheet, adventures and trend', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: ParentDashboardScreen())),
      );
      await tester.pumpAndSettle();

      // No learner is registered in this raw pump, so the header nudges
      // toward enrolling and the KPIs show real zeros, not mock numbers.
      expect(find.text('Enroll your child'), findsOneWidget);
      expect(find.text("Assalamu'alaikum"), findsOneWidget);
      expect(find.text('Not synced yet'), findsOneWidget);
      expect(find.text('This week at a glance'), findsOneWidget);
      expect(find.text('Accuracy'), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
      expect(find.text('View Detailed Progress Report'), findsOneWidget);
      expect(find.text('Adventures this week'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Weekly trend'), 200);
      expect(find.text('Weekly trend'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('phone: a child with no class gets a join-class nudge', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionProvider.overrideWith(_ClasslessLearnerSession.new),
          ],
          child: const MaterialApp(home: ParentDashboardScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final nudge = find.byKey(const ValueKey('join-class-reminder'));
      expect(nudge, findsOneWidget);
      expect(find.text('Not in a class yet'), findsOneWidget);

      // Join leads to the Profile tab's class-code field.
      await tester.tap(
        find.descendant(of: nudge, matching: find.text('Join')),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(nudge, findsNothing);
      expect(find.text('Invitation code', skipOffstage: false), findsOneWidget);
    });

    testWidgets('phone: Profile tab swaps the header title and panel', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 740));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: ParentDashboardScreen())),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Profile'));
      // The empty-state Lottie loops, so pumpAndSettle would never settle.
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.text('Family & profile'), findsOneWidget);
      expect(find.text('No child profile yet'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Create New Profile'), 200);
      expect(find.text('Synchronize Data'), findsOneWidget);
      // Settings isn't driven here: its shared EmailVerificationCard needs
      // a real Firebase app, which this widget-test harness doesn't create.
      expect(tester.takeException(), isNull);
      // Let the stagger-in delays scheduled by the scroll fire before teardown.
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('wide: content column stays capped, tabs still present', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1000, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: ParentDashboardScreen())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Enroll your child'), findsOneWidget);
      expect(find.text('Progress'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(
        tester.getSize(find.text('This week at a glance').first).width,
        lessThan(560),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('TeacherDashboardScreen', () {
    // A real class with two enrolled students and real progress, instead of
    // the old hardcoded mock roster — the dashboard reads everything from
    // Hive now, so the tests seed Hive and check what it derives.
    // Built fresh per test: a ClassSection is a HiveObject, and one instance
    // can't be stored in a second test's (newly opened) box.
    ClassSection newSection() => ClassSection(
      id: 'class-1',
      teacherId: 'teacher-1',
      name: 'Grade 1 - Section A',
      invitationCode: 'ABC123',
      createdAt: DateTime(2026, 1, 1),
    );

    Future<void> seedClass(ClassSection section) async {
      await Hive.box<ClassSection>(HiveBoxes.classes).put(section.id, section);
      final now = DateTime.now();
      final students = {'ali': ('Ali', 92.0), 'hamza': ('Hamza', 45.0)};
      for (final MapEntry(key: id, value: (name, accuracy))
          in students.entries) {
        await Hive.box<LearnerProfile>(
          HiveBoxes.learners,
        ).put(id, LearnerProfile(id: id, name: name, age: 6));
        await Hive.box<Enrollment>(HiveBoxes.enrollments).put(
          '${section.id}:$id',
          Enrollment(
            classId: section.id,
            learnerId: id,
            enrolledAt: DateTime(2026, 1, 2),
          ),
        );
        await Hive.box<ProgressRecord>(HiveBoxes.progress).put(
          'p-$id',
          ProgressRecord(
            id: 'p-$id',
            learnerId: id,
            moduleId: '${curriculum.first.id}',
            strokeAccuracyPct: accuracy,
            sequencingErrors: 1,
            timeOnTaskSeconds: 300,
            completedAt: now,
            lessonId: curriculum.first.lessons.first.id,
          ),
        );
      }
    }

    Future<void> pumpDashboard(WidgetTester tester, Size size) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final section = newSection();
      // Real Hive file I/O — must run outside the fake test clock.
      await tester.runAsync(() => seedClass(section));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            teacherClassControllerProvider.overrideWith(
              () => _FakeTeacherClassController(section),
            ),
            // Live Firestore listeners — no Firebase app in widget tests.
            accountStreamProvider.overrideWith((ref) => Stream.value(true)),
            teacherProgressSyncProvider.overrideWith(
              (ref) => const Stream.empty(),
            ),
          ],
          child: const MaterialApp(home: TeacherDashboardScreen()),
        ),
      );
      // The header's sync dot pulses forever (intended), so pumpAndSettle
      // would never return — pump past the entrance animations instead.
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
    }

    Future<void> finish(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets(
      'phone layout: class header, real roster cards and all class tools',
      (tester) async {
        await pumpDashboard(tester, const Size(400, 800));

        // Hub header: the active class name is the Home tab's title.
        expect(find.text('Grade 1 - Section A'), findsOneWidget);
        expect(find.text('2 students synced'), findsOneWidget);
        expect(find.text('Ali'), findsOneWidget);
        expect(find.text('Hamza'), findsOneWidget);
        expect(find.text('92% tracing · active 5m logged'), findsOneWidget);
        // Phone uses the dotted mastery pill draft: uppercase text.
        expect(find.text('HIGH'), findsOneWidget);
        expect(find.text('NEEDS HELP'), findsOneWidget);
        // Progression Override must be reachable on phone too, not
        // desktop-only (FR-6.7).
        await tester.scrollUntilVisible(
          find.text('Progression override'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Progression override'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await finish(tester);
      },
    );

    testWidgets('wide layout: labeled side rail and roster table', (
      tester,
    ) async {
      await pumpDashboard(tester, const Size(1000, 700));

      expect(find.text('Grade 1 - Section A'), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Classroom'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Ali'), findsOneWidget);
      expect(find.text('Hamza'), findsOneWidget);
      expect(find.text('Needs help'), findsAtLeastNWidgets(1));
      expect(tester.takeException(), isNull);
      await finish(tester);
    });
  });
}

/// Overrides the Notifier itself so the real Hive-backed
/// `TeacherClassController.build` (which needs a signed-in teacher) never
/// runs — same pattern `home_mode_dashboard_screen_test.dart` uses.
class _FakeTeacherClassController extends TeacherClassController {
  _FakeTeacherClassController(this._section);
  final ClassSection? _section;

  @override
  ClassSection? build() => _section;
}

/// Always online — the real `Connectivity()` needs the platform plugin,
/// which doesn't exist in widget tests.
class _FakeConnectivity implements Connectivity {
  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => [
    ConnectivityResult.wifi,
  ];

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFirestoreMirror extends FirestoreMirror {
  _FakeFirestoreMirror({
    List<Enrollment>? enrollments,
    Map<String, RemoteLearnerRef>? learners,
  }) : _enrollments = enrollments ?? [],
       _learners = learners ?? {};

  final List<Enrollment> _enrollments;
  final Map<String, RemoteLearnerRef> _learners;

  @override
  Future<List<Enrollment>> fetchEnrollmentsForClass(String classId) async {
    return _enrollments.where((e) => e.classId == classId).toList();
  }

  @override
  Future<RemoteLearnerRef?> fetchLearner(String learnerId) async {
    return _learners[learnerId];
  }

  @override
  Future<void> pushParent(dynamic account) async {}
  @override
  Future<void> pushTeacher(dynamic account) async {}
  @override
  Future<void> pushLearner(dynamic learner) async {}
  @override
  Future<void> pushClass(dynamic section) async {}
  @override
  Future<void> pushEnrollment(dynamic enrollment) async {}
  @override
  Future<void> pushProgress(dynamic record) async {}
  @override
  Future<void> pushAssignedModule(dynamic assignment) async {}
  @override
  Future<void> pushCustomLesson(dynamic lesson) async {}
  @override
  Future<void> pushConsent(dynamic key, dynamic record) async {}
}

class _ClasslessLearnerSession extends SessionNotifier {
  @override
  SessionState build() => SessionState(
    activeParentId: 'parent-1',
    learner: LearnerProfile(name: 'Amir', age: 7, id: 'learner-1'),
  );
}
