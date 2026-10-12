import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:salamlearn/data/models/class_section.dart';
import 'package:salamlearn/logic/teacher/teacher_providers.dart';
import 'package:salamlearn/ui/teacher_dashboard/class_detail_screen.dart';
import 'package:salamlearn/ui/teacher_dashboard/classroom_management_screen.dart';

class _FakeTeacherClassController extends TeacherClassController {
  _FakeTeacherClassController(this._section);
  final ClassSection _section;

  @override
  ClassSection? build() => _section;
}

/// Stand-in for the Teacher Hub's Classroom tab entry row.
class _Hub extends StatelessWidget {
  const _Hub();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () => context.push('/teacher/classes'),
        child: const Text('Classroom Management'),
      ),
    ),
  );
}

void main() {
  testWidgets('hub → classes → class open on top of each other, and Back '
      'slides each one off to reveal the same screen underneath', (
    tester,
  ) async {
    final section = ClassSection(
      id: 'class-1',
      teacherId: 'teacher-1',
      name: 'Grade 1 - Section A',
      invitationCode: 'ABC123',
      createdAt: DateTime(2026, 1, 1),
    );
    final router = GoRouter(
      initialLocation: '/teacher',
      routes: [
        GoRoute(path: '/teacher', builder: (_, _) => const _Hub()),
        GoRoute(
          path: '/teacher/classes',
          builder: (_, _) => const ClassroomManagementScreen(),
        ),
        GoRoute(
          path: '/teacher/classes/:classId',
          builder: (_, state) =>
              ClassDetailScreen(classId: state.pathParameters['classId']!),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          teacherClassControllerProvider.overrideWith(
            () => _FakeTeacherClassController(section),
          ),
          teacherClassesProvider.overrideWithValue([section]),
          archivedTeacherClassesProvider.overrideWithValue(const []),
          teacherTotalStudentsProvider.overrideWithValue(0),
          classRosterProvider(section.id).overrideWithValue(const []),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    final hub = tester.state(find.byType(Navigator));
    await tester.tap(find.text('Classroom Management'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('My Classes'), findsOneWidget);
    final classes = tester.state(find.byType(ClassroomManagementScreen));

    // Active class, so no switch overlay — straight to its screen.
    await tester.tap(find.text('Grade 1 - Section A').first);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Enroll a learner'), findsOneWidget);
    expect(router.canPop(), isTrue);

    // Back from the class: it slides off over the class list...
    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Enroll a learner'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Enroll a learner'), findsNothing);
    // ...revealing the very same class list, not a rebuilt one.
    expect(tester.state(find.byType(ClassroomManagementScreen)), same(classes));

    // Back from the class list returns to the hub the same way.
    await tester.tap(find.byTooltip('Back'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('My Classes'), findsNothing);
    expect(find.text('Classroom Management'), findsOneWidget);
    expect(tester.state(find.byType(Navigator)), same(hub));
    expect(router.canPop(), isFalse);
  });
}
