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
enum ActivityType {
  trace,
  pronounce,
  story,
  fiqhDrag,
  quiz,
  harakatPop,
  ayahBuilder,
  quranSync,
  creationHunt,
  classroomHeroes,
  sirahStory,
  quranEtiquette,
  fivePillars,
  goodDeedTree,
  taharahAdventure,
}

/// The Five Pillars' two sessions: answer five scenarios one pillar at a
/// time (Session 1), or build all five in order (Session 2).
enum FivePillarsMode { scenarios, ordering }

/// The Good Deed Tree's two sessions: Roots & Branches (Session 1) and
/// Flowers & Fruits (Session 2).
enum GoodDeedTreeSession { rootsAndBranches, flowersAndFruits }

/// Taharah Adventure's three sessions: Clean or Dirty? (Session 1), Wudhu
/// Part 1 (Session 2, steps 1-5) and Wudhu Part 2 (Session 3, steps 6-10).
enum TaharahSession { cleanOrDirty, wudhuPart1, wudhuPart2 }

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

/// One draggable word card in an [AyahBuilderSession] — its Arabic text and
/// transliteration. The card's correct slot is its position in
/// [AyahBuilderSession.words].
class AyahBuilderWord {
  const AyahBuilderWord(this.text, this.transliteration);

  final String text;
  final String transliteration;
}

/// One session of Ayah Builder: a single ayah split into its ordered word
/// cards — the learner listens, then drags the cards into the numbered
/// slots in order.
///
/// The seven sessions are authored in `curriculum_data.dart` as
/// `ayahBuilderSessions` and distributed across the stages exactly as the
/// source prototype lists them (Stage 2-7, two in Stage 6). Every session
/// opens on the same start screen.
class AyahBuilderSession {
  const AyahBuilderSession({
    required this.stage,
    required this.label,
    required this.sessionName,
    required this.short,
    required this.englishTranslation,
    required this.cheer,
    required this.words,
  });

  /// The stage (Destination id) this session is played in.
  final int stage;

  /// e.g. "Session 1".
  final String label;

  /// e.g. "The Basmalah".
  final String sessionName;

  /// Used in "Let's build [short] together!".
  final String short;
  final String englishTranslation;

  /// The mascot's line on the reward screen.
  final String cheer;
  final List<AyahBuilderWord> words;
}

/// One tappable region in an [CreationHuntStage]'s artwork — a hitbox
/// expressed as a fraction of the 393x852 reference frame the stage art was
/// drawn against, so it scales with the background instead of being pinned
/// to device pixels.
///
/// [x]/[y] are the *centre* of the box, [w]/[h] its size, all 0..1.
/// [isCreation] splits the two verdicts the game teaches: things Allah
/// created (a find) versus things people made (a decoy).
class CreationHuntSpot {
  const CreationHuntSpot({
    required this.id,
    required this.isCreation,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.radius,
    required this.icon,
    this.label,
    this.group,
    this.alias = false,
  });

  final String id;
  final bool isCreation;
  final double x;
  final double y;
  final double w;
  final double h;

  /// Corner rounding for the highlight ring, as an `BorderRadius`-style
  /// description of the artwork's shape — see [CreationHuntSpot.borderRadius].
  /// Mirrors the source design's per-spot CSS `border-radius` (e.g. a round
  /// sun versus a boxy car), so the found-ring hugs the thing it circles.
  final CreationHuntRadius radius;

  /// Emoji shown on the verdict card and in the token tray slot.
  final String icon;

  /// Reader-friendly name used in the verdict copy ("Allah created the
  /// **tree**"). Falls back to [id] when null.
  final String? label;

  /// Several spots can stand for the same creation (five separate pine
  /// trees all counting as "tree"). The first is the canonical one; the
  /// rest set [alias] and point [group] at it, so tapping any of them
  /// fills the same single token.
  final String? group;
  final bool alias;

  String get key => group ?? id;
  String get name => label ?? id;
}

/// The handful of corner-rounding shapes the stage artwork needs. Kept as a
/// closed set rather than a raw CSS string so the Flutter side can build a
/// real [BorderRadius] without parsing.
enum CreationHuntRadius {
  /// Fully round — sun, moon, bird, ball.
  circle,

  /// Rounded top, squarer base — a tree canopy, a mountain, a tent.
  domed,

  /// Tall rounded blob — a hot-air balloon, a cat.
  blob,

