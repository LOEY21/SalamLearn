import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:salamlearn/logic/localization/app_translations.dart';

import '../../data/curriculum_data.dart';
import '../../data/models/curriculum/curriculum_models.dart';
import '../../data/models/lesson_folder.dart';
import '../../logic/teacher/teacher_providers.dart';
import '../theme/app_colors.dart';
import 'module_library_data.dart';

/// One game on the Cast screen's game picker — every curriculum activity of
/// the same [ActivityType], in curriculum order, as its playable sessions.
class CastGame {
  const CastGame({
    required this.type,
    required this.name,
    required this.cover,
    required this.sessions,
  });

  final ActivityType type;
  final String name;
  final String cover;
  final List<ModuleRef> sessions;

  String get emoji => sessions.first.activity.icon;
}

const Map<ActivityType, (String, String)> _gameArt = {
  ActivityType.pronounce: (
    'Greeting Match',
    'assets/images/greeting_match/start_bg.png',
  ),
  ActivityType.creationHunt: (
    "Allah's Creation Hunt",
    'assets/images/creation_hunt/intro_title_art.png',
  ),
  ActivityType.trace: (
    'Magic Sand Tracer',
    'assets/images/tracing/bg_field.png',
  ),
  ActivityType.soundDetective: (
    'Arabic Sound Detective',
    'assets/images/sound_detective/start_bg.jpg',
  ),
  ActivityType.quranEtiquette: (
    "The Qur'an Etiquette",
    'assets/images/quran_etiquette/start_bg.jpg',
  ),
  ActivityType.labelMaker: ('Label Maker', 'assets/images/label_maker/bg.png'),
  ActivityType.ayahBuilder: (
    'Ayah Builder',
    'assets/images/ayah_builder/bg_night_mosque_plate.jpg',
  ),
  ActivityType.sirahStory: (
    'Sirah Story',
    'assets/images/sirah_story/s1p1_bg.png',
  ),
  ActivityType.classroomHeroes: (
    'Classroom Heroes',
    'assets/images/classroom_heroes/start_screen.png',
  ),
  ActivityType.taharahAdventure: (
    'Taharah Adventure',
    'assets/images/taharah/s1_start_bg.png',
  ),
  ActivityType.fivePillars: (
    'The Five Pillars',
    'assets/images/five_pillars/start_bg.png',
  ),
  ActivityType.goodDeedTree: (
    'The Good Deed Tree',
    'assets/images/good_deed_tree/start_bg.png',
  ),
};

final List<CastGame> castGames = () {
  final byType = <ActivityType, List<ModuleRef>>{};
  for (final m in allModuleRefs) {
    byType.putIfAbsent(m.activity.type, () => []).add(m);
  }
  return [
    for (final e in byType.entries)
      if (_gameArt[e.key] case final art?)
        CastGame(type: e.key, name: art.$1, cover: art.$2, sessions: e.value),
  ];
}();

/// A one-off [Lesson] wrapping [refs] so `LessonPlayerScreen` can play them
/// back to back — borrows color/icon from the first ref's real lesson.
Lesson castLesson(List<ModuleRef> refs, {required String id, String? title}) {
  final first = refs.first;
  final source = curriculum
      .firstWhere((d) => d.id == first.destinationId)
      .lessons
      .firstWhere((l) => l.id == first.lessonId);
  return Lesson(
    id: id,
    title: title ?? first.activity.title,
    titleAr: source.titleAr,
    icon: first.activity.icon,
    color: source.color,
    xp: 0,
    activities: [for (final r in refs) r.activity],
  );
}

/// Step 2 of the Cast screen: every game, or the teacher's Module Library
/// folders, for whoever Hot Seat drew. Locked (dimmed, taps ignored) until
/// [student] is set. Sized for the Cast screen's fixed 960x540 canvas.
class CastGamesStage extends ConsumerStatefulWidget {
  const CastGamesStage({
    super.key,
    required this.student,
    required this.onPlay,
    required this.onOpenLibrary,
  });

  final String? student;
  final void Function(Lesson lesson, int destinationId) onPlay;
  final VoidCallback onOpenLibrary;

  @override
  ConsumerState<CastGamesStage> createState() => _CastGamesStageState();
}

class _CastGamesStageState extends ConsumerState<CastGamesStage> {
  bool _showLibrary = false;

  void _pickSession(CastGame game) {
    if (game.sessions.length == 1) {
      _play(game.sessions);
      return;
    }
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(game.name),
        contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        content: SizedBox(
          width: 420,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final (i, s) in game.sessions.indexed)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.mint,
                    foregroundColor: AppColors.tealDark,
                    child: Text('${i + 1}'),
                  ),
                  title: Text(
                    s.activity.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${s.destinationName} · ${s.lessonTitle}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(
                    Icons.play_circle_fill_rounded,
                    color: AppColors.teal,
                  ),
                  onTap: () {
                    Navigator.of(dialogContext).pop();
                    _play([s]);
                  },
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _play(List<ModuleRef> refs, {String? id, String? title}) => widget.onPlay(
    castLesson(refs, id: id ?? 'cast-${refs.first.ref}', title: title),
    refs.first.destinationId,
  );

  void _playFolder(LessonFolder folder) {
    final refs = folder.itemRefs
        .map(resolveModuleRef)
        .whereType<ModuleRef>()
        .toList();
    if (refs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This folder has no modules yet.')),
      );
      return;
    }
    _play(refs, id: 'folder-${folder.id}', title: folder.name);
  }

