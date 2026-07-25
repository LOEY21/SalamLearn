import 'package:salamlearn/logic/localization/app_translations.dart';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';
import 'package:flutter/services.dart';

import '../../../data/models/curriculum/curriculum_models.dart';

/// Ayah Builder — direct port of the "Ayah Builder" HTML prototype.
///
/// The learner rebuilds a Qur'anic verse by placing its Arabic word cards
/// into the slots in the correct right-to-left order: tap (or drag) the next
/// word, correct words snap in, wrong ones shake. Finishing plays a
/// word-by-word highlighted re-recitation, then a reward overlay with stars
/// and the full Ayah + meaning. Per FR-4.3's Ayah memorization spec.
///
/// The whole scene is laid out inside a 440×900 reference board (matching the
/// prototype's fixed frame) scaled to fit the screen, so positions/sizes
/// mirror the HTML pixel-for-pixel.
class AyahBuilderActivity extends StatefulWidget {
  const AyahBuilderActivity({
    super.key,
    required this.levels,
    required this.xp,
    required this.color,
    required this.onComplete,
    required this.onBack,
  });

  final List<AyahBuilderLevel> levels;
  final int xp;
  final Color color;
  final void Function(int xp, double accuracyPct, int errors) onComplete;
  final VoidCallback onBack;

  @override
  State<AyahBuilderActivity> createState() => _AyahBuilderActivityState();
}

enum _Phase { play, recite, reward }

