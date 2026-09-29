import 'dart:async';

import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/curriculum/curriculum_models.dart';
import '../../logic/teacher/teacher_providers.dart';
import '../core_modules/lesson_player_screen.dart';
import '../theme/app_colors.dart';
import 'cast_games.dart';
import 'hot_seat_choral.dart';

/// Classroom cast screen (mockup Figure 4.6, FR-6.4): forced 16:9
/// landscape presentation view shown on the projector/TV under the
/// zero-student-device model. One screen, two steps: Hot Seat draws a
/// random student first (FR-6.6), then the teacher picks the game (or a
/// Module Library folder) that student plays in front of the class.
class CastScreen extends ConsumerStatefulWidget {
  const CastScreen({super.key});

  @override
  ConsumerState<CastScreen> createState() => _CastScreenState();
}

class _CastScreenState extends ConsumerState<CastScreen> {
  // Who's on the Hot Seat — games stay locked until someone is drawn.
  String? _hotSeatStudent;
  String? _hotSeatLearnerId;

  @override
  void initState() {
    super.initState();
    // FR-6.4: presentation UI locks to landscape while casting.
    _lockLandscape();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  void _lockLandscape() => SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Opens Android's built-in Cast (Smart View) picker so the teacher can
  // select the classroom Chromecast/Android TV; the OS then mirrors the
  // device screen (this locked-landscape presentation view) to it.
  Future<void> _openCastPicker() async {
    try {
      await const AndroidIntent(
        action: 'android.settings.CAST_SETTINGS',
        flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
      ).launch();
    } on PlatformException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cast isn\'t available on this device.')),
      );
    }
  }

  // Each game plays in its own orientation, as in the student app: start in
  // portrait and the landscape games (Greeting Match, Classroom Heroes,
  // Label Maker, Qur'an Etiquette, Sirah Story) switch themselves on open.
  // Casting mirrors the phone, so portrait games show pillarboxed on the
  // TV. Games reset orientation in their own dispose, so re-lock the cast's
  // landscape view once the class is back here.
  Future<void> _playGame(Lesson lesson, int destinationId) async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    if (!mounted) return;
    final route = MaterialPageRoute<void>(
      builder: (playerContext) => LessonPlayerScreen(
        lesson: lesson,
        destinationId: destinationId,
        classroomPlay: true,
        classroomLearnerId: _hotSeatLearnerId,
        onClose: () => Navigator.of(playerContext).pop(),
      ),
    );
    final closed = Completer<void>();
    final popped = Navigator.of(context, rootNavigator: true).push(route);
    route.animation?.addStatusListener((status) {
      if (status == AnimationStatus.dismissed && !closed.isCompleted) {
        closed.complete();
      }
    });
    await popped;
    // `push` resolves when the pop *starts*; a landscape game's dispose
    // (which forces portrait) runs only once its route is torn down after
    // the exit animation — lock landscape after that, not before.
    await closed.future;
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
    _lockLandscape();
  }

  // The Module Library/builder screens are portrait phone layouts.
  Future<void> _openModuleLibrary() async {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    if (!mounted) return;
    await context.push('/teacher/module-library');
    _lockLandscape();
    final activeClass = ref.read(teacherClassControllerProvider);
    if (activeClass != null) {
      ref.invalidate(classLessonFoldersProvider(activeClass.id));
    }
  }

  void _confirmEndCast() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('End Cast Session?'),
        content: const Text(
          'Are you sure you want to stop casting to the classroom projector?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.coral),
            onPressed: () {
              SystemChrome.setPreferredOrientations([
                DeviceOrientation.portraitUp,
                DeviceOrientation.portraitDown,
              ]);
              Navigator.of(dialogContext).pop();
              context.go('/teacher');
            },
            child: const Text('End Cast'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeClass = ref.watch(activeClassNameProvider);
    final student = _hotSeatStudent;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _confirmEndCast();
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0C1B23), Color(0xFF142C38), Color(0xFF1B3D4E)],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: 960,
                    height: 540,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: Column(
                        children: [
                          _Header(
                            activeClass: activeClass,
                            student: student,
                            onCast: _openCastPicker,
                            onEndCast: _confirmEndCast,
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(
                                  width: 280,
                                  child: _HotSeatPanel(
                                    student: student,
                                    onPicked: (id, name) => setState(() {
                                      _hotSeatLearnerId = id;
                                      _hotSeatStudent = name;
                                    }),
                                    onReset: () => setState(() {
                                      _hotSeatLearnerId = null;
                                      _hotSeatStudent = null;
                                    }),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: CastGamesStage(
                                    student: student,
                                    onPlay: _playGame,
                                    onOpenLibrary: _openModuleLibrary,
                                  ),
                                ),
                              ],
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
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.activeClass,
    required this.student,
    required this.onCast,
    required this.onEndCast,
  });

  final String activeClass;
  final String? student;
  final VoidCallback onCast;
  final VoidCallback onEndCast;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Tooltip(
          message: 'Cast to TV',
          child: InkWell(
            onTap: onCast,
            customBorder: const CircleBorder(),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.mintGreen, AppColors.teal],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.mintGreen.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.cast_connected,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PROJECTOR CAST ACTIVE',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: AppColors.mintGreen,
                  letterSpacing: 1.0,
                ),
              ),
              Text(
                activeClass,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        _StepChip(n: 1, label: 'Hot Seat', done: student != null),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Icon(Icons.chevron_right, size: 16, color: Colors.white38),
        ),
        _StepChip(
          n: 2,
          label: 'Choose a game',
          done: false,
          active: student != null,
        ),
        const SizedBox(width: 14),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.coral, Color(0xFFB8431F)],
            ),
            borderRadius: BorderRadius.circular(11),
            boxShadow: [
              BoxShadow(
                color: AppColors.coral.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            onPressed: onEndCast,
            icon: const Icon(Icons.close, size: 15),
            label: const Text(
              'End cast',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}

class _StepChip extends StatelessWidget {
  const _StepChip({
    required this.n,
    required this.label,
    required this.done,
    this.active = false,
  });

  final int n;
  final String label;
  final bool done;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final lit = done || active;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
      decoration: BoxDecoration(
        color: lit
            ? AppColors.mintGreen.withValues(alpha: done ? 0.18 : 1)
            : Colors.white.withValues(alpha: 0.06),
        border: Border.all(color: lit ? AppColors.mintGreen : Colors.white24),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: lit ? AppColors.ink : Colors.white24,
            child: done
                ? const Icon(Icons.check, size: 12, color: AppColors.mintGreen)
                : Text(
                    '$n',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: lit ? AppColors.mintGreen : Colors.white,
                    ),
                  ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: active && !done
                  ? AppColors.ink
                  : lit
                  ? AppColors.mintGreen
                  : Colors.white60,
            ),
          ),
        ],
      ),
    );
  }
}

