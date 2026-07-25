import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';
import 'package:flutter/services.dart';

import '../../data/curriculum_data.dart';
import '../../data/models/curriculum/curriculum_models.dart';
import '../theme/app_colors.dart';

/// Classroom cast view for Greeting Match: locked landscape, one big
/// phrase + play button, and a teacher-controlled "Reveal" that flips in
/// the 4 choices with the correct one highlighted — the teacher paces the
/// class's shout-the-answer moment, no timer, no auto-advance.
///
/// Plain/default styling for now, matching the Home Mode widget's
/// structural-pass approach — visual design is a follow-up.
class GreetingMatchCastScreen extends StatefulWidget {
  const GreetingMatchCastScreen({super.key});

  @override
  State<GreetingMatchCastScreen> createState() =>
      _GreetingMatchCastScreenState();
}

class _GreetingMatchCastScreenState extends State<GreetingMatchCastScreen> {
  int _idx = 0;
  bool _revealed = false;

  GreetingQuestion get _question => greetingQuestions[_idx];

  @override
  void initState() {
    super.initState();
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

  void _reveal() => setState(() => _revealed = true);

  void _next() {
    if (_idx + 1 >= greetingQuestions.length) return;
    setState(() {
      _idx++;
      _revealed = false;
    });
  }

  void _previous() {
    if (_idx == 0) return;
    setState(() {
      _idx--;
      _revealed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                  Text(
                    'Greeting ${_idx + 1} / ${greetingQuestions.length}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Center(
                  child: Text(
                    _question.phrase,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              if (_revealed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final choice in _question.choices)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: choice.correct
                                ? AppColors.adventureGreen
                                : Colors.white24,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '${choice.translit} — ${choice.meaning}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: _idx == 0 ? null : _previous,
                    child: const Text('Previous'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _revealed ? null : _reveal,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                    ),
                    child: const Text('Reveal'),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton(
                    onPressed: _idx + 1 >= greetingQuestions.length
                        ? null
                        : _next,
                    child: const Text('Next'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
