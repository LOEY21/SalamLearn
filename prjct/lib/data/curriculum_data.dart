// Ported 1:1 from Wireframe 0.3's `src/data/curriculum.ts`
// (SalamLearn ALIVE Curriculum -- DepEd Refined Elementary Madrasah
// Curriculum, Grades 1-3: Arabic Language, Qur'an, Sirah & Hadith,
// Aqidah & Fiqh, Islamic Values). Same owner/original content, ported
// into the production Flutter app per the project owner's request.
//
// Structure mirrors the TS source: intermediate const lists per
// destination (cards/quiz/story/match/sort groups), assembled into
// Activity/Lesson/Destination objects, then the final `curriculum` list.

import 'models/curriculum/curriculum_models.dart';

// ─────────────────────────────────────────────────────────────
// DESTINATION 1 -- Village of Salaam
// ─────────────────────────────────────────────────────────────

const List<FlashCard> greetingsCards = [
  FlashCard(
    id: 'g1',
    emoji: '🤲',
    arabic: 'اَلسَّلَامُ عَلَيْكُمْ',
    translit: 'As-salamu alaykum',
    english: 'Peace be upon you',
    color: '#FDECC8',
  ),
  FlashCard(
    id: 'g2',
    emoji: '💚',
    arabic: 'وَعَلَيْكُمُ السَّلَام',
    translit: 'Wa alaykum as-salam',
    english: 'And upon you peace',
    color: '#DCF0E6',
  ),
  FlashCard(
    id: 'g3',
    emoji: '🌅',
    arabic: 'صَبَاحُ الْخَيْر',
    translit: 'Sabahul khayr',
    english: 'Good morning',
    color: '#FDECC8',
  ),
  FlashCard(
    id: 'g4',
    emoji: '☀️',
    arabic: 'صَبَاحُ النُّور',
    translit: 'Sabahun nur',
    english: 'Good morning too (reply)',
    color: '#FDDCCC',
  ),
  FlashCard(
    id: 'g5',
    emoji: '🌙',
    arabic: 'مَسَاءُ الْخَيْر',
    translit: 'Masa\'ul khayr',
    english: 'Good afternoon/evening',
    color: '#E8E4FF',
  ),
  FlashCard(
    id: 'g6',
    emoji: '🌟',
    arabic: 'مَسَاءُ النُّور',
    translit: 'Masa\'un nur',
    english: 'Good afternoon too (reply)',
    color: '#E8F4FF',
  ),
  FlashCard(
    id: 'g7',
    emoji: '🏠',
    arabic: 'أَهْلاً وَسَهْلاً',
    translit: 'Ahlan wa sahlan',
    english: 'Welcome!',
    color: '#FDDCCC',
  ),
  FlashCard(
    id: 'g8',
    emoji: '👋',
    arabic: 'مَعَ السَّلَامَة',
    translit: 'Ma\'a as-salama',
    english: 'Goodbye (go with peace)',
    color: '#DCF0E6',
  ),
  FlashCard(
    id: 'g9',
    emoji: '🙏',
    arabic: 'شُكْرًا',
    translit: 'Shukran',
    english: 'Thank you',
    color: '#FDECC8',
  ),
  FlashCard(
    id: 'g10',
    emoji: '😊',
    arabic: 'عَفْوًا',
    translit: '\'Afwan',
    english: 'You\'re welcome / Sorry',
    color: '#E8F4FF',
  ),
  FlashCard(
    id: 'g11',
    emoji: '🤷',
    arabic: 'إِلَى اللِّقَاء',
    translit: 'Ilal liqa\'',
    english: 'See you again / Goodbye',
    color: '#E8E4FF',
  ),
];

const List<FlashCard> expressionsCards = [
  FlashCard(
    id: 'e1',
    emoji: '✨',
    arabic: 'بِسْمِ اللّٰهِ',
    translit: 'Bismillah',
    english: 'In the name of Allah -- say before starting anything',
    color: '#FDECC8',
  ),
  FlashCard(
    id: 'e2',
    emoji: '🌟',
    arabic: 'الْحَمْدُ لِلّٰهِ',
    translit: 'Alhamdulillah',
    english: 'Praise be to Allah -- say after good things happen',
    color: '#DCF0E6',
  ),
  FlashCard(
    id: 'e3',
    emoji: '💫',
    arabic: 'سُبْحَانَ اللّٰهِ',
    translit: 'Subhanallah',
    english: 'Glory be to Allah -- say when amazed by creation',
    color: '#E8E4FF',
  ),
  FlashCard(
    id: 'e4',
    emoji: '🕌',
    arabic: 'اللّٰهُ أَكْبَر',
    translit: 'Allahu Akbar',
    english: 'Allah is the Greatest -- in prayer and in awe',
    color: '#FDDCCC',
  ),
  FlashCard(
    id: 'e5',
    emoji: '🌈',
    arabic: 'إِنْ شَاءَ اللّٰه',
    translit: 'In sha Allah',
    english: 'If Allah wills -- say when planning for the future',
    color: '#FDECC8',
  ),
  FlashCard(
    id: 'e6',
    emoji: '🤝',
    arabic: 'جَزَاكَ اللّٰهُ خَيْرًا',
    translit: 'Jazakallahu khayran',
    english: 'May Allah reward you with good -- best thank you!',
    color: '#DCF0E6',
  ),
  FlashCard(
    id: 'e7',
    emoji: '🌸',
    arabic: 'مَا شَاءَ اللّٰه',
    translit: 'Masha Allah',
    english: 'What Allah has willed -- say to admire something',
    color: '#FDDCCC',
  ),
  FlashCard(
    id: 'e8',
    emoji: '💪',
    arabic: 'بِارَكَ اللّٰهُ فِيكَ',
    translit: 'Barakallahu fik',
    english: 'May Allah bless you',
    color: '#E8F4FF',
  ),
];

const List<StoryPanel> storyNoor = [
  StoryPanel(
    id: 's1',
    bg: 'linear-gradient(160deg, #A8D8EA 0%, #DCF0E6 100%)',
    scene: [
      StorySceneItem(emoji: '🏫', x: 50, y: 15, size: 80),
      StorySceneItem(emoji: '👧🏽', x: 30, y: 55, size: 70),
      StorySceneItem(emoji: '🎒', x: 38, y: 75, size: 35),
      StorySceneItem(emoji: '🌸', x: 70, y: 65, size: 30),
      StorySceneItem(emoji: '🌸', x: 15, y: 70, size: 25),
    ],
    caption:
        'It was Noor\'s very first day at the Madrasah. Her heart was beating fast...',
    captionAr: 'كان أوّل يوم لنور في المدرسة. كان قلبها يدقّ بسرعة...',
  ),
  StoryPanel(
    id: 's2',
    bg: 'linear-gradient(160deg, #FDECC8 0%, #FDDCCC 100%)',
    scene: [
      StorySceneItem(emoji: '👦🏽', x: 20, y: 45, size: 75),
      StorySceneItem(emoji: '👧🏽', x: 65, y: 48, size: 70),
      StorySceneItem(emoji: '⭐', x: 42, y: 25, size: 28),
      StorySceneItem(emoji: '✨', x: 58, y: 20, size: 22),
    ],
    bubble: StoryBubble(text: 'اَلسَّلَامُ عَلَيْكُمْ! 😊', side: 'left'),
    caption:
        'A kind classmate walked up and gave her the most beautiful greeting!',
    captionAr: 'اقترب منها زميل طيّب وأعطاها أجمل تحية!',
  ),
  StoryPanel(
    id: 's3',
    bg: 'linear-gradient(160deg, #DCF0E6 0%, #A8D8EA 100%)',
    scene: [
      StorySceneItem(emoji: '👧🏽', x: 25, y: 45, size: 75),
      StorySceneItem(emoji: '👦🏽', x: 62, y: 48, size: 70),
      StorySceneItem(emoji: '💚', x: 44, y: 22, size: 35),
    ],
    bubble: StoryBubble(
      text: 'وَعَلَيْكُمُ السَّلَام وَرَحْمَةُ اللّٰه! 🌟',
      side: 'right',
    ),
    caption: 'Noor smiled and replied with the full, beautiful greeting!',
    captionAr: 'ابتسمت نور وردّت بالتحية الكاملة الجميلة!',
  ),
  StoryPanel(
    id: 's4',
    bg: 'linear-gradient(160deg, #0F6E56 0%, #5B9A1E 100%)',
    scene: [
      StorySceneItem(emoji: '👧🏽', x: 25, y: 48, size: 70),
      StorySceneItem(emoji: '👦🏽', x: 60, y: 48, size: 70),
      StorySceneItem(emoji: '🌟', x: 43, y: 18, size: 42),
      StorySceneItem(emoji: '🌸', x: 12, y: 62, size: 28),
      StorySceneItem(emoji: '🌺', x: 73, y: 65, size: 28),
    ],
    caption:
        'A salaam is a gift -- it spreads peace and earns you reward from Allah! 💚',
    captionAr: 'السَّلام هديّةٌ -- ينشر السلام ويكسبك أجراً من اللّٰه! 💚',
  ),
  StoryPanel(
    id: 's5',
    bg: 'linear-gradient(160deg, #EF9F27 0%, #D85A30 100%)',
    scene: [
      StorySceneItem(emoji: '🤲', x: 43, y: 22, size: 75),
      StorySceneItem(emoji: '⭐', x: 20, y: 55, size: 40),
      StorySceneItem(emoji: '⭐', x: 65, y: 52, size: 35),
      StorySceneItem(emoji: '⭐', x: 43, y: 68, size: 30),
    ],
    caption:
        'The Prophet ﷺ said: Spread salaam among yourselves! It brings love and peace. 🌙',
    captionAr:
        'قال النبيّ ﷺ: أَفْشُوا السَّلامَ بَيْنَكُمْ! إنّه يُدخِل المحبّة والسلام. 🌙',
  ),
];

const List<QuizQ> greetQuiz = [
  QuizQ(
    id: 'q1',
    emoji: '🤲',
    question: 'Someone says \'As-salamu alaykum\'. How do you reply?',
    questionAr: 'قال لك شخص اَلسَّلَامُ عَلَيْكُمْ — ماذا تردّ؟',
    options: [
      'وَعَلَيْكُمُ السَّلَام 💚',
      'صَبَاحُ الْخَيْر 🌅',
      'أَهْلاً وَسَهْلاً 🏠',
      'مَعَ السَّلَامَة 👋',
    ],
    correct: 0,
    tip: 'We always reply \'Wa alaykum as-salam\' — return the peace in full!',
  ),
  QuizQ(
    id: 'q2',
    emoji: '🍽️',
    question: 'Before eating, what Islamic expression do you say?',
    questionAr: 'قبل الأكل، ماذا تقول؟',
    options: [
      'الْحَمْدُ لِلّٰهِ',
      'بِسْمِ اللّٰهِ ✨',
      'سُبْحَانَ اللّٰهِ',
      'اللّٰهُ أَكْبَر',
    ],
    correct: 1,
    tip: '\'Bismillah\' — we start everything in Allah\'s blessed name!',
  ),
  QuizQ(
    id: 'q3',
    emoji: '😍',
    question: 'You see a beautiful butterfly. Which expression fits?',
    questionAr: 'رأيت فراشة جميلة — أيّ عبارة تناسب؟',
    options: [
      'Alhamdulillah 🌟',
      'Masha Allah 🌸 ✓',
      'Allahu Akbar 🕌',
      'In sha Allah 🌈',
    ],
    correct: 1,
    tip: '\'Masha Allah\' means we recognize that beauty comes from Allah!',
  ),
  QuizQ(
    id: 'q4',
    emoji: '🎁',
    question: 'Your friend helps you carry your bag. You say...',
    options: [
      'Good food 🍕',
      'Shukran 🙏',
      'Masha Allah 🌸',
      'Ahlan wa sahlan 🏠',
    ],
    correct: 1,
    tip: 'Shukran means \'thank you\' in Arabic!',
  ),
  QuizQ(
    id: 'q5',
    emoji: '🚪',
    question: 'You are leaving your friend\'s house. You say...',
    options: [
      'بِسْمِ اللّٰهِ',
      'الْحَمْدُ لِلّٰهِ',
      'مَعَ السَّلَامَة 👋 ✓',
      'أَهْلاً وَسَهْلاً',
    ],
    correct: 2,
    tip: '\'Ma\'a as-salama\' means \'go with peace\' — a beautiful farewell!',
  ),
];

const List<FlashCard> introCards = [
  FlashCard(
    id: 'i1',
    emoji: '👤',
    arabic: 'اسْمِي',
    translit: 'Ismi',
    english: 'My name is...',
    color: '#FDECC8',
  ),
  FlashCard(
    id: 'i2',
    emoji: '🎂',
    arabic: 'عُمْرِي',
    translit: '\'Umri',
    english: 'My age is...',
    color: '#FDDCCC',
  ),
  FlashCard(
    id: 'i3',
    emoji: '🏡',
    arabic: 'أَنَا مِن',
    translit: 'Ana min',
    english: 'I am from...',
    color: '#DCF0E6',
  ),
  FlashCard(
    id: 'i4',
    emoji: '🏫',
    arabic: 'مَدْرَسَتِي',
    translit: 'Madrasati',
    english: 'My school',
    color: '#E8E4FF',
  ),
  FlashCard(
    id: 'i5',
    emoji: '👦🏽',
    arabic: 'مَا اسْمُكَ؟',
    translit: 'Ma ismuka?',
    english: 'What is your name?',
    color: '#E8F4FF',
  ),
  FlashCard(
    id: 'i6',
    emoji: '👧🏽',
    arabic: 'كَمْ عُمْرُكِ؟',
    translit: 'Kam umruki?',
    english: 'How old are you?',
    color: '#FDDCCC',
  ),
  FlashCard(
    id: 'i7',
    emoji: '🤝',
    arabic: 'يَسُرُّنِي أَن أَتَعَرَّفَ عَلَيْكَ',
    translit: 'Yasurruni an ata\'arraf alayk',
    english: 'Nice to meet you',
    color: '#DCF0E6',
  ),
  FlashCard(
    id: 'i8',
    emoji: '😊',
    arabic: 'كَيْفَ حَالُكَ؟',
    translit: 'Kayfa haluk?',
    english: 'How are you?',
    color: '#FDECC8',
  ),
  FlashCard(
    id: 'i9',
    emoji: '👍',
    arabic: 'بِخَيْر، وَأَنْتَ؟',
    translit: 'Bi khayr, wa anta?',
    english: 'I\'m fine, and you?',
    color: '#E8F4FF',
  ),
];

const List<FlashCard> duasCards = [
  FlashCard(
    id: 'du1',
    emoji: '🌙',
    arabic: 'اللَّهُمَّ بِاسْمِكَ أَمُوتُ وَأَحْيَا',
    translit: 'Allahumma bismika amutu wa ahya',
    english: 'Before sleeping: O Allah, in Your name I die and I live',
    color: '#E8E4FF',
  ),
  FlashCard(
    id: 'du2',
    emoji: '☀️',
    arabic: 'الحَمْدُ لِلَّهِ الَّذِي أَحْيَانَا بَعْدَ مَا أَمَاتَنَا',
    translit: 'Alhamdulillahil-ladhi ahyana ba\'da ma amatana',
    english: 'Upon waking: Praise Allah who gave us life after sleep',
    color: '#FDECC8',
  ),
  FlashCard(
    id: 'du3',
    emoji: '🍽️',
    arabic: 'بِسْمِ اللّٰهِ',
    translit: 'Bismillah',
    english: 'Before eating: In the name of Allah',
    color: '#DCF0E6',
  ),
  FlashCard(
    id: 'du4',
    emoji: '😋',
    arabic: 'الحَمْدُ لِلَّهِ الَّذِي أَطْعَمَنَا وَسَقَانَا',
    translit: 'Alhamdulillahil-ladhi at\'amana wa saqana',
    english: 'After eating: Praise Allah who fed us and gave us drink',
    color: '#FDECC8',
  ),
  FlashCard(
    id: 'du5',
    emoji: '🚿',
    arabic: 'اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الخُبُثِ وَالخَبَائِثِ',
    translit: 'Allahumma inni a\'udhu bika minal-khubthi wal-khaba\'ith',
    english: 'Entering bathroom: O Allah, I seek refuge from evil',
    color: '#E8F4FF',
  ),
  FlashCard(
    id: 'du6',
    emoji: '🏠',
    arabic: 'بِسْمِ اللّٰهِ تَوَكَّلْتُ عَلَى اللّٰهِ',
    translit: 'Bismillahi tawakkaltu alallah',
    english: 'Leaving home: In Allah\'s name I trust in Allah',
    color: '#FDDCCC',
  ),
  FlashCard(
    id: 'du7',
    emoji: '🕌',
    arabic: 'اللَّهُمَّ افْتَحْ لِي أَبْوَابَ رَحْمَتِكَ',
    translit: 'Allahumma iftah li abwaba rahmatik',
    english: 'Entering masjid: O Allah open for me the doors of Your mercy',
    color: '#DCF0E6',
  ),
  FlashCard(
    id: 'du8',
    emoji: '🌅',
    arabic: 'اللَّهُمَّ بِكَ أَصْبَحْنَا وَبِكَ أَمْسَيْنَا',
    translit: 'Allahumma bika asbahna wa bika amsayna',
    english: 'Morning du\'a: O Allah by You we enter the morning and evening',
    color: '#FDECC8',
  ),
];

const List<StoryPanel> storyDuas = [
  StoryPanel(
    id: 'du_s1',
    bg: 'linear-gradient(160deg, #1a2744 0%, #A8D8EA 100%)',
    scene: [
      StorySceneItem(emoji: '🌙', x: 65, y: 15, size: 60),
      StorySceneItem(emoji: '⭐', x: 25, y: 22, size: 30),
      StorySceneItem(emoji: '⭐', x: 75, y: 40, size: 22),
      StorySceneItem(emoji: '🛏️', x: 43, y: 50, size: 80),
      StorySceneItem(emoji: '👦🏽', x: 43, y: 42, size: 55),
    ],
    bubble: StoryBubble(
      text: 'اللَّهُمَّ بِاسْمِكَ أَمُوتُ وَأَحْيَا 🌙',
      side: 'center',
    ),
    caption:
        'Every night before sleeping, little Yusuf whispers his bedtime du\'a to Allah...',
    captionAr: 'كل ليلة قبل النوم، يُهمس يوسف الصغير دعاءه إلى اللّٰه...',
  ),
  StoryPanel(
    id: 'du_s2',
    bg: 'linear-gradient(160deg, #EF9F27 0%, #FDECC8 100%)',
    scene: [
      StorySceneItem(emoji: '☀️', x: 50, y: 12, size: 70),
      StorySceneItem(emoji: '👦🏽', x: 43, y: 55, size: 68),
      StorySceneItem(emoji: '✨', x: 22, y: 38, size: 30),
      StorySceneItem(emoji: '✨', x: 70, y: 35, size: 28),
    ],
    bubble: StoryBubble(
      text: 'الحَمْدُ لِلَّهِ الَّذِي أَحْيَانَا ☀️',
      side: 'center',
    ),
    caption:
        'In the morning, Yusuf wakes up and thanks Allah for another beautiful day!',
    captionAr: 'في الصباح، يستيقظ يوسف ويشكر اللّٰه على يوم جميل آخر!',
  ),
  StoryPanel(
    id: 'du_s3',
    bg: 'linear-gradient(160deg, #DCF0E6 0%, #FDECC8 100%)',
    scene: [
      StorySceneItem(emoji: '🍚', x: 35, y: 30, size: 55),
      StorySceneItem(emoji: '🥛', x: 58, y: 35, size: 45),
      StorySceneItem(emoji: '🌴', x: 75, y: 55, size: 40),
      StorySceneItem(emoji: '👦🏽', x: 30, y: 55, size: 68),
    ],
    bubble: StoryBubble(text: 'بِسْمِ اللّٰهِ ✨', side: 'right'),
    caption:
        'Before every bite of food, Yusuf says \'Bismillah\' and eats with his right hand!',
    captionAr: 'قبل كل لقمة، يقول يوسف بِسمِ اللّٰه ويأكل بيده اليمنى!',
  ),
  StoryPanel(
    id: 'du_s4',
    bg: 'linear-gradient(160deg, #FDDCCC 0%, #EF9F27 100%)',
    scene: [
      StorySceneItem(emoji: '🕌', x: 43, y: 12, size: 80),
      StorySceneItem(emoji: '👦🏽', x: 35, y: 58, size: 65),
      StorySceneItem(emoji: '🚶🏽', x: 62, y: 60, size: 55),
      StorySceneItem(emoji: '🌟', x: 22, y: 40, size: 30),
    ],
    bubble: StoryBubble(
      text: 'اللَّهُمَّ افْتَحْ لِي أَبْوَابَ رَحْمَتِكَ 🕌',
      side: 'center',
    ),
    caption:
        'Walking into the Masjid, Yusuf asks Allah to open the doors of His mercy for him!',
    captionAr: 'عند دخول المسجد، يسأل يوسف اللّٰه أن يفتح له أبواب رحمته!',
  ),
  StoryPanel(
    id: 'du_s5',
    bg: 'linear-gradient(160deg, #0F6E56 0%, #5B9A1E 100%)',
    scene: [
      StorySceneItem(emoji: '🌟', x: 43, y: 12, size: 70),
      StorySceneItem(emoji: '👦🏽', x: 43, y: 55, size: 70),
      StorySceneItem(emoji: '✨', x: 18, y: 42, size: 35),
      StorySceneItem(emoji: '✨', x: 70, y: 38, size: 32),
      StorySceneItem(emoji: '💚', x: 43, y: 35, size: 30),
    ],
    caption:
        'Du\'a is talking to Allah -- any time, any place! He always hears you! 🤲',
    captionAr:
        'الدعاء هو التحدّث مع اللّٰه — في أي وقت وأي مكان! إنّه يسمعك دائماً! 🤲',
  ),
];

const List<QuizQ> duasQuiz = [
  QuizQ(
    id: 'dq1',
    emoji: '🌙',
    question: 'What du\'a do you say BEFORE sleeping?',
    options: [
      'Bismillah',
      'Alhamdulillah',
      'Allahumma bismika amutu wa ahya ✓',
      'Subhanallah',
    ],
    correct: 2,
    tip:
        'Before sleeping we say: \'O Allah, in Your name I die and live\' — we trust Allah with our sleep!',
  ),
  QuizQ(
    id: 'dq2',
    emoji: '☀️',
    question: 'Which du\'a do you say upon WAKING UP?',
    options: [
      'Bismillah',
      'Alhamdulillahil-ladhi ahyana ✓',
      'Allahu Akbar',
      'Ma\'a as-salama',
    ],
    correct: 1,
    tip:
        'We thank Allah for giving us life after sleep — every morning is a gift!',
  ),
  QuizQ(
    id: 'dq3',
    emoji: '🍽️',
    question: 'Before eating, you should say...',
    options: ['Alhamdulillah', 'Masha Allah', 'Bismillah ✓', 'In sha Allah'],
    correct: 2,
    tip: 'Always start with \'Bismillah\' before eating or drinking!',
  ),
  QuizQ(
    id: 'dq4',
    emoji: '🚿',
    question: 'Before entering the bathroom, you say a du\'a to...',
    options: [
      'Thank Allah for water',
      'Ask to clean yourself',
      'Seek protection from evil ✓',
      'Say good morning',
    ],
    correct: 2,
    tip: 'We seek refuge from evil spirits before entering — smart protection!',
  ),
  QuizQ(
    id: 'dq5',
    emoji: '🏠',
    question:
        'Leaving home, you say \'Bismillahi tawakkaltu alallah\' which means...',
    options: [
      'Goodbye everyone',
      'In Allah\'s name, I trust in Allah ✓',
      'Good morning',
      'May Allah bless you',
    ],
    correct: 1,
    tip: 'We leave home trusting in Allah — He protects us on our journey!',
  ),
];

