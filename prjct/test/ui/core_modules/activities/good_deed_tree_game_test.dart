import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:salamlearn/data/models/curriculum/curriculum_models.dart';
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
      ),
    ),
  );

  Future<void> wait(WidgetTester tester, int ms) async {
    for (var t = 0; t < ms; t += 100) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

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