class _AyahBuilderActivityState extends State<AyahBuilderActivity>
    with TickerProviderStateMixin {
  // ---- prototype palette ------------------------------------------------
  static const _purple = Color(0xFF8B5CF6);
  static const _purpleDk = Color(0xFF6D3FC9);
  static const _green = Color(0xFF4CC944);
  static const _greenDk = Color(0xFF2F8F2A);
  static const _orange = Color(0xFFF5A524);
  static const _orangeDk = Color(0xFFCF8515);
  static const _blue = Color(0xFF2F9BE0);
  static const _titleGreen = Color(0xFF39B54A);
  static const _ink = Color(0xFF5B4636);
  static const _gold = Color(0xFFFFC73A);
  static const _sky = Color(0xFFBFE6F7);

  static const _cardColors = [
    Color(0xFF7C5CE0),
    Color(0xFF39B54A),
    Color(0xFF2F9BE0),
    Color(0xFFF5A524),
    Color(0xFFE0577C),
    Color(0xFF17B8A6),
  ];
  static const _cardColorsDk = [
    Color(0xFF5B3FC0),
    Color(0xFF2A8A37),
    Color(0xFF1F7FC0),
    Color(0xFFCF8515),
    Color(0xFFBF4064),
    Color(0xFF0F8F81),
  ];
  static const _buntingColors = [
    Color(0xFF7C5CE0),
    Color(0xFF39B54A),
    Color(0xFF2F9BE0),
    Color(0xFFF5A524),
    Color(0xFFE0577C),
  ];

  // ---- state ------------------------------------------------------------
  int _levelIndex = 0;
  bool _showTranslit = true;
  _Phase _phase = _Phase.play;
  int _highlight = -1;

  late List<int> _deck; // shuffled original word indices
  final List<int> _placed = []; // placed original indices, in order
  int _mistakes = 0;
  int _hints = 0;
  int _shakeId = -1;
  int _earned = 0;
  int _totalStars = 0;

  // aggregate scoring across levels for onComplete
  int _attempts = 0;
  int _wrongTotal = 0;
  int _extraTotal = 0; // wrong + hints, reported as errors

  Timer? _reciteTimer;
  late final AnimationController _ambient; // card bob + listen pulse
  late final AnimationController _shake;
  late final AnimationController _reward;

  AyahBuilderLevel get _level => widget.levels[_levelIndex];
  int get _wordCount => _level.arabicWords.length;

  @override
  void initState() {
    super.initState();
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _reward = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _setupLevel();
  }

  @override
  void dispose() {
    _reciteTimer?.cancel();
    _ambient.dispose();
    _shake.dispose();
    _reward.dispose();
    super.dispose();
  }

  void _setupLevel() {
    _deck = List<int>.generate(_wordCount, (i) => i)..shuffle();
    _placed.clear();
    _mistakes = 0;
    _hints = 0;
    _shakeId = -1;
    _highlight = -1;
    _phase = _Phase.play;
  }

  int get _stars {
    final penalty = _hints + _mistakes ~/ 2;
    return math.max(1, 3 - math.min(2, penalty));
  }

  void _place(int originalIndex) {
    if (_phase != _Phase.play) return;
    _attempts++;
    if (originalIndex == _placed.length) {
      HapticFeedback.selectionClick();
      setState(() => _placed.add(originalIndex));
      if (_placed.length == _wordCount) _complete();
    } else {
      _mistakes++;
      _wrongTotal++;
      setState(() => _shakeId = originalIndex);
      HapticFeedback.lightImpact();
      _shake.forward(from: 0).whenComplete(() {
        if (mounted) setState(() => _shakeId = -1);
      });
    }
  }

  void _useHint() {
    if (_phase != _Phase.play) return;
    final next = _placed.length;
    if (next >= _wordCount) return;
    _hints++;
    HapticFeedback.lightImpact();
    setState(() => _placed.add(next));
    if (_placed.length == _wordCount) _complete();
  }

  void _complete() {
    _playListen();
    setState(() {
      _phase = _Phase.recite;
      _highlight = 0;
    });
    var i = 0;
    _reciteTimer?.cancel();
    _reciteTimer =
        Timer.periodic(const Duration(milliseconds: 780), (timer) {
      if (!mounted) return;
      i++;
      if (i >= _wordCount) {
        timer.cancel();
        Timer(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          setState(() {
            _earned = _stars;
            _totalStars += _earned;
            _phase = _Phase.reward;
            _highlight = -1;
          });
          _reward.forward(from: 0);
        });
      } else {
        setState(() => _highlight = i);
      }
    });
  }

  void _next() {
    if (_levelIndex + 1 >= widget.levels.length) {
      _extraTotal = _wrongTotal + _hints; // hints of final level folded below
      final acc =
          _attempts == 0 ? 100.0 : (_attempts - _wrongTotal) / _attempts * 100;
      widget.onComplete(widget.xp, acc, _wrongTotal + _extraTotal);
      return;
    }
    _extraTotal += _hints;
    setState(() {
      _levelIndex++;
      _setupLevel();
    });
  }

  void _playListen() {
    final phrase = _level.translitWords.join(' ');
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('🔊  "$phrase"',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          duration:
              Duration(milliseconds: _level.translitWords.length * 700 + 400),
          behavior: SnackBarBehavior.floating,
          backgroundColor: _blue,
        ),
      );
  }

  // (name, ayahRef) split from the level reference, e.g.
  // "Surah Al-Fātiḥah (Ayah 1)" -> ("Surah Al-Fātiḥah", "Ayah 1").
  (String, String?) get _surahParts {
    final ref = _level.reference;
    final m = RegExp(r'^(.*?)\s*\(?(Ayah\s*\d+)\)?$').firstMatch(ref);
    if (m != null) return (m.group(1)!.trim(), m.group(2));
    return (ref, null);
  }

  // ---- build ------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Container(
      color: _sky,
      child: LayoutBuilder(
        builder: (context, c) {
          // Cover (not contain) the viewport: scale so the 440x900 reference
          // board fills the screen edge-to-edge, cropping the smaller axis
          // instead of letterboxing. Every element's position is a multiple
          // of this same `s`, so it stays anchored relative to the others.
          final s = math.max(c.maxWidth / 440, c.maxHeight / 900);
          return ClipRect(
            child: Center(
              child: SizedBox(
                width: 440 * s,
                height: 900 * s,
                child: _board(s),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _board(double s) {
    final n = _wordCount;
    return Stack(
      children: [
        // backdrop
        Positioned.fill(
          child: Image.asset('assets/images/ayah_builder/ayah_builder_bg.png',
              fit: BoxFit.cover),
        ),
        // bunting
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 34 * s,
          child: CustomPaint(painter: _BuntingPainter(s)),
        ),

        _header(s),
        _instruction(s),
        _slots(s),
        if (_phase == _Phase.play) _cards(s),

        // mascot sits behind the surah badge + controls
        if (_phase == _Phase.play) ..._mascotHint(s),

        _surahBadge(s),
        _controls(s),
        _progress(s, n),

        if (_phase == _Phase.reward) _rewardOverlay(s),
      ],
    );
  }

  // ---- header -----------------------------------------------------------
  Widget _header(double s) {
    return Positioned(
      top: 14 * s,
      left: 14 * s,
      right: 14 * s,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _squareButton(
                s,
                onTap: widget.onBack,
                child: Icon(Icons.arrow_back_rounded,
                    color: Colors.white, size: 24 * s),
              ),
              SizedBox(height: 8 * s),
              _whitePill(
                s,
                padH: 12 * s,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  _StarBox(size: 22 * s, gold: true),
                  SizedBox(width: 6 * s),
                  Text('$_totalStars',
                      style: TextStyle(
                          fontFamily: 'Fredoka',
                          fontWeight: FontWeight.w700,
                          fontSize: 18 * s,
                          color: _ink)),
                ]),
              ),
            ],
          ),
          const Spacer(),
          Column(
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: 18 * s, vertical: 4 * s),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0x1F000000),
                        offset: Offset(0, 3 * s)),
                  ],
                ),
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(
                      fontFamily: 'Fredoka',
                      fontWeight: FontWeight.w700,
                      fontSize: 34 * s,
                      height: 0.92,
                    ),
                    children: const [
                      TextSpan(text: 'Ayah ',
                          style: TextStyle(color: _titleGreen)),
                      TextSpan(text: 'Builder', style: TextStyle(color: _blue)),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 6 * s),
              _whitePill(
                s,
                padH: 14 * s,
                padV: 3 * s,
                child: Text('Complete the Holy Ayah',
                    style: TextStyle(
                        fontFamily: 'Fredoka',
                        fontWeight: FontWeight.w600,
                        fontSize: 14 * s,
                        color: _purple)),
              ),
            ],
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _squareButton(
                s,
                onTap: () => setState(() => _showTranslit = !_showTranslit),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _bar(20 * s, s),
                    SizedBox(height: 3 * s),
                    _bar(14 * s, s),
                    SizedBox(height: 3 * s),
                    _bar(20 * s, s),
                  ],
                ),
              ),
              SizedBox(height: 8 * s),
              _whitePill(
                s,
                padH: 12 * s,
                padV: 4 * s,
                child: Text('Level ${_levelIndex + 1}',
                    style: TextStyle(
                        fontFamily: 'Fredoka',
                        fontWeight: FontWeight.w600,
                        fontSize: 13 * s,
                        color: _ink)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bar(double w, double s) => Container(
      width: w,
      height: 3 * s,
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(2 * s)));

  Widget _squareButton(double s,
      {required VoidCallback onTap, required Widget child}) {
    return _PressButton(
      shadowY: 4 * s,
      onTap: onTap,
      builder: (pressed) => Container(
        width: 46 * s,
        height: 46 * s,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _purple,
          borderRadius: BorderRadius.circular(15 * s),
          boxShadow: [
            BoxShadow(color: _purpleDk, offset: Offset(0, (pressed ? 1 : 4) * s)),
          ],
        ),
        child: child,
      ),
    );
  }

  Widget _whitePill(double s,
      {required Widget child, double padH = 14, double padV = 5}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(color: const Color(0x1F000000), offset: Offset(0, 3 * s)),
        ],
      ),
      child: child,
    );
  }

  // ---- instruction ------------------------------------------------------
  Widget _instruction(double s) {
    return Positioned(
      top: 118 * s,
      left: 24 * s,
      right: 24 * s,
      child: Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16 * s, vertical: 8 * s),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(16 * s),
            boxShadow: [
              BoxShadow(
                  color: const Color(0x14000000), offset: Offset(0, 3 * s)),
            ],
          ),
          child: Text('Drag the words into the right places to complete the Ayah',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'Fredoka',
                fontWeight: FontWeight.w500,
                fontSize: 14 * s,
                color: const Color(0xFF6B563F)),
          ),
        ),
      ),
    );
  }

  // ---- slots ------------------------------------------------------------
  Widget _slots(double s) {
    return Positioned(
      top: 180 * s,
      left: 16 * s,
      right: 16 * s,
      child: DragTarget<int>(
        onAcceptWithDetails: (d) => _place(d.data),
        builder: (context, cand, rej) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: Wrap(
              spacing: 9 * s,
              runSpacing: 9 * s,
              alignment: WrapAlignment.center,
              children: List.generate(_wordCount, (i) {
                final filled = i < _placed.length;
                final hi = _phase == _Phase.recite && _highlight == i;
                return _slotBox(s, i, filled, hi);
              }),
            ),
          );
        },
      ),
    );
  }

  Widget _slotBox(double s, int i, bool filled, bool hi) {
    final content = filled
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_level.arabicWords[i],
                  style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.w700,
                      fontSize: 26 * s,
                      color: hi ? _titleGreen : _ink)),
              if (_showTranslit)
                Text(_level.translitWords[i],
                    style: TextStyle(
                        fontFamily: 'Fredoka',
                        fontSize: 12 * s,
                        color: const Color(0xFF7A6A53))),
            ],
          )
        : const SizedBox.shrink();

    Widget box = AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      constraints:
          BoxConstraints(minWidth: 92 * s, minHeight: 74 * s),
      padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 8 * s),
      decoration: BoxDecoration(
        color: filled
            ? (hi ? const Color(0xFFFFF6DD) : const Color(0xFFFFFDF7))
            : const Color(0xA6F5EBD2),
        borderRadius: BorderRadius.circular(14 * s),
        boxShadow: filled
            ? [BoxShadow(color: const Color(0x14000000), offset: Offset(0, 3 * s))]
            : null,
        border: filled
            ? Border.all(
                color: hi ? _gold : const Color(0xFFD9C9A4), width: 2)
            : null,
      ),
      child: content,
    );

    // dashed border for empty slots
    if (!filled) {
      box = CustomPaint(
        foregroundPainter: _DashedRRectPainter(
            color: const Color(0xFFCBB88F), radius: 14 * s, gap: 4 * s),
        child: box,
      );
    }
    // recite glow
    if (hi) {
      box = Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14 * s),
          boxShadow: [
            BoxShadow(
                color: _gold.withValues(alpha: 0.9),
                blurRadius: 22 * s,
                spreadRadius: 6 * s),
          ],
        ),
        child: box,
      );
    }
    return box;
  }

  // ---- word cards -------------------------------------------------------
  Widget _cards(double s) {
    final available = _deck.where((oi) => !_placed.contains(oi)).toList();
    return Positioned(
      top: 355 * s,
      left: 14 * s,
      right: 14 * s,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Wrap(
          spacing: 11 * s,
          runSpacing: 11 * s,
          alignment: WrapAlignment.center,
          children: available.map((oi) => _card(s, oi)).toList(),
        ),
      ),
    );
  }

  Widget _card(double s, int oi) {
    final ci = oi % _cardColors.length;
    final rot = ((oi * 37) % 5 - 2) * 0.9 * math.pi / 180;
    final chip = _WordCard(
      s: s,
      arabic: _level.arabicWords[oi],
      translit: _showTranslit ? _level.translitWords[oi] : null,
      color: _cardColors[ci],
      colorDk: _cardColorsDk[ci],
    );

    // wrong-answer shake
    Widget child = AnimatedBuilder(
      animation: _shake,
      builder: (context, ch) {
        final dx = _shakeId == oi
            ? math.sin(_shake.value * math.pi * 5) * 7 * (1 - _shake.value)
            : 0.0;
        return Transform.translate(offset: Offset(dx, 0), child: ch);
      },
      child: chip,
    );

    // idle bob (skip while shaking)
    child = AnimatedBuilder(
      animation: _ambient,
      builder: (context, ch) {
        if (_shakeId == oi) return Transform.rotate(angle: rot, child: ch);
        final phase = (oi * 0.2) % 1;
        final dy =
            math.sin((_ambient.value + phase) * 2 * math.pi) * 3 * s;
        return Transform.translate(
            offset: Offset(0, dy),
            child: Transform.rotate(angle: rot, child: ch));
      },
      child: child,
    );

    return GestureDetector(
      onTap: () => _place(oi),
      child: Draggable<int>(
        data: oi,
        feedback: Material(
          color: Colors.transparent,
          child: Transform.scale(scale: 1.12, child: chip),
        ),
        childWhenDragging: Opacity(opacity: 0.3, child: chip),
        child: child,
      ),
    );
  }

  // ---- surah badge + dots ----------------------------------------------
  Widget _surahBadge(double s) {
    final (name, ref) = _surahParts;
    return Positioned(
      bottom: 200 * s,
      left: 0,
      right: 0,
      child: Transform.translate(
        offset: Offset(-6 * s, 0),
        child: Column(
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(16 * s, 7 * s, 8 * s, 7 * s),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                    color: const Color(0x1A000000), offset: Offset(0, 4 * s)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name,
                    style: TextStyle(
                        fontFamily: 'Fredoka',
                        fontWeight: FontWeight.w600,
                        fontSize: 15 * s,
                        color: _ink)),
                if (ref != null) ...[
                  SizedBox(width: 8 * s),
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 12 * s, vertical: 3 * s),
                    decoration: BoxDecoration(
                        color: _purple,
                        borderRadius: BorderRadius.circular(999)),
                    child: Text(ref,
                        style: TextStyle(
                            fontFamily: 'Fredoka',
                            fontWeight: FontWeight.w700,
                            fontSize: 13 * s,
                            color: Colors.white)),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: 12 * s),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_wordCount, (i) {
              final on = i < _placed.length;
              return Container(
                margin: EdgeInsets.symmetric(horizontal: 4.5 * s),
                width: 12 * s,
                height: 12 * s,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: on ? _gold : Colors.white.withValues(alpha: 0.6),
                  border: on
                      ? null
                      : Border.all(
                          color: const Color(0xFFCBB88F), width: 2),
                  boxShadow: on
                      ? [
                          BoxShadow(
                              color: _gold.withValues(alpha: 0.8),
                              blurRadius: 8 * s),
                        ]
                      : null,
                ),
              );
            }),
          ),
        ],
        ),
      ),
    );
  }

  // ---- hint / listen / rewards -----------------------------------------
  Widget _controls(double s) {
    return Positioned(
      bottom: 96 * s,
      left: 22 * s,
      right: 22 * s,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // hint
          Column(
            children: [
              _roundButton(
                s,
                size: 60 * s,
                color: _orange,
                colorDk: _orangeDk,
                onTap: _phase == _Phase.play ? _useHint : null,
                child: Icon(Icons.lightbulb_rounded,
                    color: Colors.white, size: 26 * s),
              ),
              SizedBox(height: 6 * s),
              _tag(s, 'Hint', _orange, _orangeDk, 12 * s),
            ],
          ),
          // listen (pulsing) — ring overflows via OverflowBox so it never
          // inflates the column height and shoves the button into the badge.
          Column(
            children: [
              SizedBox(
                width: 74 * s,
                height: 74 * s,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _ambient,
                        builder: (context, _) {
                          final t = _ambient.value;
                          return OverflowBox(
                            maxWidth: 200 * s,
                            maxHeight: 200 * s,
                            child: Container(
                              width: 74 * s * (1 + t * 0.5),
                              height: 74 * s * (1 + t * 0.5),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _green.withValues(alpha: 0.6 * (1 - t)),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    _roundButton(
                      s,
                      size: 74 * s,
                      color: _green,
                      colorDk: _greenDk,
                      onTap: _playListen,
                      child: Padding(
                        padding: EdgeInsets.only(left: 6 * s),
                        child: Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 40 * s),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 6 * s),
              _tag(s, 'Listen to the Ayah', _blue, const Color(0x26000000),
                  13 * s),
            ],
          ),
          // rewards preview
          Column(
            children: [
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 10 * s, vertical: 2 * s),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(999)),
                child: Text('Rewards',
                    style: TextStyle(
                        fontFamily: 'Fredoka',
                        fontWeight: FontWeight.w600,
                        fontSize: 12 * s,
                        color: _purple)),
              ),
              SizedBox(height: 4 * s),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                    3,
                    (i) => Padding(
                          padding: EdgeInsets.symmetric(horizontal: 1.5 * s),
                          child: _StarBox(size: 22 * s, gold: false),
                        )),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _roundButton(double s,
      {required double size,
      required Color color,
      required Color colorDk,
      required VoidCallback? onTap,
      required Widget child}) {
    return _PressButton(
      shadowY: 5 * s,
      onTap: onTap,
      builder: (pressed) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: onTap == null ? color.withValues(alpha: 0.5) : color,
          boxShadow: [
            BoxShadow(color: colorDk, offset: Offset(0, (pressed ? 1 : 5) * s)),
          ],
        ),
        child: child,
      ),
    );
  }

  Widget _tag(double s, String text, Color bg, Color shadow, double fontSize) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12 * s, vertical: 3 * s),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [BoxShadow(color: shadow, offset: Offset(0, 3 * s))],
      ),
      child: Text(text,
          style: TextStyle(
              fontFamily: 'Fredoka',
              fontWeight: FontWeight.w600,
              fontSize: fontSize,
              color: Colors.white)),
    );
  }

  // ---- progress bar -----------------------------------------------------
  Widget _progress(double s, int n) {
    final frac = n == 0 ? 0.0 : _placed.length / n;
    final pct = math.max(0.06, frac);
    return Positioned(
      bottom: 26 * s,
      left: 22 * s,
      right: 22 * s,
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 24 * s,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.centerLeft,
                children: [
                  Container(
                    height: 16 * s,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8DCC2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: pct,
                    child: Container(
                      height: 16 * s,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFF8FD14F), _green]),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment(pct * 2 - 1, 0),
                    child: _StarBox(size: 24 * s, gold: true),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 12 * s),
          Text('${_levelIndex + 1}/${widget.levels.length}',
              style: TextStyle(
                  fontFamily: 'Fredoka',
                  fontWeight: FontWeight.w700,
                  fontSize: 20 * s,
                  color: _ink,
                  shadows: [Shadow(color: Colors.white, offset: Offset(0, 1 * s))])),
        ],
      ),
    );
  }

  // ---- mascot + hint bubble --------------------------------------------
  List<Widget> _mascotHint(double s) {
    return [
      Positioned(
        left: -5 * s,
        top: 528 * s,
        width: 240 * s,
        child: IgnorePointer(
          child: Transform.rotate(
            angle: -14 * math.pi / 180,
            alignment: const Alignment(0.6, 0.8),
            child: Image.asset('assets/images/ayah_builder/mascot_point.png'),
          ),
        ),
      ),
      Positioned(
        left: 62 * s,
        top: 516 * s,
        child: IgnorePointer(
          child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 8 * s),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16 * s),
            boxShadow: [
              BoxShadow(color: const Color(0x1F000000), offset: Offset(0, 4 * s)),
            ],
          ),
            child: Text('Click here for a hint!',
                style: TextStyle(
                    fontFamily: 'Fredoka',
                    fontWeight: FontWeight.w600,
                    fontSize: 13 * s,
                    color: _ink)),
          ),
        ),
      ),
    ];
  }

  // ---- reward overlay ---------------------------------------------------
  Widget _rewardOverlay(double s) {
    final last = _levelIndex + 1 >= widget.levels.length;
    return Positioned.fill(
      child: Container(
        color: const Color(0x80281432),
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _ambient,
                builder: (context, _) =>
                    CustomPaint(painter: _ConfettiPainter(_ambient.value, s)),
              ),
            ),
            Center(
              child: ScaleTransition(
                scale: CurvedAnimation(
                    parent: _reward, curve: Curves.easeOutBack),
                child: FractionallySizedBox(
                  widthFactor: 0.82,
                  child: Container(
                    padding: EdgeInsets.fromLTRB(22 * s, 26 * s, 22 * s, 24 * s),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.white, Color(0xFFFFF4DC)],
                      ),
                      borderRadius: BorderRadius.circular(26 * s),
                      boxShadow: [
                        BoxShadow(
                            color: const Color(0x66000000),
                            blurRadius: 50 * s,
                            offset: Offset(0, 16 * s)),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Transform.translate(
                          offset: Offset(0, -80 * s),
                          child: Image.asset(
                              'assets/images/ayah_builder/mascot_cheer.png',
                              width: 150 * s),
                        ),
                        Transform.translate(
                          offset: Offset(0, -60 * s),
                          child: _rewardBody(s, last),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rewardBody(double s, bool last) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (i) {
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 5 * s),
              child: AnimatedBuilder(
                animation: _reward,
                builder: (context, _) {
                  final t = Curves.easeOutBack.transform(
                      ((_reward.value - i * 0.15) / 0.5).clamp(0.0, 1.0));
                  return Transform.scale(
                    scale: t,
                    child: _StarBox(size: 46 * s, gold: i < _earned),
                  );
                },
              ),
            );
          }),
        ),
        SizedBox(height: 14 * s),
        Text("Mā shā' Allāh!",
            style: TextStyle(
                fontFamily: 'Fredoka',
                fontWeight: FontWeight.w700,
                fontSize: 28 * s,
                color: _titleGreen)),
        SizedBox(height: 4 * s),
        Text('You built the Ayah correctly!',
            style: TextStyle(
                fontFamily: 'Fredoka',
                fontWeight: FontWeight.w600,
                fontSize: 15 * s,
                color: const Color(0xFF7A6A53))),
        SizedBox(height: 16 * s),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(14 * s),
          decoration: BoxDecoration(
            color: const Color(0xFFF3EAD4),
            borderRadius: BorderRadius.circular(16 * s),
          ),
          child: Column(
            children: [
              Directionality(
                textDirection: TextDirection.rtl,
                child: Text(_level.arabicWords.join(' '),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.w700,
                        fontSize: 22 * s,
                        height: 1.7,
                        color: _ink)),
              ),
              SizedBox(height: 6 * s),
              Text(_level.translitWords.join(' '),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: 'Fredoka',
                      fontStyle: FontStyle.italic,
                      fontSize: 13 * s,
                      color: const Color(0xFF9A8A72))),
              Container(
                width: 40 * s,
                height: 2,
                margin: EdgeInsets.symmetric(vertical: 10 * s),
                color: const Color(0xFFD8C8A6),
              ),
              Text(_level.englishMeaning,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: 'Fredoka',
                      fontSize: 14 * s,
                      color: const Color(0xFF6B563F))),
            ],
          ),
        ),
        SizedBox(height: 18 * s),
        SizedBox(
          width: double.infinity,
          child: GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _next();
            },
            child: Container(
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(vertical: 13 * s),
              decoration: BoxDecoration(
                color: _green,
                borderRadius: BorderRadius.circular(16 * s),
                boxShadow: [BoxShadow(color: _greenDk, offset: Offset(0, 5 * s))],
              ),
              child: Text(last ? 'Finish' : 'Next Ayah →',
                  style: TextStyle(
                      fontFamily: 'Fredoka',
                      fontWeight: FontWeight.w700,
                      fontSize: 18 * s,
                      color: Colors.white)),
            ),
          ),
        ),
      ],
    );
  }
}

