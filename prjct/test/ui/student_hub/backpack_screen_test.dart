import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/ui/student_hub/backpack_screen.dart';

Widget _wrap() {
  return const ProviderScope(
    child: MaterialApp(home: BackpackScreen()),
  );
}

Future<void> _pumpTall(WidgetTester tester) async {
  tester.view.physicalSize = const Size(400, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_wrap());
}

void main() {
  testWidgets('defaults to the Milestones tab showing earned/locked badges', (
    tester,
  ) async {
    await _pumpTall(tester);

    expect(find.text('Digital Backpack'), findsOneWidget);
    expect(find.text('Desert Calligrapher Badge'), findsOneWidget);
    expect(find.text('Earned'), findsWidgets);
    expect(find.text('Locked'), findsWidgets);
  });

  testWidgets('switching to the Streaks tab shows streak badges', (
    tester,
  ) async {
    await _pumpTall(tester);

    expect(find.text('Curious Spark Badge (3-Day Streak)'), findsNothing);

    await tester.tap(find.text('Streaks'));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Curious Spark Badge (3-Day Streak)'), findsOneWidget);
    expect(find.text('First Steps Badge'), findsOneWidget);
  });

  testWidgets('tapping a locked badge shows its requirement and XP reward', (
    tester,
  ) async {
    await _pumpTall(tester);

    await tester.tap(find.text('Sound Detective Star Badge'));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('REQUIREMENT'), findsOneWidget);
    expect(find.text('+150 XP Reward'), findsOneWidget);
  });

  Color heroTopLeftColor(WidgetTester tester) {
    final container = tester.widget<AnimatedContainer>(
      find.byKey(const Key('backpack-hero-tile')),
    );
    final gradient = (container.decoration as BoxDecoration).gradient!;
    return (gradient as LinearGradient).colors.first;
  }

  testWidgets('hero tile animates to a distinct color per tab', (
    tester,
  ) async {
    await _pumpTall(tester);
    final milestonesColor = heroTopLeftColor(tester);

    await tester.tap(find.text('Streaks'));
    await tester.pump(const Duration(milliseconds: 350));
    final streaksColor = heroTopLeftColor(tester);

    expect(milestonesColor, isNot(equals(streaksColor)));
    expect(find.text('Inventory'), findsNothing);
  });
}
