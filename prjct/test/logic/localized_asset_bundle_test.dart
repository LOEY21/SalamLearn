import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/logic/localization/app_translations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(LocalizedAssetBundle.init);
  tearDown(() => AppTranslations.currentLanguageCodeOverride = null);

  const again = 'assets/images/taharah/end_again.png';
  const back = 'assets/images/taharah/w_btn_back.png';

  test('Filipino swaps in the Filipino button art where there is one', () {
    AppTranslations.currentLanguageCodeOverride = 'fil';
    expect(
      LocalizedAssetBundle.resolve(again),
      'assets/images/taharah/fil/end_again.png',
    );
    // Icon-only art has no Filipino copy and stays as is.
    expect(LocalizedAssetBundle.resolve(back), back);
  });

  test('root files like the asset manifest pass straight through', () async {
    AppTranslations.currentLanguageCodeOverride = 'fil';
    expect(
      LocalizedAssetBundle.resolve('AssetManifest.bin'),
      'AssetManifest.bin',
    );
    final data = await LocalizedAssetBundle().load('AssetManifest.bin');
    expect(data.lengthInBytes, greaterThan(0));
  });

  test('English keeps the original art', () {
    AppTranslations.currentLanguageCodeOverride = 'en';
    expect(LocalizedAssetBundle.resolve(again), again);
  });

  test('the Filipino copy loads', () async {
    AppTranslations.currentLanguageCodeOverride = 'fil';
    final bundle = LocalizedAssetBundle();
    final data = await bundle.load(again);
    expect(data.lengthInBytes, greaterThan(1000));
  });
}
