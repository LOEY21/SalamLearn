# Greeting Match Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the existing `PronounceActivity` (market-basket item-counting drag game, currently used by all 15 `ActivityType.pronounce` lesson slots) with a new "Greeting Match" audio-MCQ game — a Home Mode widget plus a separate teacher Classroom Mode cast screen — using plain/default styling as a functional structure, ready for a visual design pass later.

**Architecture:** New `GreetingQuestion`/`GreetingChoice` data model replaces `FlashCard` for this activity type. `pronounce_activity.dart` is deleted and replaced by `greeting_match_activity.dart` (`GreetingMatchActivity`), still bound to the existing `ActivityType.pronounce` enum value so no other part of the app needs to know the type changed. A new `greeting_match_cast_screen.dart` gives teachers a locked-landscape, teacher-paced reveal view, reachable via a new `/cast-greeting-match` route and a new dashboard tile (separate from the existing letter-tracing `cast_screen.dart`, which is untouched).

**Tech Stack:** Flutter/Dart, no new packages.

---

### Task 1: Data model — `GreetingQuestion` / `GreetingChoice`

**Files:**
- Modify: `prjct/lib/data/models/curriculum/curriculum_models.dart`

- [ ] **Step 1: Add the two new classes**

Insert directly after the `FlashCard` class (after line 44, before `class QuizQ`):

```dart
/// One choice on a [GreetingQuestion] — its translit text, English
/// meaning, and whether it's the correct answer for that question.
/// Distractors are other greetings' translit/meaning pairs, so the
/// wrong choices still read as valid Arabic greetings, not nonsense.
class GreetingChoice {
  const GreetingChoice({
    required this.translit,
    required this.meaning,
    required this.correct,
  });

  final String translit;
  final String meaning;
  final bool correct;
}

/// Greeting Match's content shape: one spoken/displayed greeting phrase
/// and 4 [GreetingChoice]s, exactly one of which is correct — the correct
/// choice is always that same phrase paired with its real meaning.
/// `audioAsset` is nullable for the same placeholder-phase reason as
/// [FlashCard.audioAsset]: the tap-to-play button exists and shows
/// feedback, it just doesn't play a real recording yet.
class GreetingQuestion {
  const GreetingQuestion({
    required this.id,
    required this.phrase,
    required this.choices,
    this.audioAsset,
  });

  final String id;
  final String phrase;
  final List<GreetingChoice> choices;
  final String? audioAsset;
}
```

- [ ] **Step 2: Add the field to `Activity`**

In the same file, find the `Activity` class constructor (around line 175) and add `this.greetingQuestions` to the optional params, and the field declaration after `cards`:

```dart
class Activity {
  const Activity({
    required this.id,
    required this.type,
    required this.title,
    required this.icon,
    required this.xp,
    this.cards,
    this.greetingQuestions,
    this.questions,
    this.panels,
    this.quranLine,
    this.fiqhItems,
    this.fiqhZones,
  });

  final String id;
  final ActivityType type;
  final String title;
  final String icon;
  final int xp;

  /// Used by `trace` (see [FlashCard] doc).
  final List<FlashCard>? cards;

  /// Used by `pronounce`, now Greeting Match (see [GreetingQuestion] doc).
  final List<GreetingQuestion>? greetingQuestions;
  final List<QuizQ>? questions;
  final List<StoryPanel>? panels;
  final QuranSyncLine? quranLine;
  final List<FiqhDragItem>? fiqhItems;
  final List<FiqhDropZone>? fiqhZones;
}
```

Note the `FlashCard` doc comment above `cards` changes from "Used by both
`trace` and `pronounce`" to "Used by `trace`" since `pronounce` no longer
uses `FlashCard`.

- [ ] **Step 3: Verify it compiles**

