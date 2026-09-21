import 'package:flutter/material.dart' as m;
import 'package:hive/hive.dart';
import '../../data/local/hive_boxes.dart';

class AppTranslations {
  static const Map<String, String> _filipino = {
    // Onboarding / Get Started
    'WELCOME': 'MALIGAYANG PAGDATING',
    "Let's get started": 'Magsimula na tayo',
    'Choose your language': 'Piliin ang iyong wika',
    'You can change this anytime in Settings': 'Maaari mo itong baguhin anumang oras sa Mga Setting',
    'INSTRUCTIONAL LANGUAGE': 'WIKANG PAMPAGTUTURO',
    'English': 'Ingles',
    'Lessons narrated in English': 'Mga aralin sa Ingles',
    'Filipino': 'Filipino',
    'Mga aralin sa Filipino': 'Mga aralin sa Filipino',
    'Continue': 'Magpatuloy',
    'Not sure which to choose?': 'Hindi sigurado kung ano ang pipiliin?',
    'You can always switch languages later in your profile settings.': 'Maaari mo ring palitan ang wika pagkatapos sa mga setting ng iyong profile.',
    'Skip': 'Laktawan',
    'Assets verified': 'Na-verify na ang mga asset',
    'Checking assets…': 'Sinusuri ang mga asset…',
    'Checking assets': 'Sinusuri ang mga asset',
    '512MB free · 500MB required': '512MB libre · 500MB kailangan',
    
    // Privacy & Consent
    'Privacy & data consent': 'Pahintulot sa Privacy at Data',
    'A full look at what we collect, why, and your rights, before your child starts learning.': 'Isang buong pagtingin sa aming kinokolekta, bakit, at ang iyong mga karapatan, bago magsimulang mag-aral ang iyong anak.',
    'Last updated: June 2026': 'Huling na-update: Hunyo 2026',
    'REQUIRED FOR OFFLINE & CLASSROOM FEATURES': 'KAILANGAN PARA SA OFFLINE AT CLASSROOM FEATURES',
    'I agree to the privacy policy and consent to the collection of learning data': 'Sumasang-ayon ako sa patakaran sa privacy at pahintulot sa pangongolekta ng data sa pag-aaral',
    'Please agree to the privacy consent to continue.': 'Mangyaring sumang-ayon sa pahintulot sa privacy upang magpatuloy.',
    'Please review the data policy above. Your agreement is required to create a student profile and sync learning progress.': 'Mangyaring suriin ang patakaran sa data sa itaas. Ang iyong kasunduan ay kinakailangan upang lumikha ng isang profile ng mag-aaral at i-sync ang pag-unlad sa pag-aaral.',
    'I Agree': 'Sumasang-ayon Ako',
    'Back': 'Bumalik',
    
    // Role Selection
    'Who is using this device?': 'Sino ang gagamit ng device na ito?',
    'Choose your role to customize your learning journey': 'Piliin ang iyong papel upang i-customize ang iyong paglalakbay sa pag-aaral',
    'Learner': 'Mag-aaral',
    'Parent': 'Magulang',
    'Teacher': 'Guro',
    'Asatidz': 'Asatidz',
    
    // Authentication / PIN Screen
    'Enter 4-digit PIN': 'Ilagay ang 4-digit na PIN',
    'Verify PIN': 'I-verify ang PIN',
    'Setup 4-digit PIN': 'Mag-setup ng 4-digit na PIN',
    'Confirm 4-digit PIN': 'Kumpirmahin ang 4-digit na PIN',
    'Incorrect PIN': 'Maling PIN',
    'PIN Verified': 'Na-verify na ang PIN',
    'Enter your PIN to access admin settings': 'Ilagay ang iyong PIN upang ma-access ang mga setting ng admin',
    'Create a PIN to secure parental settings': 'Gumawa ng PIN upang ma-secure ang mga setting ng magulang',
    'Confirm your new PIN': 'Kumpirmahin ang iyong bagong PIN',
    'Enter PIN': 'Ilagay ang PIN',
    'SETUP PIN': 'MAG-SETUP NG PIN',
    'VERIFY PIN': 'I-VERIFY ANG PIN',
    'PINs do not match. Try again.': 'Hindi nagtutugma ang mga PIN. Subukan muli.',
    
    // Parent/Teacher Setup
    'Create Parent Profile': 'Gumawa ng Profile ng Magulang',
    'Parent Profile': 'Profile ng Magulang',
    'Email Address': 'Email Address',
    'Password': 'Password',
    'Confirm Password': 'Kumpirmahin ang Password',
    'Full Name': 'Buong Pangalan',
    'Sign Up': 'Mag-sign Up',
    'Sign In': 'Mag-sign In',
    'Already have an account?': 'Mayroon ka na bang account?',
    'Create an account': 'Gumawa ng account',
    'Teacher Profile': 'Profile ng Guro',
    'Create Teacher Profile': 'Gumawa ng Profile ng Guro',
    
    // Learner Setup
    'Create Student Profile': 'Gumawa ng Profile ng Mag-aaral',
    'Learner Setup': 'Setup ng Mag-aaral',
    'First Name': 'Pangalan',
    'Gender': 'Kasarian',
    'Boy': 'Lalaki',
    'Girl': 'Babae',
    'Age': 'Edad',
    'Select Avatar': 'Pumili ng Avatar',
    'Save Profile': 'I-save ang Profile',
    'Add Child': 'Magdagdag ng Anak',
    
    // Student Hub
    'ADVENTURE MAP': 'MAPA NG PAKIKIPAGSAPALARAN',
    'BACKPACK': 'BACKPACK',
    'PROFILE': 'PROFILE',
    'Welcome to Madrasah': 'Maligayang Pagdating sa Madrasah',
    'Exploring Our World': 'Paggalugad sa Aming Daigdig',
    'A Growing Muslim': 'Isang Lumalaking Muslim',
    'Stories & Letters': 'Mga Kwento at Titik',
    'Cleanliness & Character': 'Kalinisan at Ugali',
    'The Path of the Prophet': 'Ang Landas ng Propeta',
    'The Good Deed Hero': 'Ang Bayani ng Mabuting Gawa',
    'Noor Energy': 'Lakas ng Noor',
    'Level': 'Antas',
    'Lessons': 'Mga Aralin',
    'Daily Quest': 'Pang-araw-araw na Pakikipagsapalaran',
    'Homework': 'Takdang-Aralin',
    'Badges': 'Mga Badge',
    'Streaks': 'Mga Streak',
    'Start Learning': 'Simulan ang Pag-aaral',
    'Assigned Homework': 'Itinalagang Takdang-Aralin',
    'No assigned homework': 'Walang itinalagang takdang-aralin',
    'Recent Badges': 'Mga Kamakailang Badge',
    'View All': 'Tingnan Lahat',
    'Active Streak': 'Aktibong Streak',
    'days': 'mga araw',
    'No energy left! Let\'s rest.': 'Wala nang lakas! Magpahinga muna tayo.',
    'Rest': 'Magpahinga',
    
    // Settings
    'Settings': 'Mga Setting',
    'General': 'Pangkalahatan',
    'Language': 'Wika',
    'Volume': 'Lakas ng Tunog',
    'Background Music': 'Tugtog sa Background',
    'Sound Effects': 'Mga Epekto ng Tunog',
    'Voiceover': 'Boses',
    'App Version': 'Bersyon ng App',
    'Developer Options': 'Mga Pagpipilian sa Developer',
    'Erase All Data': 'Burahin Lahat ng Data',
    'Logout': 'Mag-logout',
    'Confirm Erase': 'Kumpirmahin ang Pagbura',
    'Are you sure you want to erase all data? This cannot be undone.': 'Sigurado ka bang gusto mong burahin ang lahat ng data? Hindi ito mababawi.',
    'Cancel': 'Kanselahin',
    'Erase': 'Burahin',
    'Switch Account': 'Lumipat ng Account',
    'Parent Dashboard': 'Dashboard ng Magulang',
    'Teacher Dashboard': 'Dashboard ng Guro',
  };

