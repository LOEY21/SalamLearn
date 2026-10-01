import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/data/curriculum_data.dart';
import 'package:salamlearn/data/models/curriculum/curriculum_models.dart';
import 'package:salamlearn/ui/student_hub/destination_levels_sheet.dart';

void main() {
  testWidgets('tapping an unlocked lesson tile launches it directly, with no '
      'intermediate "Start Activity" step', (tester) async {
    final destination = curriculum.first;
    Lesson? started;
    var isNewLevelSeen = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => DestinationLevelsSheet.show(
                context,
                destination: destination,
                completedLessons: ValueNotifier(const <String>{}),
                noorEnergy: 5,
                onStartLesson: (lesson, isNewLevel) {
                  started = lesson;
                  isNewLevelSeen = isNewLevel;
                },
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    // The sheet's entrance uses an overshoot curve over 300ms — settle
    // past it rather than pumpAndSettle (no infinite animations here,
    // but an explicit duration keeps this in line with this repo's other
    // Adventure Map tests).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(DestinationLevelsSheet), findsOneWidget);

    final firstLesson = destination.lessons.first;
    // Only the first lesson in level 1 is unlocked with no completions
    // recorded yet — tapping its title text hits the tile's
    // `GestureDetector` (no dedicated key on the tile itself, so this
    // finds it the same way a learner would: by what's on screen).
    await tester.tap(find.text(firstLesson.title));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(started, same(firstLesson));
    expect(isNewLevelSeen, isTrue);
    // The sheet closes itself before handing off to `onStartLesson` —
    // matching the source's "no confirmation screen" behavior exactly.
    expect(find.byType(DestinationLevelsSheet), findsNothing);
  });

  testWidgets('level 2 stays locked until every level 1 lesson is done', (
    tester,
  ) async {
    final destination = curriculum.first;
    final perLevel = (destination.lessons.length / 3).ceil();
    final level2First = destination.lessons[perLevel];
    Lesson? started;

    Future<void> open(Set<String> completed) async {
      started = null;
      await tester.pumpWidget(
        MaterialApp(
          key: UniqueKey(),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => DestinationLevelsSheet.show(
                  context,
                  destination: destination,
                  completedLessons: ValueNotifier(completed),
                  noorEnergy: 5,
                  onStartLesson: (lesson, _) => started = lesson,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.ensureVisible(
        find.text(level2First.title, skipOffstage: false),
      );
      await tester.pump();
      await tester.tap(find.text(level2First.title));
      await tester.pump();
    }

    await open(const <String>{});
    expect(started, isNull);

    await open({for (final l in destination.lessons.take(perLevel)) l.id});
    expect(started, same(level2First));
  });

  testWidgets('marks a lesson completed while the sheet is still open', (
    tester,
  ) async {
    final destination = curriculum.first;
    final completed = ValueNotifier(const <String>{});

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => DestinationLevelsSheet.show(
                context,
                destination: destination,
                completedLessons: completed,
                noorEnergy: 5,
                onStartLesson: (_, _) {},
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('✓ Completed'), findsNothing);

    completed.value = {destination.lessons.first.id};
    await tester.pump();

    expect(find.text('✓ Completed'), findsOneWidget);
  });
}
