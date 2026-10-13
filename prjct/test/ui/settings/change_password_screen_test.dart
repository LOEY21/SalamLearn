import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:salamlearn/data/local/hive_boxes.dart';
import 'package:salamlearn/data/models/parent_account.dart';
import 'package:salamlearn/logic/auth/credential_hasher.dart';
import 'package:salamlearn/logic/auth/session.dart';
import 'package:salamlearn/ui/settings/change_password_screen.dart';

import '../../test_helpers/hive_test_setup.dart';
import '../../test_helpers/responsive_harness.dart';

class _FakeSession extends SessionNotifier {
  @override
  SessionState build() => const SessionState(
    activeRole: UserRole.parent,
    activeParentId: 'parent-1',
    pinVerified: true,
  );
}

ParentAccount get _saved =>
    Hive.box<ParentAccount>(HiveBoxes.parents).get('parent-1')!;

void main() {
  late Directory tempDir;

  setUpAll(loadRealFonts);

  // Not cloud-linked (no firebaseUid), so the change stays on this device
  // and never touches Firebase.
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

  tearDown(() => tearDownTestHive(tempDir));

  Future<void> pumpRow(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith(_FakeSession.new)],
        child: const MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: ChangePasswordRow(),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
    await tester.tap(find.text('Change password'));
    await settle(tester);
  }

  Future<void> fill(
    WidgetTester tester, {
    required String current,
    required String next,
    String? confirm,
  }) async {
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), current);
    await tester.enterText(fields.at(1), next);
    await tester.enterText(fields.at(2), confirm ?? next);
  }

  /// Save does real Hive I/O, which can't finish inside the fake clock.
  Future<void> submit(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.tap(find.widgetWithText(FilledButton, 'Change password'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await settle(tester);
  }

  testWidgets('rejects weak, mismatched and wrong passwords', (tester) async {
    await pumpRow(tester);

    await fill(tester, current: 'OldPass1!', next: 'short', confirm: 'nope');
    await submit(tester);
    expect(find.textContaining("doesn't meet the requirements"), findsOne);
    expect(find.text('Passwords do not match'), findsOneWidget);

    await fill(tester, current: 'WrongPass1!', next: 'NewPass2@');
    await submit(tester);
    expect(find.text('Incorrect password. Try again.'), findsOneWidget);

    final account = _saved;
    expect(
      CredentialHasher.verify(
        'OldPass1!',
        account.passwordSalt!,
        account.passwordHash!,
      ),
      isTrue,
    );
  });

  testWidgets('saves the new password locally', (tester) async {
    await pumpRow(tester);

    await fill(tester, current: 'OldPass1!', next: 'NewPass2@');
    await submit(tester);

    final account = _saved;
    expect(
      CredentialHasher.verify(
        'NewPass2@',
        account.passwordSalt!,
        account.passwordHash!,
      ),
      isTrue,
    );
    expect(account.pinHash, 'x');
    expect(find.text('Password changed successfully'), findsOneWidget);
  });
}
