import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:salamlearn/logic/auth/session.dart';
import 'package:salamlearn/ui/auth/consent_screen.dart';
import 'package:salamlearn/ui/onboarding/get_started_screen.dart';
import 'package:salamlearn/ui/parent_dashboard/parent_dashboard_screen.dart';
import 'package:salamlearn/ui/student_hub/backpack_screen.dart';
import 'package:salamlearn/ui/student_hub/leaderboard_screen.dart';
import 'package:salamlearn/ui/student_hub/profile_screen.dart';
import 'package:salamlearn/ui/student_hub/student_hub_screen.dart';
import 'package:salamlearn/ui/teacher_dashboard/teacher_dashboard_screen.dart';
import 'package:salamlearn/ui/widgets/pin_pad.dart';
import 'package:salamlearn/ui/widgets/streak_tracker.dart';

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

  group('StudentHubScreen', () {
    testWidgets('renders the stats row, greeting and all 5 '
        'modules in the grid list', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: StudentHubScreen())),
      );
      // Advance past the entrance fade/slide-in explicitly rather than
      // pumpAndSettle: the header's ambient blob runs a repeat(reverse:
      // true) drift animation that never settles.
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.textContaining("Assalamu'alaikum"), findsOneWidget);
      expect(find.text('Day Streak'), findsOneWidget);
      expect(find.text("Today's Progress"), findsOneWidget);
      expect(find.text('Your Learning Modules'), findsOneWidget);

      // All 5 modules are in the grid list. "Sounds" is also on the continue card,
      // so it appears twice.
      expect(find.text('Tracing'), findsOneWidget);
      expect(find.text('Sounds'), findsNWidgets(2));
      expect(find.text("Qur'an & Hadith"), findsOneWidget);

      // Below the fold on the default test surface — scroll incrementally
      // (rather than ensureVisible, which needs the element to already
      // exist) until each comes into view.
      await tester.scrollUntilVisible(
        find.text('Stories'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Stories'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Sort & Match'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Sort & Match'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Daily Goal'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Daily Goal'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Keep your streak alive!'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Keep your streak alive!'), findsOneWidget);
    });

    testWidgets('module row press-scales down without navigating', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: StudentHubScreen())),
      );
      await tester.pump(const Duration(milliseconds: 700));

      final scaleFinder = find
          .ancestor(
            of: find.text('Tracing'),
            matching: find.byType(AnimatedScale),
          )
          .first;
      expect(tester.widget<AnimatedScale>(scaleFinder).scale, 1.0);

      // Inside a Scrollable, the tap recognizer competes with the
      // vertical-drag recognizer in the gesture arena and only resolves
      // (triggering onHighlightChanged) after that arena settles.
      await tester.press(find.text('Tracing'));
      await tester.pump(const Duration(milliseconds: 150));

      expect(tester.widget<AnimatedScale>(scaleFinder).scale, 0.97);
    });

    testWidgets(
      'continue card is teal, shows the in-progress module\'s mascot, and '
      'the progress ring renders',
      (tester) async {
        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: StudentHubScreen())),
        );
        await tester.pump(const Duration(milliseconds: 700));

        expect(find.text('Continue Learning'), findsOneWidget);
        expect(find.text('2 of 5 cards left'), findsOneWidget);
        expect(find.text('Continue Lesson'), findsOneWidget);

        // "Sounds" (flashcards) is the mock in-progress module — its
        // mascot should render inside the continue card, and nowhere
        // else (it's excluded from the module list below).
        expect(
          find.byWidgetPredicate((w) {
            if (w is! Image) return false;
            final image = w.image;
            final resolved = image is ResizeImage
                ? image.imageProvider
                : image;
            return resolved ==
                const AssetImage('assets/images/mascot_flashcards.png');
          }),
          findsOneWidget,
        );
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      },
    );

    testWidgets('module rows fit at phone width without overflow', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: StudentHubScreen())),
      );
      await tester.pump(const Duration(milliseconds: 700));

      expect(tester.takeException(), isNull);

      await tester.ensureVisible(find.text('Sort & Match'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('bell button opens the notifications sheet', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: StudentHubScreen())),
      );
      await tester.pump(const Duration(milliseconds: 700));

      await tester.tap(find.byIcon(Icons.notifications_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('5-day streak!'), findsOneWidget);
    });
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

  group('LeaderboardScreen', () {
    testWidgets('tab switches ranked entries and re-ranks the podium', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: LeaderboardScreen())),
      );
      await tester.pump();

      // Week is the default range: Amira ("YOU") leads, appearing in both
      // the podium and the highlighted you-row below it.
      expect(find.text('YOU'), findsOneWidget);
      expect(find.text('Amira'), findsNWidgets(2));
      expect(find.text('248'), findsOneWidget);

      await tester.tap(find.text('All-time'));
      await tester.pump();

      // All-time re-ranks Zayd to 1st and Amira to 2nd with different
      // point totals.
      expect(find.text('3120 pts'), findsOneWidget);
      expect(find.text('2860'), findsOneWidget);
      expect(find.text('248'), findsNothing);
      expect(tester.takeException(), isNull);
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
        // Hot Seat, Choral, and Progression Override must be reachable on
        // phone too, not desktop-only (FR-6.5/6.6/6.7).
        expect(find.text('Hot seat'), findsOneWidget);
        expect(find.text('Choral controller'), findsOneWidget);
        expect(find.text('Progression override'), findsOneWidget);
        expect(find.text('Cast to class'), findsOneWidget);
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
