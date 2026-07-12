import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../data/models/curriculum/curriculum_models.dart';

enum _TileState { idle, selected, matched, wrong }

/// Ported from Wireframe 0.3's `MatchActivity.tsx` — a two-column
/// tap-to-match activity: tap a left tile then a right tile (or vice
/// versa); matching ids lock in green, mismatches flash red and reset.
///
/// Simplification: the source's `matchPop`/`wrongShake` keyframes are
/// skipped — matched/wrong tiles get the color/border feedback state
/// only, with no scale-pop or shake motion.
class MatchActivity extends StatefulWidget {
  const MatchActivity({
    super.key,
    required this.pairs,
    required this.xp,
    required this.color,
    required this.onComplete,
  });

  final List<MatchPair> pairs;
  final int xp;
  final Color color;
  final void Function(int xp) onComplete;

  @override
  State<MatchActivity> createState() => _MatchActivityState();
}

class _MatchActivityState extends State<MatchActivity> {
  late final List<String> _rightShuffled;
  late final Map<String, MatchPair> _pairMap;

  String? _selectedLeft;
  String? _selectedRight;
  final Set<String> _matched = {};
  (String, String)? _wrongPair;

  static final _arabicRe = RegExp(r'[؀-ۿ]');

  bool _isArabic(String text) => _arabicRe.hasMatch(text);

  @override
  void initState() {
    super.initState();
    final ids = widget.pairs.map((p) => p.id).toList();
    final rnd = math.Random();
    for (var i = ids.length - 1; i > 0; i--) {
      final j = rnd.nextInt(i + 1);
      final tmp = ids[i];
      ids[i] = ids[j];
      ids[j] = tmp;
    }
    _rightShuffled = ids;
    _pairMap = {for (final p in widget.pairs) p.id: p};
  }

  void _handleLeftTap(String id) {
    if (_matched.contains(id)) return;
    setState(() {
      _selectedLeft = id;
      _wrongPair = null;
    });
    if (_selectedRight != null) _checkMatch(id, _selectedRight!);
  }

  void _handleRightTap(String id) {
    if (_matched.contains(id)) return;
    setState(() {
      _selectedRight = id;
      _wrongPair = null;
    });
    if (_selectedLeft != null) _checkMatch(_selectedLeft!, id);
  }

  void _checkMatch(String leftId, String rightId) {
    if (leftId == rightId) {
      setState(() {
        _matched.add(leftId);
        _selectedLeft = null;
        _selectedRight = null;
      });
      if (_matched.length >= widget.pairs.length) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (!mounted) return;
          widget.onComplete(widget.xp);
        });
      }
    } else {
      setState(() => _wrongPair = (leftId, rightId));
      Future.delayed(const Duration(milliseconds: 700), () {
        if (!mounted) return;
        setState(() {
          _selectedLeft = null;
          _selectedRight = null;
          _wrongPair = null;
        });
      });
    }
  }

  _TileState _getTileState(String id, bool isLeft) {
    if (_matched.contains(id)) return _TileState.matched;
    if (_wrongPair != null && (_wrongPair!.$1 == id || _wrongPair!.$2 == id)) {
      return _TileState.wrong;
    }
    if (isLeft && _selectedLeft == id) return _TileState.selected;
    if (!isLeft && _selectedRight == id) return _TileState.selected;
    return _TileState.idle;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Match each Arabic word with its meaning! ✨',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Fredoka',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF888888),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_matched.length}/${widget.pairs.length} matched',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 12,
              color: Color(0xFFCCCCCC),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left column (Arabic).
                Expanded(
                  child: Column(
                    children: [
                      for (var i = 0; i < widget.pairs.length; i++) ...[
                        if (i != 0) const SizedBox(height: 8),
                        Expanded(
                          child: _buildTile(
                            text: widget.pairs[i].left,
                            emoji: widget.pairs[i].leftEmoji,
                            state: _getTileState(widget.pairs[i].id, true),
                            onTap: () => _handleLeftTap(widget.pairs[i].id),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Center connection markers.
                SizedBox(
                  width: 20,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Column(
                      children: [
                        for (var i = 0; i < widget.pairs.length; i++) ...[
                          if (i != 0) const SizedBox(height: 8),
                          Expanded(
                            child: Center(
                              child: _matched.contains(widget.pairs[i].id)
                                  ? Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF5B9A1E),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      alignment: Alignment.center,
                                      child: const Text(
                                        '✓',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.white,
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                // Right column (English).
                Expanded(
                  child: Column(
                    children: [
                      for (var i = 0; i < _rightShuffled.length; i++) ...[
                        if (i != 0) const SizedBox(height: 8),
                        Builder(
                          builder: (context) {
                            final id = _rightShuffled[i];
                            final pair = _pairMap[id]!;
                            return Expanded(
                              child: _buildTile(
                                text: pair.right,
                                emoji: pair.rightEmoji,
                                state: _getTileState(id, false),
                                onTap: () => _handleRightTap(id),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile({
    required String text,
    required String? emoji,
    required _TileState state,
    required VoidCallback onTap,
  }) {
    final isArabic = _isArabic(text);
    late final Color bg;
    late final Color border;
    late final Color textColor;
    switch (state) {
      case _TileState.idle:
        bg = Colors.white;
        border = const Color(0xFFE0E0E0);
        textColor = const Color(0xFF222222);
      case _TileState.selected:
        bg = widget.color.withAlpha(0x22);
        border = widget.color;
        textColor = widget.color;
      case _TileState.matched:
        bg = const Color(0xFFDCF0E6);
        border = const Color(0xFF5B9A1E);
        textColor = const Color(0xFF5B9A1E);
      case _TileState.wrong:
        bg = const Color(0xFFFDDCCC);
        border = const Color(0xFFD85A30);
        textColor = const Color(0xFFD85A30);
    }

    return GestureDetector(
      onTap: state == _TileState.matched ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: border, width: 3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emoji != null)
              Text(emoji, style: const TextStyle(fontSize: 18)),
            Text(
              text,
              textAlign: TextAlign.center,
              textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
              style: TextStyle(
                fontFamily: isArabic ? 'Cairo' : 'Fredoka',
                fontSize: isArabic ? 16 : 14,
                fontWeight: FontWeight.w600,
                color: textColor,
                height: 1.2,
              ),
            ),
            if (state == _TileState.matched)
              const Text('✓', style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