// ─────────────────────────────────────────────────────────────
// DESTINATION 2 -- Desert of Letters
// ─────────────────────────────────────────────────────────────

const List<FlashCard> lettersGroup1 = [
  FlashCard(
    id: 'l1',
    emoji: '🍎',
    arabic: 'أَلِف\nا',
    translit: 'Alif',
    english: 'Like "a" in apple — اِسْم (name)',
    color: '#FDECC8',
  ),
  FlashCard(
    id: 'l2',
    emoji: '🏠',
    arabic: 'بَاء\nب',
    translit: 'Ba',
    english: 'Like "b" in ball — بَيْت (house)',
    color: '#FDDCCC',
  ),
  FlashCard(
    id: 'l3',
    emoji: '🍎',
    arabic: 'تَاء\nت',
    translit: 'Ta',
    english: 'Like "t" in tiger — تُفَّاحَة (apple)',
    color: '#DCF0E6',
  ),
  FlashCard(
    id: 'l4',
    emoji: '🦊',
    arabic: 'ثَاء\nث',
    translit: 'Tha',
    english: 'Soft "th" like in think — ثَعْلَب (fox)',
    color: '#E8E4FF',
  ),
  FlashCard(
    id: 'l5',
    emoji: '🐪',
    arabic: 'جِيم\nج',
    translit: 'Jim',
    english: 'Like "j" in jar — جَمَل (camel)',
    color: '#FDECC8',
  ),
  FlashCard(
    id: 'l6',
    emoji: '🐴',
    arabic: 'حَاء\nح',
    translit: 'Ha',
    english: 'Soft "h" from deep throat — حِصَان (horse)',
    color: '#E8F4FF',
  ),
];

const List<FlashCard> lettersGroup2 = [
  FlashCard(
    id: 'l7',
    emoji: '🗺️',
    arabic: 'خَاء\nخ',
    translit: 'Kha',
    english: 'Like "ch" in Bach (rough) — خَرِيطَة (map)',
    color: '#FDECC8',
  ),
  FlashCard(
    id: 'l8',
    emoji: '🐻',
    arabic: 'دَال\nد',
    translit: 'Dal',
    english: 'Like "d" in duck — دُبّ (bear)',
    color: '#FDDCCC',
  ),
  FlashCard(
    id: 'l9',
    emoji: '🌽',
    arabic: 'ذَال\nذ',
    translit: 'Dhal',
    english: 'Like "th" in THAT — ذُرَة (corn)',
    color: '#DCF0E6',
  ),
  FlashCard(
    id: 'l10',
    emoji: '⚡',
    arabic: 'رَاء\nر',
    translit: 'Ra',
    english: 'Rolling "r" — رَعْد (thunder)',
    color: '#FDECC8',
  ),
  FlashCard(
    id: 'l11',
    emoji: '🌺',
    arabic: 'زَاي\nز',
    translit: 'Zayn',
    english: 'Like "z" in zoo — زَهْرَة (flower)',
    color: '#E8E4FF',
  ),
  FlashCard(
    id: 'l12',
    emoji: '🐟',
    arabic: 'سِين\nس',
    translit: 'Sin',
    english: 'Like "s" in sea — سَمَكَة (fish)',
    color: '#E8F4FF',
  ),
];

const List<FlashCard> lettersGroup3 = [
  FlashCard(
    id: 'l13',
    emoji: '🌲',
    arabic: 'شِين\nش',
    translit: 'Shin',
    english: 'Like "sh" in ship — شَجَرَة (tree)',
    color: '#DCF0E6',
  ),
  FlashCard(
    id: 'l14',
    emoji: '🐦',
    arabic: 'صَاد\nص',
    translit: 'Sad',
    english: 'Emphatic "s" — صَقْر (falcon)',
    color: '#FDECC8',
  ),
  FlashCard(
    id: 'l15',
    emoji: '🐸',
    arabic: 'ضَاد\nض',
    translit: 'Dad',
    english: 'Emphatic "d" — ضِفْدَع (frog)',
    color: '#FDDCCC',
  ),
  FlashCard(
    id: 'l16',
    emoji: '🍅',
    arabic: 'طَاء\nط',
    translit: 'Ta',
    english: 'Emphatic "t" — طَمَاطِم (tomato)',
    color: '#FDDCCC',
  ),
  FlashCard(
    id: 'l17',
    emoji: '🌿',
    arabic: 'ظَاء\nظ',
    translit: 'Dha',
    english: 'Emphatic "dh" — ظِل (shade/shadow)',
    color: '#DCF0E6',
  ),
  FlashCard(
    id: 'l18',
    emoji: '🦅',
    arabic: 'عَيْن\nع',
    translit: '\'Ayn',
    english: 'Deep \'a\' from the throat — عُقَاب (eagle)',
    color: '#E8E4FF',
  ),
];

const List<FlashCard> lettersGroup4 = [
  FlashCard(
    id: 'l19',
    emoji: '🌫️',
    arabic: 'غَيْن\nغ',
    translit: 'Ghayn',
    english: 'Like "gh" gargling — غَيْم (cloud)',
    color: '#E8E4FF',
  ),
  FlashCard(
    id: 'l20',
    emoji: '🦋',
    arabic: 'فَاء\nف',
    translit: 'Fa',
    english: 'Like "f" in fly — فَرَاشَة (butterfly)',
    color: '#FDECC8',
  ),
  FlashCard(
    id: 'l21',
    emoji: '🐱',
    arabic: 'قَاف\nق',
    translit: 'Qaf',
    english: 'Deep "q" from the throat — قِطَّة (cat)',
    color: '#FDDCCC',
  ),
  FlashCard(
    id: 'l22',
    emoji: '📖',
    arabic: 'كَاف\nك',
    translit: 'Kaf',
    english: 'Like "k" in key — كِتَاب (book)',
    color: '#DCF0E6',
  ),
  FlashCard(
    id: 'l23',
    emoji: '🦁',
    arabic: 'لَام\nل',
    translit: 'Lam',
    english: 'Like "l" in lion — أَسَد/لَيْث (lion)',
    color: '#FDECC8',
  ),
  FlashCard(
    id: 'l24',
    emoji: '🕌',
    arabic: 'مِيم\nم',
    translit: 'Mim',
    english: 'Like "m" in moon — مَسْجِد (mosque)',
    color: '#E8F4FF',
  ),
];

const List<FlashCard> lettersGroup5 = [
  FlashCard(
    id: 'l25',
    emoji: '⭐',
    arabic: 'نُون\nن',
    translit: 'Nun',
    english: 'Like "n" in night — نَجْم (star)',
    color: '#FDECC8',
  ),
  FlashCard(
    id: 'l26',
    emoji: '🌬️',
    arabic: 'هَاء\nه',
    translit: 'Ha',
    english: 'Like "h" in hello — هَوَاء (air)',
    color: '#FDDCCC',
  ),
  FlashCard(
    id: 'l27',
    emoji: '🌹',
    arabic: 'وَاو\nو',
    translit: 'Waw',
    english: 'Like "w" in wonder — وَرْد (rose)',
    color: '#DCF0E6',
  ),
  FlashCard(
    id: 'l28',
    emoji: '🤲',
    arabic: 'يَاء\nي',
    translit: 'Ya',
    english: 'Like "y" in yes — يَد (hand)',
    color: '#E8E4FF',
  ),
];

const List<FlashCard> harakatCards = [
  FlashCard(
    id: 'h1',
    emoji: '☀️',
    arabic: 'بَ\nFatha ( َ )',
    translit: 'a sound',
    english: 'Fatha — short "a" sound. Example: بَيْت (bayt = house)',
    color: '#FDECC8',
  ),
  FlashCard(
    id: 'h2',
    emoji: '🌊',
    arabic: 'بِ\nKasra ( ِ )',
    translit: 'i sound',
    english: 'Kasra — short "i" sound. Example: بِسْمِ (bismi = in the name)',
    color: '#E8F4FF',
  ),
  FlashCard(
    id: 'h3',
    emoji: '🌙',
    arabic: 'بُ\nDamma ( ُ )',
    translit: 'u sound',
    english: 'Damma — short "u" sound. Example: كُتُب (kutub = books)',
    color: '#E8E4FF',
  ),
  FlashCard(
    id: 'h4',
    emoji: '🤫',
    arabic: 'بْ\nSukun ( ْ )',
    translit: 'no vowel',
    english: 'Sukun — no vowel, the letter stops. Example: مُسْلِم (Muslim)',
    color: '#FDDCCC',
  ),
  FlashCard(
    id: 'h5',
    emoji: '✨',
    arabic: 'بَّ\nShadda ( ّ )',
    translit: 'double',
    english: 'Shadda — doubles the letter\'s sound. Example: اللّٰه (Allah)',
    color: '#DCF0E6',
  ),
  FlashCard(
    id: 'h6',
    emoji: '🎵',
    arabic: 'بَا / بِي / بُو\nLong vowels',
    translit: 'long sounds',
    english: 'Madd Tabiy: long a (آ), long i (ي), long u (و)',
    color: '#FDECC8',
  ),
];

const List<StoryPanel> storyLetters = [
  StoryPanel(
    id: 'sl1',
    bg: 'linear-gradient(160deg, #F5D9A0 0%, #EDD080 100%)',
    scene: [
      StorySceneItem(emoji: '🏜️', x: 45, y: 10, size: 90),
      StorySceneItem(emoji: '😢', x: 43, y: 52, size: 55),
    ],
    caption:
        'In the vast Arabic desert, little Ba\' sat alone feeling lonely...',
    captionAr: 'في صحراء عربية واسعة، جلست باء الصغيرة وحيدةً تشعر بالوحدة...',
  ),
  StoryPanel(
    id: 'sl2',
    bg: 'linear-gradient(160deg, #EDD080 0%, #F5D9A0 100%)',
    scene: [
      StorySceneItem(emoji: '🤩', x: 43, y: 20, size: 50),
      StorySceneItem(emoji: '🔡', x: 25, y: 52, size: 55),
      StorySceneItem(emoji: '🔡', x: 62, y: 55, size: 48),
    ],
    bubble: StoryBubble(
      text: 'ب  ت  ث  — We all have DOTS! 🎉',
      side: 'center',
    ),
    caption:
        'She found Ta\' and Tha\' -- her dot family! Ba\' has 1 dot below, Ta\' has 2 above, Tha\' has 3!',
    captionAr:
        'وجدت تاء وثاء — عائلتها! باء: نقطة تحت، تاء: نقطتان فوق، ثاء: ثلاث نقاط فوق!',
  ),
  StoryPanel(
    id: 'sl3',
    bg: 'linear-gradient(160deg, #DCF0E6 0%, #A8D8EA 100%)',
    scene: [
      StorySceneItem(emoji: '💃', x: 25, y: 45, size: 65),
      StorySceneItem(emoji: '🎵', x: 45, y: 28, size: 40),
      StorySceneItem(emoji: '💃', x: 62, y: 48, size: 58, flip: true),
      StorySceneItem(emoji: '🎶', x: 15, y: 32, size: 32),
    ],
    caption:
        'They danced and sang their Arabic alphabet song together -- all 28 letters are friends!',
    captionAr:
        'رقصوا وغنّوا معاً أغنية أبجدية عربية — كلّ الحروف الـ 28 أصدقاء!',
  ),
  StoryPanel(
    id: 'sl4',
    bg: 'linear-gradient(160deg, #0F6E56 0%, #5B9A1E 100%)',
    scene: [
      StorySceneItem(emoji: '🎊', x: 43, y: 12, size: 60),
      StorySceneItem(emoji: '🤩', x: 43, y: 52, size: 65),
      StorySceneItem(emoji: '⭐', x: 18, y: 40, size: 38),
      StorySceneItem(emoji: '⭐', x: 70, y: 38, size: 35),
      StorySceneItem(emoji: '🌟', x: 43, y: 80, size: 30),
    ],
    caption:
        'Every Arabic letter has a name, a sound, and a story. Learn them one by one -- you can do it! 🌟',
    captionAr:
        'كلّ حرف عربي له اسم وصوت وقصّة. تعلّمها واحداً تلو الآخر — تستطيع ذلك! 🌟',
  ),
];

const List<QuizQ> letterQuiz = [
  QuizQ(
    id: 'lq1',
    emoji: 'ب',
    question: 'This letter is...',
    questionAr: 'هذا الحرف هو...',
    options: ['Alif ا', 'Ba ب ✓', 'Ta ت', 'Nun ن'],
    correct: 1,
    tip: 'Ba\' has ONE dot below! One dot = Ba\'!',
  ),
  QuizQ(
    id: 'lq2',
    emoji: '🏠',
    question: 'The Arabic word for "house" (bayt) starts with...',
    questionAr: 'كلمة بيت تبدأ بأيّ حرف؟',
    options: ['ت', 'ج', 'ب ✓', 'ه'],
    correct: 2,
    tip: 'بَيْت (Bayt) = house — starts with Ba\'!',
  ),
  QuizQ(
    id: 'lq3',
    emoji: 'ت',
    question: 'How many dots does ت (Ta) have?',
    options: ['One below', 'Three above', 'Two above ✓', 'None'],
    correct: 2,
    tip: 'Ta\' has TWO dots above — like two eyes looking up!',
  ),
  QuizQ(
    id: 'lq4',
    emoji: '⭐',
    question: 'نَجْم (star) — which letter does it start with?',
    options: ['ن ✓', 'م', 'و', 'ي'],
    correct: 0,
    tip: 'نَجْم (Najm) = star, starts with Nun ن!',
  ),
  QuizQ(
    id: 'lq5',
    emoji: '☀️',
    question: 'Fatha (the little dash above) makes which sound?',
    options: [
      '\'u\' like put',
      '\'i\' like sit',
      '\'a\' like apple ✓',
      'no sound',
    ],
    correct: 2,
    tip: 'Fatha = short \'a\' sound — bright and open like the sun!',
  ),
  QuizQ(
    id: 'lq6',
    emoji: '💫',
    question: 'Shadda ( ّ ) means...',
    options: [
      'Short \'a\' sound',
      'No vowel sound',
      'Double the letter sound ✓',
      'Long vowel',
    ],
    correct: 2,
    tip:
        'Shadda doubles the consonant — اللّٰه (Allah) has a shadda on the Lam!',
  ),
];

// ─────────────────────────────────────────────────────────────
// DESTINATION 3 -- Garden of Words
// ─────────────────────────────────────────────────────────────

const List<FlashCard> bodyPartsCards = [
  FlashCard(
    id: 'bp1',
    emoji: '👤',
    arabic: 'رَأْس',
    translit: 'Ra\'s',
    english: 'Head',
    color: '#FDECC8',
  ),
  FlashCard(
    id: 'bp2',
    emoji: '👀',
    arabic: 'عَيْن / عَيْنَان',
    translit: '\'Ayn / \'Aynan',
    english: 'Eye / Eyes',
    color: '#E8F4FF',
  ),
  FlashCard(
    id: 'bp3',
    emoji: '👂',
    arabic: 'أُذُن / أُذُنَان',
    translit: 'Udhun / Udhunaan',
    english: 'Ear / Ears',
    color: '#DCF0E6',
  ),
  FlashCard(
    id: 'bp4',
    emoji: '👃',
    arabic: 'أَنْف',
    translit: 'Anf',
    english: 'Nose',
    color: '#FDDCCC',
  ),
  FlashCard(
    id: 'bp5',
    emoji: '👄',
    arabic: 'فَم',
    translit: 'Fam',
    english: 'Mouth',
    color: '#FDDCCC',
  ),
  FlashCard(
    id: 'bp6',
    emoji: '✋',
    arabic: 'يَد / يَدَان',
    translit: 'Yad / Yadaan',
    english: 'Hand / Hands',
    color: '#FDECC8',
  ),
  FlashCard(
    id: 'bp7',
    emoji: '🦶',
    arabic: 'رِجْل / رِجْلَان',
    translit: 'Rijl / Rijlaan',
    english: 'Foot / Feet',
    color: '#E8E4FF',
  ),
  FlashCard(
    id: 'bp8',
    emoji: '❤️',
    arabic: 'قَلْب',
    translit: 'Qalb',
    english: 'Heart',
    color: '#FDDCCC',
  ),
  FlashCard(
    id: 'bp9',
    emoji: '🦷',
    arabic: 'أَسْنَان',
    translit: 'Asnan',
    english: 'Teeth',
    color: '#F5F5F5',
  ),
  FlashCard(
    id: 'bp10',
    emoji: '💪',
    arabic: 'ذِرَاع',
    translit: 'Dhira\'',
    english: 'Arm',
    color: '#FDECC8',
  ),
];

const List<FlashCard> colorsCards = [
  FlashCard(
    id: 'c1',
    emoji: '🔴',
    arabic: 'أَحْمَر',
    translit: 'Ahmar',
    english: 'Red',
    color: '#FDDCCC',
  ),
  FlashCard(
    id: 'c2',
    emoji: '🔵',
    arabic: 'أَزْرَق',
    translit: 'Azraq',
    english: 'Blue',
    color: '#E8F4FF',
  ),
  FlashCard(
    id: 'c3',
    emoji: '🟡',
    arabic: 'أَصْفَر',
    translit: 'Asfar',
    english: 'Yellow',
    color: '#FDECC8',
  ),
  FlashCard(
    id: 'c4',
    emoji: '🟢',
    arabic: 'أَخْضَر',
    translit: 'Akhdar',
    english: 'Green',
    color: '#DCF0E6',
  ),
  FlashCard(
    id: 'c5',
    emoji: '⚪',
    arabic: 'أَبْيَض',
    translit: 'Abyad',
    english: 'White',
    color: '#F5F5F5',
  ),
  FlashCard(
    id: 'c6',
    emoji: '⚫',
    arabic: 'أَسْوَد',
    translit: 'Aswad',
    english: 'Black',
    color: '#E8E8E8',
  ),
  FlashCard(
    id: 'c7',
    emoji: '🟠',
    arabic: 'بُرْتُقَالِي',
    translit: 'Burtuqali',
    english: 'Orange',
    color: '#FDDCCC',
  ),
  FlashCard(
    id: 'c8',
    emoji: '🟣',
    arabic: 'بَنَفْسَجِي',
    translit: 'Banafsaji',
    english: 'Purple',
    color: '#E8E4FF',
  ),
  FlashCard(
    id: 'c9',
    emoji: '🩷',
    arabic: 'وَرْدِي',
    translit: 'Wardi',
    english: 'Pink',
    color: '#FDDCCC',
  ),
];

/// Ayah Builder's seven sessions, ported word-for-word from the source
/// prototype and distributed one per stage as it lists them (Stage 2-7, with
/// Al-Falaq and An-Nas both in Stage 6).
const AyahBuilderSession ayahBasmalahSession = AyahBuilderSession(
  stage: 2,
  label: 'Session 1',
  sessionName: 'The Basmalah',
  short: 'the Basmalah',
  englishTranslation:
      'In the name of Allah, the Most Compassionate, the Most Merciful.',
  cheer: 'Same words. Bigger hearts. Brighter futures.',
  words: [
    AyahBuilderWord('بِسْمِ', 'Bismi'),
    AyahBuilderWord('اللَّهِ', 'Allahi'),
    AyahBuilderWord('الرَّحْمَٰنِ', 'Ar-Rahman'),
    AyahBuilderWord('الرَّحِيمِ', 'Ar-Rahim'),
  ],
);

const AyahBuilderSession ayahFatihah1Session = AyahBuilderSession(
  stage: 3,
  label: 'Session 2',
  sessionName: 'Al-Fatihah Pt 1',
  short: 'Al-Fatihah',
  englishTranslation: 'All praise belongs to Allah, Lord of the worlds.',
  cheer: 'Small steps, big imaan.',
  words: [
    AyahBuilderWord('الْحَمْدُ', 'Al-hamdu'),
    AyahBuilderWord('لِلَّهِ', 'lillahi'),
    AyahBuilderWord('رَبِّ', 'Rabbi'),
    AyahBuilderWord('الْعَالَمِينَ', 'al-alamin'),
  ],
);

const AyahBuilderSession ayahFatihah2Session = AyahBuilderSession(
  stage: 4,
  label: 'Session 3',
  sessionName: 'Al-Fatihah Pt 2',
  short: 'Al-Fatihah Pt 2',
  englishTranslation:
      'The Most Compassionate, the Most Merciful. Master of the Day of Judgment.',
  cheer: 'Five words, one ayah, well done.',
  words: [
    AyahBuilderWord('الرَّحْمَٰنِ', 'Ar-Rahman'),
    AyahBuilderWord('الرَّحِيمِ', 'Ar-Rahim'),
    AyahBuilderWord('مَالِكِ', 'Maliki'),
    AyahBuilderWord('يَوْمِ', 'yawmi'),
    AyahBuilderWord('الدِّينِ', 'ad-din'),
  ],
);

const AyahBuilderSession ayahIkhlasSession = AyahBuilderSession(
  stage: 5,
  label: 'Session 4',
  sessionName: 'Al-Ikhlas',
  short: 'Al-Ikhlas',
  englishTranslation: 'Say, He is Allah, the One.',
  cheer: 'One Allah. One beautiful ayah.',
  words: [
    AyahBuilderWord('قُلْ', 'Qul'),
    AyahBuilderWord('هُوَ', 'Huwa'),
    AyahBuilderWord('اللَّهُ', 'Allahu'),
    AyahBuilderWord('أَحَدٌ', 'Ahad'),
  ],
);

const AyahBuilderSession ayahFalaqSession = AyahBuilderSession(
  stage: 6,
  label: 'Session 5',
  sessionName: 'Al-Falaq',
  short: 'Al-Falaq',
  englishTranslation: 'Say, I seek refuge in the Lord of daybreak.',
  cheer: 'Seeking refuge, word by word.',
  words: [
    AyahBuilderWord('قُلْ', 'Qul'),
    AyahBuilderWord('أَعُوذُ', "A'udhu"),
    AyahBuilderWord('بِرَبِّ', 'Birabbi'),
    AyahBuilderWord('الْفَلَقِ', 'Al-Falaq'),
  ],
);

const AyahBuilderSession ayahNasSession = AyahBuilderSession(
  stage: 6,
  label: 'Session 6',
  sessionName: 'An-Nas',
  short: 'An-Nas',
  englishTranslation: 'Say, I seek refuge in the Lord of mankind.',
  cheer: 'You know this one now.',
  words: [
    AyahBuilderWord('قُلْ', 'Qul'),
    AyahBuilderWord('أَعُوذُ', "A'udhu"),
    AyahBuilderWord('بِرَبِّ', 'Birabbi'),
    AyahBuilderWord('النَّاسِ', 'An-Nas'),
  ],
);

