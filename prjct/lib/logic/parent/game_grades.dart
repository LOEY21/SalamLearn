import '../../data/curriculum_data.dart';
import '../../data/models/curriculum/curriculum_models.dart';

/// One of the curriculum's games (Magic Sand Tracer, Ayah Builder, ...)
/// or one of its 7 map stages, with its sessions in map order.
class GameGroup {
  GameGroup({required this.name, required this.type, required this.icon});

  final String name;

  /// Null for a stage, whose sessions span several games.
  final ActivityType? type;
  final String icon;
  final List<({Lesson lesson, Destination destination})> sessions = [];

  bool get isStage => type == null;
}


/// Groups the curriculum's lessons by game, ordered by where each game
/// first appears on the map. Lesson titles read "Game - Session N (Topic)",
/// so the game name is the part before " - ".
List<GameGroup> curriculumGames() {
  final byType = <ActivityType, GameGroup>{};
  for (final destination in curriculum) {
    for (final lesson in destination.lessons) {
      final activity = lesson.activities.first;
      byType
          .putIfAbsent(
            activity.type,
            () => GameGroup(
              name: lesson.title.split(' - ').first,
              type: activity.type,
              icon: activity.icon,
            ),
          )
          .sessions
          .add((lesson: lesson, destination: destination));
    }
  }
  return byType.values.toList();
}

/// The 7 map stages (destinations), each with its sessions.
List<GameGroup> curriculumStages() => [
  for (final (i, destination) in curriculum.indexed)
    GameGroup(
        name: 'Stage ${i + 1}: ${destination.name}',
        type: null,
        icon: destination.icon,
      )
      ..sessions.addAll([
        for (final lesson in destination.lessons)
          (lesson: lesson, destination: destination),
      ]),
];

/// "Session 1 (Forest)" from "Allah's Creation Hunt - Session 1 (Forest)".
String sessionLabel(Lesson lesson) {
  final i = lesson.title.indexOf(' - ');
  return i == -1 ? lesson.title : lesson.title.substring(i + 3);
}

/// Parent-facing grade for one game's score, on the DepEd K-12 descriptor
/// scale Filipino parents already know from report cards.
enum GradeBand {
  outstanding('Outstanding', '90–100%'),
  verySatisfactory('Very Satisfactory', '85–89%'),
  satisfactory('Satisfactory', '80–84%'),
  fairlySatisfactory('Fairly Satisfactory', '75–79%'),
  needsPractice('Needs More Practice', 'Below 75%');

  const GradeBand(this.label, this.range);

  final String label;
  final String range;

  static GradeBand forScore(double pct) {
    if (pct >= 90) return outstanding;
    if (pct >= 85) return verySatisfactory;
    if (pct >= 80) return satisfactory;
    if (pct >= 75) return fairlySatisfactory;
    return needsPractice;
  }
}

/// What the game trains, in plain words for a parent.
String gameSkill(ActivityType type) => switch (type) {
  ActivityType.trace => 'Writing Arabic letters with the correct strokes.',
  ActivityType.pronounce =>
    'Knowing which Islamic greeting or phrase fits each everyday moment.',
  ActivityType.quranSync => "Following along with a Qur'an recitation.",
  ActivityType.story => 'Listening to a story and understanding its lesson.',
  ActivityType.fiqhDrag =>
    'Sorting everyday actions into the right Islamic rule.',
  ActivityType.quiz => 'Remembering what was taught in the lesson.',
  ActivityType.harakatPop =>
    'Recognising the vowel marks (harakat) that change how letters sound.',
  ActivityType.ayahBuilder =>
    'Putting the words of an ayah in the right order.',
  ActivityType.creationHunt =>
    "Spotting and naming the things Allah created in the world around us.",
  ActivityType.classroomHeroes =>
    'Good manners and behaviour in the classroom.',
  ActivityType.sirahStory =>
    "Following events from the Prophet's (ﷺ) life in the right order.",
  ActivityType.quranEtiquette => "How to respect and handle the Qur'an.",
  ActivityType.fivePillars => 'Knowing the Five Pillars of Islam.',
  ActivityType.goodDeedTree => 'Telling good deeds apart from bad ones.',
  ActivityType.taharahAdventure =>
    'Cleanliness (taharah) and the steps of wudu.',
  ActivityType.labelMaker => 'Matching words to the right pictures.',
  ActivityType.soundDetective => 'Hearing and telling apart letter sounds.',
};

/// One thing a parent can do at home to reinforce the game.
String gameHomeTip(ActivityType type) => switch (type) {
  ActivityType.trace =>
    'Have them trace the letter with a finger on paper, sand, or your palm.',
  ActivityType.pronounce =>
    'Greet each other with "Assalamu alaikum" at home and practise the replies.',
  ActivityType.quranSync =>
    'Recite the same surah together slowly, pointing at each word.',
  ActivityType.story => 'Ask them to retell the story in their own words.',
  ActivityType.fiqhDrag =>
    'During the day, ask "Is this allowed?" about simple everyday actions.',
  ActivityType.quiz => 'Ask them two or three of the questions over dinner.',
  ActivityType.harakatPop =>
    'Say a letter with fatha, kasra and damma and let them repeat after you.',
  ActivityType.ayahBuilder =>
    'Recite the ayah together, one word at a time, until they can say it alone.',
  ActivityType.creationHunt =>
    'On a walk, take turns naming things Allah created and saying "SubhanAllah".',
  ActivityType.classroomHeroes =>
    'Talk about one good classroom habit they can try tomorrow.',
  ActivityType.sirahStory =>
    "Ask what happened first, next, and last in the Prophet's (ﷺ) story.",
  ActivityType.quranEtiquette =>
    "Show them how you hold and place the Qur'an before reading.",
  ActivityType.fivePillars => 'Count the Five Pillars together on one hand.',
  ActivityType.goodDeedTree =>
    'At bedtime, ask them to name one good deed they did today.',
  ActivityType.taharahAdventure =>
    'Do wudu together and let them say each step out loud.',
  ActivityType.labelMaker =>
    'Point at things around the house and ask them to name them.',
  ActivityType.soundDetective =>
    'Say two similar letter sounds and ask which one they heard.',
};

/// The written feedback on one game attempt: how it went, then the
/// mistakes count.
String gameFeedback({
  required double scorePct,
  required int mistakes,
  String name = 'Your child',
}) {
  final summary = switch (GradeBand.forScore(scorePct)) {
    GradeBand.outstanding => 'Excellent work! $name has mastered this game.',
    GradeBand.verySatisfactory =>
      'Very good! $name understands this well, with only small slips.',
    GradeBand.satisfactory =>
      '$name understands the basics. A little more practice will make it stronger.',
    GradeBand.fairlySatisfactory =>
      '$name is still learning this. Replaying the game will help.',
    GradeBand.needsPractice =>
      'This one was hard for $name. Try playing it together and talk through each step.',
  };
  final mistakesLine = mistakes == 0
      ? 'No mistakes made.'
      : 'Made $mistakes mistake${mistakes == 1 ? '' : 's'} along the way.';
  return '$summary $mistakesLine';
}

/// "2m 05s" / "45s".
String formatDuration(int seconds) {
  if (seconds < 60) return '${seconds}s';
  return '${seconds ~/ 60}m ${(seconds % 60).toString().padLeft(2, '0')}s';
}
