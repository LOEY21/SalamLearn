import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/data/models/class_section.dart';
import 'package:salamlearn/logic/teacher/teacher_providers.dart';
import 'package:salamlearn/ui/teacher_dashboard/module_library_screen.dart';

/// Avoids the real Hive-backed [TeacherClassController.build] (which reads
/// `sessionProvider`/the `settings` box) — same "override the Notifier,
/// not just the provider" treatment `lesson_player_screen_test.dart` uses
/// for its own Hive-backed providers.
class _FakeTeacherClassController extends TeacherClassController {
  _FakeTeacherClassController(this._section);
  final ClassSection? _section;

  @override
  ClassSection? build() => _section;
}

ClassSection _testClass() => ClassSection(
  id: 'class-1',
  teacherId: 'teacher-1',
  name: 'Grade 1 - Section A',
  invitationCode: 'ABC123',
  createdAt: DateTime(2026, 1, 1),
);

void main() {
  testWidgets('prompts to create a class when none is active', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          teacherClassControllerProvider.overrideWith(
            () => _FakeTeacherClassController(null),
          ),
        ],
        child: const MaterialApp(home: ModuleLibraryScreen()),
      ),
    );

    expect(find.text('Create a class first'), findsOneWidget);
    expect(find.text('New lesson folder'), findsNothing);
  });

  testWidgets('shows the empty state and a New lesson folder action for '
      'an active class with no saved folders', (tester) async {
    final section = _testClass();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          teacherClassControllerProvider.overrideWith(
            () => _FakeTeacherClassController(section),
          ),
          classLessonFoldersProvider(section.id).overrideWithValue(const []),
        ],
        child: const MaterialApp(home: ModuleLibraryScreen()),
      ),
    );

    expect(
      find.textContaining('No lesson folders yet'),
      findsOneWidget,
    );
    expect(find.text('New lesson folder'), findsOneWidget);
  });
}
