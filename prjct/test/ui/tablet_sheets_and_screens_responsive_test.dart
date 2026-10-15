import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:salamlearn/data/local/hive_boxes.dart';
import 'package:salamlearn/data/models/class_section.dart';
import 'package:salamlearn/data/models/parent_account.dart';
import 'package:salamlearn/data/remote/pin_reset_mailer.dart';
import 'package:salamlearn/logic/auth/credential_hasher.dart';
import 'package:salamlearn/logic/auth/session.dart';
import 'package:salamlearn/logic/learner/learner_xp_provider.dart';
import 'package:salamlearn/logic/learner/noor_energy_provider.dart';
import 'package:salamlearn/logic/onboarding/onboarding_checks.dart';
import 'package:salamlearn/logic/recent_module_provider.dart';
import 'package:salamlearn/logic/teacher/teacher_providers.dart';
import 'package:salamlearn/ui/auth/forgot_pin_sheet.dart';
import 'package:salamlearn/ui/core_modules/custom_lesson_detail_screen.dart';
import 'package:salamlearn/ui/onboarding/splash_screen.dart';
import 'package:salamlearn/ui/settings/change_password_screen.dart';
import 'package:salamlearn/ui/student_hub/hub_info_sheet.dart';
import 'package:salamlearn/ui/student_hub/mascot_welcome_overlay.dart';
import 'package:salamlearn/ui/student_hub/noor_energy_info_sheet.dart';
import 'package:salamlearn/ui/student_hub/noor_energy_resting_sheet.dart';
import 'package:salamlearn/ui/student_hub/notifications_sheet.dart';
import 'package:salamlearn/ui/student_hub/tutorial/mascot_tutorial_overlay.dart';
import 'package:salamlearn/ui/teacher_dashboard/archived_classes_screen.dart';
import 'package:salamlearn/ui/teacher_dashboard/cast_screen.dart';
import 'package:salamlearn/ui/teacher_dashboard/greeting_match_cast_screen.dart';

import '../test_helpers/hive_test_setup.dart';
import '../test_helpers/responsive_harness.dart';

class _Session extends SessionNotifier {
  @override
  SessionState build() => const SessionState(
    activeRole: UserRole.parent,
    activeParentId: 'parent-1',
    pinVerified: true,
  );

  @override
  ({String? email, String name}) activeGrownUpContact() =>
      (email: 'parent@example.com', name: 'Aisha');
}

class _TeacherSession extends SessionNotifier {
  @override
  SessionState build() => const SessionState(
    activeRole: UserRole.asatidz,
    activeTeacherId: 'teacher-1',
    pinVerified: true,
  );
}

class _Energy extends NoorEnergyNotifier {
  _Energy(this._current);
  final int _current;

  @override
  NoorEnergyState build() => NoorEnergyState(current: _current, maxEnergy: 5);
}

class _Streak extends LearnerStreakNotifier {
  @override
  int build() => 4;
}

class _Xp extends LearnerXpNotifier {
  @override
  int build() => 120;
}

class _NoClass extends TeacherClassController {
  @override
  ClassSection? build() => null;
}

class _Mailer extends PinResetMailer {
  @override
  Future<bool> sendCode({
    required String toEmail,
    required String name,
    required String code,
  }) async => true;
}

