import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/logic/localization/app_translations.dart'
    show AppTranslations;
import 'package:salamlearn/logic/onboarding/onboarding_checks.dart';
import 'package:salamlearn/ui/onboarding/onboarding_screen.dart';

void main() {
  tearDown(() => AppTranslations.currentLanguageCodeOverride = null);

  testWidgets('tapping Filipino switches the screen copy immediately',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.6;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        launchChecksProvider.overrideWith(
          (ref) async =>
              const LaunchCheckResult(assetsIntact: true, storageOk: true),
        ),
      ],
      child: const MaterialApp(home: Scaffold(body: OnboardingScreen())),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Continue'), findsOneWidget);

    await tester.tap(find.text('Mga aralin sa Filipino'));
    await tester.pumpAndSettle();
    expect(find.text('Magpatuloy'), findsOneWidget);
    expect(find.text('Piliin ang iyong wika'), findsOneWidget);
    expect(find.text('Continue'), findsNothing);

    await tester.tap(find.text('Mga aralin sa Ingles'));
    await tester.pumpAndSettle();
    expect(find.text('Continue'), findsOneWidget);
  });

  test('translates static, checkmarked and interpolated strings', () {
    String fil(String s) => AppTranslations.translate(s, 'fil');
    expect(fil('Settings'), 'Mga Setting');
    expect(fil('Makkah'), 'Makkah');
    expect(fil('Two above'), 'Dalawa sa itaas');
    expect(fil('Question 2 / 5'), 'Tanong 2 / 5');
    expect(fil('The Greeting Match is Locked'),
        'Naka-lock ang Pagtutugma ng Pagbati');
    expect(fil('MY CLASSES'), 'ANG AKING MGA KLASE');
    expect(AppTranslations.translate('Settings', 'en'), 'Settings');
  });
}
