import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../logic/auth/session.dart';
import '../../logic/learner/noor_energy_provider.dart';
import '../../logic/recent_module_provider.dart';
import '../../logic/teacher/teacher_providers.dart';
import '../core_modules/module_registry.dart';
import '../teacher_dashboard/teacher_dashboard_screen.dart'
    show progressionOverrideProvider;
import '../theme/app_colors.dart';
import '../widgets/learner_avatar.dart';
import 'adventure_map_top_bar.dart';
import 'noor_energy_resting_sheet.dart';

/// Matches module ids to the free-text module names teachers pick when
/// assigning homework — same matching rules `StudentHubScreen` used before
/// this screen replaced it (kept in sync here since assignment gating is
/// still module-name-based on the teacher side).
bool _doesModuleNameMatchId(String name, String id) {
  final cleanName = name.toLowerCase();
  return switch (id) {
    'tracing' => cleanName.contains('tracing') || cleanName.contains('alif'),
    'flashcards' =>
      cleanName.contains('song') ||
          cleanName.contains('practice') ||
          cleanName.contains('flashcards') ||
          cleanName.contains('sounds'),
    'recitation' =>
      cleanName.contains('recitation') ||
          cleanName.contains('pronunciation') ||
          cleanName.contains('ج') ||
          cleanName.contains('qur\'an') ||
          cleanName.contains('hadith'),
    'sorting' =>
      cleanName.contains('sequence') ||
          cleanName.contains('matcher') ||
          cleanName.contains('sort') ||
          cleanName.contains('match'),
    'stories' => cleanName.contains('stories') || cleanName.contains('story'),
    _ => false,
  };
}

// Final positions recorded from the approved Task 7 HTML preview
// (dumps/adventure_map_preview/preview.html, bg 2.png background,
// 390x1821 canvas). Fraction of the background image's height, 0=top
// 1=bottom.
const _nodePositions = <String, double>{
  'tracing': 0.824, // top: 1500px of 1821px canvas
  'flashcards': 0.620, // top: 1130px — "Sounds"
  'recitation': 0.439, // top: 800px — "Qur'an & Hadith" (current, approved)
  'stories': 0.258, // top: 470px
  'sorting': 0.077, // top: 140px — locked this phase
};

/// The exact overshoot easing the approved preview uses everywhere (nodes,
/// pills, mascot, speech bubble): `cubic-bezier(0.34, 1.56, 0.64, 1)`.
const _overshoot = Cubic(0.34, 1.56, 0.64, 1.0);

enum _NodeState { locked, available, current, completed }

class AdventureMapScreen extends ConsumerStatefulWidget {
  const AdventureMapScreen({super.key});

  @override
  ConsumerState<AdventureMapScreen> createState() => _AdventureMapScreenState();
}

class _AdventureMapScreenState extends ConsumerState<AdventureMapScreen> {
  final _scrollController = ScrollController();
  static const _mapHeight = 1821.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final currentId = ref.read(recentModuleProvider) ?? 'tracing';
      final fraction = _nodePositions[currentId] ?? 0.5;
      final target = (_mapHeight * fraction) - 300;
      _scrollController.jumpTo(target.clamp(0, _mapHeight));
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Same rule `StudentHubScreen` used before this screen replaced it, with
  /// its always-true fallthrough bug fixed: a module only unlocks when the
  /// debug override is on, or a teacher has actually assigned it (per class
  /// homework or this student's own assignment list) — otherwise it's
  /// locked, matching the "Locked by ustadzah" messaging learners already
  /// know from the old Home tab.
  bool _isModuleAssigned(String moduleId) {
    final override = ref.watch(progressionOverrideProvider);
    if (override) return true;

    final classHomeworks = ref.watch(classHomeworkProvider);
    final isClassAssigned = classHomeworks.any((hw) {
      final moduleName = hw['module'] as String? ?? '';
      return _doesModuleNameMatchId(moduleName, moduleId);
    });
    if (isClassAssigned) return true;

    final learner = ref.watch(sessionProvider).learner;
    if (learner != null) {
      final students = ref.watch(teacherRosterProvider);
      final currentStudent = students.firstWhere(
        (s) => s['learnerId'] == learner.id,
        orElse: () => <String, dynamic>{},
      );
      final studentAssigned =
          currentStudent['assignedModules'] as List<dynamic>? ?? [];
      final isStudentAssigned = studentAssigned.any((hw) {
        final moduleText = hw as String? ?? '';
        return _doesModuleNameMatchId(moduleText, moduleId);
      });
      if (isStudentAssigned) return true;
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
          'This module is not currently assigned by your teacher. Please ask your teacher or parent to assign it to you!',
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

  void _onNodeTap(ModuleInfo module, bool isAssigned) {
    if (!isAssigned) {
      _showLockedDialog(module.title);
      return;
    }
    final energy = ref.read(noorEnergyProvider);
    if (!energy.hasEnergy) {
      showNoorEnergyRestingSheet(context);
      return;
    }
    ref.read(noorEnergyProvider.notifier).consume();
    ref.read(recentModuleProvider.notifier).interactWith(module.id);
    context.go('/module/${module.id}');
  }

  @override
  Widget build(BuildContext context) {
    final currentId = ref.watch(recentModuleProvider) ?? 'tracing';
    final learnerAvatar = ref.watch(sessionProvider).learner?.avatar;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _scrollController,
            // `HubShell`'s outer Scaffold uses `extendBody: true` so the
            // floating pill nav doesn't shorten this screen's visible
            // height. No bottom padding here — matching the approved
            // preview exactly, the nav simply floats *over* whatever's
            // currently at the bottom of the scroll, the same way it does
            // in dumps/adventure_map_preview/preview.html. Padding here
            // would just add dead cream space past the image's real end.
            child: SizedBox(
              height: _mapHeight,
              child: Stack(
                children: [
                  const Positioned.fill(child: _MapVideoBackground()),
                  const Positioned.fill(child: _AmbientBreathing()),
                  const _MapSparkles(),
                  for (final (i, module) in coreModules.indexed)
                    _MapNode(
                      key: ValueKey(module.id),
                      module: module,
                      topFraction: _nodePositions[module.id] ?? 0.5,
                      mapHeight: _mapHeight,
                      state: _stateFor(
                        module,
                        currentId,
                        _isModuleAssigned(module.id),
                      ),
                      entranceDelay: Duration(milliseconds: 40 + i * 50),
                      onTap: () =>
                          _onNodeTap(module, _isModuleAssigned(module.id)),
                    ),
                  _MascotAvatar(
                    topFraction: _nodePositions[currentId] ?? 0.5,
                    mapHeight: _mapHeight,
                    avatar: learnerAvatar,
                  ),
                ],
              ),
            ),
          ),
          const SafeArea(child: AdventureMapTopBar()),
        ],
      ),
    );
  }
}

