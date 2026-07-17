import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../data/models/curriculum/curriculum_models.dart';
import '../../theme/app_colors.dart';

class HarakatPopActivity extends StatefulWidget {
  const HarakatPopActivity({
    super.key,
    required this.cards,
    required this.xp,
    required this.color,
    required this.onComplete,
  });

  final List<FlashCard> cards;
  final int xp;
  final Color color;
  final void Function(int xpEarned, double accuracyPct, int errors) onComplete;

  @override
  State<HarakatPopActivity> createState() => _HarakatPopActivityState();
}

class _HarakatPopActivityState extends State<HarakatPopActivity>
    with TickerProviderStateMixin {
  int _idx = 0;
  bool _success = false;
  int _wrongDrops = 0;
  double _wobble = 0.0;
  late AnimationController _wobbleController;
  late AnimationController _pulseController;

  final List<Map<String, String>> _vowels = [
    {'mark': 'َ', 'name': 'Fathah', 'desc': 'short "a" sound'},
    {'mark': 'ِ', 'name': 'Kasrah', 'desc': 'short "i" sound'},
    {'mark': 'ُ', 'name': 'Dammah', 'desc': 'short "u" sound'},
  ];

  @override
  void initState() {
    super.initState();
    _wobbleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..addListener(() {
        setState(() {
          final t = _wobbleController.value;
          _wobble = math.sin(t * math.pi * 5) * 8 * (1 - t);
        });
      });

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _wobbleController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  FlashCard get _currentCard => widget.cards[_idx];

  String get _baseLetter => _currentCard.arabic;
  String get _targetSound => _currentCard.translit;
  String get _targetVowelName => _currentCard.english; // e.g. Fathah

  void _playSound() {
    // Simulate phonetic pronunciation clip playback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '🔊 Pronouncing phonetic clip: "$_targetSound"',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        duration: const Duration(milliseconds: 800),
        behavior: SnackBarBehavior.floating,
        backgroundColor: widget.color,
      ),
    );
  }

  void _onDrop(String vowelName) {
    if (_success) return;
    if (vowelName == _targetVowelName) {
      setState(() {
        _success = true;
      });
      // Move to next card after a delay
      Future.delayed(const Duration(milliseconds: 1600), () {
        if (!mounted) return;
        if (_idx + 1 >= widget.cards.length) {
          final totalAttempts = widget.cards.length + _wrongDrops;
          final accuracyPct = totalAttempts == 0
              ? 100.0
              : widget.cards.length / totalAttempts * 100;
          widget.onComplete(widget.xp, accuracyPct, _wrongDrops);
        } else {
          setState(() {
            _idx++;
            _success = false;
          });
        }
      });
    } else {
      // Wrong bubble - trigger shake animation
      _wrongDrops++;
      _wobbleController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final correctMark = _vowels.firstWhere((v) => v['name'] == _targetVowelName)['mark']!;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        children: [
          // Game Progress Dots
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < widget.cards.length; i++) ...[
                if (i != 0) const SizedBox(width: 5),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: i == _idx ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i < _idx
                        ? AppColors.adventureGreen
                        : i == _idx
                            ? widget.color
                            : AppColors.creamDark,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Header Instruction
          Text(
            'Harakat Pop!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: widget.color,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Listen to the sound and drag the correct vowel bubble onto the letter!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 14),

          // Audio Phonetic Playback Prompt
          GestureDetector(
            onTap: _playSound,
            child: ScaleTransition(
              scale: Tween<double>(begin: 1.0, end: 1.05).animate(
                CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: widget.color, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🔊', style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 8),
                    Text(
                      'Listen: "$_targetSound"',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: widget.color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Main Game Board (Base Letter and Target Slot)
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Base Letter Board (Centered with shake offset)
                Transform.translate(
                  offset: Offset(_wobble, 0),
                  child: Center(
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: AppColors.goldTint,
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: AppColors.goldSoft, width: 3),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x124A3A1E),
                            blurRadius: 12,
                            offset: Offset(0, 6),
                          )
                        ],
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          // Base Letter Glyph
                          Text(
                            _baseLetter,
                            style: const TextStyle(
                              fontSize: 100,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF4A3A1E),
                              fontFamily: 'sans',
                            ),
                          ),

                          // Vowel Mark Target Slot
                          Positioned(
                            top: _targetVowelName == 'Kasrah' ? null : -24,
                            bottom: _targetVowelName == 'Kasrah' ? -24 : null,
                            child: DragTarget<String>(
                              onAcceptWithDetails: (details) => _onDrop(details.data),
                              builder: (context, candidateData, rejectedData) {
                                final isHovering = candidateData.isNotEmpty;
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: _success
                                        ? AppColors.adventureGreen.withValues(alpha: 0.15)
                                        : isHovering
                                            ? widget.color.withValues(alpha: 0.25)
                                            : Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: _success
                                          ? AppColors.adventureGreen
                                          : isHovering
                                              ? widget.color
                                              : AppColors.goldSoft,
                                      width: 2.5,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: _success
                                      ? Text(
                                          correctMark,
                                          style: const TextStyle(
                                            fontSize: 28,
                                            fontWeight: FontWeight.w900,
                                            color: AppColors.adventureGreen,
                                            fontFamily: 'sans',
                                          ),
                                        )
                                      : Text(
                                          '?',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                            color: isHovering
                                                ? widget.color
                                                : AppColors.goldSoft,
                                          ),
                                        ),
                                );
                              },
                            ),
                          ),

                          // Lottie burst upon success
                          if (_success)
                            Positioned.fill(
                              child: Center(
                                child: SizedBox(
                                  width: 140,
                                  height: 140,
                                  child: Lottie.asset(
                                    'assets/lottie/milestone_burst.json',
                                    repeat: false,
                                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Floating Vowels Tray (descending viewport simulation)
                if (!_success) ...[
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: -10,
                    child: Center(
                      child: Wrap(
                        spacing: 24,
                        children: _vowels.map((vowel) {
                          return Draggable<String>(
                            data: vowel['name']!,
                            feedback: Material(
                              color: Colors.transparent,
                              child: Transform.scale(
                                scale: 1.15,
                                child: _Bubble(
                                  mark: vowel['mark']!,
                                  name: vowel['name']!,
                                  color: widget.color,
                                ),
                              ),
                            ),
                            childWhenDragging: Opacity(
                              opacity: 0.35,
                              child: _Bubble(
                                mark: vowel['mark']!,
                                name: vowel['name']!,
                                color: widget.color,
                              ),
                            ),
                            child: _FloatingWidget(
                              child: _Bubble(
                                mark: vowel['mark']!,
                                name: vowel['name']!,
                                color: widget.color,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.mark,
    required this.name,
    required this.color,
  });

  final String mark;
  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.45), width: 3),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, color.withValues(alpha: 0.08)],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            mark,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: color,
              fontFamily: 'sans',
            ),
          ),
          const SizedBox(height: 1),
          Text(
            name,
            style: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w900,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingWidget extends StatefulWidget {
  const _FloatingWidget({required this.child});

  final Widget child;

  @override
  State<_FloatingWidget> createState() => _FloatingWidgetState();
}

class _FloatingWidgetState extends State<_FloatingWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late double _offset;

  @override
  void initState() {
    super.initState();
    _offset = math.Random().nextDouble() * math.pi * 2;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final float = math.sin(_controller.value * math.pi * 2 + _offset) * 6;
        return Transform.translate(
          offset: Offset(0, float),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
