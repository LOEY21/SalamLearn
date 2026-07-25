import 'package:flutter/widgets.dart';

import 'tutorial_anchors.dart';

/// Which of the 5 approved pose illustrations a step shows —
/// `assets/images/mascot/boy/<name>.png`.
enum MascotPose { wave, present, pointUp, pointUpLeft, pointDown, cheer }

extension MascotPoseAsset on MascotPose {
  /// [isGirl] picks the matching pose from `assets/images/mascot/girl/`
  /// instead — a separately-illustrated set (not a runtime mirror), so
  /// each girl asset was hand-picked to match the boy pose's gesture.
  String assetPath(bool isGirl) {
    final folder = isGirl ? 'girl' : 'boy';
    switch (this) {
      case MascotPose.wave:
        return 'assets/images/mascot/$folder/wave.png';
      case MascotPose.present:
        return 'assets/images/mascot/$folder/present.png';
      case MascotPose.pointUp:
        return 'assets/images/mascot/$folder/point_up.png';
      case MascotPose.pointUpLeft:
        return 'assets/images/mascot/$folder/point_up_left.png';
      case MascotPose.pointDown:
        return 'assets/images/mascot/$folder/point_down.png';
      case MascotPose.cheer:
        return 'assets/images/mascot/$folder/cheer.png';
    }
  }
}

/// Which screen edge the mascot stands at for a step — `center` is only
/// used for the final cheer beat.
enum MascotSide { left, right, center }

/// How the mascot docks relative to a spotlighted anchor, when one exists.
enum MascotDock {
  /// Stand on whichever side of the anchor has more room, hugging just
  /// above its top edge — the default for anchors with no stronger
  /// directional relationship to the mascot's pose.
  auto,

  /// Stand directly above the anchor, horizontally centered on it — pairs
  /// with a downward-pointing pose so the gesture reads as "right there,
  /// below me."
  aboveTarget,

  /// Stand immediately to the anchor's left, vertically centered on it —
  /// pairs with the "present" pose (arm reaching right) so the gesture
  /// visually connects sideways to the target instead of down at it.
  leftOfTarget,

  /// Stand directly below the anchor, horizontally centered on it — pairs
  /// with the "point up" pose so the raised arm lands squarely under the
  /// target instead of the side-hugged `auto` dock, whose horizontal
  /// offset can leave a diagonal gap between fingertip and target.
  belowTarget,
}

/// One beat of the tutorial: a pose + position + one or more dialogue
/// lines, optionally spotlighting a real anchor from [TutorialAnchors].
class TutorialStep {
  const TutorialStep({
    required this.pose,
    required this.side,
    required this.lines,
    this.anchorOf,
    this.dock = MascotDock.auto,
    this.dimOnly = false,
    this.isFinal = false,
  });

  final MascotPose pose;
  final MascotSide side;
  final List<String> lines;
  final MascotDock dock;

  /// Picks this step's spotlight target out of the shared anchors — null
  /// means "no spotlight" (full dim instead).
  final GlobalKey? Function(TutorialAnchors anchors)? anchorOf;

  /// True for a full-dim step with no anchor at all (the map-intro beat) —
  /// distinct from "no anchor found" so it always reads as a lighter,
  /// ambient dim rather than the darker default.
  final bool dimOnly;

  /// The closing cheer beat — auto-dismisses instead of waiting for a tap.
  final bool isFinal;
}

/// The approved 8-beat first-run tutorial (see
/// `dumps/mascot_tutorial_preview_mock.html`) — greets the learner by name,
/// walks the Adventure Map's top bar/current node/own avatar/Backpack tab,
/// then hands off to the real map.
List<TutorialStep> buildTutorialSteps(
  String learnerName, {
  bool isGirl = false,
}) {
  final mascotName = isGirl ? 'Amira' : 'Amir';
  // The two free-standing intro beats have no anchor to hug, so their side
  // is a pure art choice — the girl set's poses are separately illustrated
  // (not a runtime mirror of the boy's), and her waving/presenting hand
  // reads toward the opposite edge. Standing her on the flipped side keeps
  // that gesture pointing at the bubble instead of off-screen.
  final introSide = isGirl ? MascotSide.right : MascotSide.left;
  return [
  TutorialStep(
    pose: MascotPose.wave,
    side: introSide,
    lines: [
      "Assalamu'alaikum, $learnerName! 🌟",
      "I'm $mascotName, and I'll be your friend on this whole adventure!",
    ],
  ),
  TutorialStep(
    // Girl mascot stands on the opposite side from the wave beat here —
    // her replaced "present" art reaches its hand rightward, so standing
    // her on the left points that gesture at the bubble instead of away
    // from it. Boy mascot keeps introSide (unaffected).
    pose: MascotPose.present,
    side: isGirl ? MascotSide.left : introSide,
    dimOnly: true,
    lines: [
      "This is our Adventure Map. Every place here has something new to learn!",
    ],
  ),
  TutorialStep(
    pose: MascotPose.pointUp,
    side: MascotSide.left,
    anchorOf: (a) => a.energyPillKey,
    dock: MascotDock.belowTarget,
    lines: [
      "These lanterns are your Noor Energy. Each lesson uses one — they refill when you rest!",
    ],
  ),
  TutorialStep(
    pose: MascotPose.pointUpLeft,
    side: MascotSide.left,
    anchorOf: (a) => a.streakPillKey,
    lines: [
      "Stars are the points you earn. The flame counts your days in a row!",
    ],
  ),
  TutorialStep(
    pose: MascotPose.present,
    side: MascotSide.right,
    anchorOf: (a) => a.mapAvatarKey,
    dock: MascotDock.leftOfTarget,
    lines: [
      "See that? That's YOU, standing on the map. You move forward with every lesson you finish!",
    ],
  ),
  TutorialStep(
    pose: MascotPose.pointDown,
    side: MascotSide.right,
    anchorOf: (a) => a.backpackTabKey,
    dock: MascotDock.aboveTarget,
    lines: [
      "Your Backpack keeps every badge you win. Check it any time!",
    ],
  ),
  TutorialStep(
    pose: MascotPose.pointDown,
    side: MascotSide.right,
    anchorOf: (a) => a.currentNodeKey,
    dock: MascotDock.aboveTarget,
    lines: [
      "Now — tap the glowing place to start your very first lesson. Bismillah!",
    ],
  ),
  const TutorialStep(
    pose: MascotPose.cheer,
    side: MascotSide.center,
    dimOnly: true,
    isFinal: true,
    lines: [
      "Masha'Allah! You did it! I'll be right here whenever you need me. 🎉",
    ],
  ),
];
}
