import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/data/models/class_section.dart';
import 'package:salamlearn/logic/teacher/teacher_providers.dart';
import 'package:salamlearn/ui/teacher_dashboard/cast_screen.dart';

class _NoClass extends TeacherClassController {
  @override
  ClassSection? build() => null;
}

void main() {
  testWidgets('Hot Seat draws a student first, then games unlock', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeClassNameProvider.overrideWithValue('Grade 1 - A'),
          teacherRosterProvider.overrideWithValue([
            {'learnerId': 'l1', 'name': 'Amina'},
            {'learnerId': 'l2', 'name': 'Yusuf'},
          ]),
          teacherClassControllerProvider.overrideWith(_NoClass.new),
        ],
        child: const MaterialApp(home: CastScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Spin the Hot Seat first'), findsOneWidget);
    expect(find.byKey(const ValueKey('cast-hot-seat-student')), findsNothing);

    await tester.tap(find.text('Spin the wheel'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();

    final name = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('cast-hot-seat-student')),
        matching: find.byType(Text),
      ),
    );
    expect(['Amina', 'Yusuf'], contains(name.data));
    expect(find.text('Spin the Hot Seat first'), findsNothing);
    expect(find.text('for ${name.data}'), findsOneWidget);
  });
}