// =====================================================================
// Reusable painters / small widgets
// =====================================================================

/// A tactile button that drops down onto its bevel shadow while held,
/// mirroring the prototype's `:active` press feedback. Disabled when
/// [onTap] is null.
class _PressButton extends StatefulWidget {
  const _PressButton({
    required this.builder,
    required this.onTap,
    required this.shadowY,
  });

  final Widget Function(bool pressed) builder;
  final VoidCallback? onTap;
  final double shadowY;

  @override
  State<_PressButton> createState() => _PressButtonState();
}

class _PressButtonState extends State<_PressButton> {
  bool _pressed = false;

  void _set(bool v) {
    if (widget.onTap == null || _pressed == v) return;
    setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap == null
          ? null
          : () {
              HapticFeedback.lightImpact();
              widget.onTap!();
            },
      child: Transform.translate(
        // drop by the bevel height minus the 1px pressed shadow, so the
        // button visually sinks onto its shadow.
        offset: Offset(0, _pressed ? widget.shadowY - 1 : 0),
        child: widget.builder(_pressed),
      ),
    );
  }
}

/// A colored draggable word card matching the prototype's rounded pill.
class _WordCard extends StatelessWidget {
  const _WordCard({
    required this.s,
    required this.arabic,
    required this.translit,
    required this.color,
    required this.colorDk,
  });

