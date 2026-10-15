import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Tablets (shortest side >= 600 dp, e.g. 1280 x 800 class displays) may
/// rotate freely so they get a real landscape layout; phones stay
/// portrait-locked.
bool isTabletDisplay() {
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  return (view.physicalSize / view.devicePixelRatio).shortestSide >= 600;
}

/// The app's default orientations — what every landscape-only game or
/// casting screen restores on exit.
Future<void> restoreAppOrientations() => SystemChrome.setPreferredOrientations(
  isTabletDisplay()
      ? DeviceOrientation.values
      : const [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown],
);