Run: `cd prjct && flutter analyze lib/data/models/curriculum/curriculum_models.dart`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add prjct/lib/data/models/curriculum/curriculum_models.dart
git commit -m "Add GreetingQuestion/GreetingChoice data model for Greeting Match"
```

---

### Task 2: Content — seed data and 15 call-site swaps

**Files:**
- Modify: `prjct/lib/data/curriculum_data.dart`

- [ ] **Step 1: Replace the `numbersCards` constant with `greetingQuestions`**

Find `const List<FlashCard> numbersCards = [` (line 1196) and its closing
`];`. Replace the entire constant (all its `FlashCard(...)` entries) with:

```dart
const List<GreetingQuestion> greetingQuestions = [
  GreetingQuestion(
    id: 'greet1',
    phrase: 'As-salāmu ʿalaykum',
    choices: [
      GreetingChoice(translit: 'Wa ʿalaykum as-salām', meaning: 'And peace be upon you too.', correct: false),
      GreetingChoice(translit: 'Marhaban', meaning: 'Hello / Welcome', correct: false),
      GreetingChoice(translit: 'Ilā al-liqāʾ', meaning: 'See you again', correct: false),
      GreetingChoice(translit: 'As-salāmu ʿalaykum', meaning: 'Peace be upon you.', correct: true),
    ],
  ),
  GreetingQuestion(
    id: 'greet2',
    phrase: 'Wa ʿalaykum as-salām',
    choices: [
      GreetingChoice(translit: 'Wa ʿalaykum as-salām', meaning: 'And peace be upon you too.', correct: true),
      GreetingChoice(translit: 'Maʿa as-salāmah', meaning: 'Goodbye', correct: false),
      GreetingChoice(translit: 'Marhaban', meaning: 'Hello / Welcome', correct: false),
      GreetingChoice(translit: 'Ṣabāḥ al-khayr', meaning: 'Good morning', correct: false),
    ],
  ),
  GreetingQuestion(
    id: 'greet3',
    phrase: 'Marhaban',
    choices: [
      GreetingChoice(translit: 'Ahlan wa sahlan', meaning: 'Welcome', correct: false),
      GreetingChoice(translit: 'Marhaban', meaning: 'Hello / Welcome', correct: true),
      GreetingChoice(translit: 'Masāʾ al-khayr', meaning: 'Good evening', correct: false),
      GreetingChoice(translit: 'Ilā al-liqāʾ', meaning: 'See you again', correct: false),
    ],
  ),
  GreetingQuestion(
    id: 'greet4',
    phrase: 'Ahlan wa sahlan',
    choices: [
      GreetingChoice(translit: 'Wa ʿalaykum as-salām', meaning: 'And peace be upon you too.', correct: false),
      GreetingChoice(translit: 'Maʿa as-salāmah', meaning: 'Goodbye', correct: false),
      GreetingChoice(translit: 'Ahlan wa sahlan', meaning: 'Welcome', correct: true),
      GreetingChoice(translit: 'Jazākallāhu khayran', meaning: 'May Allah reward you with goodness', correct: false),
    ],
  ),
  GreetingQuestion(
    id: 'greet5',
    phrase: 'Ṣabāḥ al-khayr',
    choices: [
      GreetingChoice(translit: 'Ṣabāḥ al-khayr', meaning: 'Good morning', correct: true),
      GreetingChoice(translit: 'Masāʾ al-khayr', meaning: 'Good evening', correct: false),
      GreetingChoice(translit: 'Ṣabāḥ an-nūr', meaning: 'Good morning – response', correct: false),
      GreetingChoice(translit: 'Marhaban', meaning: 'Hello / Welcome', correct: false),
    ],
  ),
  GreetingQuestion(
    id: 'greet6',
    phrase: 'Masāʾ al-khayr',
    choices: [
      GreetingChoice(translit: 'Masāʾ an-nūr', meaning: 'Good evening – response', correct: false),
      GreetingChoice(translit: 'Ṣabāḥ an-nūr', meaning: 'Good morning – response', correct: false),
      GreetingChoice(translit: 'Masāʾ al-khayr', meaning: 'Good evening', correct: true),
      GreetingChoice(translit: 'Maʿa as-salāmah', meaning: 'Goodbye', correct: false),
    ],
  ),
  GreetingQuestion(
    id: 'greet7',
    phrase: 'Maʿa as-salāmah',
    choices: [
      GreetingChoice(translit: 'Ilā al-liqāʾ', meaning: 'See you again', correct: false),
      GreetingChoice(translit: 'Maʿa as-salāmah', meaning: 'Goodbye', correct: true),
      GreetingChoice(translit: 'Marhaban', meaning: 'Hello / Welcome', correct: false),
      GreetingChoice(translit: 'Alḥamdulillāh', meaning: 'All praise is due to Allah', correct: false),
    ],
  ),
  GreetingQuestion(
    id: 'greet8',
    phrase: 'Alḥamdulillāh',
    choices: [
      GreetingChoice(translit: 'Subḥānallāh', meaning: 'Glory be to Allah', correct: false),
      GreetingChoice(translit: 'Bārakallāhu fīk', meaning: 'May Allah bless you', correct: false),
      GreetingChoice(translit: 'Alḥamdulillāh', meaning: 'All praise is due to Allah', correct: true),
      GreetingChoice(translit: 'Wa ʿalaykum as-salām', meaning: 'And peace be upon you too.', correct: false),
    ],
  ),
  GreetingQuestion(
    id: 'greet9',
    phrase: 'Jazākallāhu khayran',
    choices: [
      GreetingChoice(translit: 'Jazākallāhu khayran', meaning: 'May Allah reward you with goodness', correct: true),
      GreetingChoice(translit: 'Bārakallāhu fīk', meaning: 'May Allah bless you', correct: false),
      GreetingChoice(translit: 'Ilā al-liqāʾ', meaning: 'See you again', correct: false),
      GreetingChoice(translit: 'Maʿa as-salāmah', meaning: 'Goodbye', correct: false),
    ],
  ),
  GreetingQuestion(
    id: 'greet10',
    phrase: 'Bārakallāhu fīk',
    choices: [
      GreetingChoice(translit: 'Alḥamdulillāh', meaning: 'All praise is due to Allah', correct: false),
      GreetingChoice(translit: 'Marhaban', meaning: 'Hello / Welcome', correct: false),
      GreetingChoice(translit: 'Bārakallāhu fīk', meaning: 'May Allah bless you', correct: true),
      GreetingChoice(translit: 'Ṣabāḥ al-khayr', meaning: 'Good morning', correct: false),
    ],
  ),
];
```

- [ ] **Step 2: Swap all 15 call sites from `cards:` to `questions:`**

Every `ActivityType.pronounce` `Activity(...)` currently has
`cards: numbersCards,`. Replace all 15 occurrences with
`greetingQuestions: numbersCards.isEmpty ? [] : greetingQuestions,` — no,
simpler: just replace the line itself. Run:

```bash
cd prjct
python3 - <<'EOF'
import re
path = "lib/data/curriculum_data.dart"
text = open(path, encoding="utf-8").read()
count = text.count("cards: numbersCards,")
text = text.replace("cards: numbersCards,", "greetingQuestions: greetingQuestions,")
open(path, "w", encoding="utf-8").write(text)
print(f"replaced {count} occurrences")
EOF
```

Expected output: `replaced 15 occurrences`

- [ ] **Step 3: Rename the lesson/activity titles and icon**

These lessons are titled "Arabic Numbers Game N" / "Arabic Numbers N" with
a 🧺 basket icon, which no longer matches the content. Run:

```bash
cd prjct
python3 - <<'EOF'
import re
path = "lib/data/curriculum_data.dart"
text = open(path, encoding="utf-8").read()
text = text.replace("Arabic Numbers Game 1", "Greeting Match 1")
text = text.replace("Arabic Numbers Game 2", "Greeting Match 2")
text = text.replace("Arabic Numbers Game 3", "Greeting Match 3")
text = text.replace("Arabic Numbers 1", "Greeting Match 1")
text = text.replace("Arabic Numbers 2", "Greeting Match 2")
text = text.replace("title: 'Arabic Numbers'", "title: 'Greeting Match'")
text = text.replace("🧺", "👋")
open(path, "w", encoding="utf-8").write(text)
EOF
```

- [ ] **Step 4: Verify no leftover references and it compiles**

```bash
cd prjct
grep -n "numbersCards\|cards: numbersCards" lib/data/curriculum_data.dart
```
Expected: no output (empty — `numbersCards` no longer exists anywhere).

```bash
flutter analyze lib/data/curriculum_data.dart
```
Expected: `No issues found!` (this will still show errors from
`greeting_match_activity.dart` not existing yet if you run the full
`flutter analyze` — that's expected until Task 3 lands; scoping to this
one file avoids that noise for now).

- [ ] **Step 5: Commit**

```bash
git add prjct/lib/data/curriculum_data.dart
git commit -m "Replace numbersCards content with Greeting Match question data"
```

---

### Task 3: Home Mode widget — `GreetingMatchActivity`

**Files:**
- Create: `prjct/lib/ui/core_modules/activities/greeting_match_activity.dart`
- Delete: `prjct/lib/ui/core_modules/activities/pronounce_activity.dart`

- [ ] **Step 1: Delete the old file**

```bash
git rm prjct/lib/ui/core_modules/activities/pronounce_activity.dart
```

- [ ] **Step 2: Create the new widget**

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../data/models/curriculum/curriculum_models.dart';
import '../../theme/app_colors.dart';
import '../../widgets/soft_card.dart';

/// Greeting Match Home Mode: play a greeting phrase, tap the choice with
/// its correct meaning among 3 other real (but wrong) greeting phrases.
/// Wrong taps wobble and allow a retry on the same question — no penalty
/// beyond the accuracy/error count reported to [onComplete]. Correct taps
/// flash green and auto-advance.
///
/// Plain/default styling for now — this is a structural pass; the visual
/// design (colors, illustrations, animation) is a follow-up once the
/// project owner provides the asset pack.
class GreetingMatchActivity extends StatefulWidget {
  const GreetingMatchActivity({
    super.key,
    required this.questions,
    required this.xp,
    required this.color,
    required this.onComplete,
  });

  final List<GreetingQuestion> questions;
  final int xp;
  final Color color;
  final void Function(int xp, double accuracyPct, int errors) onComplete;

  @override
  State<GreetingMatchActivity> createState() => _GreetingMatchActivityState();
}

class _GreetingMatchActivityState extends State<GreetingMatchActivity>
    with SingleTickerProviderStateMixin {
  int _idx = 0;
  bool _answeredCorrectly = false;
  int _correctCount = 0;
  int _errors = 0;
  double _wobble = 0.0;
  late final AnimationController _wobbleController;

  GreetingQuestion get _question => widget.questions[_idx];

  @override
  void initState() {
    super.initState();
    _wobbleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..addListener(() {
        final t = _wobbleController.value;
        setState(() {
          _wobble = math.sin(t * math.pi * 3) * 8 * (1 - t);
        });
      });
  }

  @override
  void dispose() {
    _wobbleController.dispose();
    super.dispose();
  }

  // FIREBASE/HIVE PLUG POINT: plays widget.audioAsset once real greeting
  // recordings exist; currently a no-op since audio is placeholder-phase
  // (see GreetingQuestion.audioAsset doc).
  void _playPhrase() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '🔊 "${_question.phrase}"',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        duration: const Duration(milliseconds: 700),
        behavior: SnackBarBehavior.floating,
        backgroundColor: widget.color,
      ),
    );
  }

  void _handleChoice(GreetingChoice choice) {
    if (_answeredCorrectly) return;
    if (choice.correct) {
      setState(() {
        _answeredCorrectly = true;
        _correctCount++;
      });
      Future.delayed(const Duration(milliseconds: 650), _next);
    } else {
      setState(() => _errors++);
      _wobbleController.forward(from: 0);
    }
  }

  void _next() {
    if (!mounted) return;
    if (_idx + 1 >= widget.questions.length) {
      final totalAttempts = _correctCount + _errors;
      final accuracyPct = totalAttempts == 0
          ? 100.0
          : _correctCount / totalAttempts * 100;
      widget.onComplete(widget.xp, accuracyPct, _errors);
    } else {
      setState(() {
        _idx++;
        _answeredCorrectly = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < widget.questions.length; i++) ...[
                if (i != 0) const SizedBox(width: 5),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: i == _idx ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i < _idx
                        ? AppColors.adventureGreen
                        : i == _idx
                        ? widget.color
                        : AppColors.creamDark,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Greeting Match',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: widget.color,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Listen, then tap what it means',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 18),
          Transform.translate(
            offset: Offset(_wobble, 0),
            child: GestureDetector(
              onTap: _playPhrase,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: widget.color, width: 2.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🔊', style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 8),
                    Text(
                      _question.phrase,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: widget.color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.separated(
              itemCount: _question.choices.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final choice = _question.choices[i];
                final revealed = _answeredCorrectly && choice.correct;
                return SoftCard(
                  color: revealed ? AppColors.mint : AppColors.surface,
                  borderColor: revealed ? AppColors.adventureGreen : null,
                  onTap: () => _handleChoice(choice),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              choice.translit,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                              ),
                            ),
                            Text(
                              choice.meaning,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (revealed)
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.adventureGreen,
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Verify it compiles**

Run: `cd prjct && flutter analyze lib/ui/core_modules/activities/greeting_match_activity.dart`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add prjct/lib/ui/core_modules/activities/greeting_match_activity.dart
git commit -m "Replace PronounceActivity's basket game with GreetingMatchActivity"
```

