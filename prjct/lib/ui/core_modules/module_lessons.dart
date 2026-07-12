/// Two-lesson content for each core module (FR-4.1 … FR-4.5), Grade 1
/// ALIVE curriculum scope. Static, in-memory content — no backend fetch,
/// matches how the rest of the module engine works today.
class Lesson {
  const Lesson({required this.id, required this.title, required this.subtitle});

  final String id;
  final String title;
  final String subtitle;
}

class LetterItem {
  const LetterItem(this.letter, this.name);

  final String letter;
  final String name;
}

class TracingLessonContent extends Lesson {
  const TracingLessonContent({
    required super.id,
    required super.title,
    required super.subtitle,
    required this.letters,
  });

  final List<LetterItem> letters;
}

const tracingLessons = [
  TracingLessonContent(
    id: 'tracing-1',
    title: 'Lesson 1',
    subtitle: 'Alif, Ba, Ta',
    letters: [
      LetterItem('ا', 'Alif'),
      LetterItem('ب', 'Ba'),
      LetterItem('ت', 'Ta'),
    ],
  ),
  TracingLessonContent(
    id: 'tracing-2',
    title: 'Lesson 2',
    subtitle: 'Jeem, Dal, Ra',
    letters: [
      LetterItem('ج', 'Jeem'),
      LetterItem('د', 'Dal'),
      LetterItem('ر', 'Ra'),
    ],
  ),
];

class FlashcardLessonContent extends Lesson {
  const FlashcardLessonContent({
    required super.id,
    required super.title,
    required super.subtitle,
    required this.cards,
  });

  final List<LetterItem> cards;
}

const flashcardLessons = [
  FlashcardLessonContent(
    id: 'flashcards-1',
    title: 'Lesson 1',
    subtitle: 'Starter sounds',
    cards: [
      LetterItem('ا', 'Alif'),
      LetterItem('ب', 'Ba'),
      LetterItem('ت', 'Ta'),
    ],
  ),
  FlashcardLessonContent(
    id: 'flashcards-2',
    title: 'Lesson 2',
    subtitle: 'More sounds',
    cards: [
      LetterItem('ج', 'Jeem'),
      LetterItem('د', 'Dal'),
      LetterItem('ر', 'Ra'),
    ],
  ),
];

class RecitationLessonContent extends Lesson {
  const RecitationLessonContent({
    required super.id,
    required super.title,
    required super.subtitle,
    required this.sourceLabel,
    required this.arabic,
    required this.transliteration,
    required this.translation,
  });

  final String sourceLabel;
  final String arabic;
  final String transliteration;
  final String translation;
}

const recitationLessons = [
  RecitationLessonContent(
    id: 'recitation-1',
    title: 'Lesson 1',
    subtitle: "Surah Al-Fatihah (opening verse)",
    sourceLabel: "Qur'an — Surah Al-Fatihah, 1:1",
    arabic: 'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
    transliteration: 'Bismillahir-Rahmanir-Raheem',
    translation: 'In the name of Allah, the Most Gracious, the Most Merciful.',
  ),
  RecitationLessonContent(
    id: 'recitation-2',
    title: 'Lesson 2',
    subtitle: 'Hadith on kindness',
    sourceLabel: 'Hadith — Sahih al-Bukhari',
    arabic: 'مَنْ لَا يَرْحَمْ لَا يُرْحَمْ',
    transliteration: 'Man laa yarham laa yurham',
    translation: 'Whoever does not show mercy will not be shown mercy.',
  ),
];

class StoryLessonContent extends Lesson {
  const StoryLessonContent({
    required super.id,
    required super.title,
    required super.subtitle,
    required this.pages,
  });

  final List<String> pages;
}

const storyLessons = [
  StoryLessonContent(
    id: 'stories-1',
    title: 'Lesson 1',
    subtitle: 'The birth of Prophet Muhammad ﷺ',
    pages: [
      'A long time ago, in the city of Makkah, a very special baby was born. His name was Muhammad ﷺ.',
      'His father had already passed away before he was born, so his mother, Aminah, cared for him with love.',
      'Everyone who met baby Muhammad ﷺ could feel that he was kind, gentle, and different from other children.',
    ],
  ),
  StoryLessonContent(
    id: 'stories-2',
    title: 'Lesson 2',
    subtitle: 'The honest trader',
    pages: [
      'When Prophet Muhammad ﷺ grew up, he worked as a trader, buying and selling goods for people.',
      'He always told the truth about his goods and never cheated anyone, even when it was easy to.',
      'People began calling him "Al-Amin," which means "the Trustworthy One," because everyone knew they could believe him.',
    ],
  ),
];

class MatchPair {
  const MatchPair(this.left, this.right);

  final String left;
  final String right;
}

class SortingLessonContent extends Lesson {
  const SortingLessonContent({
    required super.id,
    required super.title,
    required super.subtitle,
    required this.pairs,
  });

  final List<MatchPair> pairs;
}

const sortingLessons = [
  SortingLessonContent(
    id: 'sorting-1',
    title: 'Lesson 1',
    subtitle: 'Steps of Wudu',
    pairs: [
      MatchPair('1. Niyyah', 'Make the intention'),
      MatchPair('2. Hands', 'Wash hands to the wrists'),
      MatchPair('3. Mouth', 'Rinse the mouth'),
      MatchPair('4. Face', 'Wash the whole face'),
    ],
  ),
  SortingLessonContent(
    id: 'sorting-2',
    title: 'Lesson 2',
    subtitle: 'Prayer times',
    pairs: [
      MatchPair('Fajr', 'Dawn'),
      MatchPair('Dhuhr', 'Midday'),
      MatchPair('Asr', 'Afternoon'),
      MatchPair('Maghrib', 'Sunset'),
    ],
  ),
];
