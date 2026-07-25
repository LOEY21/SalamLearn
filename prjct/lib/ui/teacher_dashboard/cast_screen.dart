import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../logic/teacher/teacher_providers.dart';
import '../theme/app_colors.dart';
import 'hot_seat_choral.dart';

/// Classroom cast screen (mockup Figure 4.6, FR-6.4): forced 16:9
/// landscape presentation view shown on the projector/TV under the
/// zero-student-device model.
class CastScreen extends ConsumerStatefulWidget {
  const CastScreen({super.key});

  @override
  ConsumerState<CastScreen> createState() => _CastScreenState();
}

class _CastScreenState extends ConsumerState<CastScreen> {
  int _currentLetterIdx = 0;

  // Real Hot Seat state (FR-6.6), mirrored here from HotSeatSheet's
  // callbacks — Hot Seat only exists inside an active cast now, so this
  // screen is the single source of truth for who's up and their last
  // recorded tracing accuracy. The left column is permanently the Hot Seat
  // panel (not in the SRS spec for anything else — the big letter/Play
  // Audio display that used to live there is gone), and the right column's
  // second card is permanently the Choral Controller, so neither needs an
  // on/off toggle anymore.
  String? _hotSeatStudent;
  double? _hotSeatAccuracy;

  // Which letter Hot Seat is actively tracing — once set, the vocab card
  // follows this instead of the stepper's _currentLetterIdx, so the class
  // sees the word for whatever the volunteer is actually drawing.
  String? _hotSeatLetterChar;

  final List<Map<String, dynamic>> _castLetters = [
    {
      'char': 'ا',
      'name': 'Alif',
      'word': 'Arnabun',
      'meaning': 'Rabbit',
      'trans': 'أَرْنَبٌ',
      'hint': 'Start from the top and trace straight down.',
    },
    {
      'char': 'ب',
      'name': 'Ba',
      'word': 'Baitun',
      'meaning': 'House',
      'trans': 'بَيْتٌ',
      'hint': 'Trace left to right, curve up, and dot below.',
    },
    {
      'char': 'ت',
      'name': 'Ta',
      'word': 'Tiffahun',
      'meaning': 'Apple',
      'trans': 'تُفَّاحٌ',
      'hint': 'Trace left to right, curve up, and add two dots.',
    },
    {
      'char': 'ج',
      'name': 'Jeem',
      'word': 'Jamalun',
      'meaning': 'Camel',
      'trans': 'جَمَلٌ',
      'hint': 'Trace left, curve around right, and dot in center.',
    },
  ];