  final double s;
  final String arabic;
  final String? translit;
  final Color color;
  final Color colorDk;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minWidth: 76 * s, minHeight: 56 * s),
      padding: EdgeInsets.symmetric(horizontal: 16 * s, vertical: 8 * s),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16 * s),
        boxShadow: [BoxShadow(color: colorDk, offset: Offset(0, 5 * s))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(arabic,
              style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.w700,
                  fontSize: 24 * s,
                  color: Colors.white,
                  shadows: const [
                    Shadow(color: Color(0x40000000), offset: Offset(0, 1))
                  ])),
          if (translit != null)
            Text(translit!,
                style: TextStyle(
                    fontFamily: 'Fredoka',
                    fontSize: 11 * s,
                    color: Colors.white.withValues(alpha: 0.92))),
        ],
      ),
    );
  }
}

/// The 10-point star used for the counter, progress knob, and reward stars.
class _StarBox extends StatelessWidget {
  const _StarBox({required this.size, required this.gold});
  final double size;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _StarPainter(gold)),
    );
  }
}

class _StarPainter extends CustomPainter {
  _StarPainter(this.gold);
  final bool gold;

  static const _pts = [
    Offset(.50, 0),
    Offset(.61, .35),
    Offset(.98, .35),
    Offset(.68, .57),
    Offset(.79, .91),
    Offset(.50, .70),
    Offset(.21, .91),
    Offset(.32, .57),
    Offset(.02, .35),
    Offset(.39, .35),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    for (var i = 0; i < _pts.length; i++) {
      final p = Offset(_pts[i].dx * size.width, _pts[i].dy * size.height);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    final color = gold ? const Color(0xFFFFC73A) : const Color(0xFFD9CBB0);
    if (gold) {
      canvas.drawShadow(path, const Color(0xFFFFC73A), 4, false);
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_StarPainter old) => old.gold != gold;
}

/// Triangle bunting flags across the top of the board.
class _BuntingPainter extends CustomPainter {
  _BuntingPainter(this.s);
  final double s;
  static const _colors = _AyahBuilderActivityState._buntingColors;

  @override
  void paint(Canvas canvas, Size size) {
    const count = 11;
    final w = 26 * s;
    final h = 30 * s;
    final gap = (size.width - w) / (count - 1);
    for (var i = 0; i < count; i++) {
      final x = i * gap;
      final path = Path()
        ..moveTo(x, 0)
        ..lineTo(x + w, 0)
        ..lineTo(x + w / 2, h)
        ..close();
      canvas.drawPath(path, Paint()..color = _colors[i % _colors.length]);
    }
  }

  @override
  bool shouldRepaint(_BuntingPainter old) => false;
}

/// Dashed rounded-rect border for empty slots.
class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter(
      {required this.color, required this.radius, required this.gap});
  final Color color;
  final double radius;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
        Offset.zero & size, Radius.circular(radius));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var dist = 0.0;
      while (dist < metric.length) {
        canvas.drawPath(
            metric.extractPath(dist, dist + gap), paint);
        dist += gap * 2;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter old) => false;
}

/// Falling confetti shown behind the reward card.
class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t, this.s);
  final double t;
  final double s;

  static final _rnd = math.Random(7);
  static const _colors = [
    Color(0xFF7C5CE0),
    Color(0xFF39B54A),
    Color(0xFF2F9BE0),
    Color(0xFFF5A524),
    Color(0xFFE0577C),
    Color(0xFFFFC73A),
  ];
  static final _bits = List.generate(40, (_) {
    return (
      x: _rnd.nextDouble(),
      size: 6 + _rnd.nextDouble() * 6,
      color: _colors[_rnd.nextInt(_colors.length)],
      phase: _rnd.nextDouble(),
      round: _rnd.nextBool(),
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final b in _bits) {
      final prog = (t + b.phase) % 1;
      final y = prog * (size.height + 40) - 20;
      final x = b.x * size.width;
      final sz = b.size * s;
      final paint = Paint()..color = b.color;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(prog * math.pi * 4);
      final rect = Rect.fromCenter(
          center: Offset.zero, width: sz, height: sz * 0.8);
      if (b.round) {
        canvas.drawOval(rect, paint);
      } else {
        canvas.drawRRect(
            RRect.fromRectAndRadius(rect, Radius.circular(2 * s)), paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
