import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:salamlearn/data/curriculum_data.dart';
import 'package:salamlearn/data/models/learner_profile.dart';
import 'package:salamlearn/logic/auth/session.dart';
import 'package:salamlearn/logic/learner/learner_xp_provider.dart';
import 'package:salamlearn/logic/learner/noor_energy_provider.dart';
import 'package:salamlearn/logic/learner/tutorial_progress_provider.dart';
import 'package:salamlearn/ui/core_modules/lesson_complete_screen.dart';
import 'package:salamlearn/ui/student_hub/adventure_map_bottom_nav.dart';
import 'package:salamlearn/ui/student_hub/adventure_map_screen.dart';
import 'package:salamlearn/ui/student_hub/backpack_screen.dart';
import 'package:salamlearn/ui/student_hub/destination_levels_sheet.dart';
import 'package:salamlearn/ui/student_hub/hub_bottom_nav.dart';
import 'package:salamlearn/ui/student_hub/profile_screen.dart';
import 'package:salamlearn/ui/teacher_dashboard/teacher_dashboard_screen.dart'
    show ProgressionOverrideNotifier, progressionOverrideProvider;

import '../../test_helpers/hive_test_setup.dart';
import '../../test_helpers/responsive_harness.dart';

class _NoLearnerSession extends SessionNotifier {
  @override
  SessionState build() => const SessionState();
}

class _LearnerSession extends SessionNotifier {
  @override
  SessionState build() => SessionState(
    learner: LearnerProfile(name: 'Amina', age: 6, id: 'learner-1'),
  );
}

class _Xp extends LearnerXpNotifier {
  @override
  int build() => 0;
}

class _Energy extends NoorEnergyNotifier {
  @override
  NoorEnergyState build() => const NoorEnergyState(current: 5, maxEnergy: 5);
}

class _TutorialSeen extends TutorialSeenNotifier {
  @override
  bool build() => true;
}

class _AllUnlocked extends ProgressionOverrideNotifier {
  @override
  bool build() => true;
}

/// Learner Hub on tablet windows, portrait and landscape: Me tab, Backpack,
/// the stage sheet and the map fit without overflow, and the floating nav
/// and stage sheet keep a phone-like width instead of stretching.
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

  setUpAll(loadRealFonts);
  setUp(() async => tempDir = await setUpTestHive());
  tearDown(() async => tearDownTestHive(tempDir));

  Future<void> pumpAt(
    WidgetTester tester,
    Size size,
    double scale,
    Widget home, {
    SessionNotifier Function() session = _NoLearnerSession.new,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/',
      routes: [GoRoute(path: '/', builder: (_, _) => home)],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: [
          sessionProvider.overrideWith(session),
          learnerXpProvider.overrideWith(_Xp.new),
          noorEnergyProvider.overrideWith(_Energy.new),
          tutorialSeenProvider.overrideWith(_TutorialSeen.new),
          progressionOverrideProvider.overrideWith(_AllUnlocked.new),
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

  for (final scale in responsiveTextScales) {
    testWidgets('Me tab and Backpack fit tablets, text x$scale', (
      tester,
    ) async {
      for (final size in sizes) {
        final label = '${size.width.toInt()}x${size.height.toInt()} @ x$scale';
        await pumpAt(tester, size, scale, const ProfileScreen());
        await scrollThroughChecking(tester, 'Me $label');
        await finish(tester, 'Me $label');

        await pumpAt(tester, size, scale, const BackpackScreen());
        await scrollThroughChecking(tester, 'Backpack $label');
        await finish(tester, 'Backpack $label');
      }
    });

    testWidgets('stage sheet fits tablets at phone width, text x$scale', (
      tester,
    ) async {
      for (final size in sizes) {
        final label = '${size.width.toInt()}x${size.height.toInt()} @ x$scale';
        await pumpAt(
          tester,
          size,
          scale,
          Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => DestinationLevelsSheet.show(
                  context,
                  destination: curriculum.first,
                  completedLessons: ValueNotifier(const <String>{}),
                  noorEnergy: 5,
                  onStartLesson: (_, _) {},
                ),
                child: const Text('open'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await settle(tester);
        final board = find.descendant(
          of: find.byType(DestinationLevelsSheet),
          matching: find.byType(ConstrainedBox),
        );
        expect(
          tester.getSize(board.first).width,
          lessThanOrEqualTo(640),
          reason: label,
        );
        await scrollThroughChecking(tester, 'stage sheet $label');
        await finish(tester, 'stage sheet $label');
      }
    });
  }

  for (final scale in responsiveTextScales) {
    testWidgets('lesson complete fits tablets, text x$scale', (tester) async {
      for (final size in sizes) {
        final label = '${size.width.toInt()}x${size.height.toInt()} @ x$scale';
        await pumpAt(
          tester,
          size,
          scale,
          LessonCompleteScreen(
            lesson: curriculum.first.lessons.first,
            xpEarned: 20,
            onContinue: () {},
          ),
        );
        await tester.pump(const Duration(seconds: 2));
        await scrollThroughChecking(tester, 'lesson complete $label');
        await finish(tester, 'lesson complete $label');
      }
    });
  }

  testWidgets('map and floating nav fit tablets', (tester) async {
    for (final size in sizes) {
      final label = '${size.width.toInt()}x${size.height.toInt()}';
      await pumpAt(
        tester,
        size,
        1,
        const AdventureMapScreen(),
        session: _LearnerSession.new,
      );
      expect(tester.takeException(), isNull, reason: 'map $label');
      expect(brokenWords(tester), isEmpty, reason: 'map $label');
      await finish(tester, 'map $label');

      await pumpAt(
        tester,
        size,
        1,
        Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: AdventureMapBottomNav(
              active: HubTab.home,
              onHomeTap: () {},
              onBackpackTap: () {},
              onProfileTap: () {},
            ),
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(AdventureMapBottomNav)).width,
        size.width,
      );
      final board = find.descendant(
        of: find.byType(AdventureMapBottomNav),
        matching: find.byType(ConstrainedBox),
      );
      expect(
        tester.getSize(board.first).width,
        lessThanOrEqualTo(560),
        reason: 'nav $label',
      );
      await finish(tester, 'nav $label');
    }
  });
}
