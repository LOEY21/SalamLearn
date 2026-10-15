import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:salamlearn/data/models/curriculum/curriculum_models.dart';
import 'package:salamlearn/ui/core_modules/activities/good_deed_tree_audio.dart';
import 'package:salamlearn/ui/core_modules/activities/good_deed_tree_game.dart';

void main() {
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!;
    view.devicePixelRatio = 1.0;
    view.physicalSize = const Size(393, 852);
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Widget host(
    GoodDeedTreeSession session,
    void Function(int, double, int) done,
  ) => MaterialApp(
    home: Scaffold(
      body: GoodDeedTreeGame(
        key: ValueKey(session),
        session: session,
        xp: 40,
        onComplete: done,
        onExit: () {},
        audio: _SilentAudio(),
      ),
    ),
  );

  Future<void> wait(WidgetTester tester, int ms) async {
    for (var t = 0; t < ms; t += 100) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('play opens by reading every card, with no input till done', (
    tester,
  ) async {
    final audio = _HeldAudio();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GoodDeedTreeGame(
            session: GoodDeedTreeSession.rootsAndBranches,
            xp: 40,
            onComplete: (_, _, _) {},
            onExit: () {},
            audio: audio,
          ),
        ),
      ),
    );
    await wait(tester, 2500);
    await tester.tap(find.byKey(const ValueKey('gdt-play')));
    await wait(tester, 6500);
    await tester.tap(find.byKey(const ValueKey('gdt-start')));
    await wait(tester, 4500);

    final cards = audio.said.where((c) => c.startsWith('card_')).length;
    expect(cards, 1, reason: 'one name at a time');
    // The garden dims while the names are read, so the cards stand out.
    double focus() => tester
        .widget<AnimatedOpacity>(find.byKey(const ValueKey('gdt-focus')))
        .opacity;
    expect(focus(), 1);
    await tester.tap(find.byKey(const ValueKey('gdt-tree-zone')));
    await wait(tester, 300);
    expect(find.textContaining('Pick a card first'), findsNothing);

    for (var i = 0; i < 10 && !audio.line.isCompleted; i++) {
      audio.line.complete();
      await wait(tester, 200);
    }
    expect(audio.said.where((c) => c.startsWith('card_')).length, 5);
    expect(focus(), 0);
    await tester.tap(find.byKey(const ValueKey('gdt-tree-zone')));
    await wait(tester, 300);
    expect(find.textContaining('Pick a card first'), findsOneWidget);

    // Touching or dragging a card no longer says its name again.
    final card = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('gdt-card-'),
    );
    final g = await tester.startGesture(tester.getCenter(card.first));
    await g.moveBy(const Offset(0, -40));
    await tester.pump(const Duration(milliseconds: 16));
    await g.moveBy(const Offset(0, 40));
    await g.up();
    await wait(tester, 300);
    expect(audio.said.where((c) => c.startsWith('card_')).length, 5);
    await wait(tester, 2000);
  });

  testWidgets("a right answer's line plays out before the next card moves", (
    tester,
  ) async {
    final audio = _HeldPraise();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GoodDeedTreeGame(
            session: GoodDeedTreeSession.rootsAndBranches,
            xp: 40,
            onComplete: (_, _, _) {},
            onExit: () {},
            audio: audio,
          ),
        ),
      ),
    );
    await wait(tester, 2500);
    await tester.tap(find.byKey(const ValueKey('gdt-play')));
    await wait(tester, 6500);
    await tester.tap(find.byKey(const ValueKey('gdt-start')));
    await wait(tester, 6000);

    final cards = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('gdt-card-'),
    );
    Future<void> drag(Finder card, String target) async {
      final from = tester.getCenter(card);
      final to = tester.getCenter(find.byKey(ValueKey(target)));
      final g = await tester.startGesture(from);
      for (var k = 1; k <= 6; k++) {
        await g.moveTo(Offset.lerp(from, to, k / 6)!);
        await tester.pump(const Duration(milliseconds: 16));
      }
      await g.up();
      await wait(tester, 2500);
    }

    // Sort one card right (tree, else bin): its line is now playing.
    final first = (cards.evaluate().first.widget.key! as ValueKey<String>);
    for (final target in ['gdt-tree-zone', 'gdt-bin']) {
      if (audio.held == null && find.byKey(first).evaluate().isNotEmpty) {
        await drag(find.byKey(first), target);
      }
    }
    expect(audio.held, isNotNull);

    // Nothing moves, and nothing new is said, until it ends.
    final left = cards.evaluate().length;
    final said = audio.said.length;
    await drag(cards.first, 'gdt-tree-zone');
    await drag(cards.first, 'gdt-bin');
    expect(cards.evaluate().length, left);
    expect(audio.said.length, said);

    audio.held!.complete();
    await wait(tester, 500);
    await drag(cards.first, 'gdt-tree-zone');
    await drag(cards.first, 'gdt-bin');
    expect(audio.said.length, greaterThan(said));
    audio.held?.complete();
    await wait(tester, 6000);
  });

  for (final session in GoodDeedTreeSession.values) {
    testWidgets(
      '${session.name}: start, how to play, sort every card, finish',
      (tester) async {
        int? xp;
        await tester.pumpWidget(host(session, (x, _, _) => xp = x));
        await wait(tester, 2500);

        await tester.tap(find.byKey(const ValueKey('gdt-play')));
        await wait(tester, 6500);
        await tester.tap(find.byKey(const ValueKey('gdt-start')));
        await wait(tester, 4000);

        final cards = find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith('gdt-card-'),
        );
        expect(cards, findsWidgets);

        // Cards come in as others are sorted, so keep going until none are
        // left. Each card: try the tree, then the bin — the wrong one only
        // counts a mistake, an already sorted card ignores the second tap.
        for (var round = 0; round < 8 && cards.evaluate().isNotEmpty; round++) {
          final ids = [
            for (final e in cards.evaluate())
              (e.widget.key! as ValueKey<String>).value,
          ];
          for (final id in ids) {
            for (final target in ['gdt-tree-zone', 'gdt-bin']) {
              final card = find.byKey(ValueKey(id));
              final goal = find.byKey(ValueKey(target));
              if (card.evaluate().isEmpty || goal.evaluate().isEmpty) continue;
              // Dragged onto it, the way a child plays.
              final from = tester.getCenter(card);
              final to = tester.getCenter(goal);
              final g = await tester.startGesture(from);
              for (var k = 1; k <= 6; k++) {
                await g.moveTo(Offset.lerp(from, to, k / 6)!);
                await tester.pump(const Duration(milliseconds: 16));
              }
              await g.up();
              await wait(tester, 2500);
            }
          }
        }

        await wait(tester, 6000);
        for (final key in ['gdt-learned', 'gdt-continue', 'gdt-finish']) {
          final f = find.byKey(ValueKey(key));
          if (f.evaluate().isNotEmpty) {
            await tester.tap(f, warnIfMissed: false);
            await wait(tester, 4000);
          }
        }
        expect(xp, isNotNull, reason: 'the session reports its score');
      },
    );
  }
}

/// Narration that ends at once, so How to play's Start shows straight away.
class _SilentAudio extends GoodDeedTreeAudio {
  @override
  Future<void> say(List<String> clips) async {}
}

/// Card names only finish when the test says so; everything else at once.
class _HeldAudio extends GoodDeedTreeAudio {
  final said = <String>[];
  Completer<void> line = Completer();

  @override
  Future<void> say(List<String> clips) {
    said.addAll(clips);
    if (!clips.first.startsWith('card_')) return Future.value();
    line = Completer();
    return line.future;
  }
}

/// Praise/retry lines only finish when the test says so.
class _HeldPraise extends GoodDeedTreeAudio {
  final said = <String>[];
  Completer<void>? held;

  @override
  Future<void> say(List<String> clips) {
    said.addAll(clips);
    final c = clips.first;
    if (!c.startsWith('praise_') && !c.startsWith('retry_')) {
      return Future.value();
    }
    return (held = Completer()).future;
  }
}