---

### Task 4: Wire into `LessonPlayerScreen`

**Files:**
- Modify: `prjct/lib/ui/core_modules/lesson_player_screen.dart`

- [ ] **Step 1: Swap the import**

Find:
```dart
import 'activities/pronounce_activity.dart';
```
Replace with:
```dart
import 'activities/greeting_match_activity.dart';
```

- [ ] **Step 2: Swap the switch case**

Find (around line 444):
```dart
      ActivityType.pronounce => PronounceActivity(
        key: ValueKey(activity.id),
        cards: activity.cards!,
        xp: activity.xp,
        color: lessonColor,
        onComplete: _handleActivityComplete,
      ),
```
Replace with:
```dart
      ActivityType.pronounce => GreetingMatchActivity(
        key: ValueKey(activity.id),
        questions: activity.greetingQuestions!,
        xp: activity.xp,
        color: lessonColor,
        onComplete: _handleActivityComplete,
      ),
```

- [ ] **Step 3: Verify it compiles**

Run: `cd prjct && flutter analyze lib/ui/core_modules/lesson_player_screen.dart`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add prjct/lib/ui/core_modules/lesson_player_screen.dart
git commit -m "Wire GreetingMatchActivity into LessonPlayerScreen"
```

---

### Task 5: Update the existing lesson-player test

**Files:**
- Modify: `prjct/test/ui/core_modules/lesson_player_screen_test.dart`

The existing test (`_twoPronounceActivityLesson`) already targeted UI text
("1/2", "✓ Done!") and an icon (`Icons.play_arrow_rounded`) that don't
match *either* the old or the new `pronounce` widget — it was already
stale before this change. Rewrite it end-to-end against the new widget's
actual behavior.

- [ ] **Step 1: Replace the whole file**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/data/models/curriculum/curriculum_models.dart';
import 'package:salamlearn/logic/auth/session.dart';
import 'package:salamlearn/logic/learner/learner_xp_provider.dart';
import 'package:salamlearn/ui/core_modules/lesson_complete_screen.dart';
import 'package:salamlearn/ui/core_modules/lesson_player_screen.dart';

/// No real Hive I/O — `LessonPlayerScreen` awards XP through
/// `learnerXpProvider` on lesson completion, which normally reads/writes a
/// real Hive box. Unlike this repo's other Hive-avoidance fakes (which only
/// override `build()` since they never trigger a write), this test actually
/// drives lesson completion, so `addXp` itself must be overridden too —
/// otherwise it falls through to the real implementation's
/// `Hive.box(...)` call and throws `HiveError: Box not found`.
class _FakeLearnerXpNotifier extends LearnerXpNotifier {
  @override
  int build() => 0;

  @override
  void addXp(int amount) => state = state + amount;
}

/// `LessonPlayerScreen` also reads `sessionProvider` on lesson completion to
/// write a `ProgressRecord` (FR-5.1) — `SessionNotifier.build()` normally
/// reads the real Hive `settings` box, so it needs the same override
/// treatment as `learnerXpProvider` above. Returning a learner-less state
/// keeps the write a no-op without needing a real Hive box for progress
/// either.
class _FakeSessionNotifier extends SessionNotifier {
  @override
  SessionState build() => const SessionState();
}

Lesson _twoGreetingMatchActivityLesson() {
  const questionA = GreetingQuestion(
    id: 'q1',
    phrase: 'As-salāmu ʿalaykum',
    choices: [
      GreetingChoice(translit: 'Marhaban', meaning: 'Hello', correct: false),
      GreetingChoice(
        translit: 'As-salāmu ʿalaykum',
        meaning: 'Peace be upon you.',
        correct: true,
      ),
    ],
  );
  const questionB = GreetingQuestion(
    id: 'q2',
    phrase: 'Marhaban',
    choices: [
      GreetingChoice(translit: 'Marhaban', meaning: 'Hello', correct: true),
      GreetingChoice(
        translit: 'Maʿa as-salāmah',
        meaning: 'Goodbye',
        correct: false,
      ),
    ],
  );
  return const Lesson(
    id: 'test-lesson',
    title: 'Test Lesson',
    titleAr: 'درس تجريبي',
    icon: '📘',
    color: '#0F6E56',
    xp: 20,
    activities: [
      Activity(
        id: 'a1',
        type: ActivityType.pronounce,
        title: 'Greeting One',
        icon: '👋',
        xp: 10,
        greetingQuestions: [questionA],
      ),
      Activity(
        id: 'a2',
        type: ActivityType.pronounce,
        title: 'Greeting Two',
        icon: '👋',
        xp: 10,
        greetingQuestions: [questionB],
      ),
    ],
  );
}

void main() {
  testWidgets(
    'activities auto-advance with no manual "start next activity" step, '
    'and finishing the lesson awards XP/streak/badge then shows completion',
    (tester) async {
      final lesson = _twoGreetingMatchActivityLesson();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            learnerXpProvider.overrideWith(_FakeLearnerXpNotifier.new),
            sessionProvider.overrideWith(_FakeSessionNotifier.new),
          ],
          child: MaterialApp(
            home: LessonPlayerScreen(
              lesson: lesson,
              destinationId: 1,
              onClose: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      // First activity's single correct choice is visible.
      expect(find.text('As-salāmu ʿalaykum'), findsWidgets);
      expect(find.byType(LessonCompleteScreen), findsNothing);

      // Tap the correct choice — auto-advances after a short delay.
      await tester.tap(find.text('Peace be upon you.'));
      await tester.pump(const Duration(milliseconds: 700));

      // Auto-advanced straight into the second activity.
      expect(find.text('Marhaban'), findsWidgets);
      expect(find.byType(LessonCompleteScreen), findsNothing);

      // Finish the last activity.
      await tester.tap(find.text('Hello'));
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.byType(LessonCompleteScreen), findsOneWidget);
      expect(find.text('+20 XP'), findsOneWidget);
    },
  );
}
```

