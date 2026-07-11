import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../logic/learner/learner_xp_provider.dart';
import '../../logic/recent_module_provider.dart';
import '../theme/app_colors.dart';
import 'module_lessons.dart';
import 'module_registry.dart';


/// Interactive Simulator representing the DFD flow of the Learner's Hub
class ModulePlaceholderScreen extends ConsumerStatefulWidget {
  const ModulePlaceholderScreen({super.key, required this.moduleId});

  final String moduleId;

  @override
  ConsumerState<ModulePlaceholderScreen> createState() =>
      _ModulePlaceholderScreenState();
}

class _ModulePlaceholderScreenState
    extends ConsumerState<ModulePlaceholderScreen>
    with TickerProviderStateMixin {
  String _simState = 'idle';
  bool _simulateInternet = true;
  // ignore: unused_field
  String _validationMsg = '';
  final List<Offset?> _tracePoints = [];
  final _canvasKey = GlobalKey();

  // Two-lesson content selection (shared across every module).
  int _lessonIndex = 0;

  // Tracing activity state. The accuracy bar is computed against a pixel
  // mask of the guide glyph (rasterized once per letter+canvas size) rather
  // than a hand-authored vector path — the app has no vector data for
  // Arabic letters, and rasterizing the same TextPainter the guide itself
  // uses keeps the mask pixel-for-pixel aligned with what the learner sees.
  int _letterIndex = 0;
  Uint8List? _letterMaskAlpha;
  int _maskWidth = 0;
  int _maskHeight = 0;
  String? _maskBuiltForKey;
  double _tracingAccuracy = 0;
  int _panUpdateTick = 0;

  // Stories activity state.
  int _storyPage = 0;

  // Sort & Match activity state.
  List<String> _shuffledRight = [];
  final Set<int> _matchedLeft = {};
  int? _selectedLeftIndex;
  String? _selectedRight;
  String? _wrongRight;

  // Animation controller for floating mascot helper
  late final AnimationController _mascotFloatController;

  @override
  void initState() {
    super.initState();
    _resetSortingRound(widget.moduleId);
    _mascotFloatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (kIsWeb || !Platform.environment.containsKey('FLUTTER_TEST')) {
      _mascotFloatController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _mascotFloatController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ModulePlaceholderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.moduleId != widget.moduleId) {
      _resetSortingRound(widget.moduleId);
      _lessonIndex = 0;
      _letterIndex = 0;
      _storyPage = 0;
      _tracePoints.clear();
      _tracingAccuracy = 0;
    }
  }

  void _selectLesson(int index) {
    setState(() {
      _lessonIndex = index;
      _letterIndex = 0;
      _storyPage = 0;
      _tracePoints.clear();
      _tracingAccuracy = 0;
      _resetSortingRound(widget.moduleId);
    });
  }

  // Rasterizes the guide letter with the same TextPainter styling used to
  // draw it on screen, then reads back the alpha channel as an ink mask —
  // this is what the accuracy bar compares strokes against. Rebuilt
  // whenever the letter or canvas size changes (tracked via [_maskBuiltForKey]
  // so a stale in-flight build from a previous letter doesn't overwrite a
  // newer one after `await`).
  Future<void> _buildLetterMask(
    String letter,
    Size size,
    TextDirection direction,
  ) async {
    final key =
        '$letter-${size.width.toStringAsFixed(1)}x${size.height.toStringAsFixed(1)}';
    if (_maskBuiltForKey == key) return;
    _maskBuiltForKey = key;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final textPainter = TextPainter(
      text: TextSpan(
        text: letter,
        style: const TextStyle(
          fontSize: 110,
          fontWeight: FontWeight.w100,
          color: Colors.black,
        ),
      ),
      textDirection: direction,
    )..layout();
    final offset = Offset(
      (size.width - textPainter.width) / 2,
      (size.height - textPainter.height) / 2,
    );
    textPainter.paint(canvas, offset);
    final picture = recorder.endRecording();
    final image = await picture.toImage(size.width.ceil(), size.height.ceil());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null || !mounted || _maskBuiltForKey != key) return;
    setState(() {
      _letterMaskAlpha = byteData.buffer.asUint8List();
      _maskWidth = image.width;
      _maskHeight = image.height;
    });
  }

  bool _isInk(int x, int y) {
    if (_letterMaskAlpha == null) return false;
    if (x < 0 || y < 0 || x >= _maskWidth || y >= _maskHeight) return false;
    final alphaIndex = (y * _maskWidth + x) * 4 + 3;
    return _letterMaskAlpha![alphaIndex] > 40;
  }

  bool _hasInkNear(int x, int y, int radius) {
    for (var dy = -radius; dy <= radius; dy += 2) {
      for (var dx = -radius; dx <= radius; dx += 2) {
        if (_isInk(x + dx, y + dy)) return true;
      }
    }
    return false;
  }

  /// Two-part heuristic proxy for handwriting accuracy (this app has no real
  /// stroke-recognition engine — see the module's DFD-simulator framing):
  /// precision (are the learner's points landing on the letter's ink?) and
  /// coverage (did they trace enough of the letter's ink to count?).
  void _recomputeTracingAccuracy() {
    if (_letterMaskAlpha == null) return;
    final points = _tracePoints.whereType<Offset>().toList();
    if (points.isEmpty) {
      setState(() => _tracingAccuracy = 0);
      return;
    }

    var onInk = 0;
    for (final p in points) {
      if (_hasInkNear(p.dx.round(), p.dy.round(), 8)) onInk++;
    }
    final precision = onInk / points.length;

    const step = 6;
    var inkSamples = 0;
    var coveredSamples = 0;
    for (var y = 0; y < _maskHeight; y += step) {
      for (var x = 0; x < _maskWidth; x += step) {
        if (!_isInk(x, y)) continue;
        inkSamples++;
        final hit = points.any(
          (p) => (p.dx - x).abs() < 14 && (p.dy - y).abs() < 14,
        );
        if (hit) coveredSamples++;
      }
    }
    final coverage = inkSamples == 0 ? 0.0 : coveredSamples / inkSamples;

    setState(() {
      _tracingAccuracy = ((precision * 0.5 + coverage * 0.5) * 100).clamp(
        0,
        100,
      );
    });
  }

  void _resetSortingRound(String moduleId) {
    if (moduleId != 'sorting') return;
    final lesson = sortingLessons[_lessonIndex];
    _shuffledRight = lesson.pairs.map((p) => p.right).toList()..shuffle();
    _matchedLeft.clear();
    _selectedLeftIndex = null;
    _selectedRight = null;
    _wrongRight = null;
  }

  void _clearCanvas() {
    setState(() {
      _tracePoints.clear();
      _tracingAccuracy = 0;
    });
  }

  void _runDfdSimulation() async {
    if (_simState != 'idle') return;

    // 1. Validate responses
    setState(() {
      _simState = 'validating';
      _validationMsg = 'DFD: Validating learner responses...';
    });
    await Future<void>.delayed(const Duration(milliseconds: 1200));

    // 2. Save progress locally
    if (!mounted) return;
    setState(() {
      _simState = 'savingLocal';
      _validationMsg = 'DFD: Saving progress into local database...';
    });
    ref.read(learnerCompletedTodayProvider.notifier).increment();
    await Future<void>.delayed(const Duration(milliseconds: 1000));

    // 3. Update streak tracker
    if (!mounted) return;
    setState(() {
      _simState = 'updatingStreak';
      _validationMsg = 'DFD: Updating streak tracker...';
    });
    ref.read(learnerStreakProvider.notifier).increment();
    await Future<void>.delayed(const Duration(milliseconds: 1000));

    // 4. Award achievement badges
    if (!mounted) return;
    setState(() {
      _simState = 'awardingBadges';
      _validationMsg = 'DFD: Updating achievement badges...';
    });
    ref
        .read(unlockedBadgesProvider.notifier)
        .unlockBadge('${widget.moduleId.toUpperCase()} Master');
    ref.read(learnerXpProvider.notifier).addXp(50);
    await Future<void>.delayed(const Duration(milliseconds: 1000));

    // 5. Internet Connection Available?
    if (!mounted) return;
    setState(() {
      _simState = 'checkingInternet';
      _validationMsg = 'DFD: Checking internet connection availability...';
    });
    await Future<void>.delayed(const Duration(milliseconds: 800));

    if (_simulateInternet) {
      if (!mounted) return;
      setState(() {
        _simState = 'syncingCloud';
        _validationMsg =
            'DFD: Synchronizing learner progress to cloud server...';
      });
      await Future<void>.delayed(const Duration(milliseconds: 1200));
    }

    if (!mounted) return;
    setState(() {
      _simState = 'finished';
      _validationMsg = 'DFD Flow Complete! All progress synchronized.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final module = coreModules.firstWhere(
      (m) => m.id == widget.moduleId,
      orElse: () => coreModules.first,
    );

    final streak = ref.watch(learnerStreakProvider);
    final completedToday = ref.watch(learnerCompletedTodayProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) context.go('/hub');
      },
      child: Scaffold(
        backgroundColor: AppColors.cream,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Banner
              _buildTopBar(streak, completedToday),

              // Main slate workspace — Mihrab arch frame
              // The lesson tabs live INSIDE the arch, just below the title
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                  child: ClipPath(
                    clipper: _MihrabArchClipper(),
                    child: Container(
                      color: Colors.white,
                      child: CustomPaint(
                        painter: _MihrabBorderPainter(),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 28, 20, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: _simState != 'idle'
                                    ? _buildDfdFlowProgress()
                                    : _buildModuleInteractiveWorkspace(module),
                              ),
                              const SizedBox(height: 10),
                              if (_simState == 'idle')
                                _buildMihrabBottomBar(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom Module Switcher
              if (_simState == 'idle')
                _buildBottomModuleSwitcher(module),
            ],
          ),
        ),
      ),
    );
  }

  // Decorative Bottom Bar with gold accents and rotated diamond center
  Widget _buildMihrabBottomBar() {
    return Container(
      height: 36,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFE2F0EA), // light green card background
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF89B3A2), width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.arrow_left_rounded, color: Color(0xFFEF9F27), size: 18),
          const SizedBox(width: 6),
          Container(
            width: 10,
            height: 10,
            transform: Matrix4.rotationZ(0.785), // Rotate 45 deg to draw a diamond
            decoration: const BoxDecoration(
              color: Color(0xFF0A4F3E),
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.arrow_right_rounded, color: Color(0xFFEF9F27), size: 18),
        ],
      ),
    );
  }

  Widget _buildTopBar(int streak, int completedToday) {
    return Container(
      color: const Color(0xFF0A4F3E), // Deep green header banner from mockup
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Circular Back Button
          GestureDetector(
            onTap: () => context.go('/hub'),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFFFAF6EC), // cream base color
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Color(0xFF0A4F3E), // deep green icon
                size: 20,
              ),
            ),
          ),
          const Spacer(),
          // Center Stars (3 gold stars)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0x22000000), // subtle overlay
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: const [
                Icon(Icons.star_rounded, color: AppColors.gold, size: 18),
                Icon(Icons.star_rounded, color: AppColors.gold, size: 18),
                Icon(Icons.star_rounded, color: AppColors.gold, size: 18),
              ],
            ),
          ),
          const Spacer(),
          // Star Counter Chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF6EC), // cream base color
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.gold, width: 2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(
                  Icons.star_rounded,
                  color: AppColors.gold,
                  size: 16,
                ),
                SizedBox(width: 4),
                Text(
                  '120 Stars',
                  style: TextStyle(
                    color: Color(0xFF0A4F3E), // deep green text
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomModuleSwitcher(ModuleInfo currentModule) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF0A4F3E), // Deep green switcher bar
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final m in coreModules)
            _buildSwitcherTabButton(m, m.id == currentModule.id),
        ],
      ),
    );
  }

  Widget _buildSwitcherTabButton(ModuleInfo module, bool isActive) {
    return GestureDetector(
      onTap: () {
        context.go('/module/${module.id}');
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF1EA689) : const Color(0xFFFCDCA4), // Active teal, inactive gold
          borderRadius: BorderRadius.circular(16),
          boxShadow: isActive
              ? const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              module.icon,
              color: isActive ? Colors.white : const Color(0xFF0A4F3E), // White or deep green
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              module.title,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: isActive ? Colors.white : const Color(0xFF0A4F3E),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Floating mascot helper card with custom animation builder
  Widget _buildMascotCard(ModuleInfo module) {
    return AnimatedBuilder(
      animation: _mascotFloatController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -6 * _mascotFloatController.value), // Float 6px up/down
          child: child,
        );
      },
      child: Container(
        width: 110,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFFD3E7DE), // Green card base from mockup
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF89B3A2), width: 2), // Thin green border
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFBFDCD2)),
              ),
              padding: const EdgeInsets.all(4),
              child: module.illustrationAsset != null
                  ? Image.asset(
                      module.illustrationAsset!,
                      fit: BoxFit.contain,
                      errorBuilder: (context, err, stack) => Lottie.asset(
                        'assets/lottie/owl_idle.json',
                        fit: BoxFit.contain,
                      ),
                    )
                  : Lottie.asset('assets/lottie/owl_idle.json'),
            ),
            const SizedBox(height: 4),
            const Text(
              'Mascot Helper',
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0A4F3E),
              ),
            ),
            Text(
              '(${module.illustrationAsset?.split('/').last ?? "mascot.png"})',
              style: const TextStyle(
                fontSize: 7,
                color: AppColors.textMuted,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // Visual simulation step indicators using Lottie animations
  Widget _buildDfdFlowProgress() {
    Widget animation;
    String friendlyTitle;
    String friendlySubtitle;

    switch (_simState) {
      case 'validating':
        animation = Lottie.asset('assets/lottie/owl_idle.json', height: 120);
        friendlyTitle = "Checking Your Work! 🔍";
        friendlySubtitle = "Let's see how well you traced and answered...";
        break;
      case 'savingLocal':
        animation = Lottie.asset('assets/lottie/goal_target.json', height: 120);
        friendlyTitle = "Saving to Backpack! 🎒";
        friendlySubtitle = "Adding these stars and progress to your local inventory.";
        break;
      case 'updatingStreak':
        animation = Lottie.asset('assets/lottie/flame_streak.json', height: 120);
        friendlyTitle = "Streak Up! 🔥";
        friendlySubtitle = "Keep learning daily to grow your massive streak!";
        break;
      case 'awardingBadges':
        animation = Lottie.asset('assets/lottie/milestone_burst.json', height: 120);
        friendlyTitle = "Badge Unlocked! 🏆";
        friendlySubtitle = "Amazing! You earned the Master badge for this activity!";
        break;
      case 'checkingInternet':
        animation = Lottie.asset('assets/lottie/owl_idle.json', height: 120);
        friendlyTitle = "Looking for Internet... 🌐";
        friendlySubtitle = "Checking if we can send this online to your teacher.";
        break;
      case 'syncingCloud':
        animation = Lottie.asset('assets/lottie/goal_target.json', height: 120);
        friendlyTitle = "Cloud Sync! ☁️";
        friendlySubtitle = "Sending your progress up to our cloud classrooms.";
        break;
      case 'finished':
        animation = Lottie.asset('assets/lottie/practice_complete.json', height: 180);
        friendlyTitle = "Lesson Complete! 🎉";
        friendlySubtitle = "Hurray! You did an outstanding job today!";
        break;
      default:
        animation = const Icon(Icons.check_circle, color: AppColors.teal, size: 60);
        friendlyTitle = "Complete!";
        friendlySubtitle = "All progress saved.";
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Bouncy animation
        animation,
        const SizedBox(height: 12),
        Text(
          friendlyTitle,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: AppColors.teal,
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            friendlySubtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textMuted,
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Star milestones
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildDfdStar(
              active:
                  _simState == 'validating' ||
                  _simState == 'savingLocal' ||
                  _simState == 'updatingStreak' ||
                  _simState == 'awardingBadges' ||
                  _simState == 'checkingInternet' ||
                  _simState == 'syncingCloud' ||
                  _simState == 'finished',
            ),
            _buildDfdStar(
              active:
                  _simState == 'savingLocal' ||
                  _simState == 'updatingStreak' ||
                  _simState == 'awardingBadges' ||
                  _simState == 'checkingInternet' ||
                  _simState == 'syncingCloud' ||
                  _simState == 'finished',
            ),
            _buildDfdStar(
              active:
                  _simState == 'updatingStreak' ||
                  _simState == 'awardingBadges' ||
                  _simState == 'checkingInternet' ||
                  _simState == 'syncingCloud' ||
                  _simState == 'finished',
            ),
            _buildDfdStar(
              active:
                  _simState == 'awardingBadges' ||
                  _simState == 'checkingInternet' ||
                  _simState == 'syncingCloud' ||
                  _simState == 'finished',
            ),
            _buildDfdStar(
              active:
                  _simState == 'checkingInternet' ||
                  _simState == 'syncingCloud' ||
                  _simState == 'finished',
            ),
            if (_simulateInternet)
              _buildDfdStar(
                active: _simState == 'syncingCloud' || _simState == 'finished',
              ),
            _buildDfdStar(active: _simState == 'finished'),
          ],
        ),
        if (_simState == 'finished') ...[
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => context.go('/hub'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.goldSoft, width: 3),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: const Text(
                'Back to Student Hub 🏠',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDfdStar({required bool active}) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Icon(
        Icons.star_rounded,
        size: active ? 24 : 16,
        color: active ? AppColors.gold : Colors.grey.shade300,
      ),
    );
  }

  Widget _buildModuleInteractiveWorkspace(ModuleInfo module) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Module title at the top of the arch (under the dome)
        Center(
          child: Text(
            _getMihrabTitle(module),
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0A4F3E),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Lesson tabs — inside the arch, right below the title
        _buildLessonTabs(module),
        const SizedBox(height: 10),

        // Split layout: content left, mascot card right
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildLessonContent(module),
              ),
              const SizedBox(width: 12),
              Align(
                alignment: Alignment.centerRight,
                child: _buildMascotCard(module),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Bottom controls: Finish Lesson + Online toggle
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _runDfdSimulation,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.teal,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.tealDark, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'Finish Lesson! 🌟',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.neutralTint,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.creamBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_rounded, color: AppColors.teal, size: 16),
                  const SizedBox(width: 4),
                  const Text(
                    'Online',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(width: 4),
                  SizedBox(
                    height: 20,
                    width: 32,
                    child: FittedBox(
                      child: Switch.adaptive(
                        activeThumbColor: AppColors.teal,
                        value: _simulateInternet,
                        onChanged: (v) => setState(() => _simulateInternet = v),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _getMihrabTitle(ModuleInfo module) {
    return switch (module.id) {
      'tracing' => tracingLessons[_lessonIndex].letters[_letterIndex].name,
      'flashcards' => 'Letter Sounds',
      'recitation' => 'Qur\'an & Hadith',
      'stories' => 'Islamic Stories',
      'sorting' => 'Sort & Match',
      _ => 'Islamic Study',
    };
  }

  Widget _buildLessonTabs(ModuleInfo module) {
    final titles = switch (module.id) {
      'tracing' => tracingLessons.map((l) => (l.title, l.subtitle)).toList(),
      'flashcards' =>
        flashcardLessons.map((l) => (l.title, l.subtitle)).toList(),
      'recitation' =>
        recitationLessons.map((l) => (l.title, l.subtitle)).toList(),
      'stories' => storyLessons.map((l) => (l.title, l.subtitle)).toList(),
      'sorting' => sortingLessons.map((l) => (l.title, l.subtitle)).toList(),
      _ => const <(String, String)>[],
    };
    if (titles.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        for (final (i, (title, subtitle)) in titles.indexed) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => _selectLesson(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: 8,
                ),
                decoration: BoxDecoration(
                  color: _lessonIndex == i
                      ? module.color.withValues(alpha: 0.14)
                      : AppColors.neutralTint,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _lessonIndex == i
                        ? module.color
                        : AppColors.creamBorder,
                    width: _lessonIndex == i ? 2.0 : 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: _lessonIndex == i ? module.color : AppColors.ink,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLessonContent(ModuleInfo module) {
    return switch (module.id) {
      'tracing' => _buildTracingActivity(tracingLessons[_lessonIndex]),
      'flashcards' => _buildFlashcardsActivity(flashcardLessons[_lessonIndex]),
      'recitation' => _buildRecitationActivity(recitationLessons[_lessonIndex]),
      'stories' => _buildStoryActivity(storyLessons[_lessonIndex]),
      'sorting' => _buildSortingActivity(sortingLessons[_lessonIndex]),
      _ => Center(child: Icon(module.icon, size: 60, color: module.color)),
    };
  }

  Widget _buildAccuracyBar() {
    final pct = _tracingAccuracy.round();
    final color = pct >= 70
        ? AppColors.mintGreen
        : pct >= 40
        ? AppColors.gold
        : AppColors.coral;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.neutralTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.creamBorder),
      ),
      child: Row(
        children: [
          const Text(
            'Trace:',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 10),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _tracingAccuracy / 100,
                minHeight: 8,
                backgroundColor: Colors.white,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 28,
            child: Text(
              '$pct%',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 11,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTracingActivity(TracingLessonContent lesson) {
    final current = lesson.letters[_letterIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            GestureDetector(
              onTap: _clearCanvas,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.coral.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.coral),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.refresh_rounded, size: 12, color: AppColors.coral),
                    SizedBox(width: 4),
                    Text(
                      'Clear',
                      style: TextStyle(
                        color: AppColors.coral,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final (i, item) in lesson.letters.indexed)
              ChoiceChip(
                showCheckmark: false,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                label: Text(
                  '${item.letter} ${item.name}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _letterIndex == i ? Colors.white : AppColors.ink,
                  ),
                ),
                selectedColor: AppColors.teal,
                backgroundColor: AppColors.neutralTint,
                selected: _letterIndex == i,
                onSelected: (_) => setState(() {
                  _letterIndex = i;
                  _tracePoints.clear();
                  _tracingAccuracy = 0;
                }),
              ),
          ],
        ),
        const SizedBox(height: 6),
        _buildAccuracyBar(),
        const SizedBox(height: 6),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              if (size.width > 0 && size.height > 0) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _buildLetterMask(
                    current.letter,
                    size,
                    Directionality.of(context),
                  );
                });
              }
              return Container(
                key: _canvasKey,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.creamBorder, width: 3),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Text(
                        current.letter,
                        style: const TextStyle(
                          fontSize: 120,
                          fontWeight: FontWeight.w100,
                          color: Color(0x1F2C2C2A),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onPanUpdate: (details) {
                        final renderBox =
                            _canvasKey.currentContext!.findRenderObject()
                                as RenderBox;
                        setState(() {
                          _tracePoints.add(
                            renderBox.globalToLocal(details.globalPosition),
                          );
                          _panUpdateTick++;
                        });
                        if (_panUpdateTick % 6 == 0) {
                          _recomputeTracingAccuracy();
                        }
                      },
                      onPanEnd: (details) {
                        setState(() {
                          _tracePoints.add(null);
                        });
                        _recomputeTracingAccuracy();
                      },
                      child: CustomPaint(
                        painter: _LineSketchPainter(_tracePoints),
                        size: Size.infinite,
                      ),
                    ),
                    if (_tracingAccuracy >= 80)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Lottie.asset(
                          'assets/lottie/milestone_burst.json',
                          height: 60,
                          repeat: false,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFlashcardsActivity(FlashcardLessonContent lesson) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Tap cards to hear pronunciation! 🔊',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Center(
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                for (final card in lesson.cards)
                  _buildFlashcard(card.letter, card.name),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFlashcard(String letter, String name) {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.teal,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            content: Text(
              'Playing phonetic sound for $name... 🔊',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 80,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.creamBorder, width: 3),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.volume_up_rounded,
              color: AppColors.gold,
              size: 14,
            ),
            const SizedBox(height: 2),
            Text(
              letter,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: AppColors.teal,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              name,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecitationActivity(RecitationLessonContent lesson) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          lesson.sourceLabel,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: AppColors.textMuted,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.creamBorder, width: 3),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0F000000),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Text(
                    lesson.arabic,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    lesson.transliteration,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w700,
                      color: AppColors.teal,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    lesson.translation,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppColors.gold,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  content: const Text(
                    'Playing recitation audio... 🎵',
                    style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.bold),
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.goldSoft, width: 2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(
                    Icons.play_circle_fill_rounded,
                    color: AppColors.ink,
                    size: 18,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Play recitation',
                    style: TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStoryActivity(StoryLessonContent lesson) {
    final isLast = _storyPage == lesson.pages.length - 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          lesson.subtitle,
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.creamBorder, width: 3),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0E000000),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: SingleChildScrollView(
              child: Text(
                lesson.pages[_storyPage],
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: _storyPage > 0 ? () => setState(() => _storyPage--) : null,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _storyPage > 0 ? AppColors.teal : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 20),
              ),
            ),
            Row(
              children: [
                for (final (i, _) in lesson.pages.indexed)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == _storyPage
                          ? AppColors.gold
                          : AppColors.creamBorder,
                    ),
                  ),
              ],
            ),
            GestureDetector(
              onTap: isLast ? null : () => setState(() => _storyPage++),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isLast ? Colors.grey.shade200 : AppColors.teal,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isLast ? Icons.check_rounded : Icons.chevron_right_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSortingActivity(SortingLessonContent lesson) {
    final allMatched = _matchedLeft.length == lesson.pairs.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          allMatched
              ? 'All matched! 🎉'
              : 'Tap a term, then its matching answer:',
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    for (final (i, pair) in lesson.pairs.indexed)
                      _buildMatchTile(
                        label: pair.left,
                        isMatched: _matchedLeft.contains(i),
                        isSelected: _selectedLeftIndex == i,
                        onTap: _matchedLeft.contains(i)
                            ? null
                            : () => _onSelectLeft(i),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  children: [
                    for (final right in _shuffledRight)
                      _buildMatchTile(
                        label: right,
                        isMatched: lesson.pairs.any(
                          (p) =>
                              p.right == right &&
                              _matchedLeft.contains(lesson.pairs.indexOf(p)),
                        ),
                        isSelected: _selectedRight == right,
                        isWrong: _wrongRight == right,
                        onTap: () => _onSelectRight(right, lesson),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _onSelectLeft(int index) {
    setState(() {
      _selectedLeftIndex = index;
      _wrongRight = null;
    });
    if (_selectedRight != null) _tryMatch(sortingLessons[_lessonIndex]);
  }

  void _onSelectRight(String right, SortingLessonContent lesson) {
    setState(() {
      _selectedRight = right;
      _wrongRight = null;
    });
    if (_selectedLeftIndex != null) _tryMatch(lesson);
  }

  void _tryMatch(SortingLessonContent lesson) {
    final leftIndex = _selectedLeftIndex!;
    final right = _selectedRight!;
    final isCorrect = lesson.pairs[leftIndex].right == right;
    if (isCorrect) {
      setState(() {
        _matchedLeft.add(leftIndex);
        _selectedLeftIndex = null;
        _selectedRight = null;
      });
    } else {
      setState(() => _wrongRight = right);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        setState(() {
          _selectedLeftIndex = null;
          _selectedRight = null;
          _wrongRight = null;
        });
      });
    }
  }

  Widget _buildMatchTile({
    required String label,
    required bool isMatched,
    required bool isSelected,
    bool isWrong = false,
    VoidCallback? onTap,
  }) {
    final color = isMatched
        ? AppColors.mintGreen
        : isWrong
        ? AppColors.danger
        : isSelected
        ? AppColors.teal
        : AppColors.creamBorder;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isMatched
                ? AppColors.mint
                : isSelected
                ? AppColors.teal.withValues(alpha: 0.1)
                : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: color,
              width: isSelected || isMatched || isWrong ? 3 : 2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x06000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: isMatched ? AppColors.tealDark : AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _LineSketchPainter extends CustomPainter {
  final List<Offset?> points;
  _LineSketchPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.teal
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 6.0;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _MihrabArchClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, size.height * 0.15)
      ..cubicTo(0, size.height * 0.08, size.width * 0.35, 8, size.width / 2, 4)
      ..cubicTo(size.width * 0.65, 8, size.width, size.height * 0.08, size.width, size.height * 0.15)
      ..lineTo(size.width, size.height)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _MihrabBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final paint = Paint()
      ..color = const Color(0xFF89B3A2) // green border
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(2, size.height)
      ..lineTo(2, size.height * 0.15)
      ..cubicTo(2, size.height * 0.08, size.width * 0.35, 6, size.width / 2, 6)
      ..cubicTo(size.width * 0.65, 6, size.width - 2, size.height * 0.08, size.width - 2, size.height * 0.15)
      ..lineTo(size.width - 2, size.height);

    canvas.drawPath(path, paint);

    // Draw gold circular details at bottom curves
    final goldPaint = Paint()
      ..color = const Color(0xFFEF9F27)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(2, size.height * 0.15), 6, goldPaint);
    canvas.drawCircle(Offset(size.width - 2, size.height * 0.15), 6, goldPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
