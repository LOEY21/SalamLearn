import 'dart:async';

import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';

import '../theme/app_colors.dart';

/// Full-screen mascot welcome overlay with tap-to-advance dialogue.
///
/// Shows Amir (the mascot boy) greeting the learner with a multi-step
/// dialogue sequence. Each tap advances to the next line. After the
/// final line, the learner taps to dismiss and enter the adventure map.
///
/// Motion design:
/// - Mascot slides up from below with a spring overshoot
/// - Speech bubble pops in with scale + opacity
/// - Each new dialogue line fades in with a subtle slide
/// - "Tap to continue" pulses gently
/// - Final dismiss has a scale-down + fade-out exit
class MascotWelcomeOverlay extends StatefulWidget {
  const MascotWelcomeOverlay({
    super.key,
    required this.learnerName,
    required this.onDismiss,
  });

  final String learnerName;
  final VoidCallback onDismiss;

  @override
  State<MascotWelcomeOverlay> createState() => _MascotWelcomeOverlayState();
}

class _MascotWelcomeOverlayState extends State<MascotWelcomeOverlay>
    with TickerProviderStateMixin {
  // --- Dialogue lines (Option A: The Adventurous Companion) ---
  late final List<String> _lines = [
    "Assalamu'alaikum, ${widget.learnerName}! 🌟",
    "I'm Amir, your learning companion, and I am so excited to meet you!",
    "Together, we're going to go on a grand adventure through the Village of Salaam and the Desert of Letters. 🗺️",
    "We will collect shiny stars, light up beautiful lanterns of knowledge, and learn to read together! ✨",
    "Grab your backpack and let's start our first step on the map! Bismillah! 🚀",
  ];

  int _currentLine = 0;
  bool _dismissing = false;

  // --- Animation controllers ---
  late final _bgFade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );
  late final _mascotEntrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );
  late final _bubbleEntrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );
  late final _textFade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
    value: 0,
  );
  late final _tapPulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  late final _exit = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
    value: 0,
  );

  Timer? _bubbleDelay;
  Timer? _textDelay;

  static const _springCurve = Cubic(0.34, 1.56, 0.64, 1.0);

  @override
  void initState() {
    super.initState();
    // Sequence: bg fade → mascot slides up → bubble pops → text fades in
    _bgFade.forward();
    _mascotEntrance.forward();
    _bubbleDelay = Timer(const Duration(milliseconds: 400), () {
      if (mounted) {
        _bubbleEntrance.forward();
        _textDelay = Timer(const Duration(milliseconds: 300), () {
          if (mounted) {
            _textFade.forward();
            _tapPulse.repeat(reverse: true);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _bubbleDelay?.cancel();
    _textDelay?.cancel();
    _bgFade.dispose();
    _mascotEntrance.dispose();
    _bubbleEntrance.dispose();
    _textFade.dispose();
    _tapPulse.dispose();
    _exit.dispose();
    super.dispose();
  }

  void _advance() {
    if (_dismissing) return;

    if (_currentLine < _lines.length - 1) {
      // Advance to next line with fade transition
      _textFade.reverse().whenComplete(() {
        if (!mounted) return;
        setState(() => _currentLine++);
        _textFade.forward();
      });
    } else {
      // Final tap — dismiss with exit animation
      _dismissing = true;
      _tapPulse.stop();
      _exit.forward().whenComplete(() {
        if (mounted) widget.onDismiss();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isLastLine = _currentLine == _lines.length - 1;
    final mascotHeight = screenHeight * 0.55;

    return AnimatedBuilder(
      animation: _exit,
      builder: (context, child) {
        final exitT = _exit.value;
        return Opacity(
          opacity: 1.0 - exitT,
          child: Transform.scale(
            scale: 1.0 - 0.1 * exitT,
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: _advance,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            // Semi-transparent dark background
            AnimatedBuilder(
              animation: _bgFade,
              builder: (context, _) => Container(
                color: Colors.black.withValues(alpha: 0.7 * _bgFade.value),
              ),
            ),

            // Large mascot image — center-left, covering most of screen
            Positioned(
              bottom: screenHeight * 0.08,
              left: -screenWidth * 0.08,
              child: AnimatedBuilder(
                animation: _mascotEntrance,
                builder: (context, child) {
                  final t = _springCurve.transform(_mascotEntrance.value);
                  return Transform.translate(
                    offset: Offset(-60 * (1 - t), 100 * (1 - t)),
                    child: Opacity(
                      opacity: t.clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: 0.6 + 0.4 * t,
                        alignment: Alignment.bottomCenter,
                        child: child,
                      ),
                    ),
                  );
                },
                child: SizedBox(
                  height: mascotHeight,
                  child: Image.asset(
                    'assets/images/adventure_map/mascot_amir.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),

            // Speech bubble — positioned on the right side like a message
            Positioned(
              top: screenHeight * 0.12,
              right: 16,
              left: screenWidth * 0.32,
              child: AnimatedBuilder(
                animation: Listenable.merge([_bubbleEntrance, _textFade, _tapPulse]),
                builder: (context, _) {
                  final bubbleT = _springCurve.transform(_bubbleEntrance.value);
                  final textOpacity = _textFade.value;
                  final pulseT = Curves.easeInOut.transform(_tapPulse.value);

                  return Opacity(
                    opacity: bubbleT.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: 0.7 + 0.3 * bubbleT,
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Main speech bubble
                          Container(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(20),
                                topRight: Radius.circular(20),
                                bottomRight: Radius.circular(20),
                                bottomLeft: Radius.circular(6),
                              ),
                              border: Border.all(
                                color: AppColors.gold,
                                width: 2.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.gold.withValues(alpha: 0.15),
                                  blurRadius: 24,
                                  offset: const Offset(0, 10),
                                ),
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // "Amir" name badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.teal,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    'Amir',
                                    style: TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Dialogue text with fade
                                Opacity(
                                  opacity: textOpacity,
                                  child: Transform.translate(
                                    offset: Offset(0, 6 * (1 - textOpacity)),
                                    child: Text(
                                      _lines[_currentLine],
                                      style: const TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF2D2D2D),
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                // "Tap to continue" prompt
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Opacity(
                                    opacity: 0.5 + 0.5 * pulseT,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          isLastLine
                                              ? 'Tap to start! 🚀'
                                              : 'Tap to continue',
                                          style: TextStyle(
                                            fontFamily: 'Outfit',
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: isLastLine
                                                ? AppColors.teal
                                                : AppColors.textMuted,
                                          ),
                                        ),
                                        const SizedBox(width: 3),
                                        Icon(
                                          isLastLine
                                              ? Icons.play_arrow_rounded
                                              : Icons.touch_app_rounded,
                                          size: 13,
                                          color: isLastLine
                                              ? AppColors.teal
                                              : AppColors.textMuted,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Progress dots below bubble
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(_lines.length, (i) {
                              final isActive = i == _currentLine;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                width: isActive ? 18 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
