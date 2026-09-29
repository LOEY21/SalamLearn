import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Good Deed Tree music and bloom recordings are bundled', () async {
    for (final path in [
      'assets/audio/good_deed_tree/audio_bgm_garden_blooming.mp3',
      'assets/audio/good_deed_tree/audio_sfx_magic_bloom.mp3',
    ]) {
      final bytes = await rootBundle.load(path);
      expect(bytes.lengthInBytes, greaterThan(1000), reason: path);
    }
  });
}
