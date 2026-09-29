import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/data/curriculum_data.dart';
import 'package:salamlearn/ui/core_modules/module_registry.dart';

void main() {
  test('teacher can assign every Student Hub game', () {
    expect(
      allGames.length,
      curriculum.fold<int>(0, (n, d) => n + d.lessons.length),
    );
  });

  test('a game assignment resolves to that game and its map node', () {
    final game = allGames[7];
    expect(assignmentTitle(game.lesson.id), game.lesson.title);
    expect(
      moduleForAssignment(game.lesson.id)?.destinationId,
      game.destination.id,
    );
    expect(assignedLessonsFor(game.lesson.id, 3, null), [game.lesson]);
  });

  test('older whole-destination and unknown assignments still resolve', () {
    final first = curriculum.first;
    expect(assignmentTitle('${first.id}'), first.name);
    expect(assignedLessonsFor(coreModules.first.id, 3, null), first.lessons);
    expect(moduleForAssignment('Letters Tracing (Alif to Kha)'), isNull);
    expect(assignedLessonsFor('Letters Tracing (Alif to Kha)', 3, null), isEmpty);
  });

  test('games group into the 12 Student Hub games with their sessions', () {
    expect(gameSessions.length, 12);
    expect(
      gameSessions.values.fold<int>(0, (n, s) => n + s.length),
      allGames.length,
    );
    final sky = gameSessions["Allah's Creation Hunt"]![1];
    expect(sessionLabelOf(sky), 'Session 2 (Sky)');
  });
}