  static String translate(String text, [String? languageCode]) {
    final code = languageCode ?? currentLanguageCode;
    if (code == 'fil') {
      final translated = _filipino[text] ?? _filipino[text.trim()];
      if (translated != null) return translated;
      
      // Fallback searches for case insensitivity or minor variations
      // (like trailing colon/spaces/dots)
      var cleaned = text.trim();
      var suffix = '';
      if (cleaned.endsWith(':')) {
        cleaned = cleaned.substring(0, cleaned.length - 1).trim();
        suffix = ':';
      } else if (cleaned.endsWith('?')) {
        cleaned = cleaned.substring(0, cleaned.length - 1).trim();
        suffix = '?';
      } else if (cleaned.endsWith('!')) {
        cleaned = cleaned.substring(0, cleaned.length - 1).trim();
        suffix = '!';
      } else if (cleaned.endsWith('.')) {
        cleaned = cleaned.substring(0, cleaned.length - 1).trim();
        suffix = '.';
      }
      
      final transCleaned = _filipino[cleaned] ?? _filipino[cleaned.toLowerCase()] ?? _filipino[cleaned.toUpperCase()];
      if (transCleaned != null) {
        return '$transCleaned$suffix';
      }
    }
    return text;
  }

  static String? currentLanguageCodeOverride;

