import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:salamlearn/logic/auth/session.dart';
import 'package:salamlearn/ui/auth/consent_screen.dart';
import 'package:salamlearn/ui/onboarding/get_started_screen.dart';
import 'package:salamlearn/ui/parent_dashboard/parent_dashboard_screen.dart';
import 'package:salamlearn/ui/student_hub/backpack_screen.dart';
import 'package:salamlearn/ui/student_hub/profile_screen.dart';
import 'package:salamlearn/ui/teacher_dashboard/teacher_dashboard_screen.dart';
import 'package:salamlearn/ui/widgets/pin_pad.dart';
import 'package:salamlearn/ui/widgets/streak_tracker.dart';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:salamlearn/data/models/enrollment.dart';
import 'package:salamlearn/data/remote/firestore_mirror.dart';
import 'package:salamlearn/data/repositories/class_repository.dart';
import 'package:salamlearn/data/repositories/learner_repository.dart';
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

  group('SessionNotifier', () {
    test('role guard state: learner never gains pin verification', () async {
      final container = ProviderContainer();
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
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(sessionProvider.notifier);
      notifier.selectRole(UserRole.parent);

      await notifier.createPin('1234');
      expect(container.read(sessionProvider).pinVerified, isTrue);

      notifier.selectRole(UserRole.parent);
      expect(container.read(sessionProvider).pinVerified, isFalse);
    });

    test('verifyPin rejects when no account exists yet', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(sessionProvider.notifier);

      expect(notifier.verifyPin('1234'), isFalse);
      expect(container.read(sessionProvider).pinVerified, isFalse);
    });

    test('eraseAll clears learner, consent, and pin (FR-7.3)', () async {
      final container = ProviderContainer();
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

      await notifier.eraseAll();
      final state = container.read(sessionProvider);
      expect(state.learner, isNull);
      expect(state.consent, isNull);
      expect(state.hasPin, isFalse);
      expect(state.languageCode, isNull);
    });

    test('added child is preserved and restored after logout and login', () async {
      final container = ProviderContainer();
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
    });

    test('previously selected child is preserved and restored after logout and login', () async {
      final container = ProviderContainer();
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
    });

    test('teacher sync pulls new remote enrollments and learner profiles', () async {
      final container = ProviderContainer();
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
      
      await container.read(teacherClassControllerProvider.notifier).createClass(
        gradeLevel: 'Grade 1',
        section: 'A',
      );
      
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
        connectivity: Connectivity(),
        mirror: fakeMirror,
        ref: container,
      );

      // Run sync!
      await syncManager.syncNow();

      // Verify the enrollment and learner profile were pulled and saved locally
      final classRepo = ClassRepository();
      expect(classRepo.isEnrolled(classId: classId, learnerId: studentId), isTrue);

      final learnerRepo = LearnerRepository();
      final localLearner = learnerRepo.findById(studentId);
      expect(localLearner, isNotNull);
      expect(localLearner?.name, 'Remote Student');
      expect(localLearner?.age, 8);

      // Verify that the classRosterProvider refreshed and now shows the student
      roster = container.read(classRosterProvider(classId));
      expect(roster, hasLength(1));
      expect(roster.first['name'], 'Remote Student');
    });

    test('teacher can unenroll/remove student from class', () async {
      final container = ProviderContainer();
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
      
      await container.read(teacherClassControllerProvider.notifier).createClass(
        gradeLevel: 'Grade 1',
        section: 'A',
      );
      
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
      expect(classRepo.isEnrolled(classId: classId, learnerId: studentId), isTrue);
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
      expect(classRepo.assignmentsFor(classId: classId, learnerId: studentId), isNotEmpty);

      // Unenroll the student!
      await classRepo.unenroll(classId: classId, learnerId: studentId);

      // Verify unenrollment cleared both enrollment and student's assignments in this class
      expect(classRepo.isEnrolled(classId: classId, learnerId: studentId), isFalse);
      expect(classRepo.assignmentsFor(classId: classId, learnerId: studentId), isEmpty);

      // Verify that roster refreshed to be empty
      container.read(rosterRefreshProvider.notifier).bump();
      roster = container.read(classRosterProvider(classId));
      expect(roster, isEmpty);
    });
  });

  group('PinPad', () {
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
      expect(find.byIcon(Icons.local_fire_department), findsOneWidget);
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
      'renders the full 9-section policy and enables "I agree" on consent',
      (tester) async {
        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: ConsentScreen())),
        );
        await tester.pump(const Duration(milliseconds: 850));

        for (final title in const [
          'What we collect',
          'How we use it',
          "Where it's stored",
          'Data retention',
          'Your rights',
          'Third-party sharing',
          "Children's privacy",
          'Teacher sync',
          'Questions or concerns',
        ]) {
          expect(find.text(title), findsOneWidget);
        }
        expect(find.textContaining('privacy@salamlearn.app'), findsOneWidget);
        expect(find.text('Last updated: June 2026'), findsOneWidget);

        final agreeButton = find.widgetWithText(FilledButton, 'I agree');
        expect(
          tester.widget<FilledButton>(agreeButton).onPressed,
          isNull,
          reason: '"I agree" starts disabled until the consent row is tapped',
        );

        final consentText = find.text(
          "I consent to local telemetry collection for my child's "
          'learning progress.',
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
    testWidgets('shows stats and rows, and Settings routes through the '
        'parent-PIN gate', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: ProfileScreen())),
      );
      await tester.pump();

      expect(find.text('Day streak'), findsOneWidget);
      expect(find.text('Modules done'), findsOneWidget);
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('My avatar'), findsOneWidget);
      expect(find.text('Settings (parent PIN)'), findsOneWidget);
    });
  });

  group('BackpackScreen', () {
    testWidgets('shows earned and locked badges with a progress pill', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: BackpackScreen())),
      );
      await tester.pump();

      expect(find.text('2 / 4'), findsOneWidget);
      expect(find.text('First Steps'), findsOneWidget);
      expect(find.text('Earned'), findsNWidgets(2));
      expect(find.text('Locked'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  });

  group('ParentDashboardScreen', () {
    testWidgets('phone layout: hero greeting, KPI cards and suggestions', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: ParentDashboardScreen())),
      );
      await tester.pumpAndSettle();

      expect(find.text("your child's progress"), findsOneWidget);
      // No sync has run and no learner is registered in this raw pump, so
      // the dashboard correctly shows empty/zero real data instead of the
      // old hardcoded mock numbers.
      expect(find.text('Not synced yet'), findsOneWidget);
      expect(find.text('Accuracy'), findsOneWidget);
      expect(find.text('0%'), findsOneWidget);
      expect(find.text('Weekly activity'), findsOneWidget);
      expect(find.text('This week'), findsOneWidget);
      expect(find.text('Practice recommended'), findsOneWidget);
    });

    testWidgets('wide layout: labeled side rail replaces the AppBar', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1000, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: ParentDashboardScreen())),
      );
      await tester.pumpAndSettle();

      expect(find.text("your child's progress"), findsOneWidget);
      expect(find.text('Progress'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Sync now'), findsOneWidget);
    });
  });

  group('TeacherDashboardScreen', () {
    testWidgets(
      'phone layout: hero snapshot, roster cards and all class tools',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(400, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(home: TeacherDashboardScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Grade 1 · A'), findsOneWidget);
        expect(find.text("Today's progress"), findsOneWidget);
        expect(find.text('Ali'), findsOneWidget);
        expect(find.text('92% tracing · active 2h ago'), findsOneWidget);
        // Phone uses the dotted mastery pill draft: uppercase text.
        expect(find.text('HIGH'), findsOneWidget);
        // Progression Override must be reachable on phone too, not
        // desktop-only (FR-6.7). Hot Seat/Choral Controller were removed
        // from the Home quick actions (still reachable from Cast).
        expect(find.text('Progression override'), findsOneWidget);
      },
    );

    testWidgets('wide layout: labeled side rail and roster table', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1000, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: TeacherDashboardScreen())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Grade 1 · Section A'), findsOneWidget);
      expect(find.text('Roster'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Student roster'), findsOneWidget);
      expect(find.text('Hamza'), findsOneWidget);
      expect(find.text('Needs help'), findsAtLeastNWidgets(1));
    });
  });
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
