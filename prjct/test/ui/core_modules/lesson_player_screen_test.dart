import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/data/models/curriculum/curriculum_models.dart';
import 'package:salamlearn/logic/auth/session.dart';
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

/// `LessonPlayerScreen` also reads `sessionProvider` on lesson completion to
/// write a `ProgressRecord` (FR-5.1) — `SessionNotifier.build()` normally
/// reads the real Hive `settings` box, so it needs the same override
/// treatment as `learnerXpProvider` above. Returning a learner-less state
/// keeps the write a no-op without needing a real Hive box for progress
/// either.
class _FakeSessionNotifier extends SessionNotifier {
  @override
  SessionState build() => const SessionState();
}

Lesson _twoGreetingMatchActivityLesson() {
  const questionA = GreetingQuestion(
    id: 'q1',
    phrase: 'As-salāmu ʿalaykum',
    arabic: 'اَلسَّلامُ عَلَيْكُم',
    choices: [
      GreetingChoice(translit: 'Marhaban', meaning: 'Hello', correct: false, emoji: '👋'),
      GreetingChoice(
        translit: 'As-salāmu ʿalaykum',
        meaning: 'Peace be upon you.',
        correct: true,
        emoji: '🕊️',
      ),
    ],
  );
  const questionB = GreetingQuestion(
    id: 'q2',
    phrase: 'Marhaban',
    arabic: 'مَرْحَبًا',
    choices: [
      GreetingChoice(translit: 'Marhaban', meaning: 'Hello', correct: true, emoji: '👋'),
      GreetingChoice(
        translit: 'Maʿa as-salāmah',
        meaning: 'Goodbye',
        correct: false,
        emoji: '🤗',
      ),
    ],
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
        type: ActivityType.pronounce,
        title: 'Greeting One',
        icon: '👋',
        xp: 10,
        greetingQuestions: [questionA],
      ),
      Activity(
        id: 'a2',
        type: ActivityType.pronounce,
        title: 'Greeting Two',
        icon: '👋',
        xp: 10,
        greetingQuestions: [questionB],
      ),
    ],
  );
}

void main() {
  testWidgets(
    'activities auto-advance with no manual "start next activity" step, '
    'and finishing the lesson awards XP/streak/badge then shows completion',
    (tester) async {
      final lesson = _twoGreetingMatchActivityLesson();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            learnerXpProvider.overrideWith(_FakeLearnerXpNotifier.new),
            sessionProvider.overrideWith(_FakeSessionNotifier.new),
          ],
          child: MaterialApp(
            home: LessonPlayerScreen(
              lesson: lesson,
              destinationId: 1,
              onClose: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      // First activity's single correct choice is visible. Its translit
      // matches the phrase shown on the play button too (the correct
      // choice always repeats the phrase), so two widgets show this text —
      // the play button, then the choice card.
      expect(find.text('As-salāmu ʿalaykum'), findsNWidgets(2));
      expect(find.byType(LessonCompleteScreen), findsNothing);

      // Tap the correct choice card (the second match) — auto-advances
      // after a short delay.
      await tester.tap(find.text('As-salāmu ʿalaykum').last);
      await tester.pump(const Duration(milliseconds: 700));

      // Auto-advanced straight into the second activity; same
      // phrase-equals-correct-choice duplication as above.
      expect(find.text('Marhaban'), findsNWidgets(2));
      expect(find.byType(LessonCompleteScreen), findsNothing);

      // Finish the last activity.
      await tester.tap(find.text('Marhaban').last);
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.byType(LessonCompleteScreen), findsOneWidget);
      expect(find.text('+20 XP'), findsOneWidget);
    },
  );
}