  @override
  void initState() {
    super.initState();
    // FR-6.4: presentation UI locks to landscape while casting.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

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
        const SnackBar(
          content: Text('Cast isn\'t available on this device.'),
        ),
      );
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
    final letter = _castLetters.firstWhere(
      (l) => l['char'] == _hotSeatLetterChar,
      orElse: () => _castLetters[_currentLetterIdx],
    );

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
            colors: [
              Color(0xFF0C1B23),
              Color(0xFF142C38),
              Color(0xFF1B3D4E),
            ],
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
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Column(
              children: [
                // Header Row
                Row(
                  children: [
                    Tooltip(
                      message: 'Cast to TV',
                      child: InkWell(
                        onTap: _openCastPicker,
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
                    Column(
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
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Hot Seat indicator — the panel itself is permanently
                    // the left column below, so this chip is just a status
                    // label (who's up / their last accuracy), not a toggle.
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.goldSoft, AppColors.gold],
                        ),
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.gold.withValues(alpha: 0.24),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Row(
                        children: [
                          if (_hotSeatStudent != null) ...[
                            Container(
                              width: 18,
                              height: 18,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: Color(0xFF3D2705),
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                _hotSeatStudent![0].toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFFFE8BF),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ] else ...[
                            const Icon(Icons.airline_seat_recline_normal_rounded, size: 14, color: AppColors.ink),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            _hotSeatStudent == null
                                ? 'Hot Seat'
                                : _hotSeatAccuracy == null
                                ? 'Hot Seat — $_hotSeatStudent'
                                : 'Hot Seat — $_hotSeatStudent · ${_hotSeatAccuracy!.round()}%',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Choral Controller indicator — the player itself is
                    // permanently the right-hand card's content below (each
                    // track has its own play/pause), so this chip is just a
                    // label, not a toggle.
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        border: Border.all(color: Colors.white24),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.volume_up, size: 14, color: Colors.white),
                          SizedBox(width: 6),
                          Text(
                            'Choral controller',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Main Content Body
                Expanded(
                  child: Row(
                    children: [
                      // Left Column: the Hot Seat panel (FR-6.6), permanently
                      // — the big letter/Play Audio display that used to live
                      // here isn't in the SRS spec, this card is designated
                      // for Hot Seat tracing only.
                      Expanded(
                        flex: 4,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white12, width: 1.4),
                          ),
                          padding: const EdgeInsets.all(10),
                          child: SingleChildScrollView(
                            child: HotSeatSheet(
                              onStudentPicked: (name) =>
                                  setState(() => _hotSeatStudent = name),
                              onAttemptSaved: (name, accuracyPct) => setState(() {
                                _hotSeatStudent = name;
                                _hotSeatAccuracy = accuracyPct;
                              }),
                              onLetterChanged: (char) =>
                                  setState(() => _hotSeatLetterChar = char),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Right Column: Vocab, Hot Seat activity tracker & visual waveform
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Card 1: Word & Transliteration
                            Expanded(
                              flex: 10,
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white12, width: 1.4),
                                ),
                                child: Center(
                                  child: SingleChildScrollView(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Text(
                                          'ACTIVE VOCABULARY',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.gold,
                                            letterSpacing: 1.2,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.baseline,
                                          textBaseline: TextBaseline.alphabetic,
                                          children: [
                                            Text(
                                              letter['word'] as String,
                                              style: const TextStyle(
                                                fontSize: 22,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              letter['trans'] as String,
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.gold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'English translation: ${letter['meaning']}',
                                          style: const TextStyle(
                                            fontSize: 12.5,
                                            color: Colors.white70,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          letter['hint'] as String,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontStyle: FontStyle.italic,
                                            color: Colors.white38,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Card 2: Choral Controller (FR-6.6) — permanently
                            // here, embedded directly (never a separate
                            // sheet/screen). Hot Seat's tracing accuracy lives
                            // in the left panel next to the canvas instead of
                            // sharing this card, so the two never compete for
                            // the same slot.
                            Expanded(
                              flex: 9,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white12, width: 1.4),
                                ),
                                child: SingleChildScrollView(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'CHORAL CONTROLLER (TALQEEN)',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.mintGreen,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      const ChoralPlayer(),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Footer row with letter stepper indicators & End Cast
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int i = 0; i < _castLetters.length; i++)
                      GestureDetector(
                        onTap: () => setState(() => _currentLetterIdx = i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: i == _currentLetterIdx ? 22 : 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(99),
                            color: i == _currentLetterIdx
                                ? AppColors.mintGreen
                                : Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                      ),
                    const SizedBox(width: 14),
                    Text(
                      'Question ${_currentLetterIdx + 1} of ${_castLetters.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                      ),
                    ),
                    const Spacer(),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white30),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      onPressed: () {
                        if (_currentLetterIdx > 0) {
                          setState(() => _currentLetterIdx--);
                        }
                      },
                      icon: const Icon(Icons.arrow_back_ios, size: 12),
                      label: const Text('Prev', style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 6),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white30),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      onPressed: () {
                        if (_currentLetterIdx < _castLetters.length - 1) {
                          setState(() => _currentLetterIdx++);
                        }
                      },
                      icon: const Icon(Icons.arrow_forward_ios, size: 12),
                      label: const Text('Next', style: TextStyle(fontSize: 12)),
                    ),
                    const SizedBox(width: 12),
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
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        onPressed: _confirmEndCast,
                        icon: const Icon(Icons.close, size: 15),
                        label: const Text(
                          'End cast',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
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
