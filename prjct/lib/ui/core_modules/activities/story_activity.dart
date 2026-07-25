import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;
import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';
import 'package:lottie/lottie.dart';

import '../../../data/models/curriculum/curriculum_models.dart';
import '../../theme/app_colors.dart';

/// FR-4.4: Aqidah & Core Beliefs — "The Five Pillars Match"
/// Renders 5 static pillars (Shahada, Salah, Zakat, Sawm, Hajj) and
/// validates illustrative concept cards dragged onto the matching pillar foundations.
class StoryActivity extends StatefulWidget {
  const StoryActivity({
    super.key,
    required this.activityId,
    required this.panels,
    required this.xp,
    required this.onComplete,
  });

  /// e.g. 'dest3-story-2' — used to derive difficulty level
  final String activityId;
  final List<StoryPanel> panels;
  final int xp;
  final void Function(int xp, double accuracyPct, int errors) onComplete;

  @override
  State<StoryActivity> createState() => _StoryActivityState();
}

class _PillarConcept {
  final String id;
  final String name;
  final String emoji;
  final String targetPillar; // 'Shahada', 'Salah', 'Zakat', 'Sawm', 'Hajj'

  const _PillarConcept({
    required this.id,
    required this.name,
    required this.emoji,
    required this.targetPillar,
  });
}

class _StoryActivityState extends State<StoryActivity> with TickerProviderStateMixin {
  bool _success = false;
  int _mismatchCount = 0;

  // List of all five pillars in order
  final List<String> _pillars = ['Shahada', 'Salah', 'Zakat', 'Sawm', 'Hajj'];

  // Pillar Arabic labels
  final Map<String, String> _pillarArabic = {
    'Shahada': 'الشَّهَادَة',
    'Salah': 'الصَّلَاة',
    'Zakat': 'الزَّكَاة',
    'Sawm': 'الصَّوْم',
    'Hajj': 'الْحَجّ',
  };

  // Full pool of concepts
  final List<_PillarConcept> _allConcepts = const [
    _PillarConcept(id: 'sh1', name: 'Declaration', emoji: '☝️', targetPillar: 'Shahada'),
    _PillarConcept(id: 'sh2', name: 'Testimony', emoji: '📜', targetPillar: 'Shahada'),
    _PillarConcept(id: 'sa1', name: 'Prayer Mat', emoji: '🧎', targetPillar: 'Salah'),
    _PillarConcept(id: 'sa2', name: 'Mosque', emoji: '🕌', targetPillar: 'Salah'),
    _PillarConcept(id: 'zk1', name: 'Charity Box', emoji: '🪙', targetPillar: 'Zakat'),
    _PillarConcept(id: 'zk2', name: 'Gold Coins', emoji: '💰', targetPillar: 'Zakat'),
    _PillarConcept(id: 'sw1', name: 'Crescent Moon', emoji: '🌙', targetPillar: 'Sawm'),
    _PillarConcept(id: 'sw2', name: 'Dates', emoji: '🌴', targetPillar: 'Sawm'),
    _PillarConcept(id: 'hj1', name: 'Kaaba', emoji: '🕋', targetPillar: 'Hajj'),
    _PillarConcept(id: 'hj2', name: 'Pilgrim', emoji: '✈️', targetPillar: 'Hajj'),
  ];

  late List<_PillarConcept> _levelConcepts;
  late Map<String, List<_PillarConcept>> _matchedPillars;
  late List<_PillarConcept> _remainingPool;

  late AnimationController _pulseController;
  final Map<String, double> _pillarShakes = {};

