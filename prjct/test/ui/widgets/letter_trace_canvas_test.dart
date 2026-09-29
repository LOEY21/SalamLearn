import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/ui/widgets/letter_trace_canvas.dart';

void main() {
  // Like ج: stroke 2 starts on the middle of stroke 1's line.
  const guides = [
    [Offset(50, 50), Offset(100, 50), Offset(150, 50), Offset(200, 50), Offset(250, 50)],
    [Offset(150, 50), Offset(150, 150), Offset(150, 250)],
  ];

  testWidgets('lifting mid-stroke does not push later strokes out of step',
      (tester) async {
    final breathe = AnimationController(vsync: const _NoVsync());
    addTearDown(breathe.dispose);
    var last = <List<Offset>>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            height: 300,
            child: LetterTraceCanvas(
              passed: false,
              failed: false,
              breathe: breathe,
              guidePointsBuilder: (_) => guides,
              onStroke: (s, _) => last = s,
              onDirectionViolation: () {},
              coverTolerance: 18,
            ),
          ),
        ),
      ),
    );

    final o = tester.getTopLeft(find.byType(LetterTraceCanvas));
    Future<void> drag(List<Offset> pts) async {
      final g = await tester.startGesture(o + pts.first);
      for (final p in pts.skip(1)) {
        await g.moveTo(o + p);
      }
      await g.up();
      await tester.pump();
    }

    await drag(const [Offset(50, 50), Offset(140, 50)]);
    await drag(const [Offset(140, 50), Offset(250, 50)]);
    await drag(const [Offset(150, 50), Offset(150, 150), Offset(150, 250)]);

    expect(last.length, 2);
    expect(last[0].length, 4);
    expect(last[1], const [Offset(150, 50), Offset(150, 150), Offset(150, 250)]);
  });

  testWidgets('tracing inside the letter kicks up sand and paints cleanly',
      (tester) async {
    final breathe = AnimationController(vsync: const _NoVsync());
    addTearDown(breathe.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            height: 300,
            child: LetterTraceCanvas(
              passed: false,
              failed: false,
              breathe: breathe,
              guidePointsBuilder: (_) => guides,
              onStroke: (_, _) {},
              onDirectionViolation: () {},
              coverTolerance: 18,
              glyphBuilder: (_) =>
                  Path()..addRect(const Rect.fromLTRB(30, 30, 270, 270)),
            ),
          ),
        ),
      ),
    );

    final o = tester.getTopLeft(find.byType(LetterTraceCanvas));
    final g = await tester.startGesture(o + const Offset(50, 50));
    for (var x = 60.0; x <= 250; x += 10) {
      await g.moveTo(o + Offset(x, 50));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    for (var i = 0; i < 70; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(tester.takeException(), isNull);
  });
}

class _NoVsync implements TickerProvider {
  const _NoVsync();
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}
