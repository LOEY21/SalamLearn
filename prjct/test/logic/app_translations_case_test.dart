import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/logic/localization/app_translations.dart';

void main() {
  test('all-caps-only keys keep the casing of the requested text', () {
    expect(AppTranslations.translate('Backpack', 'fil'), 'Backpack');
    expect(AppTranslations.translate('BACKPACK', 'fil'), 'BACKPACK');
    expect(AppTranslations.translate('Classes', 'fil'), 'Mga klase');
    expect(AppTranslations.translate('Quick Actions', 'fil'), 'Mga Mabilisang Aksyon');
    expect(AppTranslations.translate('Profile', 'fil'), 'Profile');
  });
}
