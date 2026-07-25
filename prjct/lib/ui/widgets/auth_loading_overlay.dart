import 'dart:ui';

import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';

import '../theme/app_colors.dart';

/// Which async auth action [AuthLoadingOverlay] is covering — drives its
/// accent color, icon, and copy. Add a case here rather than a bespoke
/// one-off overlay if a new action needs this treatment.
enum AuthLoadingAction { signIn, logout, erase, switchProfile, switchClass }

class _ActionStyle {
  const _ActionStyle({
    required this.accent,
    required this.haloAccent,
    required this.icon,
    required this.heading,
    required this.subtitle,
  });

  final Color accent;
  final Color haloAccent;
  final IconData icon;
  final String heading;
  final String subtitle;
}

_ActionStyle _styleFor(AuthLoadingAction action) {
  switch (action) {
    case AuthLoadingAction.signIn:
      return const _ActionStyle(
        accent: AppColors.gold,
        haloAccent: AppColors.teal,
        icon: Icons.login_rounded,
        heading: 'Signing in…',
        subtitle: 'Verifying your account',
      );
    case AuthLoadingAction.logout:
      return const _ActionStyle(
        accent: AppColors.teal,
        haloAccent: AppColors.teal,
        icon: Icons.logout_rounded,
        heading: 'Logging out…',
        subtitle: 'See you again soon',
      );
    case AuthLoadingAction.erase:
      return const _ActionStyle(
        accent: AppColors.coral,
        haloAccent: AppColors.coral,
        icon: Icons.delete_outline_rounded,
        heading: 'Erasing local data…',
        subtitle: 'This may take a moment',
      );
    case AuthLoadingAction.switchProfile:
      return const _ActionStyle(
        accent: AppColors.gold,
        haloAccent: AppColors.teal,
        icon: Icons.swap_horiz_rounded,
        heading: 'Switching profile…',
        subtitle: 'Loading their progress',
      );
    case AuthLoadingAction.switchClass:
      return const _ActionStyle(
        accent: AppColors.teal,
        haloAccent: AppColors.gold,
        icon: Icons.groups_rounded,
        heading: 'Loading classroom…',
        subtitle: 'Fetching students and progress',
      );
  }
}

/// The app's single root `Navigator` (wired in `app_router.dart`'s
/// `GoRouter(navigatorKey: rootNavigatorKey, ...)`). [showAuthLoadingOverlay]
/// uses this instead of a per-call `BuildContext` specifically so callers
/// can navigate away (`context.go(...)`) *before* running the state-changing
/// work the overlay covers — see that function's doc for why that ordering
/// matters and a plain `BuildContext` can't survive it.
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Shows [AuthLoadingOverlay] via a raw [OverlayEntry] on [rootNavigatorKey]'s
/// overlay — deliberately NOT `showDialog`/`Navigator.push`, and deliberately
/// NOT tied to whichever screen's `BuildContext` triggered it.
///
/// The real bug this avoids: logout/erase clear the active account as part
/// of their very first synchronous step, and `go_router`'s `refreshListenable`
/// reacts to *that* immediately — while the app is still sitting on the
/// gated route (e.g. `/parent`) the button was pressed from. At that instant
/// the redirect re-evaluates *the current route*, sees no account, and
/// briefly flips to `/pin/setup` — a full route change, not just a stray
/// dialog frame, so it's visible under the loading overlay and can still
/// show through once the overlay drops, before the caller's own corrective
/// `.go('/roles')` lands a moment later.
///
/// The fix is to navigate to `/roles` *before* calling `logout()`/`eraseAll()`
/// at all, so the current route is already safe by the time the redirect
/// reacts. That means the overlay must still work after the screen that
/// requested it has already been navigated away from (its `BuildContext`
/// no longer has a live route) — hence using the app's one root Navigator
/// instead of the caller's own context.
VoidCallback showAuthLoadingOverlay(AuthLoadingAction action) {
  final overlayState = rootNavigatorKey.currentState!.overlay!;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => AuthLoadingOverlay(action: action),
  );
  overlayState.insert(entry);
  return () {
    entry.remove();
  };
}

/// Minimum time the overlay stays up regardless of how fast [work]
/// finishes — matches the splash screen's own `_minSplash` pattern
/// (`onboarding/splash_screen.dart`) for the same reason: a loading state
/// that appears for a handful of milliseconds isn't loading feedback, it's
/// a flicker.
const _minAuthLoadingDuration = Duration(milliseconds: 900);

/// Shows [AuthLoadingOverlay] for at least [_minAuthLoadingDuration] while
/// [work] runs, then hides it and returns [work]'s result. This is the
/// function every call site should use — see [showAuthLoadingOverlay]'s
/// doc for why the bare show/hide pair alone isn't enough, and why call
/// sites should navigate away from any PIN-gated route *before* calling
/// this for logout/erase.
Future<T> runWithAuthLoadingOverlay<T>(
  AuthLoadingAction action,
  Future<T> Function() work,
) async {
  final hide = showAuthLoadingOverlay(action);
  try {
    final results = await Future.wait<Object?>([
      work(),
      Future<void>.delayed(_minAuthLoadingDuration),
    ]);
    return results[0] as T;
  } finally {
    hide();
  }
}

/// Full-screen loading overlay shown during sign-in, logout, and erase-data
/// (approved preview: `dumps/auth_loading_overlay_mock.html`). Three motion
/// layers per the motion-design "Premium" personality (350-600ms,
/// cubic-bezier(0.4,0,0.2,1), no overshoot — reassuring, not jarring, for
/// security-sensitive actions):
/// - primary: rotating progress ring (linear, spinners are the one
///   exemption to "never linear")
/// - secondary: gently-pulsing icon mark, breathing halo (same breathing
///   treatment as the splash screen, for visual consistency)
/// - ambient: three staggered pulsing dots
class AuthLoadingOverlay extends StatefulWidget {
  const AuthLoadingOverlay({super.key, required this.action});

