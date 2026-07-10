import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../logic/auth/session.dart';
import '../theme/app_colors.dart';
import '../widgets/ambient_blobs.dart';

/// Wraps the role picker and the sign-in/sign-up hub so their ambient
/// blobs are one persistent element across both routes — same technique
/// as [OnboardingShell]. Two things this adds on top of that:
///
/// 1. A one-time entrance the first time this shell mounts, since consent
///    (the screen before it) has no blobs of its own — each blob slides in
///    from whichever side it's anchored to (reusing [BlobSpec.exitDx]'s
///    slide mechanism in reverse), the mirror of how consent's blobs slide
///    out left/right when leaving language.
/// 2. A real position change between /roles and /auth (opposite corners,
///    different sizes), so picking a role visibly moves the background
///    instead of it sitting frozen underneath two different screens.
class RoleFlowShell extends ConsumerStatefulWidget {
  const RoleFlowShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  ConsumerState<RoleFlowShell> createState() => _RoleFlowShellState();
}

class _RoleFlowShellState extends ConsumerState<RoleFlowShell> {
  // Starts false so the first frame renders each blob off-screen (per its
  // exitDx); flipping true one frame later lets AmbientBlobs' own
  // AnimatedSlide carry them in, instead of a separate entrance controller.
  bool _blobsIn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _blobsIn = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final isLearner = session.activeRole == UserRole.learner;
    final onAuth = widget.location == '/auth';

    return Scaffold(
      // White, matching the onboarding screens (get-started/language/
      // consent) rather than cream.
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          AmbientBlobs(
            key: const ValueKey('role-flow-blobs'),
            blob1: onAuth
                ? BlobSpec(
                    color: isLearner ? AppColors.goldTint : AppColors.mint,
                    size: 220,
                    top: -70,
                    left: -90,
                    visible: _blobsIn,
                    exitDx: -1.4,
                  )
                : BlobSpec(
                    color: AppColors.goldTint,
                    size: 240,
                    top: -90,
                    right: -80,
                    visible: _blobsIn,
                    exitDx: 1.4,
                  ),
            blob2: onAuth
                ? BlobSpec(
                    color: isLearner ? AppColors.goldTint : AppColors.mint,
                    size: 170,
                    bottom: 120,
                    right: -70,
                    visible: _blobsIn,
                    exitDx: 1.4,
                  )
                : BlobSpec(
                    color: AppColors.mint,
                    size: 190,
                    bottom: 100,
                    left: -80,
                    visible: _blobsIn,
                    exitDx: -1.4,
                  ),
          ),
          widget.child,
        ],
      ),
    );
  }
}