const AyahBuilderSession ayahKawtharSession = AyahBuilderSession(
  stage: 7,
  label: 'Session 7',
  sessionName: 'Al-Kawthar',
  short: 'Al-Kawthar',
  englishTranslation: 'Indeed, We have given you Al-Kawthar.',
  cheer: 'Three words. A whole ayah.',
  words: [
    AyahBuilderWord('إِنَّا', 'Inna'),
    AyahBuilderWord('أَعْطَيْنَاكَ', "A'taynaka"),
    AyahBuilderWord('الْكَوْثَرَ', 'Al-Kawthar'),
  ],
);

const List<AyahBuilderSession> ayahBuilderSessions = [
  ayahBasmalahSession,
  ayahFatihah1Session,
  ayahFatihah2Session,
  ayahIkhlasSession,
  ayahFalaqSession,
  ayahNasSession,
  ayahKawtharSession,
];

const List<GreetingQuestion> greetingQuestions = [
  GreetingQuestion(
    id: 'greet1',
    phrase: 'As-salāmu ʿalaykum',
    arabic: 'اَلسَّلامُ عَلَيْكُم',
    choices: [
      GreetingChoice(
        translit: 'Marhaban',
        meaning: 'Hello / Welcome.',
        emoji: '👋',
        correct: false,
      ),
      GreetingChoice(
        translit: 'As-salāmu ʿalaykum',
        meaning: 'Peace be upon you.',
        emoji: '🕊️',
        correct: true,
      ),
      GreetingChoice(
        translit: 'Maʿa as-salāmah',
        meaning: 'Goodbye.',
        emoji: '🤗',
        correct: false,
      ),
      GreetingChoice(
        translit: 'Wa ʿalaykum as-salām',
        meaning: 'And peace be upon you too.',
        emoji: '🤲',
        correct: false,
      ),
    ],
  ),
  GreetingQuestion(
    id: 'greet2',
    phrase: 'Wa ʿalaykum as-salām',
    arabic: 'وَعَلَيْكُمُ السَّلام',
    choices: [
      GreetingChoice(
        translit: 'Wa ʿalaykum as-salām',
        meaning: 'And peace be upon you too.',
        emoji: '🤲',
        correct: true,
      ),
      GreetingChoice(
        translit: 'Ahlan wa sahlan',
        meaning: 'Welcome!',
        emoji: '😊',
        correct: false,
      ),
      GreetingChoice(
        translit: 'Ilā al-liqāʾ',
        meaning: 'See you again.',
        emoji: '🤝',
        correct: false,
      ),
      GreetingChoice(
        translit: 'As-salāmu ʿalaykum',
        meaning: 'Peace be upon you.',
        emoji: '🕊️',
        correct: false,
      ),
    ],
  ),
  GreetingQuestion(
    id: 'greet3',
    phrase: 'Marhaban',
    arabic: 'مَرْحَبًا',
    choices: [
      GreetingChoice(
        translit: 'Masāʾ al-khayr',
        meaning: 'Good evening.',
        emoji: '🌆',
        correct: false,
      ),
      GreetingChoice(
        translit: 'Ahlan wa sahlan',
        meaning: 'Welcome!',
        emoji: '😊',
        correct: false,
      ),
      GreetingChoice(
        translit: 'Marhaban',
        meaning: 'Hello / Welcome.',
        emoji: '👋',
        correct: true,
      ),
      GreetingChoice(
        translit: 'Ṣabāḥ al-khayr',
        meaning: 'Good morning.',
        emoji: '🌅',
        correct: false,
      ),
    ],
  ),
  GreetingQuestion(
    id: 'greet4',
    phrase: 'Ahlan wa sahlan',
    arabic: 'أَهْلاً وَسَهْلاً',
    choices: [
      GreetingChoice(
        translit: 'Ahlan wa sahlan',
        meaning: 'Welcome!',
        emoji: '😊',
        correct: true,
      ),
      GreetingChoice(
        translit: 'Masāʾ an-nūr',
        meaning: 'Good evening (reply).',
        emoji: '🌙',
        correct: false,
      ),
      GreetingChoice(
        translit: 'Marhaban',
        meaning: 'Hello / Welcome.',
        emoji: '👋',
        correct: false,
      ),
      GreetingChoice(
        translit: 'Ṣabāḥ an-nūr',
        meaning: 'Good morning (reply).',
        emoji: '☀️',
        correct: false,
      ),
    ],
  ),
  GreetingQuestion(
    id: 'greet5',
    phrase: 'Ṣabāḥ al-khayr',
    arabic: 'صَباحُ الخَيْر',
    choices: [
      GreetingChoice(
        translit: 'Ṣabāḥ an-nūr',
        meaning: 'Good morning (reply).',
        emoji: '☀️',
        correct: false,
      ),
      GreetingChoice(
        translit: 'Ṣabāḥ al-khayr',
        meaning: 'Good morning.',
        emoji: '🌅',
        correct: true,
      ),
      GreetingChoice(
        translit: 'As-salāmu ʿalaykum',
        meaning: 'Peace be upon you.',
        emoji: '🕊️',
        correct: false,
      ),
      GreetingChoice(
        translit: 'Masāʾ al-khayr',
        meaning: 'Good evening.',
        emoji: '🌆',
        correct: false,
      ),
    ],
  ),
  GreetingQuestion(
    id: 'greet6',
    phrase: 'Ṣabāḥ an-nūr',
    arabic: 'صَباحُ النُّور',
    choices: [
      GreetingChoice(
        translit: 'Ṣabāḥ an-nūr',
        meaning: 'Good morning (reply).',
        emoji: '☀️',
        correct: true,
      ),
      GreetingChoice(
        translit: 'Wa ʿalaykum as-salām',
        meaning: 'And peace be upon you too.',
        emoji: '🤲',
        correct: false,
      ),
      GreetingChoice(
        translit: 'Ṣabāḥ al-khayr',
        meaning: 'Good morning.',
        emoji: '🌅',
        correct: false,
      ),
      GreetingChoice(
        translit: 'Masāʾ an-nūr',
        meaning: 'Good evening (reply).',
        emoji: '🌙',
        correct: false,
      ),
    ],
  ),
  GreetingQuestion(
    id: 'greet7',
    phrase: 'Masāʾ al-khayr',
    arabic: 'مَساءُ الخَيْر',
    choices: [
      GreetingChoice(
        translit: 'Maʿa as-salāmah',
        meaning: 'Goodbye.',
        emoji: '🤗',
        correct: false,
      ),
      GreetingChoice(
        translit: 'Masāʾ al-khayr',
        meaning: 'Good evening.',
        emoji: '🌆',
        correct: true,
      ),
      GreetingChoice(
        translit: 'Masāʾ an-nūr',
        meaning: 'Good evening (reply).',
        emoji: '🌙',
        correct: false,
      ),
      GreetingChoice(
        translit: 'Ṣabāḥ al-khayr',
        meaning: 'Good morning.',
        emoji: '🌅',
        correct: false,
      ),
    ],
  ),
  GreetingQuestion(
    id: 'greet8',
    phrase: 'Masāʾ an-nūr',
    arabic: 'مَساءُ النُّور',
    choices: [
      GreetingChoice(
        translit: 'Masāʾ an-nūr',
        meaning: 'Good evening (reply).',
        emoji: '🌙',
        correct: true,
      ),
      GreetingChoice(
        translit: 'Masāʾ al-khayr',
        meaning: 'Good evening.',
        emoji: '🌆',
        correct: false,
      ),
      GreetingChoice(
        translit: 'Ilā al-liqāʾ',
        meaning: 'See you again.',
        emoji: '🤝',
        correct: false,
      ),
      GreetingChoice(
        translit: 'Ṣabāḥ an-nūr',
        meaning: 'Good morning (reply).',
        emoji: '☀️',
        correct: false,
      ),
    ],
  ),
  GreetingQuestion(
    id: 'greet9',
    phrase: 'Maʿa as-salāmah',
    arabic: 'مَعَ السَّلامَة',
    choices: [
      GreetingChoice(
        translit: 'Ilā al-liqāʾ',
        meaning: 'See you again.',
        emoji: '🤝',
        correct: false,
      ),
      GreetingChoice(
        translit: 'Alḥamdulillāh',
        meaning: 'All praise is due to Allah.',
        emoji: '🤍',
        correct: false,
      ),
      GreetingChoice(
        translit: 'Maʿa as-salāmah',
        meaning: 'Goodbye.',
        emoji: '🤗',
        correct: true,
      ),
      GreetingChoice(
        translit: 'As-salāmu ʿalaykum',
        meaning: 'Peace be upon you.',
        emoji: '🕊️',
        correct: false,
      ),
    ],
  ),
  GreetingQuestion(
    id: 'greet10',
    phrase: 'Ilā al-liqāʾ',
    arabic: 'إِلى اللِّقاء',
    choices: [
      GreetingChoice(
        translit: 'Subḥānallāh',
        meaning: 'Glory be to Allah.',
        emoji: '✨',
        correct: false,
      ),
      GreetingChoice(
        translit: 'Ilā al-liqāʾ',
        meaning: 'See you again.',
        emoji: '🤝',
        correct: true,
      ),
      GreetingChoice(
        translit: 'Maʿa as-salāmah',
        meaning: 'Goodbye.',
        emoji: '🤗',
        correct: false,
      ),
      GreetingChoice(
        translit: 'Wa ʿalaykum as-salām',
        meaning: 'And peace be upon you too.',
        emoji: '🤲',
        correct: false,
      ),
    ],
  ),
];

const List<FlashCard> animalsCards = [
  FlashCard(
    id: 'a1',
    emoji: '🦁',
    arabic: 'أَسَد',
    translit: 'Asad',
    english: 'Lion',
    color: '#FDECC8',
  ),
  FlashCard(
    id: 'a2',
    emoji: '🐘',
    arabic: 'فِيل',
    translit: 'Fil',
    english: 'Elephant',
    color: '#E8E4FF',
  ),
  FlashCard(
    id: 'a3',
    emoji: '🐪',
    arabic: 'جَمَل',
    translit: 'Jamal',
    english: 'Camel',
    color: '#FDDCCC',
  ),
  FlashCard(
    id: 'a4',
    emoji: '🦋',
    arabic: 'فَرَاشَة',
    translit: 'Farasha',
    english: 'Butterfly',
    color: '#DCF0E6',
  ),
  FlashCard(
    id: 'a5',
    emoji: '🐟',
    arabic: 'سَمَكَة',
    translit: 'Samaka',
    english: 'Fish',
    color: '#E8F4FF',
  ),
  FlashCard(
    id: 'a6',
    emoji: '🐦',
    arabic: 'عُصْفُور',
    translit: 'Usfur',
    english: 'Bird / Sparrow',
    color: '#FDECC8',
  ),
  FlashCard(
    id: 'a7',
    emoji: '🐝',
    arabic: 'نَحْلَة',
    translit: 'Nahla',
    english: 'Bee',
    color: '#FDECC8',
  ),
  FlashCard(
    id: 'a8',
    emoji: '🐰',
    arabic: 'أَرْنَب',
    translit: 'Arnab',
    english: 'Rabbit',
    color: '#E8F4FF',
  ),
  FlashCard(
    id: 'a9',
    emoji: '🐎',
    arabic: 'حِصَان',
    translit: 'Hisan',
    english: 'Horse',
    color: '#FDDCCC',
  ),
  FlashCard(
    id: 'a10',
    emoji: '🐑',
    arabic: 'خَرُوف',
    translit: 'Kharuf',
    english: 'Sheep / Lamb',
    color: '#DCF0E6',
  ),
];

const List<FlashCard> familyCards = [
  FlashCard(
    id: 'f1',
    emoji: '👨🏽',
    arabic: 'أَب',
    translit: 'Ab',
    english: 'Father',
    color: '#E8F4FF',
  ),
  FlashCard(
    id: 'f2',
    emoji: '👩🏽',
    arabic: 'أُمّ',
    translit: 'Umm',
    english: 'Mother',
    color: '#FDDCCC',
  ),
  FlashCard(
    id: 'f3',
    emoji: '👦🏽',
    arabic: 'أَخ',
    translit: 'Akh',
    english: 'Brother',
    color: '#DCF0E6',
  ),
  FlashCard(
    id: 'f4',
    emoji: '👧🏽',
    arabic: 'أُخْت',
    translit: 'Ukht',
    english: 'Sister',
    color: '#FDECC8',
  ),
  FlashCard(
    id: 'f5',
    emoji: '👴🏽',
    arabic: 'جَدّ',
    translit: 'Jadd',
    english: 'Grandfather',
    color: '#E8E4FF',
  ),
  FlashCard(
    id: 'f6',
    emoji: '👵🏽',
    arabic: 'جَدَّة',
    translit: 'Jadda',
    english: 'Grandmother',
    color: '#FDDCCC',
  ),
  FlashCard(
    id: 'f7',
    emoji: '👨‍👩‍👧‍👦',
    arabic: 'أُسْرَة',
    translit: 'Usra',
    english: 'Family',
    color: '#DCF0E6',
  ),
  FlashCard(
    id: 'f8',
    emoji: '👶🏽',
    arabic: 'طِفْل',
    translit: 'Tifl',
    english: 'Baby / Child',
    color: '#FDECC8',
  ),
];

const List<FlashCard> foodCards = [
  FlashCard(
    id: 'fd1',
    emoji: '🍎',
    arabic: 'تُفَّاحَة',
    translit: 'Tuffaha',
    english: 'Apple',
    color: '#FDDCCC',
  ),
  FlashCard(
    id: 'fd2',
    emoji: '🍞',
    arabic: 'خُبْز',
    translit: 'Khubz',
    english: 'Bread',
    color: '#FDECC8',
  ),
  FlashCard(
    id: 'fd3',
    emoji: '💧',
    arabic: 'مَاء',
    translit: 'Ma\'',
    english: 'Water',
    color: '#E8F4FF',
  ),
  FlashCard(
    id: 'fd4',
    emoji: '🥛',
    arabic: 'لَبَن',
    translit: 'Laban',
    english: 'Milk',
    color: '#F5F5F5',
  ),
  FlashCard(
    id: 'fd5',
    emoji: '🍚',
    arabic: 'رُزّ',
    translit: 'Ruzz',
    english: 'Rice',
    color: '#FDECC8',
  ),
  FlashCard(
    id: 'fd6',
    emoji: '🌴',
    arabic: 'تَمْر',
    translit: 'Tamr',
    english: 'Dates (fruit)',
    color: '#FDECC8',
  ),
  FlashCard(
    id: 'fd7',
    emoji: '🍯',
    arabic: 'عَسَل',
    translit: 'Asal',
    english: 'Honey',
    color: '#FDECC8',
  ),
  FlashCard(
    id: 'fd8',
    emoji: '🫘',
    arabic: 'عَدَس',
    translit: 'Adas',
    english: 'Lentils',
    color: '#FDDCCC',
  ),
];

const List<QuizQ> familyQuiz = [
  QuizQ(
    id: 'fq1',
    emoji: '👨🏽',
    question: 'أَب means...',
    options: ['Brother', 'Father ✓', 'Grandfather', 'Uncle'],
    correct: 1,
    tip: 'أَب (Ab) = Father!',
  ),
  QuizQ(
    id: 'fq2',
    emoji: '👧🏽',
    question: '\'Sister\' in Arabic is...',
    options: ['أَخ', 'أُمّ', 'أُخْت ✓', 'جَدّ'],
    correct: 2,
    tip: 'أُخْت (Ukht) = Sister!',
  ),
  QuizQ(
    id: 'fq3',
    emoji: '👴🏽',
    question: 'جَدّ means...',
    options: ['Father', 'Grandmother', 'Brother', 'Grandfather ✓'],
    correct: 3,
    tip: 'جَدّ (Jadd) = Grandfather — the wise elder!',
  ),
  QuizQ(
    id: 'fq4',
    emoji: '👨‍👩‍👧‍👦',
    question: 'The Arabic word for \'family\' is...',
    options: ['أُخْت', 'أُسْرَة ✓', 'حَقِيبَة', 'مَدْرَسَة'],
    correct: 1,
    tip: 'أُسْرَة (Usra) = Family!',
  ),
];

// ─────────────────────────────────────────────────────────────
// DESTINATION 4 -- River of Sirah
// ─────────────────────────────────────────────────────────────

const List<FlashCard> prophetCards = [
  FlashCard(
    id: 'pr1',
    emoji: '🕌',
    arabic: 'مَكَّة المُكَرَّمَة',
    translit: 'Makkah al-Mukarramah',
    english: 'Makkah -- birthplace of Prophet Muhammad ﷺ',
    color: '#FDECC8',
  ),
  FlashCard(
    id: 'pr2',
    emoji: '📅',
    arabic: 'عَام الفِيل — ٥٧٠م',
    translit: '\'Aam al-Fil — 570 CE',
    english: 'Year of the Elephant -- the year he was born',
    color: '#E8E4FF',
  ),
  FlashCard(
    id: 'pr3',
    emoji: '👶🏽',
    arabic: 'مُحَمَّد بن عَبْدِ اللّٰه',
    translit: 'Muhammad ibn Abdillah',
    english: 'His full name: Muhammad, son of Abdullah',
    color: '#FDDCCC',
  ),
  FlashCard(
    id: 'pr4',
    emoji: '🌟',
    arabic: 'مُحَمَّد — المَحْمُود',
    translit: 'Muhammad — Al-Mahmud',
    english: 'Muhammad means \'The Praised One\'',
    color: '#FDECC8',
  ),
  FlashCard(
    id: 'pr5',
    emoji: '👩🏽',
    arabic: 'السَّيِّدَة آمِنَة',
    translit: 'As-Sayyida Aminah',
    english: 'His mother: Aminah bint Wahb',
    color: '#DCF0E6',
  ),
  FlashCard(
    id: 'pr6',
    emoji: '👴🏽',
    arabic: 'عَبْد المُطَّلِب',
    translit: '\'Abdul Muttalib',
    english: 'His grandfather: Abdul Muttalib, who named him',
    color: '#E8F4FF',
  ),
  FlashCard(
    id: 'pr7',
    emoji: '🤱🏽',
    arabic: 'حَلِيمَة السَّعْدِيَّة',
    translit: 'Halimah as-Sa\'diyyah',
    english: 'His nurse from the desert: Halimah -- blessings came with him!',
    color: '#FDDCCC',
  ),
  FlashCard(
    id: 'pr8',
    emoji: '✅',
    arabic: 'الأَمِين',
    translit: 'Al-Amin',
    english: 'His nickname: Al-Amin -- \'The Trustworthy One\'',
    color: '#DCF0E6',
  ),
];

const List<StoryPanel> storyProphet = [
  StoryPanel(
    id: 'pr_s1',
    bg: 'linear-gradient(160deg, #1a2744 0%, #2A3F6F 100%)',
    scene: [
      StorySceneItem(emoji: '🌙', x: 65, y: 10, size: 55),
      StorySceneItem(emoji: '⭐', x: 22, y: 22, size: 38),
      StorySceneItem(emoji: '⭐', x: 75, y: 35, size: 28),
      StorySceneItem(emoji: '✨', x: 43, y: 18, size: 22),
      StorySceneItem(emoji: '🕌', x: 43, y: 55, size: 85),
      StorySceneItem(emoji: '🌟', x: 15, y: 55, size: 30),
    ],
    caption:
        'In the holy city of Makkah, in the Year of the Elephant (570 CE), a special night arrived...',
    captionAr:
        'في مدينة مكّة المكرَّمة، في عام الفيل (570م)، جاءت ليلةٌ مميَّزة...',
  ),
  StoryPanel(
    id: 'pr_s2',
    bg: 'linear-gradient(160deg, #FDECC8 0%, #EF9F27 100%)',
    scene: [
      StorySceneItem(emoji: '👶🏽', x: 43, y: 35, size: 80),
      StorySceneItem(emoji: '🌟', x: 30, y: 15, size: 45),
      StorySceneItem(emoji: '✨', x: 65, y: 20, size: 35),
      StorySceneItem(emoji: '💛', x: 43, y: 68, size: 35),
    ],
    bubble: StoryBubble(text: 'مُحَمَّد — The Praised One ﷺ', side: 'center'),
    caption:
        'A baby boy was born -- his grandfather named him Muhammad, \'The Praised One\'. The angels rejoiced!',
    captionAr: 'وُلِد طفلٌ — سمّاه جدّه مُحَمَّداً \'المحمود\'. فرحت الملائكة!',
  ),
  StoryPanel(
    id: 'pr_s3',
    bg: 'linear-gradient(160deg, #DCF0E6 0%, #5B9A1E 100%)',
    scene: [
      StorySceneItem(emoji: '🤱🏽', x: 28, y: 42, size: 80),
      StorySceneItem(emoji: '👶🏽', x: 58, y: 48, size: 60),
      StorySceneItem(emoji: '🐑', x: 15, y: 68, size: 40),
      StorySceneItem(emoji: '🐑', x: 72, y: 65, size: 38),
      StorySceneItem(emoji: '🌸', x: 43, y: 15, size: 50),
    ],
    bubble: StoryBubble(text: 'بَارَكَ اللّٰهُ فِيكَ! 💚', side: 'left'),
    caption:
        'A Bedouin woman named Halimah became his nurse. Wherever baby Muhammad ﷺ went -- blessings followed!',
    captionAr:
        'أصبحت امرأة بدوية تُدعى حليمة مُرضِعَته. أينما ذهب الطفل محمّد ﷺ — تبعته البركة!',
  ),
  StoryPanel(
    id: 'pr_s4',
    bg: 'linear-gradient(160deg, #FDECC8 0%, #D85A30 100%)',
    scene: [
      StorySceneItem(emoji: '👦🏽', x: 43, y: 48, size: 78),
      StorySceneItem(emoji: '👥', x: 22, y: 58, size: 50),
      StorySceneItem(emoji: '👥', x: 65, y: 55, size: 48),
      StorySceneItem(emoji: '💚', x: 43, y: 20, size: 45),
    ],
    bubble: StoryBubble(text: 'الأَمِين — The Trustworthy! ✅', side: 'center'),
    caption:
        'Young Muhammad ﷺ never lied, never hurt anyone. Everyone loved and trusted him -- Al-Amin!',
    captionAr:
        'محمّد الشابّ ﷺ لم يكذب ولم يؤذِ أحداً. كلّ الناس أحبّوه ووثقوا به — الأمين!',
  ),
  StoryPanel(
    id: 'pr_s5',
    bg: 'linear-gradient(160deg, #0F6E56 0%, #2A7FCC 100%)',
    scene: [
      StorySceneItem(emoji: '🌍', x: 43, y: 20, size: 80),
      StorySceneItem(emoji: '💚', x: 43, y: 55, size: 55),
      StorySceneItem(emoji: '⭐', x: 20, y: 48, size: 38),
      StorySceneItem(emoji: '⭐', x: 68, y: 42, size: 35),
    ],
    caption:
        'Allah chose Muhammad ﷺ as the Final Prophet -- to bring mercy, peace and guidance to all of humanity! 🌟',
    captionAr:
        'اختار اللّٰه محمّداً ﷺ خاتمَ الأنبياء — ليُحضر الرحمة والسلام والهداية لكلّ البشريّة! 🌟',
  ),
];

