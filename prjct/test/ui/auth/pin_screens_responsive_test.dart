import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:salamlearn/logic/auth/session.dart';
import 'package:salamlearn/ui/auth/pin_setup_screen.dart';
import 'package:salamlearn/ui/auth/pin_verify_screen.dart';

import '../../test_helpers/responsive_harness.dart';

class _FakeSession extends SessionNotifier {
  _FakeSession(this._role);
  final UserRole _role;

  @override
  SessionState build() => SessionState(activeRole: _role);
}

/// PIN setup and PIN verify, for parents and teachers, at every window
/// size and text scale: no overflow, no word broken mid-word, the whole
/// keypad reachable.
void main() {
  setUpAll(loadRealFonts);
  // Plus landscape phones, where the panel and keypad sit side by side.
  const sizes = [...responsiveSizes, Size(844, 390), Size(640, 360)];

  Future<void> pumpAt(
    WidgetTester tester,
    Size size,
    double scale,
    UserRole role,
    String location,
  ) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: '/pin/verify',
          builder: (_, _) => const PinVerifyScreen(),
        ),
        GoRoute(path: '/pin/setup', builder: (_, _) => const PinSetupScreen()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [sessionProvider.overrideWith(() => _FakeSession(role))],
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
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  for (final scale in responsiveTextScales) {
    testWidgets('PIN verify fits for parent and teacher, text x$scale', (
      tester,
    ) async {
      for (final size in sizes) {
        final label = '${size.width.toInt()}x${size.height.toInt()} @ x$scale';
        for (final (role, title) in [
          (UserRole.parent, 'Parent PIN Gate'),
          (UserRole.asatidz, 'Asatidz PIN Gate'),
        ]) {
          await pumpAt(
            tester,
            size,
            scale,
            role,
            '/pin/verify?redirect=/parent',
          );
          expect(find.text(title), findsOneWidget, reason: label);
          await scrollThroughChecking(tester, '$title $label');
          await scrollUntilFound(
            tester,
            find.text('Forgot PIN?'),
            towardsTop: false,
          );
        }
      }
      await finish(tester);
    });

    testWidgets('PIN setup fits, create and confirm, text x$scale', (
      tester,
    ) async {
      for (final size in sizes) {
        final label = '${size.width.toInt()}x${size.height.toInt()} @ x$scale';
        for (final (role, title) in [
          (UserRole.parent, 'Create Parent PIN'),
          (UserRole.asatidz, 'Create Asatidz PIN'),
        ]) {
          await pumpAt(tester, size, scale, role, '/pin/setup');
          expect(find.text(title), findsOneWidget, reason: label);
          await scrollThroughChecking(tester, '$title $label');

          // First entry flips the screen to the confirm step.
          for (final digit in ['1', '2', '3', '4']) {
            await scrollUntilFound(
              tester,
              find.text(digit),
              towardsTop: digit == '1',
            );
            await tester.tap(find.text(digit));
            await tester.pump();
          }
          await settle(tester);
          await scrollUntilFound(
            tester,
            find.text('Confirm your PIN'),
            towardsTop: true,
          );
          await scrollThroughChecking(tester, 'Confirm $title $label');
        }
      }
      await finish(tester);
    });
  }
}
