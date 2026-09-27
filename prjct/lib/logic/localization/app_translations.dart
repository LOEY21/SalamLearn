import 'package:flutter/material.dart' as m;
import 'package:hive/hive.dart';
import '../../data/local/hive_boxes.dart';
import 'filipino_strings.dart';

class AppTranslations {
  static String translate(String text, [String? languageCode]) {
    final code = languageCode ?? currentLanguageCode;
    if (code != 'fil' || text.isEmpty) return text;
    return _cache[text] ??= _translateFil(text);
  }

  // ponytail: unbounded memo of every string rendered in Filipino; fine for
  // this app's finite UI copy, cap it if dynamic text ever grows unbounded.
  static final Map<String, String> _cache = {};

  static String _lookup(String text) {
    final translated = filipinoStrings[text] ?? filipinoStrings[text.trim()];
    if (translated != null) return translated;

    // Fallback for minor variations (trailing punctuation, casing).
    var cleaned = text.trim();
    var suffix = '';
    for (final p in const [':', '?', '!', '.']) {
      if (cleaned.endsWith(p)) {
        cleaned = cleaned.substring(0, cleaned.length - 1).trim();
        suffix = p;
        break;
      }
    }
    final transCleaned = filipinoStrings[cleaned] ??
        filipinoStrings[cleaned.toLowerCase()] ??
        filipinoStrings[cleaned.toUpperCase()] ??
        _upper[cleaned];
    return transCleaned != null ? '$transCleaned$suffix' : text;
  }

  // Headers often render `title.toUpperCase()`, so index keys by their
  // uppercased form too.
  static final Map<String, String> _upper = {
    for (final e in filipinoStrings.entries)
      e.key.toUpperCase(): e.value.toUpperCase(),
  };

  static String _translateFil(String text) {
    final direct = _lookup(text);
    if (!identical(direct, text)) return direct;
    for (final (pattern, replacement) in _templates) {
      final m = pattern.firstMatch(text);
      if (m == null) continue;
      return replacement.replaceAllMapped(
        RegExp(r'\{(\d+)\}'),
        (r) => _lookup(m.group(int.parse(r.group(1)!) + 1) ?? ''),
      );
    }
    return text;
  }

  // Interpolated strings: "Level {0}" -> ^Level (.*?)$, most literal text first
  // so a specific template wins over a looser one.
  static final List<(RegExp, String)> _templates = () {
    final entries = filipinoTemplates.entries.toList()
      ..sort((a, b) => b.key.replaceAll(RegExp(r'\{\d+\}'), '').length
          .compareTo(a.key.replaceAll(RegExp(r'\{\d+\}'), '').length));
    return [
      for (final e in entries)
        (
          RegExp(
            '^${e.key.split(RegExp(r'\{\d+\}')).map(RegExp.escape).join('(.*?)')}\$',
            dotAll: true,
          ),
          e.value,
        ),
    ];
  }();

  /// Re-runs build on every mounted widget so const Texts pick up a language
  /// change (setState alone skips const subtrees). Element state is kept.
  static void refreshAll() {
    void rebuild(m.Element e) {
      e.markNeedsBuild();
      e.visitChildren(rebuild);
    }

    m.WidgetsBinding.instance.rootElement?.visitChildren(rebuild);
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