const List<QuizQ> sirahQuiz = [
  QuizQ(
    id: 'sq1',
    emoji: '🕌',
    question: 'Where was Prophet Muhammad ﷺ born?',
    options: ['Madinah', 'Jerusalem', 'Makkah ✓', 'Cairo'],
    correct: 2,
    tip:
        'Prophet Muhammad ﷺ was born in the holy city of Makkah al-Mukarramah!',
  ),
  QuizQ(
    id: 'sq2',
    emoji: '📅',
    question: 'What year was Prophet Muhammad ﷺ born?',
    options: [
      'Year of the Elephant 570 CE ✓',
      'Year 600 CE',
      'Year 500 CE',
      'Year of the Rainbow',
    ],
    correct: 0,
    tip: 'He was born in 570 CE — the Year of the Elephant (Aam Al-Fil)!',
  ),
  QuizQ(
    id: 'sq3',
    emoji: '🌟',
    question: 'What does the name \'Muhammad\' mean?',
    options: [
      'The Strong One',
      'The Wise One',
      'The Peaceful One',
      'The Praised One ✓',
    ],
    correct: 3,
    tip:
        'Muhammad means \'Al-Mahmud\' — The Praised One — the most beautiful name!',
  ),
  QuizQ(
    id: 'sq4',
    emoji: '👩🏽',
    question: 'Who was Prophet Muhammad\'s ﷺ mother?',
    options: ['Halimah', 'Aminah ✓', 'Khadijah', 'Fatimah'],
    correct: 1,
    tip: 'His mother was Aminah bint Wahb — she loved him dearly!',
  ),
  QuizQ(
    id: 'sq5',
    emoji: '✅',
    question: 'Why did people call him \'Al-Amin\'?',
    options: [
      'He was very rich',
      'He was very strong',
      'He was always trustworthy and honest ✓',
      'He was very tall',
    ],
    correct: 2,
    tip:
        'Al-Amin means The Trustworthy — he never lied and always kept promises!',
  ),
  QuizQ(
    id: 'sq6',
    emoji: '🤱🏽',
    question: 'Who was Prophet Muhammad\'s ﷺ nurse from the desert?',
    options: ['Aminah', 'Khadijah', 'Halimah as-Sa\'diyyah ✓', 'Fatimah'],
    correct: 2,
    tip: 'Halimah took care of baby Muhammad ﷺ — blessings came to her family!',
  ),
];

const List<FlashCard> hadithMannersCards = [
  FlashCard(
    id: 'hm1',
    emoji: '😊',
    arabic: '"تَبَسُّمُكَ فِي وَجْهِ أَخِيكَ صَدَقَة"',
    translit: '"Tabassmuka fi wajhi akhika sadaqa"',
    english: '"Your smile in your brother\'s face is charity." — Prophet ﷺ',
    color: '#FDECC8',
  ),
  FlashCard(
    id: 'hm2',
    emoji: '🤝',
    arabic: '"المُسْلِمُ أَخُو المُسْلِم"',
    translit: '"Al-Muslimu akhu al-Muslim"',
    english: '"A Muslim is the brother of a Muslim." — Prophet ﷺ',
    color: '#DCF0E6',
  ),
  FlashCard(
    id: 'hm3',
    emoji: '💧',
    arabic: '"إِمَاطَةُ الأَذَى عَنِ الطَّرِيقِ صَدَقَة"',
    translit: '\'Imatu al-adha anis-tariq sadaqa\'',
    english:
        '"Removing something harmful from the road is charity." — Prophet ﷺ',
    color: '#E8F4FF',
  ),
  FlashCard(
    id: 'hm4',
    emoji: '🌱',
    arabic: '"الدِّينُ النَّصِيحَة"',
    translit: '\'Ad-Dinu an-nasiha\'',
    english: '"Religion is sincere advice." — Prophet ﷺ',
    color: '#DCF0E6',
  ),
  FlashCard(
    id: 'hm5',
    emoji: '🍽️',
    arabic: '"كُلْ بِيَمِينِكَ وَكُلْ مِمَّا يَلِيكَ"',
    translit: '"Kul biyaminika wa kul mimma yalika"',
    english:
        '"Eat with your right hand and eat from what is in front of you." — Prophet ﷺ',
    color: '#FDDCCC',
  ),
];

const List<StoryPanel> storyMiko = [
  StoryPanel(
    id: 'mk1',
    bg: 'linear-gradient(160deg, #DCF0E6 0%, #A8D8EA 100%)',
    scene: [
      StorySceneItem(emoji: '🐻', x: 30, y: 45, size: 75),
      StorySceneItem(emoji: '🐰', x: 65, y: 52, size: 58),
      StorySceneItem(emoji: '📚', x: 62, y: 75, size: 35),
      StorySceneItem(emoji: '📖', x: 68, y: 72, size: 30),
      StorySceneItem(emoji: '🌸', x: 12, y: 68, size: 25),
    ],
    caption:
        'Miko was rushing to class when he bumped into Bunny -- her books went flying!',
    captionAr: 'كان ميكو يتسرّع للذهاب للصف حين اصطدم بأرنبة — طارت كتبها!',
  ),
  StoryPanel(
    id: 'mk2',
    bg: 'linear-gradient(160deg, #FDDCCC 0%, #FDECC8 100%)',
    scene: [
      StorySceneItem(emoji: '🐻', x: 25, y: 48, size: 72),
      StorySceneItem(emoji: '🐰', x: 65, y: 55, size: 55),
      StorySceneItem(emoji: '😢', x: 68, y: 38, size: 35),
      StorySceneItem(emoji: '📚', x: 60, y: 75, size: 32),
    ],
    caption: 'Miko kept walking... Bunny looked sad. 😔',
    captionAr: 'مضى ميكو في طريقه... ونظرت الأرنبة بحزن. 😔',
  ),
  StoryPanel(
    id: 'mk3',
    bg: 'linear-gradient(160deg, #FDECC8 0%, #DCF0E6 100%)',
    scene: [
      StorySceneItem(emoji: '🐻', x: 43, y: 50, size: 70),
      StorySceneItem(emoji: '💭', x: 62, y: 18, size: 75),
    ],
    bubble: StoryBubble(
      text: 'تَبَسُّمُكَ فِي وَجْهِ أَخِيكَ صَدَقَة 💛',
      side: 'right',
    ),
    caption:
        'Then Miko remembered what Ustazah taught: Your smile to your brother is charity!',
    captionAr: 'ثم تذكّر ميكو ما علّمته المعلّمة: تبسّمك في وجه أخيك صدقة!',
  ),
  StoryPanel(
    id: 'mk4',
    bg: 'linear-gradient(160deg, #0F6E56 0%, #5B9A1E 100%)',
    scene: [
      StorySceneItem(emoji: '🐻', x: 28, y: 48, size: 72),
      StorySceneItem(emoji: '🐰', x: 63, y: 52, size: 58),
      StorySceneItem(emoji: '📚', x: 44, y: 72, size: 38),
      StorySceneItem(emoji: '💚', x: 44, y: 28, size: 45),
    ],
    bubble: StoryBubble(text: 'أَنَا آسِف جِدًّا! 🙏', side: 'left'),
    caption:
        'Miko ran back, helped pick up all the books, and said sorry. Bunny smiled! 😊',
    captionAr: 'عاد ميكو، ساعد في جمع الكتب، واعتذر. ابتسمت الأرنبة! 😊',
  ),
  StoryPanel(
    id: 'mk5',
    bg: 'linear-gradient(160deg, #EF9F27 0%, #D85A30 100%)',
    scene: [
      StorySceneItem(emoji: '🐻', x: 28, y: 48, size: 72),
      StorySceneItem(emoji: '🐰', x: 63, y: 50, size: 58),
      StorySceneItem(emoji: '💛', x: 43, y: 18, size: 55),
      StorySceneItem(emoji: '🌟', x: 18, y: 38, size: 30),
      StorySceneItem(emoji: '🌟', x: 70, y: 35, size: 28),
    ],
    caption:
        'The Prophet ﷺ said: A kind word and a smile change everything. Be kind -- it is charity! 😊',
    captionAr:
        'قال النبيّ ﷺ: كلمةٌ طيّبة وابتسامة تغيّران كلّ شيء. كُن طيّباً — إنّها صدقة! 😊',
  ),
];

// ─────────────────────────────────────────────────────────────
// DESTINATION 5 -- Masjid of Salah
// ─────────────────────────────────────────────────────────────

const List<StoryPanel> wuduStory = [
  StoryPanel(
    id: 'wu1',
    bg: 'linear-gradient(160deg, #DCF0E6 0%, #A8D8EA 100%)',
    scene: [
      StorySceneItem(emoji: '🕌', x: 43, y: 8, size: 80),
      StorySceneItem(emoji: '👦🏽', x: 43, y: 60, size: 65),
      StorySceneItem(emoji: '🌙', x: 72, y: 18, size: 35),
      StorySceneItem(emoji: '⭐', x: 22, y: 22, size: 25),
    ],
    caption:
        'It is Dhuhr time! Rayan wants to pray -- but first, Wudu! الوُضُوء',
    captionAr: 'حان وقت الظهر! يريد ريّان أن يصلّي — لكن أوّلاً الوضوء!',
  ),
  StoryPanel(
    id: 'wu2',
    bg: 'linear-gradient(160deg, #A8D8EA 0%, #E8F4FF 100%)',
    scene: [
      StorySceneItem(emoji: '🚿', x: 43, y: 12, size: 65),
      StorySceneItem(emoji: '💧', x: 28, y: 42, size: 35),
      StorySceneItem(emoji: '💧', x: 55, y: 45, size: 30),
      StorySceneItem(emoji: '👐', x: 43, y: 62, size: 55),
    ],
    bubble: StoryBubble(text: 'بِسْمِ اللّٰهِ ✨', side: 'center'),
    caption:
        'Step 1: Niyyah (intention). Step 2: Say Bismillah! Step 3: Wash BOTH HANDS 3 times! 💧',
    captionAr:
        'الخطوة 1: النيّة. الخطوة 2: قل بسم اللّٰه! الخطوة 3: اغسل كلتا يديك 3 مرات! 💧',
  ),
  StoryPanel(
    id: 'wu3',
    bg: 'linear-gradient(160deg, #E8F4FF 0%, #DCF0E6 100%)',
    scene: [
      StorySceneItem(emoji: '💧', x: 25, y: 20, size: 40),
      StorySceneItem(emoji: '💧', x: 62, y: 22, size: 35),
      StorySceneItem(emoji: '😮', x: 43, y: 50, size: 65),
    ],
    caption:
        'Step 4: Rinse mouth 3 times  •  Step 5: Sniff water into nose 3 times  •  Step 6: Wash face 3 times',
    captionAr:
        'الخطوة 4: المضمضة 3×  •  الخطوة 5: الاستنشاق 3×  •  الخطوة 6: غسل الوجه 3×',
  ),
  StoryPanel(
    id: 'wu4',
    bg: 'linear-gradient(160deg, #FDECC8 0%, #DCF0E6 100%)',
    scene: [
      StorySceneItem(emoji: '💪', x: 30, y: 40, size: 65),
      StorySceneItem(emoji: '💪', x: 62, y: 42, size: 62, flip: true),
      StorySceneItem(emoji: '💧', x: 43, y: 20, size: 40),
    ],
    caption:
        'Step 7: Wash RIGHT arm to elbow 3 times  •  Step 8: Wash LEFT arm to elbow 3 times',
    captionAr:
        'الخطوة 7: غسل الذراع الأيمن حتى المرفق 3×  •  الخطوة 8: غسل الذراع الأيسر 3×',
  ),
  StoryPanel(
    id: 'wu5',
    bg: 'linear-gradient(160deg, #0F6E56 0%, #5B9A1E 100%)',
    scene: [
      StorySceneItem(emoji: '🌟', x: 43, y: 12, size: 70),
      StorySceneItem(emoji: '👦🏽', x: 43, y: 55, size: 70),
      StorySceneItem(emoji: '✨', x: 18, y: 42, size: 35),
      StorySceneItem(emoji: '✨', x: 70, y: 38, size: 32),
    ],
    caption:
        'Step 9: Wipe head  •  Step 10: Wipe ears  •  Step 11: Wash BOTH FEET 3× — Wudu complete! 🌟',
    captionAr:
        'الخطوة 9: مسح الرأس  •  الخطوة 10: مسح الأذنين  •  الخطوة 11: غسل القدمين 3× — اكتمل الوضوء! 🌟',
  ),
];

const List<FlashCard> salahCards = [
  FlashCard(
    id: 'sl1',
    emoji: '🌅',
    arabic: 'صَلَاة الفَجْر\n٢ رَكْعَات',
    translit: 'Salat al-Fajr',
    english: 'Fajr — Dawn Prayer — 2 rakah (before sunrise)',
    color: '#E8E4FF',
  ),
  FlashCard(
    id: 'sl2',
    emoji: '☀️',
    arabic: 'صَلَاة الظُّهْر\n٤ رَكْعَات',
    translit: 'Salat az-Zuhr',
    english: 'Zuhr — Midday Prayer — 4 rakah (when sun passes highest)',
    color: '#FDECC8',
  ),
  FlashCard(
    id: 'sl3',
    emoji: '🌤️',
    arabic: 'صَلَاة العَصْر\n٤ رَكْعَات',
    translit: 'Salat al-\'Asr',
    english: '\'Asr — Afternoon Prayer — 4 rakah (mid-afternoon)',
    color: '#FDDCCC',
  ),
  FlashCard(
    id: 'sl4',
    emoji: '🌇',
    arabic: 'صَلَاة المَغْرِب\n٣ رَكْعَات',
    translit: 'Salat al-Maghrib',
    english: 'Maghrib — Sunset Prayer — 3 rakah (just after sunset)',
    color: '#FDDCCC',
  ),
  FlashCard(
    id: 'sl5',
    emoji: '🌙',
    arabic: 'صَلَاة العِشَاء\n٤ رَكْعَات',
    translit: 'Salat al-\'Isha',
    english: '\'Isha — Night Prayer — 4 rakah (night time)',
    color: '#E8E4FF',
  ),
];

const List<FlashCard> adhanCards = [
  FlashCard(
    id: 'ad1',
    emoji: '📢',
    arabic: 'اللّٰهُ أَكْبَر، اللّٰهُ أَكْبَر',
    translit: 'Allahu Akbar, Allahu Akbar',
    english: 'Allah is the Greatest (x2 -- said 4 times total)',
    color: '#FDECC8',
  ),
  FlashCard(
    id: 'ad2',
    emoji: '☝️',
    arabic: 'أَشْهَدُ أَنْ لَا إِلٰهَ إِلَّا اللّٰه',
    translit: 'Ashhadu an la ilaha illallah',
    english: 'I bear witness that there is no god but Allah (x2)',
    color: '#E8F4FF',
  ),
  FlashCard(
    id: 'ad3',
    emoji: '🌟',
    arabic: 'أَشْهَدُ أَنَّ مُحَمَّدًا رَسُولُ اللّٰه',
    translit: 'Ashhadu anna Muhammadan rasulullah',
    english: 'I bear witness that Muhammad is the Messenger of Allah (x2)',
    color: '#FDDCCC',
  ),
  FlashCard(
    id: 'ad4',
    emoji: '🕌',
    arabic: 'حَيَّ عَلَى الصَّلَاة',
    translit: 'Hayya alas-salah',
    english: 'Come to prayer! (x2)',
    color: '#DCF0E6',
  ),
  FlashCard(
    id: 'ad5',
    emoji: '💫',
    arabic: 'حَيَّ عَلَى الفَلَاح',
    translit: 'Hayya alal-falah',
    english: 'Come to success! (x2)',
    color: '#FDECC8',
  ),
  FlashCard(
    id: 'ad6',
    emoji: '✨',
    arabic: 'اللّٰهُ أَكْبَر، لَا إِلٰهَ إِلَّا اللّٰه',
    translit: 'Allahu Akbar, la ilaha illallah',
    english: 'Allah is Greatest, there is no god but Allah (closing)',
    color: '#E8E4FF',
  ),
];

const List<QuizQ> salahQuiz = [
  QuizQ(
    id: 'saq1',
    emoji: '🌅',
    question: 'Fajr is the _____ prayer of the day.',
    options: ['Last', 'Third', 'First ✓', 'Second'],
    correct: 2,
    tip: 'Fajr is prayed at dawn — the very start of the day!',
  ),
  QuizQ(
    id: 'saq2',
    emoji: '🌙',
    question: 'How many rakah in Isha prayer?',
    options: ['2', '3', '5', '4 ✓'],
    correct: 3,
    tip: 'Isha has 4 rakah — the last prayer of the night.',
  ),
  QuizQ(
    id: 'saq3',
    emoji: '☀️',
    question: 'Which prayer is prayed at midday?',
    options: ['Fajr', 'Asr', 'Zuhr ✓', 'Maghrib'],
    correct: 2,
    tip: 'Zuhr = midday prayer when the sun is at its highest!',
  ),
  QuizQ(
    id: 'saq4',
    emoji: '🌇',
    question: 'Maghrib has how many rakah?',
    options: ['4', '2', '5', '3 ✓'],
    correct: 3,
    tip: 'Maghrib = 3 rakah, prayed right after sunset.',
  ),
  QuizQ(
    id: 'saq5',
    emoji: '⏰',
    question: 'Muslims pray ___ times every day.',
    options: ['3', '6', '5 ✓', '7'],
    correct: 2,
    tip: '5 prayers every day: Fajr, Zuhr, Asr, Maghrib, Isha!',
  ),
  QuizQ(
    id: 'saq6',
    emoji: '📢',
    question: 'What is the Adhan?',
    options: [
      'A prayer itself',
      'The call to prayer ✓',
      'A type of wudu',
      'A du\'a',
    ],
    correct: 1,
    tip:
        'The Adhan is the call to prayer — it calls all Muslims to come and pray!',
  ),
];

const List<FlashCard> fatihaCards = [
  FlashCard(
    id: 'ft1',
    emoji: '📖',
    arabic: 'بِسْمِ اللّٰهِ الرَّحْمٰنِ الرَّحِيم',
    translit: 'Bismillahi ar-Rahmani ar-Raheem',
    english: 'In the name of Allah, the Most Gracious, the Most Merciful',
    color: '#FDECC8',
  ),
  FlashCard(
    id: 'ft2',
    emoji: '🌟',
    arabic: 'الْحَمْدُ لِلّٰهِ رَبِّ الْعَالَمِين',
    translit: 'Al-hamdu lillahi rabb il-\'alamin',
    english: 'All praise is due to Allah, the Lord of all worlds',
    color: '#DCF0E6',
  ),
  FlashCard(
    id: 'ft3',
    emoji: '💚',
    arabic: 'الرَّحْمٰنِ الرَّحِيم',
    translit: 'Ar-Rahmani ar-Raheem',
    english: 'The Most Gracious, the Most Merciful',
    color: '#FDDCCC',
  ),
  FlashCard(
    id: 'ft4',
    emoji: '👑',
    arabic: 'مَالِكِ يَوْمِ الدِّين',
    translit: 'Maliki yawm id-deen',
    english: 'Master of the Day of Judgement',
    color: '#E8E4FF',
  ),
  FlashCard(
    id: 'ft5',
    emoji: '🤲',
    arabic: 'إِيَّاكَ نَعْبُدُ وَإِيَّاكَ نَسْتَعِين',
    translit: 'Iyyaka na\'budu wa iyyaka nasta\'een',
    english: 'You alone we worship, You alone we ask for help',
    color: '#E8F4FF',
  ),
  FlashCard(
    id: 'ft6',
    emoji: '🌈',
    arabic: 'اهْدِنَا الصِّرَاطَ المُسْتَقِيم',
    translit: 'Ihdinas siratal mustaqeem',
    english: 'Guide us on the straight path',
    color: '#FDECC8',
  ),
  FlashCard(
    id: 'ft7',
    emoji: '⭐',
    arabic:
        'صِرَاطَ الَّذِينَ أَنْعَمْتَ عَلَيْهِم غَيْرِ المَغْضُوبِ عَلَيْهِمْ وَلَا الضَّالِّين',
    translit:
        'Siratal ladhina an\'amta \'alayhim, ghayril maghdhubi \'alayhim wa lad-dallin',
    english:
        'The path of those You blessed -- not those who earned anger or went astray',
    color: '#DCF0E6',
  ),
];

// ─────────────────────────────────────────────────────────────
// DESTINATION 6 -- Mountain of Iman
// ─────────────────────────────────────────────────────────────

const List<FlashCard> allahCards = [
  FlashCard(
    id: 'al1',
    emoji: '🌍',
    arabic: 'اللّٰهُ الخَالِق',
    translit: 'Allahu al-Khaliq',
    english: 'Allah is the Creator -- He made everything we see!',
    color: '#FDECC8',
  ),
  FlashCard(
    id: 'al2',
    emoji: '☝️',
    arabic: 'اللّٰهُ الأَحَد',
    translit: 'Allahu al-Ahad',
    english: 'Allah is One -- no partners, no equal, only He!',
    color: '#DCF0E6',
  ),
  FlashCard(
    id: 'al3',
    emoji: '👑',
    arabic: 'مَالِكُ المُلْك',
    translit: 'Malikul Mulk',
    english: 'Owner of All -- the entire universe belongs to Allah!',
    color: '#E8E4FF',
  ),
  FlashCard(
    id: 'al4',
    emoji: '🍽️',
    arabic: 'الرَّزَّاق',
    translit: 'Ar-Razzaq',
    english: 'The Provider -- Allah provides food and everything we need',
    color: '#FDECC8',
  ),
  FlashCard(
    id: 'al5',
    emoji: '🔍',
    arabic: 'العَلِيم',
    translit: 'Al-\'Alim',
    english: 'The All-Knowing -- Allah knows everything, even our thoughts!',
    color: '#E8F4FF',
  ),
  FlashCard(
    id: 'al6',
    emoji: '❤️',
    arabic: 'الوَدُود',
    translit: 'Al-Wadud',
    english: 'The Loving One -- Allah loves us more than anyone!',
    color: '#FDDCCC',
  ),
  FlashCard(
    id: 'al7',
    emoji: '🌟',
    arabic: 'الحَمِيد',
    translit: 'Al-Hamid',
    english: 'The Praised One -- Allah is always worthy of our praise',
    color: '#DCF0E6',
  ),
  FlashCard(
    id: 'al8',
    emoji: '🌱',
    arabic: 'المُحْيِي',
    translit: 'Al-Muhyi',
    english: 'The Giver of Life -- Allah gave us life and breath!',
    color: '#FDECC8',
  ),
];

