import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../data/models/curriculum/curriculum_models.dart';
import '../../theme/app_colors.dart';

class PronounceActivity extends StatefulWidget {
  const PronounceActivity({
    super.key,
    required this.cards,
    required this.xp,
    required this.color,
    required this.onComplete,
  });

  final List<FlashCard> cards;
  final int xp;
  final Color color;
  final void Function(int xp, double accuracyPct, int errors) onComplete;

  @override
  State<PronounceActivity> createState() => _PronounceActivityState();
}

class _PronounceActivityState extends State<PronounceActivity>
    with TickerProviderStateMixin {
  int _idx = 0;
  bool _success = false;
  int _correctDrops = 0;
  int _wrongDrops = 0;
  final List<String> _droppedItems = []; // Emojis of items currently in the basket
  double _wobble = 0.0;
  late AnimationController _wobbleController;
  late AnimationController _pulseController;

  List<String> _currentTrayItems = [];

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

    _generateTrayItems();
  }

  void _generateTrayItems() {
    final correct = _targetItemEmoji;
    final allPool = ['🌴', '🐪', '🏮', '⭐', '🎈', '🍎', '🐱', '🚗'];
    final incorrects = allPool.where((item) => item != correct).toList();
    
    incorrects.shuffle();

    // Always use exactly 3 distractors to display exactly 4 choices in the tray
    const count = 3;

    final selected = [correct, ...incorrects.take(count)];
    selected.shuffle();
    
    _currentTrayItems = selected;
  }

  @override
  void dispose() {
    _wobbleController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  FlashCard get _card => widget.cards[_idx];

  int get _targetNumber {
    final name = _card.english.toLowerCase();
    if (name.contains('one')) return 1;
    if (name.contains('two')) return 2;
    if (name.contains('three')) return 3;
    if (name.contains('four')) return 4;
    if (name.contains('five')) return 5;
    if (name.contains('six')) return 6;
    if (name.contains('seven')) return 7;
    if (name.contains('eight')) return 8;
    if (name.contains('nine')) return 9;
    if (name.contains('ten')) return 10;
    
    // Fallback: if it's not a number card, use index-based counting (e.g. 1 to 5)
    return (_idx % 5) + 1;
  }

  String get _targetSound => _card.translit;

  String get _targetItemEmoji {
    final list = ['🌴', '🐪', '🏮', '⭐'];
    return list[_idx % list.length];
  }

  String get _targetItemName {
    final list = ['Dates', 'Camels', 'Lanterns', 'Stars'];
    return list[_idx % list.length];
  }

  void _playSound() {
    // Simulate phonetic pronunciation clip playback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '🔊 Pronouncing number prompt: "$_targetSound" ($_targetNumber $_targetItemName)',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        duration: const Duration(milliseconds: 800),
        behavior: SnackBarBehavior.floating,
        backgroundColor: widget.color,
      ),
    );
  }

  void _onItemDrop(String emoji) {
    if (_success) return;

    // Check if the item dropped matches the target item type!
    if (emoji != _targetItemEmoji) {
      _wrongDrops++;
      _wobbleController.forward(from: 0);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '⚠️ Put only $_targetItemName in the basket!',
            style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
          ),
          duration: const Duration(milliseconds: 600),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.coral,
        ),
      );
      return;
    }
    
    if (_droppedItems.length < _targetNumber) {
      _correctDrops++;
      setState(() {
        _droppedItems.add(emoji);
      });

      if (_droppedItems.length == _targetNumber) {
        setState(() {
          _success = true;
        });

        // Auto-advance to next card/number after a delay
        Future.delayed(const Duration(milliseconds: 1600), () {
          if (!mounted) return;
          if (_idx + 1 >= widget.cards.length) {
            final totalAttempts = _correctDrops + _wrongDrops;
            final accuracyPct = totalAttempts == 0
                ? 100.0
                : _correctDrops / totalAttempts * 100;
            widget.onComplete(widget.xp, accuracyPct, _wrongDrops);
          } else {
            setState(() {
              _idx++;
              _success = false;
              _droppedItems.clear();
              _generateTrayItems();
            });
          }
        });
      }
    } else {
      // Exceeded target count! Trigger wobble/shake on the basket
      _wobbleController.forward(from: 0);
    }
  }

  void _clearBasket() {
    if (_success) return;
    setState(() {
      _droppedItems.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        children: [
          // Progress Dots
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
                    color: _droppedItems.length == _targetNumber && _idx == i
                        ? AppColors.adventureGreen
                        : i < _idx
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
            'The Market Basket',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: widget.color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Drag $_targetNumber $_targetItemName into the basket!',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 14),

          // Audio Number Prompt Button
          GestureDetector(
            onTap: _playSound,
            child: ScaleTransition(
              scale: Tween<double>(begin: 1.0, end: 1.05).animate(
                CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: widget.color, width: 2.5),
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
                      '$_targetSound ($_targetNumber $_targetItemName)',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: widget.color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Main Game Board (Drop-Zone & Counters)
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // The Market Basket Drop Zone
                Transform.translate(
                  offset: Offset(_wobble, 0),
                  child: Center(
                    child: DragTarget<String>(
                      onAcceptWithDetails: (details) => _onItemDrop(details.data),
                      builder: (context, candidateData, rejectedData) {
                        final isHovering = candidateData.isNotEmpty;
                        return Container(
                          width: 175,
                          height: 175,
                          decoration: BoxDecoration(
                            color: _success
                                ? AppColors.adventureGreen.withValues(alpha: 0.12)
                                : isHovering
                                    ? widget.color.withValues(alpha: 0.22)
                                    : AppColors.goldTint,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: _success
                                  ? AppColors.adventureGreen
                                  : isHovering
                                      ? widget.color
                                      : AppColors.goldSoft,
                              width: 2.5,
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Basket Background Icon & Text
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    '🧺',
                                    style: TextStyle(
                                      fontSize: 72,
                                    ),
                                  ),
                                ],
                              ),

                              // Dropped items display grid inside the basket!
                              if (_droppedItems.isNotEmpty)
                                Positioned.fill(
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Wrap(
                                      alignment: WrapAlignment.center,
                                      runAlignment: WrapAlignment.center,
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: _droppedItems.map((itemEmoji) {
                                        return Text(
                                          itemEmoji,
                                          style: const TextStyle(fontSize: 20),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),

                              // Counter Badge
                              Positioned(
                                bottom: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _success
                                        ? AppColors.adventureGreen
                                        : AppColors.gold,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Text(
                                    '${_droppedItems.length} of $_targetNumber',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),

                              // Success Burst
                              if (_success)
                                Positioned.fill(
                                  child: Center(
                                    child: SizedBox(
                                      width: 150,
                                      height: 150,
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
                        );
                      },
                    ),
                  ),
                ),

                // Clear/Reset Basket Button
                if (_droppedItems.isNotEmpty && !_success)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: IconButton(
                      onPressed: _clearBasket,
                      icon: const Icon(Icons.refresh, color: AppColors.coral, size: 24),
                      tooltip: 'Clear Basket',
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Draggable Asset Items selector tray (dates, camels, lanterns, stars)
          if (!_success) ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.goldSoft, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0C4A3A1E),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  )
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _currentTrayItems.map((itemEmoji) {
                  return Draggable<String>(
                    data: itemEmoji,
                    feedback: Material(
                      color: Colors.transparent,
                      child: Transform.scale(
                        scale: 1.25,
                        child: _DraggableItem(emoji: itemEmoji, color: widget.color),
                      ),
                    ),
                    childWhenDragging: Opacity(
                      opacity: 0.45,
                      child: _DraggableItem(emoji: itemEmoji, color: widget.color),
                    ),
                    child: _DraggableItem(emoji: itemEmoji, color: widget.color),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DraggableItem extends StatelessWidget {
  const _DraggableItem({required this.emoji, required this.color});

  final String emoji;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.35), width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C4A3A1E),
            blurRadius: 5,
            offset: Offset(0, 2),
          )
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        emoji,
        style: const TextStyle(fontSize: 22),
      ),
    );
  }
}
