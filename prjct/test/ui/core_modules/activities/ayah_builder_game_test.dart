import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:salamlearn/data/curriculum_data.dart';
import 'package:salamlearn/ui/core_modules/activities/ayah_builder_game.dart';

void main() {
  // The game is laid out against the prototype's 402x874 phone frame and
  // scaled to fit, so matching the surface keeps the scale exactly 1.
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!;
    view.devicePixelRatio = 1.0;
    view.physicalSize = const Size(402, 874);
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Widget host(int index, {void Function(int, double, int)? onComplete}) =>
      MaterialApp(
        home: Scaffold(
          body: AyahBuilderGame(
            sessions: ayahBuilderSessions,
            initialIndex: index,
            xp: 50,
            onComplete: onComplete ?? (_, _, _) {},
          ),
        ),
      );

  Future<void> toPuzzle(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('ab-play')));
    await tester.pump(const Duration(milliseconds: 600));
    // I'm ready appears after a 5s read of the board.
    await tester.pump(const Duration(milliseconds: 5600));
    await tester.tap(find.bySemanticsLabel("I'm ready"));
    // 3-2-1 countdown, then the fade into the listen screen.
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 600));
    // Start building only appears once the ayah has finished playing.
    expect(find.bySemanticsLabel('Start building'), findsNothing);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    await tester.tap(find.bySemanticsLabel('Start building'));
    await tester.pump(const Duration(milliseconds: 600));
  }

  Future<void> drag(WidgetTester tester, String word, int slot) async {
    final from = tester.getCenter(find.text(word).last);
    final to = tester.getCenter(find.text('$slot'));
    await tester.dragFrom(from, to - from);
    await tester.pump(const Duration(milliseconds: 400));
  }

  test('seven sessions distributed across Stages 2-7 as in the prototype', () {
    expect(ayahBuilderSessions.map((s) => s.stage), [2, 3, 4, 5, 6, 6, 7]);
    expect(ayahBuilderSessions.map((s) => s.words.length), [
      4,
      4,
      5,
      4,
      4,
      4,
      3,
    ]);
  });

  testWidgets('start screen shows the session; Play opens the how-to board', (
    tester,
  ) async {
    await tester.pumpWidget(host(6));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Session 7'), findsOneWidget);
    expect(find.text('Al-Kawthar'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ab-play')));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.bySemanticsLabel("I'm ready"), findsNothing);
    await tester.pump(const Duration(milliseconds: 5600));
    expect(find.bySemanticsLabel("I'm ready"), findsOneWidget);
    expect(find.text("Let's build Al-Kawthar together!"), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ab-back')));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const ValueKey('ab-play')), findsOneWidget);
  });

  testWidgets('five-word puzzle keeps 4-word card size in two rows', (
    tester,
  ) async {
    await tester.pumpWidget(host(2));
    await tester.pump(const Duration(milliseconds: 600));
    await toPuzzle(tester);
    final one = tester.getRect(find.text('1'));
    final four = tester.getRect(find.text('4'));
    expect(four.top, greaterThan(one.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('dropping on an already-filled slot is not an error', (
    tester,
  ) async {
    await tester.pumpWidget(host(6));
    await tester.pump(const Duration(milliseconds: 600));
    await toPuzzle(tester);

    final words = ayahBuilderSessions[6].words;
    final slot1 = tester.getCenter(find.text('1'));
    await drag(tester, words[0].text, 1);
    final from = tester.getCenter(find.text(words[1].text).last);
    await tester.dragFrom(from, slot1 - from);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Oops! Try again!'), findsNothing);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('wrong drop says oops; building the ayah reaches the reward', (
    tester,
  ) async {
    final results = <List<num>>[];
    await tester.pumpWidget(
      host(6, onComplete: (xp, acc, err) => results.add([xp, acc, err])),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await toPuzzle(tester);

    final words = ayahBuilderSessions[6].words;
    await drag(tester, words[1].text, 1);
    expect(find.text('Oops! Try again!'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1400));

    for (var i = 0; i < words.length; i++) {
      await drag(tester, words[i].text, i + 1);
    }
    // Tests have no audio plugin, so the recitation times out (1s) before
    // the fallback word beat runs.
    await tester.pump(const Duration(seconds: 5));
    expect(find.bySemanticsLabel("Masha'Allah!"), findsOneWidget);
    // One mistake earns 2 of the 3 stars; the summary recaps the round.
    expect(find.text('You earned 2 stars · 2 total'), findsOneWidget);
    expect(find.text('3 of 3 words'), findsOneWidget);
    expect(find.text('1 mistake'), findsOneWidget);
    expect(find.text('75%'), findsOneWidget);
    expect(find.byKey(const ValueKey('ab-back')), findsNothing);

    await tester.tap(find.text('Finish'));
    await tester.pump();
    expect(results, [
      [50, 75.0, 1],
    ]);
  });
}