const List<StoryPanel> storyCreation = [
  StoryPanel(
    id: 'cr1',
    bg: 'linear-gradient(160deg, #1a2744 0%, #0F6E56 100%)',
    scene: [
      StorySceneItem(emoji: '🌌', x: 43, y: 12, size: 90),
      StorySceneItem(emoji: '⭐', x: 22, y: 35, size: 35),
      StorySceneItem(emoji: '🌟', x: 65, y: 28, size: 42),
      StorySceneItem(emoji: '✨', x: 43, y: 50, size: 30),
      StorySceneItem(emoji: '✨', x: 78, y: 52, size: 22),
    ],
    caption:
        'Before anything existed, there was only Allah. He said \'Kun!\' (Be!) -- and everything began!',
    captionAr:
        'قبل أن يوجد أيّ شيء، كان اللّٰه وحده. قال: \'كُنْ!\' فكان كلّ شيء!',
  ),
  StoryPanel(
    id: 'cr2',
    bg: 'linear-gradient(160deg, #2A7FCC 0%, #DCF0E6 100%)',
    scene: [
      StorySceneItem(emoji: '🌊', x: 43, y: 60, size: 90),
      StorySceneItem(emoji: '🌍', x: 43, y: 28, size: 75),
      StorySceneItem(emoji: '💧', x: 22, y: 48, size: 30),
      StorySceneItem(emoji: '💧', x: 68, y: 45, size: 28),
    ],
    caption:
        'Allah created the earth -- the mountains, oceans, rivers and valleys. All so perfect! سُبْحَانَ اللّٰه!',
    captionAr:
        'خلق اللّٰه الأرض — الجبال والمحيطات والأنهار والوديان. كلّها مثاليّة! سُبْحَانَ اللّٰه!',
  ),
  StoryPanel(
    id: 'cr3',
    bg: 'linear-gradient(160deg, #5B9A1E 0%, #FDECC8 100%)',
    scene: [
      StorySceneItem(emoji: '☀️', x: 65, y: 12, size: 60),
      StorySceneItem(emoji: '🌳', x: 18, y: 55, size: 70),
      StorySceneItem(emoji: '🌺', x: 55, y: 62, size: 45),
      StorySceneItem(emoji: '🦋', x: 38, y: 38, size: 35),
      StorySceneItem(emoji: '🐦', x: 62, y: 42, size: 30),
    ],
    caption:
        'He created the trees, flowers, butterflies, birds -- every living thing is His creation! الحَمْدُ لِلّٰه!',
    captionAr:
        'خلق الأشجار والزهور والفراشات والطيور — كلّ كائن حيّ من خلقه! الحَمْدُ لِلّٰه!',
  ),
  StoryPanel(
    id: 'cr4',
    bg: 'linear-gradient(160deg, #EF9F27 0%, #D85A30 100%)',
    scene: [
      StorySceneItem(emoji: '👦🏽', x: 30, y: 45, size: 72),
      StorySceneItem(emoji: '👧🏽', x: 63, y: 48, size: 68),
      StorySceneItem(emoji: '❤️', x: 43, y: 20, size: 55),
      StorySceneItem(emoji: '🌟', x: 18, y: 38, size: 30),
      StorySceneItem(emoji: '🌟', x: 70, y: 35, size: 28),
    ],
    caption:
        'And Allah created YOU -- His most special creation, given a mind and a heart to know Him! 💚',
    captionAr:
        'وخلق اللّٰه أنتَ — أكثر مخلوقاته تميّزاً، وهبك عقلاً وقلباً لتعرفه! 💚',
  ),
  StoryPanel(
    id: 'cr5',
    bg: 'linear-gradient(160deg, #0F6E56 0%, #2A7FCC 100%)',
    scene: [
      StorySceneItem(emoji: '🤲', x: 43, y: 25, size: 80),
      StorySceneItem(emoji: '💫', x: 20, y: 50, size: 38),
      StorySceneItem(emoji: '💫', x: 68, y: 45, size: 35),
    ],
    caption:
        'Whenever you see something beautiful -- say سُبْحَانَ اللّٰه! Whenever you are grateful -- say الحَمْدُ لِلّٰه!',
    captionAr:
        'كلّما رأيت شيئاً جميلاً — قُل سُبْحَانَ اللّٰه! وكلّما شعرت بالامتنان — قُل الحَمْدُ لِلّٰه!',
  ),
];

const List<QuizQ> aqidahQuiz = [
  QuizQ(
    id: 'aq1',
    emoji: '☝️',
    question: 'How many gods do Muslims believe in?',
    options: ['Three', 'Many', 'Two', 'One — Allah ✓'],
    correct: 3,
    tip: 'Muslims believe in ONE God — Allah alone, with no partners!',
  ),
  QuizQ(
    id: 'aq2',
    emoji: '🌍',
    question: 'Who created everything in the universe?',
    options: [
      'Nature created itself',
      'People built it all',
      'Allah created everything ✓',
      'The stars made it',
    ],
    correct: 2,
    tip: 'Allah is Al-Khaliq — the Creator of everything that exists!',
  ),
  QuizQ(
    id: 'aq3',
    emoji: '❤️',
    question: 'The name \'Al-Wadud\' means...',
    options: [
      'The All-Knowing',
      'The Provider',
      'The Loving One ✓',
      'The Creator',
    ],
    correct: 2,
    tip: 'Al-Wadud = The Loving One — Allah\'s love for us is endless!',
  ),
  QuizQ(
    id: 'aq4',
    emoji: '🍽️',
    question: '\'Ar-Razzaq\' means Allah is...',
    options: [
      'The Creator',
      'The Provider of all things ✓',
      'The All-Seeing',
      'The Most Merciful',
    ],
    correct: 1,
    tip:
        'Ar-Razzaq = The Provider — everything we eat, drink and have comes from Allah!',
  ),
];

const List<FlashCard> pillarsCards = [
  FlashCard(
    id: 'p1',
    emoji: '☝️',
    arabic: 'الشَّهَادَة\n"لَا إِلٰهَ إِلَّا اللّٰهُ مُحَمَّدٌ رَسُولُ اللّٰه"',
    translit: 'Ash-Shahadah',
    english:
        '1st Pillar: Declaration of Faith -- There is no god but Allah, Muhammad ﷺ is His messenger',
    color: '#FDECC8',
  ),
  FlashCard(
    id: 'p2',
    emoji: '🕌',
    arabic: 'الصَّلَاة\n٥ مَرَّات يَوْمِيًّا',
    translit: 'As-Salah',
    english: '2nd Pillar: Prayer -- 5 times every single day',
    color: '#DCF0E6',
  ),
  FlashCard(
    id: 'p3',
    emoji: '💛',
    arabic: 'الزَّكَاة\nمُسَاعَدَة الفُقَرَاء',
    translit: 'Az-Zakah',
    english: '3rd Pillar: Charity -- Sharing wealth with those in need',
    color: '#FDECC8',
  ),
  FlashCard(
    id: 'p4',
    emoji: '🌙',
    arabic: 'الصَّوْم\nشَهْر رَمَضَان',
    translit: 'As-Sawm',
    english: '4th Pillar: Fasting -- During the blessed month of Ramadan',
    color: '#E8E4FF',
  ),
  FlashCard(
    id: 'p5',
    emoji: '🕋',
    arabic: 'الحَجّ\nمَكَّة المُكَرَّمَة',
    translit: 'Al-Hajj',
    english:
        '5th Pillar: Pilgrimage -- Journey to Makkah once in a lifetime (if able)',
    color: '#FDDCCC',
  ),
];

const List<FlashCard> imanCards = [
  FlashCard(
    id: 'im1',
    emoji: '💫',
    arabic: 'الإِيمَان بِاللّٰه',
    translit: 'Al-iman billah',
    english: '1. Belief in Allah -- One God, no partners',
    color: '#FDECC8',
  ),
  FlashCard(
    id: 'im2',
    emoji: '👼',
    arabic: 'الإِيمَان بِالمَلَائِكَة',
    translit: 'Al-iman bil-mala\'ika',
    english: '2. Belief in Angels -- Allah\'s messengers of light',
    color: '#E8E4FF',
  ),
  FlashCard(
    id: 'im3',
    emoji: '📚',
    arabic: 'الإِيمَان بِالكُتُب',
    translit: 'Al-iman bil-kutub',
    english: '3. Belief in the Holy Books -- Quran, Torah, Injeel, Zabur',
    color: '#DCF0E6',
  ),
  FlashCard(
    id: 'im4',
    emoji: '🌟',
    arabic: 'الإِيمَان بِالرُّسُل',
    translit: 'Al-iman bir-rusul',
    english: '4. Belief in the Prophets -- from Adam to Muhammad ﷺ',
    color: '#FDECC8',
  ),
  FlashCard(
    id: 'im5',
    emoji: '⚖️',
    arabic: 'الإِيمَان بِاليَوْمِ الآخِر',
    translit: 'Al-iman bil-yawm il-akhir',
    english: '5. Belief in the Last Day -- the Day of Judgement',
    color: '#FDDCCC',
  ),
  FlashCard(
    id: 'im6',
    emoji: '🌱',
    arabic: 'الإِيمَان بِالقَدَر',
    translit: 'Al-iman bil-qadar',
    english: '6. Belief in Divine Decree -- Allah\'s perfect plan',
    color: '#DCF0E6',
  ),
];

const List<QuizQ> valuesQuiz = [
  QuizQ(
    id: 'vq1',
    emoji: '☝️',
    question: 'How many Pillars of Islam are there?',
    options: ['3', '6', '7', '5 ✓'],
    correct: 3,
    tip: '5 Pillars: Shahadah, Salah, Zakah, Sawm, Hajj!',
  ),
  QuizQ(
    id: 'vq2',
    emoji: '💛',
    question: 'Zakah means...',
    options: [
      'Prayer',
      'Fasting',
      'Giving charity to those in need ✓',
      'Pilgrimage',
    ],
    correct: 2,
    tip: 'Zakah is giving part of your wealth to help those in need!',
  ),
  QuizQ(
    id: 'vq3',
    emoji: '📚',
    question: 'How many Articles of Faith (Arkan Al-Iman) are there?',
    options: ['5', '4', '7', '6 ✓'],
    correct: 3,
    tip: '6 Articles: Allah, Angels, Books, Prophets, Last Day, Divine Decree!',
  ),
  QuizQ(
    id: 'vq4',
    emoji: '🌙',
    question: 'Which month do Muslims fast in?',
    options: ['Shawwal', 'Sha\'ban', 'Rajab', 'Ramadan ✓'],
    correct: 3,
    tip: 'We fast during the blessed month of Ramadan!',
  ),
  QuizQ(
    id: 'vq5',
    emoji: '😊',
    question: 'The Prophet ﷺ said: Your smile in your friend\'s face is...',
    options: ['Rude', 'Charity (Sadaqah) ✓', 'Bragging', 'Wasting time'],
    correct: 1,
    tip:
        '\'Tabassmuka fi wajhi akhika sadaqah\' — smiling is rewarded by Allah!',
  ),
];

// ─────────────────────────────────────────────────────────────
// DESTINATION 7 -- Quran Corner
// ─────────────────────────────────────────────────────────────

const List<FlashCard> quranIntroCards = [
  FlashCard(
    id: 'qi1',
    emoji: '📖',
    arabic: 'القُرْآن الكَرِيم',
    translit: 'Al-Quran al-Karim',
    english:
        'The Noble Quran -- the word of Allah revealed to Prophet Muhammad ﷺ',
    color: '#FDECC8',
  ),
  FlashCard(
    id: 'qi2',
    emoji: '🌟',
    arabic: 'أَعُوذُ بِاللّٰهِ مِنَ الشَّيْطَانِ الرَّجِيم',
    translit: 'A\'udhu billahi minash-shaytanir-rajim',
    english:
        'Istiádhah -- I seek refuge in Allah from the cursed Shaytan (say before reciting)',
    color: '#E8E4FF',
  ),
  FlashCard(
    id: 'qi3',
    emoji: '✨',
    arabic: 'بِسْمِ اللّٰهِ الرَّحْمٰنِ الرَّحِيم',
    translit: 'Bismillahi ar-Rahmani ar-Raheem',
    english:
        'Basmalah -- In the name of Allah, the Most Gracious, the Most Merciful',
    color: '#DCF0E6',
  ),
  FlashCard(
    id: 'qi4',
    emoji: '🤲',
    arabic: 'آدَابُ تِلَاوَة القُرْآن',
    translit: 'Adabut-tilawa',
    english: 'Etiquette: Be clean, face qibla, say Istiádhah then Basmalah',
    color: '#FDDCCC',
  ),
];

const List<FlashCard> suwarCards = [
  FlashCard(
    id: 'sw1',
    emoji: '🙏',
    arabic: 'سُورَة الفَاتِحَة\n(٧ آيَات)',
    translit: 'Surah al-Fatiha',
    english: 'The Opening -- recited in every rakah of prayer. 7 verses',
    color: '#FDECC8',
  ),
  FlashCard(
    id: 'sw2',
    emoji: '👥',
    arabic: 'سُورَة النَّاس\n(٦ آيَات)',
    translit: 'Surah an-Nas',
    english: 'Mankind -- Seek refuge in Allah from whispering evil',
    color: '#E8E4FF',
  ),
  FlashCard(
    id: 'sw3',
    emoji: '🌅',
    arabic: 'سُورَة الفَلَق\n(٥ آيَات)',
    translit: 'Surah al-Falaq',
    english: 'Daybreak -- Seek refuge in Allah from all harm and darkness',
    color: '#FDECC8',
  ),
  FlashCard(
    id: 'sw4',
    emoji: '☝️',
    arabic: 'سُورَة الإِخْلَاص\n(٤ آيَات)',
    translit: 'Surah al-Ikhlas',
    english:
        'Sincerity -- Qul huwallahu ahad: Allah is One! Equal to 1/3 of Quran',
    color: '#DCF0E6',
  ),
  FlashCard(
    id: 'sw5',
    emoji: '🔥',
    arabic: 'سُورَة المَسَد\n(٥ آيَات)',
    translit: 'Surah al-Masad',
    english: 'The Palm Fiber -- about those who oppose truth',
    color: '#FDDCCC',
  ),
  FlashCard(
    id: 'sw6',
    emoji: '🏆',
    arabic: 'سُورَة النَّصْر\n(٣ آيَات)',
    translit: 'Surah an-Nasr',
    english:
        'Victory -- when Allah\'s help arrives, praise Him and ask forgiveness',
    color: '#DCF0E6',
  ),
  FlashCard(
    id: 'sw7',
    emoji: '🌊',
    arabic: 'سُورَة الكَافِرُون\n(٦ آيَات)',
    translit: 'Surah al-Kafirun',
    english:
        'The Disbelievers -- Lakum dinukum wa liy ad-din: You have your religion, I have mine',
    color: '#E8F4FF',
  ),
  FlashCard(
    id: 'sw8',
    emoji: '🌸',
    arabic: 'سُورَة الكَوْثَر\n(٣ آيَات)',
    translit: 'Surah al-Kawthar',
    english:
        'Al-Kawthar -- the shortest surah! Allah gave Prophet ﷺ \'Al-Kawthar\' (abundance)',
    color: '#FDECC8',
  ),
];

const List<QuizQ> suwarQuiz = [
  QuizQ(
    id: 'swq1',
    emoji: '☝️',
    question: 'Surah al-Ikhlas says \'Qul huwallahu ahad\' which means...',
    options: [
      'Allah is Most Merciful',
      'Say: Allah is One ✓',
      'Praise be to Allah',
      'Allah is the Greatest',
    ],
    correct: 1,
    tip:
        '\'Qul huwallahu ahad\' — SAY: He is Allah, ONE. This surah is worth 1/3 of the whole Quran!',
  ),
  QuizQ(
    id: 'swq2',
    emoji: '🌸',
    question: 'Which is the SHORTEST surah in the Quran?',
    options: ['Al-Fatiha', 'An-Nas', 'Al-Ikhlas', 'Al-Kawthar ✓'],
    correct: 3,
    tip:
        'Surah Al-Kawthar has only 3 verses — but it carries so much blessing!',
  ),
  QuizQ(
    id: 'swq3',
    emoji: '🙏',
    question: 'Which surah do we recite in EVERY rakah of prayer?',
    options: ['An-Nas', 'Al-Kawthar', 'Al-Fatiha ✓', 'Al-Ikhlas'],
    correct: 2,
    tip: 'Surah Al-Fatiha — The Opening — is recited in every single rakah!',
  ),
  QuizQ(
    id: 'swq4',
    emoji: '🌅',
    question: 'Surah al-Falaq teaches us to seek refuge from...',
    options: [
      'Being hungry',
      'Harm and darkness ✓',
      'Loud sounds',
      'Getting lost',
    ],
    correct: 1,
    tip:
        'Al-Falaq = Daybreak — we ask Allah to protect us from all evil and harm!',
  ),
  QuizQ(
    id: 'swq5',
    emoji: '📖',
    question: 'What do you say BEFORE starting to recite the Quran?',
    options: [
      'Bismillah only',
      'Alhamdulillah',
      'Istiádhah then Basmalah ✓',
      'Subhanallah',
    ],
    correct: 2,
    tip:
        'First say A\'udhu billah (Istiádhah) then Bismillah (Basmalah) before reciting!',
  ),
  QuizQ(
    id: 'swq6',
    emoji: '🏆',
    question: 'Surah an-Nasr is about...',
    options: [
      'Fasting in Ramadan',
      'Prayer times',
      'Allah\'s victory and asking forgiveness ✓',
      'Kindness to parents',
    ],
    correct: 2,
    tip:
        'An-Nasr = Victory — when Allah\'s help comes, praise Him and seek His forgiveness!',
  ),
];

const List<StoryPanel> storyQuran = [
  StoryPanel(
    id: 'qr1',
    bg: 'linear-gradient(160deg, #0F6E56 0%, #1a2744 100%)',
    scene: [
      StorySceneItem(emoji: '📖', x: 43, y: 22, size: 80),
      StorySceneItem(emoji: '✨', x: 22, y: 48, size: 38),
      StorySceneItem(emoji: '✨', x: 68, y: 42, size: 35),
      StorySceneItem(emoji: '🌟', x: 43, y: 68, size: 32),
    ],
    caption:
        'The Holy Quran is the word of Allah -- revealed to Prophet Muhammad ﷺ through Angel Jibreel!',
    captionAr:
        'القرآن الكريم كلام اللّٰه — نزل على النبيّ محمّد ﷺ عن طريق الملاك جبريل!',
  ),
  StoryPanel(
    id: 'qr2',
    bg: 'linear-gradient(160deg, #2A7FCC 0%, #0F6E56 100%)',
    scene: [
      StorySceneItem(emoji: '👦🏽', x: 35, y: 48, size: 72),
      StorySceneItem(emoji: '📖', x: 58, y: 42, size: 55),
      StorySceneItem(emoji: '🌟', x: 22, y: 28, size: 35),
      StorySceneItem(emoji: '🌟', x: 70, y: 30, size: 30),
    ],
    bubble: StoryBubble(
      text: 'أَعُوذُ بِاللّٰهِ مِنَ الشَّيْطَانِ الرَّجِيم...',
      side: 'right',
    ),
    caption:
        'Before reading, little Umar always says Istiádhah -- seeking Allah\'s protection first!',
    captionAr:
        'قبل القراءة، دائماً يقول عمر الصغير الاستعاذة — طالباً حماية اللّٰه أوّلاً!',
  ),
  StoryPanel(
    id: 'qr3',
    bg: 'linear-gradient(160deg, #EF9F27 0%, #0F6E56 100%)',
    scene: [
      StorySceneItem(emoji: '🌈', x: 43, y: 12, size: 80),
      StorySceneItem(emoji: '📖', x: 38, y: 52, size: 55),
      StorySceneItem(emoji: '💚', x: 43, y: 72, size: 35),
    ],
    bubble: StoryBubble(
      text: 'الحَمْدُ لِلّٰهِ رَبِّ العَالَمِين ✨',
      side: 'center',
    ),
    caption:
        'Surah Al-Fatiha -- the Opening -- is the greatest surah! We recite it in every prayer. Can you memorize it?',
    captionAr:
        'سورة الفاتحة — الفاتحة — هي أعظم سورة! نتلوها في كلّ صلاة. هل يمكنك حفظها؟',
  ),
  StoryPanel(
    id: 'qr4',
    bg: 'linear-gradient(160deg, #FDECC8 0%, #E8E4FF 100%)',
    scene: [
      StorySceneItem(emoji: '☝️', x: 43, y: 22, size: 70),
      StorySceneItem(emoji: '👦🏽', x: 28, y: 55, size: 68),
      StorySceneItem(emoji: '👧🏽', x: 63, y: 58, size: 65),
      StorySceneItem(emoji: '⭐', x: 43, y: 70, size: 35),
    ],
    bubble: StoryBubble(text: 'قُلْ هُوَ اللّٰهُ أَحَد 💚', side: 'center'),
    caption:
        'Surah al-Ikhlas says: Say -- He is Allah, ONE! Reciting it THREE times equals the whole Quran in reward!',
    captionAr:
        'سورة الإخلاص تقول: قُل هو اللّٰه أحد! تلاوتها ثلاث مرّات تعادل ثواب ختم القرآن!',
  ),
  StoryPanel(
    id: 'qr5',
    bg: 'linear-gradient(160deg, #0F6E56 0%, #EF9F27 100%)',
    scene: [
      StorySceneItem(emoji: '🌟', x: 43, y: 12, size: 75),
      StorySceneItem(emoji: '📖', x: 43, y: 50, size: 70),
      StorySceneItem(emoji: '✨', x: 18, y: 42, size: 38),
      StorySceneItem(emoji: '✨', x: 70, y: 38, size: 35),
    ],
    caption:
        'The Prophet ﷺ said: The best of you is the one who learns the Quran and teaches it! 🌟',
    captionAr:
        'قال النبيّ ﷺ: خَيْرُكُمْ مَنْ تَعَلَّمَ القُرْآنَ وَعَلَّمَهُ! 🌟',
  ),
];

const List<QuizQ> masteryQuiz = [
  QuizQ(
    id: 'mq1',
    emoji: '🤲',
    question: 'What do you say when meeting a Muslim?',
    options: [
      'Ahlan 🏠',
      'بِسْمِ اللّٰهِ',
      'اَلسَّلَامُ عَلَيْكُمْ ✓',
      'Shukran',
    ],
    correct: 2,
  ),
  QuizQ(
    id: 'mq2',
    emoji: 'ب',
    question: 'Ba\' (ب) has how many dots?',
    options: ['Two above', 'Three above', 'One below ✓', 'None'],
    correct: 2,
  ),
  QuizQ(
    id: 'mq3',
    emoji: '🟡',
    question: 'أَصْفَر means...',
    options: ['Green', 'Blue', 'Red', 'Yellow ✓'],
    correct: 3,
  ),
  QuizQ(
    id: 'mq4',
    emoji: '🦁',
    question: 'أَسَد means...',
    options: ['Elephant', 'Cat', 'Lion ✓', 'Camel'],
    correct: 2,
  ),
  QuizQ(
    id: 'mq5',
    emoji: '🕌',
    question: 'How many times do Muslims pray each day?',
    options: ['3', '7', '4', '5 ✓'],
    correct: 3,
  ),
  QuizQ(
    id: 'mq6',
    emoji: '☝️',
    question: 'The 1st Pillar of Islam is...',
    options: ['Salah', 'Hajj', 'Sawm', 'Shahadah ✓'],
    correct: 3,
  ),
  QuizQ(
    id: 'mq7',
    emoji: '💧',
    question: 'We make Wudu before...',
    options: ['Eating', 'Sleeping', 'Prayer ✓', 'Reading'],
    correct: 2,
  ),
  QuizQ(
    id: 'mq8',
    emoji: '📖',
    question: 'الحَمْدُ لِلّٰهِ means...',
    options: [
      'Bismillah',
      'Praise be to Allah ✓',
      'Allahu Akbar',
      'In sha Allah',
    ],
    correct: 1,
  ),
  QuizQ(
    id: 'mq9',
    emoji: '🌟',
    question: 'Prophet Muhammad ﷺ was born in...',
    options: ['Madinah', 'Jerusalem', 'Makkah ✓', 'Baghdad'],
    correct: 2,
  ),
  QuizQ(
    id: 'mq10',
    emoji: '☝️',
    question: 'Surah al-Ikhlas says Allah is...',
    options: ['All-Seeing', 'All-Knowing', 'ONE (Ahad) ✓', 'Most Merciful'],
    correct: 2,
  ),
];

