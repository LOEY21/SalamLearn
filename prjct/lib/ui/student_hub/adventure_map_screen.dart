import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../data/curriculum_data.dart';
import '../../data/models/curriculum/curriculum_models.dart';
import '../../data/repositories/class_repository.dart';
import '../../data/repositories/progress_repository.dart';
import '../../logic/auth/session.dart';
import '../../logic/learner/hub_tab_provider.dart';
import '../../logic/learner/map_zoom_provider.dart';
import '../../logic/learner/noor_energy_provider.dart';
import '../../logic/recent_module_provider.dart';
import '../core_modules/lesson_player_screen.dart';
import '../core_modules/module_registry.dart';
import '../teacher_dashboard/teacher_dashboard_screen.dart'
    show progressionOverrideProvider;
import '../theme/app_colors.dart';
import '../widgets/learner_avatar.dart';
import 'adventure_map_top_bar.dart';
import 'destination_levels_sheet.dart';
import 'noor_energy_resting_sheet.dart';
import 'tutorial/mascot_tutorial_overlay.dart';
import 'tutorial/tutorial_anchors.dart';




/// The Wireframe 0.3 curriculum entry each core module represents — looked
/// up once via `ModuleInfo.destinationId`, since the map's real layout
/// (`mapX`/`mapY`) and per-level color live on `Destination`, not on
/// `ModuleInfo` itself.
Destination _destinationFor(ModuleInfo module) =>
    curriculum.firstWhere((d) => d.id == module.destinationId);

/// `mapX`/`mapY` on each `Destination` are pixel coordinates on the Journey
/// Map background's own 1080x3060 canvas (Madrasah at the bottom, mosque
/// summit at the top) — measured directly off that artwork's plaque
/// positions, so each node badge lands exactly on its stage sign.
const _wireframeCanvasWidth = 1080.0;
const _wireframeCanvasHeight = 3060.0;

final _nodePositions = <String, double>{
  for (final module in coreModules)
    module.id: _destinationFor(module).mapY / _wireframeCanvasHeight,
};

final _nodePositionsX = <String, double>{
  for (final module in coreModules)
    module.id: _destinationFor(module).mapX / _wireframeCanvasWidth,
};

/// Each destination's own accent color (from the wireframe's `color` field)
/// — every level reads as visually distinct, not just by number.
final _nodeColors = <String, Color>{
  for (final module in coreModules)
    module.id: _hexColor(_destinationFor(module).color),
};

Color _hexColor(String hex) {
  final h = hex.replaceFirst('#', '');
  return Color(int.parse('FF$h', radix: 16));
}

/// The exact overshoot easing the approved preview uses everywhere (nodes,
/// pills, mascot, speech bubble): `cubic-bezier(0.34, 1.56, 0.64, 1)`.
const _overshoot = Cubic(0.34, 1.56, 0.64, 1.0);

const _debugUnlockAllModules = true;

enum _NodeState { locked, available, current, completed }

class AdventureMapScreen extends ConsumerStatefulWidget {
  const AdventureMapScreen({super.key});

  @override
  ConsumerState<AdventureMapScreen> createState() => _AdventureMapScreenState();
}

