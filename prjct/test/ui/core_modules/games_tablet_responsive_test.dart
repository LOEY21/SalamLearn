import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/data/curriculum_data.dart';
import 'package:salamlearn/logic/auth/session.dart';
import 'package:salamlearn/logic/learner/learner_xp_provider.dart';
import 'package:salamlearn/ui/core_modules/game_ui_audio.dart';
import 'package:salamlearn/ui/core_modules/lesson_player_screen.dart';

import '../../test_helpers/hive_test_setup.dart';
import '../../test_helpers/responsive_harness.dart';

class _SilentUi implements GameUiAudioPlayback {
  @override
  void tap() {}

  @override
  void levelComplete() {}

  @override
  void starAward() {}
}

class _Xp extends LearnerXpNotifier {
  @override
  int build() => 0;

  @override
  void addXp(int amount) {}
}

class _NoLearner extends SessionNotifier {
  @override
  SessionState build() => const SessionState();
}

/// Every lesson's game opened through the lesson player on tablet windows.
/// Portrait too: Android 16+ ignores the games' landscape lock on large
/// screens, so a tablet can show them either way.
void main() {
  late Directory tempDir;
  const sizes = [
    Size(800, 1280),
    Size(768, 1024),
    Size(1280, 800),
    Size(1024, 768),
  ];

  setUpAll(loadRealFonts);
  setUp(() async => tempDir = await setUpTestHive());
  tearDown(() async => tearDownTestHive(tempDir));

  for (final destination in curriculum) {
    testWidgets('destination ${destination.id} games open on tablets', (
      tester,
    ) async {
      for (final lesson in destination.lessons) {
        for (final size in sizes) {
          final label =
              '${lesson.title} ${size.width.toInt()}x${size.height.toInt()}';
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            ProviderScope(
              key: UniqueKey(),
              overrides: [
                learnerXpProvider.overrideWith(_Xp.new),
                sessionProvider.overrideWith(_NoLearner.new),
              ],
              child: MaterialApp(
                home: LessonPlayerScreen(
                  lesson: lesson,
                  destinationId: destination.id,
                  onClose: () {},
                  uiAudio: _SilentUi(),
                ),
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(seconds: 2));
          expect(tester.takeException(), isNull, reason: label);
          expect(brokenWords(tester), isEmpty, reason: label);
          // The game itself mounted, not just an empty player.
          final built = find.descendant(
            of: find.byType(LessonPlayerScreen),
            matching: find.byWidgetPredicate((_) => true),
          );
          expect(built.evaluate().length, greaterThan(40), reason: label);
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 1));
          expect(tester.takeException(), isNull, reason: 'closing $label');
        }
      }
    });
  }
}
