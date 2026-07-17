import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/logic/teacher/teacher_providers.dart';
import 'package:salamlearn/ui/teacher_dashboard/teacher_dashboard_screen.dart';

const _classId = 'class-1';

void main() {
  testWidgets('shows "no activity yet" for a module with hasActivity false', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          classHealthIndexProvider(_classId).overrideWithValue(const [
            ModuleHealth(
              moduleId: '1',
              moduleName: 'Alif to Yaa',
              completionRate: 0,
              avgAccuracy: 0,
              avgErrors: 0,
              trend: null,
              healthIndex: 0,
              hasActivity: false,
            ),
          ]),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ClassHealthSection(classId: _classId)),
        ),
      ),
    );

    expect(find.text('Alif to Yaa'), findsOneWidget);
    expect(find.text('Not cast yet this week'), findsOneWidget);
  });

  testWidgets('shows a High health pill and an upward trend for a healthy module', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          classHealthIndexProvider(_classId).overrideWithValue(const [
            ModuleHealth(
              moduleId: '1',
              moduleName: 'Alif to Yaa',
              completionRate: 1.0,
              avgAccuracy: 92,
              avgErrors: 0.5,
              trend: 8.0,
              healthIndex: 90,
              hasActivity: true,
            ),
          ]),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ClassHealthSection(classId: _classId)),
        ),
      ),
    );

    expect(find.text('Alif to Yaa'), findsOneWidget);
    expect(find.text('HIGH'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
  });

  testWidgets('shows a Needs help pill and a downward trend for a struggling module', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          classHealthIndexProvider(_classId).overrideWithValue(const [
            ModuleHealth(
              moduleId: '1',
              moduleName: 'Alif to Yaa',
              completionRate: 0.3,
              avgAccuracy: 40,
              avgErrors: 3,
              trend: -5.0,
              healthIndex: 30,
              hasActivity: true,
            ),
          ]),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ClassHealthSection(classId: _classId)),
        ),
      ),
    );

    expect(find.text('NEEDS HELP'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_downward_rounded), findsOneWidget);
  });
}