class _AdventureMapScreenState extends ConsumerState<AdventureMapScreen>
    with TickerProviderStateMixin {
  final _scrollController = ScrollController();
  // Resting balance point: zoomed in enough to read as a tall scrollable
  // journey (not the whole 7-destination map flattened onto one screen),
  // without over-cropping the background video.
  static const _baseMapHeight = 1300.0;

  // Pinch-zoom tracking. Uses raw `Listener` pointer events rather than a
  // `GestureDetector`'s scale recognizer so a 2-finger pinch never steals
  // the gesture arena from the map's own `SingleChildScrollView` —
  // one-finger scrolling keeps working untouched underneath.
  final Map<int, Offset> _activePointers = {};
  double? _pinchStartDistance;
  double _pinchStartZoom = 1.0;
  double _pinchZoom = 1.0;
  late final _release = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );
  double _releaseFromZoom = 1.0;

  /// Set once the background video reports its real decoded size (width /
  /// height) — lets the map track the video's own aspect ratio instead of
  /// the old fixed 1300px canvas, so the new Journey Map video shows at its
  /// native proportions instead of being cropped/stretched to fit the
  /// previous map's dimensions.
  double? _videoAspectRatio;

  double _mapHeightFor(double width) {
    final ratio = _videoAspectRatio;
    final natural = ratio != null ? width / ratio : _baseMapHeight;
    return natural * _pinchZoom;
  }

  /// How much the pinch has moved away from resting (1.0) before the top
  /// bar / bottom nav are fully faded out — same distance either direction,
  /// so zooming in and zooming out both clear the chrome away.
  static const _chromeFadeRange = 0.12;

  void _setPinchZoom(double value) {
    setState(() => _pinchZoom = value.clamp(0.6, 1.6));
    final fade = (1.0 - (_pinchZoom - 1.0).abs() / _chromeFadeRange).clamp(
      0.0,
      1.0,
    );
    ref.read(mapZoomProvider.notifier).set(fade);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final currentId = ref.read(recentModuleProvider) ?? coreModules.first.id;
      final fraction = _nodePositions[currentId] ?? 0.5;
      final width = MediaQuery.sizeOf(context).width;
      final mapHeight = _mapHeightFor(width);
      final target = (mapHeight * fraction) - 300;
      _scrollController.jumpTo(target.clamp(0, mapHeight));
      _playTutorial();
    });
    _release.addListener(() {
      final t = Curves.easeOutCubic.transform(_release.value);
      _setPinchZoom(_releaseFromZoom + (1.0 - _releaseFromZoom) * t);
    });
  }

  bool _tutorialActive = false;

  /// Plays the mascot tutorial every time the Home tab becomes active —
  /// once on first landing here (called from `initState`), and again on
  /// every later switch back from Backpack/Profile (see the `ref.listen`
  /// on `activeHubTabIndexProvider` in `build`). `_tutorialActive` just
  /// stops two overlays stacking if a replay is triggered while one is
  /// already up; it isn't a "seen" flag, so this is never permanently
  /// skipped.
  void _playTutorial() {
    if (_tutorialActive) return;
    final learner = ref.read(sessionProvider).learner;
    if (learner == null) return;
    _tutorialActive = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) {
          _tutorialActive = false;
          return;
        }
        MascotTutorialOverlay.show(
          context,
          learnerName: learner.name,
          isGirl: learner.avatar == 'girl_mascot',
          onFinished: () => _tutorialActive = false,
        );
      });
    });
  }

  void _onPointerDown(PointerDownEvent event) {
    _activePointers[event.pointer] = event.position;
    if (_activePointers.length == 2) {
      _release.stop();
      final pts = _activePointers.values.toList();
      _pinchStartDistance = (pts[0] - pts[1]).distance;
      _pinchStartZoom = _pinchZoom;
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_activePointers.containsKey(event.pointer)) return;
    _activePointers[event.pointer] = event.position;
    final startDistance = _pinchStartDistance;
    if (_activePointers.length != 2 || startDistance == null) return;
    final pts = _activePointers.values.toList();
    final distance = (pts[0] - pts[1]).distance;
    // Ratio < 1 (fingers moved closer together) zooms out; ratio > 1
    // (spread apart) zooms in.
    final ratio = distance / startDistance;
    _setPinchZoom(_pinchStartZoom * ratio);
  }

  void _onPointerEnd(PointerEvent event) {
    _activePointers.remove(event.pointer);
    if (_activePointers.length < 2) {
      _pinchStartDistance = null;
      if (_pinchZoom != 1.0) {
        _releaseFromZoom = _pinchZoom;
        _release.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _release.dispose();
    super.dispose();
  }

  /// Same rule `StudentHubScreen` used before this screen replaced it, with
  /// its always-true fallthrough bug fixed: a module only unlocks when the
  /// debug override is on, or a teacher has actually assigned it (per class
  /// homework or this student's own assignment list) — otherwise it's
  /// locked, matching the "Locked by ustadzah" messaging learners already
  /// know from the old
  bool _isModuleAssigned(String moduleId) {
    if (_debugUnlockAllModules) return true;
    final override = ref.watch(progressionOverrideProvider);
    if (override) return true;

    // 1. Sequential unlocking:
    final completed = _completedLessons;
    final index = coreModules.indexWhere((m) => m.id == moduleId);
    if (index <= 0) return true; // First module is always unlocked

    // Check if previous module is completed
    final prevModule = coreModules[index - 1];
    final dest = curriculum.firstWhere((d) => d.id == prevModule.destinationId, orElse: () => curriculum.first);
    final isPrevCompleted = dest.lessons.every((lesson) => completed.contains(lesson.id));
    if (isPrevCompleted) return true;

    // 2. Teacher assignment override (unlocks the module early):
    final learner = ref.watch(sessionProvider).learner;
    if (learner == null) return false;
    final learnerId = learner.id;
    if (learnerId == null) return false;

    final enrollments = ClassRepository().byLearnerId(learnerId);
    final enrolledClassIds = enrollments.map((e) => e.classId).toSet();

    for (final classId in enrolledClassIds) {
      final classAssignments = ClassRepository().assignmentsFor(classId: classId, learnerId: null);
      if (classAssignments.any((a) => a.moduleId == moduleId)) return true;

      final personalAssignments = ClassRepository().assignmentsFor(classId: classId, learnerId: learnerId);
      if (personalAssignments.any((a) => a.moduleId == moduleId)) return true;
    }

    return false;
  }

  /// How far (1–3) a teacher has allowed [moduleId] to be played into.
  /// On the main map, sequential levels are fully unlocked so students can play self-paced.
  int _maxLevelFor(String moduleId) {
    return 3;
  }

  /// How many lessons within the top level are unlocked — on the main map, this is uncapped.
  int? _maxLessonsFor(String moduleId) {
    return null;
  }

  /// True if [moduleId] is assigned (class-wide or per-student) with a due
  /// date already in the past — drives the small overdue badge on the map node.
  bool _isModuleOverdue(String moduleId) {
    if (ref.watch(progressionOverrideProvider)) return false;
    final now = DateTime.now();

    final learner = ref.watch(sessionProvider).learner;
    if (learner == null) return false;
    final learnerId = learner.id;
    if (learnerId == null) return false;

    final enrollments = ClassRepository().byLearnerId(learnerId);
    final enrolledClassIds = enrollments.map((e) => e.classId).toSet();

    for (final classId in enrolledClassIds) {
      final classAssignments = ClassRepository().assignmentsFor(classId: classId, learnerId: null);
      for (final a in classAssignments) {
        if (a.moduleId == moduleId && a.dueDate.isBefore(now)) return true;
      }
      final personalAssignments = ClassRepository().assignmentsFor(classId: classId, learnerId: learnerId);
      for (final a in personalAssignments) {
        if (a.moduleId == moduleId && a.dueDate.isBefore(now)) return true;
      }
    }
    return false;
  }

  /// No real progress-tracking backend exists yet (placeholder phase, per
  /// this repo's standing constraint) — modules ahead of the current one in
  /// `coreModules`' fixed order read as "completed", matching the approved
  /// preview's green-checkmark nodes, without inventing a new provider.
  _NodeState _stateFor(ModuleInfo module, String currentId, bool assigned) {
    if (!assigned) return _NodeState.locked;
    if (module.id == currentId) return _NodeState.current;
    final currentIndex = coreModules.indexWhere((m) => m.id == currentId);
    final thisIndex = coreModules.indexWhere((m) => m.id == module.id);
    return thisIndex < currentIndex
        ? _NodeState.completed
        : _NodeState.available;
  }

  void _showLockedDialog(String moduleTitle) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.lock_outline_rounded,
          color: AppColors.coral,
          size: 44,
        ),
        title: Text('$moduleTitle is Locked'),
        content: const Text(
          'This module is not currently unlocked. Complete the previous module first, or complete your teacher-assigned homework to unlock new modules!',
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Every lesson this learner has actually finished, read fresh from
  /// [ProgressRepository] each time a level sheet opens — drives
  /// `DestinationLevelsSheet`'s real per-lesson/per-level unlock gating.
  Set<String> get _completedLessons {
    final learnerId = ref.read(sessionProvider).learner?.id;
    if (learnerId == null) return const {};
    return ProgressRepository().completedLessonIds(learnerId);
  }

  /// Opens the level selection sheet for [destination] and [module].
  /// When the player closes a lesson, this is called again so the user always
  /// lands back on the level selection — never on the bare map.
  void _openLevelSheet(ModuleInfo module, Destination destination) {
    DestinationLevelsSheet.show(
      context,
      destination: destination,
      completedLessons: _completedLessons,
      maxLevel: _maxLevelFor(module.id),
      maxLessons: _maxLessonsFor(module.id),
      noorEnergy: ref.read(noorEnergyProvider).current,
      onStartLesson: (lesson, isNewLevel) {
        ref.read(noorEnergyProvider.notifier).consume();
        ref.read(recentModuleProvider.notifier).interactWith(module.id);
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(
            builder: (_) => LessonPlayerScreen(
              lesson: lesson,
              destinationId: destination.id,
              onClose: () {
                // Close the lesson player
                Navigator.of(context, rootNavigator: true).pop();
                // Always go back to the level selection sheet
                _openLevelSheet(module, destination);
              },
            ),
          ),
        );
      },
    );
  }

  void _onNodeTap(ModuleInfo module, bool isAssigned) {
    if (!isAssigned) {
      _showLockedDialog(module.title);
      return;
    }
    final energy = ref.read(noorEnergyProvider);
    if (!_debugUnlockAllModules && !energy.hasEnergy) {
      showNoorEnergyRestingSheet(context);
      return;
    }
    final destination = curriculum.firstWhere(
      (d) => d.id == module.destinationId,
    );
    _openLevelSheet(module, destination);
  }

  @override
  Widget build(BuildContext context) {
    final currentId = ref.watch(recentModuleProvider) ?? coreModules.first.id;
    final learnerAvatar = ref.watch(sessionProvider).learner?.avatar;
    final chromeFade = ref.watch(mapZoomProvider);
    final anchors = ref.watch(tutorialAnchorsProvider);
    ref.listen(activeHubTabIndexProvider, (prev, next) {
      if (next == 0 && prev != null && prev != 0) _playTutorial();
    });

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Listener(
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerEnd,
        onPointerCancel: _onPointerEnd,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final mapHeight = _mapHeightFor(constraints.maxWidth);
            // Once the video's real aspect ratio is known, its natural
            // height is used as-is (no cropping) so it shows at original
            // size — the old floor-to-viewport-height trick only still
            // applies before that, to avoid a flash of bare cream space
            // below the fallback-sized placeholder.
            final effectiveMapHeight = _videoAspectRatio != null
                ? mapHeight
                : math.max(mapHeight, constraints.maxHeight);
            return Stack(
              children: [
                SingleChildScrollView(
                  controller: _scrollController,
                  // `HubShell`'s outer Scaffold uses `extendBody: true` so
                  // the floating pill nav doesn't shorten this screen's
                  // visible height. No bottom padding here — matching the
                  // approved preview exactly, the nav simply floats *over*
                  // whatever's currently at the bottom of the scroll, the
                  // same way it does in
                  // dumps/adventure_map_preview/preview.html. Padding here
                  // would just add dead cream space past the image's real
                  // end.
                  child: SizedBox(
                    height: effectiveMapHeight,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: _MapVideoBackground(
                            onAspectRatio: (ratio) {
                              if (_videoAspectRatio == ratio) return;
                              setState(() => _videoAspectRatio = ratio);
                            },
                          ),
                        ),
                        const Positioned.fill(child: _AmbientBreathing()),
                        const _MapSparkles(),
                        for (final (i, module) in coreModules.indexed)
                          _MapNode(
                            key: ValueKey(module.id),
                            module: module,
                            topFraction: _nodePositions[module.id] ?? 0.5,
                            left:
                                constraints.maxWidth *
                                (_nodePositionsX[module.id] ?? 0.33),
                            mapHeight: effectiveMapHeight,
                            color: _nodeColors[module.id] ?? AppColors.teal,
                            state: _stateFor(
                              module,
                              currentId,
                              _isModuleAssigned(module.id),
                            ),
                            overdue: _isModuleOverdue(module.id),
                            entranceDelay: Duration(milliseconds: 40 + i * 50),
                            onTap: () => _onNodeTap(
                              module,
                              _isModuleAssigned(module.id),
                            ),
                            anchorKey: module.id == currentId
                                ? anchors.currentNodeKey
                                : null,
                          ),
                        KeyedSubtree(
                          key: anchors.mapAvatarKey,
                          child: _MascotAvatar(
                            topFraction: _nodePositions[currentId] ?? 0.5,
                            left:
                                constraints.maxWidth *
                                (_nodePositionsX[currentId] ?? 0.33),
                            mapHeight: effectiveMapHeight,
                            avatar: learnerAvatar,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IgnorePointer(
                  ignoring: chromeFade < 0.5,
                  child: Opacity(
                    opacity: chromeFade,
                    child: Transform.translate(
                      offset: Offset(0, -16 * (1 - chromeFade)),
                      child: const SafeArea(
                        child: AdventureMapTopBar(),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Looping muted video behind the map nodes, replacing the static
/// `map_background.png`. Falls back to the still image while the video
/// decodes (or if it fails to load) so there's never a blank/black frame.
///
/// Reports its decoded aspect ratio via [onAspectRatio] once known, so the
/// parent can size the scrollable map to the video's own natural
/// proportions instead of a fixed canvas — the video is then shown with
/// `BoxFit.fitWidth` (no cropping) rather than `BoxFit.cover`.
class _MapVideoBackground extends StatefulWidget {
  const _MapVideoBackground({required this.onAspectRatio});

  final ValueChanged<double> onAspectRatio;

  @override
  State<_MapVideoBackground> createState() => _MapVideoBackgroundState();
}

class _MapVideoBackgroundState extends State<_MapVideoBackground> {
  late final _controller = VideoPlayerController.asset(
    'assets/videos/adventure_map_loop.mp4',
  );
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  // No video decoder platform channel exists in the widget-test
  // environment (and might not on some desktop targets either) —
  // `initialize()` throws there. Caught here so the still-image fallback
  // in `build()` renders instead of crashing the whole screen.
  Future<void> _initVideo() async {
    try {
      await _controller.initialize();
    } catch (_) {
      return;
    }
    if (!mounted) return;
    await _controller.setLooping(true);
    await _controller.setVolume(0);
    await _controller.play();
    widget.onAspectRatio(_controller.value.aspectRatio);
    if (mounted) setState(() => _ready = true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.cream,
      child: _ready
          ? ClipRect(
              child: FittedBox(
                fit: BoxFit.fitWidth,
                child: SizedBox(
                  width: _controller.value.size.width,
                  height: _controller.value.size.height,
                  child: VideoPlayer(_controller),
                ),
              ),
            )
          : Image.asset(
              'assets/images/adventure_map/map_background.png',
              fit: BoxFit.cover,
            ),
    );
  }
}

/// Very slight radial-glow breathing over the whole map — the approved
/// preview's `.map-canvas::before` ambient overlay, 5200ms ease-in-out.
class _AmbientBreathing extends StatefulWidget {
  const _AmbientBreathing();

  @override
  State<_AmbientBreathing> createState() => _AmbientBreathingState();
}

class _AmbientBreathingState extends State<_AmbientBreathing>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 5200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = Curves.easeInOut.transform(_controller.value);
          final opacity = 0.5 + 0.5 * t;
          return Opacity(
            opacity: opacity,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.4),
                  radius: 0.6,
                  colors: [
                    Colors.white.withValues(alpha: 0.10),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Four floating ambient sparkles at fixed spots, matching the preview's
/// decorative `.sparkle` dots.
class _MapSparkles extends StatelessWidget {
  const _MapSparkles();

  static const _spots = <(double, double, int)>[
    (260, 80, 0),
    (620, 300, 900),
    (980, 60, 1600),
    (1350, 310, 500),
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        for (final (top, left, delay) in _spots)
          Positioned(
            top: top,
            left: left,
            child: _Sparkle(delayMs: delay),
          ),
      ],
    );
  }
}

class _Sparkle extends StatefulWidget {
  const _Sparkle({required this.delayMs});

  final int delayMs;

  @override
  State<_Sparkle> createState() => _SparkleState();
}

class _SparkleState extends State<_Sparkle>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4800),
  );
  Timer? _startTimer;

  @override
  void initState() {
    super.initState();
    _startTimer = Timer(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = Curves.easeInOut.transform(_controller.value);
          return Opacity(
            opacity: 0.3 + 0.6 * t,
            child: Transform.translate(
              offset: Offset(0, -16 * t),
              child: Transform.scale(
                scale: 1 + 0.3 * t,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.6),
                        blurRadius: 6,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MapNode extends StatefulWidget {
  const _MapNode({
    super.key,
    required this.module,
    required this.topFraction,
    required this.left,
    required this.mapHeight,
    required this.color,
    required this.state,
    required this.overdue,
    required this.entranceDelay,
    required this.onTap,
    this.anchorKey,
  });

  final ModuleInfo module;
  final double topFraction;
  final double left;
  final double mapHeight;
  final Color color;
  final _NodeState state;
  final bool overdue;
  final Duration entranceDelay;
  final VoidCallback onTap;

  /// Attached only to the current-lesson node so the first-run mascot
  /// tutorial can spotlight its real on-screen rect — see [TutorialAnchors].
  final GlobalKey? anchorKey;

  @override
  State<_MapNode> createState() => _MapNodeState();
}

class _MapNodeState extends State<_MapNode> with TickerProviderStateMixin {
  late final _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  // Current & available nodes idle-tilt continuously (3400ms, ±4deg).
  late final _idleTilt = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3400),
  );
  // Current node also pulses its glow ring (2600ms, matches the shared
  // ambient rhythm used across the whole Adventure Map).
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  // One-shot "no" wobble when a locked node is tapped, before the dialog.
  late final _wobble = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  Timer? _entranceTimer;
  late final _animations = Listenable.merge([
    _entrance,
    _idleTilt,
    _pulse,
    _wobble,
  ]);

  @override
  void initState() {
    super.initState();
    _entranceTimer = Timer(widget.entranceDelay, () {
      if (mounted) _entrance.forward();
    });
    _syncContinuousAnimations(previousState: null);
  }

  @override
  void didUpdateWidget(covariant _MapNode oldWidget) {
    super.didUpdateWidget(oldWidget);
    // This screen stays mounted underneath `/module/:id` (a sibling
    // top-level route, not an indexed-stack branch) — the learner going in
    // and back out advances `recentModuleProvider`, so the same `_MapNode`
    // instance (matched by `ValueKey(module.id)`) can flip between
    // available/current/completed without ever being recreated. Without
    // this, a node that just became current would never start pulsing, and
    // one that just finished would keep tilting forever.
    if (oldWidget.state != widget.state) {
      _syncContinuousAnimations(previousState: oldWidget.state);
    }
  }

  void _syncContinuousAnimations({required _NodeState? previousState}) {
    final wantsTilt =
        widget.state == _NodeState.current ||
        widget.state == _NodeState.available;
    if (wantsTilt && !_idleTilt.isAnimating) {
      _idleTilt.repeat(reverse: true);
    } else if (!wantsTilt && _idleTilt.isAnimating) {
      _idleTilt.stop();
      _idleTilt.value = 0;
    }

    final wantsPulse = widget.state == _NodeState.current;
    if (wantsPulse && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!wantsPulse && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _entranceTimer?.cancel();
    _entrance.dispose();
    _idleTilt.dispose();
    _pulse.dispose();
    _wobble.dispose();
    super.dispose();
  }

  void _handleTap() {
    if (widget.state == _NodeState.locked) {
      _wobble.forward(from: 0);
    }
    widget.onTap();
  }

  /// Each level keeps its own destination color (from the wireframe) as
  /// its badge fill — only "locked" overrides to a neutral gray. The
  /// number/icon stays white on top, same contrast pattern every state
  /// already used, just recoloring the fill per destination instead of
  /// per state.
  (Color, Color) _colorsFor(_NodeState state) {
    if (state == _NodeState.locked) {
      return (const Color(0xFFC9C2AE), const Color(0xFF7A8B85));
    }
    return (widget.color, Colors.white);
  }

  @override
  Widget build(BuildContext context) {
    final isCurrent = widget.state == _NodeState.current;
    // Small enough to sit on the path without covering the artwork's own
    // landmarks (buildings, trees) — was 64-78px, oversized against the
    // background's actual scale.
    final size = isCurrent ? 40.0 : 34.0;
    final (bg, fg) = _colorsFor(widget.state);

    Widget icon = switch (widget.state) {
      _NodeState.locked => const Icon(
        Icons.lock_rounded,
        color: Color(0xFF7A8B85),
        size: 16,
      ),
      _NodeState.completed => Icon(Icons.check_rounded, color: fg, size: 18),
      // Numbered badge (1-7, the destination's position on the journey)
      // rather than the module's topic icon — makes the map read as a
      // level sequence at a glance.
      _ => Text(
        '${widget.module.destinationId}',
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: fg),
      ),
    };

    return Positioned(
      top: widget.mapHeight * widget.topFraction - size / 2,
      left: widget.left - size / 2,
      child: KeyedSubtree(
        key: widget.anchorKey,
        child: AnimatedBuilder(
        animation: _animations,
        builder: (context, child) {
          final entranceT = _overshoot.transform(_entrance.value);
          final tiltT = Curves.easeInOut.transform(_idleTilt.value);
          final pulseT = Curves.easeInOut.transform(_pulse.value);
          final wobbleT = Curves.easeInOut.transform(_wobble.value);

          final scale = 0.5 + 0.5 * entranceT;
          final opacity = entranceT.clamp(0.0, 1.0);
          final tiltAngle =
              (widget.state == _NodeState.current ||
                  widget.state == _NodeState.available)
              ? (tiltT * 2 - 1) *
                    0.07 // ±4deg in radians
              : 0.0;
          final wobbleDx = widget.state == _NodeState.locked
              ? (wobbleT < 0.5 ? -4.0 : 4.0) * (1 - (wobbleT - 0.5).abs() * 2)
              : 0.0;
          final glowSpread = isCurrent ? 6 + 6 * pulseT : 0.0;

          return Opacity(
            opacity: opacity,
            child: Transform.translate(
              offset: Offset(wobbleDx, 0),
              child: Transform.scale(
                scale: scale,
                child: Transform.rotate(
                  angle: tiltAngle,
                  child: Semantics(
                    button: true,
                    label: widget.state == _NodeState.locked
                        ? '${widget.module.title} module, locked by teacher'
                        : '${widget.module.title} module',
                    child: Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      child: InkWell(
                        key: ValueKey('node-badge-${widget.module.id}'),
                        customBorder: const CircleBorder(),
                        onTap: _handleTap,
                        child: SizedBox(
                          width: size,
                          height: size,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: bg,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.25,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                    if (isCurrent)
                                      BoxShadow(
                                        color: AppColors.gold.withValues(
                                          alpha: 0.35,
                                        ),
                                        blurRadius: 0,
                                        spreadRadius: glowSpread,
                                      ),
                                  ],
                                ),
                                alignment: Alignment.center,
                                child: icon,
                              ),
                              if (widget.overdue &&
                                  widget.state != _NodeState.locked)
                                const Positioned(
                                  top: -2,
                                  right: -2,
                                  child: _OverdueBadge(),
                                ),
                              Positioned(
                                top: size + 6,
                                left: -46,
                                right: -46,
                                child: IgnorePointer(
                                  child: Center(
                                    child: _NodeLabel(
                                      title: widget.module.title,
                                      locked: widget.state == _NodeState.locked,
                                      isCurrent: isCurrent,
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
              ),
            ),
          );
        },
        ),
      ),
    );
  }
}

/// Destination name pill under a map node's badge — small enough to stay
/// out of the background art's way, legible over any landmark it sits on
/// thanks to the opaque card + shadow (same treatment as the app's other
/// small text-on-photo labels).
class _NodeLabel extends StatelessWidget {
  const _NodeLabel({
    required this.title,
    required this.locked,
    required this.isCurrent,
  });

  final String title;
  final bool locked;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 88),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: locked ? 0.75 : 0.95),
          borderRadius: BorderRadius.circular(999),
          border: isCurrent
              ? Border.all(color: AppColors.gold, width: 1.5)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            height: 1.1,
            color: locked ? const Color(0xFF7A8B85) : const Color(0xFF2E2A24),
          ),
        ),
      ),
    );
  }
}

/// Small coral "!" dot pinned to a node's top-right corner when its
/// assignment's due date has passed — locked nodes never show it since
/// there's nothing overdue to act on until the module unlocks.
class _OverdueBadge extends StatelessWidget {
  const _OverdueBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.coral,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      alignment: Alignment.center,
      child: const Text(
        '!',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          height: 1,
        ),
      ),
    );
  }
}

class _MascotAvatar extends StatefulWidget {
  const _MascotAvatar({
    required this.topFraction,
    required this.left,
    required this.mapHeight,
    required this.avatar,
  });

  final double topFraction;
  final double left;
  final double mapHeight;
  final String? avatar;

  @override
  State<_MascotAvatar> createState() => _MascotAvatarState();
}

class _MascotAvatarState extends State<_MascotAvatar>
    with TickerProviderStateMixin {
  // Landing entrance: translateY(-24->4->-2->0) + scale(0.7->1.08->0.97->1),
  // 380ms overshoot, matching the preview's `mascot-enter` keyframes.
  late final _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );
  // Continuous bob + ground-shadow pulse, shared 2600ms ambient rhythm.
  late final _bob = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  late final _bubble = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );
  Timer? _bubbleTimer;
  late final _mascotAnimations = Listenable.merge([_enter, _bob]);

  @override
  void initState() {
    super.initState();
    _enter.forward().whenComplete(() {
      if (mounted) _bob.repeat(reverse: true);
    });
    _bubbleTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) _bubble.forward();
    });
  }

  @override
  void dispose() {
    _bubbleTimer?.cancel();
    _enter.dispose();
    _bob.dispose();
    _bubble.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: widget.mapHeight * widget.topFraction - 64,
      left: widget.left + 22,
      child: SizedBox(
        width: 84,
        height: 100,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Ground shadow, pulsing on the shared 2600ms rhythm.
            AnimatedBuilder(
              animation: _bob,
              builder: (context, _) {
                final t = Curves.easeInOut.transform(_bob.value);
                return Positioned(
                  bottom: 0,
                  left: 19,
                  child: Opacity(
                    opacity: 0.28 - 0.10 * t,
                    child: Transform.scale(
                      scale: 1 - 0.18 * t,
                      child: Container(
                        width: 46,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(50),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            AnimatedBuilder(
              animation: _mascotAnimations,
              builder: (context, child) {
                double dy;
                double scale;
                double opacity;
                if (_enter.value < 1.0) {
                  // Keyframes: 0%->opacity0/y-24/s0.7, 60%->opacity1/y4/s1.08,
                  // 80%->y-2/s0.97, 100%->y0/s1.
                  final v = _enter.value;
                  if (v < 0.6) {
                    final t = _overshoot.transform(v / 0.6);
                    dy = -24 + 28 * t;
                    scale = 0.7 + 0.38 * t;
                    opacity = t;
                  } else if (v < 0.8) {
                    final t = (v - 0.6) / 0.2;
                    dy = 4 - 6 * t;
                    scale = 1.08 - 0.11 * t;
                    opacity = 1;
                  } else {
                    final t = (v - 0.8) / 0.2;
                    dy = -2 + 2 * t;
                    scale = 0.97 + 0.03 * t;
                    opacity = 1;
                  }
                } else {
                  final t = Curves.easeInOut.transform(_bob.value);
                  dy = -10 * t;
                  scale = 1;
                  opacity = 1;
                }
                return Positioned(
                  bottom: 10,
                  left: 6,
                  child: Opacity(
                    opacity: opacity,
                    child: Transform.translate(
                      offset: Offset(0, dy),
                      child: Transform.scale(scale: scale, child: child),
                    ),
                  ),
                );
              },
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x4D000000),
                      blurRadius: 14,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: LearnerAvatar(avatar: widget.avatar ?? '🧒', size: 72),
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _bubble,
              builder: (context, child) {
                final t = _overshoot.transform(_bubble.value);
                return Positioned(
                  left: -30,
                  right: -30,
                  top: -20,
                  child: Opacity(
                    opacity: t.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: 0.7 + 0.3 * t,
                      alignment: Alignment.bottomCenter,
                      child: Center(child: child),
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.gold, width: 2),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x26000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: const Text(
                  'You are here!',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.tealDark,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


