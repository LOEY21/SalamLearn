import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/data/curriculum_data.dart';
import 'package:salamlearn/data/models/curriculum/curriculum_models.dart';
import 'package:salamlearn/ui/core_modules/activities/greeting_match_activity.dart';

void main() {
  const testSession = GreetingMatchSession(
    title: 'Session 2: Madrasah Manners',
    subtitle: 'Learn polite Islamic greetings and classroom manners.',
    questions: [
      GreetingQuestion(
        id: 'gq1',
        scenarioImage: 'assets/images/greeting_match/scenes/teacher_enters.jpg',
        arabic: 'السَّلَامُ عَلَيْكُمْ',
        meaning: 'Peace be upon you',
        choices: [
          GreetingChoice(
            arabic: 'شُكْرًا',
            meaning: 'Thank you',
            correct: false,
          ),
          GreetingChoice(
            arabic: 'وَعَلَيْكُمُ السَّلَامُ',
            meaning: 'And peace be upon you',
            correct: true,
          ),
        ],
      ),
    ],
  );

  Widget buildTestWidget({
    GreetingMatchSession session = testSession,
    void Function(int, double, int)? onComplete,
    VoidCallback? onBack,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: GreetingMatchActivity(
          session: session,
          xp: 100,
          onComplete: onComplete ?? (_, _, _) {},
          onBack: onBack ?? () {},
        ),
      ),
    );
  }

  /// How to Play holds Let's Play back 5 s, then a 3-2-1 countdown.
  Future<void> letsPlay(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.tap(find.byKey(const Key('greeting-howto-play')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> startGame(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('greeting-match-play-btn')));
    await tester.pump();
    await letsPlay(tester);
  }

  /// Ending screen -> Continue, which reports the result.
  Future<void> continueFromEnd(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.byKey(const Key('greeting-end')), findsOneWidget);
    await tester.tap(find.byKey(const Key('greeting-end-continue')));
    await tester.pump();
  }

  Future<void> waitForChoices(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('start screen Home button exits the game', (tester) async {
    var exits = 0;
    await tester.pumpWidget(buildTestWidget(onBack: () => exits++));
    await tester.pump();

    await tester.tap(find.byKey(const Key('greeting-start-home')));
    await tester.pump();
    expect(exits, 1);

    await tester.tap(find.byKey(const Key('greeting-start-back')));
    await tester.pump();
    expect(exits, 2);
  });

  testWidgets('Music button switches the game sound off and on', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pump();
    // Corner buttons fade in just after the screen appears.
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.bySemanticsLabel('Sound on'), findsOneWidget);

    await tester.tap(find.byKey(const Key('greeting-start-music')));
    await tester.pump();
    expect(find.bySemanticsLabel('Sound off'), findsOneWidget);

    await tester.tap(find.byKey(const Key('greeting-start-music')));
    await tester.pump();
    expect(find.bySemanticsLabel('Sound on'), findsOneWidget);
  });

  testWidgets('start screen shows the session ribbon, subtitle and Play',
      (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pump();

    expect(find.text('Session 2: Madrasah Manners'), findsOneWidget);
    expect(
      find.text('Learn polite Islamic greetings and classroom manners.'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('greeting-match-play-btn')), findsOneWidget);
  });

  testWidgets('Play opens the scenario with prompt, Play Audio and choices',
      (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pump();
    await startGame(tester);

    expect(find.text('السَّلَامُ عَلَيْكُمْ'), findsOneWidget);
    expect(find.text('(Peace be upon you)'), findsOneWidget);
    expect(find.text('Play Audio'), findsOneWidget);
    expect(find.text('Greeting Stars'), findsOneWidget);
    expect(find.text('شُكْرًا'), findsOneWidget);
    expect(find.text('وَعَلَيْكُمُ السَّلَامُ'), findsOneWidget);
    expect(find.byKey(const Key('greeting-star-0-empty')), findsOneWidget);
  });

  testWidgets('scene shows alone for 4 seconds before choices respond',
      (tester) async {
    int? errors;
    await tester.pumpWidget(
      buildTestWidget(onComplete: (_, _, e) => errors = e),
    );
    await tester.pump();
    await startGame(tester);

    final card = find.ancestor(
      of: find.byKey(const Key('greeting-choice-1')),
      matching: find.byType(AnimatedOpacity),
    );
    expect(tester.widget<AnimatedOpacity>(card.first).opacity, 0);
    await tester.tap(
      find.byKey(const Key('greeting-choice-1')),
      warnIfMissed: false,
    );
    await tester.pump(const Duration(seconds: 2));
    expect(errors, isNull);

    await waitForChoices(tester);
    expect(tester.widget<AnimatedOpacity>(card.first).opacity, 1);
    await tester.tap(find.byKey(const Key('greeting-choice-1')));
    await tester.pump(const Duration(milliseconds: 1700));
    expect(errors, isNull);
    await continueFromEnd(tester);
    expect(errors, 0);
  });

  testWidgets('wrong choice earns a red star, shows the answer, moves on',
      (tester) async {
    int? errors;
    double? accuracy;
    await tester.pumpWidget(
      buildTestWidget(
        onComplete: (_, a, e) {
          accuracy = a;
          errors = e;
        },
      ),
    );
    await tester.pump();
    await startGame(tester);
    await waitForChoices(tester);

    await tester.tap(find.byKey(const Key('greeting-choice-0')));
    await tester.pump();
    expect(find.byKey(const Key('greeting-star-0-red')), findsOneWidget);
    expect(find.text('Mumtaz!'), findsNothing);

    // No second try: tapping the right answer now changes nothing.
    await tester.tap(find.byKey(const Key('greeting-choice-1')));
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.byKey(const Key('greeting-star-0-red')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1700));
    await continueFromEnd(tester);
    expect(errors, 1);
    expect(accuracy, 0.0);
  });

  testWidgets('correct choice earns a gold star and completes the activity',
      (tester) async {
    double? accuracy;
    await tester.pumpWidget(
      buildTestWidget(onComplete: (_, a, _) => accuracy = a),
    );
    await tester.pump();
    await startGame(tester);
    await waitForChoices(tester);

    await tester.tap(find.byKey(const Key('greeting-choice-1')));
    await tester.pump();
    expect(find.byKey(const Key('greeting-star-0-gold')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1700));
    await continueFromEnd(tester);

    expect(accuracy, 100.0);
  });

  testWidgets("Let's Play counts down 3-2-1 before the first scene", (
    tester,
  ) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pump();
    await tester.tap(find.byKey(const Key('greeting-match-play-btn')));
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.tap(find.byKey(const Key('greeting-howto-play')));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const ValueKey('greeting-countdown-3')), findsOneWidget);
    expect(find.text('Play Audio'), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('greeting-countdown-2')), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('greeting-countdown-1')), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Play Audio'), findsOneWidget);
  });

  testWidgets('How to Play explains the 3 steps; Back returns to start', (
    tester,
  ) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pump();
    await tester.tap(find.byKey(const Key('greeting-match-play-btn')));
    await tester.pump();

    expect(find.text('How to Play'), findsOneWidget);
    expect(find.text('Watch & Listen'), findsOneWidget);
    expect(find.text('Tap the Reply'), findsOneWidget);
    expect(find.text('Earn Stars'), findsOneWidget);

    // Let's Play only appears after the 5-second hold.
    await tester.pump(const Duration(seconds: 4));
    expect(find.text("Let's Play!"), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text("Let's Play!"), findsOneWidget);

    await tester.tap(find.byKey(const Key('greeting-howto-back')));
    await tester.pump();
    expect(find.byKey(const Key('greeting-match-play-btn')), findsOneWidget);
  });

  testWidgets('ending congratulates, rates and lists the greetings', (
    tester,
  ) async {
    var completed = 0;
    final twoRounds = GreetingMatchSession(
      title: testSession.title,
      subtitle: testSession.subtitle,
      questions: [testSession.questions.first, testSession.questions.first],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GreetingMatchActivity(
            session: twoRounds,
            xp: 100,
            onComplete: (_, _, _) => completed++,
            onBack: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    await startGame(tester);
    await waitForChoices(tester);

    // Round 1 right (gold), round 2 wrong (red): 50% -> 1 star.
    await tester.tap(find.byKey(const Key('greeting-choice-1')));
    await tester.pump(const Duration(milliseconds: 1700));
    await waitForChoices(tester);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.byKey(const Key('greeting-choice-0')));
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pump(const Duration(milliseconds: 2000));

    expect(find.text('Great Job!'), findsOneWidget);
    expect(find.text('You got 1 of 2 right!'), findsOneWidget);
    expect(find.text('Accuracy 50%'), findsOneWidget);
    expect(find.text('+100 XP'), findsOneWidget);
    expect(find.byKey(const Key('greeting-end-star-0-on')), findsOneWidget);
    expect(find.byKey(const Key('greeting-end-star-1-off')), findsOneWidget);
    // Each learned greeting shows the star it earned.
    for (final (row, kind) in [(0, 'gold'), (1, 'red')]) {
      final star = tester.widget<Image>(
        find.descendant(
          of: find.byKey(Key('greeting-end-row-$row')),
          matching: find.byType(Image),
        ),
      );
      expect((star.image as AssetImage).assetName, contains('star_$kind'));
    }
    expect(completed, 0);

    // Play Again goes back through How to Play into a fresh round.
    await tester.tap(find.byKey(const Key('greeting-end-replay')));
    await tester.pump();
    expect(find.text('How to Play'), findsOneWidget);
    await letsPlay(tester);
    expect(find.byKey(const Key('greeting-star-0-empty')), findsOneWidget);
    expect(completed, 0);
  });

  test('both sessions have 5 scenarios with exactly one correct choice', () {
    for (final session in [greetingDailySession, greetingMannersSession]) {
      expect(session.questions, hasLength(5));
      for (final q in session.questions) {
        expect(q.choices.where((c) => c.correct), hasLength(1), reason: q.id);
      }
    }
  });
}