/// The smaller screens, sheets and overlays not covered elsewhere, on
/// tablet windows in both orientations and at large text: no overflow, no
/// word broken mid-word, everything reachable by scrolling.
void main() {
  late Directory tempDir;
  const sizes = [
    Size(600, 960),
    Size(800, 1280),
    Size(1280, 800),
    Size(1024, 768),
  ];

  setUpAll(loadRealFonts);
  setUp(() async {
    tempDir = await setUpTestHive();
    final salt = CredentialHasher.generateSalt();
    await Hive.box<ParentAccount>(HiveBoxes.parents).put(
      'parent-1',
      ParentAccount(
        id: 'parent-1',
        fullName: 'Aisha Santos',
        email: 'aisha@example.com',
        passwordHash: CredentialHasher.hash('OldPass1!', salt),
        passwordSalt: salt,
        pinHash: 'x',
        pinSalt: 'y',
        createdAt: DateTime(2026, 1, 1),
      ),
    );
  });
  tearDown(() async => tearDownTestHive(tempDir));

  Future<void> pumpAt(
    WidgetTester tester,
    Size size,
    double scale,
    Widget home, {
    SessionNotifier Function() session = _Session.new,
    int energy = 3,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => home),
        GoRoute(path: '/get-started', builder: (_, _) => const SizedBox()),
        GoRoute(path: '/hub', builder: (_, _) => const SizedBox()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          sessionProvider.overrideWith(session),
          noorEnergyProvider.overrideWith(() => _Energy(energy)),
          learnerStreakProvider.overrideWith(_Streak.new),
          learnerXpProvider.overrideWith(_Xp.new),
          launchChecksProvider.overrideWith(
            (ref) async =>
                const LaunchCheckResult(assetsIntact: true, storageOk: true),
          ),
          activeClassNameProvider.overrideWithValue('Grade 1 - A'),
          teacherRosterProvider.overrideWithValue([
            {'learnerId': 'l1', 'name': 'Muhammad Abdurrahman Al-Farouqi'},
            {'learnerId': 'l2', 'name': 'Yusuf'},
          ]),
          teacherClassControllerProvider.overrideWith(_NoClass.new),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  Future<void> finish(WidgetTester tester, String label) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull, reason: 'closing $label');
  }

  /// A blank page with one button that opens [open] — how sheets are
  /// shown in the app.
  Widget opener(void Function(BuildContext) open) => Scaffold(
    body: Builder(
      builder: (context) =>
          TextButton(onPressed: () => open(context), child: const Text('open')),
    ),
  );

  final sheets = <String, void Function(BuildContext)>{
    'Noor Energy info': showNoorEnergyInfoSheet,
    'streak info': showStreakInfoSheet,
    'stars info': showStarsInfoSheet,
    'Noor Energy resting': showNoorEnergyRestingSheet,
    'notifications': NotificationsSheet.show,
    'forgot PIN': (c) =>
        showForgotPinSheet(c, accentColor: Colors.teal, mailer: _Mailer()),
  };

  for (final scale in responsiveTextScales) {
    testWidgets('hub and PIN sheets fit tablets, text x$scale', (tester) async {
      for (final size in sizes) {
        for (final MapEntry(key: name, value: open) in sheets.entries) {
          final label =
              '$name ${size.width.toInt()}x${size.height.toInt()} @ x$scale';
          await pumpAt(
            tester,
            size,
            scale,
            opener(open),
            energy: name == 'Noor Energy resting' ? 0 : 3,
          );
          final before = find.byWidgetPredicate((_) => true).evaluate().length;
          await tester.tap(find.text('open'));
          await settle(tester);
          expect(
            find.byWidgetPredicate((_) => true).evaluate().length,
            greaterThan(before + 20),
            reason: '$label: sheet did not open',
          );
          await scrollThroughChecking(tester, label);
          await finish(tester, label);
        }
      }
    });

    testWidgets('change password, custom lesson and archived classes fit '
        'tablets, text x$scale', (tester) async {
      for (final size in sizes) {
        final at = '${size.width.toInt()}x${size.height.toInt()} @ x$scale';
        for (final (name, screen, session) in [
          ('change password', const ChangePasswordScreen(), _Session.new),
          (
            'custom lesson',
            const CustomLessonDetailScreen(lessonId: 'missing'),
            _Session.new,
          ),
          (
            'archived classes',
            const ArchivedClassesScreen(),
            _TeacherSession.new,
          ),
        ]) {
          await pumpAt(tester, size, scale, screen, session: session);
          await scrollThroughChecking(tester, '$name $at');
          await finish(tester, '$name $at');
        }
      }
    });
  }

  testWidgets('splash, mascot overlays and casting fit tablets', (
    tester,
  ) async {
    for (final size in sizes) {
      final at = '${size.width.toInt()}x${size.height.toInt()}';
      for (final (name, screen) in <(String, Widget)>[
        ('splash', const SplashScreen()),
        (
          'mascot welcome',
          MascotWelcomeOverlay(learnerName: 'Amina', onDismiss: () {}),
        ),
        (
          'mascot tutorial',
          Stack(
            children: [
              MascotTutorialOverlay(learnerName: 'Amina', onFinished: () {}),
            ],
          ),
        ),
        ('cast', const CastScreen()),
        ('greeting cast', const GreetingMatchCastScreen()),
      ]) {
        await pumpAt(tester, size, 1, Scaffold(body: screen));
        expect(tester.takeException(), isNull, reason: '$name $at');
        expect(brokenWords(tester), isEmpty, reason: '$name $at');
        await finish(tester, '$name $at');
      }
    }
  });
}
