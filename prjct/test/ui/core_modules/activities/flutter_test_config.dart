import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/logic/localization/app_translations.dart';

import '../../../support/text_fit_probe.dart';

/// Normal runs are untouched. With `--dart-define=TEXT_FIT=true` every game
/// test runs under the text-fit probe (optionally in Tagalog with
/// `--dart-define=TEXT_FIT_LANG=fil`) and writes `build/text_fit/<lang>/`.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  const on = bool.fromEnvironment('TEXT_FIT');
  if (!on) return testMain();
  const lang = String.fromEnvironment('TEXT_FIT_LANG', defaultValue: 'en');
  final binding = TextFitBinding.ensureInitialized();
  // Tests normally draw every glyph as a full-width square, which wraps and
  // shrinks text far more than the real fonts do — load the real ones.
  await loadRealFonts();
  setUp(() {
    if (lang != 'en') AppTranslations.currentLanguageCodeOverride = lang;
  });
  tearDownAll(() => binding.writeReport(lang));
  await testMain();
}
