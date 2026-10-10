import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/logic/auth/session.dart';
import 'package:salamlearn/logic/connectivity/internet_access.dart';
import 'package:salamlearn/ui/auth/learner_setup_screen.dart';
import 'package:salamlearn/ui/parent_dashboard/edit_child_profile_screen.dart';

import '../../test_helpers/hive_test_setup.dart';
import '../../test_helpers/responsive_harness.dart';

/// Create Child Profile (all three steps) and Edit Child Profile at every
/// window size and text scale: no overflow, no word broken mid-word, every
/// part of the form reachable by scrolling.
void main() {
  late Directory tempDir;
  late ProviderContainer container;

  setUpAll(loadRealFonts);

  setUp(() async {
    tempDir = await setUpTestHive();
    container = ProviderContainer(
      overrides: [internetAccessProvider.overrideWithValue(() async => true)],
    );
    final notifier = container.read(sessionProvider.notifier);
    // A real parent account with a password, so step 2's password check
    // passes for real.
    notifier.stageParentRegistration(
      fullName: 'Parent Test',
      email: 'parent@example.com',
      password: 'Password123',
    );
    await notifier.createPin('1234');
    // Deliberately long name for the edit screen's header and name field.
    await notifier.createLearner(
      name: 'Muhammad Abdurrahman Al-Farouqi',
      age: 7,
      username: 'muhammad_af',
    );
  });

  tearDown(() async {
    container.dispose();
    await tearDownTestHive(tempDir);
  });

  Future<void> pumpAt(
    WidgetTester tester,
    Widget screen,
    Size size,
    double scale,
  ) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          key: UniqueKey(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: screen,
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> enter(WidgetTester tester, int fieldIndex, String text) async {
    final field = find.byType(TextField).at(fieldIndex);
    await scrollUntilFound(tester, field, towardsTop: true);
    await tester.enterText(field, text);
    await tester.pump();
  }

  Future<void> tapButton(WidgetTester tester, String label) async {
    await tester.tap(find.text(label));
    await settle(tester);
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  for (final scale in responsiveTextScales) {
    testWidgets('Create child profile: all 3 steps fit, text x$scale', (
      tester,
    ) async {
      for (final size in responsiveSizes) {
        final label = '${size.width.toInt()}x${size.height.toInt()} @ x$scale';
        await pumpAt(tester, const LearnerSetupScreen(), size, scale);
        expect(find.text('Step 1 of 3'), findsOneWidget, reason: label);
        await scrollThroughChecking(tester, 'Create step 1 $label');

        await enter(tester, 0, 'Muhammad');
        await enter(tester, 2, 'Al-Farouqi');
        final grade = find.byType(DropdownButtonFormField<String>);
        await scrollUntilFound(tester, grade, towardsTop: true);
        await tester.tap(grade);
        await settle(tester);
        await tester.tap(find.text('Grade 1').last);
        await settle(tester);
        await tapButton(tester, 'Next: Profile details');
        expect(find.text('Step 2 of 3'), findsOneWidget, reason: label);
        await scrollThroughChecking(tester, 'Create step 2 $label');

        await enter(tester, 0, 'muhammad_af2');
        await enter(tester, 1, 'Password123');
        await tapButton(tester, 'Next');
        expect(find.text('Step 3 of 3'), findsOneWidget, reason: label);
        await scrollThroughChecking(tester, 'Create step 3 $label');
      }
      await finish(tester);
    });

    testWidgets('Edit child profile fits, text x$scale', (tester) async {
      for (final size in responsiveSizes) {
        final label = '${size.width.toInt()}x${size.height.toInt()} @ x$scale';
        await pumpAt(tester, const EditChildProfileScreen(), size, scale);
        expect(
          find.textContaining('Muhammad Abdurrahman Al-Farouqi'),
          findsWidgets,
          reason: label,
        );
        await scrollThroughChecking(tester, 'Edit $label');
        // The danger zone at the very bottom was reached.
        expect(find.text('Delete Child Profile'), findsOneWidget);
      }
      await finish(tester);
    });
  }
}
