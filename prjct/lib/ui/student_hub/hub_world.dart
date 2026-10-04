import 'dart:ui' as ui;

import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';

import '../theme/app_colors.dart';

/// Shared visual vocabulary for the Learner Hub's Backpack and Me tabs, so
/// they read as part of the Adventure Map's illustrated world instead of a
/// separate dashboard: the bottom nav's dark-wood frame + parchment + gold
/// trim, chunky press-down buttons, and bands of the map art itself.
abstract final class HubWorld {
  static const wood = Color(0xFF4A3A1E);
  static const woodMid = Color(0xFF7A5530);
  static const woodLight = Color(0xFFA9773F);
  static const parchment = AppColors.cream;
  static const parchmentDeep = Color(0xFFF1E4C6);
  static const night = Color(0xFF1A2744);
  static const inkSoft = Color(0xFF5B5346);

  /// Darker underside of a white/parchment chunky button.
  static const edge = Color(0xFFE2D6BC);
  /// Locked / empty state greys on parchment.
  static const lockedRim = Color(0xFFD9CFBA);
  static const lockedRing = Color(0xFFC4B89E);
  /// Gold that passes contrast as text on parchment, and a gold button's edge.
  static const goldDeep = Color(0xFFB8741A);
  static const goldLight = Color(0xFFFFD77A);
  static const purpleDeep = Color(0xFF4A42A8);
  /// Warm off-white for secondary text over the dark map scrim.
  static const onScene = Color(0xFFFFF3D6);

  static const mapArt = 'assets/images/adventure_map/map_background.png';
  static const backpackArt = 'assets/images/adventure_map/header_backpack.webp';
  static const meArt = 'assets/images/adventure_map/header_me.webp';
}

/// Rounded Baloo display style used by the games and map — one family for
/// every learner-facing label, weight-tuned through the variable axis.
TextStyle hubText(
  double size,
  Color color, {
  double weight = 800,
  double? height,
  List<Shadow>? shadows,
}) => TextStyle(
  fontFamily: 'Baloo2Var',
  fontSize: size,
  fontWeight: FontWeight.values[(weight / 100).round().clamp(1, 9) - 1],
  fontVariations: [ui.FontVariation.weight(weight)],
  color: color,
  height: height,
  shadows: shadows,
);

const hubTextShadow = [
  Shadow(color: Color(0x99000000), blurRadius: 6, offset: Offset(0, 2)),
];

/// Parchment board in a dark-wood frame with a thin gold inner line — the
/// same build as `AdventureMapBottomNav`.
class QuestPanel extends StatelessWidget {
  const QuestPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = HubWorld.parchment,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: HubWorld.wood,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(color: Color(0x334A3A1E), blurRadius: 14, offset: Offset(0, 6)),
        ],
      ),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(23),
          border: Border.all(color: AppColors.goldSoft, width: 1.5),
        ),
        child: child,
      ),
    );
  }
}

/// A pressable block with a solid darker "edge" underneath that the face
/// sinks into on press — the chunky game-button feel from the activities.
class ChunkyButton extends StatefulWidget {
  const ChunkyButton({
    super.key,
    required this.child,
    required this.face,
    required this.edge,
    this.onTap,
    this.radius = 20,
    this.depth = 5,
    this.padding = const EdgeInsets.all(14),
    this.border,
    this.semanticLabel,
  });

  final Widget child;
  final Color face;
  final Color edge;
  final VoidCallback? onTap;
  final double radius;
  final double depth;
  final EdgeInsetsGeometry padding;
  final Color? border;
  final String? semanticLabel;

  @override
  State<ChunkyButton> createState() => _ChunkyButtonState();
}

class _ChunkyButtonState extends State<ChunkyButton> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap == null || _down == v) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final sink = _down ? widget.depth - 1 : 0.0;
    final radius = BorderRadius.circular(widget.radius);
    return Semantics(
      button: widget.onTap != null,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap,
        child: Padding(
          padding: EdgeInsets.only(top: sink),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: widget.edge,
              borderRadius: radius,
            ),
            padding: EdgeInsets.only(bottom: widget.depth - sink),
            child: Container(
              padding: widget.padding,
              decoration: BoxDecoration(
                color: widget.face,
                borderRadius: radius,
                border: widget.border == null
                    ? null
                    : Border.all(color: widget.border!, width: 2),
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

/// A band of painted scenery used as a scene header — the Adventure Map by
/// default, or a tab's own [image]. [focusY] / [focusX] pick which part
/// stays in view when the art is cropped to the band (for the tall map,
/// -1 = starry summit, 1 = the village at the start of the path); a bottom
/// scrim keeps white text readable over the busy art.
class MapSceneHeader extends StatelessWidget {
  const MapSceneHeader({
    super.key,
    required this.height,
    required this.focusY,
    required this.child,
    this.focusX = 0,
    this.image = HubWorld.mapArt,
  });

  final double height;
  final double focusY;
  final double focusX;
  final String image;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: HubWorld.night),
          Image.asset(
            image,
            fit: BoxFit.cover,
            alignment: Alignment(focusX, focusY),
            excludeFromSemantics: true,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, 0.45, 1],
                colors: [Color(0x401A2744), Color(0x331A2744), Color(0xD91A2744)],
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// Small gold-trimmed wooden label chip, used for counts and tags.
class WoodChip extends StatelessWidget {
  const WoodChip({super.key, required this.label, this.icon});

  final String label;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
      decoration: BoxDecoration(
        color: HubWorld.wood.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppColors.goldSoft, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[icon!, const SizedBox(width: 5)],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: hubText(12.5, Colors.white, weight: 700, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

/// Whether looping ambient motion should run (off when the OS asks to
/// reduce motion).
bool hubMotionOn(BuildContext context) =>
    !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);
