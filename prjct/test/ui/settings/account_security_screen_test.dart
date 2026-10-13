import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/ui/settings/account_security_screen.dart';

import '../../test_helpers/responsive_harness.dart';

void main() {
  setUpAll(loadRealFonts);

  Future<void> pumpRow(
    WidgetTester tester, {
    Size size = const Size(400, 800),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: AccountSecurityRow(children: [Text('Account card')]),
            ),
          ),
        ),
      ),
    );
    await settle(tester);
    await tester.tap(find.text('Account & security'));
    await settle(tester);
  }

  testWidgets('opens a page with the account cards, Delete account last', (
    tester,
  ) async {
    await pumpRow(tester);
    expect(find.text('Account card'), findsOneWidget);
    expect(find.text('Delete Account'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Account card')).dy,
      lessThan(tester.getTopLeft(find.text('Delete Account')).dy),
    );
  });

  for (final scale in responsiveTextScales) {
    testWidgets('fits at every size, text x$scale', (tester) async {
      for (final size in responsiveSizes) {
        final label = '${size.width.toInt()}x${size.height.toInt()} @ x$scale';
        await pumpRow(tester, size: size, scale: scale);
        expect(tester.takeException(), isNull, reason: label);
        await scrollThroughChecking(tester, label);
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }
}
