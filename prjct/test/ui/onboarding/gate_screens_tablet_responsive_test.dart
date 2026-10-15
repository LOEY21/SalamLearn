import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:salamlearn/logic/auth/session.dart';
import 'package:salamlearn/logic/onboarding/onboarding_checks.dart';
import 'package:salamlearn/ui/auth/auth_choice_screen.dart';
import 'package:salamlearn/ui/auth/consent_screen.dart';
import 'package:salamlearn/ui/auth/email_verification_gate_screen.dart';
import 'package:salamlearn/ui/auth/learner_setup_screen.dart';
import 'package:salamlearn/ui/auth/role_flow_shell.dart';
import 'package:salamlearn/ui/auth/role_picker_screen.dart';
import 'package:salamlearn/ui/auth/teacher_pending_screen.dart';
import 'package:salamlearn/ui/onboarding/get_started_screen.dart';
import 'package:salamlearn/ui/onboarding/onboarding_screen.dart';
import 'package:salamlearn/ui/onboarding/onboarding_shell.dart';

import '../../test_helpers/hive_test_setup.dart';
import '../../test_helpers/responsive_harness.dart';

class _FakeSession extends SessionNotifier {
  _FakeSession(this._role);
  final UserRole _role;

  @override
  SessionState build() => SessionState(activeRole: _role);
}

/// Onboarding (get started, language, consent), role picker and the
/// parent/teacher sign-in and sign-up forms on tablet windows, portrait
/// and landscape — the screens a tablet can now rotate.
void main() {
  late Directory tempDir;
  const sizes = [
    Size(600, 960),
    Size(800, 1280),
    Size(768, 1024),
    Size(960, 600),
    Size(1024, 768),
    Size(1280, 800),
  ];

  setUpAll(() async {
    await loadRealFonts();
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });
  setUp(() async => tempDir = await setUpTestHive());
  tearDown(() async => tearDownTestHive(tempDir));

  Future<void> pumpAt(
    WidgetTester tester,
    Size size,
    double scale,
    String location, {
    UserRole role = UserRole.parent,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: location,
      routes: [
        ShellRoute(
          builder: (_, state, child) =>
              OnboardingShell(location: state.matchedLocation, child: child),
          routes: [
            GoRoute(
              path: '/get-started',
              builder: (_, _) => const GetStartedScreen(),
            ),
            GoRoute(
              path: '/language',
              builder: (_, _) => const OnboardingScreen(),
            ),
            GoRoute(path: '/consent', builder: (_, _) => const ConsentScreen()),
          ],
        ),
        ShellRoute(
          builder: (_, state, child) =>
              RoleFlowShell(location: state.matchedLocation, child: child),
          routes: [
            GoRoute(
              path: '/roles',
              builder: (_, _) => const RolePickerScreen(),
            ),
            GoRoute(
              path: '/auth',
              builder: (_, state) => AuthChoiceScreen(
                startOnSignUp: state.uri.queryParameters['step'] == 'signup',
              ),
            ),
          ],
        ),
        GoRoute(
          path: '/verify-email',
          builder: (_, _) =>
              const EmailVerificationGateScreen(redirectTarget: '/parent'),
        ),
        GoRoute(
          path: '/learner-setup',
          builder: (_, _) => const LearnerSetupScreen(),
        ),
        GoRoute(
          path: '/teacher/pending',
          builder: (_, _) => const TeacherPendingScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          sessionProvider.overrideWith(() => _FakeSession(role)),
          launchChecksProvider.overrideWith(
            (ref) async =>
                const LaunchCheckResult(assetsIntact: true, storageOk: true),
          ),
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
    await settle(tester);
    await tester.pump(const Duration(seconds: 2));
  }

  /// Unmounts the screen and fails if tearing it down throws.
  Future<void> finish(WidgetTester tester, [String label = '']) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull, reason: 'closing $label');
  }

  for (final scale in responsiveTextScales) {
    testWidgets('onboarding and role picker fit tablets, text x$scale', (
      tester,
    ) async {
      for (final size in sizes) {
        final label = '${size.width.toInt()}x${size.height.toInt()} @ x$scale';
        for (final location in [
          '/get-started',
          '/language',
          '/consent',
          '/roles',
        ]) {
          await pumpAt(tester, size, scale, location);
          await scrollThroughChecking(tester, '$location $label');
          await finish(tester, '$location $label');
        }
      }
      await finish(tester);
    });

    testWidgets('sign-in and sign-up fit tablets, text x$scale', (
      tester,
    ) async {
      for (final size in sizes) {
        final label = '${size.width.toInt()}x${size.height.toInt()} @ x$scale';
        for (final role in [UserRole.parent, UserRole.asatidz]) {
          await pumpAt(tester, size, scale, '/auth', role: role);
          await scrollThroughChecking(tester, 'auth choice $role $label');
          await finish(tester, 'auth choice $role $label');
          await pumpAt(tester, size, scale, '/auth?step=signup', role: role);
          await scrollThroughChecking(tester, 'sign-up $role $label');
          await finish(tester, 'sign-up $role $label');
        }
      }
      await finish(tester);
    });

    testWidgets('verify email, child setup and teacher pending fit tablets, '
        'text x$scale', (tester) async {
      for (final size in sizes) {
        final label = '${size.width.toInt()}x${size.height.toInt()} @ x$scale';
        for (final (location, role) in [
          ('/verify-email', UserRole.parent),
          ('/learner-setup', UserRole.parent),
          ('/teacher/pending', UserRole.asatidz),
        ]) {
          await pumpAt(tester, size, scale, location, role: role);
          await scrollThroughChecking(tester, '$location $label');
          await finish(tester, '$location $label');
        }
      }
    });
  }
}
