import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';

/// "Let's get started" intro screen — sits between the splash screen and
/// language selection (mockup-adjacent, approved via HTML preview).
/// Choreography: hero pops in (ease-out-back) while ambient blobs drift,
/// then eyebrow / heading / subtitle / dots / CTA / skip cascade in.
class GetStartedScreen extends StatefulWidget {
  const GetStartedScreen({super.key});

  @override
  State<GetStartedScreen> createState() => _GetStartedScreenState();
}

class _GetStartedScreenState extends State<GetStartedScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..forward();

  Animation<double> _fadeSlide(
    double start,
    double end, {
    Curve curve = Curves.easeOut,
  }) {
    return CurvedAnimation(
      parent: _c,
      curve: Interval(start, end, curve: curve),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _continue() => context.go('/language');

  @override
  Widget build(BuildContext context) {
    final hero = _fadeSlide(0.10, 0.55, curve: Curves.easeOutBack);
    final eyebrow = _fadeSlide(0.32, 0.55);
    final heading = _fadeSlide(0.37, 0.62);
    final subtitle = _fadeSlide(0.43, 0.68);
    final cta = _fadeSlide(0.55, 0.80, curve: Curves.easeOutBack);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Hero height and the gap above the CTA scale with the available
        // height instead of being fixed (340px hero + 76px gap used to hard
        // -overflow on short phones, e.g. iPhone SE, once the step-dots bar
        // and text above it were accounted for). Clamped so it neither
        // balloons on tall screens nor shrinks to nothing on tiny ones.
        final heroHeight = (constraints.maxHeight * 0.34).clamp(160.0, 340.0);
        final ctaGap = (constraints.maxHeight * 0.09).clamp(24.0, 76.0);

        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FadeTransition(
                    opacity: hero,
                    child: ScaleTransition(
                      scale: hero.drive(Tween(begin: 0.85, end: 1.0)),
                      child: Image.asset(
                        'assets/images/mascot_get_started.png',
                        width: double.infinity,
                        height: heroHeight,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _FadeUp(
                    animation: eyebrow,
                    child: const Text(
                      'WELCOME',
                      style: TextStyle(
                        color: AppColors.gold,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _FadeUp(
                    animation: heading,
                    child: const Text(
                      "Let's get started",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.ink,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _FadeUp(
                    animation: subtitle,
                    child: const Text(
                      "A fun, offline learning journey through Qur'an, "
                      'Duas, and Islamic stories — made for you.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                  ),
                  SizedBox(height: ctaGap),
                  _FadeUp(
                    animation: cta,
                    offset: 22,
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
                        onPressed: _continue,
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Get Started',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Fades and slides its child upward as [animation] runs 0→1.
class _FadeUp extends StatelessWidget {
  const _FadeUp({
    required this.animation,
    required this.child,
    this.offset = 18,
  });

  final Animation<double> animation;
  final Widget child;
  final double offset;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, c) => Transform.translate(
          offset: Offset(0, (1 - animation.value) * offset),
          child: c,
        ),
        child: child,
      ),
    );
  }
}