  @override
  void initState() {
    super.initState();
    _setupLevel();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    for (final p in _pillars) {
      _pillarShakes[p] = 0.0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  /// Parses the activity ID to produce a true difficulty level (1–14).
  /// ID format: 'destN-story-S'  →  level = (N-1)*2 + S
  /// Examples:
  ///   dest1-story-1 → level 1  (1 card — Shahada only)
  ///   dest1-story-2 → level 2  (2 cards — Shahada, Salah)
  ///   dest2-story-1 → level 3  (3 cards)
  ///   dest2-story-2 → level 4  (4 cards)
  ///   ...continuing up to...
  ///   dest7-story-2 → level 14 (all 10 cards, 2 per pillar)
  int get _difficultyLevel {
    final id = widget.activityId; // e.g. 'dest3-story-2'
    final destMatch = RegExp(r'dest(\d+)').firstMatch(id);
    final slotMatch = RegExp(r'story-(\d+)').firstMatch(id);
    final destNum = int.tryParse(destMatch?.group(1) ?? '1') ?? 1;
    final slotNum = int.tryParse(slotMatch?.group(1) ?? '1') ?? 1;
    return ((destNum - 1) * 2 + slotNum).clamp(1, 14);
  }

  void _setupLevel() {
    final level = _difficultyLevel;

    // Difficulty hierarchy:
    // Level 1  → 1 card  (Shahada × 1)
    // Level 2  → 2 cards (Shahada + Salah, 1 each)
    // Level 3  → 3 cards (Shahada + Salah + Zakat, 1 each)
    // Level 4  → 4 cards (Shahada + Salah + Zakat + Sawm, 1 each)
    // Level 5  → 5 cards (1 per pillar — full set of 'id ends with 1')
    // Level 6  → 6 cards (all 5 × id1 + Shahada × id2)
    // Level 7  → 7 cards
    // ...continuing...
    // Level 10+→ all 10 cards (2 per pillar)
    final firstConcepts = _allConcepts.where((c) => c.id.endsWith('1')).toList();
    final secondConcepts = _allConcepts.where((c) => c.id.endsWith('2')).toList();

    if (level <= 5) {
      // Take the first N 'easy' concepts (1 per pillar progressively)
      _levelConcepts = firstConcepts.take(level).toList();
    } else {
      // All 5 first-concepts + progressively add second-concepts
      final extra = (level - 5).clamp(0, 5);
      _levelConcepts = [
        ...firstConcepts,
        ...secondConcepts.take(extra),
      ];
    }

    _remainingPool = List<_PillarConcept>.from(_levelConcepts)..shuffle();
    _matchedPillars = {
      for (final p in _pillars) p: <_PillarConcept>[],
    };
    _success = false;
  }

  void _shakePillar(String pillar) {
    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    controller.addListener(() {
      if (!mounted) return;
      setState(() {
        final t = controller.value;
        _pillarShakes[pillar] = math.sin(t * math.pi * 5) * 6 * (1 - t);
      });
    });
    controller.forward().then((_) => controller.dispose());
  }

  void _onCardDropped(String pillar, _PillarConcept concept) {
    if (_success) return;

    if (concept.targetPillar == pillar) {
      // Correct Match!
      setState(() {
        _matchedPillars[pillar]!.add(concept);
        _remainingPool.remove(concept);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '🌟 Correctly matched ${concept.emoji} to $pillar!',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          duration: const Duration(milliseconds: 800),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.adventureGreen,
        ),
      );

      // Check if pool is empty
      if (_remainingPool.isEmpty) {
        setState(() {
          _success = true;
        });

        Future.delayed(const Duration(milliseconds: 1800), () {
          if (!mounted) return;
          final totalAttempts = _levelConcepts.length + _mismatchCount;
          final accuracyPct = totalAttempts == 0
              ? 100.0
              : _levelConcepts.length / totalAttempts * 100;
          widget.onComplete(widget.xp, accuracyPct, _mismatchCount);
        });
      }
    } else {
      // FR-4.4.4: Telemetry Error Logging & Mismatch bounce back
      _mismatchCount++;
      developer.log(
        'Pillar_Mismatch: Dragged card "${concept.name}" (${concept.emoji}) to wrong pillar "$pillar"',
        name: 'curriculum.telemetry',
        error: 'Pillar_Mismatch',
      );

      _shakePillar(pillar);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '⚠️ Mismatch: ${concept.name} does not belong to $pillar!',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          duration: const Duration(milliseconds: 800),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.coral,
        ),
      );
    }
  }

