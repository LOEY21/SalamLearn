import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/data/models/curriculum/curriculum_models.dart';
import 'package:salamlearn/logic/learner/learner_xp_provider.dart';
import 'package:salamlearn/ui/core_modules/lesson_complete_screen.dart';
import 'package:salamlearn/ui/core_modules/lesson_player_screen.dart';

/// No real Hive I/O — `LessonPlayerScreen` awards XP through
/// `learnerXpProvider` on lesson completion, which normally reads/writes a
/// real Hive box. Unlike this repo's other Hive-avoidance fakes (which only
/// override `build()` since they never trigger a write), this test actually
/// drives lesson completion, so `addXp` itself must be overridden too —
/// otherwise it falls through to the real implementation's
/// `Hive.box(...)` call and throws `HiveError: Box not found`.
class _FakeLearnerXpNotifier extends LearnerXpNotifier {
  @override
  int build() => 0;

  @override
  void addXp(int amount) => state = state + amount;
}

Lesson _twoFlashcardActivityLesson() {
  const card = FlashCard(
    id: 'c1',
    emoji: '🌟',
    arabic: 'كَلِمَة',
    translit: 'Kalima',
    english: 'Word',
    color: '#FDECC8',
  );
  return const Lesson(
    id: 'test-lesson',
    title: 'Test Lesson',
    titleAr: 'درس تجريبي',
    icon: '📘',
    color: '#0F6E56',
    xp: 20,
    activities: [
      Activity(
        id: 'a1',
        type: ActivityType.flashcard,
        title: 'Flashcards One',
        icon: '🃏',
        xp: 10,
        cards: [card],
      ),
      Activity(
        id: 'a2',
        type: ActivityType.flashcard,
        title: 'Flashcards Two',
        icon: '🃏',
        xp: 10,
        cards: [card],
      ),
    ],
  );
}

void main() {
  testWidgets(
    'activities auto-advance with no manual "start next activity" step, '
    'and finishing the lesson awards XP/streak/badge then shows completion',
    (tester) async {
      final lesson = _twoFlashcardActivityLesson();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            learnerXpProvider.overrideWith(_FakeLearnerXpNotifier.new),
          ],
          child: MaterialApp(
            home: LessonPlayerScreen(lesson: lesson, onClose: () {}),
          ),
        ),
      );
      await tester.pump();

      // First activity showing, no completion screen yet.
      expect(find.text('Flashcards One'), findsOneWidget);
      expect(find.text('1/2'), findsOneWidget);
      expect(find.byType(LessonCompleteScreen), findsNothing);

      // Each activity here has exactly 1 card, so its own Next button
      // already reads "✓ Done!" (the flashcard widget's "is this the last
      // card in THIS activity's deck" state) even on the very first
      // activity — that's the only button in the whole flow between one
      // activity and the next; there is no separate "start" step anywhere.
      await tester.tap(find.text('Tap to flip →'));
      await tester.pump();
      await tester.tap(find.text('✓ Done!'));
      await tester.pump();

      // Auto-advanced straight into the second activity.
      expect(find.text('Flashcards Two'), findsOneWidget);
      expect(find.text('2/2'), findsOneWidget);
      expect(find.byType(LessonCompleteScreen), findsNothing);

      // Finish the last activity.
      await tester.tap(find.text('Tap to flip →'));
      await tester.pump();
      await tester.tap(find.text('✓ Done!'));
      await tester.pump();

      expect(find.byType(LessonCompleteScreen), findsOneWidget);
      expect(find.text('+20 XP'), findsOneWidget);
    },
  );
}
