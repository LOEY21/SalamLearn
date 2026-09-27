import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/data/curriculum_data.dart';
import 'package:salamlearn/data/models/curriculum/curriculum_models.dart';
import 'package:salamlearn/ui/core_modules/activities/label_maker_game.dart';

/// A point inside each My Home object, in the 1870x841 stage.
const _home = {
  'Door': Offset(290, 470),
  'Bed': Offset(670, 160),
  'Window': Offset(1150, 110),
  'House': Offset(1288, 480),
  'Table': Offset(758, 640),
  'TV': Offset(637, 457),
  'Lamp': Offset(1115, 440),
  'Kitchen': Offset(1620, 450),
  'Cup': Offset(1558, 700),
  'Key': Offset(1628, 758),
};

void main() {
  test('each session lands on its designated lesson', () {
    Activity actFor(String id) => curriculum
        .expand((d) => d.lessons)
        .expand((l) => l.activities)
        .firstWhere((a) => a.id == id);
    for (final (id, session) in [
      ('dest2-s3-act', LabelMakerSession.home),
      ('dest3-s3-act', LabelMakerSession.body),
      ('dest5-s1-act', LabelMakerSession.classroom),
    ]) {
      expect(actFor(id).type, ActivityType.labelMaker);
      expect(actFor(id).labelSession, session);
    }
  });

  testWidgets('drag each word onto its object, then finish', (tester) async {
    tester.view.physicalSize = const Size(1870, 841);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    (int, double, int)? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LabelMakerGame(
            session: LabelMakerSession.home,
            xp: 30,
            random: math.Random(1),
            onComplete: (xp, acc, errors) => result = (xp, acc, errors),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Learn Arabic Words'), findsOneWidget);

    // Music toggles the game's sounds off and back on.
    await tester.tap(find.byKey(const ValueKey('lm-music')));
    await tester.pump();
    expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('lm-music')));
    await tester.pump();
    expect(find.byIcon(Icons.volume_off_rounded), findsNothing);

    await tester.tap(find.byKey(const ValueKey('lm-play')));
    await tester.pump();
    expect(find.text('How to Play'), findsOneWidget);
    expect(find.text("Let's Go!"), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('lm-go')));
    await tester.pumpAndSettle();
    expect(find.text('How to Play'), findsNothing);

    String current() {
      final key =
          tester
                  .widget(
                    find.byWidgetPredicate(
                      (w) =>
                          w.key is ValueKey<String> &&
                          (w.key! as ValueKey<String>).value.startsWith(
                            'lm-badge-',
                          ),
                    ),
                  )
                  .key!
              as ValueKey<String>;
      return key.value.substring('lm-badge-'.length);
    }

    Future<void> dragTo(Offset stagePoint) async {
      final from = tester.getCenter(
        find.byKey(ValueKey('lm-badge-${current()}')),
      );
      final g = await tester.startGesture(from);
      await g.moveBy(const Offset(0, -30));
      await tester.pump();
      await g.moveTo(stagePoint);
      await tester.pump();
      await g.up();
      await tester.pumpAndSettle();
    }

    // One wrong drop: the badge stays, the error counts.
    final first = current();
    final wrong = _home.keys.firstWhere((k) => k != first);
    await dragTo(_home[wrong]!);
    expect(current(), first);
    expect(find.text('0/10'), findsOneWidget);

    for (var i = 1; i <= 10; i++) {
      await dragTo(_home[current()]!);
      expect(find.text('$i/10'), findsOneWidget);
    }
    // Every word now sits on its object as a white label.
    expect(find.text('بَابٌ'), findsOneWidget);
    expect(find.text('مِفْتَاحٌ'), findsOneWidget);

    // Congrats burst, then tap through to the summary with the mascots.
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump(const Duration(milliseconds: 2500));
    expect(find.byKey(const ValueKey('lm-congrats')), findsOneWidget);
    expect(find.text('Tap to continue'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('lm-congrats')));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Words You Learned'), findsOneWidget);
    expect(find.text('91%'), findsOneWidget);
    expect(find.text('+30'), findsOneWidget);
    expect(find.text('بَابٌ'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('lm-home')));
    expect(result?.$1, 30);
    expect(result?.$3, 1);
    expect(result!.$2, closeTo(1000 / 11, .01));
  });
}
