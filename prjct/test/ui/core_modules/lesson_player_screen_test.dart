import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/data/models/curriculum/curriculum_models.dart';
import 'package:salamlearn/logic/auth/session.dart';
import 'package:salamlearn/logic/learner/learner_xp_provider.dart';
import 'package:salamlearn/ui/core_modules/lesson_complete_screen.dart';
import 'package:salamlearn/ui/core_modules/game_ui_audio.dart';
import 'package:salamlearn/ui/core_modules/lesson_player_screen.dart';

class _FakeGameUiAudio implements GameUiAudioPlayback {
  int taps = 0;
  int levels = 0;
  int stars = 0;

  @override
  void tap() => taps++;

  @override
  void levelComplete() => levels++;

  @override
  void starAward() => stars++;
}

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
    scenarioImage: 'assets/images/greeting_match/scenes/teacher_enters.jpg',
    arabic: 'السَّلَامُ عَلَيْكُمْ',
    meaning: 'Peace be upon you',
    choices: [
      GreetingChoice(arabic: 'شُكْرًا', meaning: 'Thank you', correct: false),
      GreetingChoice(
        arabic: 'وَعَلَيْكُمُ السَّلَامُ',
        meaning: 'And peace be upon you',
        correct: true,
      ),
    ],
  );
  const questionB = GreetingQuestion(
    id: 'q2',
    scenarioImage: 'assets/images/greeting_match/scenes/morning_greeting.jpg',
    arabic: 'صَبَاحُ الْخَيْرِ',
    meaning: 'Good Morning',
    choices: [
      GreetingChoice(
        arabic: 'صَبَاحُ النُّورِ',
        meaning: 'Good Morning',
        correct: true,
      ),
      GreetingChoice(
        arabic: 'مَسَاءُ النُّورِ',
        meaning: 'Good Evening',
        correct: false,
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
        greetingSession: GreetingMatchSession(
          title: 'Session 1',
          subtitle: 'Test',
          questions: [questionA],
        ),
      ),
      Activity(
        id: 'a2',
        type: ActivityType.pronounce,
        title: 'Greeting Two',
        icon: '👋',
        xp: 10,
        greetingSession: GreetingMatchSession(
          title: 'Session 2',
          subtitle: 'Test',
          questions: [questionB],
        ),
      ),
    ],
  );
}

void main() {
  test('shared game UI recordings are bundled', () async {
    for (final name in [
      'audio_sfx_button_tap.mp3',
      'audio_sfx_button_tap(1).mp3',
      'audio_sfx_level_complete.mp3',
      'audio_sfx_star_award.mp3',
      'audio_sfx_star_award(1).mp3',
    ]) {
      final bytes = await rootBundle.load('assets/audio/game_ui/$name');
      expect(bytes.lengthInBytes, greaterThan(1000), reason: name);
    }
  });

  testWidgets(
    'activities auto-advance with no manual "start next activity" step, '
    'and finishing the lesson awards XP/streak/badge then shows completion',
    (tester) async {
      final lesson = _twoGreetingMatchActivityLesson();
      final audio = _FakeGameUiAudio();

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
              uiAudio: audio,
            ),
          ),
        ),
      );
      await tester.pump();

      // First activity opens on the start screen. Tap play to enter matching game.
      expect(find.byKey(const Key('greeting-match-play-btn')), findsOneWidget);
      final drag = await tester.startGesture(
        tester.getCenter(find.byKey(const Key('greeting-match-play-btn'))),
      );
      await drag.moveBy(const Offset(30, 0));
      await drag.up();
      await tester.pump();
      expect(audio.taps, 0);
      await tester.tap(find.byKey(const Key('greeting-match-play-btn')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 600));

      // First activity's scenario is showing; tap the correct response —
      // it auto-advances after the celebration.
      expect(find.text('وَعَلَيْكُمُ السَّلَامُ'), findsOneWidget);
      expect(find.byType(LessonCompleteScreen), findsNothing);
      await tester.tap(find.byKey(const Key('greeting-choice-1')));
      await tester.pump(const Duration(milliseconds: 1700));

      // Auto-advanced straight into the second activity's start screen.
      expect(find.byKey(const Key('greeting-match-play-btn')), findsOneWidget);
      await tester.tap(find.byKey(const Key('greeting-match-play-btn')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 600));

      // Second activity matching screen.
      expect(find.text('صَبَاحُ النُّورِ'), findsOneWidget);
      expect(find.byType(LessonCompleteScreen), findsNothing);

      // Finish the last activity.
      await tester.tap(find.byKey(const Key('greeting-choice-0')));
      await tester.pump(const Duration(milliseconds: 1700));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(LessonCompleteScreen), findsOneWidget);
      expect(find.text('+20 XP'), findsOneWidget);
      expect(audio.taps, greaterThanOrEqualTo(4));
      expect(audio.levels, 2);
      expect(audio.stars, 1);
    },
  );
}