// ─────────────────────────────────────────────────────────────
// SESSION-BASED CONTENT (Journey Map redesign) -- Magic Sand Tracer's 4
// letter-range sessions, copied from the lettersGroup1-5 pools above so each
// session's title ("Alif to Kha" etc.) matches its cards exactly; the
// original 5 groups don't split on those exact boundaries.
// ─────────────────────────────────────────────────────────────

const List<FlashCard> sandTracer1 = [
  FlashCard(
    id: 'st1',
    emoji: '🍎',
    arabic: 'أَلِف\nا',
    translit: 'Alif',
    english: 'Like "a" in apple — اِسْم (name)',
    color: '#FDECC8',
  ),
  FlashCard(
    id: 'st2',
    emoji: '🏠',
    arabic: 'بَاء\nب',
    translit: 'Ba',
    english: 'Like "b" in ball — بَيْت (house)',
    color: '#FDDCCC',
  ),
  FlashCard(
    id: 'st3',
    emoji: '🍎',
    arabic: 'تَاء\nت',
    translit: 'Ta',
    english: 'Like "t" in tiger — تُفَّاحَة (apple)',
    color: '#DCF0E6',
  ),
  FlashCard(
    id: 'st4',
    emoji: '🦊',
    arabic: 'ثَاء\nث',
    translit: 'Tha',
    english: 'Soft "th" like in think — ثَعْلَب (fox)',
    color: '#E8E4FF',
  ),
  FlashCard(
    id: 'st5',
    emoji: '🐪',
    arabic: 'جِيم\nج',
    translit: 'Jim',
    english: 'Like "j" in jar — جَمَل (camel)',
    color: '#FDECC8',
  ),
  FlashCard(
    id: 'st6',
    emoji: '🐴',
    arabic: 'حَاء\nح',
    translit: 'Ha',
    english: 'Soft "h" from deep throat — حِصَان (horse)',
    color: '#E8F4FF',
  ),
  FlashCard(
    id: 'st7',
    emoji: '🗺️',
    arabic: 'خَاء\nخ',
    translit: 'Kha',
    english: 'Like "ch" in Bach (rough) — خَرِيطَة (map)',
    color: '#FDECC8',
  ),
];

const List<FlashCard> sandTracer2 = [
  FlashCard(
    id: 'st8',
    emoji: '🐻',
    arabic: 'دَال\nد',
    translit: 'Dal',
    english: 'Like "d" in duck — دُبّ (bear)',
    color: '#FDDCCC',
  ),
  FlashCard(
    id: 'st9',
    emoji: '🌽',
    arabic: 'ذَال\nذ',
    translit: 'Dhal',
    english: 'Like "th" in THAT — ذُرَة (corn)',
    color: '#DCF0E6',
  ),
  FlashCard(
    id: 'st10',
    emoji: '⚡',
    arabic: 'رَاء\nر',
    translit: 'Ra',
    english: 'Rolling "r" — رَعْد (thunder)',
    color: '#FDECC8',
  ),
  FlashCard(
    id: 'st11',
    emoji: '🌺',
    arabic: 'زَاي\nز',
    translit: 'Zayn',
    english: 'Like "z" in zoo — زَهْرَة (flower)',
    color: '#E8E4FF',
  ),
  FlashCard(
    id: 'st12',
    emoji: '🐟',
    arabic: 'سِين\nس',
    translit: 'Sin',
    english: 'Like "s" in sea — سَمَكَة (fish)',
    color: '#E8F4FF',
  ),
  FlashCard(
    id: 'st13',
    emoji: '🌲',
    arabic: 'شِين\nش',
    translit: 'Shin',
    english: 'Like "sh" in ship — شَجَرَة (tree)',
    color: '#DCF0E6',
  ),
  FlashCard(
    id: 'st14',
    emoji: '🐦',
    arabic: 'صَاد\nص',
    translit: 'Sad',
    english: 'Emphatic "s" — صَقْر (falcon)',
    color: '#FDECC8',
  ),
  FlashCard(
    id: 'st15',
    emoji: '🐸',
    arabic: 'ضَاد\nض',
    translit: 'Dad',
    english: 'Emphatic "d" — ضِفْدَع (frog)',
    color: '#FDDCCC',
  ),
];

const List<FlashCard> sandTracer3 = [
  FlashCard(
    id: 'st16',
    emoji: '🍅',
    arabic: 'طَاء\nط',
    translit: 'Ta',
    english: 'Emphatic "t" — طَمَاطِم (tomato)',
    color: '#FDDCCC',
  ),
  FlashCard(
    id: 'st17',
    emoji: '🌿',
    arabic: 'ظَاء\nظ',
    translit: 'Dha',
    english: 'Emphatic "dh" — ظِل (shade/shadow)',
    color: '#DCF0E6',
  ),
  FlashCard(
    id: 'st18',
    emoji: '🦅',
    arabic: 'عَيْن\nع',
    translit: "'Ayn",
    english: "Deep 'a' from the throat — عُقَاب (eagle)",
    color: '#E8E4FF',
  ),
  FlashCard(
    id: 'st19',
    emoji: '🌫️',
    arabic: 'غَيْن\nغ',
    translit: 'Ghayn',
    english: 'Like "gh" gargling — غَيْم (cloud)',
    color: '#E8E4FF',
  ),
  FlashCard(
    id: 'st20',
    emoji: '🦋',
    arabic: 'فَاء\nف',
    translit: 'Fa',
    english: 'Like "f" in fly — فَرَاشَة (butterfly)',
    color: '#FDECC8',
  ),
  FlashCard(
    id: 'st21',
    emoji: '🐱',
    arabic: 'قَاف\nق',
    translit: 'Qaf',
    english: 'Deep "q" from the throat — قِطَّة (cat)',
    color: '#FDDCCC',
  ),
];

const List<FlashCard> sandTracer4 = [
  FlashCard(
    id: 'st22',
    emoji: '📖',
    arabic: 'كَاف\nك',
    translit: 'Kaf',
    english: 'Like "k" in key — كِتَاب (book)',
    color: '#DCF0E6',
  ),
  FlashCard(
    id: 'st23',
    emoji: '🦁',
    arabic: 'لَام\nل',
    translit: 'Lam',
    english: 'Like "l" in lion — أَسَد/لَيْث (lion)',
    color: '#FDECC8',
  ),
  FlashCard(
    id: 'st24',
    emoji: '🕌',
    arabic: 'مِيم\nم',
    translit: 'Mim',
    english: 'Like "m" in moon — مَسْجِد (mosque)',
    color: '#E8F4FF',
  ),
  FlashCard(
    id: 'st25',
    emoji: '⭐',
    arabic: 'نُون\nن',
    translit: 'Nun',
    english: 'Like "n" in night — نَجْم (star)',
    color: '#FDECC8',
  ),
  FlashCard(
    id: 'st26',
    emoji: '🌬️',
    arabic: 'هَاء\nه',
    translit: 'Ha',
    english: 'Like "h" in hello — هَوَاء (air)',
    color: '#FDDCCC',
  ),
  FlashCard(
    id: 'st27',
    emoji: '🌹',
    arabic: 'وَاو\nو',
    translit: 'Waw',
    english: 'Like "w" in wonder — وَرْد (rose)',
    color: '#DCF0E6',
  ),
  FlashCard(
    id: 'st28',
    emoji: '🤲',
    arabic: 'يَاء\nي',
    translit: 'Ya',
    english: 'Like "y" in yes — يَد (hand)',
    color: '#E8E4FF',
  ),
];

// ─────────────────────────────────────────────────────────────
// ALLAH'S CREATION HUNT -- the three hunt scenes
//
// Ported 1:1 from the supplied "Allah's Creation Hunt" prototype's own
// `STAGES` table: same artwork, same hitboxes (centre x/y + w/h as a
// fraction of the 393x852 frame the scenes were drawn against), same
// creations and same people-made decoys.
//
// One stage per session, distributed across the journey: Session 1
// (Destination 1) hunts the Forest, Session 2 (Destination 2) the Sky,
// Session 3 (Destination 3) the Garden. Every session opens on the same
// title and how-to screens -- only the scene changes.
// ─────────────────────────────────────────────────────────────

const CreationHuntStage forestHuntStage = CreationHuntStage(
  name: 'The Forest',
  icon: '🌳',
  background: 'assets/images/creation_hunt/forest_detective.png',
  instruction: 'Find the things Allah created!',
  spots: [
    CreationHuntSpot(
      id: 'tree',
      isCreation: true,
      x: 0.215,
      y: 0.090,
      w: 0.43,
      h: 0.185,
      radius: CreationHuntRadius.blob,
      icon: '🌳',
    ),
    CreationHuntSpot(
      id: 'tree_pine_1',
      group: 'tree',
      alias: true,
      isCreation: true,
      x: 0.154,
      y: 0.259,
      w: 0.115,
      h: 0.140,
      radius: CreationHuntRadius.domed,
      icon: '🌲',
      label: 'tree',
    ),
    CreationHuntSpot(
      id: 'tree_pine_2',
      group: 'tree',
      alias: true,
      isCreation: true,
      x: 0.240,
      y: 0.272,
      w: 0.090,
      h: 0.082,
      radius: CreationHuntRadius.domed,
      icon: '🌲',
      label: 'tree',
    ),
    CreationHuntSpot(
      id: 'tree_pine_3',
      group: 'tree',
      alias: true,
      isCreation: true,
      x: 0.297,
      y: 0.304,
      w: 0.098,
      h: 0.112,
      radius: CreationHuntRadius.domed,
      icon: '🌲',
      label: 'tree',
    ),
    CreationHuntSpot(
      id: 'tree_pine_mid',
      group: 'tree',
      alias: true,
      isCreation: true,
      x: 0.715,
      y: 0.354,
      w: 0.155,
      h: 0.152,
      radius: CreationHuntRadius.domed,
      icon: '🌲',
      label: 'tree',
    ),
    CreationHuntSpot(
      id: 'tree_pine_far',
      group: 'tree',
      alias: true,
      isCreation: true,
      x: 0.930,
      y: 0.245,
      w: 0.150,
      h: 0.185,
      radius: CreationHuntRadius.domed,
      icon: '🌲',
      label: 'tree',
    ),
    CreationHuntSpot(
      id: 'bird',
      isCreation: true,
      x: 0.494,
      y: 0.149,
      w: 0.135,
      h: 0.058,
      radius: CreationHuntRadius.circle,
      icon: '🐦',
    ),
    CreationHuntSpot(
      id: 'mountain',
      isCreation: true,
      x: 0.832,
      y: 0.185,
      w: 0.27,
      h: 0.165,
      radius: CreationHuntRadius.domed,
      icon: '⛰️',
    ),
    CreationHuntSpot(
      id: 'apple',
      isCreation: true,
      x: 0.135,
      y: 0.374,
      w: 0.23,
      h: 0.122,
      radius: CreationHuntRadius.circle,
      icon: '🍎',
    ),
    CreationHuntSpot(
      id: 'monkey',
      isCreation: true,
      x: 0.861,
      y: 0.424,
      w: 0.175,
      h: 0.100,
      radius: CreationHuntRadius.circle,
      icon: '🐒',
    ),
    CreationHuntSpot(
      id: 'river',
      isCreation: true,
      x: 0.500,
      y: 0.560,
      w: 0.30,
      h: 0.20,
      radius: CreationHuntRadius.blob,
      icon: '💧',
    ),
    CreationHuntSpot(
      id: 'car',
      isCreation: false,
      x: 0.176,
      y: 0.724,
      w: 0.34,
      h: 0.110,
      radius: CreationHuntRadius.soft,
      icon: '🚗',
    ),
    CreationHuntSpot(
      id: 'tent',
      isCreation: false,
      x: 0.830,
      y: 0.788,
      w: 0.30,
      h: 0.123,
      radius: CreationHuntRadius.domed,
      icon: '⛺',
    ),
    CreationHuntSpot(
      id: 'bicycle',
      isCreation: false,
      x: 0.324,
      y: 0.868,
      w: 0.28,
      h: 0.115,
      radius: CreationHuntRadius.soft,
      icon: '🚲',
    ),
    CreationHuntSpot(
      id: 'ball',
      isCreation: false,
      x: 0.635,
      y: 0.886,
      w: 0.14,
      h: 0.065,
      radius: CreationHuntRadius.circle,
      icon: '🏐',
    ),
  ],
);

const CreationHuntStage skyHuntStage = CreationHuntStage(
  name: 'The Sky',
  icon: '☀️',
  background: 'assets/images/creation_hunt/sky_landscape.png',
  instruction: 'Find the things Allah created in the sky!',
  hudAtBottom: true,
  spots: [
    CreationHuntSpot(
      id: 'stars',
      isCreation: true,
      x: 0.355,
      y: 0.099,
      w: 0.22,
      h: 0.120,
      radius: CreationHuntRadius.soft,
      icon: '⭐',
    ),
    CreationHuntSpot(
      id: 'moon',
      isCreation: true,
      x: 0.179,
      y: 0.087,
      w: 0.17,
      h: 0.085,
      radius: CreationHuntRadius.circle,
      icon: '🌙',
    ),
    CreationHuntSpot(
      id: 'sun',
      isCreation: true,
      x: 0.867,
      y: 0.109,
      w: 0.27,
      h: 0.126,
      radius: CreationHuntRadius.circle,
      icon: '☀️',
    ),
    CreationHuntSpot(
      id: 'clouds',
      isCreation: true,
      x: 0.143,
      y: 0.219,
      w: 0.315,
      h: 0.092,
      radius: CreationHuntRadius.circle,
      icon: '☁️',
    ),
    CreationHuntSpot(
      id: 'cloud2',
      group: 'clouds',
      alias: true,
      isCreation: true,
      label: 'clouds',
      x: 0.637,
      y: 0.157,
      w: 0.225,
      h: 0.048,
      radius: CreationHuntRadius.circle,
      icon: '☁️',
    ),
    CreationHuntSpot(
      id: 'cloud3',
      group: 'clouds',
      alias: true,
      isCreation: true,
      label: 'clouds',
      x: 0.600,
      y: 0.325,
      w: 0.180,
      h: 0.042,
      radius: CreationHuntRadius.circle,
      icon: '☁️',
    ),
    CreationHuntSpot(
      id: 'cloud4',
      group: 'clouds',
      alias: true,
      isCreation: true,
      label: 'clouds',
      x: 0.625,
      y: 0.545,
      w: 0.215,
      h: 0.052,
      radius: CreationHuntRadius.circle,
      icon: '☁️',
    ),
    CreationHuntSpot(
      id: 'cloud5',
      group: 'clouds',
      alias: true,
      isCreation: true,
      label: 'clouds',
      x: 0.285,
      y: 0.600,
      w: 0.380,
      h: 0.068,
      radius: CreationHuntRadius.circle,
      icon: '☁️',
    ),
    CreationHuntSpot(
      id: 'cloud6',
      group: 'clouds',
      alias: true,
      isCreation: true,
      label: 'clouds',
      x: 0.860,
      y: 0.632,
      w: 0.260,
      h: 0.090,
      radius: CreationHuntRadius.circle,
      icon: '☁️',
    ),
    CreationHuntSpot(
      id: 'helicopter',
      isCreation: false,
      x: 0.483,
      y: 0.239,
      w: 0.25,
      h: 0.087,
      radius: CreationHuntRadius.soft,
      icon: '🚁',
    ),
    CreationHuntSpot(
      id: 'eagle',
      isCreation: true,
      x: 0.814,
      y: 0.243,
      w: 0.37,
      h: 0.115,
      radius: CreationHuntRadius.circle,
      icon: '🦅',
    ),
    CreationHuntSpot(
      id: 'rain',
      isCreation: true,
      x: 0.219,
      y: 0.450,
      w: 0.40,
      h: 0.130,
      radius: CreationHuntRadius.soft,
      icon: '🌧️',
    ),
    CreationHuntSpot(
      id: 'airplane',
      isCreation: false,
      x: 0.617,
      y: 0.406,
      w: 0.285,
      h: 0.065,
      radius: CreationHuntRadius.blob,
      icon: '✈️',
    ),
    CreationHuntSpot(
      id: 'balloon',
      isCreation: false,
      x: 0.853,
      y: 0.505,
      w: 0.19,
      h: 0.130,
      radius: CreationHuntRadius.blob,
      icon: '🎈',
    ),
    CreationHuntSpot(
      id: 'kite',
      isCreation: false,
      x: 0.162,
      y: 0.517,
      w: 0.14,
      h: 0.068,
      radius: CreationHuntRadius.diamond,
      icon: '🪁',
    ),
  ],
);

const CreationHuntStage gardenHuntStage = CreationHuntStage(
  name: 'The Garden',
  icon: '🌸',
  background: 'assets/images/creation_hunt/garden_landscape.png',
  instruction: 'Find the things Allah created in the garden!',
  instructionAtTop: true,
  spots: [
    CreationHuntSpot(
      id: 'fence',
      isCreation: false,
      x: 0.485,
      y: 0.306,
      w: 0.475,
      h: 0.072,
      radius: CreationHuntRadius.soft,
      icon: '🚧',
      label: 'fence',
    ),
    CreationHuntSpot(
      id: 'bench',
      isCreation: false,
      x: 0.183,
      y: 0.376,
      w: 0.34,
      h: 0.105,
      radius: CreationHuntRadius.soft,
      icon: '🪑',
      label: 'bench',
    ),
    CreationHuntSpot(
      id: 'watering_can',
      isCreation: false,
      x: 0.804,
      y: 0.461,
      w: 0.27,
      h: 0.097,
      radius: CreationHuntRadius.soft,
      icon: '🪣',
      label: 'watering can',
    ),
    CreationHuntSpot(
      id: 'butterfly',
      isCreation: true,
      x: 0.363,
      y: 0.480,
      w: 0.20,
      h: 0.088,
      radius: CreationHuntRadius.circle,
      icon: '🦋',
      label: 'butterfly',
    ),
    CreationHuntSpot(
      id: 'flower',
      isCreation: true,
      x: 0.117,
      y: 0.526,
      w: 0.22,
      h: 0.092,
      radius: CreationHuntRadius.circle,
      icon: '🌸',
      label: 'flower',
    ),
    CreationHuntSpot(
      id: 'bee',
      isCreation: true,
      x: 0.748,
      y: 0.549,
      w: 0.195,
      h: 0.070,
      radius: CreationHuntRadius.circle,
      icon: '🐝',
      label: 'bee',
    ),
    CreationHuntSpot(
      id: 'ladybug',
      isCreation: true,
      x: 0.136,
      y: 0.714,
      w: 0.135,
      h: 0.067,
      radius: CreationHuntRadius.circle,
      icon: '🐞',
      label: 'ladybug',
    ),
    CreationHuntSpot(
      id: 'toy_robot',
      isCreation: false,
      x: 0.424,
      y: 0.724,
      w: 0.195,
      h: 0.128,
      radius: CreationHuntRadius.soft,
      icon: '🤖',
      label: 'toy robot',
    ),
    CreationHuntSpot(
      id: 'cat',
      isCreation: true,
      x: 0.789,
      y: 0.749,
      w: 0.28,
      h: 0.185,
      radius: CreationHuntRadius.blob,
      icon: '🐈',
      label: 'cat',
    ),
    CreationHuntSpot(
      id: 'grass',
      isCreation: true,
      x: 0.520,
      y: 0.835,
      w: 0.26,
      h: 0.070,
      radius: CreationHuntRadius.soft,
      icon: '🌿',
      label: 'grass',
    ),
  ],
);

// ─────────────────────────────────────────────────────────────
// SIRAH STORY -- SESSION DATA
// ─────────────────────────────────────────────────────────────
// Ported 1:1 from the supplied "Sirah Story" prototype's own per-session
// `PAGES` tables: same narration lines, same questions, same right and
// wrong answers, word for word.
//
// One session per stage, distributed across the journey the way the
// prototype's Session Select screen orders them: Session 1 (Birth) in
// Destination 4, Session 2 (Halimah) in 5, Session 3 (Family) in 6,
// Session 4 (Al-Amin) in 7 -- landing on the four "Sirah Story Module"
// lessons that were already there. Every session opens on the same start
// screen; only the session card and the two scenes change.
//
// The scene art is new: full-width painted backdrops sized to the screen.
// The prototype's own cut-out layers sit on top of them unchanged — each
// one's placement ported from its CSS percentages to the wider frame with
// its aspect ratio preserved (see [SirahStoryLayer]).
// ─────────────────────────────────────────────────────────────

const String _sirahBg = 'assets/images/sirah_story';

const SirahStorySession sirahBirthSession = SirahStorySession(
  number: 1,
  title: 'A Special Birth in Makkah',
  blurb: 'The night a light came to the city of the Kaaba.',
  pages: [
    SirahStoryPage(
      background: '$_sirahBg/s1p1_bg.png',
      narration:
          'Long ago, a blessed child was born in the city of Makkah. '
          'His name was Muhammad.',
      narrationMs: 6200,
      glow: SirahStoryLayer(
        asset: '$_sirahBg/s1p1_kaaba.png',
        x: 0.4971,
        y: 0.5338,
        w: 0.2402,
        h: 0.485,
      ),
      prompt: 'Where was Prophet Muhammad born?',
      correct: 'In Makkah',
      decoy: 'In a forest',
    ),
    SirahStoryPage(
      background: '$_sirahBg/s1p2_bg.png',
      narration:
          "His father's name was Abdullah, and his mother's name was Aminah.",
      narrationMs: 5200,
      glow: SirahStoryLayer(
        asset: '$_sirahBg/s1p2_bed.png',
        x: 0.3921,
        y: 0.6217,
        w: 0.5019,
        h: 0.744,
      ),
      prompt: "What was his mother's name?",
      correct: 'Aminah',
      decoy: 'Fatimah',
    ),
  ],
);

const SirahStorySession sirahHalimahSession = SirahStorySession(
  number: 2,
  title: 'Halimah and the Desert',
  blurb: 'A kind woman takes the baby to the open desert.',
  pages: [
    SirahStoryPage(
      background: '$_sirahBg/s2p1_bg.png',
      narration:
          'When he was a baby, he was sent to live in the desert to grow up '
          'healthy and strong.',
      narrationMs: 6400,
      glow: SirahStoryLayer(
        asset: '$_sirahBg/s2p1_tent.png',
        x: 0.5003,
        y: 0.5074,
        w: 0.606,
        h: 0.8983,
      ),
      prompt: 'Where did he spend his early childhood?',
      correct: 'In the desert',
      decoy: 'In a castle',
    ),
    SirahStoryPage(
      background: '$_sirahBg/s2p2_bg.png',
      narration:
          'A kind woman named Halimah cared for him. She loved him very much.',
      narrationMs: 5200,
      glow: SirahStoryLayer(
        asset: '$_sirahBg/s2p2_halimah.png',
        x: 0.361,
        y: 0.5278,
        w: 0.4569,
        h: 0.9365,
      ),
      prompt: 'Who was the kind woman that cared for him?',
      correct: 'Halimah',
      decoy: 'Khadijah',
    ),
  ],
);

