import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/data/curriculum_data.dart';
import 'package:salamlearn/data/models/curriculum/curriculum_models.dart';
import 'package:salamlearn/ui/core_modules/activities/label_maker_game.dart';
import 'package:salamlearn/ui/widgets/arc_text_painter.dart';

/// The start banner's title is painted along an arch, not a Text widget.
Finder _arcText(String text) => find.byWidgetPredicate(
  (w) =>
      w is CustomPaint &&
      w.painter is ArcTextPainter &&
      (w.painter! as ArcTextPainter).text == text,
);

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

/// A point inside each body part, in the 853x1844 portrait stage.
const _body = {
  'Head': Offset(428, 348),
  'Eye': Offset(339, 582),
  'Nose': Offset(421, 618),
  'Mouth': Offset(424, 667),
  'Hand': Offset(131, 986),
  'Hair': Offset(419, 454),
  'Ear': Offset(244, 623),
  'Foot': Offset(269, 1436),
  'Leg': Offset(331, 1248),
};

void main() {
  test('Body Parts portrait art is bundled', () async {
    final bytes = await rootBundle.load(
      'assets/images/label_maker/room_body_portrait.png',
    );
    expect(bytes.lengthInBytes, greaterThan(1000));
  });

  testWidgets('Body Parts round plays on the portrait stage', (tester) async {
    // Starts landscape like the phone; turned upright before Let's Go.
    tester.view.physicalSize = const Size(1870, 841);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    (int, double, int)? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LabelMakerGame(
            session: LabelMakerSession.body,
            xp: 30,
            random: math.Random(2),
            onComplete: (xp, acc, errors) => result = (xp, acc, errors),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('lm-play')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 46));
    await tester.pump(const Duration(milliseconds: 600));

    // After the steps: a turn-your-phone prompt, no Let's Go yet...
    expect(find.text('Hold your phone upright!'), findsWidgets);
    expect(find.byKey(const ValueKey('lm-go')), findsNothing);
    // ...until the phone is upright.
    tester.view.physicalSize = const Size(853, 1844);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.byKey(const ValueKey('lm-go')));
    await tester.pump();
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pumpAndSettle();

    final badge = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('lm-badge-'),
    );
    for (var i = 1; i <= 9; i++) {
      final word = (tester.widget(badge).key! as ValueKey<String>).value
          .substring('lm-badge-'.length);
      final g = await tester.startGesture(tester.getCenter(badge));
      await g.moveBy(const Offset(0, -30));
      await tester.pump();
      await g.moveTo(_body[word]!);
      await tester.pump();
      await g.up();
      await tester.pumpAndSettle();
      expect(find.text('$i/9'), findsOneWidget);
    }

    await tester.pump(const Duration(milliseconds: 4000));
    expect(find.byKey(const ValueKey('lm-congrats')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('lm-congrats')));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Words You Learned'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('lm-home')));
    expect(result?.$3, 0);
  });

  test('Label Maker room music is bundled', () async {
    final bytes = await rootBundle.load(
      'assets/audio/label_maker/audio_bgm_label_maker_room.mp3',
    );
    expect(bytes.lengthInBytes, greaterThan(1000));
  });

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
    expect(_arcText('Learn Arabic Words'), findsOneWidget);

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

    // Back on How to Play returns to the start screen, then in again.
    await tester.tap(find.byKey(const ValueKey('lm-back')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('How to Play'), findsNothing);
    expect(_arcText('Learn Arabic Words'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('lm-play')));
    await tester.pump();
    expect(find.text('How to Play'), findsOneWidget);

    // Let's Go waits for the spoken steps behind a "Get ready" bar; with no
    // audio plugin in tests each of the three lines runs to its 15s timeout.
    expect(find.byKey(const ValueKey('lm-go')), findsNothing);
    expect(find.text('Get ready...'), findsOneWidget);
    await tester.pump(const Duration(seconds: 46));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const ValueKey('lm-go')), findsOneWidget);
    expect(find.text('Get ready...'), findsNothing);

    // 3-2-1-Go! countdown, with the badge locked until it ends.
    await tester.tap(find.byKey(const ValueKey('lm-go')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('How to Play'), findsNothing);
    expect(find.text('3'), findsWidgets);
    expect(find.text('Get Ready!'), findsWidgets);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Go!'), findsWidgets);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Get Ready!'), findsNothing);

    // No separate Replay button: the speaker badge is the replay, and it
    // swaps to its pressed art while held.
    expect(find.byKey(const ValueKey('lm-replay')), findsNothing);
    final speaker = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('lm-badge-'),
    );
    final hold = await tester.startGesture(tester.getCenter(speaker));
    await tester.pump();
    expect(
      find.descendant(
        of: speaker,
        matching: find.image(
          const AssetImage('assets/images/label_maker/btn_speaker_down.png'),
        ),
      ),
      findsOneWidget,
    );
    await hold.up();
    await tester.pumpAndSettle();

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
      // The counter shows how many words are labelled so far.
      expect(find.text('$i/10'), findsOneWidget);
    }
    // Every word now sits on its object as a white label.
    expect(find.text('بَابٌ'), findsOneWidget);
    expect(find.text('مِفْتَاحٌ'), findsOneWidget);
    // ...and every object has lit up with its star sparkle.
    expect(
      find.image(const AssetImage('assets/images/label_maker/star.png')),
      findsNWidgets(10),
    );

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
    // The ending leaves only its own buttons: no Back, no Music.
    expect(find.byKey(const ValueKey('lm-back')), findsNothing);
    expect(find.byKey(const ValueKey('lm-music')), findsNothing);

    // One slip: two stars, and the girl says so.
    expect(find.text('Great job!\nOnly 1 little slip.'), findsOneWidget);
    expect(find.text('You learned 10 home words!'), findsOneWidget);
    // Two stars is a good round: the mascots cheer, not encourage.
    expect(
      find.image(const AssetImage('assets/images/label_maker/girl_cheer.png')),
      findsOneWidget,
    );
    expect(
      find.image(
        const AssetImage('assets/images/label_maker/girl_encourage.png'),
      ),
      findsNothing,
    );

    // Words on the wall can be tapped to hear them again.
    await tester.tap(find.byKey(const ValueKey('lm-wall-0')));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byKey(const ValueKey('lm-home')));
    expect(result?.$1, 30);
    expect(result?.$3, 1);
    expect(result!.$2, closeTo(1000 / 11, .01));
  });
}
