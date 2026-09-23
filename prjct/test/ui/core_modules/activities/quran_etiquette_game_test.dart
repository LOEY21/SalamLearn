import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:salamlearn/data/curriculum_data.dart';
import 'package:salamlearn/data/models/curriculum/curriculum_models.dart';
import 'package:salamlearn/ui/core_modules/activities/quran_etiquette_game.dart';

void main() {
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!;
    view.devicePixelRatio = 1.0;
    view.physicalSize = const Size(1600, 900);
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView!;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Widget host(
    QuranEtiquetteSession session, {
    void Function(int, double, int)? onComplete,
  }) => MaterialApp(
    home: Scaffold(
      body: QuranEtiquetteGame(
        key: ValueKey(session.number),
        session: session,
        xp: 30,
        onComplete: onComplete ?? (_, _, _) {},
        onExit: () {},
      ),
    ),
  );

  Future<void> skipNarration(WidgetTester tester) async {
    // Skip sits under the 3s curtain until it opens.
    await tester.pump(const Duration(milliseconds: 3100));
    await tester.tap(find.text('Skip'));
    await tester.pump(const Duration(milliseconds: 400));
  }

  test('each session lands on its own stage', () {
    Activity actFor(String id) => curriculum
        .expand((d) => d.lessons)
        .expand((l) => l.activities)
        .firstWhere((a) => a.id == id);
    expect(actFor('dest1-s5-act').type, ActivityType.quranEtiquette);
    expect(actFor('dest1-s5-act').etiquetteSession, etiquetteMasjidSession);
    expect(actFor('dest3-s1-act').etiquetteSession, etiquetteHomeSession);
  });

  testWidgets('same start screen for both sessions', (tester) async {
    for (final session in etiquetteSessions) {
      await tester.pumpWidget(host(session));
      await tester.pump(const Duration(milliseconds: 2400));
      expect(find.byKey(ValueKey('qe-play-${session.number}')), findsOneWidget);
      expect(find.text('Star Meter'), findsNothing);
    }
  });

  testWidgets('plays a full session and reports completion', (tester) async {
    for (final session in etiquetteSessions) {
      int? xp;
      int? errors;
      await tester.pumpWidget(
        host(
          session,
          onComplete: (x, _, e) {
            xp = x;
            errors = e;
          },
        ),
      );
      await tester.pump(const Duration(milliseconds: 2400));
      await tester.tap(find.byKey(ValueKey('qe-play-${session.number}')));
      await tester.pump();

      for (var i = 0; i < session.questions.length; i++) {
        final q = session.questions[i];
        await skipNarration(tester);
        if (i == 0) {
          // A wrong pick ends the question too — red mask, then on.
          await tester.tap(find.text(q.decoy));
          await tester.pump(const Duration(milliseconds: 500));
          expect(find.text(q.decoy), findsNothing);
          await tester.pump(const Duration(milliseconds: 3600));
          continue;
        }
        await tester.tap(find.text(q.correct));
        await tester.pump(const Duration(milliseconds: 500));
        // Only the feedback art is on screen — no panel, no Next.
        expect(find.text(q.correct), findsNothing);
        expect(find.text('Next'), findsNothing);
        // Moves on by itself after 4s.
        await tester.pump(const Duration(milliseconds: 3600));
      }

      await tester.pump(const Duration(milliseconds: 800));
      // Summary: 1 wrong + 4 right.
      expect(
        find.text(
          'You made 4 of 5 respectful choices '
          '${session.title.toLowerCase()}!',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      // Nothing from the question screen stays on the ending screen.
      expect(find.text(session.questions.last.decoy), findsNothing);
      expect(find.text('Skip'), findsNothing);
      expect(find.bySemanticsLabel('Back'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('qe-home')));
      await tester.pump();
      expect(xp, 30);
      expect(errors, 1);
    }
  });

  testWidgets('a low score gets the encouraging ending', (tester) async {
    final session = etiquetteMasjidSession;
    await tester.pumpWidget(host(session));
    await tester.pump(const Duration(milliseconds: 2400));
    await tester.tap(find.byKey(ValueKey('qe-play-${session.number}')));
    await tester.pump();
    for (final q in session.questions) {
      await skipNarration(tester);
      await tester.tap(find.text(q.decoy));
      await tester.pump(const Duration(milliseconds: 4100));
    }
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('Nice try! You earned 0 of 5 stars.'), findsOneWidget);
    expect(
      find.text('Keep practicing — you can do it, in shaa Allah!'),
      findsOneWidget,
    );

    // Play Again: the curtain slides shut over the ending, then the
    // session restarts behind it with the Question 1 tile.
    await tester.tap(find.text('Play Again'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Question 1'), findsNothing);
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Question 1'), findsOneWidget);
    expect(find.text('Nice try! You earned 0 of 5 stars.'), findsNothing);
    await tester.pump(const Duration(seconds: 4));
  });
}
