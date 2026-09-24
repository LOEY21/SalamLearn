import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:salamlearn/data/curriculum_data.dart';
import 'package:salamlearn/data/models/curriculum/curriculum_models.dart';
import 'package:salamlearn/ui/core_modules/activities/five_pillars_game.dart';

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

  const order = ['shahadah', 'salah', 'zakah', 'sawm', 'hajj'];

  Widget host(FivePillarsMode mode, void Function(int, double, int) done) =>
      MaterialApp(
        home: Scaffold(
          body: FivePillarsGame(
            mode: mode,
            xp: 40,
            onComplete: done,
            onExit: () {},
          ),
        ),
      );

  Future<void> drag(WidgetTester tester, String id, int slot) async {
    final from = tester.getCenter(find.byKey(ValueKey('fp-tray-$id')));
    final to = tester.getCenter(find.byKey(ValueKey('fp-slot-$slot')));
    final g = await tester.startGesture(from);
    await g.moveTo(Offset.lerp(from, to, 0.5)!);
    await g.moveTo(to);
    await g.up();
    await tester.pump();
  }

  Future<void> play(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('fp-play')));
    await tester.pump(const Duration(milliseconds: 1400));
    expect(find.text('How to Play'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('fp-ready')));
    await tester.pump(const Duration(milliseconds: 4000));
    await tester.pump(const Duration(milliseconds: 900));
  }

  test('both sessions play The Five Pillars', () {
    Activity actFor(String id) => curriculum
        .expand((d) => d.lessons)
        .expand((l) => l.activities)
        .firstWhere((a) => a.id == id);
    expect(actFor('dest5-s6-act').type, ActivityType.fivePillars);
    expect(actFor('dest5-s6-act').pillarsMode, FivePillarsMode.scenarios);
    expect(actFor('dest6-s6-act').type, ActivityType.fivePillars);
    expect(actFor('dest6-s6-act').pillarsMode, FivePillarsMode.ordering);
  });

  testWidgets('ordering: wrong slot shakes, full build reports', (
    tester,
  ) async {
    int? errors;
    await tester.pumpWidget(
      host(FivePillarsMode.ordering, (_, _, e) => errors = e),
    );
    expect(find.byKey(const ValueKey('fp-play')), findsOneWidget);
    await play(tester);
    expect(find.text('0 OF 5 PLACED'), findsOneWidget);

    await drag(tester, 'hajj', 0);
    expect(find.text('⭐ Try again'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1200));

    for (var i = 0; i < 5; i++) {
      await drag(tester, order[i], i);
      await tester.pump(const Duration(milliseconds: 1200));
    }
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Mumtāz!'), findsNothing);
    await tester.pump(const Duration(milliseconds: 5300));
    expect(find.text('Mumtāz!'), findsWidgets);
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.tap(find.byKey(const ValueKey('fp-continue')));
    expect(errors, 1);
  });

  testWidgets('scenarios: one slot per question, in order', (tester) async {
    int? errors;
    await tester.pumpWidget(
      host(FivePillarsMode.scenarios, (_, _, e) => errors = e),
    );
    await play(tester);
    expect(find.text('STEP 1 OF 5'), findsOneWidget);

    // A correct pillar on the wrong slot is just a miss, not an error.
    await drag(tester, 'shahadah', 3);
    expect(find.text('⭐ Try again'), findsNothing);

    await drag(tester, 'salah', 0);
    expect(find.text('⭐ Try again'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1200));

    for (var i = 0; i < 5; i++) {
      expect(find.text('STEP ${i + 1} OF 5'), findsOneWidget);
      await drag(tester, order[i], i);
      await tester.pump(const Duration(milliseconds: 1600));
    }
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Mumtāz!'), findsNothing);
    await tester.pump(const Duration(milliseconds: 5300));
    expect(find.text('Mumtāz!'), findsWidgets);
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.tap(find.byKey(const ValueKey('fp-continue')));
    expect(errors, 1);
  });
}