  void _resetLevel() {
    if (_success) return;
    setState(() {
      _setupLevel();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF7F6FF), Color(0xFFE8E7FA)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          children: [
            // Title & Progress Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '🕌 Five Pillars Match',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink,
                  ),
                ),
                if (!_success && _remainingPool.length != _levelConcepts.length)
                  GestureDetector(
                    onTap: _resetLevel,
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
            const SizedBox(height: 2),
            const Text(
              'Drag concept cards to their matching pillars!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 8),

            // Pillars Grid — stretches to fill available space
            Expanded(
              flex: 3,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final totalWidth = constraints.maxWidth;
                  final totalHeight = constraints.maxHeight;
                  // 3 cols in row1, 2 cols in row2 — use 3-col width for both
                  final pillarWidth = (totalWidth - 16) / 3; // 8px gap x2
                  // 2 rows with 8px gap between them
                  final rowHeight = (totalHeight - 8) / 2;

                  Widget buildPillarCard(String pillar) {
                    final matches = _matchedPillars[pillar] ?? [];
                    final shakeOffset = _pillarShakes[pillar] ?? 0.0;

                    return Transform.translate(
                      offset: Offset(shakeOffset, 0),
                      child: DragTarget<_PillarConcept>(
                        onAcceptWithDetails: (details) => _onCardDropped(pillar, details.data),
                        builder: (context, candidateData, rejectedData) {
                          final isHovering = candidateData.isNotEmpty;

                          return Container(
                            width: pillarWidth,
                            height: rowHeight,
                            decoration: BoxDecoration(
                              color: isHovering
                                  ? AppColors.goldTint
                                  : Colors.white.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isHovering
                                    ? AppColors.gold
                                    : Colors.deepPurple.withValues(alpha: 0.2),
                                width: isHovering ? 2.5 : 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.deepPurple.withValues(alpha: 0.07),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                )
                              ],
                            ),
                            child: Column(
                              children: [
                                // Pillar header
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isHovering ? AppColors.gold : Colors.deepPurple,
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        pillar,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                      Text(
                                        _pillarArabic[pillar]!,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white.withValues(alpha: 0.85),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Drop zone body — fills remaining height
                                Expanded(
                                  child: Container(
                                    alignment: Alignment.center,
                                    child: matches.isEmpty
                                        ? Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.arrow_downward_rounded,
                                                size: 22,
                                                color: Colors.deepPurple.withValues(alpha: 0.25),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Drop here',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.deepPurple.withValues(alpha: 0.3),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          )
                                        : Wrap(
                                            spacing: 6,
                                            runSpacing: 6,
                                            alignment: WrapAlignment.center,
                                            children: matches.map((concept) {
                                              return Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  color: Colors.deepPurple.withValues(alpha: 0.08),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Text(
                                                  concept.emoji,
                                                  style: const TextStyle(fontSize: 22),
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                  ),
                                ),
                                // Base strip
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 5),
                                  decoration: BoxDecoration(
                                    color: isHovering
                                        ? AppColors.gold.withValues(alpha: 0.15)
                                        : Colors.grey[100],
                                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                                  ),
                                  child: Text(
                                    'BASE',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1,
                                      color: isHovering ? AppColors.gold : Colors.grey[500],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  }

                  return Column(
                    children: [
                      // Row 1: Shahada | Salah | Zakat
                      Row(
                        children: [
                          buildPillarCard('Shahada'),
                          const SizedBox(width: 8),
                          buildPillarCard('Salah'),
                          const SizedBox(width: 8),
                          buildPillarCard('Zakat'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Row 2: Sawm | Hajj — centered
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          buildPillarCard('Sawm'),
                          const SizedBox(width: 8),
                          buildPillarCard('Hajj'),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 8),

            // Concept Cards Pool
            Expanded(
              flex: 2,
              child: _success
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          '🎉 SubhanAllah! Complete!',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: AppColors.adventureGreen,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: 90,
                          height: 90,
                          child: Lottie.asset(
                            'assets/lottie/milestone_burst.json',
                            repeat: false,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                        ),
                      ],
                    )
                  : Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.1), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.deepPurple.withValues(alpha: 0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            '🎴 Concept Cards Pool:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: _remainingPool.map((concept) {
                              return Draggable<_PillarConcept>(
                                data: concept,
                                feedback: Material(
                                  color: Colors.transparent,
                                  child: Transform.scale(
                                    scale: 1.12,
                                    child: _ConceptCardWidget(concept: concept),
                                  ),
                                ),
                                childWhenDragging: Opacity(
                                  opacity: 0.3,
                                  child: _ConceptCardWidget(concept: concept),
                                ),
                                child: _ConceptCardWidget(concept: concept),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConceptCardWidget extends StatelessWidget {
  const _ConceptCardWidget({required this.concept});

  final _PillarConcept concept;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.2), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 3,
            offset: Offset(0, 1.5),
          )
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            concept.emoji,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(width: 4),
          Text(
            concept.name,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
