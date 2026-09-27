import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:flutter/services.dart';
import 'package:salamlearn/logic/localization/app_translations.dart';

import '../../../data/models/curriculum/curriculum_models.dart';
import 'fiqh_drag_activity.dart';

const _kA = 'assets/images/label_maker';

/// Label Maker — landscape start screen laid out in the reference comp's
/// 1870x841 pixel space over the painted living room. Play hands off to the
/// existing drag-to-label activity until the new game screens land.
class LabelMakerGame extends StatefulWidget {
  const LabelMakerGame({
    super.key,
    required this.activityId,
    required this.items,
    required this.zones,
    required this.xp,
    required this.color,
    required this.onComplete,
    this.onExit,
  });

  final String activityId;
  final List<FiqhDragItem> items;
  final List<FiqhDropZone> zones;
  final int xp;
  final Color color;
  final void Function(int xp, double accuracyPct, int errors) onComplete;
  final VoidCallback? onExit;

  @override
  State<LabelMakerGame> createState() => _LabelMakerGameState();
}

class _LabelMakerGameState extends State<LabelMakerGame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  bool _playing = false;
  bool _down = false;

  @override
  void initState() {
    super.initState();
    _landscape();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final n in [
      'bg',
      'logo',
      'girl',
      'boy',
      'label_house',
      'label_head',
      'label_book',
      'play',
      'play_down',
    ]) {
      precacheImage(AssetImage('$_kA/$n.png'), context);
    }
  }

  void _landscape() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _portrait() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  void _play() {
    _portrait();
    _c.stop();
    setState(() => _playing = true);
  }

  @override
  void dispose() {
    _portrait();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_playing) {
      return SafeArea(
        child: FiqhDragActivity(
          activityId: widget.activityId,
          items: widget.items,
          zones: widget.zones,
          xp: widget.xp,
          color: widget.color,
          onComplete: widget.onComplete,
          onBack: widget.onExit,
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset('$_kA/bg.png', fit: BoxFit.cover),
        SizedBox.expand(
          child: FittedBox(
            child: SizedBox(
              width: 1870,
              height: 841,
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) => _stage(_c.value * 2 * math.pi),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _stage(double t) {
    Widget at(double l, double tp, double w, double h, Widget c) =>
        Positioned(left: l, top: tp, width: w, height: h, child: c);
    Widget img(String n) => Image.asset('$_kA/$n.png', fit: BoxFit.fill);
    Widget bob(double phase, double amp, Widget c) => Transform.translate(
      offset: Offset(0, amp * math.sin(t + phase)),
      child: c,
    );
    Widget sway(double phase, Widget c) => Transform.rotate(
      angle: .02 * math.sin(t + phase),
      alignment: Alignment.bottomCenter,
      child: c,
    );

    return Stack(
      children: [
        at(118, 128, 262, 142, bob(0, 6, img('label_house'))),
        at(1430, 96, 232, 112, bob(2, 6, img('label_head'))),
        at(1590, 356, 236, 114, bob(4, 6, img('label_book'))),
        at(290, 255, 358, 480, sway(0, img('girl'))),
        at(1250, 240, 297, 500, sway(math.pi, img('boy'))),
        at(
          615,
          88,
          640,
          454,
          Stack(
            fit: StackFit.expand,
            children: [
              img('logo'),
              Positioned(
                left: 80,
                right: 80,
                top: 385,
                bottom: 18,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Learn Arabic Words',
                    style: const TextStyle(
                      fontFamily: 'Fredoka',
                      fontWeight: FontWeight.w700,
                      fontSize: 38,
                      color: Color(0xFF1B2A6B),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        at(
          705,
          585,
          460,
          163,
          Transform.scale(
            scale: _down ? .97 : 1 + .025 * math.sin(t * 2),
            child: GestureDetector(
              key: const ValueKey('lm-play'),
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => setState(() => _down = true),
              onTapUp: (_) => setState(() => _down = false),
              onTapCancel: () => setState(() => _down = false),
              onTap: _play,
              child: img(_down ? 'play_down' : 'play'),
            ),
          ),
        ),
      ],
    );
  }
}
