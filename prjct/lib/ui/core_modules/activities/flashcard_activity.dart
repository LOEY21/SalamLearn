import 'package:flutter/material.dart';

import '../../../data/models/curriculum/curriculum_models.dart';

/// Ported from Wireframe 0.3's `FlashcardActivity.tsx` — tap-to-flip
/// flashcard activity: a done-dot progress row, a flip card (front:
/// emoji + Arabic + translit; back: emoji + English + Arabic first line),
/// and a Back/Next-or-Done nav row.
///
/// Simplification: the source defines `cardFlip`/`unFlip`/`wobble`
/// keyframes but never actually applies them to any element (they're
/// unused CSS), so no rotation animation is ported — only the
/// tap-to-swap-content behavior, which matches the source's real
/// visual behavior.
class FlashcardActivity extends StatefulWidget {
  const FlashcardActivity({
    super.key,
    required this.cards,
    required this.xp,
    required this.color,
    required this.onComplete,
  });

  final List<FlashCard> cards;
  final int xp;
  final Color color;
  final void Function(int xp) onComplete;

  @override
  State<FlashcardActivity> createState() => _FlashcardActivityState();
}

class _FlashcardActivityState extends State<FlashcardActivity> {
  int _idx = 0;
  bool _flipped = false;
  final Set<int> _done = {};

  FlashCard get _card => widget.cards[_idx];

  Color _hexColor(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  void _handleFlip() => setState(() => _flipped = !_flipped);

  void _handleNext() {
    setState(() => _done.add(_idx));
    if (_idx + 1 >= widget.cards.length) {
      widget.onComplete(widget.xp);
    } else {
      setState(() {
        _idx += 1;
        _flipped = false;
      });
    }
  }

  void _handlePrev() {
    if (_idx > 0) {
      setState(() {
        _idx -= 1;
        _flipped = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = _hexColor(_card.color);
    final isLast = _idx + 1 >= widget.cards.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        children: [
          // Card counter dots.
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
                    color: _done.contains(i)
                        ? const Color(0xFF5B9A1E)
                        : i == _idx
                        ? widget.color
                        : const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          // Main flip card.
          Expanded(
            child: GestureDetector(
              onTap: _handleFlip,
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 340),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                decoration: BoxDecoration(
                  color: _flipped ? widget.color : cardColor,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: _flipped ? widget.color : cardColor,
                    width: 4,
                  ),
                  boxShadow: _flipped
                      ? [
                          BoxShadow(
                            color: widget.color.withAlpha(0x88),
                            offset: const Offset(0, 8),
                          ),
                          BoxShadow(
                            color: widget.color.withAlpha(0x33),
                            offset: const Offset(0, 16),
                            blurRadius: 32,
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: cardColor.withAlpha(0x99),
                            offset: const Offset(0, 8),
                          ),
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            offset: const Offset(0, 12),
                            blurRadius: 28,
                          ),
                        ],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Shine effect.
                    Positioned(
                      top: -20,
                      right: -20,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: Center(
                        child: _flipped ? _buildBack() : _buildFront(),
                      ),
                    ),
                    // Flip hint.
                    Positioned(
                      bottom: 12,
                      right: 14,
                      child: Text(
                        _flipped ? '← Back' : 'Tap to flip →',
                        style: TextStyle(
                          fontFamily: 'Nunito',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _flipped
                              ? Colors.white.withValues(alpha: 0.6)
                              : Colors.black.withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Navigation.
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _idx == 0 ? null : _handlePrev,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _idx == 0 ? const Color(0xFFF0EDE8) : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFFE0E0E0),
                        width: 3,
                      ),
                    ),
                    child: Text(
                      '‹ Back',
                      style: TextStyle(
                        fontFamily: 'Fredoka',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: _idx == 0
                            ? const Color(0xFFCCCCCC)
                            : const Color(0xFF888888),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: _handleNext,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: widget.color,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: widget.color, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: widget.color.withAlpha(0x88),
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Text(
                      isLast ? '✓ Done!' : 'Got it! →',
                      style: const TextStyle(
                        fontFamily: 'Fredoka',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Card ${_idx + 1} of ${widget.cards.length} · '
            '${_done.length} learned 🌟',
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFFAAAAAA),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFront() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(_card.emoji, style: const TextStyle(fontSize: 72, height: 1)),
        const SizedBox(height: 12),
        Text(
          _card.arabic,
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: _card.arabic.length > 8 ? 22 : 30,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF222222),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _card.translit,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Nunito',
            fontSize: 14,
            color: Color(0xFF555555),
            fontWeight: FontWeight.w600,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildBack() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('💡', style: TextStyle(fontSize: 52)),
        const SizedBox(height: 14),
        Text(
          _card.english,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Fredoka',
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _card.arabic.split('\n').first,
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 18,
            color: Colors.white.withValues(alpha: 0.8),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
