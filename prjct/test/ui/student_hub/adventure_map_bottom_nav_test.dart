import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/ui/student_hub/adventure_map_bottom_nav.dart';
import 'package:salamlearn/ui/student_hub/hub_bottom_nav.dart';

void main() {
  testWidgets('tapping Backpack calls onBackpackTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdventureMapBottomNav(
            active: HubTab.home,
            onHomeTap: () {},
            onBackpackTap: () => tapped = true,
            onProfileTap: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Backpack'));
    expect(tapped, true);
  });

  testWidgets('shows the unread dot on Backpack only when showBackpackBadge is true', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AdventureMapBottomNav(
            active: HubTab.home,
            onHomeTap: _noop,
            onBackpackTap: _noop,
            onProfileTap: _noop,
            showBackpackBadge: true,
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('backpack-nav-badge-dot')), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AdventureMapBottomNav(
            active: HubTab.home,
            onHomeTap: _noop,
            onBackpackTap: _noop,
            onProfileTap: _noop,
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('backpack-nav-badge-dot')), findsNothing);
  });
}

void _noop() {}
