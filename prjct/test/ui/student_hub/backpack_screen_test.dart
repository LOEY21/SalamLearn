import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/logic/auth/session.dart';
import 'package:salamlearn/ui/student_hub/backpack_screen.dart';

/// No learner signed in: badges resolve to "none earned" without Hive —
/// the same shelf a brand-new child sees.
class _FakeSessionNotifier extends SessionNotifier {
  @override
  SessionState build() => const SessionState();
}

Widget _wrap() {
  return ProviderScope(
    overrides: [sessionProvider.overrideWith(_FakeSessionNotifier.new)],
    child: const MaterialApp(home: BackpackScreen()),
  );
}

Future<void> _pumpTall(WidgetTester tester) async {
  tester.view.physicalSize = const Size(400, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_wrap());
  await tester.pump();
}

void main() {
  testWidgets('defaults to the Milestones shelves with earned/locked badges', (
    tester,
  ) async {
    await _pumpTall(tester);

    expect(find.text('Digital Backpack'), findsOneWidget);
    expect(find.text('Desert Calligrapher'), findsOneWidget);
    expect(find.text('Locked'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching to the Streaks tab shows streak badges', (
    tester,
  ) async {
    await _pumpTall(tester);

    expect(find.text('Curious Spark (3-Day Streak)'), findsNothing);

    await tester.tap(find.text('Streaks'));
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Curious Spark (3-Day Streak)'), findsOneWidget);
    expect(find.text('First Steps'), findsOneWidget);
  });

  testWidgets('tapping a locked badge opens a sheet with how to earn it', (
    tester,
  ) async {
    await _pumpTall(tester);

    await tester.tap(find.text('Sound Detective Star'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Sound Detective Star Badge'), findsOneWidget);
    expect(find.text('How to earn it'), findsOneWidget);
    expect(find.text('+150 XP Reward'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('How to earn it'), findsNothing);
  });

  testWidgets('narrow phone width does not overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(_wrap());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('badges on a shelf line up whatever their name length', (
    tester,
  ) async {
    await _pumpTall(tester);

    // First shelf: two-line names next to a one-line one.
    final medalTops = [
      for (final e in find.byType(BadgeMedallion).evaluate().take(3))
        tester.getTopLeft(find.byWidget(e.widget)).dy,
    ];
    expect(medalTops.toSet(), hasLength(1));

    final statusTops = [
      for (final e in find.text('Locked').evaluate().take(2))
        tester.getTopLeft(find.byWidget(e.widget)).dy,
    ];
    expect(statusTops.toSet(), hasLength(1));
  });
}