  /// A gently rounded rectangle — a car, a bench, a patch of grass.
  soft,

  /// A kite's diamond.
  diamond,
}

/// One stage of Allah's Creation Hunt: a single illustrated scene, the
/// spots hidden in it, and the line of instruction shown over it.
///
/// The three stages (Forest / Sky / Garden) are authored in
/// `curriculum_data.dart` and handed to the game one at a time — each
/// session plays exactly one stage, but every session opens on the same
/// title and how-to screens.
class CreationHuntStage {
  const CreationHuntStage({
    required this.name,
    required this.icon,
    required this.background,
    required this.instruction,
    required this.spots,
    this.hudAtBottom = false,
    this.instructionAtTop = false,
  });

  /// e.g. "The Forest" — used in the completion line.
  final String name;
  final String icon;

  /// Full-bleed scene asset (393x852-ish portrait artwork).
  final String background;
  final String instruction;
  final List<CreationHuntSpot> spots;

  /// The Sky scene's own art fills the top of the frame, so its HUD moves
  /// to the bottom rather than covering the sun and moon.
  final bool hudAtBottom;

  /// The Garden scene is busiest at the bottom, so its instruction line
  /// sits high instead.
  final bool instructionAtTop;

  /// Creations only, aliases collapsed — the number the learner must find.
  List<CreationHuntSpot> get creations =>
      spots.where((s) => s.isCreation && !s.alias).toList();
}

/// One classroom scenario in Classroom Heroes: the illustrated moment, the
/// question asked about it, the two choices, and the line said back when the
/// good one is picked.
///
/// Always exactly two choices — one right, one decoy — because the game's
/// whole teaching move is "this or that, which is the hero choice?".
class ClassroomHeroesQuestion {
  const ClassroomHeroesQuestion({
    required this.scenarioImage,
    required this.promptText,
    required this.correctText,
    required this.decoyText,
    required this.successFeedback,
  });

  final String scenarioImage;
  final String promptText;
  final String correctText;
  final String decoyText;
  final String successFeedback;
}

/// One session of Classroom Heroes — a single good-manners theme (respect,
/// kindness, responsibility, teamwork) and the three scenarios that teach it.
///
/// The four sessions are authored in `curriculum_data.dart` and distributed
/// one per stage (Destinations 4–7). Every session opens on the same title
/// screen, so a learner meets the identical opening whichever one they are
/// on — see [CreationHuntStage] for the same arrangement.
class ClassroomHeroesSession {
  const ClassroomHeroesSession({
    required this.number,
    required this.tag,
    required this.title,
    required this.blurb,
    required this.retryText,
    required this.finishText,
    required this.questions,
  });

  /// 1-4 — shown in the session card's badge.
  final int number;

  /// e.g. "SESSION 1 · RESPECT" — the curtain's eyebrow line.
  final String tag;
  final String title;

  /// The card's one-line "Greeting · Listening · Asking permission" summary.
  final String blurb;

  /// Shown in the Try again card — says *why* the decoy isn't the hero
  /// choice, in this session's own terms.
  final String retryText;

  /// The line on the Classroom Hero badge at the end of the session.
  final String finishText;

  final List<ClassroomHeroesQuestion> questions;
}

