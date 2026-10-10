import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/data/models/class_section.dart';
import 'package:salamlearn/logic/auth/session.dart';
import 'package:salamlearn/logic/teacher/teacher_providers.dart';
import 'package:salamlearn/ui/teacher_dashboard/lesson_folder_builder_screen.dart';

class _FakeTeacherClassController extends TeacherClassController {
  _FakeTeacherClassController(this._section);
  final ClassSection? _section;

  @override
  ClassSection? build() => _section;
}

class _FakeTeacherSessionNotifier extends SessionNotifier {
  @override
  SessionState build() => const SessionState(activeTeacherId: 'teacher-1');
}

ClassSection _testClass() => ClassSection(
  id: 'class-1',
  teacherId: 'teacher-1',
  name: 'Grade 1 - Section A',
  invitationCode: 'ABC123',
  createdAt: DateTime(2026, 1, 1),
);

void main() {
  testWidgets(
    'renders 12 games in module selection and expanding shows sessions',
    (tester) async {
      final section = _testClass();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            teacherClassControllerProvider.overrideWith(
              () => _FakeTeacherClassController(section),
            ),
            sessionProvider.overrideWith(_FakeTeacherSessionNotifier.new),
          ],
          child: const MaterialApp(home: LessonFolderBuilderScreen()),
        ),
      );

      // Verify header and 12 games label
      expect(find.text('Build Lesson Folder'), findsOneWidget);
      expect(find.text('Module library · 12 games'), findsOneWidget);

      // Verify first game is rendered in the accordion list
      expect(find.text('Greeting Match'), findsOneWidget);

      // The first game (Greeting Match) starts expanded — verify its sessions are visible
      expect(find.text('Sessions (2)'), findsOneWidget);
      expect(find.text('Select all'), findsWidgets);

      // Tap "Select all" to add all sessions of this game to the timeline
      await tester.tap(find.text('Select all').first);
      await tester.pumpAndSettle();

      // Verify count updated in selected pill (Greeting Match has 2 sessions)
      expect(find.text('2 selected'), findsOneWidget);
      expect(find.text('Remove all'), findsOneWidget);
    },
  );
}
