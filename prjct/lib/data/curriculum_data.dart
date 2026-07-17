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

const List<FlashCard> numbersCards = [
  FlashCard(
    id: 'n1',
    emoji: '1️⃣',
    arabic: 'وَاحِد\n١',
    translit: 'Wahid',
    english: 'One',
    color: '#FDECC8',
  ),
  FlashCard(
    id: 'n2',
    emoji: '2️⃣',
    arabic: 'اِثْنَان\n٢',
    translit: 'Ithnan',
    english: 'Two',
    color: '#FDDCCC',
  ),
  FlashCard(
    id: 'n3',
    emoji: '3️⃣',
    arabic: 'ثَلَاثَة\n٣',
    translit: 'Thalatha',
    english: 'Three',
    color: '#DCF0E6',
  ),
  FlashCard(
    id: 'n4',
    emoji: '4️⃣',
    arabic: 'أَرْبَعَة\n٤',
    translit: 'Arba\'a',
    english: 'Four',
    color: '#E8E4FF',
  ),
  FlashCard(
    id: 'n5',
    emoji: '5️⃣',
    arabic: 'خَمْسَة\n٥',
    translit: 'Khamsa',
    english: 'Five',
    color: '#E8F4FF',
  ),
  FlashCard(
    id: 'n6',
    emoji: '6️⃣',
    arabic: 'سِتَّة\n٦',
    translit: 'Sitta',
    english: 'Six',
    color: '#FDECC8',
  ),
  FlashCard(
    id: 'n7',
    emoji: '7️⃣',
    arabic: 'سَبْعَة\n٧',
    translit: 'Sab\'a',
    english: 'Seven',
    color: '#FDDCCC',
  ),
  FlashCard(
    id: 'n8',
    emoji: '8️⃣',
    arabic: 'ثَمَانِيَة\n٨',
    translit: 'Thamaniya',
    english: 'Eight',
    color: '#DCF0E6',
  ),
  FlashCard(
    id: 'n9',
    emoji: '9️⃣',
    arabic: 'تِسْعَة\n٩',
    translit: 'Tis\'a',
    english: 'Nine',
    color: '#E8E4FF',
  ),
  FlashCard(
    id: 'n10',
    emoji: '🔟',
    arabic: 'عَشَرَة\n١٠',
    translit: '\'Ashara',
    english: 'Ten',
    color: '#E8F4FF',
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
// FULL CURRICULUM ARRAY
// ─────────────────────────────────────────────────────────────

const List<Destination> curriculum = [
  Destination(
    id: 1,
    name: 'Village of Salaam',
    nameAr: 'قَرْيَة السَّلَام',
    icon: '🏡',
    color: '#D85A30',
    bg: '#FDDCCC',
    mapX: 258,
    mapY: 1680,
    description:
        'Learn Arabic greetings, Islamic expressions, self-introduction, and daily du\'as.',
    state: DestinationState.completed,
    lessons: [
      Lesson(
        id: 'dest1-trace-1',
        title: 'Trace Practice 1',
        titleAr: 'تَتَبُّع الحُرُوف 1',
        icon: '✍️',
        color: '#0F6E56',
        xp: 20,
        activities: [
          Activity(
            id: 'dest1-trace-1',
            type: ActivityType.trace,
            title: 'Trace Practice 1',
            icon: '✍️',
            xp: 20,
            cards: [
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
            ],
          ),
        ],
      ),
      Lesson(
        id: 'dest1-trace-2',
        title: 'Trace Practice 2',
        titleAr: 'تَتَبُّع الحُرُوف 2',
        icon: '✍️',
        color: '#0F6E56',
        xp: 20,
        activities: [
          Activity(
            id: 'dest1-trace-2',
            type: ActivityType.trace,
            title: 'Trace Practice 2',
            icon: '✍️',
            xp: 20,
            cards: [
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
            ],
          ),
        ],
      ),
      Lesson(
        id: 'dest1-pronounce-1',
        title: 'Arabic Numbers Game 1',
        titleAr: 'لُعْبَة الأَرْقَام 1',
        icon: '🧺',
        color: '#EF9F27',
        xp: 20,
        activities: [
          Activity(
            id: 'dest1-pronounce-1',
            type: ActivityType.pronounce,
            title: 'Arabic Numbers 1',
            icon: '🧺',
            xp: 20,
            cards: numbersCards,
          ),
        ],
      ),
      Lesson(
        id: 'dest1-pronounce-2',
        title: 'Arabic Numbers Game 2',
        titleAr: 'لُعْبَة الأَرْقَام 2',
        icon: '🧺',
        color: '#EF9F27',
        xp: 20,
        activities: [
          Activity(
            id: 'dest1-pronounce-2',
            type: ActivityType.pronounce,
            title: 'Arabic Numbers 2',
            icon: '🧺',
            xp: 20,
            cards: numbersCards,
          ),
        ],
      ),
      Lesson(
        id: 'dest1-quranSync-1',
        title: 'Bismillahi (Daily Opener)',
        titleAr: 'بِسْمِ اللَّهِ',
        icon: '📖',
        color: '#6C63D6',
        xp: 25,
        activities: [
          Activity(
            id: 'dest1-quransync-1',
            type: ActivityType.quranSync,
            title: 'Daily Supplication',
            icon: '📖',
            xp: 25,
            quranLine: QuranSyncLine(
                id: 'dest1-quransync-1',
                arabicWords: ['بِسْمِ', 'اللَّهِ'],
                translitWords: ['Bismi', 'llahi'],
                wordTimestampsMs: [0, 1000],
                totalDurationMs: 2000,
                reference: 'A daily du’a opener',
              ),
          ),
        ],
      ),
      Lesson(
        id: 'dest1-quranSync-2',
        title: 'As-salamu alaykum (Greeting)',
        titleAr: 'السَّلَامُ عَلَيْكُمْ',
        icon: '📖',
        color: '#6C63D6',
        xp: 25,
        activities: [
          Activity(
            id: 'dest1-quransync-2',
            type: ActivityType.quranSync,
            title: 'Islamic Greeting',
            icon: '📖',
            xp: 25,
            quranLine: QuranSyncLine(
                id: 'dest1-quransync-2',
                arabicWords: ['السَّلَامُ', 'عَلَيْكُمْ'],
                translitWords: ['As-salamu', 'alaykum'],
                wordTimestampsMs: [0, 1000],
                totalDurationMs: 2000,
                reference: 'The greeting of peace',
              ),
          ),
        ],
      ),
      Lesson(
        id: 'dest1-story-1',
        title: 'Five Pillars Match 1',
        titleAr: 'أَرْكَانُ الْإِسْلَامِ 1',
        icon: '🕌',
        color: '#5B9A1E',
        xp: 30,
        activities: [
          Activity(
            id: 'dest1-story-1',
            type: ActivityType.story,
            title: 'Five Pillars Match 1',
            icon: '🕌',
            xp: 30,
            panels: storyNoor,
          ),
        ],
      ),
      Lesson(
        id: 'dest1-story-2',
        title: 'Five Pillars Match 2',
        titleAr: 'أَرْكَانُ الْإِسْلَامِ 2',
        icon: '🕌',
        color: '#5B9A1E',
        xp: 30,
        activities: [
          Activity(
            id: 'dest1-story-2',
            type: ActivityType.story,
            title: 'Five Pillars Match 2',
            icon: '🕌',
            xp: 30,
            panels: storyDuas,
          ),
        ],
      ),
      Lesson(
        id: 'dest1-fiqhDrag-1',
        title: 'Water Purity Sorter',
        titleAr: 'مُصَنِّف طَهَارَة المِيَاه',
        icon: '💧',
        color: '#D85A30',
        xp: 30,
        activities: [
          Activity(
            id: 'dest1-fiqh-1',
            type: ActivityType.fiqhDrag,
            title: 'Water Purity Sorter',
            icon: '💧',
            xp: 30,
            fiqhItems: [
              FiqhDragItem(id: 'w1', emoji: '🌧️', label: 'Rain Water', correctZoneId: 'bucketA'),
              FiqhDragItem(id: 'w2', emoji: '🌊', label: 'River Water', correctZoneId: 'bucketA'),
              FiqhDragItem(id: 'w3', emoji: '🤢', label: 'Dirty Water', correctZoneId: 'bucketB'),
              FiqhDragItem(id: 'w4', emoji: '🦠', label: 'Impure Water', correctZoneId: 'bucketB'),
            ],
            fiqhZones: [
              FiqhDropZone(id: 'bucketA', label: 'Clean Water (Mutahhir)', icon: '🪣'),
              FiqhDropZone(id: 'bucketB', label: 'Impure Water', icon: '🗑️'),
            ],
          ),
        ],
      ),
      Lesson(
        id: 'dest1-fiqhDrag-2',
        title: 'Fitrah Hygiene Match',
        titleAr: 'خِصَال الفِطْرَة وَالنَّظَافَة',
        icon: '🧼',
        color: '#D85A30',
        xp: 30,
        activities: [
          Activity(
            id: 'dest1-fiqh-2',
            type: ActivityType.fiqhDrag,
            title: 'Fitrah Hygiene Match',
            icon: '🧼',
            xp: 30,
            fiqhItems: [
              FiqhDragItem(id: 'h1', emoji: '🦷', label: 'Siwak', correctZoneId: 'mouth'),
              FiqhDragItem(id: 'h2', emoji: '💅', label: 'Nail Clipper', correctZoneId: 'nails'),
              FiqhDragItem(id: 'h3', emoji: '🪣', label: 'Lota Jug', correctZoneId: 'istinja'),
            ],
            fiqhZones: [
              FiqhDropZone(id: 'mouth', label: 'Mouth (Siwak)', icon: '👄'),
              FiqhDropZone(id: 'nails', label: 'Nails (Trimming)', icon: '🖐️'),
              FiqhDropZone(id: 'istinja', label: 'Istinja (Washing)', icon: '🚽'),
            ],
          ),
        ],
      ),
      Lesson(
        id: 'dest1-fiqhDrag-3',
        title: 'Wudhu Sequencer',
        titleAr: 'تَرْتِيب الوُضُوء',
        icon: '🚿',
        color: '#D85A30',
        xp: 35,
        activities: [
          Activity(
            id: 'dest1-fiqh-3',
            type: ActivityType.fiqhDrag,
            title: 'Wudhu Sequencer',
            icon: '🚿',
            xp: 35,
            fiqhItems: [
              FiqhDragItem(id: 'u1', emoji: '👐', label: 'Wash Hands', correctZoneId: '1'),
              FiqhDragItem(id: 'u2', emoji: '👄', label: 'Rinse Mouth', correctZoneId: '2'),
              FiqhDragItem(id: 'u3', emoji: '👤', label: 'Wash Face', correctZoneId: '3'),
              FiqhDragItem(id: 'u4', emoji: '💪', label: 'Wash Arms', correctZoneId: '4'),
              FiqhDragItem(id: 'u5', emoji: '🧕', label: 'Wipe Head', correctZoneId: '5'),
              FiqhDragItem(id: 'u6', emoji: '🦶', label: 'Wash Feet', correctZoneId: '6'),
            ],
            fiqhZones: [
              FiqhDropZone(id: 'slot0', label: 'Step 1'),
              FiqhDropZone(id: 'slot1', label: 'Step 2'),
              FiqhDropZone(id: 'slot2', label: 'Step 3'),
              FiqhDropZone(id: 'slot3', label: 'Step 4'),
              FiqhDropZone(id: 'slot4', label: 'Step 5'),
              FiqhDropZone(id: 'slot5', label: 'Step 6'),
            ],
          ),
        ],
      ),
    ],
  ),

  Destination(
    id: 2,
    name: 'Desert of Letters',
    nameAr: 'صَحْرَاء الحُرُوف',
    icon: 'ا',
    color: '#EF9F27',
    bg: '#FDECC8',
    mapX: 130,
    mapY: 1400,
    description: 'Learn all 28 Arabic letters and the short vowels (harakat).',
    state: DestinationState.current,
    lessons: [
      Lesson(
        id: 'dest2-trace-1',
        title: 'Trace Practice 1',
        titleAr: 'تَتَبُّع الحُرُوف 1',
        icon: '✍️',
        color: '#0F6E56',
        xp: 20,
        activities: [
          Activity(
            id: 'dest2-trace-1',
            type: ActivityType.trace,
            title: 'Trace Practice 1',
            icon: '✍️',
            xp: 20,
            cards: [
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
            ],
          ),
        ],
      ),
      Lesson(
        id: 'dest2-trace-2',
        title: 'Trace Practice 2',
        titleAr: 'تَتَبُّع الحُرُوف 2',
        icon: '✍️',
        color: '#0F6E56',
        xp: 20,
        activities: [
          Activity(
            id: 'dest2-trace-2',
            type: ActivityType.trace,
            title: 'Trace Practice 2',
            icon: '✍️',
            xp: 20,
            cards: [
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
            ],
          ),
        ],
      ),
      Lesson(
        id: 'dest2-pronounce-1',
        title: 'Arabic Numbers Game 1',
        titleAr: 'لُعْبَة الأَرْقَام 1',
        icon: '🧺',
        color: '#EF9F27',
        xp: 20,
        activities: [
          Activity(
            id: 'dest2-pronounce-1',
            type: ActivityType.pronounce,
            title: 'Arabic Numbers 1',
            icon: '🧺',
            xp: 20,
            cards: numbersCards,
          ),
        ],
      ),
      Lesson(
        id: 'dest2-pronounce-2',
        title: 'Arabic Numbers Game 2',
        titleAr: 'لُعْبَة الأَرْقَام 2',
        icon: '🧺',
        color: '#EF9F27',
        xp: 20,
        activities: [
          Activity(
            id: 'dest2-pronounce-2',
            type: ActivityType.pronounce,
            title: 'Arabic Numbers 2',
            icon: '🧺',
            xp: 20,
            cards: numbersCards,
          ),
        ],
      ),
      Lesson(
        id: 'dest2-harakatPop-1',
        title: 'Harakat Pop Game 1',
        titleAr: 'لُعْبَة الحَرَكَات 1',
        icon: '🎈',
        color: '#D85A30',
        xp: 30,
        activities: [
          Activity(
            id: 'dest2-harakatPop-1',
            type: ActivityType.harakatPop,
            title: 'Harakat Pop 1',
            icon: '🎈',
            xp: 30,
            cards: [
              FlashCard(id: 'hp1', arabic: 'ب', translit: 'Ba', english: 'Fathah', emoji: '🎈', color: '#FDECC8'),
              FlashCard(id: 'hp2', arabic: 'ب', translit: 'Bi', english: 'Kasrah', emoji: '🎈', color: '#E8F4FF'),
              FlashCard(id: 'hp3', arabic: 'ب', translit: 'Bu', english: 'Dammah', emoji: '🎈', color: '#E8E4FF'),
              FlashCard(id: 'hp4', arabic: 'ت', translit: 'Ta', english: 'Fathah', emoji: '🎈', color: '#FDECC8'),
              FlashCard(id: 'hp5', arabic: 'ت', translit: 'Ti', english: 'Kasrah', emoji: '🎈', color: '#E8F4FF'),
              FlashCard(id: 'hp6', arabic: 'ت', translit: 'Tu', english: 'Dammah', emoji: '🎈', color: '#E8E4FF'),
            ],
          ),
        ],
      ),
      Lesson(
        id: 'dest2-harakatPop-2',
        title: 'Harakat Pop Game 2',
        titleAr: 'لُعْبَة الحَرَكَات 2',
        icon: '🎈',
        color: '#D85A30',
        xp: 30,
        activities: [
          Activity(
            id: 'dest2-harakatPop-2',
            type: ActivityType.harakatPop,
            title: 'Harakat Pop 2',
            icon: '🎈',
            xp: 30,
            cards: [
              FlashCard(id: 'hp7', arabic: 'ج', translit: 'Ja', english: 'Fathah', emoji: '🎈', color: '#FDECC8'),
              FlashCard(id: 'hp8', arabic: 'ج', translit: 'Ji', english: 'Kasrah', emoji: '🎈', color: '#E8F4FF'),
              FlashCard(id: 'hp9', arabic: 'ج', translit: 'Ju', english: 'Dammah', emoji: '🎈', color: '#E8E4FF'),
              FlashCard(id: 'hp10', arabic: 'س', translit: 'Sa', english: 'Fathah', emoji: '🎈', color: '#FDECC8'),
              FlashCard(id: 'hp11', arabic: 'س', translit: 'Si', english: 'Kasrah', emoji: '🎈', color: '#E8F4FF'),
              FlashCard(id: 'hp12', arabic: 'س', translit: 'Su', english: 'Dammah', emoji: '🎈', color: '#E8E4FF'),
            ],
          ),
        ],
      ),
      Lesson(
        id: 'dest2-quranSync-1',
        title: 'Isti\'adhah (A\'oodhu billahi)',
        titleAr: 'الِاسْتِعَاذَة',
        icon: '📖',
        color: '#6C63D6',
        xp: 25,
        activities: [
          Activity(
            id: 'dest2-quransync-1',
            type: ActivityType.quranSync,
            title: 'Qur\'an Oral Prerequisite',
            icon: '📖',
            xp: 25,
            quranLine: QuranSyncLine(
                id: 'dest2-quransync-1',
                arabicWords: ['أَعُوذُ', 'بِاللّٰهِ', 'مِنَ', 'الشَّيْطَانِ', 'الرَّجِيمِ'],
                translitWords: ["A'oodhu billahi", "minash-shaytanir", "rajeem"],
                wordTimestampsMs: [0, 1000, 2000],
                totalDurationMs: 3000,
                reference: 'Quran Prerequisite: Isti\'adhah',
              ),
          ),
        ],
      ),
      Lesson(
        id: 'dest2-quranSync-2',
        title: 'Basmalah (Bismillah)',
        titleAr: 'الْبَسْمَلَة',
        icon: '📖',
        color: '#6C63D6',
        xp: 25,
        activities: [
          Activity(
            id: 'dest2-quransync-2',
            type: ActivityType.quranSync,
            title: 'Qur\'an Oral Prerequisite',
            icon: '📖',
            xp: 25,
            quranLine: QuranSyncLine(
                id: 'dest2-quransync-2',
                arabicWords: ['بِسْمِ', 'اللّٰهِ', 'الرَّحْمٰنِ', 'الرَّحِيمِ'],
                translitWords: ["Bismillahir", "Rahmanir", "Raheem"],
                wordTimestampsMs: [0, 1000, 2000],
                totalDurationMs: 3000,
                reference: 'Quran Prerequisite: Basmalah',
              ),
          ),
        ],
      ),
      Lesson(
        id: 'dest2-story-1',
        title: 'Five Pillars Match 1',
        titleAr: 'أَرْكَانُ الْإِسْلَامِ 1',
        icon: '🕌',
        color: '#5B9A1E',
        xp: 40,
        activities: [
          Activity(
            id: 'dest2-story-1',
            type: ActivityType.story,
            title: 'Five Pillars Match 1',
            icon: '🕌',
            xp: 40,
            panels: [
              StoryPanel(
                id: 'sl1',
                bg: 'linear-gradient(160deg, #F5D9A0 0%, #EDD080 100%)',
                scene: [],
                caption: 'Pillars Match level 1',
              ),
            ],
          ),
        ],
      ),
      Lesson(
        id: 'dest2-story-2',
        title: 'Five Pillars Match 2',
        titleAr: 'أَرْكَانُ الْإِسْلَامِ 2',
        icon: '🕌',
        color: '#5B9A1E',
        xp: 40,
        activities: [
          Activity(
            id: 'dest2-story-2',
            type: ActivityType.story,
            title: 'Five Pillars Match 2',
            icon: '🕌',
            xp: 40,
            panels: [
              StoryPanel(
                id: 'sl3',
                bg: 'linear-gradient(160deg, #DCF0E6 0%, #A8D8EA 100%)',
                scene: [],
                caption: 'Pillars Match level 2',
              ),
              StoryPanel(
                id: 'sl4',
                bg: 'linear-gradient(160deg, #0F6E56 0%, #5B9A1E 100%)',
                scene: [],
                caption: 'Pillars Match level 2 panel 2',
              ),
            ],
          ),
        ],
      ),
      Lesson(
        id: 'dest2-fiqhDrag-1',
        title: 'Fiqh Sort & Match 1',
        titleAr: 'الفِقْه: رَتِّب وطَابِق 1',
        icon: '🧩',
        color: '#D85A30',
        xp: 30,
        activities: [
          Activity(
            id: 'dest2-fiqh-1',
            type: ActivityType.fiqhDrag,
            title: 'Fiqh Sort & Match 1',
            icon: '🧩',
            xp: 30,
            fiqhItems: [
            FiqhDragItem(id: 'lm1', emoji: '📝', label: 'ب', correctZoneId: 'lm1'),
            FiqhDragItem(id: 'lm2', emoji: '📝', label: 'ج', correctZoneId: 'lm2'),
            FiqhDragItem(id: 'lm3', emoji: '📝', label: 'ر', correctZoneId: 'lm3'),
            FiqhDragItem(id: 'lm4', emoji: '📝', label: 'س', correctZoneId: 'lm4'),
            FiqhDragItem(id: 'lm5', emoji: '📝', label: 'ز', correctZoneId: 'lm5'),
            ],
            fiqhZones: [
            FiqhDropZone(id: 'lm1', label: 'Ball / بَيْت', icon: '🏠'),
            FiqhDropZone(id: 'lm2', label: 'Camel / جَمَل', icon: '🐪'),
            FiqhDropZone(id: 'lm3', label: 'Thunder / رَعْد', icon: '⚡'),
            FiqhDropZone(id: 'lm4', label: 'Fish / سَمَكَة', icon: '🐟'),
            FiqhDropZone(id: 'lm5', label: 'Flower / زَهْرَة', icon: '🌺'),
            ],
          ),
        ],
      ),
      Lesson(
        id: 'dest2-fiqhDrag-2',
        title: 'Fiqh Sort & Match 2',
        titleAr: 'الفِقْه: رَتِّب وطَابِق 2',
        icon: '🧩',
        color: '#D85A30',
        xp: 30,
        activities: [
          Activity(
            id: 'dest2-fiqh-2',
            type: ActivityType.fiqhDrag,
            title: 'Fiqh Sort & Match 2',
            icon: '🧩',
            xp: 30,
            fiqhItems: [
            FiqhDragItem(id: 'lm6', emoji: '📝', label: 'ن', correctZoneId: 'lm6'),
            FiqhDragItem(id: 'lm7', emoji: '📝', label: 'م', correctZoneId: 'lm7'),
            FiqhDragItem(id: 'lm8', emoji: '📝', label: 'ك', correctZoneId: 'lm8'),
            FiqhDragItem(id: 'lm9', emoji: '📝', label: 'ف', correctZoneId: 'lm9'),
            FiqhDragItem(id: 'lm10', emoji: '📝', label: 'ي', correctZoneId: 'lm10'),
            ],
            fiqhZones: [
            FiqhDropZone(id: 'lm6', label: 'Star / نَجْم', icon: '⭐'),
            FiqhDropZone(id: 'lm7', label: 'Mosque / مَسْجِد', icon: '🕌'),
            FiqhDropZone(id: 'lm8', label: 'Book / كِتَاب', icon: '📖'),
            FiqhDropZone(id: 'lm9', label: 'Butterfly / فَرَاشَة', icon: '🦋'),
            FiqhDropZone(id: 'lm10', label: 'Hand / يَد', icon: '🤲'),
            ],
          ),
        ],
      ),
    ],
  ),

  Destination(
    id: 3,
    name: 'Garden of Words',
    nameAr: 'حَدِيقَة الكَلِمَات',
    icon: '🌸',
    color: '#5B9A1E',
    bg: '#DCEDC8',
    mapX: 268,
    mapY: 1110,
    description:
        'Discover Arabic vocabulary -- body parts, colors, numbers, animals, family and more!',
    state: DestinationState.locked,
    lessons: [
      Lesson(
        id: 'dest3-trace-1',
        title: 'Trace Practice 1',
        titleAr: 'تَتَبُّع الحُرُوف 1',
        icon: '✍️',
        color: '#0F6E56',
        xp: 20,
        activities: [
          Activity(
            id: 'dest3-trace-1',
            type: ActivityType.trace,
            title: 'Trace Practice 1',
            icon: '✍️',
            xp: 20,
            cards: [
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
            ],
          ),
        ],
      ),
      Lesson(
        id: 'dest3-trace-2',
        title: 'Trace Practice 2',
        titleAr: 'تَتَبُّع الحُرُوف 2',
        icon: '✍️',
        color: '#0F6E56',
        xp: 20,
        activities: [
          Activity(
            id: 'dest3-trace-2',
            type: ActivityType.trace,
            title: 'Trace Practice 2',
            icon: '✍️',
            xp: 20,
            cards: [
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
            ],
          ),
        ],
      ),
      Lesson(
        id: 'dest3-pronounce-1',
        title: 'Arabic Numbers Game 1',
        titleAr: 'لُعْبَة الأَرْقَام 1',
        icon: '🧺',
        color: '#EF9F27',
        xp: 20,
        activities: [
          Activity(
            id: 'dest3-pronounce-1',
            type: ActivityType.pronounce,
            title: 'Arabic Numbers 1',
            icon: '🧺',
            xp: 20,
            cards: numbersCards,
          ),
        ],
      ),
      Lesson(
        id: 'dest3-pronounce-2',
        title: 'Arabic Numbers Game 2',
        titleAr: 'لُعْبَة الأَرْقَام 2',
        icon: '🧺',
        color: '#EF9F27',
        xp: 20,
        activities: [
          Activity(
            id: 'dest3-pronounce-2',
            type: ActivityType.pronounce,
            title: 'Arabic Numbers 2',
            icon: '🧺',
            xp: 20,
            cards: numbersCards,
          ),
        ],
      ),
      Lesson(
        id: 'dest3-pronounce-3',
        title: 'Arabic Numbers Game 3',
        titleAr: 'لُعْبَة الأَرْقَام 3',
        icon: '🧺',
        color: '#EF9F27',
        xp: 30,
        activities: [
          Activity(
            id: 'dest3-pronounce-3',
            type: ActivityType.pronounce,
            title: 'Arabic Numbers',
            icon: '🧺',
            xp: 30,
            cards: numbersCards,
          ),
        ],
      ),
      Lesson(
        id: 'dest3-quranSync-1',
        title: 'Waking Up Du\'a',
        titleAr: 'دُعَاء الِاسْتِيقَاظ',
        icon: '📖',
        color: '#6C63D6',
        xp: 25,
        activities: [
          Activity(
            id: 'dest3-quransync-1',
            type: ActivityType.quranSync,
            title: 'Daily Supplication',
            icon: '📖',
            xp: 25,
            quranLine: QuranSyncLine(
                id: 'dest3-quransync-1',
                arabicWords: ['الْحَمْدُ', 'لِلّٰهِ', 'الَّذِي', 'أَحْيَانَا', 'بَعْدَ', 'مَا', 'أَمَاتَنَا', 'وَإِلَيْهِ', 'النُّشُورُ'],
                translitWords: ["Alhamdu lillahil-ladhi", "ahyana ba'da", "ma amatana", "wa ilayhin-nushur"],
                wordTimestampsMs: [0, 1000, 2000, 3000],
                totalDurationMs: 4000,
                reference: 'Daily Supplication: Waking Up',
              ),
          ),
        ],
      ),
      Lesson(
        id: 'dest3-quranSync-2',
        title: 'Sleeping Du\'a',
        titleAr: 'دُعَاء النَّوْم',
        icon: '📖',
        color: '#6C63D6',
        xp: 25,
        activities: [
          Activity(
            id: 'dest3-quransync-2',
            type: ActivityType.quranSync,
            title: 'Daily Supplication',
            icon: '📖',
            xp: 25,
            quranLine: QuranSyncLine(
                id: 'dest3-quransync-2',
                arabicWords: ['بِاسْمِكَ', 'اللّٰهُمَّ', 'أَمُوتُ', 'وَأَحْيَا'],
                translitWords: ["Bismika", "Allahumma", "amutu", "wa ahya"],
                wordTimestampsMs: [0, 1000, 2000, 3000],
                totalDurationMs: 4000,
                reference: 'Daily Supplication: Sleeping',
              ),
          ),
        ],
      ),
      Lesson(
        id: 'dest3-story-1',
        title: 'Five Pillars Match 1',
        titleAr: 'أَرْكَانُ الْإِسْلَامِ 1',
        icon: '🕌',
        color: '#5B9A1E',
        xp: 30,
        activities: [
          Activity(
            id: 'dest3-story-1',
            type: ActivityType.story,
            title: 'Five Pillars Match 1',
            icon: '🕌',
            xp: 30,
            panels: [
              StoryPanel(
                id: 'dest3-story-1-p0',
                bg: '#E8F4FF',
                scene: [],
                caption: 'Pillars Match level 1',
              ),
            ],
          ),
        ],
      ),
      Lesson(
        id: 'dest3-story-2',
        title: 'Five Pillars Match 2',
        titleAr: 'أَرْكَانُ الْإِسْلَامِ 2',
        icon: '🕌',
        color: '#5B9A1E',
        xp: 30,
        activities: [
          Activity(
            id: 'dest3-story-2',
            type: ActivityType.story,
            title: 'Five Pillars Match 2',
            icon: '🕌',
            xp: 30,
            panels: [
              StoryPanel(
                id: 'dest3-story-2-p0',
                bg: '#FBE3BC',
                scene: [],
                caption: 'Pillars Match level 2',
              ),
              StoryPanel(
                id: 'dest3-story-2-p1',
                bg: '#F7E0D6',
                scene: [],
                caption: 'Pillars Match level 2 panel 2',
              ),
            ],
          ),
        ],
      ),
      Lesson(
        id: 'dest3-fiqhDrag-1',
        title: 'Fiqh Sort & Match 1',
        titleAr: 'الفِقْه: رَتِّب وطَابِق 1',
        icon: '🧩',
        color: '#D85A30',
        xp: 30,
        activities: [
          Activity(
            id: 'dest3-fiqh-1',
            type: ActivityType.fiqhDrag,
            title: 'Fiqh Sort & Match 1',
            icon: '🧩',
            xp: 30,
            fiqhItems: [
            FiqhDragItem(id: 'bpm1', emoji: '👤', label: 'رَأْس', correctZoneId: 'bpm1'),
            FiqhDragItem(id: 'bpm2', emoji: '👀', label: 'عَيْن', correctZoneId: 'bpm2'),
            FiqhDragItem(id: 'bpm3', emoji: '✋', label: 'يَد', correctZoneId: 'bpm3'),
            FiqhDragItem(id: 'bpm4', emoji: '🦶', label: 'رِجْل', correctZoneId: 'bpm4'),
            FiqhDragItem(id: 'bpm5', emoji: '❤️', label: 'قَلْب', correctZoneId: 'bpm5'),
            ],
            fiqhZones: [
            FiqhDropZone(id: 'bpm1', label: 'Head', icon: '🙂'),
            FiqhDropZone(id: 'bpm2', label: 'Eye', icon: '👁️'),
            FiqhDropZone(id: 'bpm3', label: 'Hand', icon: '🖐️'),
            FiqhDropZone(id: 'bpm4', label: 'Foot', icon: '👟'),
            FiqhDropZone(id: 'bpm5', label: 'Heart', icon: '💓'),
            ],
          ),
        ],
      ),
      Lesson(
        id: 'dest3-fiqhDrag-2',
        title: 'Fiqh Sort & Match 2',
        titleAr: 'الفِقْه: رَتِّب وطَابِق 2',
        icon: '🧩',
        color: '#D85A30',
        xp: 30,
        activities: [
          Activity(
            id: 'dest3-fiqh-2',
            type: ActivityType.fiqhDrag,
            title: 'Fiqh Sort & Match 2',
            icon: '🧩',
            xp: 30,
            fiqhItems: [
            FiqhDragItem(id: 'cm1', emoji: '📝', label: 'أَحْمَر', correctZoneId: 'cm1'),
            FiqhDragItem(id: 'cm2', emoji: '📝', label: 'أَزْرَق', correctZoneId: 'cm2'),
            FiqhDragItem(id: 'cm3', emoji: '📝', label: 'أَصْفَر', correctZoneId: 'cm3'),
            FiqhDragItem(id: 'cm4', emoji: '📝', label: 'أَخْضَر', correctZoneId: 'cm4'),
            FiqhDragItem(id: 'cm5', emoji: '📝', label: 'أَبْيَض', correctZoneId: 'cm5'),
            ],
            fiqhZones: [
            FiqhDropZone(id: 'cm1', label: 'Red', icon: '🔴'),
            FiqhDropZone(id: 'cm2', label: 'Blue', icon: '🔵'),
            FiqhDropZone(id: 'cm3', label: 'Yellow', icon: '🟡'),
            FiqhDropZone(id: 'cm4', label: 'Green', icon: '🟢'),
            FiqhDropZone(id: 'cm5', label: 'White', icon: '⚪'),
            ],
          ),
        ],
      ),
    ],
  ),

  Destination(
    id: 4,
    name: 'River of Sirah',
    nameAr: 'نَهْر السِّيرَة',
    icon: '🌙',
    color: '#2A7FCC',
    bg: '#E8F4FF',
    mapX: 120,
    mapY: 840,
    description:
        'Learn the life of Prophet Muhammad ﷺ and practice daily supplications from Hadith.',
    state: DestinationState.locked,
    lessons: [
      Lesson(
        id: 'dest4-trace-1',
        title: 'Trace Practice 1',
        titleAr: 'تَتَبُّع الحُرُوف 1',
        icon: '✍️',
        color: '#0F6E56',
        xp: 20,
        activities: [
          Activity(
            id: 'dest4-trace-1',
            type: ActivityType.trace,
            title: 'Trace Practice 1',
            icon: '✍️',
            xp: 20,
            cards: [
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
            ],
          ),
        ],
      ),
      Lesson(
        id: 'dest4-trace-2',
        title: 'Trace Practice 2',
        titleAr: 'تَتَبُّع الحُرُوف 2',
        icon: '✍️',
        color: '#0F6E56',
        xp: 20,
        activities: [
          Activity(
            id: 'dest4-trace-2',
            type: ActivityType.trace,
            title: 'Trace Practice 2',
            icon: '✍️',
            xp: 20,
            cards: [
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
            ],
          ),
        ],
      ),
      Lesson(
        id: 'dest4-pronounce-1',
        title: 'Arabic Numbers Game 1',
        titleAr: 'لُعْبَة الأَرْقَام 1',
        icon: '🧺',
        color: '#EF9F27',
        xp: 20,
        activities: [
          Activity(
            id: 'dest4-pronounce-1',
            type: ActivityType.pronounce,
            title: 'Arabic Numbers 1',
            icon: '🧺',
            xp: 20,
            cards: numbersCards,
          ),
        ],
      ),
      Lesson(
        id: 'dest4-pronounce-2',
        title: 'Arabic Numbers Game 2',
        titleAr: 'لُعْبَة الأَرْقَام 2',
        icon: '🧺',
        color: '#EF9F27',
        xp: 20,
        activities: [
          Activity(
            id: 'dest4-pronounce-2',
            type: ActivityType.pronounce,
            title: 'Arabic Numbers 2',
            icon: '🧺',
            xp: 20,
            cards: numbersCards,
          ),
        ],
      ),
      Lesson(
        id: 'dest4-quranSync-1',
        title: 'Meal Beginning Du\'a',
        titleAr: 'دُعَاء قَبْلَ الطَّعَام',
        icon: '📖',
        color: '#6C63D6',
        xp: 25,
        activities: [
          Activity(
            id: 'dest4-quransync-1',
            type: ActivityType.quranSync,
            title: 'Daily Supplication',
            icon: '📖',
            xp: 25,
            quranLine: QuranSyncLine(
                id: 'dest4-quransync-1',
                arabicWords: ['بِسْمِ', 'اللّٰهِ', 'وَعَلَىٰ', 'بَرَكَةِ', 'اللّٰهِ'],
                translitWords: ["Bismillah", "wa 'ala", "barakatillah"],
                wordTimestampsMs: [0, 1000, 2000],
                totalDurationMs: 3000,
                reference: 'Daily Supplication: Meal Beginning',
              ),
          ),
        ],
      ),
      Lesson(
        id: 'dest4-quranSync-2',
        title: 'Meal Ending Du\'a',
        titleAr: 'دُعَاء بَعْدَ الطَّعَام',
        icon: '📖',
        color: '#6C63D6',
        xp: 25,
        activities: [
          Activity(
            id: 'dest4-quransync-2',
            type: ActivityType.quranSync,
            title: 'Daily Supplication',
            icon: '📖',
            xp: 25,
            quranLine: QuranSyncLine(
                id: 'dest4-quransync-2',
                arabicWords: ['الْحَمْدُ', 'لِلّٰهِ', 'الَّذِي', 'أَطْعَمَنَا', 'وَسَقَانَا'],
                translitWords: ["Alhamdu lillahil-ladhi", "at'amana", "wa saqana"],
                wordTimestampsMs: [0, 1000, 2000],
                totalDurationMs: 3000,
                reference: 'Daily Supplication: Meal Ending',
              ),
          ),
        ],
      ),
      Lesson(
        id: 'dest4-story-1',
        title: 'Five Pillars Match 1',
        titleAr: 'أَرْكَانُ الْإِسْلَامِ 1',
        icon: '🕌',
        color: '#5B9A1E',
        xp: 20,
        activities: [
          Activity(
            id: 'dest4-story-1',
            type: ActivityType.story,
            title: 'Five Pillars Match 1',
            icon: '🕌',
            xp: 20,
            panels: storyProphet,
          ),
        ],
      ),
      Lesson(
        id: 'dest4-story-2',
        title: 'Five Pillars Match 2',
        titleAr: 'أَرْكَانُ الْإِسْلَامِ 2',
        icon: '🕌',
        color: '#5B9A1E',
        xp: 30,
        activities: [
          Activity(
            id: 'dest4-story-2',
            type: ActivityType.story,
            title: 'Five Pillars Match 2',
            icon: '🕌',
            xp: 30,
            panels: storyDuas,
          ),
        ],
      ),
      Lesson(
        id: 'dest4-fiqhDrag-1',
        title: 'Fiqh Sort & Match 1',
        titleAr: 'الفِقْه: رَتِّب وطَابِق 1',
        icon: '🧩',
        color: '#D85A30',
        xp: 30,
        activities: [
          Activity(
            id: 'dest4-fiqh-1',
            type: ActivityType.fiqhDrag,
            title: 'Fiqh Sort & Match 1',
            icon: '🧩',
            xp: 30,
            fiqhItems: [
            FiqhDragItem(id: 'srm1', emoji: '🌟', label: 'مُحَمَّد', correctZoneId: 'srm1'),
            FiqhDragItem(id: 'srm2', emoji: '✅', label: 'الأَمِين', correctZoneId: 'srm2'),
            FiqhDragItem(id: 'srm3', emoji: '👩🏽', label: 'آمِنَة', correctZoneId: 'srm3'),
            FiqhDragItem(id: 'srm4', emoji: '🤱🏽', label: 'حَلِيمَة', correctZoneId: 'srm4'),
            FiqhDragItem(id: 'srm5', emoji: '🕌', label: 'مَكَّة', correctZoneId: 'srm5'),
            ],
            fiqhZones: [
            FiqhDropZone(id: 'srm1', label: 'The Praised One', icon: '✨'),
            FiqhDropZone(id: 'srm2', label: 'The Trustworthy', icon: '🤝'),
            FiqhDropZone(id: 'srm3', label: 'His mother\'s name', icon: '❤️'),
            FiqhDropZone(id: 'srm4', label: 'His nurse from the desert', icon: '🌾'),
            FiqhDropZone(id: 'srm5', label: 'His birthplace', icon: '🌍'),
            ],
          ),
        ],
      ),
      Lesson(
        id: 'dest4-fiqhDrag-2',
        title: 'Fiqh Sort & Match 2',
        titleAr: 'الفِقْه: رَتِّب وطَابِق 2',
        icon: '🧩',
        color: '#D85A30',
        xp: 15,
        activities: [
          Activity(
            id: 'dest4-fiqh-2',
            type: ActivityType.fiqhDrag,
            title: 'Fiqh Sort & Match 2',
            icon: '🧩',
            xp: 15,
            fiqhItems: [
            FiqhDragItem(id: 'mn1', emoji: '🤝', label: 'Saying Salaam first when meeting', labelAr: 'قُل السلام أوّلاً', correctZoneId: 'bucketA'),
            FiqhDragItem(id: 'mn2', emoji: '🙋', label: 'Helping a friend who fell down', labelAr: 'ساعد صديقك إذا سقط', correctZoneId: 'bucketA'),
            FiqhDragItem(id: 'mn3', emoji: '🍽️', label: 'Saying Bismillah before eating', labelAr: 'قل بسم اللّٰه قبل الأكل', correctZoneId: 'bucketA'),
            FiqhDragItem(id: 'mn4', emoji: '👂', label: 'Listening when teacher speaks', labelAr: 'اسمع حين يتكلّم المعلّم', correctZoneId: 'bucketA'),
            FiqhDragItem(id: 'mn5', emoji: '🌱', label: 'Picking up litter from the ground', labelAr: 'التقط القمامة من الأرض', correctZoneId: 'bucketA'),
            FiqhDragItem(id: 'mn6', emoji: '🗣️', label: 'Interrupting when someone talks', labelAr: 'اقطع كلام شخص آخر', correctZoneId: 'bucketB'),
            ],
            fiqhZones: [
            FiqhDropZone(id: 'bucketA', label: 'Good Manner ✓', icon: '✅'),
            FiqhDropZone(id: 'bucketB', label: 'Bad Manner ✗', icon: '❌'),
            ],
          ),
        ],
      ),
    ],
  ),

  Destination(
    id: 5,
    name: 'Masjid of Salah',
    nameAr: 'مَسْجِد الصَّلَاة',
    icon: '🕌',
    color: '#0F6E56',
    bg: '#DCF0E6',
    mapX: 268,
    mapY: 570,
    description:
        'Learn Taharah (purification), Wudu, the Adhan and the 5 daily prayers.',
    state: DestinationState.locked,
    lessons: [
      Lesson(
        id: 'dest5-trace-1',
        title: 'Trace Practice 1',
        titleAr: 'تَتَبُّع الحُرُوف 1',
        icon: '✍️',
        color: '#0F6E56',
        xp: 20,
        activities: [
          Activity(
            id: 'dest5-trace-1',
            type: ActivityType.trace,
            title: 'Trace Practice 1',
            icon: '✍️',
            xp: 20,
            cards: [
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
            ],
          ),
        ],
      ),
      Lesson(
        id: 'dest5-trace-2',
        title: 'Trace Practice 2',
        titleAr: 'تَتَبُّع الحُرُوف 2',
        icon: '✍️',
        color: '#0F6E56',
        xp: 20,
        activities: [
          Activity(
            id: 'dest5-trace-2',
            type: ActivityType.trace,
            title: 'Trace Practice 2',
            icon: '✍️',
            xp: 20,
            cards: [
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
            ],
          ),
        ],
      ),
      Lesson(
        id: 'dest5-pronounce-1',
        title: 'Arabic Numbers Game 1',
        titleAr: 'لُعْبَة الأَرْقَام 1',
        icon: '🧺',
        color: '#EF9F27',
        xp: 20,
        activities: [
          Activity(
            id: 'dest5-pronounce-1',
            type: ActivityType.pronounce,
            title: 'Arabic Numbers 1',
            icon: '🧺',
            xp: 20,
            cards: numbersCards,
          ),
        ],
      ),
      Lesson(
        id: 'dest5-pronounce-2',
        title: 'Arabic Numbers Game 2',
        titleAr: 'لُعْبَة الأَرْقَام 2',
        icon: '🧺',
        color: '#EF9F27',
        xp: 20,
        activities: [
          Activity(
            id: 'dest5-pronounce-2',
            type: ActivityType.pronounce,
            title: 'Arabic Numbers 2',
            icon: '🧺',
            xp: 20,
            cards: numbersCards,
          ),
        ],
      ),
      Lesson(
        id: 'dest5-quranSync-1',
        title: 'Entering Comfort Room Du\'a',
        titleAr: 'دُعَاء دُخُولِ الخَلَاءِ',
        icon: '📖',
        color: '#6C63D6',
        xp: 25,
        activities: [
          Activity(
            id: 'dest5-quransync-1',
            type: ActivityType.quranSync,
            title: 'Daily Supplication',
            icon: '📖',
            xp: 25,
            quranLine: QuranSyncLine(
                id: 'dest5-quransync-1',
                arabicWords: ['اللّٰهُمَّ', 'إِنِّي', 'أَعُوذُ', 'بِكَ', 'مِنَ', 'الْخُبُثِ', 'وَالْخَبَائِثِ'],
                translitWords: ["Allahumma inni", "a'oodhu bika", "minal-khubuthi", "wal-khaba'ith"],
                wordTimestampsMs: [0, 1000, 2000, 3000],
                totalDurationMs: 4000,
                reference: 'Daily Supplication: Toilet Enter',
              ),
          ),
        ],
      ),
      Lesson(
        id: 'dest5-quranSync-2',
        title: 'Leaving Comfort Room Du\'a',
        titleAr: 'دُعَاء خُرُوجِ الخَلَاءِ',
        icon: '📖',
        color: '#6C63D6',
        xp: 25,
        activities: [
          Activity(
            id: 'dest5-quransync-2',
            type: ActivityType.quranSync,
            title: 'Daily Supplication',
            icon: '📖',
            xp: 25,
            quranLine: QuranSyncLine(
                id: 'dest5-quransync-2',
                arabicWords: ['غُفْرَانَكَ'],
                translitWords: ["Ghufranak"],
                wordTimestampsMs: [0],
                totalDurationMs: 1500,
                reference: 'Daily Supplication: Toilet Leave',
              ),
          ),
        ],
      ),
      Lesson(
        id: 'dest5-story-1',
        title: 'Five Pillars Match 1',
        titleAr: 'أَرْكَانُ الْإِسْلَامِ 1',
        icon: '🕌',
        color: '#5B9A1E',
        xp: 30,
        activities: [
          Activity(
            id: 'dest5-story-1',
            type: ActivityType.story,
            title: 'Five Pillars Match 1',
            icon: '🕌',
            xp: 30,
            panels: [
              StoryPanel(
                id: 'wu1',
                bg: 'linear-gradient(160deg, #DCF0E6 0%, #A8D8EA 100%)',
                scene: [],
                caption: 'Pillars Match level 1',
              ),
            ],
          ),
        ],
      ),
      Lesson(
        id: 'dest5-story-2',
        title: 'Five Pillars Match 2',
        titleAr: 'أَرْكَانُ الْإِسْلَامِ 2',
        icon: '🕌',
        color: '#5B9A1E',
        xp: 30,
        activities: [
          Activity(
            id: 'dest5-story-2',
            type: ActivityType.story,
            title: 'Five Pillars Match 2',
            icon: '🕌',
            xp: 30,
            panels: [
              StoryPanel(
                id: 'wu3',
                bg: 'linear-gradient(160deg, #E8F4FF 0%, #DCF0E6 100%)',
                scene: [],
                caption: 'Pillars Match level 2',
              ),
              StoryPanel(
                id: 'wu4',
                bg: 'linear-gradient(160deg, #FDECC8 0%, #DCF0E6 100%)',
                scene: [],
                caption: 'Pillars Match level 2 panel 2',
              ),
            ],
          ),
        ],
      ),
      Lesson(
        id: 'dest5-fiqhDrag-1',
        title: 'Fiqh Sort & Match 1',
        titleAr: 'الفِقْه: رَتِّب وطَابِق 1',
        icon: '🧩',
        color: '#D85A30',
        xp: 30,
        activities: [
          Activity(
            id: 'dest5-fiqh-1',
            type: ActivityType.fiqhDrag,
            title: 'Fiqh Sort & Match 1',
            icon: '🧩',
            xp: 30,
            fiqhItems: [
            FiqhDragItem(id: 'ws1', emoji: '🌧️', label: 'Rain water', labelAr: 'مَاء المَطَر', correctZoneId: 'bucketA'),
            FiqhDragItem(id: 'ws2', emoji: '🌊', label: 'River water', labelAr: 'مَاء النَّهْر', correctZoneId: 'bucketA'),
            FiqhDragItem(id: 'ws3', emoji: '🏔️', label: 'Mountain spring water', labelAr: 'مَاء اليَنْبُوع', correctZoneId: 'bucketA'),
            FiqhDragItem(id: 'ws4', emoji: '🌀', label: 'Well water', labelAr: 'مَاء البِئْر', correctZoneId: 'bucketA'),
            FiqhDragItem(id: 'ws5', emoji: '🫧', label: 'Clean tap water', labelAr: 'مَاء الحَنَفِيَّة النَّظِيف', correctZoneId: 'bucketA'),
            FiqhDragItem(id: 'ws6', emoji: '🟫', label: 'Muddy water mixed with earth', labelAr: 'مَاء مَخْلُوط بالطِّين', correctZoneId: 'bucketB'),
            FiqhDragItem(id: 'ws7', emoji: '💛', label: 'Water mixed with urine (najas)', labelAr: 'مَاء مُلَوَّث بِالنَّجَاسَة', correctZoneId: 'bucketB'),
            FiqhDragItem(id: 'ws8', emoji: '🧴', label: 'Soapy water (used for cleaning)', labelAr: 'مَاء الصَّابُون المُسْتَعْمَل', correctZoneId: 'bucketB'),
            FiqhDragItem(id: 'ws9', emoji: '🍵', label: 'Water boiled with tea', labelAr: 'مَاء مَطْبُوخ بالشَّاي', correctZoneId: 'bucketB'),
            ],
            fiqhZones: [
            FiqhDropZone(id: 'bucketA', label: 'Tahir (Purifying) ✓', icon: '✅'),
            FiqhDropZone(id: 'bucketB', label: 'Not for Wudu ✗', icon: '❌'),
            ],
          ),
        ],
      ),
      Lesson(
        id: 'dest5-fiqhDrag-2',
        title: 'Fiqh Sort & Match 2',
        titleAr: 'الفِقْه: رَتِّب وطَابِق 2',
        icon: '🧩',
        color: '#D85A30',
        xp: 30,
        activities: [
          Activity(
            id: 'dest5-fiqh-2',
            type: ActivityType.fiqhDrag,
            title: 'Fiqh Sort & Match 2',
            icon: '🧩',
            xp: 30,
            fiqhItems: [
            FiqhDragItem(id: 'wd1', emoji: '🙏', label: 'Make Niyyah (intention)', labelAr: 'النيّة', correctZoneId: 'bucketA'),
            FiqhDragItem(id: 'wd2', emoji: '✨', label: 'Say Bismillah first', labelAr: 'قل بسم اللّٰه أوّلاً', correctZoneId: 'bucketA'),
            FiqhDragItem(id: 'wd3', emoji: '👐', label: 'Wash both hands 3x', labelAr: 'اغسل يديك 3×', correctZoneId: 'bucketA'),
            FiqhDragItem(id: 'wd4', emoji: '😮', label: 'Rinse mouth 3x', labelAr: 'المضمضة 3×', correctZoneId: 'bucketA'),
            FiqhDragItem(id: 'wd5', emoji: '👃', label: 'Sniff water into nose 3x', labelAr: 'الاستنشاق 3×', correctZoneId: 'bucketA'),
            FiqhDragItem(id: 'wd6', emoji: '😊', label: 'Wash face 3x', labelAr: 'اغسل وجهك 3×', correctZoneId: 'bucketA'),
            FiqhDragItem(id: 'wd7', emoji: '🍕', label: 'Eat food first before wudu', labelAr: 'كُل الطعام أوّلاً', correctZoneId: 'bucketB'),
            FiqhDragItem(id: 'wd8', emoji: '📱', label: 'Check your phone during wudu', labelAr: 'تفقّد هاتفك أثناء الوضوء', correctZoneId: 'bucketB'),
            ],
            fiqhZones: [
            FiqhDropZone(id: 'bucketA', label: 'Wudu Step ✓', icon: '✅'),
            FiqhDropZone(id: 'bucketB', label: 'Not Wudu ✗', icon: '❌'),
            ],
          ),
        ],
      ),
    ],
  ),

  Destination(
    id: 6,
    name: 'Mountain of Iman',
    nameAr: 'جَبَل الإِيمَان',
    icon: '⛰️',
    color: '#6C63D6',
    bg: '#E8E4FF',
    mapX: 120,
    mapY: 310,
    description:
        'Discover Allah\'s beautiful attributes, the 5 Pillars of Islam and the 6 Articles of Faith.',
    state: DestinationState.locked,
    lessons: [
      Lesson(
        id: 'dest6-trace-1',
        title: 'Trace Practice 1',
        titleAr: 'تَتَبُّع الحُرُوف 1',
        icon: '✍️',
        color: '#0F6E56',
        xp: 15,
        activities: [
          Activity(
            id: 'dest6-trace-1',
            type: ActivityType.trace,
            title: 'Trace Practice 1',
            icon: '✍️',
            xp: 15,
            cards: [
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
            ],
          ),
        ],
      ),
      Lesson(
        id: 'dest6-trace-2',
        title: 'Trace Practice 2',
        titleAr: 'تَتَبُّع الحُرُوف 2',
        icon: '✍️',
        color: '#0F6E56',
        xp: 20,
        activities: [
          Activity(
            id: 'dest6-trace-2',
            type: ActivityType.trace,
            title: 'Trace Practice 2',
            icon: '✍️',
            xp: 20,
            cards: [
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
            ],
          ),
        ],
      ),
      Lesson(
        id: 'dest6-pronounce-1',
        title: 'Arabic Numbers Game 1',
        titleAr: 'لُعْبَة الأَرْقَام 1',
        icon: '🧺',
        color: '#EF9F27',
        xp: 15,
        activities: [
          Activity(
            id: 'dest6-pronounce-1',
            type: ActivityType.pronounce,
            title: 'Arabic Numbers 1',
            icon: '🧺',
            xp: 15,
            cards: numbersCards,
          ),
        ],
      ),
      Lesson(
        id: 'dest6-pronounce-2',
        title: 'Arabic Numbers Game 2',
        titleAr: 'لُعْبَة الأَرْقَام 2',
        icon: '🧺',
        color: '#EF9F27',
        xp: 20,
        activities: [
          Activity(
            id: 'dest6-pronounce-2',
            type: ActivityType.pronounce,
            title: 'Arabic Numbers 2',
            icon: '🧺',
            xp: 20,
            cards: numbersCards,
          ),
        ],
      ),
      Lesson(
        id: 'dest6-quranSync-1',
        title: 'Dressing Up Du\'a',
        titleAr: 'دُعَاء لُبْسِ الثَّوْبِ',
        icon: '📖',
        color: '#6C63D6',
        xp: 25,
        activities: [
          Activity(
            id: 'dest6-quransync-1',
            type: ActivityType.quranSync,
            title: 'Daily Supplication',
            icon: '📖',
            xp: 25,
            quranLine: QuranSyncLine(
                id: 'dest6-quransync-1',
                arabicWords: ['الْحَمْدُ', 'لِلّٰهِ', 'الَّذِي', 'كَسَانِي', 'هٰذَا'],
                translitWords: ["Alhamdu lillahil-ladhi", "kasani", "hadha"],
                wordTimestampsMs: [0, 1000, 2000],
                totalDurationMs: 3000,
                reference: 'Daily Supplication: Dressing Up',
              ),
          ),
        ],
      ),
      Lesson(
        id: 'dest6-quranSync-2',
        title: 'Undressing Du\'a',
        titleAr: 'دُعَاء نَزْعِ الثَّوْبِ',
        icon: '📖',
        color: '#6C63D6',
        xp: 25,
        activities: [
          Activity(
            id: 'dest6-quransync-2',
            type: ActivityType.quranSync,
            title: 'Daily Supplication',
            icon: '📖',
            xp: 25,
            quranLine: QuranSyncLine(
                id: 'dest6-quransync-2',
                arabicWords: ['بِسْمِ', 'اللّٰهِ', 'الَّذِي', 'لَا', 'إِلٰهَ', 'إِلَّا', 'هُوَ'],
                translitWords: ["Bismillahil-ladhi", "la ilaha", "illa huwa"],
                wordTimestampsMs: [0, 1000, 2000],
                totalDurationMs: 3000,
                reference: 'Daily Supplication: Undressing',
              ),
          ),
        ],
      ),
      Lesson(
        id: 'dest6-story-1',
        title: 'Five Pillars Match 1',
        titleAr: 'أَرْكَانُ الْإِسْلَامِ 1',
        icon: '🕌',
        color: '#5B9A1E',
        xp: 30,
        activities: [
          Activity(
            id: 'dest6-story-1',
            type: ActivityType.story,
            title: 'Five Pillars Match 1',
            icon: '🕌',
            xp: 30,
            panels: [
              StoryPanel(
                id: 'cr1',
                bg: 'linear-gradient(160deg, #1a2744 0%, #0F6E56 100%)',
                scene: [],
                caption: 'Pillars Match level 1',
              ),
            ],
          ),
        ],
      ),
      Lesson(
        id: 'dest6-story-2',
        title: 'Five Pillars Match 2',
        titleAr: 'أَرْكَانُ الْإِسْلَامِ 2',
        icon: '🕌',
        color: '#5B9A1E',
        xp: 30,
        activities: [
          Activity(
            id: 'dest6-story-2',
            type: ActivityType.story,
            title: 'Five Pillars Match 2',
            icon: '🕌',
            xp: 30,
            panels: [
              StoryPanel(
                id: 'cr3',
                bg: 'linear-gradient(160deg, #5B9A1E 0%, #FDECC8 100%)',
                scene: [],
                caption: 'Pillars Match level 2',
              ),
              StoryPanel(
                id: 'cr4',
                bg: 'linear-gradient(160deg, #EF9F27 0%, #D85A30 100%)',
                scene: [],
                caption: 'Pillars Match level 2 panel 2',
              ),
            ],
          ),
        ],
      ),
      Lesson(
        id: 'dest6-fiqhDrag-1',
        title: 'Fiqh Sort & Match 1',
        titleAr: 'الفِقْه: رَتِّب وطَابِق 1',
        icon: '🧩',
        color: '#D85A30',
        xp: 20,
        activities: [
          Activity(
            id: 'dest6-fiqh-1',
            type: ActivityType.fiqhDrag,
            title: 'Fiqh Sort & Match 1',
            icon: '🧩',
            xp: 20,
            fiqhItems: [
            FiqhDragItem(id: 'plm1', emoji: '☝️', label: 'الشَّهَادَة', correctZoneId: 'plm1'),
            FiqhDragItem(id: 'plm2', emoji: '🕌', label: 'الصَّلَاة', correctZoneId: 'plm2'),
            FiqhDragItem(id: 'plm3', emoji: '💛', label: 'الزَّكَاة', correctZoneId: 'plm3'),
            FiqhDragItem(id: 'plm4', emoji: '🌙', label: 'الصَّوْم', correctZoneId: 'plm4'),
            FiqhDragItem(id: 'plm5', emoji: '🕋', label: 'الحَجّ', correctZoneId: 'plm5'),
            ],
            fiqhZones: [
            FiqhDropZone(id: 'plm1', label: 'Declaration of Faith', icon: '🌟'),
            FiqhDropZone(id: 'plm2', label: '5 Daily Prayers', icon: '🤲'),
            FiqhDropZone(id: 'plm3', label: 'Giving Charity', icon: '🤝'),
            FiqhDropZone(id: 'plm4', label: 'Fasting in Ramadan', icon: '🌙'),
            FiqhDropZone(id: 'plm5', label: 'Pilgrimage to Makkah', icon: '🕋'),
            ],
          ),
        ],
      ),
      Lesson(
        id: 'dest6-fiqhDrag-2',
        title: 'Fiqh Sort & Match 2',
        titleAr: 'الفِقْه: رَتِّب وطَابِق 2',
        icon: '🧩',
        color: '#D85A30',
        xp: 30,
        activities: [
          Activity(
            id: 'dest6-fiqh-2',
            type: ActivityType.fiqhDrag,
            title: 'Fiqh Sort & Match 2',
            icon: '🧩',
            xp: 30,
            fiqhItems: [
            FiqhDragItem(id: 'mn1', emoji: '🤝', label: 'Saying Salaam first when meeting', labelAr: 'قُل السلام أوّلاً', correctZoneId: 'bucketA'),
            FiqhDragItem(id: 'mn2', emoji: '🙋', label: 'Helping a friend who fell down', labelAr: 'ساعد صديقك إذا سقط', correctZoneId: 'bucketA'),
            FiqhDragItem(id: 'mn3', emoji: '🍽️', label: 'Saying Bismillah before eating', labelAr: 'قل بسم اللّٰه قبل الأكل', correctZoneId: 'bucketA'),
            FiqhDragItem(id: 'mn4', emoji: '👂', label: 'Listening when teacher speaks', labelAr: 'اسمع حين يتكلّم المعلّم', correctZoneId: 'bucketA'),
            FiqhDragItem(id: 'mn5', emoji: '🌱', label: 'Picking up litter from the ground', labelAr: 'التقط القمامة من الأرض', correctZoneId: 'bucketA'),
            FiqhDragItem(id: 'mn6', emoji: '🗣️', label: 'Interrupting when someone talks', labelAr: 'اقطع كلام شخص آخر', correctZoneId: 'bucketB'),
            FiqhDragItem(id: 'mn7', emoji: '😤', label: 'Pushing others in the lunch line', labelAr: 'ادفع الآخرين في الطابور', correctZoneId: 'bucketB'),
            FiqhDragItem(id: 'mn8', emoji: '😒', label: 'Making fun of a classmate', labelAr: 'السخرية من زميل', correctZoneId: 'bucketB'),
            FiqhDragItem(id: 'mn9', emoji: '🗑️', label: 'Throwing litter on the floor', labelAr: 'إلقاء القمامة على الأرض', correctZoneId: 'bucketB'),
            ],
            fiqhZones: [
            FiqhDropZone(id: 'bucketA', label: 'Islamic Manner ✓', icon: '✅'),
            FiqhDropZone(id: 'bucketB', label: 'Bad Manner ✗', icon: '❌'),
            ],
          ),
        ],
      ),
    ],
  ),

  Destination(
    id: 7,
    name: 'Quran Corner',
    nameAr: 'رُكْن القُرْآن',
    icon: '📖',
    color: '#0F6E56',
    bg: '#DCF0E6',
    mapX: 195,
    mapY: 105,
    description:
        'Memorize and understand the short suwar from Juz Amma -- the final chapter of the Holy Quran.',
    state: DestinationState.locked,
    lessons: [
      Lesson(
        id: 'dest7-trace-1',
        title: 'Trace Practice 1',
        titleAr: 'تَتَبُّع الحُرُوف 1',
        icon: '✍️',
        color: '#0F6E56',
        xp: 20,
        activities: [
          Activity(
            id: 'dest7-trace-1',
            type: ActivityType.trace,
            title: 'Trace Practice 1',
            icon: '✍️',
            xp: 20,
            cards: [
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
            ],
          ),
        ],
      ),
      Lesson(
        id: 'dest7-trace-2',
        title: 'Trace Practice 2',
        titleAr: 'تَتَبُّع الحُرُوف 2',
        icon: '✍️',
        color: '#0F6E56',
        xp: 25,
        activities: [
          Activity(
            id: 'dest7-trace-2',
            type: ActivityType.trace,
            title: 'Trace Practice 2',
            icon: '✍️',
            xp: 25,
            cards: [
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
            ],
          ),
        ],
      ),
      Lesson(
        id: 'dest7-pronounce-1',
        title: 'Arabic Numbers Game 1',
        titleAr: 'لُعْبَة الأَرْقَام 1',
        icon: '🧺',
        color: '#EF9F27',
        xp: 20,
        activities: [
          Activity(
            id: 'dest7-pronounce-1',
            type: ActivityType.pronounce,
            title: 'Arabic Numbers 1',
            icon: '🧺',
            xp: 20,
            cards: numbersCards,
          ),
        ],
      ),
      Lesson(
        id: 'dest7-pronounce-2',
        title: 'Arabic Numbers Game 2',
        titleAr: 'لُعْبَة الأَرْقَام 2',
        icon: '🧺',
        color: '#EF9F27',
        xp: 25,
        activities: [
          Activity(
            id: 'dest7-pronounce-2',
            type: ActivityType.pronounce,
            title: 'Arabic Numbers 2',
            icon: '🧺',
            xp: 25,
            cards: numbersCards,
          ),
        ],
      ),
      Lesson(
        id: 'dest7-quranSync-1',
        title: 'Qur\'an & Hadith Sync 1',
        titleAr: 'القُرْآن والحَديث 1',
        icon: '📖',
        color: '#6C63D6',
        xp: 25,
        activities: [
          Activity(
            id: 'dest7-quransync-1',
            type: ActivityType.quranSync,
            title: 'Qur\'an & Hadith Sync 1',
            icon: '📖',
            xp: 25,
            quranLine: QuranSyncLine(
                id: 'dest7-quransync-1',
                arabicWords: ['قُلْ', 'هُوَ', 'اللَّهُ', 'أَحَدٌ'],
                translitWords: ['Qul huwa', 'Allahu', 'ahad', 'ahad'],
                wordTimestampsMs: [0, 900, 1800, 2700],
                totalDurationMs: 4000,
                reference: 'Surah Al-Ikhlas, 112:1',
              ),
          ),
        ],
      ),
      Lesson(
        id: 'dest7-quranSync-2',
        title: 'Qur\'an & Hadith Sync 2',
        titleAr: 'القُرْآن والحَديث 2',
        icon: '📖',
        color: '#6C63D6',
        xp: 25,
        activities: [
          Activity(
            id: 'dest7-quransync-2',
            type: ActivityType.quranSync,
            title: 'Qur\'an & Hadith Sync 2',
            icon: '📖',
            xp: 25,
            quranLine: QuranSyncLine(
                id: 'dest7-quransync-2',
                arabicWords: ['اللَّهُ', 'الصَّمَدُ'],
                translitWords: ['Allahu', 'as-samad'],
                wordTimestampsMs: [0, 900],
                totalDurationMs: 2200,
                reference: 'Surah Al-Ikhlas, 112:2',
              ),
          ),
        ],
      ),
      Lesson(
        id: 'dest7-story-1',
        title: 'Five Pillars Match 1',
        titleAr: 'أَرْكَانُ الْإِسْلَامِ 1',
        icon: '🕌',
        color: '#5B9A1E',
        xp: 30,
        activities: [
          Activity(
            id: 'dest7-story-1',
            type: ActivityType.story,
            title: 'Five Pillars Match 1',
            icon: '🕌',
            xp: 30,
            panels: [
              StoryPanel(
                id: 'qr1',
                bg: 'linear-gradient(160deg, #0F6E56 0%, #1a2744 100%)',
                scene: [],
                caption: 'Pillars Match level 1',
              ),
            ],
          ),
        ],
      ),
      Lesson(
        id: 'dest7-story-2',
        title: 'Five Pillars Match 2',
        titleAr: 'أَرْكَانُ الْإِسْلَامِ 2',
        icon: '🕌',
        color: '#5B9A1E',
        xp: 30,
        activities: [
          Activity(
            id: 'dest7-story-2',
            type: ActivityType.story,
            title: 'Five Pillars Match 2',
            icon: '🕌',
            xp: 30,
            panels: [
              StoryPanel(
                id: 'qr3',
                bg: 'linear-gradient(160deg, #EF9F27 0%, #0F6E56 100%)',
                scene: [],
                caption: 'Pillars Match level 2',
              ),
              StoryPanel(
                id: 'qr4',
                bg: 'linear-gradient(160deg, #FDECC8 0%, #E8E4FF 100%)',
                scene: [],
                caption: 'Pillars Match level 2 panel 2',
              ),
            ],
          ),
        ],
      ),
      Lesson(
        id: 'dest7-fiqhDrag-1',
        title: 'Fiqh Sort & Match 1',
        titleAr: 'الفِقْه: رَتِّب وطَابِق 1',
        icon: '🧩',
        color: '#D85A30',
        xp: 25,
        activities: [
          Activity(
            id: 'dest7-fiqh-1',
            type: ActivityType.fiqhDrag,
            title: 'Fiqh Sort & Match 1',
            icon: '🧩',
            xp: 25,
            fiqhItems: [
              FiqhDragItem(id: 'swm1', emoji: '🙏', label: 'الفَاتِحَة', correctZoneId: 'swm1'),
              FiqhDragItem(id: 'swm2', emoji: '☝️', label: 'الإِخْلَاص', correctZoneId: 'swm2'),
            ],
            fiqhZones: [
              FiqhDropZone(id: 'swm1', label: 'The Opening', icon: '📖'),
              FiqhDropZone(id: 'swm2', label: 'Allah is ONE', icon: '💚'),
            ],
          ),
        ],
      ),
      Lesson(
        id: 'dest7-fiqhDrag-2',
        title: 'Fiqh Sort & Match 2',
        titleAr: 'الفِقْه: رَتِّب وطَابِق 2',
        icon: '🧩',
        color: '#D85A30',
        xp: 25,
        activities: [
          Activity(
            id: 'dest7-fiqh-2',
            type: ActivityType.fiqhDrag,
            title: 'Fiqh Sort & Match 2',
            icon: '🧩',
            xp: 25,
            fiqhItems: [
              FiqhDragItem(id: 'swm3', emoji: '👥', label: 'النَّاس', correctZoneId: 'swm3'),
              FiqhDragItem(id: 'swm4', emoji: '🌅', label: 'الفَلَق', correctZoneId: 'swm4'),
              FiqhDragItem(id: 'swm5', emoji: '🌸', label: 'الكَوْثَر', correctZoneId: 'swm5'),
            ],
            fiqhZones: [
              FiqhDropZone(id: 'swm3', label: 'Mankind', icon: '🌍'),
              FiqhDropZone(id: 'swm4', label: 'Daybreak', icon: '🌄'),
              FiqhDropZone(id: 'swm5', label: 'The Shortest Surah', icon: '🏆'),
            ],
          ),
        ],
      ),
    ],
  ),
];