const SirahStorySession sirahFamilySession = SirahStorySession(
  number: 3,
  title: 'Cared by Family',
  blurb: 'A grandfather and an uncle who never let him go.',
  pages: [
    SirahStoryPage(
      background: '$_sirahBg/s3p1_bg.png',
      narration:
          'When he was young, his mother passed away. His loving grandfather, '
          'Abdul-Muttalib, took care of him.',
      narrationMs: 7200,
      glow: SirahStoryLayer(
        asset: '$_sirahBg/s3p1_staff.png',
        x: 0.8464,
        y: 0.6699,
        w: 0.0928,
        h: 0.6192,
      ),
      prompt: 'Who took care of him after his mother?',
      correct: 'His grandfather',
      decoy: 'A king',
    ),
    SirahStoryPage(
      background: '$_sirahBg/s3p2_bg.png',
      narration:
          'Later, his grandfather also passed away. Then, his uncle Abu Talib '
          'protected him and treated him like his own son.',
      narrationMs: 8000,
      glow: SirahStoryLayer(
        asset: '$_sirahBg/s3p2_camel.png',
        x: 0.8345,
        y: 0.4792,
        w: 0.3214,
        h: 0.7443,
      ),
      prompt: 'Who protected him next?',
      correct: 'His uncle, Abu Talib',
      decoy: 'A neighbor',
    ),
  ],
);

const SirahStorySession sirahAlAminSession = SirahStorySession(
  number: 4,
  title: 'Al-Amin, The Trustworthy',
  blurb: 'The shepherd boy everyone learned to trust.',
  pages: [
    SirahStoryPage(
      background: '$_sirahBg/s4p1_bg.png',
      narration:
          'As a boy, Muhammad helped his family by working as a shepherd. '
          'Taking care of sheep taught him to be patient and kind.',
      narrationMs: 8000,
      glow: SirahStoryLayer(
        asset: '$_sirahBg/s4p1_sheep.png',
        x: 0.5987,
        y: 0.6939,
        w: 0.3245,
        h: 0.5411,
      ),
      deco: [
        SirahStoryLayer(
          asset: '$_sirahBg/s4p1_boy.png',
          x: 0.3881,
          y: 0.452,
          w: 0.264,
          h: 0.7828,
        ),
      ],
      prompt: 'What work did he do when he was young?',
      correct: 'A shepherd',
      decoy: 'A soldier',
    ),
    SirahStoryPage(
      background: '$_sirahBg/s4p2_bg.png',
      narration:
          'He never lied and always kept his promises. The people loved him '
          'and called him Al-Amin, which means The Trustworthy.',
      narrationMs: 8400,
      glow: SirahStoryLayer(
        asset: '$_sirahBg/s4p2_star.png',
        x: 0.5002,
        y: 0.2067,
        w: 0.1309,
        h: 0.2801,
      ),
      prompt: "What does 'Al-Amin' mean?",
      correct: 'The Trustworthy',
      decoy: 'The Fastest Runner',
      celebrate: true,
    ),
  ],
);

// ─────────────────────────────────────────────────────────────
// CLASSROOM HEROES -- SESSION DATA
// ─────────────────────────────────────────────────────────────
// Ported 1:1 from the supplied "Classroom Heroes" prototype's own
// `SESSIONS` table: same scenario artwork, prompts, choices, feedback,
// retry lines and finish lines, word for word.
//
// One session per stage, distributed across the journey exactly as the
// prototype's own `stage:` field says: Session 1 (Respect) in Destination
// 4, Session 2 (Kindness) in 5, Session 3 (Responsibility) in 6, Session 4
// (Teamwork) in 7. Every session opens on the same title screen -- only the
// session card and the scenarios change.
// ─────────────────────────────────────────────────────────────

const String _heroesBg = 'assets/images/classroom_heroes/bg';

const ClassroomHeroesSession heroesRespectSession = ClassroomHeroesSession(
  number: 1,
  tag: 'SESSION 1 · RESPECT',
  title: 'Respecting Teachers',
  blurb: 'Greeting · Listening · Asking permission',
  retryText:
      'That choice does not show respect. You don’t earn progress yet — '
      'listen once more and pick the kind choice.',
  finishText:
      'You completed 3 respectful choices. Ahmad and Amina are proud of you!',
  questions: [
    ClassroomHeroesQuestion(
      scenarioImage: '$_heroesBg/amina_enters_class.jpg',
      promptText:
          'Amina enters the classroom and sees her teacher. What should she do?',
      correctText: 'Greet the teacher politely.',
      decoyText: 'Ignore the teacher.',
      successFeedback: 'Great job! Greeting your teacher shows respect.',
    ),
    ClassroomHeroesQuestion(
      scenarioImage: '$_heroesBg/teacher_explaining.jpg',
      promptText:
          'The teacher is explaining a new lesson. What should Ahmad do?',
      correctText: 'Listen carefully and pay attention.',
      decoyText: 'Talk loudly with friends.',
      successFeedback:
          'Excellent! A good student listens when the teacher speaks.',
    ),
    ClassroomHeroesQuestion(
      scenarioImage: '$_heroesBg/ahmad_needs_leave.jpg',
      promptText:
          'Ahmad needs to leave the classroom. What should he do first?',
      correctText: 'Raise his hand and ask permission.',
      decoyText: 'Leave without telling anyone.',
      successFeedback: 'Good choice! Asking permission shows respect.',
    ),
  ],
);

const ClassroomHeroesSession heroesKindnessSession = ClassroomHeroesSession(
  number: 2,
  tag: 'SESSION 2 · KINDNESS',
  title: 'Showing Kindness',
  blurb: 'Helping · Sharing · Comforting friends',
  retryText:
      'That choice is not kind. You don’t earn progress yet — think about '
      'your classmate’s feelings and pick again.',
  finishText: 'You completed 3 kind choices. Ahmad and Amina are proud of you!',
  questions: [
    ClassroomHeroesQuestion(
      scenarioImage: '$_heroesBg/dropped_books.jpg',
      promptText:
          'Amina sees her classmate drop their books. What should she do?',
      correctText: 'Help pick up the books.',
      decoyText: 'Laugh at her classmate.',
      successFeedback: 'Wonderful! Helping others shows true kindness.',
    ),
    ClassroomHeroesQuestion(
      scenarioImage: '$_heroesBg/forgot_pencil.jpg',
      promptText: 'A classmate forgot to bring a pencil. What should Ahmad do?',
      correctText: 'Share an extra pencil.',
      decoyText: 'Hide his pencils.',
      successFeedback: 'Great! Sharing what we have is a kind action.',
    ),
    ClassroomHeroesQuestion(
      scenarioImage: '$_heroesBg/sad_friend.jpg',
      promptText:
          'Your friend feels sad because they made a mistake. What should you do?',
      correctText: 'Encourage and comfort them.',
      decoyText: 'Make fun of them.',
      successFeedback: 'Excellent! Good friends support each other.',
    ),
  ],
);

const ClassroomHeroesSession heroesResponsibilitySession =
    ClassroomHeroesSession(
      number: 3,
      tag: 'SESSION 3 · RESPONSIBILITY',
      title: 'Being Responsible',
      blurb: 'Tidying up · Book care · Homework',
      retryText:
          'That choice is not responsible. You don’t earn progress yet — '
          'think about caring for your class and pick again.',
      finishText:
          'You completed 3 responsible choices. Ahmad and Amina are proud '
          'of you!',
      questions: [
        ClassroomHeroesQuestion(
          scenarioImage: '$_heroesBg/paper_on_floor.jpg',
          promptText:
              'Ahmad sees a piece of paper on the floor. What should he do?',
          correctText: 'Pick it up and throw it in the bin.',
          decoyText: 'Step on it and leave it there.',
          successFeedback: 'Great! Keeping places clean is our responsibility.',
        ),
        ClassroomHeroesQuestion(
          scenarioImage: '$_heroesBg/finished_book.jpg',
          promptText: 'Amina finished using her textbook. What should she do?',
          correctText: 'Return it neatly to the shelf.',
          decoyText: 'Throw it on the floor.',
          successFeedback:
              'Excellent! We must take care of the things given to us.',
        ),
        ClassroomHeroesQuestion(
          scenarioImage: '$_heroesBg/teacher_homework.jpg',
          promptText:
              'The teacher gives the class an assignment. What should a '
              'responsible student do?',
          correctText: 'Complete it and submit it on time.',
          decoyText: 'Ignore it.',
          successFeedback: 'Good job! Responsibility helps us learn and grow.',
        ),
      ],
    );

const ClassroomHeroesSession heroesTeamworkSession = ClassroomHeroesSession(
  number: 4,
  tag: 'SESSION 4 · TEAMWORK',
  title: 'Working Together',
  blurb: 'Sharing ideas · Taking turns · Welcoming',
  retryText:
      'That choice does not help the team. You don’t earn progress yet — '
      'think about your classmates and pick again.',
  finishText:
      'You completed 3 teamwork choices. Ahmad and Amina are proud of you!',
  questions: [
    ClassroomHeroesQuestion(
      scenarioImage: '$_heroesBg/group_activity.jpg',
      promptText:
          'The teacher asks the students to work together on a project. '
          'What should the group do?',
      correctText: 'Share ideas and help each other.',
      decoyText: 'Argue and let one person do all the work.',
      successFeedback:
          'Great teamwork! Helping each other makes learning better.',
    ),
    ClassroomHeroesQuestion(
      scenarioImage: '$_heroesBg/many_want_to_answer.jpg',
      promptText:
          "Many students want to answer the teacher's question. What should "
          'you do?',
      correctText: 'Wait patiently for your turn.',
      decoyText: 'Shout your answer over the others.',
      successFeedback:
          'Excellent! Patience and waiting your turn are good manners.',
    ),
    ClassroomHeroesQuestion(
      scenarioImage: '$_heroesBg/new_student.jpg',
      promptText:
          'A new student joins the class and feels shy. What should you do?',
      correctText: 'Welcome them and introduce yourself.',
      decoyText: 'Ignore them and make them feel left out.',
      successFeedback: 'Wonderful! Kindness makes everyone feel welcome.',
    ),
  ],
);

// ─────────────────────────────────────────────────────────────
// THE QUR'AN ETIQUETTE
// Ported 1:1 from the supplied "Qur'an Etiquette" prototype (v2): both
// sessions, their copy, retry lines, lesson checklists and badge spots.
// Session 1 (At the Masjid) plays in Destination 1, Session 2 (At Home) in
// Destination 3 -- the two "The Qur'an Etiquette" lessons on the journey.
// ─────────────────────────────────────────────────────────────

const String _etqBg = 'assets/images/quran_etiquette';

const QuranEtiquetteSession etiquetteMasjidSession = QuranEtiquetteSession(
  number: 1,
  tag: 'SESSION 1 · AT THE MASJID',
  title: 'At the Masjid',
  blurb: "Listening · Wudhu · Handling the Qur'an",
  retry:
      'That choice does not show adab. You don’t earn progress yet — listen once more and pick the respectful choice.',
  finish: 'You completed 5 respectful choices at the masjid!',
  lessons: [
    'Sit quietly and listen.',
    'Keep listening even if others want to chat.',
    'Make Wudhu and sit respectfully before reading.',
    "Place the Qur'an carefully on a clean shelf.",
    'Say “Sadaqallahul Azim” after recitation.',
  ],
  questions: [
    QuranEtiquetteQuestion(
      image: '$_etqBg/s1q1.jpg',
      feedbackImage: '$_etqBg/s1q1f.jpg',
      badgeX: 0.25,
      badgeY: 0.36,
      prompt:
          "The Imam begins reciting the Qur'an in the Masjid. What should you do?",
      correct: 'Sit quietly and listen.',
      decoy: 'Run around and play.',
      feedback: 'Great job! Sitting quietly and listening is respectful.',
    ),
    QuranEtiquetteQuestion(
      image: '$_etqBg/s1q2.jpg',
      feedbackImage: '$_etqBg/s1q2f.jpg',
      badgeX: 0.40,
      badgeY: 0.18,
      prompt:
          "Fatimah hears the Qur'an. Her friend wants to chat. What should she do?",
      correct: 'Continue listening quietly.',
      decoy: 'Talk loudly with her friend.',
      feedback: "Excellent! We keep listening quietly to the Qur'an.",
    ),
    QuranEtiquetteQuestion(
      image: '$_etqBg/s1q3.jpg',
      feedbackImage: '$_etqBg/s1q3f.jpg',
      badgeX: 0.57,
      badgeY: 0.24,
      prompt: "Before reading the Qur'an, what should Amina do?",
      correct: 'Make Wudhu and sit respectfully.',
      decoy: 'Eat candy and play.',
      feedback:
          "Good choice! Wudhu and sitting respectfully honour the Qur'an.",
    ),
    QuranEtiquetteQuestion(
      image: '$_etqBg/s1q4.jpg',
      feedbackImage: '$_etqBg/s1q4f.jpg',
      badgeX: 0.58,
      badgeY: 0.09,
      prompt: "You finished reading the Qur'an. What should you do?",
      correct: 'Place it carefully on a clean shelf.',
      decoy: 'Leave it under your toys.',
      feedback: "Wonderful! We keep the Qur'an in a clean, high place.",
    ),
    QuranEtiquetteQuestion(
      image: '$_etqBg/s1q5.jpg',
      feedbackImage: '$_etqBg/s1q5f.jpg',
      badgeX: 0.26,
      badgeY: 0.37,
      prompt: 'The recitation has finished. What should you do?',
      correct: "Say 'Sadaqallahul Azim' respectfully.",
      decoy: 'Start shouting and jumping.',
      feedback: 'Mumtaz! We end recitation with respectful words.',
    ),
  ],
);

const QuranEtiquetteSession etiquetteHomeSession = QuranEtiquetteSession(
  number: 2,
  tag: 'SESSION 2 · AT HOME',
  title: 'At Home',
  blurb: 'Stop playing · Phones down · Kind reminders',
  retry:
      'That choice is not respectful. You don’t earn progress yet — think about the Qur\'an being recited and pick again.',
  finish: 'You completed 5 respectful choices at home!',
  lessons: [
    'Stop playing and listen respectfully.',
    'Put the phone down and listen.',
    'Kindly ask others to be quiet.',
    'Do not play loudly during recitation.',
    'Sit quietly and listen.',
  ],
  questions: [
    QuranEtiquetteQuestion(
      image: '$_etqBg/s2q1.jpg',
      feedbackImage: '$_etqBg/s2q1f.jpg',
      badgeX: 0.40,
      badgeY: 0.09,
      prompt:
          "The Qur'an starts playing while Yusuf is playing with blocks. What should he do?",
      correct: 'Stop playing and listen respectfully.',
      decoy: 'Keep playing and ignore it.',
      feedback: 'Great job! We pause our play to listen.',
    ),
    QuranEtiquetteQuestion(
      image: '$_etqBg/s2q2.jpg',
      feedbackImage: '$_etqBg/s2q2f.jpg',
      badgeX: 0.36,
      badgeY: 0.07,
      prompt: "The Qur'an is being recited on the phone. What should you do?",
      correct: 'Put the phone down and listen.',
      decoy: 'Watch cartoons instead.',
      feedback: 'Excellent! Listening comes before entertainment.',
    ),
    QuranEtiquetteQuestion(
      image: '$_etqBg/s2q3.jpg',
      feedbackImage: '$_etqBg/s2q3f.jpg',
      badgeX: 0.68,
      badgeY: 0.08,
      prompt:
          "Your younger brother is making loud noise while the Qur'an is playing. What should you do?",
      correct: 'Kindly ask him to be quiet.',
      decoy: 'Yell at him.',
      feedback: 'Wonderful! Gentle reminders are the kind way.',
    ),
    QuranEtiquetteQuestion(
      image: '$_etqBg/s2q4.jpg',
      feedbackImage: '$_etqBg/s2q4f.jpg',
      badgeX: 0.39,
      badgeY: 0.15,
      prompt:
          "Is it respectful to play loudly while the Qur'an is being recited?",
      correct: 'No.',
      decoy: 'Yes.',
      feedback: 'Correct! Loud play during recitation is not respectful.',
    ),
    QuranEtiquetteQuestion(
      image: '$_etqBg/s2q5.jpg',
      feedbackImage: '$_etqBg/s2q5f.jpg',
      badgeX: 0.30,
      badgeY: 0.08,
      prompt: "The Qur'an is being recited. What should Ahmad do?",
      correct: 'Sit quietly and listen.',
      decoy: 'Cover his ears.',
      feedback: "Mumtaz! Sitting quietly shows love for the Qur'an.",
    ),
  ],
);

/// Both sessions in prototype order — the title screen lists every one.
const List<QuranEtiquetteSession> etiquetteSessions = [
  etiquetteMasjidSession,
  etiquetteHomeSession,
];

// ─────────────────────────────────────────────────────────────
// FULL CURRICULUM ARRAY -- Journey Map (7 stages, 40 sessions)
// ─────────────────────────────────────────────────────────────