  @override
  Widget build(BuildContext context) {
    final activeClass = ref.watch(teacherClassControllerProvider);
    final folders = activeClass == null
        ? const <LessonFolder>[]
        : ref.watch(classLessonFoldersProvider(activeClass.id));
    final student = widget.student;
    final locked = student == null;

    return _Panel(
      highlight: !locked,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const _PanelLabel('STEP 2 · CHOOSE A GAME', color: AppColors.mintGreen),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  locked
                      ? 'Spin the Hot Seat first'
                      : 'for $student',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: locked ? FontWeight.w400 : FontWeight.w800,
                    color: locked ? Colors.white60 : AppColors.goldSoft,
                  ),
                ),
              ),
              Flexible(
                flex: 2,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: _Tabs(
                    showLibrary: _showLibrary,
                    onChanged: (v) => setState(() => _showLibrary = v),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: IgnorePointer(
              ignoring: locked,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: locked ? 0.35 : 1,
                child: _showLibrary
                    ? _LibraryList(
                        folders: folders,
                        onPlay: _playFolder,
                        onOpenLibrary: widget.onOpenLibrary,
                      )
                    : GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              childAspectRatio: 1.3,
                            ),
                        itemCount: castGames.length,
                        itemBuilder: (_, i) => _GameCard(
                          game: castGames[i],
                          onTap: () => _pickSession(castGames[i]),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.showLibrary, required this.onChanged});

  final bool showLibrary;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget tab(String label, IconData icon, bool library) {
      final active = showLibrary == library;
      return InkWell(
        key: ValueKey(library ? 'cast-tab-library' : 'cast-tab-games'),
        borderRadius: BorderRadius.circular(999),
        onTap: () => onChanged(library),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: active ? AppColors.gold : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: active ? AppColors.ink : Colors.white70),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: active ? AppColors.ink : Colors.white70,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          tab('All games', Icons.sports_esports_rounded, false),
          tab('Module Library', Icons.library_books_rounded, true),
        ],
      ),
    );
  }
}

class _LibraryList extends StatelessWidget {
  const _LibraryList({
    required this.folders,
    required this.onPlay,
    required this.onOpenLibrary,
  });

  final List<LessonFolder> folders;
  final ValueChanged<LessonFolder> onPlay;
  final VoidCallback onOpenLibrary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: folders.isEmpty
              ? const Center(
                  child: Text(
                    'No folders yet.\nBuild one from your chosen modules.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white54,
                      height: 1.4,
                    ),
                  ),
                )
              : GridView.builder(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        mainAxisExtent: 58,
                      ),
                  itemCount: folders.length,
                  itemBuilder: (_, i) => _FolderTile(
                    folder: folders[i],
                    onPlay: () => onPlay(folders[i]),
                  ),
                ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            key: const ValueKey('cast-open-library'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.ink,
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: onOpenLibrary,
            icon: const Icon(Icons.edit_note_rounded, size: 18),
            label: const Text(
              'Open Module Library',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.highlight = false});

  final Widget child;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highlight ? AppColors.mintGreen : Colors.white12,
          width: 1.4,
        ),
      ),
      child: child,
    );
  }
}

class _PanelLabel extends StatelessWidget {
  const _PanelLabel(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 9.5,
        fontWeight: FontWeight.w800,
        color: color,
        letterSpacing: 1.1,
      ),
    );
  }
}

class _FolderTile extends StatelessWidget {
  const _FolderTile({required this.folder, required this.onPlay});

  final LessonFolder folder;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final count = folder.itemRefs.length;
    return Material(
      color: Colors.white.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onPlay,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            children: [
              const Icon(Icons.folder_rounded, color: AppColors.goldSoft, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      folder.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '$count module${count == 1 ? '' : 's'}',
                      style: const TextStyle(fontSize: 10.5, color: Colors.white54),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.play_circle_fill_rounded,
                color: AppColors.mintGreen,
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({required this.game, required this.onTap});

  final CastGame game;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sessions = game.sessions.length;
    return Material(
      color: const Color(0xFF1B3D4E),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('cast-game-${game.type.name}'),
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(game.cover, fit: BoxFit.cover, cacheWidth: 360),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.35, 1],
                  colors: [Color(0x00000000), Color(0xE6081A22)],
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                ),
                child: Text(game.emoji, style: const TextStyle(fontSize: 15)),
              ),
            ),
            if (sessions > 1)
              Positioned(
                top: 10,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$sessions sessions',
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 8,
              child: Text(
                game.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
