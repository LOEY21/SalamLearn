import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/ui/student_hub/hub_world.dart';
import 'package:salamlearn/ui/student_hub/profile_screen.dart';

import '../../test_helpers/hive_test_setup.dart';

void main() {
  late Directory tempDir;
  setUp(() async => tempDir = await setUpTestHive());
  tearDown(() async => tearDownTestHive(tempDir));

  testWidgets('Me tab shows real stats, homework and settings without '
      'overflow on a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(320, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ProfileScreen())),
    );
    await tester.pump();

    expect(find.text('Day Streak'), findsOneWidget);
    expect(find.text('XP'), findsOneWidget);
    expect(find.text('Badges'), findsOneWidget);
    expect(find.textContaining('Salam, friend!'), findsOneWidget);
    expect(find.text('Switch Account'), findsOneWidget);
    // Fake level/XP-ring and the duplicate badge strip are gone.
    expect(find.text('Level 3'), findsNothing);
    expect(find.text('My Badges'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the three stat tiles are the same height', (tester) async {
    tester.view.physicalSize = const Size(320, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ProfileScreen())),
    );
    await tester.pump();

    double tileHeight(String label) => tester
        .getSize(
          find.ancestor(of: find.text(label), matching: find.byType(ChunkyButton)),
        )
        .height;
    final heights = {tileHeight('Day Streak'), tileHeight('XP'), tileHeight('Badges')};
    expect(heights, hasLength(1));
    expect(heights.single, greaterThan(60));
  });
}
