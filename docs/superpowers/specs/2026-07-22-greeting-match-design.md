# Greeting Match — Pilot Design

## Context

Project owner wants to eventually replace all core-module games with 7 new
game concepts (Magic Sand Tracer, Greeting Match, Ayah Builder, Daily Du'a
Wheel, Wudhu Master, Clear the Water, Good Deed Tree), each with a Home Mode
(solo, on the child's device) and a Classroom Mode (teacher-controlled,
cast to a TV/projector). That is too large to design and build in one pass.

**Greeting Match is the pilot** — it establishes the pattern the other 6
will follow. Only Greeting Match ships in this round; the other 6 games are
untouched. Magic Sand Tracer already effectively exists as `trace_activity.dart`
and needs no new build.

The existing core modules are documented in `CLAUDE.md` as intentional
placeholders ("no game logic, no real telemetry"). Building real game logic
for Greeting Match is a deliberate, explicit reversal of that for this one
activity — not a signal to rebuild every placeholder.

## Content (final, provided by project owner)

10 questions. Each has one spoken/displayed Arabic greeting phrase and 4
choices (translit + English meaning), exactly one correct — the correct
choice is always the same phrase repeated with its correct meaning; the 3
distractors are other greeting phrases' translit/meaning pairs.

1. As-salāmu ʿalaykum → (d) As-salāmu ʿalaykum — Peace be upon you.
2. Wa ʿalaykum as-salām → (a) Wa ʿalaykum as-salām — And peace be upon you too.
3. Marhaban → (b) Marhaban — Hello / Welcome
4. Ahlan wa sahlan → (c) Ahlan wa sahlan — Welcome
5. Ṣabāḥ al-khayr → (a) Ṣabāḥ al-khayr — Good morning
6. Masāʾ al-khayr → (c) Masāʾ al-khayr — Good evening
7. Maʿa as-salāmah → (b) Maʿa as-salāmah — Goodbye
8. Alḥamdulillāh → (c) Alḥamdulillāh — All praise is due to Allah
9. Jazākallāhu khayran → (a) Jazākallāhu khayran — May Allah reward you with goodness
10. Bārakallāhu fīk → (c) Bārakallāhu fīk — May Allah bless you

Audio: **placeholder for now** (`audioAsset` field left `null`, same pattern
as existing `FlashCard.audioAsset` — tap-to-play button exists but plays
nothing/a stub until real recordings are dropped in).

Visual design/assets: **not yet provided** — this pass builds functional
structure with plain/default styling (existing `AppColors`, `SoftCard`,
button patterns already used elsewhere in the app). Visual redesign is a
follow-up once the project owner provides the asset pack.

## Data model

New types in `lib/data/models/curriculum/curriculum_models.dart`:

```dart
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

class GreetingQuestion {
  const GreetingQuestion({
    required this.id,
    required this.phrase,
    required this.choices,
    this.audioAsset,
  });
  final String id;
  final String phrase;        // the spoken/displayed Arabic phrase (translit)
  final List<GreetingChoice> choices;  // always 4, exactly one correct
  final String? audioAsset;
}
```

`ActivityType` gains `greetingMatch`. `Activity` gains a nullable
`List<GreetingQuestion>? greetingQuestions` field, following the exact
pattern of `cards`/`fiqhItems`/`questions` already on that class.

Seed data (the 10 questions above) goes in `curriculum_data.dart`, added to
an existing or new lesson the project owner designates — for this pilot,
add a new lesson step so it doesn't disturb existing lesson content.

## Home Mode — `lib/ui/core_modules/activities/greeting_match_activity.dart`

Follows the same shape as `pronounce_activity.dart` / `quiz_activity.dart`
(`StatefulWidget`, `cards`-style `questions` list, `xp`, `color`,
`onComplete(xp, accuracyPct, errors)`):

- Progress dots row (same widget pattern as `trace_activity.dart`).
- Tap-to-play button for the phrase (visually plain for now — a bordered
  card with a speaker icon and the phrase text, same structural role as
  `pronounce_activity.dart`'s `_playSound` button; actual audio playback is
  a no-op/stub until real files exist).
- 4 choice buttons/cards, tap to answer.
- Wrong tap: wobble/shake feedback (reuse `trace_activity.dart`'s
  `_wobble` `AnimationController` pattern), no penalty, stays on the same
  question.
- Correct tap: brief green success state, then auto-advance; last question
  triggers `onComplete`.
- Accuracy tracked as (correct-on-first-try count / total questions).

## Classroom Mode — `lib/ui/teacher_dashboard/greeting_match_cast_screen.dart`

A **new, separate** screen — the existing `cast_screen.dart` is tightly
built around letter-tracing Hot Seat + Choral Controller and is not
generalized in this pass (explicitly deferred; revisit only if a later
game needs it too).

- Locked landscape (same `SystemChrome.setPreferredOrientations` pattern as
  `cast_screen.dart`'s `initState`/`dispose`).
- Big phrase display + play button.
- "Reveal" button: flips in the 4 choices with the correct one highlighted
  — teacher controls pacing, no timer, no auto-advance.
- Next/previous question controls for the teacher.
- Entry point: a new button from wherever the teacher currently launches
  Hot Seat casting (`teacher_dashboard_screen.dart` / `class_detail_screen.dart`
  — exact hookup point decided during implementation).

## Explicitly out of scope for this pass

- Real audio files/recordings.
- Final visual design (colors, illustrations, animations beyond basic
  wobble/success feedback) — placeholder styling using existing
  `AppColors`/`SoftCard` only, pending the project owner's asset pack.
- The other 6 games.
- Generalizing `cast_screen.dart` into a multi-activity shell.
- Widget tests (added after visuals are finalized, per repo's normal
  `flutter-flutter-add-widget-test` skill trigger on materially-changed
  widgets).
