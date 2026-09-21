import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/ui/student_hub/backpack_screen.dart';

Widget _wrap() {
  return const ProviderScope(
    child: MaterialApp(home: BackpackScreen()),
  );
}

// The default 800x600 test surface only fits one grid row below the hero
// header + tab selector — every test here needs to see locked cards further
// down the list, so give the surface real phone-sized headroom.
Future<void> _pumpTall(WidgetTester tester) async {
  tester.view.physicalSize = const Size(400, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_wrap());
}

void main() {
  testWidgets('defaults to the Badges tab showing earned/locked badges', (
    tester,
  ) async {
    await _pumpTall(tester);

    expect(find.text('Digital Backpack'), findsOneWidget);
    expect(find.text('First Steps'), findsOneWidget);
    expect(find.text('Earned'), findsWidgets);
    expect(find.text('Locked'), findsWidgets);
  });

  testWidgets('switching to the Stickers tab shows sticker cards', (
    tester,
  ) async {
    await _pumpTall(tester);

    expect(find.text('Moon'), findsNothing);

    await tester.tap(find.text('Stickers'));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Moon'), findsOneWidget);
  });

  testWidgets('tapping a locked sticker opens the unlock-rule detail dialog', (
    tester,
  ) async {
    await _pumpTall(tester);
    await tester.tap(find.text('Stickers'));
    await tester.pump(const Duration(milliseconds: 350));

    await tester.tap(find.text('Palm'));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('HOW TO UNLOCK'), findsOneWidget);
    expect(find.text('Complete Exploring Our World'), findsOneWidget);
  });

  testWidgets('tapping a locked badge shows its XP reward', (tester) async {
    await _pumpTall(tester);

    await tester.tap(find.text('TRACING Master'));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('+150 XP reward'), findsOneWidget);
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
    final badgesColor = heroTopLeftColor(tester);

    await tester.tap(find.text('Inventory'));
    await tester.pump(const Duration(milliseconds: 350));
    final inventoryColor = heroTopLeftColor(tester);

    await tester.tap(find.text('Stickers'));
    await tester.pump(const Duration(milliseconds: 350));
    final stickersColor = heroTopLeftColor(tester);

    expect(badgesColor, isNot(equals(inventoryColor)));
    expect(inventoryColor, isNot(equals(stickersColor)));
    expect(badgesColor, isNot(equals(stickersColor)));
  });
}
