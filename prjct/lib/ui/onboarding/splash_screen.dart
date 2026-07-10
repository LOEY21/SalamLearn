import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../logic/auth/session.dart';
import '../../logic/onboarding/onboarding_checks.dart';
import '../theme/app_colors.dart';

/// Launch loading screen: clean white canvas, the logo opens dead center
/// with a soft scale/fade while the silent asset + storage checks run
/// (FR-1.1/1.2), then flows into the instructional-language step (FR-1.3).
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..forward();

  // Ring draws open first, logo pops through the middle of it.
  late final Animation<double> _ringSweep = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0, 0.45, curve: Curves.easeOut),
  );

  late final Animation<double> _scale = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.12, 0.62, curve: Curves.easeOutBack),
  ).drive(Tween(begin: 0.55, end: 1.0));

  late final Animation<double> _fade = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.12, 0.45, curve: Curves.easeOut),
  );

  late final Animation<double> _textFade = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.55, 1, curve: Curves.easeOut),
  );

  late final Animation<Offset> _textSlide = CurvedAnimation(
    parent: _intro,
    curve: const Interval(0.55, 1, curve: Curves.easeOutCubic),
  ).drive(Tween(begin: const Offset(0, 0.35), end: Offset.zero));

  // Gentle breathing loop once the logo has landed — keeps it feeling alive
  // while checks run in the background.
  late final AnimationController _breathe = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  late final Animation<double> _breatheScale = CurvedAnimation(
    parent: _breathe,
    curve: Curves.easeInOut,
  ).drive(Tween(begin: 1.0, end: 1.035));

  // Keep the logo on screen long enough to register as an opening moment.
  static const _minSplash = Duration(milliseconds: 2400);
  late final Future<void> _minDelay = Future.delayed(_minSplash);
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _intro.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _breathe.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    _breathe.dispose();
    super.dispose();
  }

  Future<void> _proceed(LaunchCheckResult result) async {
    if (_navigated) return;
    _navigated = true;
    await _minDelay;
    if (!mounted) return;
    if (!result.storageOk) {
      _showStorageAlert();
      return;
    }

    // Returning user: session.dart rehydrates languageCode/consent/
    // activeRole/account ids straight from Hive, so a device that's
    // already been through onboarding shouldn't be sent back through
    // get-started → language → consent → role picker on every launch —
    // go straight to that role's home path instead. The router's own
    // redirect (app_router.dart) still bounces to /pin/verify first if
    // pinVerified isn't true, which it never is right after a fresh
    // launch — that's the intended re-lock, not a bug.
    final session = ref.read(sessionProvider);
    if (!session.onboarded) {
      context.go('/get-started');
      return;
    }
    if (!session.consented) {
      context.go('/consent');
      return;
    }
    switch (session.activeRole) {
      case UserRole.learner:
        context.go('/hub');
      case UserRole.parent:
        context.go('/parent');
      case UserRole.asatidz:
        context.go('/teacher');
      case null:
        context.go('/roles');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(launchChecksProvider, (_, next) {
      next.whenData(_proceed);
    });
    // Handle the case where checks completed before this listener attached.
    ref.read(launchChecksProvider).whenData(_proceed);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 208,
                  height: 208,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Ring sweeps open behind the logo before it pops in.
                      AnimatedBuilder(
                        animation: _ringSweep,
                        builder: (context, _) => CustomPaint(
                          size: const Size(208, 208),
                          painter: _RingSweepPainter(
                            progress: _ringSweep.value,
                            color: AppColors.gold,
                          ),
                        ),
                      ),
                      FadeTransition(
                        opacity: _fade,
                        child: ScaleTransition(
                          scale: _scale,
                          // RepaintBoundary isolates the endless breathing
                          // scale (plus its blurred BoxShadow, which is
                          // costly to redraw every frame) onto its own
                          // compositor layer instead of repainting the
                          // whole splash tree each tick.
                          child: RepaintBoundary(
                            child: AnimatedBuilder(
                              animation: _breatheScale,
                              builder: (context, child) => Transform.scale(
                                scale: _breatheScale.value,
                                child: child,
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.cream,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.teal
                                          .withValues(alpha: 0.18),
                                      blurRadius: 40,
                                      spreadRadius: 2,
                                      offset: const Offset(0, 14),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(14),
                                child: ClipOval(
                                  child: Image.asset(
                                    'assets/images/logo.png',
                                    width: 160,
                                    height: 160,
                                    cacheWidth: 320,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                FadeTransition(
                  opacity: _textFade,
                  child: SlideTransition(
                    position: _textSlide,
                    child: Column(
                      children: [
                        const Text(
                          'SalamLearn',
                          style: TextStyle(
                            color: AppColors.teal,
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 42,
                          height: 3,
                          decoration: BoxDecoration(
                            color: AppColors.gold,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Learn · Play · Grow',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Loader pinned to the bottom, independent of the centered logo.
          Positioned(
            left: 0,
            right: 0,
            bottom: 44,
            child: FadeTransition(
              opacity: _textFade,
              child: const Column(
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: AppColors.teal,
                      strokeWidth: 2.4,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Preparing offline lessons…',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showStorageAlert() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded,
            color: AppColors.coral, size: 44),
        title: const Text('Not enough space'),
        content: const Text(
          'SalamLearn needs at least 500MB of free storage for offline '
          'lessons. Please free up space and try again.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

/// Draws a ring that sweeps open (from the top, clockwise) behind the
/// logo as the intro animation runs — a quiet "unveiling" beat before the
/// mark pops in on top of it.
class _RingSweepPainter extends CustomPainter {
  const _RingSweepPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 3;
    final paint = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingSweepPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
