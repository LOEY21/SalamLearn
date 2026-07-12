// Ports the type definitions from Wireframe 0.3's `src/data/curriculum.ts`
// (lines 1-40) — see that file for the source of truth on shape/naming.

enum ActivityType { flashcard, quiz, story, match, sort }

enum DestinationState { completed, current, locked }

class FlashCard {
  const FlashCard({
    required this.id,
    required this.emoji,
    required this.arabic,
    required this.translit,
    required this.english,
    required this.color,
  });

  final String id;
  final String emoji;
  final String arabic;
  final String translit;
  final String english;
  final String color;
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

class MatchPair {
  const MatchPair({
    required this.id,
    required this.left,
    this.leftEmoji,
    required this.right,
    this.rightEmoji,
  });

  final String id;
  final String left;
  final String? leftEmoji;
  final String right;
  final String? rightEmoji;
}

class SortItem {
  const SortItem({
    required this.id,
    required this.emoji,
    required this.label,
    this.labelAr,
    required this.bucket,
  });

  final String id;
  final String emoji;
  final String label;
  final String? labelAr;
  final int bucket;
}

class Activity {
  const Activity({
    required this.id,
    required this.type,
    required this.title,
    required this.icon,
    required this.xp,
    this.cards,
    this.questions,
    this.panels,
    this.pairs,
    this.items,
    this.bucketA,
    this.bucketB,
  });

  final String id;
  final ActivityType type;
  final String title;
  final String icon;
  final int xp;
  final List<FlashCard>? cards;
  final List<QuizQ>? questions;
  final List<StoryPanel>? panels;
  final List<MatchPair>? pairs;
  final List<SortItem>? items;
  final String? bucketA;
  final String? bucketB;
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
