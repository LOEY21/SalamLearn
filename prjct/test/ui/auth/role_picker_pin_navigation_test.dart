import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:salamlearn/logic/auth/session.dart';
import 'package:salamlearn/ui/auth/pin_verify_screen.dart';
import 'package:salamlearn/ui/auth/role_picker_screen.dart';

/// A parent account already on this device, so picking Parent goes
/// straight to the PIN screen.
class _FakeSession extends SessionNotifier {
  @override
  SessionState build() => const SessionState(activeParentId: 'parent-1');

  @override
  void selectRole(UserRole role) =>
      state = state.copyWith(activeRole: role, pinVerified: false);
}

void main() {
  testWidgets('PIN screen opens on top of the role picker and Back slides it '
      'back off, revealing the same picker', (tester) async {
    final router = GoRouter(
      initialLocation: '/roles',
      routes: [
        GoRoute(
          path: '/roles',
          builder: (_, _) => const Scaffold(body: RolePickerScreen()),
        ),
        GoRoute(
          path: '/pin/verify',
          builder: (_, _) => const PinVerifyScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith(_FakeSession.new)],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump(const Duration(seconds: 2));

    final picker = tester.state(find.byType(RolePickerScreen));
    await tester.tap(find.text('Parent / Guardian'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Pushed on top: the picker is still in the stack underneath.
    expect(find.text('Parent PIN Gate'), findsOneWidget);
    expect(router.canPop(), isTrue);

    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    // Mid-way the PIN screen is still sliding out over the picker.
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Parent PIN Gate'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Parent PIN Gate'), findsNothing);
    // Same picker instance — returned to, not rebuilt as a new page.
    expect(tester.state(find.byType(RolePickerScreen)), same(picker));
    expect(router.canPop(), isFalse);
  });
}
