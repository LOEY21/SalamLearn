import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:salamlearn/data/curriculum_data.dart';
import 'package:salamlearn/data/local/hive_boxes.dart';
import 'package:salamlearn/data/models/progress_record.dart';
import 'package:salamlearn/logic/auth/session.dart';
import 'package:salamlearn/logic/connectivity/internet_access.dart';
import 'package:salamlearn/logic/parent/children_providers.dart';
import 'package:salamlearn/logic/progress_providers.dart';
import 'package:salamlearn/ui/parent_dashboard/parent_dashboard_screen.dart';

import '../../test_helpers/hive_test_setup.dart';
import '../../test_helpers/responsive_harness.dart';

void main() {
  late Directory tempDir;
  late ProviderContainer container;

  setUpAll(() async {
    await loadRealFonts();
    // Settings shows shared account cards that read FirebaseAuth; a mocked
    // core app lets them build (signed out) like on a fresh device.
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() async {
    tempDir = await setUpTestHive();
    container = ProviderContainer(
      overrides: [
        internetAccessProvider.overrideWithValue(() async => true),
        // Live Firestore listeners — no Firebase app exists in widget tests.
        accountStreamProvider.overrideWith((ref) => Stream.value(true)),
        learnerSyncProvider.overrideWith((ref) => const Stream.empty()),
        parentEnrollmentSyncProvider.overrideWith(
          (ref) => const Stream.empty(),
        ),
        parentProgressSyncProvider.overrideWith((ref) => const Stream.empty()),
      ],
    );
    final notifier = container.read(sessionProvider.notifier);
    notifier.selectRole(UserRole.parent);
    await notifier.createPin('1234');
    // Deliberately long name — the case that used to get "…"-truncated.
    final child = await notifier.createLearner(
      name: 'Muhammad Abdurrahman Al-Farouqi',
      age: 7,
      username: 'muhammad_af',
    );

    // Real progress across three adventures — one weak (<60%) so the
    // "Try this at home" note and "Needs review" rows render too.
    final progress = Hive.box<ProgressRecord>(HiveBoxes.progress);
    final now = DateTime.now();
    final scores = [92.0, 74.0, 45.0];
    for (var d = 0; d < 3; d++) {
      final destination = curriculum[d];
      for (var k = 0; k < 2; k++) {
        final id = 'r$d$k';
        await progress.put(
          id,
          ProgressRecord(
            id: id,
            learnerId: child.id!,
            moduleId: '${destination.id}',
            strokeAccuracyPct: scores[d],
            sequencingErrors: d + k,
            timeOnTaskSeconds: 300 + 60 * d,
            completedAt: now.subtract(Duration(days: d + k)),
            lessonId: destination.lessons[k].id,
          ),
        );
      }
    }
  });

  tearDown(() async {
    container.dispose();
    await tearDownTestHive(tempDir);
  });

  Future<void> pumpAt(WidgetTester tester, Size size, double scale) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          key: ValueKey('$size@$scale@${DateTime.now().microsecond}'),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const ParentDashboardScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  for (final scale in responsiveTextScales) {
    testWidgets('Progress + Profile tabs fit at every size, text x$scale', (
      tester,
    ) async {
      for (final size in responsiveSizes) {
        final label = '${size.width.toInt()}x${size.height.toInt()} @ x$scale';
        await pumpAt(tester, size, scale);
        // Full name shown, never cut with an ellipsis.
        expect(
          find.textContaining('Muhammad Abdurrahman Al-Farouqi'),
          findsWidgets,
          reason: label,
        );
        await scrollThroughChecking(tester, 'Progress $label');

        // Short windows scroll the header away; bring the tabs back.
        await scrollUntilFound(tester, find.text('Profile'), towardsTop: true);
        await tester.tap(find.text('Profile'));
        await settle(tester);
        await scrollThroughChecking(tester, 'Profile $label');
      }
      await finish(tester);
    });

    testWidgets('Settings tab fits at every size, text x$scale', (
      tester,
    ) async {
      for (final size in responsiveSizes) {
        final label = '${size.width.toInt()}x${size.height.toInt()} @ x$scale';
        await pumpAt(tester, size, scale);
        await scrollUntilFound(tester, find.text('Settings'), towardsTop: true);
        await tester.tap(find.text('Settings').last);
        await settle(tester);
        await scrollThroughChecking(tester, 'Settings $label');
      }
      await finish(tester);
    });

    testWidgets('report dialog, adventure detail and game report fit, '
        'text x$scale', (tester) async {
      for (final size in [
        responsiveSizes[0],
        responsiveSizes[2],
        responsiveSizes[5],
        responsiveSizes[7],
      ]) {
        final label = '${size.width.toInt()}x${size.height.toInt()} @ x$scale';

        await pumpAt(tester, size, scale);
        final reportLink = find.text('View Detailed Progress Report');
        await scrollUntilFound(tester, reportLink, towardsTop: false);
        await tester.tap(reportLink);
        await settle(tester);
        expect(find.byTooltip('Close'), findsOneWidget, reason: label);
        await scrollThroughChecking(
          tester,
          'Report dialog $label',
          dragAt: 0.5,
        );

        await pumpAt(tester, size, scale);
        await tapToOpen(
          tester,
          find.text(curriculum[2].name),
          find.text('Adventure detail'),
          reason: 'Adventure detail $label',
        );
        await scrollThroughChecking(tester, 'Adventure detail $label');

        await tapToOpen(
          tester,
          find.textContaining('Tap for feedback'),
          find.text('How grades work'),
          reason: 'Game report $label',
          towardsTop: true,
        );
        await scrollThroughChecking(tester, 'Game report $label', dragAt: 0.8);
      }
      await finish(tester);
    });
  }
}
