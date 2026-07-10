import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../logic/auth/session.dart';
import '../../logic/onboarding/onboarding_checks.dart';
import '../theme/app_colors.dart';

/// Instructional-language step (step 2 of the onboarding gate flow), redesigned
/// per the approved motion-design/ui-ux-pro-max HTML preview: tappable
/// language cards instead of a segmented toggle, a stroke-draw checkmark on
/// the verified-assets status card, and a staggered Playful-archetype
/// entrance consistent with the get-started screen.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  String _language = 'en';

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..forward();

  Animation<double> _in(
    double start,
    double end, {
    Curve curve = Curves.easeOut,
  }) {
    return CurvedAnimation(
      parent: _c,
      curve: Interval(start, end, curve: curve),
    );
  }

  // Built once and reused — CurvedAnimation attaches a permanent listener
  // to its parent controller that's only released by calling dispose() on
  // the CurvedAnimation itself. Recreating these in build() (which reran on
  // every language-card tap via setState) leaked a fresh batch of listeners
  // onto `_c` each time, so every tap made the screen's animations do more
  // and more work forever — the actual cause of the reported lag.
  late final icon = _in(0.0, 0.36, curve: Curves.easeOutBack);
  late final heading = _in(0.08, 0.42, curve: Curves.easeOutBack);
  late final subhead = _in(0.22, 0.46);
  late final status = _in(0.28, 0.55);
  late final checkDraw = _in(0.50, 0.72, curve: Curves.easeOut);
  late final label = _in(0.32, 0.52);
  late final card1 = _in(0.38, 0.62);
  late final card2 = _in(0.44, 0.68);
  late final tip = _in(0.52, 0.74);
  late final cta = _in(0.50, 0.80, curve: Curves.easeOutBack);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final checks = ref.watch(launchChecksProvider);
    final verified = checks.value?.assetsIntact ?? false;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) context.go('/get-started');
      },
      child: _buildBody(context, verified),
    );
  }

  Widget _buildBody(BuildContext context, bool verified) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Every real device reports a different available height (status
        // bar, nav bar, notch, aspect ratio all vary), and this step is a
        // single quick decision — it must never need a scroll. Rather than
        // chase individual breakpoints, lay the content out at its tuned
        // reference size inside a fixed-width box, then let FittedBox
        // scale the whole thing down uniformly to whatever height this
        // device actually gives us. Devices at/above the reference height
        // render at 1:1 (scaleDown never enlarges), so nothing changes
        // there; only genuinely short screens shrink, and everything
        // shrinks together instead of overflowing or clipping the mascot.
        return FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: constraints.maxWidth,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 12, 28, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: FadeTransition(
                      opacity: icon,
                      child: ScaleTransition(
                        scale: icon.drive(Tween(begin: 0.8, end: 1.0)),
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: const BoxDecoration(
                            color: AppColors.teal,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.language,
                            size: 28,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _FadeUp(
                    animation: heading,
                    child: const Text(
                      'Choose your language',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  _FadeUp(
                    animation: subhead,
                    child: const Text(
                      'You can change this anytime in Settings',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ),
                  const SizedBox(height: 22),
                  _FadeUp(
                    animation: status,
                    child: _StatusCard(verified: verified, checkDraw: checkDraw),
                  ),
                  const SizedBox(height: 26),
                  _FadeUp(
                    animation: label,
                    child: const Text(
                      'INSTRUCTIONAL LANGUAGE',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _FadeUp(
                    animation: card1,
                    child: _LanguageCard(
                      badge: 'EN',
                      name: 'English',
                      subtitle: 'Lessons narrated in English',
                      selected: _language == 'en',
                      onTap: () => setState(() => _language = 'en'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _FadeUp(
                    animation: card2,
                    child: _LanguageCard(
                      badge: 'FIL',
                      name: 'Filipino',
                      subtitle: 'Mga aralin sa Filipino',
                      selected: _language == 'fil',
                      onTap: () => setState(() => _language = 'fil'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _FadeUp(animation: tip, child: const _TipCard()),
                  const SizedBox(height: 22),
                  _FadeUp(
                    animation: cta,
                    offset: 18,
                    child: SizedBox(
                      height: 56,
                      child: FilledButton(
                        onPressed: () {
                          ref
                              .read(sessionProvider.notifier)
                              .setLanguage(_language);
                          context.go('/consent');
                        },
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Continue',
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
                  const SizedBox(height: 10),
                  _FadeUp(
                    animation: cta,
                    child: Image.asset(
                      'assets/images/mascot_language_closing.png',
                      width: double.infinity,
                      fit: BoxFit.fitWidth,
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
    this.offset = 14,
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

/// Mint status card showing the silent asset/storage check result, with a
/// stroke-draw checkmark once [checkDraw] reaches 1.
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.verified, required this.checkDraw});

  final bool verified;
  final Animation<double> checkDraw;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.mint,
        border: Border.all(color: AppColors.mintBorder),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              color: AppColors.teal,
              shape: BoxShape.circle,
            ),
            child: ScaleTransition(
              scale: checkDraw,
              child: const Icon(Icons.check, size: 16, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  verified ? 'Assets verified' : 'Checking assets…',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const Text(
                  '512MB free · 500MB required',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Reassurance card beneath the language cards — a lightbulb glyph, copy
/// reminding the choice isn't permanent, and the mascot pair peeking over
/// the top-right corner (ported from the approved HTML preview's
/// `.tip-card`, reusing the same asset as the screen's closing hero image).
/// The mascot is a [Positioned] sibling of the card in an unclipped
/// [Stack] — per the reference it floats above the card's rounded edge
/// rather than being cropped by it.
class _TipCard extends StatelessWidget {
  const _TipCard();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Text gutter and mascot were both fixed pixel widths (120 /
        // 150) tuned against one reference screen size — on a narrower
        // phone the mascot didn't shrink with it, so it either crowded
        // the copy or hung off the card. Scale both off the card's own
        // width instead so the mascot keeps the same proportion (and
        // the same top-corner peek) on any screen.
        final mascotWidth = (constraints.maxWidth * 0.34).clamp(96.0, 150.0);
        final textGutter = mascotWidth * 0.86;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: EdgeInsets.fromLTRB(16, 14, textGutter, 14),
              decoration: BoxDecoration(
                color: AppColors.mint,
                border: Border.all(color: AppColors.mintBorder),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: const BoxDecoration(
                      color: AppColors.teal,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lightbulb_outline,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Not sure which to choose?',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'You can always switch languages later in your '
                          'profile settings.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              // Shifted further right (was right: 2) — at 2 the mascot's
              // raised hand crept into the text gutter and clipped the
              // word "later" on real narrow devices.
              right: -10,
              top: -46,
              bottom: -6,
              child: Image.asset(
                'assets/images/mascot_language_select.png',
                width: mascotWidth,
                fit: BoxFit.contain,
                alignment: Alignment.bottomCenter,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Tappable language selector card — badge, name, native-script subtitle,
/// and an animated selection checkmark (44px+ touch target).
class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    required this.badge,
    required this.name,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String badge;
  final String name;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppColors.teal : AppColors.creamDark,
              width: 2,
            ),
            color: selected
                ? AppColors.teal.withValues(alpha: 0.05)
                : Colors.white,
          ),
          child: Row(
            children: [
              AnimatedScale(
                scale: selected ? 1.06 : 1.0,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutBack,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: selected ? AppColors.teal : AppColors.creamDark,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: selected ? Colors.white : AppColors.ink,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? AppColors.teal : Colors.transparent,
                  border: Border.all(
                    color: selected ? AppColors.teal : AppColors.creamDark,
                    width: 2,
                  ),
                ),
                child: AnimatedScale(
                  scale: selected ? 1.0 : 0.5,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  child: AnimatedOpacity(
                    opacity: selected ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(
                      Icons.check,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
