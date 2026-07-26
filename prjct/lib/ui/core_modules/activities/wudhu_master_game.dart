import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';

import '../../../data/models/curriculum/curriculum_models.dart';

/// FR-4.5.5 / FR-4.5.6 — Wudhu Master.
///
/// Full-bleed 10-step ordering game. Layout, palette, copy and motion mirror
/// the supplied "Wudhu Master" design comp 1:1 (400x853 reference frame).
class WudhuMasterGame extends StatefulWidget {
  const WudhuMasterGame({
    super.key,
    required this.items,
    required this.xp,
    required this.onComplete,
    this.onExit,
  });

  final List<FiqhDragItem> items;
  final int xp;
  final void Function(int xp, double accuracyPct, int errors) onComplete;

  /// Leaves the lesson. The comp's `‹` chip is the only exit, so it maps
  /// straight onto this instead of the comp's intro-screen bounce.
  final VoidCallback? onExit;

  @override
  State<WudhuMasterGame> createState() => _WudhuMasterGameState();
}

// ---------------------------------------------------------------------------
// Palette lifted verbatim from the comp.
// ---------------------------------------------------------------------------
class _C {
  static const teal = Color(0xFF2FD0D8);
  static const tealDeep = Color(0xFF12A3AE);
  static const tealText = Color(0xFF0F7D8C);
  static const slate = Color(0xFF0F5F74);
  static const navy = Color(0xFF0E3A5C);
  static const navyMid = Color(0xFF103E64);
  static const blue = Color(0xFF1F74B4);
  static const blueInk = Color(0xFF1C6AA8);
  static const gold = Color(0xFFFFD75E);
  static const goldSoft = Color(0xFFFFE08A);
  static const skyLabel = Color(0xFF8FD4FF);
  static const green = Color(0xFF3FE07A);
  static const greenDeep = Color(0xFF1FAE57);
  static const greenLine = Color(0xFF2AD17A);
  static const red = Color(0xFFFF5B5B);
  static const redSoft = Color(0xFFFF8080);
  static const redLine = Color(0xFFFF6B6B);
  static const orange = Color(0xFFFF9F43);
  static const amber = Color(0xFFFFB64D);
  static const amberDeep = Color(0xFFF7902A);
  static const cardLine = Color(0xFFBDE9F1);
  static const dropLine = Color(0xFFBCDCEA);
  static const dropText = Color(0xFF8FBDD0);
  static const paleIce = Color(0xFFEEF9FD);
  static const hatchA = Color(0xFFEAF6FB);
  static const hatchB = Color(0xFFDCEEF6);
  static const hatchLine = Color(0xFFA9CFE0);
  static const artText = Color(0xFF7FA8C4);
  static const iceTop = Color(0xFFEAFCFF);
  static const iceBottom = Color(0xFFD3F4FB);
  static const winBorder = Color(0xFFFFCE4A);
  static const winSub = Color(0xFF2B7D8C);
  static const introBody = Color(0xFF2B6B7D);
  static const introFoot = Color(0xFF6B93A3);
  static const tipLine = Color(0xFFD6F2F8);
  static const boardTop = Color(0xFF22C3CF);
  static const boardBottom = Color(0xFF149AA8);
  static const checkOffA = Color(0xFF9FD6DD);
  static const checkOffB = Color(0xFF7FBFC7);
}

const _kFredoka = 'Fredoka';
const _kBaloo = 'Baloo2';
const _kAssets = 'assets/images/wudhu';

