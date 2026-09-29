import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/logic/auth/session.dart';
import 'package:salamlearn/logic/connectivity/internet_access.dart';
import 'package:salamlearn/ui/widgets/delete_account_dialog.dart';

import '../../test_helpers/hive_test_setup.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await setUpTestHive();
  });

  tearDown(() async {
    await tearDownTestHive(tempDir);
  });

  testWidgets('warns, asks for the password and rejects a wrong one', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [internetAccessProvider.overrideWithValue(() async => true)],
    );
    addTearDown(container.dispose);
    await tester.runAsync(() async {
      final notifier = container.read(sessionProvider.notifier);
      notifier.stageParentRegistration(
        fullName: 'Aisha',
        email: 'aisha@example.com',
        password: 'Secret#123',
      );
      await notifier.createPin('1234');
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => showDeleteAccountDialog(context, ref),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Delete your account?'), findsOneWidget);

    await tester.tap(find.text('Delete account'));
    await tester.pump();
    expect(find.text('Enter your password'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'wrong');
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    expect(find.text('Incorrect password'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Delete your account?'), findsNothing);
    expect(container.read(sessionProvider).activeParentId, isNotNull);
  });
}
