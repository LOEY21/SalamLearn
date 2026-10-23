import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/ui/widgets/letter_trace_canvas.dart';

void main() {
  // Like ج: stroke 2 starts on the middle of stroke 1's line.
  const guides = [
    [
      Offset(50, 50),
      Offset(100, 50),
      Offset(150, 50),
      Offset(200, 50),
      Offset(250, 50),
    ],
    [Offset(150, 50), Offset(150, 150), Offset(150, 250)],
  ];

  testWidgets('lifting mid-stroke does not push later strokes out of step', (
    tester,
  ) async {
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
    expect(last[1], const [
      Offset(150, 50),
      Offset(150, 150),
      Offset(150, 250),
    ]);
  });

  testWidgets('tapping the dot before finishing the body scores the dot', (
    tester,
  ) async {
    final breathe = AnimationController(vsync: const _NoVsync());
    addTearDown(breathe.dispose);
    var last = <List<Offset>>[];
    // Like ب: a body, then a dot just under it.
    const withDot = [
      [
        Offset(50, 50),
        Offset(100, 50),
        Offset(150, 50),
        Offset(200, 50),
        Offset(250, 50),
      ],
      [Offset(150, 90)],
    ];

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
              guidePointsBuilder: (_) => withDot,
              onStroke: (s, _) => last = s,
              onDirectionViolation: () {},
              coverTolerance: 18,
            ),
          ),
        ),
      ),
    );

    final o = tester.getTopLeft(find.byType(LetterTraceCanvas));
    final g = await tester.startGesture(o + const Offset(50, 50));
    await g.moveTo(o + const Offset(190, 50));
    await g.up();
    await tester.pump();
    await tester.tapAt(o + const Offset(150, 90));
    await tester.pump();

    expect(last[0].last, const Offset(190, 50));
    expect(last[1], const [Offset(150, 90)]);
  });

  testWidgets('tracing inside the letter kicks up sand and paints cleanly', (
    tester,
  ) async {
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

  testWidgets('strict direction flags tracing back right to left', (
    tester,
  ) async {
    final breathe = AnimationController(vsync: const _NoVsync());
    addTearDown(breathe.dispose);
    final line = [
      [for (var x = 50.0; x <= 250; x += 6) Offset(x, 50)],
    ];
    var violations = 0;

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
              guidePointsBuilder: (_) => line,
              onStroke: (_, _) {},
              onDirectionViolation: () => violations++,
              coverTolerance: 18,
              strictDirection: true,
            ),
          ),
        ),
      ),
    );

    final o = tester.getTopLeft(find.byType(LetterTraceCanvas));
    final g = await tester.startGesture(o + const Offset(50, 50));
    for (var x = 60.0; x <= 150; x += 10) {
      await g.moveTo(o + Offset(x, 50));
    }
    expect(violations, 0);
    for (var x = 140.0; x >= 90; x -= 10) {
      await g.moveTo(o + Offset(x, 50));
    }
    await g.up();
    expect(violations, 1);
  });

  testWidgets('strict direction allows a stroke that retraces itself', (
    tester,
  ) async {
    final breathe = AnimationController(vsync: const _NoVsync());
    addTearDown(breathe.dispose);
    // Like ٣'s middle tooth: right, up, straight back down, then right.
    List<Offset> run(Offset a, Offset b) => [
      for (var t = 0.0; t < 1; t += 6 / (b - a).distance) Offset.lerp(a, b, t)!,
    ];
    final tooth = [
      [
        ...run(const Offset(50, 150), const Offset(150, 150)),
        ...run(const Offset(150, 150), const Offset(150, 50)),
        ...run(const Offset(150, 50), const Offset(150, 150)),
        ...run(const Offset(150, 150), const Offset(250, 150)),
        const Offset(250, 150),
      ],
    ];
    var violations = 0;

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
              guidePointsBuilder: (_) => tooth,
              onStroke: (_, _) {},
              onDirectionViolation: () => violations++,
              coverTolerance: 18,
              strictDirection: true,
            ),
          ),
        ),
      ),
    );

    final o = tester.getTopLeft(find.byType(LetterTraceCanvas));
    final g = await tester.startGesture(o + const Offset(50, 150));
    for (final p in [
      for (var x = 60.0; x <= 150; x += 10) Offset(x, 150),
      for (var y = 140.0; y >= 50; y -= 10) Offset(150, y),
      for (var y = 60.0; y <= 150; y += 10) Offset(150, y),
      for (var x = 160.0; x <= 250; x += 10) Offset(x, 150),
    ]) {
      await g.moveTo(o + p);
    }
    await g.up();
    expect(violations, 0);
  });
}

class _NoVsync implements TickerProvider {
  const _NoVsync();
  @override
  Ticker createTicker(TickerCallback onTick) => Ticker(onTick);
}