/// Looping muted video behind the map nodes, replacing the static
/// `map_background.png`. Falls back to the still image while the video
/// decodes (or if it fails to load) so there's never a blank/black frame.
///
/// `BoxFit.cover` — same framing the static image always used. (A prior
/// `contain` + scale-down pass was reverted: it left dead cream space
/// below the map instead of filling the screen.)
class _MapVideoBackground extends StatefulWidget {
  const _MapVideoBackground();

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
                fit: BoxFit.cover,
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
    required this.mapHeight,
    required this.state,
    required this.entranceDelay,
    required this.onTap,
  });

  final ModuleInfo module;
  final double topFraction;
  final double mapHeight;
  final _NodeState state;
  final Duration entranceDelay;
  final VoidCallback onTap;

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

  (Color, Color) _colorsFor(_NodeState state) {
    return switch (state) {
      _NodeState.completed => (AppColors.adventureGreen, Colors.white),
      _NodeState.current => (AppColors.gold, Colors.white),
      _NodeState.available => (AppColors.adventureBlue, Colors.white),
      _NodeState.locked => (const Color(0xFFC9C2AE), const Color(0xFF7A8B85)),
    };
  }

  @override
  Widget build(BuildContext context) {
    final isCurrent = widget.state == _NodeState.current;
    final size = isCurrent ? 78.0 : 64.0;
    final (bg, fg) = _colorsFor(widget.state);

    Widget icon = switch (widget.state) {
      _NodeState.locked => const Icon(
        Icons.lock_rounded,
        color: Color(0xFF7A8B85),
      ),
      _NodeState.completed => Icon(Icons.check_rounded, color: fg, size: 28),
      _ => Icon(widget.module.icon, color: fg),
    };

    return Positioned(
      top: widget.mapHeight * widget.topFraction - size / 2,
      left: 130, // matches the approved preview's .node { left: 130px }
      child: Column(
        children: [
          AnimatedBuilder(
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
                  ? (wobbleT < 0.5 ? -4.0 : 4.0) *
                        (1 - (wobbleT - 0.5).abs() * 2)
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
                            child: Container(
                              width: size,
                              height: size,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: bg,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 4,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.25),
                                    blurRadius: 14,
                                    offset: const Offset(0, 6),
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
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.module.title,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.tealDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MascotAvatar extends StatefulWidget {
  const _MascotAvatar({
    required this.topFraction,
    required this.mapHeight,
    required this.avatar,
  });

  final double topFraction;
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
      top: widget.mapHeight * widget.topFraction - 100,
      left: 18, // matches the approved preview's .mascot-wrap { left: 18px }
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
                  left: 78,
                  top: -2,
                  child: Opacity(
                    opacity: t.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: 0.7 + 0.3 * t,
                      alignment: Alignment.centerLeft,
                      child: child,
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