/// One painted cut-out laid over a [SirahStoryPage]'s scene — the glowing
/// thing the page asks the learner to tap, or a piece of set dressing beside
/// it. [x]/[y] are its *centre* and [w]/[h] its size, all as fractions of the
/// scene, so it scales with the art instead of being pinned to device pixels
/// (the same scheme as [CreationHuntSpot]).
///
/// The prototype authored these as CSS `left/top/width/height` percentages
/// against a 16/9 frame; ported here to the scene art's wider frame with each
/// sprite's own aspect ratio preserved, so nothing stretches.
class SirahStoryLayer {
  const SirahStoryLayer({
    required this.asset,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  final String asset;
  final double x;
  final double y;
  final double w;
  final double h;
}

/// One page of a Sirah Story session: the scene, the line narrated over it,
/// the cut-out that lights up once the narration ends, and the question asked
/// when it is tapped.
///
/// Always exactly two answers — one right, one decoy — matching the source
/// prototype's "this or that" question card.
class SirahStoryPage {
  const SirahStoryPage({
    required this.background,
    required this.narration,
    required this.narrationMs,
    required this.glow,
    required this.prompt,
    required this.correct,
    required this.decoy,
    this.deco = const [],
    this.celebrate = false,
  });

  final String background;
  final String narration;

  /// How long the narration bar takes to fill — authored per line in the
  /// prototype rather than derived, since it was timed against the read.
  final int narrationMs;

  /// The cut-out that glows and takes the tap.
  final SirahStoryLayer glow;

  /// Scene layers that sit in the picture but are not the answer — the
  /// shepherd boy beside his sheep. Dim with the background when the glow
  /// lights up, exactly as the prototype's own `deco` array does.
  final List<SirahStoryLayer> deco;

  final String prompt;
  final String correct;
  final String decoy;

  /// The prototype's Session 4 finale: turning light rays and a pulsing halo
  /// behind the glow, for the page that is *about* light.
  final bool celebrate;
}

/// One session of Sirah Story — two illustrated pages from the Prophet ﷺ's
/// early life.
///
/// The four sessions are authored in `curriculum_data.dart` and distributed
/// one per stage (Destinations 4-7). Every session opens on the same start
/// screen, so a learner meets the identical opening whichever one they are
/// on — see [ClassroomHeroesSession] for the same arrangement.
class SirahStorySession {
  const SirahStorySession({
    required this.number,
    required this.title,
    required this.blurb,
    required this.pages,
  });

  /// 1-4 — shown in the start screen's badge.
  final int number;
  final String title;

  /// The start card's one-line summary of the session.
  final String blurb;

  final List<SirahStoryPage> pages;
}

/// One scene of The Qur'an Etiquette: the question and feedback artwork, the
/// prompt read over it, the two choices, and the line said back when the
/// respectful one is picked.
///
/// [badgeX]/[badgeY] place the MUMTAZ! badge burst as fractions of the stage,
/// exactly as the prototype's per-question `badge` pair does.
class QuranEtiquetteQuestion {
  const QuranEtiquetteQuestion({
    required this.image,
    required this.feedbackImage,
    required this.badgeX,
    required this.badgeY,
    required this.prompt,
    required this.correct,
    required this.decoy,
    required this.feedback,
  });

  final String image;
  final String feedbackImage;
  final double badgeX;
  final double badgeY;
  final String prompt;
  final String correct;
  final String decoy;
  final String feedback;
}

/// One session of The Qur'an Etiquette (At the Masjid / At Home) — five
/// scenes ported 1:1 from the supplied prototype.
///
/// Distributed one per stage where the curriculum lists the lesson (Session 1
/// in Destination 1, Session 2 in Destination 3). Every session opens on the
/// same title screen with both session cards on it.
class QuranEtiquetteSession {
  const QuranEtiquetteSession({
    required this.number,
    required this.tag,
    required this.title,
    required this.blurb,
    required this.retry,
    required this.finish,
    required this.lessons,
    required this.questions,
  });

  final int number;

  /// e.g. "SESSION 1 · AT THE MASJID" — the curtain's eyebrow line.
  final String tag;
  final String title;
  final String blurb;
  final String retry;
  final String finish;

  /// The checklist on the Qur'an Hero card.
  final List<String> lessons;
  final List<QuranEtiquetteQuestion> questions;
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
    this.ayahSession,
    this.huntStage,
    this.heroesSession,
    this.sirahSession,
    this.etiquetteSession,
    this.pillarsMode,
    this.deedTreeSession,
    this.taharahSession,
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

  /// Used by `ayahBuilder` — the session this lesson opens on.
  final AyahBuilderSession? ayahSession;

  /// Used by `creationHunt` — the one scene this session hunts through.
  final CreationHuntStage? huntStage;

  /// Used by `classroomHeroes` — the one session this lesson plays.
  final ClassroomHeroesSession? heroesSession;

  /// Used by `sirahStory` — the one session this lesson reads through.
  final SirahStorySession? sirahSession;

  /// Used by `quranEtiquette` — the session this lesson plays.
  final QuranEtiquetteSession? etiquetteSession;

  /// Used by `fivePillars` — which of the two sessions this lesson plays.
  final FivePillarsMode? pillarsMode;

  /// Used by `goodDeedTree` — which of the two sessions this lesson plays.
  final GoodDeedTreeSession? deedTreeSession;

  /// Used by `taharahAdventure` — which of the three sessions this lesson plays.
  final TaharahSession? taharahSession;
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