  static String get currentLanguageCode {
    if (currentLanguageCodeOverride != null) return currentLanguageCodeOverride!;
    try {
      final box = Hive.box(HiveBoxes.settings);
      return box.get('languageCode') as String? ?? 'en';
    } catch (_) {
      return 'en';
    }
  }
}

extension TranslationExtension on String {
  String get tr => AppTranslations.translate(this);
}

class Text extends m.StatelessWidget {
  final String? data;
  final m.InlineSpan? textSpan;
  final m.TextStyle? style;
  final m.StrutStyle? strutStyle;
  final m.TextAlign? textAlign;
  final m.TextDirection? textDirection;
  final m.Locale? locale;
  final bool? softWrap;
  final m.TextOverflow? overflow;
  final double? textScaleFactor;
  final int? maxLines;
  final String? semanticsLabel;
  final m.TextWidthBasis? textWidthBasis;
  final m.TextHeightBehavior? textHeightBehavior;
  final m.Color? selectionColor;

  const Text(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaleFactor,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  }) : textSpan = null;

  const Text.rich(
    this.textSpan, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaleFactor,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  }) : data = null;

  @override
  m.Widget build(m.BuildContext context) {
    final language = locale?.languageCode ?? AppTranslations.currentLanguageCode;
    if (textSpan != null) {
      final translatedSpan = _translateInlineSpan(textSpan!, language);
      return m.Text.rich(
        translatedSpan,
        key: key,
        style: style,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        textScaleFactor: textScaleFactor,
        maxLines: maxLines,
        semanticsLabel: semanticsLabel,
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        selectionColor: selectionColor,
      );
    } else {
      return m.Text(
        AppTranslations.translate(data ?? '', language),
        key: key,
        style: style,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        textScaleFactor: textScaleFactor,
        maxLines: maxLines,
        semanticsLabel: semanticsLabel,
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        selectionColor: selectionColor,
      );
    }
  }

  static m.InlineSpan _translateInlineSpan(m.InlineSpan span, String language) {
    if (span is m.TextSpan) {
      return m.TextSpan(
        text: span.text != null ? AppTranslations.translate(span.text!, language) : null,
        children: span.children?.map((child) => _translateInlineSpan(child, language)).toList(),
        style: span.style,
        recognizer: span.recognizer,
        mouseCursor: span.mouseCursor,
        onEnter: span.onEnter,
        onExit: span.onExit,
        semanticsLabel: span.semanticsLabel,
        locale: span.locale,
        spellOut: span.spellOut,
      );
    }
    return span;
  }
}

class TextSpan extends m.TextSpan {
  const TextSpan({
    super.text,
    super.children,
    super.style,
    super.recognizer,
    super.mouseCursor,
    super.onEnter,
    super.onExit,
    super.semanticsLabel,
    super.locale,
    super.spellOut,
  });

  @override
  String? get text {
    final t = super.text;
    if (t == null) return null;
    final language = locale?.languageCode ?? AppTranslations.currentLanguageCode;
    return AppTranslations.translate(t, language);
  }
}