const List<Destination> curriculum = [
  Destination(
    id: 1,
    name: 'Welcome to Madrasah',
    nameAr: 'أَهْلًا بِكُمْ فِي المَدْرَسَة',
    icon: '🏫',
    color: '#D85A30',
    bg: '#FDDCCC',
    mapX: 719,
    mapY: 2532,
    description:
        'Meet your Madrasah family, learn Arabic greetings, and take your first steps into Islamic learning.',
    state: DestinationState.completed,
    lessons: [
      Lesson(
        id: 'dest1-s1',
        title: 'The Greeting Match - Session 1',
        titleAr: 'لُعْبَة التَّحِيَّة 1',
        icon: '👋',
        color: '#EF9F27',
        xp: 20,
        activities: [
          Activity(
            id: 'dest1-s1-act',
            type: ActivityType.pronounce,
            title: 'The Greeting Match',
            icon: '👋',
            xp: 20,
            greetingQuestions: greetingQuestions,
          ),
        ],
      ),
      Lesson(
        id: 'dest1-s2',
        title: "Allah's Creation Hunt - Session 1 (Forest)",
        titleAr: 'مُطَارَدَةُ خَلْقِ اللّٰه 1 (الغَابَة)',
        icon: '🌳',
        color: '#5B9A1E',
        xp: 30,
        activities: [
          Activity(
            id: 'dest1-s2-act',
            type: ActivityType.creationHunt,
            title: "Allah's Creation Hunt (Forest)",
            icon: '🌳',
            xp: 30,
            huntStage: forestHuntStage,
          ),
        ],
      ),
      Lesson(
        id: 'dest1-s3',
        title: 'Magic Sand Tracer - Session 1 (Alif to Kha)',
        titleAr: 'تَتَبُّعُ الرَّمْل السِّحْرِيّ 1',
        icon: '✍️',
        color: '#0F6E56',
        xp: 20,
        activities: [
          Activity(
            id: 'dest1-s3-act',
            type: ActivityType.trace,
            title: 'Magic Sand Tracer (Alif to Kha)',
            icon: '✍️',
            xp: 20,
            cards: sandTracer1,
          ),
        ],
      ),
      Lesson(
        id: 'dest1-s4',
        title: 'Arabic Sound Detective - Session 1',
        titleAr: 'مُحَقِّقُ الأَصْوَاتِ العَرَبِيَّة 1',
        icon: '🎈',
        color: '#D85A30',
        xp: 30,
        activities: [
          Activity(
            id: 'dest1-s4-act',
            type: ActivityType.harakatPop,
            title: 'Arabic Sound Detective',
            icon: '🎈',
            xp: 30,
            cards: harakatCards,
          ),
        ],
      ),
      Lesson(
        id: 'dest1-s5',
        title: "The Qur'an Etiquette - Session 1",
        titleAr: 'آدَابُ القُرْآن 1',
        icon: '📗',
        color: '#2A7FCC',
        xp: 30,
        activities: [
          Activity(
            id: 'dest1-s5-act',
            type: ActivityType.quranEtiquette,
            title: "The Qur'an Etiquette",
            icon: '📗',
            xp: 30,
            etiquetteSession: etiquetteMasjidSession,
          ),
        ],
      ),
    ],
  ),

  Destination(
    id: 2,
    name: 'Exploring Our World',
    nameAr: 'اِسْتِكْشَافُ عَالَمِنَا',
    icon: '🌍',
    color: '#EF9F27',
    bg: '#FDECC8',
    mapX: 536,
    mapY: 2043,
    description:
        "Discover Allah's creation in the sky, meet new letters, and build your first Ayah.",
    state: DestinationState.current,
    lessons: [
      Lesson(
        id: 'dest2-s1',
        title: 'The Greeting Match - Session 2',
        titleAr: 'لُعْبَة التَّحِيَّة 2',
        icon: '👋',
        color: '#EF9F27',
        xp: 20,
        activities: [
          Activity(
            id: 'dest2-s1-act',
            type: ActivityType.pronounce,
            title: 'The Greeting Match',
            icon: '👋',
            xp: 20,
            greetingQuestions: greetingQuestions,
          ),
        ],
      ),
      Lesson(
        id: 'dest2-s2',
        title: "Allah's Creation Hunt - Session 2 (Sky)",
        titleAr: 'مُطَارَدَةُ خَلْقِ اللّٰه 2 (السَّمَاء)',
        icon: '🌌',
        color: '#5B9A1E',
        xp: 30,
        activities: [
          Activity(
            id: 'dest2-s2-act',
            type: ActivityType.creationHunt,
            title: "Allah's Creation Hunt (Sky)",
            icon: '🌌',
            xp: 30,
            huntStage: skyHuntStage,
          ),
        ],
      ),
      Lesson(
        id: 'dest2-s3',
        title: 'Label Maker - Session 1 (Home)',
        titleAr: 'صَانِعُ البِطَاقَات 1 (البَيْت)',
        icon: '🏷️',
        color: '#D85A30',
        xp: 30,
        activities: [
          Activity(
            id: 'dest2-s3-act',
            type: ActivityType.fiqhDrag,
            title: 'Label Maker (Home)',
            icon: '🏷️',
            xp: 30,
            fiqhItems: [
              FiqhDragItem(
                id: 'home1',
                emoji: '🛏️',
                label: 'Bed',
                correctZoneId: 'bedroom',
              ),
              FiqhDragItem(
                id: 'home2',
                emoji: '🍽️',
                label: 'Dining Table',
                correctZoneId: 'kitchen',
              ),
              FiqhDragItem(
                id: 'home3',
                emoji: '🛁',
                label: 'Bathtub',
                correctZoneId: 'bathroom',
              ),
              FiqhDragItem(
                id: 'home4',
                emoji: '🛋️',
                label: 'Sofa',
                correctZoneId: 'living',
              ),
            ],
            fiqhZones: [
              FiqhDropZone(id: 'bedroom', label: 'Bedroom', icon: '🛏️'),
              FiqhDropZone(id: 'kitchen', label: 'Kitchen', icon: '🍽️'),
              FiqhDropZone(id: 'bathroom', label: 'Bathroom', icon: '🛁'),
              FiqhDropZone(id: 'living', label: 'Living Room', icon: '🛋️'),
            ],
          ),
        ],
      ),
      Lesson(
        id: 'dest2-s4',
        title: 'Magic Sand Tracer - Session 2 (Dal to Dad)',
        titleAr: 'تَتَبُّعُ الرَّمْل السِّحْرِيّ 2',
        icon: '✍️',
        color: '#0F6E56',
        xp: 20,
        activities: [
          Activity(
            id: 'dest2-s4-act',
            type: ActivityType.trace,
            title: 'Magic Sand Tracer (Dal to Dad)',
            icon: '✍️',
            xp: 20,
            cards: sandTracer2,
          ),
        ],
      ),
      Lesson(
        id: 'dest2-s5',
        title: 'Arabic Sound Detective - Session 2',
        titleAr: 'مُحَقِّقُ الأَصْوَاتِ العَرَبِيَّة 2',
        icon: '🎈',
        color: '#D85A30',
        xp: 30,
        activities: [
          Activity(
            id: 'dest2-s5-act',
            type: ActivityType.harakatPop,
            title: 'Arabic Sound Detective',
            icon: '🎈',
            xp: 30,
            cards: harakatCards,
          ),
        ],
      ),
      Lesson(
        id: 'dest2-s6',
        title: 'Ayah Builder - Session 1 (Basmalah)',
        titleAr: 'بِنَاءُ الْآيَةِ 1 (البَسْمَلَة)',
        icon: '🧩',
        color: '#6C63D6',
        xp: 50,
        activities: [
          Activity(
            id: 'dest2-s6-act',
            type: ActivityType.ayahBuilder,
            title: 'Ayah Builder (Basmalah)',
            icon: '🧩',
            xp: 50,
            ayahSession: ayahBasmalahSession,
          ),
        ],
      ),
    ],
  ),

  Destination(
    id: 3,
    name: 'A Growing Muslim',
    nameAr: 'مُسْلِمٌ يَنْمُو',
    icon: '🌱',
    color: '#5B9A1E',
    bg: '#DCEDC8',
    mapX: 589,
    mapY: 1737,
    description:
        "Grow in faith and vocabulary through Qur'an etiquette, body-part words, and daily Ayahs.",
    state: DestinationState.locked,
    lessons: [
      Lesson(
        id: 'dest3-s1',
        title: "The Qur'an Etiquette - Session 2",
        titleAr: 'آدَابُ القُرْآن 2',
        icon: '📗',
        color: '#2A7FCC',
        xp: 30,
        activities: [
          Activity(
            id: 'dest3-s1-act',
            type: ActivityType.quranEtiquette,
            title: "The Qur'an Etiquette",
            icon: '📗',
            xp: 30,
            etiquetteSession: etiquetteHomeSession,
          ),
        ],
      ),
      Lesson(
        id: 'dest3-s2',
        title: "Allah's Creation Hunt - Session 3 (Garden)",
        titleAr: 'مُطَارَدَةُ خَلْقِ اللّٰه 3 (الحَدِيقَة)',
        icon: '🌷',
        color: '#5B9A1E',
        xp: 30,
        activities: [
          Activity(
            id: 'dest3-s2-act',
            type: ActivityType.creationHunt,
            title: "Allah's Creation Hunt (Garden)",
            icon: '🌷',
            xp: 30,
            huntStage: gardenHuntStage,
          ),
        ],
      ),
      Lesson(
        id: 'dest3-s3',
        title: 'Label Maker - Session 2 (Body Parts)',
        titleAr: 'صَانِعُ البِطَاقَات 2 (أَعْضَاءُ الجِسْم)',
        icon: '🏷️',
        color: '#D85A30',
        xp: 30,
        activities: [
          Activity(
            id: 'dest3-s3-act',
            type: ActivityType.fiqhDrag,
            title: 'Label Maker (Body Parts)',
            icon: '🏷️',
            xp: 30,
            fiqhItems: [
              FiqhDragItem(
                id: 'body1',
                emoji: '👤',
                label: "Ra's / رَأْس",
                correctZoneId: 'head',
              ),
              FiqhDragItem(
                id: 'body2',
                emoji: '👀',
                label: "'Ayn / عَيْن",
                correctZoneId: 'eye',
              ),
              FiqhDragItem(
                id: 'body3',
                emoji: '👂',
                label: 'Udhun / أُذُن',
                correctZoneId: 'ear',
              ),
              FiqhDragItem(
                id: 'body4',
                emoji: '👃',
                label: 'Anf / أَنْف',
                correctZoneId: 'nose',
              ),
              FiqhDragItem(
                id: 'body5',
                emoji: '👄',
                label: 'Fam / فَم',
                correctZoneId: 'mouth',
              ),
              FiqhDragItem(
                id: 'body6',
                emoji: '✋',
                label: 'Yad / يَد',
                correctZoneId: 'hand',
              ),
            ],
            fiqhZones: [
              FiqhDropZone(id: 'head', label: 'Head'),
              FiqhDropZone(id: 'eye', label: 'Eye'),
              FiqhDropZone(id: 'ear', label: 'Ear'),
              FiqhDropZone(id: 'nose', label: 'Nose'),
              FiqhDropZone(id: 'mouth', label: 'Mouth'),
              FiqhDropZone(id: 'hand', label: 'Hand'),
            ],
          ),
        ],
      ),
      Lesson(
        id: 'dest3-s4',
        title: 'Magic Sand Tracer - Session 3 (Ta to Qaf)',
        titleAr: 'تَتَبُّعُ الرَّمْل السِّحْرِيّ 3',
        icon: '✍️',
        color: '#0F6E56',
        xp: 20,
        activities: [
          Activity(
            id: 'dest3-s4-act',
            type: ActivityType.trace,
            title: 'Magic Sand Tracer (Ta to Qaf)',
            icon: '✍️',
            xp: 20,
            cards: sandTracer3,
          ),
        ],
      ),
      Lesson(
        id: 'dest3-s5',
        title: 'Arabic Sound Detective - Session 3',
        titleAr: 'مُحَقِّقُ الأَصْوَاتِ العَرَبِيَّة 3',
        icon: '🎈',
        color: '#D85A30',
        xp: 30,
        activities: [
          Activity(
            id: 'dest3-s5-act',
            type: ActivityType.harakatPop,
            title: 'Arabic Sound Detective',
            icon: '🎈',
            xp: 30,
            cards: harakatCards,
          ),
        ],
      ),
      Lesson(
        id: 'dest3-s6',
        title: 'Ayah Builder - Session 2 (Al-Fatihah 1)',
        titleAr: 'بِنَاءُ الْآيَةِ 2 (الفَاتِحَة ١)',
        icon: '🧩',
        color: '#6C63D6',
        xp: 50,
        activities: [
          Activity(
            id: 'dest3-s6-act',
            type: ActivityType.ayahBuilder,
            title: 'Ayah Builder (Al-Fatihah 1)',
            icon: '🧩',
            xp: 50,
            ayahSession: ayahFatihah1Session,
          ),
        ],
      ),
    ],
  ),

  Destination(
    id: 4,
    name: 'Stories & Letters',
    nameAr: 'قِصَصٌ وَحُرُوف',
    icon: '📖',
    color: '#D85A30',
    bg: '#FDDCCC',
    mapX: 543,
    mapY: 1377,
    description:
        "Meet Prophet Muhammad ﷺ's story, practice respect, and finish tracing the Arabic alphabet.",
    state: DestinationState.locked,
    lessons: [
      Lesson(
        id: 'dest4-s1',
        title: 'Sirah Story Module - Session 1 (Birth)',
        titleAr: 'وَحْدَةُ السِّيرَة 1 (المَوْلِد)',
        icon: '🌙',
        color: '#5B9A1E',
        xp: 40,
        activities: [
          Activity(
            id: 'dest4-s1-act',
            type: ActivityType.sirahStory,
            title: 'Sirah Story Module (Birth)',
            icon: '🌙',
            xp: 40,
            sirahSession: sirahBirthSession,
          ),
        ],
      ),
      Lesson(
        id: 'dest4-s2',
        title: 'Classroom Heroes - Session 1 (Respect)',
        titleAr: 'أَبْطَالُ الصَّفّ 1 (الاِحْتِرَام)',
        icon: '🤝',
        color: '#D85A30',
        xp: 30,
        activities: [
          Activity(
            id: 'dest4-s2-act',
            type: ActivityType.classroomHeroes,
            title: 'Classroom Heroes (Respect)',
            icon: '🤝',
            xp: 30,
            heroesSession: heroesRespectSession,
          ),
        ],
      ),
      Lesson(
        id: 'dest4-s3',
        title: 'Magic Sand Tracer - Session 4 (Kaf to Ya)',
        titleAr: 'تَتَبُّعُ الرَّمْل السِّحْرِيّ 4',
        icon: '✍️',
        color: '#0F6E56',
        xp: 20,
        activities: [
          Activity(
            id: 'dest4-s3-act',
            type: ActivityType.trace,
            title: 'Magic Sand Tracer (Kaf to Ya)',
            icon: '✍️',
            xp: 20,
            cards: sandTracer4,
          ),
        ],
      ),
      Lesson(
        id: 'dest4-s4',
        title: 'Arabic Sound Detective - Session 4',
        titleAr: 'مُحَقِّقُ الأَصْوَاتِ العَرَبِيَّة 4',
        icon: '🎈',
        color: '#D85A30',
        xp: 30,
        activities: [
          Activity(
            id: 'dest4-s4-act',
            type: ActivityType.harakatPop,
            title: 'Arabic Sound Detective',
            icon: '🎈',
            xp: 30,
            cards: harakatCards,
          ),
        ],
      ),
      Lesson(
        id: 'dest4-s5',
        title: 'Ayah Builder - Session 3 (Al-Fatihah 2)',
        titleAr: 'بِنَاءُ الْآيَةِ 3 (الفَاتِحَة ٢)',
        icon: '🧩',
        color: '#6C63D6',
        xp: 50,
        activities: [
          Activity(
            id: 'dest4-s5-act',
            type: ActivityType.ayahBuilder,
            title: 'Ayah Builder (Al-Fatihah 2)',
            icon: '🧩',
            xp: 50,
            ayahSession: ayahFatihah2Session,
          ),
        ],
      ),
      Lesson(
        id: 'dest4-s6',
        title: 'Taharah Adventure - Session 1 (Hygiene Basics)',
        titleAr: 'مُغَامَرَةُ الطَّهَارَة 1 (أَسَاسِيَّاتُ النَّظَافَة)',
        icon: '🧼',
        color: '#D85A30',
        xp: 30,
        activities: [
          Activity(
            id: 'dest4-s6-act',
            type: ActivityType.taharahAdventure,
            title: 'Taharah Adventure (Hygiene Basics)',
            icon: '🧼',
            xp: 30,
            taharahSession: TaharahSession.cleanOrDirty,
          ),
        ],
      ),
    ],
  ),

  Destination(
    id: 5,
    name: 'Cleanliness & Character',
    nameAr: 'النَّظَافَةُ وَالأَخْلَاق',
    icon: '🧼',
    color: '#2A7FCC',
    bg: '#E8F4FF',
    mapX: 490,
    mapY: 949,
    description:
        'Practice classroom kindness, meet Halimah, and take the first steps of wudu.',
    state: DestinationState.locked,
    lessons: [
      Lesson(
        id: 'dest5-s1',
        title: 'Label Maker - Session 3 (Classroom)',
        titleAr: 'صَانِعُ البِطَاقَات 3 (الصَّفّ)',
        icon: '🏷️',
        color: '#D85A30',
        xp: 30,
        activities: [
          Activity(
            id: 'dest5-s1-act',
            type: ActivityType.fiqhDrag,
            title: 'Label Maker (Classroom)',
            icon: '🏷️',
            xp: 30,
            fiqhItems: [
              FiqhDragItem(
                id: 'class1',
                emoji: '📖',
                label: 'Book',
                correctZoneId: 'shelf',
              ),
              FiqhDragItem(
                id: 'class2',
                emoji: '✏️',
                label: 'Pencil',
                correctZoneId: 'desk',
              ),
              FiqhDragItem(
                id: 'class3',
                emoji: '🖍️',
                label: 'Whiteboard',
                correctZoneId: 'front',
              ),
              FiqhDragItem(
                id: 'class4',
                emoji: '🎒',
                label: 'Bag',
                correctZoneId: 'hook',
              ),
            ],
            fiqhZones: [
              FiqhDropZone(id: 'shelf', label: 'Bookshelf', icon: '📚'),
              FiqhDropZone(id: 'desk', label: 'Desk', icon: '🪑'),
              FiqhDropZone(id: 'front', label: 'Front of Class', icon: '🖍️'),
              FiqhDropZone(id: 'hook', label: 'Bag Hook', icon: '🪝'),
            ],
          ),
        ],
      ),
      Lesson(
        id: 'dest5-s2',
        title: 'Sirah Story Module - Session 2 (Halimah/Desert)',
        titleAr: 'وَحْدَةُ السِّيرَة 2 (حَلِيمَة وَالصَّحْرَاء)',
        icon: '🐑',
        color: '#5B9A1E',
        xp: 40,
        activities: [
          Activity(
            id: 'dest5-s2-act',
            type: ActivityType.sirahStory,
            title: 'Sirah Story Module (Halimah/Desert)',
            icon: '🐑',
            xp: 40,
            sirahSession: sirahHalimahSession,
          ),
        ],
      ),
      Lesson(
        id: 'dest5-s3',
        title: 'Classroom Heroes - Session 2 (Kindness)',
        titleAr: 'أَبْطَالُ الصَّفّ 2 (اللُّطْف)',
        icon: '🤝',
        color: '#D85A30',
        xp: 30,
        activities: [
          Activity(
            id: 'dest5-s3-act',
            type: ActivityType.classroomHeroes,
            title: 'Classroom Heroes (Kindness)',
            icon: '🤝',
            xp: 30,
            heroesSession: heroesKindnessSession,
          ),
        ],
      ),
      Lesson(
        id: 'dest5-s4',
        title: 'Taharah Adventure - Session 2 (Wudhu Pt 1)',
        titleAr: 'مُغَامَرَةُ الطَّهَارَة 2 (الوُضُوء ١)',
        icon: '🚿',
        color: '#D85A30',
        xp: 40,
        activities: [
          Activity(
            id: 'dest5-s4-act',
            type: ActivityType.taharahAdventure,
            title: 'Taharah Adventure (Wudhu Pt 1)',
            icon: '🚿',
            xp: 40,
            taharahSession: TaharahSession.wudhuPart1,
          ),
        ],
      ),
      Lesson(
        id: 'dest5-s5',
        title: 'Ayah Builder - Session 4 (Al-Ikhlas)',
        titleAr: 'بِنَاءُ الْآيَةِ 4 (الإِخْلَاص)',
        icon: '🧩',
        color: '#6C63D6',
        xp: 50,
        activities: [
          Activity(
            id: 'dest5-s5-act',
            type: ActivityType.ayahBuilder,
            title: 'Ayah Builder (Al-Ikhlas)',
            icon: '🧩',
            xp: 50,
            ayahSession: ayahIkhlasSession,
          ),
        ],
      ),
      Lesson(
        id: 'dest5-s6',
        title: 'The Five Pillars - Session 1 (Naming)',
        titleAr: 'أَرْكَانُ الإِسْلَام 1 (التَّسْمِيَة)',
        icon: '🕋',
        color: '#2A7FCC',
        xp: 30,
        activities: [
          Activity(
            id: 'dest5-s6-act',
            type: ActivityType.fivePillars,
            title: 'The Five Pillars (Naming)',
            icon: '🕋',
            xp: 30,
            pillarsMode: FivePillarsMode.scenarios,
          ),
        ],
      ),
    ],
  ),

  Destination(
    id: 6,
    name: 'The Path of the Prophet',
    nameAr: 'طَرِيقُ النَّبِيّ',
    icon: '🕌',
    color: '#6C63D6',
    bg: '#E8E4FF',
    mapX: 566,
    mapY: 620,
    description:
        'Follow the family, responsibility, and worship of Prophet Muhammad ﷺ.',
    state: DestinationState.locked,
    lessons: [
      Lesson(
        id: 'dest6-s1',
        title: 'Sirah Story Module - Session 3 (Family Care)',
        titleAr: 'وَحْدَةُ السِّيرَة 3 (رِعَايَةُ الأُسْرَة)',
        icon: '💚',
        color: '#5B9A1E',
        xp: 40,
        activities: [
          Activity(
            id: 'dest6-s1-act',
            type: ActivityType.sirahStory,
            title: 'Sirah Story Module (Family Care)',
            icon: '💚',
            xp: 40,
            sirahSession: sirahFamilySession,
          ),
        ],
      ),
      Lesson(
        id: 'dest6-s2',
        title: 'Classroom Heroes - Session 3 (Responsibility)',
        titleAr: 'أَبْطَالُ الصَّفّ 3 (المَسْؤُولِيَّة)',
        icon: '🤝',
        color: '#D85A30',
        xp: 30,
        activities: [
          Activity(
            id: 'dest6-s2-act',
            type: ActivityType.classroomHeroes,
            title: 'Classroom Heroes (Responsibility)',
            icon: '🤝',
            xp: 30,
            heroesSession: heroesResponsibilitySession,
          ),
        ],
      ),
      Lesson(
        id: 'dest6-s3',
        title: 'Taharah Adventure - Session 3 (Wudhu Pt 2)',
        titleAr: 'مُغَامَرَةُ الطَّهَارَة 3 (الوُضُوء ٢)',
        icon: '🚿',
        color: '#D85A30',
        xp: 40,
        activities: [
          Activity(
            id: 'dest6-s3-act',
            type: ActivityType.taharahAdventure,
            title: 'Taharah Adventure (Wudhu Pt 2)',
            icon: '🚿',
            xp: 40,
            taharahSession: TaharahSession.wudhuPart2,
          ),
        ],
      ),
      Lesson(
        id: 'dest6-s4',
        title: 'Ayah Builder - Session 5 (Al-Falaq)',
        titleAr: 'بِنَاءُ الْآيَةِ 5 (الفَلَق)',
        icon: '🧩',
        color: '#6C63D6',
        xp: 50,
        activities: [
          Activity(
            id: 'dest6-s4-act',
            type: ActivityType.ayahBuilder,
            title: 'Ayah Builder (Al-Falaq)',
            icon: '🧩',
            xp: 50,
            ayahSession: ayahFalaqSession,
          ),
        ],
      ),
      Lesson(
        id: 'dest6-s5',
        title: 'Ayah Builder - Session 6 (An-Nas)',
        titleAr: 'بِنَاءُ الْآيَةِ 6 (النَّاس)',
        icon: '🧩',
        color: '#6C63D6',
        xp: 50,
        activities: [
          Activity(
            id: 'dest6-s5-act',
            type: ActivityType.ayahBuilder,
            title: 'Ayah Builder (An-Nas)',
            icon: '🧩',
            xp: 50,
            ayahSession: ayahNasSession,
          ),
        ],
      ),
      Lesson(
        id: 'dest6-s6',
        title: 'The Five Pillars - Session 2 (Ordering)',
        titleAr: 'أَرْكَانُ الإِسْلَام 2 (التَّرْتِيب)',
        icon: '🕋',
        color: '#2A7FCC',
        xp: 40,
        activities: [
          Activity(
            id: 'dest6-s6-act',
            type: ActivityType.fivePillars,
            title: 'The Five Pillars (Ordering)',
            icon: '🕋',
            xp: 40,
            pillarsMode: FivePillarsMode.ordering,
          ),
        ],
      ),
    ],
  ),

  Destination(
    id: 7,
    name: 'The Good Deed Hero',
    nameAr: 'بَطَلُ العَمَلِ الصَّالِح',
    icon: '🌳',
    color: '#5B9A1E',
    bg: '#DCF0E6',
    mapX: 727,
    mapY: 245,
    description:
        'Become a Good Deed Hero with Prophetic character, teamwork, and a final review of everything learned.',
    state: DestinationState.locked,
    lessons: [
      Lesson(
        id: 'dest7-s1',
        title: 'Sirah Story Module - Session 4 (Character/Al-Amin)',
        titleAr: 'وَحْدَةُ السِّيرَة 4 (الأَمِين)',
        icon: '✅',
        color: '#5B9A1E',
        xp: 40,
        activities: [
          Activity(
            id: 'dest7-s1-act',
            type: ActivityType.sirahStory,
            title: 'Sirah Story Module (Character/Al-Amin)',
            icon: '✅',
            xp: 40,
            sirahSession: sirahAlAminSession,
          ),
        ],
      ),
      Lesson(
        id: 'dest7-s2',
        title: 'Classroom Heroes - Session 4 (Teamwork)',
        titleAr: 'أَبْطَالُ الصَّفّ 4 (العَمَلُ الجَمَاعِيّ)',
        icon: '🤝',
        color: '#D85A30',
        xp: 30,
        activities: [
          Activity(
            id: 'dest7-s2-act',
            type: ActivityType.classroomHeroes,
            title: 'Classroom Heroes (Teamwork)',
            icon: '🤝',
            xp: 30,
            heroesSession: heroesTeamworkSession,
          ),
        ],
      ),
      Lesson(
        id: 'dest7-s3',
        title: 'Ayah Builder - Session 7 (Al-Kawthar)',
        titleAr: 'بِنَاءُ الْآيَةِ 7 (الكَوْثَر)',
        icon: '🧩',
        color: '#6C63D6',
        xp: 50,
        activities: [
          Activity(
            id: 'dest7-s3-act',
            type: ActivityType.ayahBuilder,
            title: 'Ayah Builder (Al-Kawthar)',
            icon: '🧩',
            xp: 50,
            ayahSession: ayahKawtharSession,
          ),
        ],
      ),
      Lesson(
        id: 'dest7-s4',
        title: 'The Good Deed Tree - Session 1',
        titleAr: 'شَجَرَةُ العَمَلِ الصَّالِح 1',
        icon: '🌳',
        color: '#5B9A1E',
        xp: 30,
        activities: [
          Activity(
            id: 'dest7-s4-act',
            type: ActivityType.goodDeedTree,
            title: 'The Good Deed Tree',
            icon: '🌳',
            xp: 30,
            deedTreeSession: GoodDeedTreeSession.rootsAndBranches,
          ),
        ],
      ),
      Lesson(
        id: 'dest7-s5',
        title: 'The Good Deed Tree - Session 2 (Final Synthesis)',
        titleAr: 'شَجَرَةُ العَمَلِ الصَّالِح 2 (المُلَخَّص النِّهَائِيّ)',
        icon: '🌟',
        color: '#2A7FCC',
        xp: 50,
        activities: [
          Activity(
            id: 'dest7-s5-act',
            type: ActivityType.goodDeedTree,
            title: 'The Good Deed Tree (Final Synthesis)',
            icon: '🌟',
            xp: 50,
            deedTreeSession: GoodDeedTreeSession.flowersAndFruits,
          ),
        ],
      ),
    ],
  ),
];
