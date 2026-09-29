import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/data/models/class_section.dart';
import 'package:salamlearn/data/models/curriculum/curriculum_models.dart';
import 'package:salamlearn/data/models/lesson_folder.dart';
import 'package:salamlearn/logic/teacher/teacher_providers.dart';
import 'package:salamlearn/ui/teacher_dashboard/cast_games.dart';
import 'package:salamlearn/ui/teacher_dashboard/module_library_data.dart';

class _FakeClass extends TeacherClassController {
  @override
  ClassSection? build() => ClassSection(
    id: 'c1',
    teacherId: 't1',
    name: 'Grade 1 - A',
    invitationCode: 'ABC123',
    createdAt: DateTime(2026),
  );
}

void main() {
  final folder = LessonFolder(
    id: 'f1',
    teacherId: 't1',
    classId: 'c1',
    name: 'Week 4: Wudhu',
    itemRefs: [allModuleRefs[0].ref, allModuleRefs[1].ref],
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  Future<List<(Lesson, int)>> pump(
    WidgetTester tester, {
    String? student = 'Amina',
  }) async {
    final played = <(Lesson, int)>[];
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          teacherClassControllerProvider.overrideWith(_FakeClass.new),
          classLessonFoldersProvider('c1').overrideWithValue([folder]),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: CastGamesStage(
              student: student,
              onPlay: (lesson, dest) => played.add((lesson, dest)),
              onOpenLibrary: () {},
            ),
          ),
        ),
      ),
    );
    return played;
  }

  test('every curriculum game appears once, in curriculum order', () {
    final types = {for (final m in allModuleRefs) m.activity.type};
    expect(castGames.map((g) => g.type), types.toList());
    expect(
      castGames.fold<int>(0, (n, g) => n + g.sessions.length),
      allModuleRefs.length,
    );
  });

  testWidgets('picking a game session plays just that activity', (
    tester,
  ) async {
    final played = await pump(tester);
    final game = castGames.first;
    await tester.tap(find.byKey(ValueKey('cast-game-${game.type.name}')));
    await tester.pumpAndSettle();

    await tester.tap(find.text(game.sessions[1].activity.title).last);
    await tester.pumpAndSettle();

    expect(played, hasLength(1));
    expect(played.single.$1.activities.single.id, game.sessions[1].activity.id);
    expect(played.single.$2, game.sessions[1].destinationId);
  });

  testWidgets('games stay locked until Hot Seat picks a student', (
    tester,
  ) async {
    final played = await pump(tester, student: null);
    expect(find.text('Spin the Hot Seat first'), findsOneWidget);
    await tester.tap(
      find.byKey(ValueKey('cast-game-${castGames.first.type.name}')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(played, isEmpty);
  });

  testWidgets('a Module Library folder plays its modules in order', (
    tester,
  ) async {
    final played = await pump(tester);
    await tester.tap(find.byKey(const ValueKey('cast-tab-library')));
    await tester.pumpAndSettle();
    expect(find.text('Week 4: Wudhu'), findsOneWidget);

    await tester.tap(find.text('Week 4: Wudhu'));
    await tester.pump();

    expect(played.single.$1.title, 'Week 4: Wudhu');
    expect(played.single.$1.activities.map((a) => a.id), [
      allModuleRefs[0].activity.id,
      allModuleRefs[1].activity.id,
    ]);
  });
}