- [ ] **Step 2: Run the test**

Run: `cd prjct && flutter test test/ui/core_modules/lesson_player_screen_test.dart`
Expected: `All tests passed!`

- [ ] **Step 3: Commit**

```bash
git add prjct/test/ui/core_modules/lesson_player_screen_test.dart
git commit -m "Update lesson player test for GreetingMatchActivity"
```

---

### Task 6: Classroom Mode — `GreetingMatchCastScreen`

**Files:**
- Create: `prjct/lib/ui/teacher_dashboard/greeting_match_cast_screen.dart`
- Modify: `prjct/lib/logic/router/app_router.dart`
- Modify: `prjct/lib/ui/teacher_dashboard/teacher_dashboard_screen.dart`

- [ ] **Step 1: Create the cast screen**

A separate, purpose-built screen — not a generalization of the existing
`cast_screen.dart` (that stays exactly as-is for letter-tracing Hot Seat).

```dart
import 'package:flutter/material.dart';
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
```

- [ ] **Step 2: Add the route**

In `app_router.dart`, add the import near the other teacher screen
imports:
```dart
import '../../ui/teacher_dashboard/greeting_match_cast_screen.dart';
```

Add the route next to the existing `/cast` route:
```dart
      GoRoute(path: '/cast', builder: (_, _) => const CastScreen()),
      GoRoute(
        path: '/cast-greeting-match',
        builder: (_, _) => const GreetingMatchCastScreen(),
      ),
```

