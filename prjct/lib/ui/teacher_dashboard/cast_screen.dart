import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../logic/teacher/teacher_providers.dart';
import '../theme/app_colors.dart';

/// Classroom cast screen (mockup Figure 4.6, FR-6.4): forced 16:9
/// landscape presentation view shown on the projector/TV under the
/// zero-student-device model.
class CastScreen extends ConsumerStatefulWidget {
  const CastScreen({super.key});

  @override
  ConsumerState<CastScreen> createState() => _CastScreenState();
}

class _CastScreenState extends ConsumerState<CastScreen>
    with SingleTickerProviderStateMixin {
  int _currentLetterIdx = 0;
  bool _choralPlaying = false;
  bool _voicePlaying = false;

  late final AnimationController _waveController = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );

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
    _waveController.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  void _toggleChoral() {
    setState(() {
      _choralPlaying = !_choralPlaying;
      if (_choralPlaying) {
        _waveController.repeat(reverse: true);
      } else {
        _waveController.stop();
      }
    });
  }

  void _triggerVoice() async {
    if (_voicePlaying) return;
    setState(() => _voicePlaying = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (mounted) setState(() => _voicePlaying = false);
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
    final letter = _castLetters[_currentLetterIdx];

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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              children: [
                // Header Row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.cast_connected,
                        color: AppColors.mintGreen,
                        size: 18,
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
                    // Hot seat chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.gold,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.gold.withValues(alpha: 0.24),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.airline_seat_recline_normal_rounded, size: 14, color: AppColors.ink),
                          SizedBox(width: 6),
                          Text(
                            'Hot Seat: Ali',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Choral Controller chip
                    GestureDetector(
                      onTap: _toggleChoral,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _choralPlaying ? AppColors.teal : Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _choralPlaying ? Colors.transparent : Colors.white24,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _choralPlaying ? Icons.volume_up : Icons.volume_mute,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _choralPlaying ? 'Talqeen Loop: ON' : 'Choral repeat',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Main Content Body
                Expanded(
                  child: Row(
                    children: [
                      // Left Column: Big Glowing Arabic Letter Display
                      Expanded(
                        flex: 4,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white12, width: 1.4),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned(
                                top: 10,
                                left: 14,
                                child: Text(
                                  'Letter ${letter['name']}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white38,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              // Calligraphy Glow
                              Center(
                                child: Container(
                                  width: 140,
                                  height: 140,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.02),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.teal.withValues(alpha: 0.15),
                                        blurRadius: 50,
                                        spreadRadius: 15,
                                      )
                                    ],
                                  ),
                                ),
                              ),
                              Center(
                                child: Text(
                                  letter['char'] as String,
                                  style: const TextStyle(
                                    fontSize: 120,
                                    fontWeight: FontWeight.w100,
                                    color: Colors.white,
                                    fontFamily: 'Roboto',
                                  ),
                                ),
                              ),
                              // Play Voice button overlay
                              Positioned(
                                bottom: 12,
                                child: FloatingActionButton.extended(
                                  onPressed: _triggerVoice,
                                  backgroundColor: _voicePlaying ? AppColors.gold : AppColors.teal,
                                  icon: Icon(
                                    _voicePlaying ? Icons.record_voice_over : Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                  label: Text(
                                    _voicePlaying ? 'Pronouncing...' : 'Play Audio',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
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
                            // Card 2: Student Tracing Simulation & Choral Waveform
                            Expanded(
                              flex: 9,
                              child: Container(
                                padding: const EdgeInsets.all(12),
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
                                        if (_choralPlaying) ...[
                                          const Text(
                                            'CHORAL REPEAT ACTIVE (TALQEEN)',
                                            style: TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                              color: AppColors.mintGreen,
                                              letterSpacing: 1.0,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          AnimatedBuilder(
                                            animation: _waveController,
                                            builder: (context, child) {
                                              return Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  for (int i = 0; i < 15; i++)
                                                    Container(
                                                      width: 3.5,
                                                      height: 6 + (28 * (0.2 + 0.8 * (i % 2 == 0 ? _waveController.value : (1.0 - _waveController.value)))),
                                                      margin: const EdgeInsets.symmetric(horizontal: 3),
                                                      decoration: BoxDecoration(
                                                        color: AppColors.teal,
                                                        borderRadius: BorderRadius.circular(99),
                                                      ),
                                                    ),
                                                ],
                                              );
                                            },
                                          ),
                                        ] else ...[
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: const [
                                              Text(
                                                'HOT SEAT ACCURACY MONITOR',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w800,
                                                  color: AppColors.goldSoft,
                                                  letterSpacing: 1.0,
                                                ),
                                              ),
                                              Text(
                                                '94% MATCH',
                                                style: TextStyle(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.mintGreen,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          const ClipRRect(
                                            borderRadius: BorderRadius.all(Radius.circular(4)),
                                            child: LinearProgressIndicator(
                                              value: 0.94,
                                              minHeight: 8,
                                              backgroundColor: Colors.white10,
                                              color: AppColors.mintGreen,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          const Text(
                                            'Ali is currently tracing the letters on the hot seat device.',
                                            style: TextStyle(fontSize: 10.5, color: Colors.white54),
                                          ),
                                        ],
                                      ],
                                    ),
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
                        child: Container(
                          width: 12,
                          height: 12,
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i == _currentLetterIdx ? AppColors.teal : Colors.transparent,
                            border: Border.all(
                              color: i == _currentLetterIdx ? Colors.transparent : Colors.white30,
                              width: 1.5,
                            ),
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
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.coral,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      onPressed: _confirmEndCast,
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('End cast', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}
