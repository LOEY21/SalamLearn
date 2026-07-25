// Ports the type definitions from Wireframe 0.3's `src/data/curriculum.ts`
// (lines 1-40) — see that file for the source of truth on shape/naming.
//
// `flashcard`/`match`/`sort` (Wireframe 0.3 port) retired in favor of the
// capstone spec's real 5 core modules (FR-4.1–4.5): `trace` (FR-4.1),
// `pronounce` (FR-4.2), `story` (FR-4.4, unchanged — already matched),
// `fiqhDrag` (FR-4.5). `quiz` isn't one of the 5 FR modules but is kept as
// an optional 6th assessment layer per the project owner's call. FR-4.3's
// original `quranSync` ("Supplication Stepping Stones") was retired in
// favor of `ayahBuilder` (Ayah Builder).
enum ActivityType { trace, pronounce, story, fiqhDrag, quiz, harakatPop, ayahBuilder, quranSync }

enum DestinationState { completed, current, locked }

/// FR-4.1/FR-4.2's shared content shape — a single Arabic word/letter with
/// its translit + translation. `trace` activities look up the letter's own
/// guide path from `TraceActivity`'s per-letter table (extracted from the
/// Cairo font's glyph outlines, not stored per-word here); `pronounce`
/// activities render it as a tap-to-play card. Same class, two different
/// activities, since both are "show one Arabic word and let the learner
/// interact with it" at heart.
class FlashCard {
  const FlashCard({
    required this.id,
    required this.emoji,
    required this.arabic,
    required this.translit,
    required this.english,
    required this.color,
    this.audioAsset,
  });

  final String id;
  final String emoji;
  final String arabic;
  final String translit;
  final String english;
  final String color;

  /// FR-4.2's "native media playback" asset — nullable because this app is
  /// in its placeholder phase with no recorded audio yet (per project
  /// owner's call); `PronounceActivity` shows its tap/waveform feedback
  /// either way and simply skips playback when this is null.
  final String? audioAsset;
}

/// One choice on a [GreetingQuestion] — its translit text, English
/// meaning, and whether it's the correct answer for that question.
/// Distractors are other greetings' translit/meaning pairs, so the
/// wrong choices still read as valid Arabic greetings, not nonsense.
class GreetingChoice {
  const GreetingChoice({
    required this.translit,
    required this.meaning,
    required this.correct,
    required this.emoji,
  });

  final String translit;
  final String meaning;
  final bool correct;

  /// One glyph shown on the choice card (e.g. 🕊️ for "Peace be upon you").
  final String emoji;
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
    required this.arabic,
    required this.choices,
    this.audioAsset,
  });

  final String id;
  final String phrase;

  /// The prompt's Arabic script (e.g. "اَلسَّلامُ عَلَيْكُم").
  final String arabic;
  final List<GreetingChoice> choices;
  final String? audioAsset;
}

class QuizQ {
  const QuizQ({
    required this.id,
    required this.emoji,
    required this.question,
    this.questionAr,
    required this.options,
    required this.correct,
    this.tip,
  });

  final String id;
  final String emoji;
  final String question;
  final String? questionAr;
  final List<String> options;
  final int correct;
  final String? tip;
}

class StorySceneItem {
  const StorySceneItem({
    required this.emoji,
    required this.x,
    required this.y,
    required this.size,
    this.flip,
  });

  final String emoji;
  final num x;
  final num y;
  final num size;
  final bool? flip;
}

class StoryBubble {
  const StoryBubble({required this.text, this.ar, required this.side});

  final String text;
  final String? ar;
  final String side;
}

class StoryPanel {
  const StoryPanel({
    required this.id,
    required this.bg,
    required this.scene,
    this.bubble,
    required this.caption,
    this.captionAr,
  });

  final String id;
  final String bg;
  final List<StorySceneItem> scene;
  final StoryBubble? bubble;
  final String caption;
  final String? captionAr;
}

