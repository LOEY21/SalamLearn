import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/ambient_blobs.dart';
import '../widgets/step_dots.dart';

/// Wraps get-started / language / consent so the step-dots bar is a single
/// persistent widget instance across the three routes — it stays mounted
/// and animates its own dot in place when the route changes, instead of
/// each screen fading its own copy in and out.
class OnboardingShell extends StatelessWidget {
  const OnboardingShell({
    super.key,
    required this.location,
    required this.child,
  });

  final String location;
  final Widget child;

  static const _steps = ['/get-started', '/language', '/consent'];

  @override
  Widget build(BuildContext context) {
    final activeIndex = _steps.indexOf(location).clamp(0, _steps.length - 1);

    return Scaffold(
      // All three onboarding screens sit on a white canvas per the approved
      // previews (overridden from cream on request).
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Bleeds to the true screen edges, outside SafeArea — matches each
          // preview's blobs overflowing the `.phone` frame.
          //
          // Same key across all three steps on purpose: it keeps this the
          // SAME persistent AmbientBlobs element for the whole onboarding
          // flow. get-started → language: each blob glides to its new
          // position/size/color. language → consent: rather than the
          // blobs just vanishing when this widget stops rendering them
          // (consent has none by design — calmer, trust-screen
          // personality), they stay mounted at their last position and
          // fade+shrink out in place, a deliberate exit that hands focus
          // to the consent content instead of a hard cut.
          AmbientBlobs(
            key: const ValueKey('onboarding-blobs'),
            blob1: _blob1For(location),
            blob2: _blob2For(location),
          ),
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 8),
                StepDots(
                  activeIndex: activeIndex,
                  count: _steps.length,
                  activeColor: location == '/consent'
                      ? AppColors.danger
                      : AppColors.teal,
                ),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }

  BlobSpec _blob1For(String location) {
    if (location == '/get-started') {
      return const BlobSpec(
          color: AppColors.goldTint, size: 280, top: -90, right: -90);
    }
    // language and consent share the same spec — consent just sets
    // visible:false so it slides out left from language's position
    // instead of jumping there first.
    return BlobSpec(
      color: AppColors.goldTint,
      size: 260,
      top: -100,
      left: -70,
      visible: location != '/consent',
      exitDx: -1.6,
    );
  }

  BlobSpec _blob2For(String location) {
    if (location == '/get-started') {
      return const BlobSpec(
          color: AppColors.creamDark, size: 220, bottom: 60, left: -80);
    }
    return BlobSpec(
      color: AppColors.mint,
      size: 200,
      bottom: -60,
      right: -70,
      visible: location != '/consent',
      exitDx: 1.6,
    );
  }
}
