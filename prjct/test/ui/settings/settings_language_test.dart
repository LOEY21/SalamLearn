import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/logic/auth/session.dart';
import 'package:salamlearn/logic/localization/app_translations.dart'
    as l10n;
import 'package:salamlearn/ui/settings/settings_screen.dart';

/// Hive-free session: records the picked language instead of writing the
/// real `settings` box.
class _FakeSessionNotifier extends SessionNotifier {
  static String? saved;

  @override
  SessionState build() => const SessionState(languageCode: 'en');

  @override
  void setLanguage(String code) {
    saved = code;
    l10n.AppTranslations.currentLanguageCodeOverride = code;
    state = state.copyWith(languageCode: code);
  }
}

void main() {
  tearDown(() => l10n.AppTranslations.currentLanguageCodeOverride = null);

  testWidgets('FIL/EN toggle saves the language and re-translates const text',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [sessionProvider.overrideWith(_FakeSessionNotifier.new)],
      child: const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [l10n.Text('Settings'), LanguageSettingRow()],
          ),
        ),
      ),
    ));
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('App language'), findsOneWidget);

    await tester.tap(find.text('FIL'));
    await tester.pump();
    expect(_FakeSessionNotifier.saved, 'fil');
    expect(find.text('Mga Setting'), findsOneWidget);
    expect(find.text('Wika ng app'), findsOneWidget);

    await tester.tap(find.text('EN'));
    await tester.pump();
    expect(_FakeSessionNotifier.saved, 'en');
    expect(find.text('Settings'), findsOneWidget);
  });
}
