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
                completedLessons: const <String>{},
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

  testWidgets('a locked destination shows the locked message, not levels', (
    tester,
  ) async {
    final lockedDestination = Destination(
      id: 999,
      name: 'Test Peak',
      nameAr: 'قمة الاختبار',
      icon: '🏔️',
      color: '#000000',
      bg: '#FFFFFF',
      mapX: 0,
      mapY: 0,
      description: 'A locked test destination.',
      state: DestinationState.locked,
      lessons: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => DestinationLevelsSheet.show(
                context,
                destination: lockedDestination,
                completedLessons: const <String>{},
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

    expect(find.text('Complete earlier destinations first!'), findsOneWidget);
  });
}