/// Step 1 — draw a random student from the active class's roster with the
/// Hot Seat wheel, then show who's up until the teacher spins again.
class _HotSeatPanel extends ConsumerWidget {
  const _HotSeatPanel({
    required this.student,
    required this.onPicked,
    required this.onReset,
  });

  final String? student;
  final void Function(String learnerId, String name) onPicked;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roster = ref.watch(teacherRosterProvider);
    final picked = student;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: picked == null ? AppColors.gold : Colors.white12,
          width: 1.4,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'STEP 1 · HOT SEAT',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: AppColors.gold,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            picked == null
                ? 'Spin to choose a random student'
                : 'This student plays the next game',
            style: const TextStyle(fontSize: 11, color: Colors.white60),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: roster.isEmpty
                ? const Center(
                    child: Text(
                      'No students enrolled yet — enroll students first.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.white54),
                    ),
                  )
                : picked == null
                ? Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: HotSeatWheel(
                        roster: roster,
                        onPicked: onPicked,
                        onSpinningChanged: (_) {},
                      ),
                    ),
                  )
                : _PickedStudent(name: picked, onSpinAgain: onReset),
          ),
        ],
      ),
    );
  }
}

class _PickedStudent extends StatelessWidget {
  const _PickedStudent({required this.name, required this.onSpinAgain});

  final String name;
  final VoidCallback onSpinAgain;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.6, end: 1),
          duration: const Duration(milliseconds: 450),
          curve: Curves.elasticOut,
          builder: (_, s, child) => Transform.scale(scale: s, child: child),
          child: Container(
            width: 96,
            height: 96,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppColors.goldSoft, AppColors.gold],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: 0.4),
                  blurRadius: 24,
                ),
              ],
            ),
            child: Text(
              name.isEmpty ? '?' : name[0].toUpperCase(),
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w900,
                color: Color(0xFF3D2705),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          name,
          key: const ValueKey('cast-hot-seat-student'),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'is on the Hot Seat!',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.goldSoft,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Now choose a game →',
          style: TextStyle(fontSize: 11.5, color: Colors.white60),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white30),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: onSpinAgain,
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Spin again', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }
}
