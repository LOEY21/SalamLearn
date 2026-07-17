import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../data/models/curriculum/curriculum_models.dart';
import '../../theme/app_colors.dart';

/// FR-4.3's Supplication Stepping Stones game - sorts phrase blocks ("stones")
/// chronologically, synchronized with timestamped audio segments.
class QuranSyncActivity extends StatefulWidget {
  const QuranSyncActivity({
    super.key,
    required this.line,
    required this.xp,
    required this.color,
    required this.onComplete,
  });

  final QuranSyncLine line;
  final int xp;
  final Color color;
  final void Function(int xp, double accuracyPct, int errors) onComplete;

  @override
  State<QuranSyncActivity> createState() => _QuranSyncActivityState();
}

class _QuranSyncActivityState extends State<QuranSyncActivity>
    with TickerProviderStateMixin {
  bool _success = false;
  bool _playingAudio = false;
  int _highlightIndex = -1;
  int _wrongAttempts = 0;
  Timer? _playbackTimer;

  late final List<String> _correctOrder;
  late List<String> _shuffledStones;
  late List<String?> _placedStones;

  double _wobble = 0.0;
  late AnimationController _wobbleController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _correctOrder = _determineCorrectOrder();
    _placedStones = List<String?>.filled(_correctOrder.length, null);
    
    _shuffledStones = List<String>.from(_correctOrder);
    // Shuffle the stepping stones so they are scattered
    _shuffledStones.shuffle();

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
    _playbackTimer?.cancel();
    _wobbleController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  List<String> _determineCorrectOrder() {
    final id = widget.line.id.toLowerCase();
    if (id.contains('isti')) {
      return ["A'oodhu billahi", "minash-shaytanir", "rajeem"];
    }
    if (id.contains('basmalah') || id.contains('bismillah')) {
      return ["Bismillahir", "Rahmanir", "Raheem"];
    }
    if (id.contains('wake') || id.contains('ahyana')) {
      return ["Alhamdu lillahil-ladhi", "ahyana ba'da", "ma amatana", "wa ilayhin-nushur"];
    }
    if (id.contains('sleep') || id.contains('amutu')) {
      return ["Bismika", "Allahumma", "amutu", "wa ahya"];
    }
    if (id.contains('meal-begin') || id.contains('meal_begin')) {
      return ["Bismillah", "wa 'ala", "barakatillah"];
    }
    if (id.contains('meal-end') || id.contains('meal_end')) {
      return ["Alhamdu lillahil-ladhi", "at'amana", "wa saqana"];
    }
    if (id.contains('toilet-enter') || id.contains('khubuthi')) {
      return ["Allahumma inni", "a'oodhu bika", "minal-khubuthi", "wal-khaba'ith"];
    }
    if (id.contains('toilet-leave') || id.contains('ghufranak')) {
      return ["Ghufranak"];
    }
    if (id.contains('dress-on') || id.contains('kasani')) {
      return ["Alhamdu lillahil-ladhi", "kasani", "hadha"];
    }
    if (id.contains('dress-off') || id.contains('la ilaha')) {
      return ["Bismillahil-ladhi", "la ilaha", "illa huwa"];
    }
    return widget.line.translitWords;
  }

  void _playFullAudio() {
    if (_playingAudio) return;
    
    setState(() {
      _playingAudio = true;
      _highlightIndex = 0;
    });

    _playbackTimer?.cancel();
    
    // SnackBar audio cue
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '🔊 Playback: "${_correctOrder.join(' ')}"',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        duration: Duration(milliseconds: _correctOrder.length * 1000),
        behavior: SnackBarBehavior.floating,
        backgroundColor: widget.color,
      ),
    );

    // Highlight each block step-by-step
    _playbackTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
      if (!mounted) return;
      if (_highlightIndex < _correctOrder.length - 1) {
        setState(() {
          _highlightIndex++;
        });
      } else {
        timer.cancel();
        setState(() {
          _playingAudio = false;
          _highlightIndex = -1;
        });
      }
    });
  }

  void _onStonePlaced(int slotIndex, String stoneValue) {
    if (_success) return;

    // Check if the stone matches the chronological slot index!
    if (_correctOrder[slotIndex] == stoneValue) {
      setState(() {
        _placedStones[slotIndex] = stoneValue;
        _shuffledStones.remove(stoneValue);
      });

      // Play individual phrase audio segment (FR-4.3.4 segment sync)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '🎵 Correct stone locked: "$stoneValue"',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          duration: const Duration(milliseconds: 650),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.adventureGreen,
        ),
      );

      // Check if complete
      if (_placedStones.every((s) => s != null)) {
        setState(() {
          _success = true;
        });

        // Trigger success completion after milestone burst delay
        Future.delayed(const Duration(milliseconds: 1800), () {
          if (!mounted) return;
          final totalAttempts = _correctOrder.length + _wrongAttempts;
          final accuracyPct = totalAttempts == 0
              ? 100.0
              : _correctOrder.length / totalAttempts * 100;
          widget.onComplete(widget.xp, accuracyPct, _wrongAttempts);
        });
      }
    } else {
      // Wrong slot! Trigger wobble error and reject
      _wrongAttempts++;
      _wobbleController.forward(from: 0);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '⚠️ "$stoneValue" does not belong in stepping stone #${slotIndex + 1}!',
            style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
          ),
          duration: const Duration(milliseconds: 700),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.coral,
        ),
      );
    }
  }

  void _resetStones() {
    if (_success) return;
    setState(() {
      _placedStones = List<String?>.filled(_correctOrder.length, null);
      _shuffledStones = List<String>.from(_correctOrder);
      _shuffledStones.shuffle();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: Column(
        children: [
          // Reference Badge
          if (widget.line.reference != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.goldTint,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: AppColors.goldSoft, width: 1.2),
              ),
              child: Text(
                widget.line.reference!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: AppColors.gold,
                ),
              ),
            ),
          const SizedBox(height: 6),

          // Title & Description
          const Text(
            'Stepping Stones Sorter',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Sort the supplication phrases chronologically!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 12),

          // Full Audio Pronunciation Button
          GestureDetector(
            onTap: _playFullAudio,
            child: ScaleTransition(
              scale: Tween<double>(begin: 1.0, end: 1.04).animate(
                CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: widget.color, width: 2.2),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    )
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🔊', style: TextStyle(fontSize: 22)),
                    const SizedBox(width: 8),
                    Text(
                      _playingAudio ? 'Playing...' : 'Play Supplication',
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
          const SizedBox(height: 16),

          // Stepping Stone Path (Drop Targets)
          Expanded(
            child: Center(
              child: Transform.translate(
                offset: Offset(_wobble, 0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12,
                        runSpacing: 14,
                        children: List.generate(_correctOrder.length, (index) {
                          final isFilled = _placedStones[index] != null;
                          final textValue = _placedStones[index] ?? '';
                          final isHighlighted = _highlightIndex == index;

                          return DragTarget<String>(
                            onAcceptWithDetails: (details) => _onStonePlaced(index, details.data),
                            builder: (context, candidateData, rejectedData) {
                              final isHovering = candidateData.isNotEmpty;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 135,
                                height: 75,
                                decoration: BoxDecoration(
                                  color: isHighlighted
                                      ? widget.color.withValues(alpha: 0.2)
                                      : isFilled
                                          ? AppColors.adventureGreen.withValues(alpha: 0.12)
                                          : isHovering
                                              ? widget.color.withValues(alpha: 0.16)
                                              : AppColors.goldTint,
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: isHighlighted
                                        ? widget.color
                                        : isFilled
                                            ? AppColors.adventureGreen
                                            : isHovering
                                                ? widget.color
                                                : AppColors.goldSoft,
                                    width: isHighlighted || isHovering || isFilled ? 3 : 2,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: isFilled
                                    ? Text(
                                        textValue,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.ink,
                                        ),
                                      )
                                    : Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Stone #${index + 1}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                              color: widget.color.withValues(alpha: 0.65),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          const Icon(
                                            Icons.add_circle_outline,
                                            size: 16,
                                            color: AppColors.goldSoft,
                                          ),
                                        ],
                                      ),
                              );
                            },
                          );
                        }),
                      ),
                      
                      // Success Celebration Burst Lottie
                      if (_success)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: SizedBox(
                            width: 130,
                            height: 130,
                            child: Lottie.asset(
                              'assets/lottie/milestone_burst.json',
                              repeat: false,
                              errorBuilder: (_, _, _) => const SizedBox.shrink(),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Scattered Stepping Stones (Draggable Tray)
          if (!_success) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.goldSoft, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0C4A3A1E),
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  )
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '🪨 Phrase Blocks:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      if (_placedStones.any((s) => s != null))
                        GestureDetector(
                          onTap: _resetStones,
                          child: const Text(
                            'Reset',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.coral,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: _shuffledStones.map((stone) {
                      return Draggable<String>(
                        data: stone,
                        feedback: Material(
                          color: Colors.transparent,
                          child: Transform.scale(
                            scale: 1.1,
                            child: _StoneBlock(text: stone, color: widget.color),
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.35,
                          child: _StoneBlock(text: stone, color: widget.color),
                        ),
                        child: _StoneBlock(text: stone, color: widget.color),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StoneBlock extends StatelessWidget {
  const _StoneBlock({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          )
        ],
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: AppColors.ink,
        ),
      ),
    );
  }
}
