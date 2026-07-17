import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/logic/teacher/teacher_providers.dart';
import 'package:salamlearn/ui/teacher_dashboard/class_health_detail_screen.dart';

const _classId = 'class-1';

void main() {
  testWidgets('shows overall average, per-module stats, and methodology', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          classHealthIndexProvider(_classId).overrideWithValue(const [
            ModuleHealth(
              moduleId: '1',
              moduleName: 'Alif',
              completionRate: 1.0,
              avgAccuracy: 92,
              avgErrors: 0.5,
              trend: 8.0,
              healthIndex: 90,
              hasActivity: true,
            ),
            ModuleHealth(
              moduleId: '2',
              moduleName: 'Ba',
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
          home: ClassHealthDetailScreen(classId: _classId),
        ),
      ),
    );

    expect(find.text('Class Health Index'), findsOneWidget);
    expect(find.text('90'), findsOneWidget);
    expect(find.text('Alif'), findsOneWidget);
    expect(find.text('92%'), findsOneWidget);
    expect(find.text('No activity yet'), findsOneWidget);
    expect(find.text('Tiers'), findsOneWidget);
  });

  testWidgets('shows empty state when no classroom activity exists', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          classHealthIndexProvider(_classId).overrideWithValue(const [
            ModuleHealth(
              moduleId: '1',
              moduleName: 'Alif',
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
          home: ClassHealthDetailScreen(classId: _classId),
        ),
      ),
    );

    expect(find.text('No classroom activity recorded yet.'), findsOneWidget);
  });
}