No change needed to `adminPaths` — it gates via `path.startsWith`, and
`/cast-greeting-match` already starts with `/cast`.

- [ ] **Step 3: Add a dashboard entry point**

In `teacher_dashboard_screen.dart`, find the `_ActionColumn.build` method's
`specs` list (around line 1758) and add one more entry after the "Module
library" entry:

```dart
          (
            icon: Icons.campaign_rounded,
            label: 'Cast Greeting Match',
            color: AppColors.teal,
            bg: AppColors.mint,
            onTap: () => context.push('/cast-greeting-match'),
          ),
```

Check the top of the file already imports `package:go_router/go_router.dart`
for `context.push` — the existing `context.push('/teacher/module-library')`
call two lines above confirms it does, so no new import is needed.

- [ ] **Step 4: Verify it compiles**

```bash
cd prjct
flutter analyze lib/ui/teacher_dashboard/greeting_match_cast_screen.dart lib/logic/router/app_router.dart lib/ui/teacher_dashboard/teacher_dashboard_screen.dart
```
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add prjct/lib/ui/teacher_dashboard/greeting_match_cast_screen.dart prjct/lib/logic/router/app_router.dart prjct/lib/ui/teacher_dashboard/teacher_dashboard_screen.dart
git commit -m "Add Greeting Match classroom cast screen and dashboard entry point"
```

---

### Task 7: Full verification

**Files:** none (verification only)

- [ ] **Step 1: Full analyze**

```bash
cd prjct && flutter analyze
```
Expected: `No issues found!` (aside from any pre-existing issues unrelated
to this change — if any appear, confirm they exist on `master` before this
branch too; don't fix unrelated pre-existing issues as part of this plan).

- [ ] **Step 2: Full test suite**

```bash
cd prjct && flutter test
```
Expected: all tests pass, including the rewritten
`test/ui/core_modules/lesson_player_screen_test.dart`.

- [ ] **Step 3: Manual smoke check**

Per this repo's `verify` skill convention: run the app, open a lesson that
contains a "Greeting Match" activity (any of the 15 renamed lessons, e.g.
Destination 1's "Greeting Match 1"), play through it (tap play, tap a
wrong choice to see the wobble/retry, tap the correct choice to see
auto-advance), and separately open Teacher Dashboard → "Cast Greeting
Match" to confirm the classroom screen locks landscape, reveals choices,
and Previous/Next navigate correctly.
