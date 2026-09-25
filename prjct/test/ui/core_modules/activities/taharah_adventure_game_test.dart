import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:salamlearn/data/curriculum_data.dart';
import 'package:salamlearn/data/models/curriculum/curriculum_models.dart';
import 'package:salamlearn/ui/core_modules/activities/taharah_adventure_game.dart';

void main() {
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!;
    view.devicePixelRatio = 1.0;
    view.physicalSize = const Size(390, 844);
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Widget host(
    TaharahSession session,
    void Function(int, double, int) onComplete,
  ) => MaterialApp(
    home: Scaffold(
      body: TaharahAdventureGame(
        session: session,
        xp: 30,
        onComplete: onComplete,
        onExit: () {},
      ),
    ),
  );

  test('each session lands on its designated lesson', () {
    Activity actFor(String id) => curriculum
        .expand((d) => d.lessons)
        .expand((l) => l.activities)
        .firstWhere((a) => a.id == id);
    for (final (id, session) in [
      ('dest4-s6-act', TaharahSession.cleanOrDirty),
      ('dest5-s4-act', TaharahSession.wudhuPart1),
      ('dest6-s3-act', TaharahSession.wudhuPart2),
    ]) {
      expect(actFor(id).type, ActivityType.taharahAdventure);
      expect(actFor(id).taharahSession, session);
    }
  });

  testWidgets('Clean or Dirty: sort all six cards and finish', (tester) async {
    int? errors;
    await tester.pumpWidget(
      host(TaharahSession.cleanOrDirty, (_, _, e) => errors = e),
    );
    await tester.tap(find.text('START'));
    await tester.pump();
    await tester.tap(find.text('PLAY ▶'));
    await tester.pump(const Duration(milliseconds: 400));

    Future<void> drag(String card, String bin) async {
      final g = await tester.startGesture(
        tester.getCenter(find.byKey(ValueKey('ta-card-$card'))),
      );
      await g.moveBy(const Offset(0, 20));
      await tester.pump();
      await g.moveTo(tester.getCenter(find.byKey(ValueKey('ta-bin-$bin'))));
      await tester.pump();
      await g.up();
      await tester.pump(const Duration(milliseconds: 300));
    }

    await drag('muddy_shoes', 'clean');
    expect(find.textContaining('Oops! Muddy Shoes'), findsOneWidget);

    for (final (card, bin) in [
      ('wash_hands', 'clean'),
      ('brush_teeth', 'clean'),
      ('dirty_clothes', 'dirty'),
      ('throw_trash', 'clean'),
      ('muddy_shoes', 'dirty'),
      ('cut_nails', 'clean'),
    ]) {
      await drag(card, bin);
    }
    await tester.pump(const Duration(milliseconds: 1600));
    expect(find.text('MUMTAZ!'), findsOneWidget);

    await tester.tap(find.text('SEE WHAT YOU LEARNED'));
    await tester.pump();
    expect(find.text('What You Learned'), findsOneWidget);
    await tester.tap(find.text('→ Next Session: Wudhu'));
    expect(errors, 1);
  });

  for (final (session, order, wrong) in [
    (
      TaharahSession.wudhuPart1,
      ['hands-3', 'mouth-5', 'nose-4', 'face-0', 'arms-1'],
      'mouth-5',
    ),
    (
      TaharahSession.wudhuPart2,
      [
        'left_arm-0',
        'head-1',
        'ears-2',
        'right_foot-4',
        'left_foot-5',
      ],
      'head-1',
    ),
  ]) {
    testWidgets('${session.name}: tap the steps in order', (tester) async {
      int? errors;
      await tester.pumpWidget(host(session, (_, _, e) => errors = e));
      await tester.tap(find.text('Play'));
      await tester.pump();
      await tester.tap(find.textContaining('Wudhu').last);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 600));

      Future<void> tapZone(String z) async {
        final f = find.byKey(ValueKey('ta-zone-$z'));
        // The face zone's centre sits on the nose zone's edge.
        final nudge = z.startsWith('face') ? const Offset(0, -30) : Offset.zero;
        await tester.tapAt(tester.getCenter(f) + nudge);
        await tester.pump(const Duration(milliseconds: 100));
      }

      await tapZone(wrong);
      expect(find.textContaining('Oops!'), findsOneWidget);
      for (final z in order) {
        await tapZone(z);
      }
      await tester.pump(const Duration(milliseconds: 5300));
      expect(find.text('Mumtaz!'), findsOneWidget);
      await tester.tap(find.text('Next Session →'));
      expect(errors, 1);
    });
  }
}