/// FR-4.5's "validates if a dragged item ID matches a target drop-zone ID"
/// — one draggable chip. [correctZoneId] must equal a [FiqhDropZone.id] in
/// the same activity's `fiqhZones` list. Covers both of the FR's own
/// example shapes with one model: an *ordered array* (zones are numbered
/// slots, e.g. Wudu steps 1→4) and a *binary sort* (zones are two named
/// buckets, e.g. Halal/Haram) — the distinction lives entirely in how
/// `fiqhZones` is authored, not in a separate class.
class FiqhDragItem {
  const FiqhDragItem({
    required this.id,
    required this.emoji,
    required this.label,
    this.labelAr,
    required this.correctZoneId,
  });

  final String id;
  final String emoji;
  final String label;
  final String? labelAr;
  final String correctZoneId;
}

class FiqhDropZone {
  const FiqhDropZone({required this.id, required this.label, this.icon});

  final String id;
  final String label;

  /// Optional leading glyph for the zone chip itself (e.g. an order number
  /// "1", or a small icon like "✅"/"❌" for binary zones).
  final String? icon;
}

/// Ayah Builder's content shape: one Ayah (or standalone phrase like the
/// Basmalah) split into its ordered Arabic words, each paired with a
/// transliteration — the learner listens, then drags the word cards into
/// the blanks in the correct order. [englishMeaning] is revealed once the
/// Ayah is fully (and correctly) assembled. `audioAsset` is nullable for
/// the same placeholder-phase reason as [FlashCard.audioAsset]; without it,
/// `AyahBuilderActivity` substitutes a SnackBar reading out the
/// transliteration while still driving the word-by-word highlight.
/// FR-4.3's "highlights text strings ... synchronously with audio
/// timestamps" — one Arabic line (ayah/hadith excerpt), word-by-word, each
/// word paired with the millisecond offset (from the start of the clip)
/// at which it should highlight. `audioAsset` is nullable for the same
/// placeholder-phase reason as `FlashCard.audioAsset`; without it,
/// `QuranSyncActivity` drives the highlight off a plain timer instead of
/// real playback position, so the sync behavior is still exercisable.
class QuranSyncLine {
  const QuranSyncLine({
    required this.id,
    required this.arabicWords,
    required this.translitWords,
    required this.wordTimestampsMs,
    required this.totalDurationMs,
    this.audioAsset,
    this.reference,
  });

  final String id;
  final List<String> arabicWords;
  final List<String> translitWords;

  /// One timestamp per word, same length/order as [arabicWords].
  final List<int> wordTimestampsMs;
  final int totalDurationMs;
  final String? audioAsset;

  /// e.g. "Surah Al-Fatiha, 1:1" or "Hadith — Sahih al-Bukhari" — shown as
  /// a small caption above the line.
  final String? reference;
}

class AyahBuilderLevel {
  const AyahBuilderLevel({
    required this.id,
    required this.reference,
    required this.arabicWords,
    required this.translitWords,
    required this.englishMeaning,
    this.audioAsset,
  });

  final String id;

  /// e.g. "Surah Al-Fātiḥah (Ayah 1)".
  final String reference;

  /// Same length/order as [translitWords] — one entry per draggable word.
  final List<String> arabicWords;
  final List<String> translitWords;
  final String englishMeaning;
  final String? audioAsset;
}

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
    this.ayahLevels,
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

  /// Used by `ayahBuilder` (see [AyahBuilderLevel] doc).
  final List<AyahBuilderLevel>? ayahLevels;
}

class Lesson {
  const Lesson({
    required this.id,
    required this.title,
    required this.titleAr,
    required this.icon,
    required this.color,
    required this.xp,
    required this.activities,
  });

  final String id;
  final String title;
  final String titleAr;
  final String icon;
  final String color;
  final int xp;
  final List<Activity> activities;
}

class Destination {
  const Destination({
    required this.id,
    required this.name,
    required this.nameAr,
    required this.icon,
    required this.color,
    required this.bg,
    required this.mapX,
    required this.mapY,
    required this.description,
    required this.state,
    required this.lessons,
  });

  final int id;
  final String name;
  final String nameAr;
  final String icon;
  final String color;
  final String bg;
  final num mapX;
  final num mapY;
  final String description;
  final DestinationState state;
  final List<Lesson> lessons;
}
