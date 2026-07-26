import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:salamlearn/data/models/curriculum/curriculum_models.dart';
import 'package:salamlearn/ui/core_modules/activities/fiqh_drag_activity.dart';

void main() {
  // Wudhu Master's 10-step order ('dest1-fiqh-3' content). The game is
  // check-based: any step may sit in any slot, and ✓/✗ only appear after
  // "Check my answer".
  final items = [
    const FiqhDragItem(id: 'u1', emoji: '👐', label: 'Wash Hands', correctZoneId: '1'),
    const FiqhDragItem(id: 'u2', emoji: '👄', label: 'Rinse Mouth', correctZoneId: '2'),
    const FiqhDragItem(id: 'u3', emoji: '👃', label: 'Rinse Nose', correctZoneId: '3'),
    const FiqhDragItem(id: 'u4', emoji: '👤', label: 'Wash Face', correctZoneId: '4'),
    const FiqhDragItem(id: 'u5', emoji: '💪', label: 'Wash Right Arm', correctZoneId: '5'),
    const FiqhDragItem(id: 'u6', emoji: '💪', label: 'Wash Left Arm', correctZoneId: '6'),
    const FiqhDragItem(id: 'u7', emoji: '🧕', label: 'Wipe Head', correctZoneId: '7'),
    const FiqhDragItem(id: 'u8', emoji: '👂', label: 'Wipe Ears', correctZoneId: '8'),
    const FiqhDragItem(id: 'u9', emoji: '🦶', label: 'Wash Right Foot', correctZoneId: '9'),
    const FiqhDragItem(id: 'u10', emoji: '🦶', label: 'Wash Left Foot', correctZoneId: '10'),
  ];

  // The game is laid out against the comp's 400x853 phone frame; the default
  // 800x600 test surface pushes the intro card and the check bar off-screen.
  setUp(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher
        .implicitView!;
    view.devicePixelRatio = 1.0;
    view.physicalSize = const Size(400, 853);
  });

  tearDown(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher
        .implicitView!;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Widget host({void Function(int, double, int)? onComplete}) => MaterialApp(
    home: Scaffold(
      body: FiqhDragActivity(
        activityId: 'dest1-fiqh-3',
        items: items,
        zones: const [],
        xp: 50,
        color: const Color(0xFFD85A30),
        onComplete: onComplete ?? (_, _, _) {},
      ),
    ),
  );

  /// Pumps the activity and taps through the intro card into the board.
  Future<void> pumpGame(
    WidgetTester tester, {
    void Function(int, double, int)? onComplete,
  }) async {
    await tester.pumpWidget(host(onComplete: onComplete));
    await tester.pumpAndSettle();
    await tester.tap(find.text('▶  START'));
    await tester.pumpAndSettle();
  }

  /// Tap-to-place: select the tray card for [stepId], then tap slot [slotIndex].
  Future<void> place(WidgetTester tester, int stepId, int slotIndex) async {
    await tester.ensureVisible(find.byKey(ValueKey('wudhuTrayCard$stepId')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('wudhuTrayCard$stepId')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(ValueKey('wudhuSlot$slotIndex')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('wudhuSlot$slotIndex')));
    await tester.pumpAndSettle();
  }

  testWidgets('intro card gates the board until START is tapped',
      (tester) async {
    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    expect(find.text('▶  START'), findsOneWidget);
    expect(find.byKey(const ValueKey('wudhuSlot0')), findsNothing);

    await tester.tap(find.text('▶  START'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('wudhuSlot0')), findsOneWidget);

    // 10 slots, not the old hardcoded 6.
    expect(find.byKey(const ValueKey('wudhuSlot9')), findsOneWidget);
  });

  testWidgets('the board scrolls vertically and the tray horizontally',
      (tester) async {
    await pumpGame(tester);

    final board = tester
        .stateList<ScrollableState>(find.byType(Scrollable))
        .firstWhere((s) => s.position.axis == Axis.vertical);
    final tray = tester
        .stateList<ScrollableState>(find.byType(Scrollable))
        .firstWhere((s) => s.position.axis == Axis.horizontal);

    expect(board.position.maxScrollExtent, greaterThan(0));
    expect(tray.position.maxScrollExtent, greaterThan(0));

    // Swiping over a slot row must reach the board, not start a card drag.
    await tester.drag(
      find.byKey(const ValueKey('wudhuSlot2')),
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    expect(board.position.pixels, greaterThan(0));

    // Swiping over a tray card must reach the tray, not start a card drag.
    // The shuffle can park step 1 off-screen, so bring it in range first.
    await tester.ensureVisible(find.byKey(const ValueKey('wudhuTrayCard1')));
    await tester.pumpAndSettle();
    final trayBefore = tray.position.pixels;
    await tester.drag(
      find.byKey(const ValueKey('wudhuTrayCard1')),
      const Offset(-150, 0),
    );
    await tester.pumpAndSettle();
    expect(tray.position.pixels, greaterThan(trayBefore));
  });

  testWidgets('a tray card still drags up onto a slot', (tester) async {
    await pumpGame(tester);

    await tester.ensureVisible(find.byKey(const ValueKey('wudhuTrayCard1')));
    await tester.pumpAndSettle();

    final from = tester.getCenter(find.byKey(const ValueKey('wudhuTrayCard1')));
    final to = tester.getCenter(find.byKey(const ValueKey('wudhuSlot0')));
    final gesture = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 20));
    for (var step = 1; step <= 8; step++) {
      await gesture.moveTo(Offset.lerp(from, to, step / 8)!);
      await tester.pump(const Duration(milliseconds: 20));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('wudhuTrayCard1')), findsNothing);
    expect(find.text('WASH HANDS'), findsOneWidget);
  });

  testWidgets('all 10 steps start in the tray', (tester) async {
    await pumpGame(tester);

    for (var stepId = 1; stepId <= 10; stepId++) {
      expect(
        find.byKey(ValueKey('wudhuTrayCard$stepId')),
        findsOneWidget,
        reason: 'step $stepId should be in the tray',
      );
    }
    expect(find.text('Fill every slot to check'), findsOneWidget);
  });

  testWidgets('tap-to-place moves a step out of the tray into its slot',
      (tester) async {
    await pumpGame(tester);

    await place(tester, 1, 0);

    expect(find.byKey(const ValueKey('wudhuTrayCard1')), findsNothing);
    expect(find.text('WASH HANDS'), findsOneWidget);
  });

  testWidgets('a wrong order scores partially and offers Retry',
      (tester) async {
    await pumpGame(tester);

    // Reversed order — no step lands on its own slot.
    for (var stepId = 1; stepId <= 10; stepId++) {
      await place(tester, stepId, 10 - stepId);
    }

    await tester.tap(find.text('✓ Check my answer'));
    await tester.pumpAndSettle();

    expect(find.text('↺ Retry'), findsOneWidget);
    expect(find.text('Great — 0/10 correct!'), findsOneWidget);
    expect(find.text("MASHA'ALLAH!"), findsNothing);
  });

  testWidgets('the correct order wins and hands XP back on collect',
      (tester) async {
    var awardedXp = 0;
    await pumpGame(tester, onComplete: (xp, _, _) => awardedXp = xp);

    for (var stepId = 1; stepId <= 10; stepId++) {
      await place(tester, stepId, stepId - 1);
    }

    await tester.tap(find.text('✓ Check my answer'));
    await tester.pumpAndSettle();

    expect(find.text("MASHA'ALLAH!"), findsOneWidget);

    await tester.tap(find.text('Collect 50 XP'));
    await tester.pumpAndSettle();

    expect(awardedXp, 50);
  });
}
