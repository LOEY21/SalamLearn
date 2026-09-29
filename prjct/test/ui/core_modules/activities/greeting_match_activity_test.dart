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
  }) {
    return MaterialApp(
      home: Scaffold(
        body: GreetingMatchActivity(
          session: session,
          xp: 100,
          onComplete: onComplete ?? (_, _, _) {},
          onBack: () {},
        ),
      ),
    );
  }

  Future<void> startGame(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('greeting-match-play-btn')));
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> waitForChoices(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 600));
  }

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
    expect(find.byKey(const Key('greeting-star-0-off')), findsOneWidget);
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
    expect(errors, 0);
  });

  testWidgets('wrong choice counts an error and does not advance',
      (tester) async {
    int? errors;
    await tester.pumpWidget(
      buildTestWidget(onComplete: (_, _, e) => errors = e),
    );
    await tester.pump();
    await startGame(tester);
    await waitForChoices(tester);

    await tester.tap(find.byKey(const Key('greeting-choice-0')));
    await tester.pump(const Duration(milliseconds: 800));
    expect(errors, isNull);
    expect(find.byKey(const Key('greeting-star-0-off')), findsOneWidget);

    await tester.tap(find.byKey(const Key('greeting-choice-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const Key('greeting-star-0-on')), findsOneWidget);
    expect(find.text('Mumtaz!'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1500));
    expect(errors, 1);
  });

  testWidgets('correct choice earns a star and completes the activity',
      (tester) async {
    double? accuracy;
    await tester.pumpWidget(
      buildTestWidget(onComplete: (_, a, _) => accuracy = a),
    );
    await tester.pump();
    await startGame(tester);
    await waitForChoices(tester);

    await tester.tap(find.byKey(const Key('greeting-choice-1')));
    await tester.pump(const Duration(milliseconds: 1700));

    expect(accuracy, 100.0);
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
