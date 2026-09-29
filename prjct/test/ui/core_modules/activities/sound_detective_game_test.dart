import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/data/curriculum_data.dart';
import 'package:salamlearn/data/models/curriculum/curriculum_models.dart';
import 'package:salamlearn/ui/core_modules/activities/sound_detective_game.dart';

const _alifToKha = ['ا', 'ب', 'ت', 'ث', 'ج', 'ح', 'خ'];

void main() {
  test('forest music is bundled for offline play', () async {
    final data = await rootBundle.load(
      'assets/audio/sound_detective/forest_ambient.mp3',
    );
    expect(data.lengthInBytes, greaterThan(0));
  });

  test('all 28 detective letters have playable recordings', () async {
    expect(soundDetectiveLetterAudio.length, 28);
    expect(soundDetectiveLetterAudio.values.toSet().length, 28);
    for (final asset in soundDetectiveLetterAudio.values) {
      final data = await rootBundle.load(asset);
      expect(data.lengthInBytes, greaterThan(0), reason: asset);
    }
  });
  test('each session lands on its designated lesson', () {
    Activity actFor(String id) => curriculum
        .expand((d) => d.lessons)
        .expand((l) => l.activities)
        .firstWhere((a) => a.id == id);
    for (final (id, session) in [
      ('dest1-s4-act', SoundDetectiveSession.alifToKha),
      ('dest2-s5-act', SoundDetectiveSession.dalToDad),
      ('dest3-s5-act', SoundDetectiveSession.taToQaf),
      ('dest4-s4-act', SoundDetectiveSession.kafToYa),
    ]) {
      expect(actFor(id).type, ActivityType.soundDetective);
      expect(actFor(id).soundSession, session);
    }
  });

  /// Plays Alif to Kha through, missing the first [misses] questions once
  /// each, and returns a callback that taps Continue on the ending.
  Future<Future<(int, double, int)?> Function()> playRound(
    WidgetTester tester,
    int misses,
  ) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    (int, double, int)? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SoundDetectiveGame(
            session: SoundDetectiveSession.alifToKha,
            xp: 30,
            random: math.Random(1),
            musicEnabled: false,
            onComplete: (xp, acc, errors) => result = (xp, acc, errors),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1300));
    expect(find.text('Alif to Kha'), findsWidgets);
    // The forest backdrop fills the whole screen, edge to edge.
    expect(
      tester.getSize(
        find.byWidgetPredicate((w) => w is FittedBox && w.fit == BoxFit.cover),
      ),
      const Size(402, 874),
    );

    await tester.tap(find.byKey(const ValueKey('sd-play')));
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.text('How to Play'), findsOneWidget);
    // Let's Go waits five seconds before it shows.
    expect(find.byKey(const ValueKey('sd-go')), findsNothing);
    await tester.pump(const Duration(seconds: 4));
    expect(find.byKey(const ValueKey('sd-go')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('sd-go')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('How to Play'), findsNothing);
    // 3-2-1-Go!, then the round begins.
    expect(find.text('3'), findsWidgets);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('2'), findsWidgets);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Go!'), findsWidgets);
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pump(const Duration(milliseconds: 1100));
    expect(find.text('Go!'), findsNothing);

    int slotWith(String letter) => [0, 1, 2].firstWhere(
      (i) => find
          .descendant(
            of: find.byKey(ValueKey('sd-slot-$i')),
            matching: find.byWidgetPredicate(
              (w) => w is Semantics && w.properties.label == letter,
            ),
          )
          .evaluate()
          .isNotEmpty,
    );

    for (final (qi, letter) in _alifToKha.indexed) {
      expect(find.text('Q${qi + 1} of 7'), findsOneWidget);
      final right = slotWith(letter);
      if (qi < misses) {
        await tester.tap(find.byKey(ValueKey('sd-slot-${(right + 1) % 3}')));
        await tester.pump();
        expect(find.text('Try again!'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 3100));
        expect(find.text('Try again!'), findsNothing);
      }
      await tester.tap(find.byKey(ValueKey('sd-slot-$right')));
      await tester.pump();
      expect(find.text('Correct!'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('${qi + 1}/7'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 3100));
      await tester.pump(const Duration(milliseconds: 1100));
    }

    expect(find.text('Session 1 Complete'), findsOneWidget);
    expect(result, isNull);
    return () async {
      await tester.tap(find.byKey(const ValueKey('sd-continue')));
      await tester.pump();
      return result;
    };
  }

  testWidgets('high score: cheering ending, then continue', (tester) async {
    final finish = await playRound(tester, 1);
    expect(find.text('MUMTAZ!'), findsOneWidget);
    expect(find.text('Good Try!'), findsNothing);
    expect(await finish(), (30, 7 / 8 * 100, 1));
  });

  testWidgets('low score: encouraging ending names the missed letters', (
    tester,
  ) async {
    final finish = await playRound(tester, 3);
    expect(find.text('Good Try!'), findsOneWidget);
    expect(find.text('MUMTAZ!'), findsNothing);
    expect(find.text("Let's practise these:"), findsOneWidget);
    expect(find.text('ا  ب  ت'), findsOneWidget);
    expect(await finish(), (30, 7 / 10 * 100, 3));
  });

  testWidgets('back steps to the previous screen; only home leaves', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    var exited = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SoundDetectiveGame(
            session: SoundDetectiveSession.alifToKha,
            xp: 30,
            random: math.Random(1),
            musicEnabled: false,
            onComplete: (_, _, _) {},
            onExit: () => exited++,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1500));
    Future<void> tapKey(String k) async {
      await tester.tap(find.byKey(ValueKey(k)).last);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 700));
    }

    await tapKey('sd-play');
    await tester.pump(const Duration(seconds: 5));
    await tapKey('sd-go');
    expect(find.text('Q1 of 7'), findsOneWidget);

    await tapKey('sd-back'); // game -> How to Play
    expect(find.text('How to Play'), findsOneWidget);
    await tapKey('sd-back'); // How to Play -> start
    expect(find.byKey(const ValueKey('sd-play')), findsOneWidget);
    expect(exited, 0);

    await tapKey('sd-home'); // only Home quits to the map
    expect(exited, 1);
  });
}