  final AuthLoadingAction action;

  @override
  State<AuthLoadingOverlay> createState() => _AuthLoadingOverlayState();
}

class _AuthLoadingOverlayState extends State<AuthLoadingOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  )..forward();

  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  late final AnimationController _breathe = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat(reverse: true);

  late final AnimationController _dots = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  late final Animation<double> _scrim = CurvedAnimation(
    parent: _entrance,
    curve: const Interval(0.0, 0.9, curve: Curves.easeOut),
  );

  late final Animation<double> _cardOpacity = CurvedAnimation(
    parent: _entrance,
    curve: const Interval(0.2, 1.0, curve: Cubic(0.4, 0, 0.2, 1)),
  );

  late final Animation<Offset> _cardOffset = Tween(
    begin: const Offset(0, 0.06),
    end: Offset.zero,
  ).animate(CurvedAnimation(
    parent: _entrance,
    curve: const Interval(0.2, 1.0, curve: Cubic(0.4, 0, 0.2, 1)),
  ));

  late final Animation<double> _headingOpacity = CurvedAnimation(
    parent: _entrance,
    curve: const Interval(0.62, 1.0, curve: Curves.easeOut),
  );

  late final Animation<double> _subtitleOpacity = CurvedAnimation(
    parent: _entrance,
    curve: const Interval(0.8, 1.0, curve: Curves.easeOut),
  );

  @override
  void dispose() {
    _entrance.dispose();
    _spin.dispose();
    _breathe.dispose();
    _dots.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(widget.action);

    return AnimatedBuilder(
      animation: _scrim,
      builder: (context, child) => Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: 3 * _scrim.value,
                sigmaY: 3 * _scrim.value,
              ),
              child: Container(
                color: AppColors.ink.withValues(alpha: 0.38 * _scrim.value),
              ),
            ),
          ),
          child!,
        ],
      ),
      child: Center(
        child: FadeTransition(
          opacity: _cardOpacity,
          child: SlideTransition(
            position: _cardOffset,
            child: Container(
              width: 240,
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.tealDark.withValues(alpha: 0.25),
                    blurRadius: 48,
                    offset: const Offset(0, 24),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Mark(style: style, spin: _spin, breathe: _breathe),
                  const SizedBox(height: 18),
                  FadeTransition(
                    opacity: _headingOpacity,
                    child: Text(
                      style.heading,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  FadeTransition(
                    opacity: _subtitleOpacity,
                    child: Text(
                      style.subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _Dots(controller: _dots, color: style.accent),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Halo (ambient) + rotating ring (primary) + icon (secondary) stack,
/// matching the preview's `.mark-wrap`.
class _Mark extends StatelessWidget {
  const _Mark({required this.style, required this.spin, required this.breathe});

  final _ActionStyle style;
  final AnimationController spin;
  final AnimationController breathe;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      height: 88,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: breathe,
            builder: (context, child) {
              final t = Curves.easeInOut.transform(breathe.value);
              return Opacity(
                opacity: 0.7 + (0.3 * t),
                child: Transform.scale(scale: 1.0 + (0.12 * t), child: child),
              );
            },
            child: Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    style.haloAccent.withValues(alpha: 0.18),
                    style.haloAccent.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          RotationTransition(
            turns: spin,
            child: SizedBox(
              width: 76,
              height: 76,
              child: CustomPaint(
                painter: _RingPainter(color: style.accent),
              ),
            ),
          ),
          AnimatedBuilder(
            animation: breathe,
            builder: (context, child) {
              final t = Curves.easeInOut.transform(breathe.value);
              return Transform.scale(scale: 1.0 + (0.035 * t), child: child);
            },
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: style.accent.withValues(alpha: 0.14),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Icon(style.icon, size: 26, color: AppColors.teal),
            ),
          ),
        ],
      ),
    );
  }
}

/// Rotating progress-ring track, matching the preview's SVG ring (a fixed
/// ~65% arc that spins continuously — linear timing, the one exemption to
/// "never linear" since this is a literal spinner).
class _RingPainter extends CustomPainter {
  const _RingPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - 2.5;
    final trackPaint = Paint()
      ..color = AppColors.mintBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    canvas.drawCircle(center, radius, trackPaint);

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    // ~65% arc, matching the preview's stroke-dasharray/dashoffset ratio.
    const sweep = 3.9;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.57,
      sweep,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) => oldDelegate.color != color;
}

/// Three staggered pulsing dots (ambient detail), matching the preview's
/// `.dots` — each offset by ~12.5% of the shared cycle.
class _Dots extends StatelessWidget {
  const _Dots({required this.controller, required this.color});

  final AnimationController controller;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final delay = i * 0.125;
        final animation = CurvedAnimation(
          parent: controller,
          curve: Interval(delay, (delay + 0.5).clamp(0.0, 1.0), curve: Curves.easeInOut),
        );
        return Padding(
          padding: EdgeInsets.only(right: i == 2 ? 0 : 5),
          child: AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              // Triangle wave so each dot pulses up then back down within
              // its own slice of the shared 1200ms loop.
              final t = animation.value < 0.5
                  ? animation.value * 2
                  : (1 - animation.value) * 2;
              return Opacity(
                opacity: 0.35 + (0.65 * t),
                child: Transform.scale(
                  scale: 0.85 + (0.25 * t),
                  child: child,
                ),
              );
            },
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
        );
      }),
    );
  }
}
