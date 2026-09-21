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
    await tester.tap(find.text("I'm ready"));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('Start building'));
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

  testWidgets('start screen shows the session; Play opens the how-to card', (
    tester,
  ) async {
    await tester.pumpWidget(host(6));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Session 7'), findsOneWidget);
    expect(find.text('Al-Kawthar'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ab-play')));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Drag the words into the correct order.'), findsOneWidget);
    expect(find.text("Let's build Al-Kawthar together!"), findsOneWidget);
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
    await tester.pump(const Duration(seconds: 3));
    expect(find.text("Masha'Allah!"), findsOneWidget);
    expect(find.text('You earned 1 star · 1 total'), findsOneWidget);

    await tester.tap(find.text('Finish'));
    await tester.pump();
    expect(results, [
      [50, 75.0, 1],
    ]);
  });
}
