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

    // Play opens How to Play; its Back returns to the start screen.
    await tester.tap(find.byKey(const ValueKey('trace-play')));
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.byKey(const ValueKey('trace-play')), findsNothing);
    expect(find.byKey(const ValueKey('trace-go')), findsOneWidget);
    expect(find.byType(LetterTraceCanvas), findsNothing);

    await tester.tap(find.byKey(const ValueKey('trace-howto-back')));
    await tester.pump();
    expect(find.byKey(const ValueKey('trace-play')), findsOneWidget);

    // Play, then Let's Go, lands in the tray.
    await tester.tap(find.byKey(const ValueKey('trace-play')));
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.tap(find.byKey(const ValueKey('trace-go')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('trace-go')), findsNothing);
    expect(find.byType(LetterTraceCanvas), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('trace-back')));
    expect(backs, 1);
  });
}
