import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/data/curriculum_data.dart';
import 'package:salamlearn/data/student_badges.dart';
import 'package:salamlearn/ui/core_modules/module_registry.dart';

void main() {
  group('Milestone badge all-sessions requirement', () {
    test('areAllGameSessionsCompleted requires every session of the game', () {
      final sandTracerGame = allGames.firstWhere(
        (g) => g.lesson.title.contains('Magic Sand Tracer'),
      );
      final gameName = gameNameOf(sandTracerGame.lesson);
      final sessions = gameSessions[gameName]!;

      expect(sessions.length, 4);

      final completedIds = <String>{};

      // 0 sessions completed
      expect(
        areAllGameSessionsCompleted(sandTracerGame.lesson, completedIds),
        isFalse,
      );

      // 1 session completed
      completedIds.add(sessions[0].id);
      expect(
        areAllGameSessionsCompleted(sandTracerGame.lesson, completedIds),
        isFalse,
      );

      // 2 sessions completed
      completedIds.add(sessions[1].id);
      expect(
        areAllGameSessionsCompleted(sandTracerGame.lesson, completedIds),
        isFalse,
      );

      // 3 sessions completed
      completedIds.add(sessions[2].id);
      expect(
        areAllGameSessionsCompleted(sandTracerGame.lesson, completedIds),
        isFalse,
      );

      // All 4 sessions completed
      completedIds.add(sessions[3].id);
      expect(
        areAllGameSessionsCompleted(sandTracerGame.lesson, completedIds),
        isTrue,
      );

      final badge = badgeForLessonTitle(sandTracerGame.lesson.title);
      expect(badge, isNotNull);
      expect(badge!.id, 'desert_calligrapher');
    });

    test('The Greeting Match badge requires all 2 sessions', () {
      final greetingGame = allGames.firstWhere(
        (g) => g.lesson.title.contains('The Greeting Match'),
      );
      final gameName = gameNameOf(greetingGame.lesson);
      final sessions = gameSessions[gameName]!;

      expect(sessions.length, 2);

      final completedIds = <String>{sessions[0].id};
      expect(
        areAllGameSessionsCompleted(greetingGame.lesson, completedIds),
        isFalse,
      );

      completedIds.add(sessions[1].id);
      expect(
        areAllGameSessionsCompleted(greetingGame.lesson, completedIds),
        isTrue,
      );

      final badge = badgeForLessonTitle(greetingGame.lesson.title);
      expect(badge, isNotNull);
      expect(badge!.id, 'greeting_ambassador');
    });

    test('Ayah Builder badge requires all 7 sessions', () {
      final ayahGame = allGames.firstWhere(
        (g) => g.lesson.title.contains('Ayah Builder'),
      );
      final gameName = gameNameOf(ayahGame.lesson);
      final sessions = gameSessions[gameName]!;

      expect(sessions.length, 7);

      final completedIds = <String>{};
      for (var i = 0; i < 6; i++) {
        completedIds.add(sessions[i].id);
        expect(
          areAllGameSessionsCompleted(ayahGame.lesson, completedIds),
          isFalse,
        );
      }

      completedIds.add(sessions[6].id);
      expect(
        areAllGameSessionsCompleted(ayahGame.lesson, completedIds),
        isTrue,
      );

      final badge = badgeForLessonTitle(ayahGame.lesson.title);
      expect(badge, isNotNull);
      expect(badge!.id, 'ayah_builder');
    });
  });
}
