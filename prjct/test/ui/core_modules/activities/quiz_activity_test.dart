import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/data/models/curriculum/curriculum_models.dart';
import 'package:salamlearn/ui/core_modules/activities/quiz_activity.dart';

void main() {
  testWidgets('all-correct quiz reports 100% accuracy and full XP', (
    tester,
  ) async {
    (int, double, int)? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuizActivity(
            questions: const [
              QuizQ(
                id: 'q1',
                emoji: '🕌',
                question: 'Pick the right one',
                options: ['Right', 'Wrong'],
                correct: 0,
              ),
            ],
            xp: 10,
            color: Colors.teal,
            onComplete: (xp, accuracy, errors) =>
                result = (xp, accuracy, errors),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Right'));
    await tester.pump();
    await tester.tap(find.text('✓ Finish!'));
    await tester.pump();

    expect(result, (10, 100.0, 0));
  });
}
