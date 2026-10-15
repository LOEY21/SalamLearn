import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/ui/widgets/app_orientation.dart';

void main() {
  testWidgets('phones stay portrait, tablets may rotate', (tester) async {
    final requested = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') {
          requested.add(call.arguments);
        }
        return null;
      },
    );
    addTearDown(tester.view.reset);

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    expect(isTabletDisplay(), isFalse);
    await restoreAppOrientations();
    expect(requested.last, [
      'DeviceOrientation.portraitUp',
      'DeviceOrientation.portraitDown',
    ]);

    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.33;
    expect(isTabletDisplay(), isTrue);
    await restoreAppOrientations();
    expect((requested.last as List).length, DeviceOrientation.values.length);
  });
}
