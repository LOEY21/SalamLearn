import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../data/models/curriculum/curriculum_models.dart';

/// Ported from Wireframe 0.3's `StoryActivity.tsx` — tap-anywhere-to-advance
/// storyboard: scene emoji/characters positioned by percentage, an
/// optional speech bubble, and a caption bar with the next-panel hint.
///
/// Simplification: the source staggers each scene item's entrance
/// (`floatIn` with a per-item delay) and keeps them gently bobbing forever
/// (`charFloat`, an infinite loop). Both are collapsed here into a single
/// simple fade+slide entrance for the whole scene layer when the panel
/// changes — the per-item stagger delay and the continuous idle bob are
/// dropped as decorative motion that isn't part of the paging logic.
class StoryActivity extends StatefulWidget {
  const StoryActivity({
    super.key,
    required this.panels,
    required this.xp,
    required this.onComplete,
  });

  final List<StoryPanel> panels;
  final int xp;
  final void Function(int xp) onComplete;

  @override
  State<StoryActivity> createState() => _StoryActivityState();
}

class _StoryActivityState extends State<StoryActivity> {
  int _idx = 0;
  bool _entering = false;

  StoryPanel get _panel => widget.panels[_idx];

  Color _hexColor(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  void _advance() {
    if (_idx + 1 >= widget.panels.length) {
      widget.onComplete(widget.xp);
    } else {
      setState(() => _entering = true);
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!mounted) return;
        setState(() {
          _idx += 1;
          _entering = false;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _idx + 1 >= widget.panels.length;

    return GestureDetector(
      onTap: _advance,
      child: AnimatedOpacity(
        opacity: _entering ? 0 : 1,
        duration: const Duration(milliseconds: 200),
        child: Container(
          decoration: BoxDecoration(color: _hexColor(_panel.bg)),
          clipBehavior: Clip.hardEdge,
          child: Column(
            children: [
              const SizedBox(height: 12),
              // Panel number dots.
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < widget.panels.length; i++) ...[
                    if (i != 0) const SizedBox(width: 6),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: i == _idx ? 20 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: i <= _idx
                            ? Colors.white.withValues(alpha: 0.9)
                            : Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              // Scene area.
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final height = constraints.maxHeight;
                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Stack(
                        key: ValueKey(_idx),
                        clipBehavior: Clip.none,
                        children: [
                          for (final item in _panel.scene)
                            Positioned(
                              left: width * item.x / 100,
                              top: height * item.y / 100,
                              child: FractionalTranslation(
                                translation: const Offset(-0.5, 0),
                                child: Transform(
                                  alignment: Alignment.center,
                                  transform: item.flip == true
                                      ? Matrix4.diagonal3Values(-1.0, 1.0, 1.0)
                                      : Matrix4.identity(),
                                  child: Text(
                                    item.emoji,
                                    style: TextStyle(
                                      fontSize: item.size.toDouble(),
                                      height: 1,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          if (_panel.bubble != null)
                            _buildBubble(_panel.bubble!, width, height),
                        ],
                      ),
                    );
                  },
                ),
              ),
              // Caption bar.
              ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    color: Colors.black.withValues(alpha: 0.55),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _panel.caption,
                          style: const TextStyle(
                            fontFamily: 'Fredoka',
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            height: 1.35,
                          ),
                        ),
                        if (_panel.captionAr != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _panel.captionAr!,
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.75),
                              height: 1.4,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Center(
                          child: Text(
                            isLast
                                ? '⭐ Tap to finish the story!'
                                : '👆 Tap anywhere to continue...',
                            style: TextStyle(
                              fontFamily: 'Nunito',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
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
  }

  Widget _buildBubble(
    StoryBubble bubble,
    double parentWidth,
    double parentHeight,
  ) {
    final maxWidth = parentWidth * 0.65;
    final topOffset = parentHeight * 0.08;
    final content = Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            bubble.text,
            textAlign: bubble.side == 'right'
                ? TextAlign.right
                : bubble.side == 'center'
                ? TextAlign.center
                : TextAlign.left,
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Color(0xFF222222),
              height: 1.4,
            ),
          ),
          if (bubble.ar != null)
            Text(
              bubble.ar!,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12,
                color: Color(0xFF888888),
              ),
            ),
        ],
      ),
    );

    if (bubble.side == 'left') {
      return Positioned(
        top: topOffset,
        left: parentWidth * 0.05,
        child: content,
      );
    }
    if (bubble.side == 'right') {
      return Positioned(
        top: topOffset,
        right: parentWidth * 0.05,
        child: content,
      );
    }
    return Positioned(
      top: topOffset,
      left: 0,
      right: 0,
      child: Center(child: content),
    );
  }
}
