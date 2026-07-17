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

Lesson _twoPronounceActivityLesson() {
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
        type: ActivityType.pronounce,
        title: 'Listen One',
        icon: '🔊',
        xp: 10,
        cards: [card],
      ),
      Activity(
        id: 'a2',
        type: ActivityType.pronounce,
        title: 'Listen Two',
        icon: '🔊',
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
      final lesson = _twoPronounceActivityLesson();

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

      // First activity showing, no completion screen yet.
      expect(find.text('Listen One'), findsOneWidget);
      expect(find.text('1/2'), findsOneWidget);
      expect(find.byType(LessonCompleteScreen), findsNothing);

      // Tap the speaker to "play" the clip (900ms mock playback, see
      // `PronounceActivity`'s AUDIO PLUG POINT), which reveals the
      // translation and enables the Next/Done button — the only button in
      // the whole flow between one activity and the next; there is no
      // separate "start" step anywhere.
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump(const Duration(milliseconds: 950));
      await tester.tap(find.text('✓ Done!'));
      await tester.pump();

      // Auto-advanced straight into the second activity.
      expect(find.text('Listen Two'), findsOneWidget);
      expect(find.text('2/2'), findsOneWidget);
      expect(find.byType(LessonCompleteScreen), findsNothing);

      // Finish the last activity.
      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump(const Duration(milliseconds: 950));
      await tester.tap(find.text('✓ Done!'));
      await tester.pump();

      expect(find.byType(LessonCompleteScreen), findsOneWidget);
      expect(find.text('+20 XP'), findsOneWidget);
    },
  );
}