class _WudhuMasterGameState extends State<WudhuMasterGame>
    with TickerProviderStateMixin {
  static const _slotCount = 10;

  bool _started = false;
  late List<int> _order;
  final List<int?> _slots = List<int?>.filled(_slotCount, null);
  int? _selected;
  bool _checked = false;
  int _pulse = 0;
  int _failedChecks = 0;

  late final AnimationController _chrome = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 620),
  );

  @override
  void initState() {
    super.initState();
    _order = _shuffle();
  }

  @override
  void dispose() {
    _chrome.dispose();
    super.dispose();
  }

  List<int> _shuffle() {
    final a = List<int>.generate(_slotCount, (i) => i + 1);
    a.shuffle(math.Random());
    return a;
  }

  /// Step id (1-based) for an item, taken from its `correctZoneId`.
  int _stepId(FiqhDragItem item) => int.tryParse(item.correctZoneId) ?? 0;

  FiqhDragItem? _itemFor(int stepId) {
    for (final i in widget.items) {
      if (_stepId(i) == stepId) return i;
    }
    return null;
  }

  int get _numCorrect {
    var n = 0;
    for (var i = 0; i < _slotCount; i++) {
      if (_slots[i] == i + 1) n++;
    }
    return n;
  }

  int get _numPlaced => _slots.where((s) => s != null).length;
  bool get _allFilled => _numPlaced == _slotCount;
  bool get _won => _checked && _numCorrect == _slotCount;

  void _place(int slotNumber, int stepId) {
    setState(() {
      final prev = _slots.indexOf(stepId);
      if (prev > -1) _slots[prev] = null;
      _slots[slotNumber - 1] = stepId;
      _selected = null;
      _checked = false;
    });
  }

  void _removeSlot(int slotNumber) {
    setState(() {
      _slots[slotNumber - 1] = null;
      _selected = null;
      _checked = false;
    });
  }

  void _tapSlot(int slotNumber) {
    if (_selected != null) {
      _place(slotNumber, _selected!);
    } else if (_slots[slotNumber - 1] != null) {
      _removeSlot(slotNumber);
    }
  }

  void _checkNow() {
    if (!_allFilled) return;
    setState(() {
      _checked = true;
      _selected = null;
      if (_numCorrect < _slotCount) _failedChecks++;
    });
  }

  /// Clears every slot that is *not* already in its correct place.
  void _retryWrong() {
    setState(() {
      for (var i = 0; i < _slotCount; i++) {
        if (_slots[i] != i + 1) _slots[i] = null;
      }
      _selected = null;
      _checked = false;
      _pulse++;
    });
  }

  void _resetAll() {
    setState(() {
      for (var i = 0; i < _slotCount; i++) {
        _slots[i] = null;
      }
      _selected = null;
      _checked = false;
      _pulse++;
    });
  }

  void _startGame() {
    setState(() => _started = true);
    _chrome.forward(from: 0);
  }

  void _finish() {
    final attempts = _failedChecks + 1;
    widget.onComplete(widget.xp, 100.0 / attempts, _failedChecks);
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('$_kAssets/bg.png'),
          fit: BoxFit.cover,
        ),
        color: _C.navy,
      ),
      child: _started
          ? _buildGame(context)
          : _WudhuIntro(onStart: _startGame, onExit: widget.onExit),
    );
  }

  Widget _buildGame(BuildContext context) {
    final trayIds = _order.where((id) => !_slots.contains(id)).toList();
    final trayEmpty = trayIds.isEmpty;

    return Stack(
      children: [
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
            child: Column(
              children: [
                _Entrance(
                  controller: _chrome,
                  begin: 0.0,
                  from: const Offset(0, -18),
                  child: _buildHud(),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: _Entrance(
                    controller: _chrome,
                    begin: 0.13,
                    from: const Offset(0, 16),
                    scaleFrom: 0.97,
                    child: _buildBoard(),
                  ),
                ),
                const SizedBox(height: 22),
                _Entrance(
                  controller: _chrome,
                  begin: 0.26,
                  from: const Offset(0, 22),
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeOut,
                    alignment: Alignment.bottomCenter,
                    child: trayEmpty
                        ? const SizedBox(width: double.infinity)
                        : _buildTray(trayIds),
                  ),
                ),
                const SizedBox(height: 6),
                _Entrance(
                  controller: _chrome,
                  begin: 0.38,
                  from: const Offset(0, 22),
                  child: _buildCheckRow(),
                ),
              ],
            ),
          ),
        ),
        if (_won) _buildWinOverlay(),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // HUD
  // -------------------------------------------------------------------------
  Widget _buildHud() {
    final shown = _checked ? _numCorrect : _numPlaced;
    return Row(
      children: [
        GestureDetector(
          onTap: widget.onExit ?? () => setState(() => _started = false),
          child: _Press(
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_C.teal, _C.tealDeep],
                ),
                shape: BoxShape.circle,
                border: Border.all(color: _C.iceTop, width: 3),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66005060),
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Text(
                '‹',
                style: TextStyle(
                  fontSize: 22,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_C.blue, _C.navyMid],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _C.gold, width: 2.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x660A3250),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'LEARN & PLAY',
                  style: TextStyle(
                    fontFamily: _kFredoka,
                    fontWeight: FontWeight.w600,
                    fontSize: 9,
                    letterSpacing: 5,
                    color: _C.skyLabel,
                  ),
                ),
                const SizedBox(height: 1),
                const _StrokedText(
                  'WUDHU MASTER',
                  fontSize: 24,
                  strokeWidth: 2.5,
                  strokeColor: _C.navy,
                  fillColor: _C.goldSoft,
                  letterSpacing: 0.5,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 52,
          height: 52,
          child: CustomPaint(
            painter: _ProgressRingPainter(shown / _slotCount),
            child: Center(
              child: Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF12354F), _C.blueInk],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$shown/$_slotCount',
                      style: const TextStyle(
                        fontFamily: _kBaloo,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        height: 1,
                        color: Colors.white,
                      ),
                    ),
                    const Text(
                      'DONE',
                      style: TextStyle(
                        fontFamily: _kFredoka,
                        fontSize: 7,
                        letterSpacing: 1,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Answer board
  // -------------------------------------------------------------------------
  Widget _buildBoard() {
    final anyPlaced = _numPlaced > 0;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.90),
            const Color(0xFFE0F7FC).withValues(alpha: 0.86),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x52083C55),
            blurRadius: 26,
            offset: Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_C.boardTop, _C.boardBottom],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(19)),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '💧 Put the 10 steps in the right order',
                    style: TextStyle(
                      fontFamily: _kFredoka,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      letterSpacing: 0.3,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (anyPlaced)
                  GestureDetector(
                    onTap: _resetAll,
                    child: _Press(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.75),
                            width: 1.5,
                          ),
                        ),
                        child: const Text(
                          '↺ Reset all',
                          style: TextStyle(
                            fontFamily: _kFredoka,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            // Ten rows, each stretched to fill an equal share of the board
            // so the list always occupies the full height instead of
            // leaving empty space below row 10 on tall screens.
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                spacing: 7,
                children: [
                  for (var i = 0; i < _slotCount; i++)
                    Expanded(child: _buildSlotRow(i)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotRow(int i) {
    final n = i + 1;
    final stepId = _slots[i];
    final filled = stepId != null;
    final isRight = stepId == n;
    final showRight = _checked && isRight;
    final showWrong = _checked && filled && !isRight;

    final badgeColors = showRight
        ? const [_C.green, _C.greenDeep]
        : showWrong
        ? const [_C.redSoft, _C.red]
        : const [_C.teal, _C.tealDeep];

    return DragTarget<int>(
      key: ValueKey('wudhuSlot$i'),
      onAcceptWithDetails: (d) => _place(n, d.data),
      builder: (context, candidate, rejected) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _tapSlot(n),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: badgeColors,
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(color: Color(0x4D005060), offset: Offset(0, 3)),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$n',
                    style: const TextStyle(
                      fontFamily: _kFredoka,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      height: 1,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: filled
                    ? _buildFilledCard(stepId, showRight, showWrong)
                    : _buildEmptyDrop(candidate.isNotEmpty),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilledCard(int stepId, bool showRight, bool showWrong) {
    final border = showRight
        ? _C.greenLine
        : showWrong
        ? _C.redLine
        : _C.cardLine;
    final bg = showRight
        ? const Color(0xFFF0FFF7)
        : showWrong
        ? const Color(0xFFFFF2F2)
        : Colors.white;

    final card = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: border, width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0x26146E82), offset: Offset(0, 3)),
        ],
      ),
      alignment: Alignment.center,
      child: Row(
        children: [
          _StepArt(stepId: stepId, size: 52, radius: 10),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              _labelFor(stepId),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: _kFredoka,
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: 0.3,
                color: _C.slate,
              ),
            ),
          ),
          if (showRight)
            const Text(
              '✓',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: _C.greenDeep,
              ),
            ),
          if (showWrong)
            const Text(
              '✗',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: _C.red,
              ),
            ),
        ],
      ),
    );

    return Draggable<int>(
      data: stepId,
      // The board scrolls vertically, so a vertical swipe must reach the
      // scroll view — only a sideways pull starts a drag.
      affinity: Axis.horizontal,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(width: 240, child: card),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: card),
      child: card,
    );
  }

  Widget _buildEmptyDrop(bool hovering) {
    final active = _selected != null || hovering;
    return CustomPaint(
      painter: _DashedRRectPainter(
        color: active ? _C.teal : _C.dropLine,
        radius: 13,
        strokeWidth: 2,
        fill: active
            ? _C.teal.withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: 0.4),
      ),
      child: const SizedBox.expand(
        child: Center(
          child: Text(
            'drop step here',
            style: TextStyle(
              fontFamily: _kFredoka,
              fontSize: 11,
              color: _C.dropText,
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Card tray
  // -------------------------------------------------------------------------
  Widget _buildTray(List<int> trayIds) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.92),
            const Color(0xFFD6FBFF).withValues(alpha: 0.88),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x4D083C55),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'TAP A STEP, THEN TAP A NUMBER — OR DRAG IT',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: _kFredoka,
              fontWeight: FontWeight.w600,
              fontSize: 10,
              letterSpacing: 1,
              color: _C.tealText,
            ),
          ),
          const SizedBox(height: 7),
          SizedBox(
            height: 122,
            child: _ShuffleNudge(
              trigger: _pulse,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  spacing: 8,
                  children: [
                    for (final id in trayIds) _buildTrayCard(id),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrayCard(int stepId) {
    final selected = _selected == stepId;
    final card = Container(
      width: 98,
      height: 118,
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? _C.orange : _C.cardLine,
          width: 2,
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x29146E82), offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _StepArt(stepId: stepId, size: 72, radius: 12),
          const SizedBox(height: 5),
          Flexible(
            child: Text(
              _labelFor(stepId),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: _kFredoka,
                fontWeight: FontWeight.w700,
                fontSize: 11,
                height: 1.05,
                color: _C.slate,
              ),
            ),
          ),
        ],
      ),
    );

    return AnimatedContainer(
      key: ValueKey('wudhuTrayCard$stepId'),
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      transform: selected
          ? (Matrix4.identity()
              ..translateByDouble(-2.5, -4.0, 0.0, 1.0)
              ..scaleByDouble(1.05, 1.05, 1.0, 1.0))
          : Matrix4.identity(),
      child: Draggable<int>(
        data: stepId,
        // The tray scrolls horizontally, so a sideways swipe must reach the
        // scroll view — only an upward pull starts a drag.
        affinity: Axis.vertical,
        feedback: Material(color: Colors.transparent, child: card),
        childWhenDragging: Opacity(opacity: 0.3, child: card),
        child: GestureDetector(
          onTap: () => setState(
            () => _selected = _selected == stepId ? null : stepId,
          ),
          child: card,
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Check / retry
  // -------------------------------------------------------------------------
  Widget _buildCheckRow() {
    final correct = _numCorrect;
    final showRetry = _checked && correct < _slotCount;
    final label = showRetry
        ? 'Great — $correct/$_slotCount correct!'
        : _allFilled
        ? '✓ Check my answer'
        : 'Fill every slot to check';

    return Row(
      children: [
        if (showRetry) ...[
          GestureDetector(
            onTap: _retryWrong,
            child: _Press(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_C.amber, _C.amberDeep],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const [
                    BoxShadow(color: Color(0x598C4600), offset: Offset(0, 6)),
                  ],
                ),
                child: const Text(
                  '↺ Retry',
                  style: TextStyle(
                    fontFamily: _kFredoka,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 9),
        ],
        Expanded(
          child: Opacity(
            opacity: _allFilled ? 1 : 0.8,
            child: GestureDetector(
              onTap: _checkNow,
              child: _Press(
                enabled: _allFilled,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: _allFilled
                          ? const [_C.green, _C.greenDeep]
                          : const [_C.checkOffA, _C.checkOffB],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: const [
                      BoxShadow(color: Color(0x59005060), offset: Offset(0, 6)),
                    ],
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: _kFredoka,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      letterSpacing: 0.5,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Win overlay
  // -------------------------------------------------------------------------
  Widget _buildWinOverlay() {
    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0x94082846),
        child: Center(
          child: _Pop(
            child: FractionallySizedBox(
              widthFactor: 0.76,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 26,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_C.iceTop, _C.iceBottom],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _C.winBorder, width: 4),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66000000),
                      blurRadius: 34,
                      offset: Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🌟', style: TextStyle(fontSize: 44)),
                    const Text(
                      "MASHA'ALLAH!",
                      style: TextStyle(
                        fontFamily: _kBaloo,
                        fontWeight: FontWeight.w800,
                        fontSize: 28,
                        color: _C.blueInk,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'You put every step of Wudhu in the right order!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: _kFredoka,
                        fontSize: 13,
                        color: _C.winSub,
                      ),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: _finish,
                      child: _Press(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [_C.teal, _C.tealDeep],
                            ),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x59005060),
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Text(
                            'Collect ${widget.xp} XP',
                            style: const TextStyle(
                              fontFamily: _kFredoka,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _labelFor(int stepId) =>
      _itemFor(stepId)?.label.toUpperCase() ?? 'STEP $stepId';
}

// ===========================================================================
// Intro screen
// ===========================================================================
class _WudhuIntro extends StatelessWidget {
  const _WudhuIntro({required this.onStart, this.onExit});
  final VoidCallback onStart;
  final VoidCallback? onExit;

  @override
  Widget build(BuildContext context) {
    final intro = _buildIntro(context);
    if (onExit == null) return intro;
    return Stack(
      children: [
        Positioned.fill(child: intro),
        Positioned(
          left: 14,
          top: MediaQuery.of(context).padding.top + 16,
          child: GestureDetector(
            onTap: onExit,
            child: _Press(
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_C.teal, _C.tealDeep],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: _C.iceTop, width: 3),
                  boxShadow: const [
                    BoxShadow(color: Color(0x66005060), offset: Offset(0, 4)),
                  ],
                ),
                alignment: Alignment.center,
                child: const Text(
                  '‹',
                  style: TextStyle(
                    fontSize: 22,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIntro(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x590A2D4B), Color(0x8C0A2D4B)],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(26, 96, 26, 26),
          child: Center(
            child: _Pop(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.topCenter,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 88),
                      padding: const EdgeInsets.fromLTRB(22, 64, 22, 26),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withValues(alpha: 0.95),
                            const Color(0xFFE0F7FC).withValues(alpha: 0.92),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x73083250),
                            blurRadius: 40,
                            offset: Offset(0, 16),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            "LET'S LEARN",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: _kFredoka,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              letterSpacing: 3,
                              color: _C.tealText,
                            ),
                          ),
                          const Center(
                            child: _StrokedText(
                              'WUDHU MASTER',
                              fontSize: 38,
                              strokeWidth: 3,
                              strokeColor: _C.blueInk,
                              fillColor: _C.gold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Wudhu is how we wash before we pray. '
                            'Can you put the 10 steps in the correct order?',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: _kFredoka,
                              fontSize: 13,
                              height: 1.5,
                              color: _C.introBody,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const _Tip(
                            emoji: '👆',
                            text: 'Tap a step, then tap a number — '
                                'or drag it in.',
                            delayMs: 150,
                          ),
                          const SizedBox(height: 8),
                          const _Tip(
                            emoji: '✅',
                            text: 'Hit Check to see your ✓ and ✗.',
                            delayMs: 280,
                          ),
                          const SizedBox(height: 8),
                          const _Tip(
                            emoji: '🌟',
                            text: 'Get all 10 right to become a Wudhu Master!',
                            delayMs: 410,
                          ),
                          const SizedBox(height: 20),
                          GestureDetector(
                            onTap: onStart,
                            child: _Press(
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [_C.green, _C.greenDeep],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x5900503C),
                                      offset: Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: const Text(
                                  '▶  START',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontFamily: _kBaloo,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 19,
                                    letterSpacing: 0.5,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Remember to say “Bismillah” before you begin 🤍',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: _kFredoka,
                              fontSize: 10,
                              color: _C.introFoot,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Image.asset(
                      '$_kAssets/mascot.png',
                      width: 190,
                      height: 190,
                      errorBuilder: (_, _, _) => const SizedBox(height: 190),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip({required this.emoji, required this.text, required this.delayMs});
  final String emoji;
  final String text;
  final int delayMs;

  @override
  Widget build(BuildContext context) {
    return _Delayed(
      delayMs: delayMs,
      from: const Offset(14, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _C.tipLine, width: 2),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontFamily: _kFredoka,
                  fontSize: 11.5,
                  color: _C.slate,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Step artwork — steps 1-9 ship illustrations, step 10 is still a placeholder
// in the source comp (`img: null`), so it keeps the hatched "art" swatch.
// ===========================================================================
class _StepArt extends StatelessWidget {
  const _StepArt({
    required this.stepId,
    required this.size,
    required this.radius,
  });
  final int stepId;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    if (stepId < 1 || stepId > 9) return _placeholder();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _C.paleIce,
        borderRadius: BorderRadius.circular(radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        '$_kAssets/step$stepId.png',
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => _placeholder(),
      ),
    );
  }

  Widget _placeholder() => CustomPaint(
    painter: _HatchPainter(radius: radius),
    child: SizedBox(
      width: size,
      height: size,
      child: const Center(
        child: Text(
          'art',
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 9,
            color: _C.artText,
          ),
        ),
      ),
    ),
  );
}

// ===========================================================================
// Painters
// ===========================================================================
class _ProgressRingPainter extends CustomPainter {
  _ProgressRingPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = size.width / 2;
    final track = Paint()
      ..color = Colors.white.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius - 1.5, track);
    if (progress <= 0) return;
    final arc = Paint()
      ..color = _C.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 1.5),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_ProgressRingPainter old) => old.progress != progress;
}

class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
    required this.fill,
  });
  final Color color;
  final double radius;
  final double strokeWidth;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    canvas.drawRRect(rrect, Paint()..color = fill);

    final path = Path()..addRRect(rrect.deflate(strokeWidth / 2));
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    const dash = 6.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(
          metric.extractPath(d, math.min(d + dash, metric.length)),
          stroke,
        );
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter old) =>
      old.color != color || old.fill != fill;
}

class _HatchPainter extends CustomPainter {
  _HatchPainter({required this.radius});
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(Offset.zero & size, Paint()..color = _C.hatchA);
    final stripe = Paint()
      ..color = _C.hatchB
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    for (var x = -size.height; x < size.width + size.height; x += 8) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height),
          stripe);
    }
    canvas.restore();
    canvas.drawRRect(
      rrect.deflate(0.5),
      Paint()
        ..color = _C.hatchLine
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_HatchPainter old) => false;
}

// ===========================================================================
// Motion helpers — Flutter equivalents of the comp's CSS keyframes
// ===========================================================================

/// `.press` — sinks 3px and shrinks slightly while held.
class _Press extends StatefulWidget {
  const _Press({required this.child, this.enabled = true});
  final Widget child;
  final bool enabled;
  @override
  State<_Press> createState() => _PressState();
}

class _PressState extends State<_Press> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) {
        if (widget.enabled) setState(() => _down = true);
      },
      onPointerUp: (_) => setState(() => _down = false),
      onPointerCancel: (_) => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.98 : 1,
        duration: const Duration(milliseconds: 120),
        child: AnimatedSlide(
          offset: _down ? const Offset(0, 0.04) : Offset.zero,
          duration: const Duration(milliseconds: 120),
          child: widget.child,
        ),
      ),
    );
  }
}

/// `@keyframes pop` — scale-in with a slight overshoot.
class _Pop extends StatelessWidget {
  const _Pop({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: const Cubic(0.34, 1.56, 0.64, 1.0),
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.6 + 0.4 * t, child: child),
      ),
      child: child,
    );
  }
}

/// Staggered slide+fade driven by a shared controller (`dropDown`, `boardIn`,
/// `riseUp`).
class _Entrance extends StatelessWidget {
  const _Entrance({
    required this.controller,
    required this.begin,
    required this.from,
    required this.child,
    this.scaleFrom = 1.0,
  });
  final AnimationController controller;
  final double begin;
  final Offset from;
  final double scaleFrom;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final anim = CurvedAnimation(
      parent: controller,
      curve: Interval(begin, 1, curve: Curves.easeOut),
    );
    return AnimatedBuilder(
      animation: anim,
      builder: (context, child) {
        final t = anim.value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: from * (1 - t),
            child: Transform.scale(
              scale: scaleFrom + (1 - scaleFrom) * t,
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

/// `@keyframes tipIn` — delayed slide-in used by the intro tip rows.
class _Delayed extends StatefulWidget {
  const _Delayed({
    required this.delayMs,
    required this.from,
    required this.child,
  });
  final int delayMs;
  final Offset from;
  final Widget child;
  @override
  State<_Delayed> createState() => _DelayedState();
}

class _DelayedState extends State<_Delayed> {
  double _t = 0;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) setState(() => _t = 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _t,
      duration: const Duration(milliseconds: 400),
      child: AnimatedSlide(
        offset: _t == 0 ? const Offset(0.06, 0) : Offset.zero,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// `@keyframes shuffleA/B` — the tray bobs once whenever cards are returned.
class _ShuffleNudge extends StatefulWidget {
  const _ShuffleNudge({required this.trigger, required this.child});
  final int trigger;
  final Widget child;
  @override
  State<_ShuffleNudge> createState() => _ShuffleNudgeState();
}

class _ShuffleNudgeState extends State<_ShuffleNudge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void didUpdateWidget(_ShuffleNudge old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value;
        final dy = t == 0
            ? 0.0
            : t < 0.35
            ? 7 * (t / 0.35)
            : t < 0.7
            ? 7 - 9 * ((t - 0.35) / 0.35)
            : -2 + 2 * ((t - 0.7) / 0.3);
        return Transform.translate(offset: Offset(0, dy), child: child);
      },
      child: widget.child,
    );
  }
}

// ===========================================================================
// Stroked display type (`-webkit-text-stroke` + `paint-order: stroke fill`)
// ===========================================================================
class _StrokedText extends StatelessWidget {
  const _StrokedText(
    this.text, {
    required this.fontSize,
    required this.strokeWidth,
    required this.strokeColor,
    required this.fillColor,
    this.letterSpacing = 0,
  });
  final String text;
  final double fontSize;
  final double strokeWidth;
  final Color strokeColor;
  final Color fillColor;
  final double letterSpacing;

  @override
  Widget build(BuildContext context) {
    TextStyle base(Paint? fg, Color? color) => TextStyle(
      fontFamily: _kBaloo,
      fontWeight: FontWeight.w800,
      fontSize: fontSize,
      height: 1,
      letterSpacing: letterSpacing,
      foreground: fg,
      color: color,
    );
    return Stack(
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: base(
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..strokeJoin = StrokeJoin.round
              ..color = strokeColor,
            null,
          ),
        ),
        Text(text, textAlign: TextAlign.center, style: base(null, fillColor)),
      ],
    );
  }
}
