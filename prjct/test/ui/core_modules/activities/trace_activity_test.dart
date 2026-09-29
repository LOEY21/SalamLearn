import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/data/curriculum_data.dart';
import 'package:salamlearn/data/letter_trace_data.dart';
import 'package:salamlearn/ui/core_modules/activities/trace_activity.dart';
import 'package:salamlearn/ui/widgets/letter_trace_canvas.dart';

void main() {
  test('every tracer letter and its ambient music are bundled', () async {
    final cards = [
      ...sandTracer1,
      ...sandTracer2,
      ...sandTracer3,
      ...sandTracer4,
    ];
    expect(cards.length, 28);
    final clips = cards.map((card) => card.audioAsset).toSet();
    expect(clips.length, 28);
    for (final clip in clips) {
      expect(clip, isNotNull);
      final data = await rootBundle.load(clip!);
      expect(data.lengthInBytes, greaterThan(0), reason: clip);
    }
    final music = await rootBundle.load('assets/audio/sand_tracer/ambient.mp3');
    expect(music.lengthInBytes, greaterThan(0));
  });
  test('every tracer letter has its outline and a stroke to follow', () {
    for (final card in [
      ...sandTracer1,
      ...sandTracer2,
      ...sandTracer3,
      ...sandTracer4,
    ]) {
      final letter = card.arabic.split('\n').last.trim();
      final t = letterTraces[letter];
      expect(t, isNotNull, reason: letter);
      expect(t!.outline, isNotEmpty, reason: letter);
      expect(t.strokes.first.length, greaterThan(4), reason: letter);
    }
  });

  testWidgets('start, How to Play, then the tracing canvas', (tester) async {
    tester.view.physicalSize = const Size(853, 1844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var backs = 0;

    // Frame by frame, like a device, so chained animations start on time.
    Future<void> wait(int ms) async {
      for (var t = 0; t < ms; t += 50) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Future<void> tap(String key) async {
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pump();
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TraceActivity(
            cards: sandTracer1,
            xp: 20,
            color: Colors.teal,
            onComplete: (_, _, _) {},
            onBack: () => backs++,
            audioEnabled: false,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('trace-play')), findsOneWidget);
    expect(find.byType(LetterTraceCanvas), findsNothing);

    // Play opens How to Play; Let's Go only appears after a 5s read.
    await wait(1800);
    await tap('trace-play');
    await wait(1500);
    expect(find.byKey(const ValueKey('trace-play')), findsNothing);
    expect(find.byKey(const ValueKey('trace-wait')), findsOneWidget);
    expect(find.byKey(const ValueKey('trace-go')), findsNothing);
    await wait(4200);
    expect(find.byKey(const ValueKey('trace-go')), findsOneWidget);
    expect(find.byType(LetterTraceCanvas), findsNothing);

    // Its Back returns to the start screen.
    await tap('trace-howto-back');
    await wait(600);
    expect(find.byKey(const ValueKey('trace-play')), findsOneWidget);

    // Play, then Let's Go, lands in the tray behind a 3·2·1.
    await wait(1800);
    await tap('trace-play');
    await wait(5700);
    await tap('trace-go');
    await wait(600);
    expect(find.byKey(const ValueKey('trace-go')), findsNothing);
    expect(find.byType(LetterTraceCanvas), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    await wait(2600);
    expect(find.text('Go!'), findsOneWidget);
    await wait(600);
    expect(find.text('Go!'), findsNothing);

    // Clear sweeps the sand: old and new canvas share the tray mid-wipe.
    await tap('trace-clear');
    await wait(300);
    expect(find.byType(LetterTraceCanvas), findsNWidgets(2));
    await wait(600);
    expect(find.byType(LetterTraceCanvas), findsOneWidget);

    await tap('trace-back');
    expect(backs, 1);
  });
}
