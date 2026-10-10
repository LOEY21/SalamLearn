import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:salamlearn/logic/localization/app_translations.dart';

import '../../data/models/curriculum/curriculum_models.dart';
import '../../data/repositories/lesson_folder_repository.dart';
import '../../logic/auth/session.dart';
import '../../logic/teacher/teacher_providers.dart';
import '../theme/app_colors.dart';
import '../widgets/child_profile_form.dart'
    show
        ChildFieldLabel,
        ChildFormBottomBar,
        ChildFormButton,
        ChildTextField,
        scaledExtent;
import '../widgets/hub_kit.dart';
import 'cast_games.dart';
import 'module_library_data.dart';

/// FR-6.8 Custom Lesson Builder — pick pre-existing modules from the 12
/// curriculum games, sequence them into an ordered timeline, and save the
/// sequence into a named folder. Reached from `module_library_screen.dart`.
/// Built on the hub kit's sub-page frame; the timeline sits beside the
/// library from tablet-landscape widths.
class LessonFolderBuilderScreen extends ConsumerStatefulWidget {
  const LessonFolderBuilderScreen({super.key, this.folderId});

  final String? folderId;

  @override
  ConsumerState<LessonFolderBuilderScreen> createState() =>
      _LessonFolderBuilderScreenState();
}

class _LessonFolderBuilderScreenState
    extends ConsumerState<LessonFolderBuilderScreen> {
  final _nameC = TextEditingController();
  // Rebuilds on focus change so the example hint clears as soon as the
  // field is tapped, not only once the teacher starts typing.
  late final _nameFocus = FocusNode()..addListener(() => setState(() {}));
  final List<String> _order = [];
  final Set<ActivityType> _expandedGames = {castGames.first.type};

  @override
  void initState() {
    super.initState();
    final existing = widget.folderId == null
        ? null
        : LessonFolderRepository().findById(widget.folderId!);
    if (existing != null) {
      _nameC.text = existing.name;
      _order.addAll(existing.itemRefs);
    }
  }

  @override
  void dispose() {
    _nameC.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _toggle(ModuleRef module) {
    setState(() {
      if (_order.contains(module.ref)) {
        _order.remove(module.ref);
      } else {
        _order.add(module.ref);
      }
    });
  }

  void _toggleAllInGame(CastGame game) {
    final allAdded = game.sessions.every((s) => _order.contains(s.ref));
    setState(() {
      if (allAdded) {
        for (final s in game.sessions) {
          _order.remove(s.ref);
        }
      } else {
        for (final s in game.sessions) {
          if (!_order.contains(s.ref)) {
            _order.add(s.ref);
          }
        }
      }
    });
  }

  void _remove(String ref) => setState(() => _order.remove(ref));

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex -= 1;
      final item = _order.removeAt(oldIndex);
      _order.insert(newIndex, item);
    });
  }

  Future<void> _save() async {
    final name = _nameC.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please name this lesson folder')),
      );
      return;
    }
    final teacherId = ref.read(sessionProvider).activeTeacherId;
    final classId = ref.read(teacherClassControllerProvider)?.id;
    if (teacherId == null || classId == null) return;

    final repo = LessonFolderRepository();
    final existing = widget.folderId == null
        ? null
        : repo.findById(widget.folderId!);
    if (existing != null) {
      await repo.update(folder: existing, name: name, itemRefs: _order);
    } else {
      await repo.create(
        classId: classId,
        teacherId: teacherId,
        name: name,
        itemRefs: _order,
      );
    }
    ref.invalidate(classLessonFoldersProvider(classId));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Lesson folder saved!')));
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.folderId != null;

    return HubSubpage(
      header: HubSubpageHeader(
        title: isEditing ? 'Edit Lesson Folder' : 'Build Lesson Folder',
        subtitle: 'Pick sessions from the 12 games, then put them in order.',
        onBack: () => context.pop(),
        bottom: Align(
          alignment: Alignment.centerLeft,
          child: _SelectedCountPill(count: _order.length),
        ),
      ),
      bottomBar: ChildFormBottomBar(
        children: [
          ChildFormButton(
            label: 'Save lesson folder',
            icon: Icons.check_rounded,
            onPressed: _save,
          ),
        ],
      ),
      body: HubTabBody(
        left: [
          const ChildFieldLabel('Folder name'),
          ChildTextField(
            controller: _nameC,
            focusNode: _nameFocus,
            hint: _nameFocus.hasFocus ? null : 'e.g. Week 4: Wudhu',
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: 8),
          const HubSectionLabel('Module library · 12 games'),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Text(
              'Open a game to pick its sessions for your lesson timeline.',
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: AppColors.inkSoft,
              ),
            ),
          ),
          for (final game in castGames)
            _GameAccordion(
              game: game,
              expanded: _expandedGames.contains(game.type),
              selectedRefs: _order,
              onToggleExpand: () {
                setState(() {
                  if (_expandedGames.contains(game.type)) {
                    _expandedGames.remove(game.type);
                  } else {
                    _expandedGames.add(game.type);
                  }
                });
              },
              onToggleSession: _toggle,
              onToggleAll: () => _toggleAllInGame(game),
            ),
        ],
        right: [
          const HubSectionLabel('Timeline'),
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Text(
              'Press and hold a session, then drag it to reorder.',
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: AppColors.inkSoft,
              ),
            ),
          ),
          _Timeline(order: _order, onReorder: _reorder, onRemove: _remove),
        ],
      ),
    );
  }
}

/// Bumps with a spring "pop" every time [count] changes — a fresh
/// [TweenAnimationBuilder] instance restarts the tween on each new value
/// (keyed by the count itself), giving the replay-on-change effect without
/// needing a manually-managed [AnimationController].
class _SelectedCountPill extends StatelessWidget {
  const _SelectedCountPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(count),
      tween: Tween(begin: 1.18, end: 1.0),
      duration: const Duration(milliseconds: 260),
      curve: Curves.elasticOut,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: HubHeaderChip(
        icon: Icons.check_circle_rounded,
        label: '$count selected',
      ),
    );
  }
}

class _GameAccordion extends StatelessWidget {
  const _GameAccordion({
    required this.game,
    required this.expanded,
    required this.selectedRefs,
    required this.onToggleExpand,
    required this.onToggleSession,
    required this.onToggleAll,
  });

  final CastGame game;
  final bool expanded;
  final List<String> selectedRefs;
  final VoidCallback onToggleExpand;
  final ValueChanged<ModuleRef> onToggleSession;
  final VoidCallback onToggleAll;

  @override
  Widget build(BuildContext context) {
    final style = activityTypeStyles[game.type]!;
    final totalSessions = game.sessions.length;
    final selectedCount = game.sessions
        .where((s) => selectedRefs.contains(s.ref))
        .length;
    final allSelected = selectedCount == totalSessions && totalSessions > 0;
    final iconAsset = gameIconAssetFor(game.type);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selectedCount > 0 ? AppColors.teal : AppColors.creamBorder,
            width: selectedCount > 0 ? 1.6 : 1.2,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                key: ValueKey('game-accordion-${game.type.name}'),
                onTap: onToggleExpand,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: style.bg,
                        ),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.all(5),
                        child: iconAsset != null
                            ? Image.asset(iconAsset, fit: BoxFit.contain)
                            : Text(
                                game.emoji,
                                style: const TextStyle(fontSize: 22),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            HubFitText(
                              game.name,
                              style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$totalSessions session${totalSessions == 1 ? '' : 's'} · ${style.label}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.inkSoft,
                              ),
                            ),
                            if (selectedCount > 0) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.mint,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '$selectedCount of $totalSessions added',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.tealDark,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      AnimatedRotation(
                        turns: expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 26,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (expanded) ...[
                const Divider(height: 1, color: AppColors.creamBorder),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 8, 2),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      Text(
                        'Sessions (${game.sessions.length})',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(0, 44),
                          foregroundColor: AppColors.teal,
                          textStyle: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        onPressed: onToggleAll,
                        icon: Icon(
                          allSelected
                              ? Icons.remove_circle_outline
                              : Icons.add_circle_outline,
                          size: 18,
                        ),
                        label: Text(allSelected ? 'Remove all' : 'Select all'),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Tiles size to their text; columns drop as space or
                      // text size runs out.
                      final scaled = scaledExtent(
                        context,
                        constraints.maxWidth,
                      );
                      final columns = scaled >= 520
                          ? 3
                          : scaled >= 280
                          ? 2
                          : 1;
                      const gap = 8.0;
                      final tileWidth =
                          (constraints.maxWidth - gap * (columns - 1)) /
                          columns;
                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: [
                          for (final session in game.sessions)
                            SizedBox(
                              width: tileWidth,
                              child: _ModuleTile(
                                module: session,
                                added: selectedRefs.contains(session.ref),
                                orderIndex: selectedRefs.contains(session.ref)
                                    ? selectedRefs.indexOf(session.ref)
                                    : null,
                                onTap: () => onToggleSession(session),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A picked module tile *is* the selection feedback (per the approved
/// mock, dumps/lesson_tile_select_motion_mock.html): a quick press-in
/// scale on tap-down, then a smooth 220ms cross-fade to the selected
/// color/border/shadow, with badges fading + scaling in at 180ms. No
/// bounce, no burst ring, no icon rotation.
class _ModuleTile extends StatefulWidget {
  const _ModuleTile({
    required this.module,
    required this.added,
    required this.orderIndex,
    required this.onTap,
  });

  final ModuleRef module;
  final bool added;

  /// This module's position in the timeline, or null if not added — drives
  /// the gold order-number badge.
  final int? orderIndex;
  final VoidCallback onTap;

  @override
  State<_ModuleTile> createState() => _ModuleTileState();
}

class _ModuleTileState extends State<_ModuleTile> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final module = widget.module;
    final added = widget.added;
    final orderIndex = widget.orderIndex;
    final style = activityTypeStyles[module.activity.type]!;
    final iconAsset = gameIconAssetFor(module.activity.type);

    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: ValueKey('library-module-tile-${module.ref}'),
            borderRadius: BorderRadius.circular(16),
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: added ? AppColors.mint : AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: added ? AppColors.teal : AppColors.creamBorder,
                  width: 1.4,
                ),
                boxShadow: added
                    ? [
                        BoxShadow(
                          color: AppColors.teal.withValues(alpha: 0.18),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: added ? Colors.white : style.bg,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        alignment: Alignment.center,
                        child: iconAsset != null
                            ? Padding(
                                padding: const EdgeInsets.all(4),
                                child: Image.asset(
                                  iconAsset,
                                  fit: BoxFit.contain,
                                ),
                              )
                            : Icon(style.icon, size: 18, color: style.color),
                      ),
                      const SizedBox(height: 10),
                      HubFitText(
                        module.activity.title,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      HubFitText(
                        '${module.destinationName} · ${style.label}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.3,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: AnimatedOpacity(
                      opacity: added ? 1 : 0,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      child: AnimatedScale(
                        scale: added ? 1 : 0.6,
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: style.color,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.check,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    child: AnimatedOpacity(
                      opacity: orderIndex != null ? 1 : 0,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      child: AnimatedScale(
                        scale: orderIndex != null ? 1 : 0.6,
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: AppColors.gold,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          alignment: Alignment.center,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '${(orderIndex ?? 0) + 1}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({
    required this.order,
    required this.onReorder,
    required this.onRemove,
  });

  final List<String> order;
  final void Function(int oldIndex, int newIndex) onReorder;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    if (order.isEmpty) {
      return const HubEmptyState(
        icon: Icons.view_timeline_outlined,
        title: 'Nothing here yet',
        message: 'Tap sessions in the library to add them here.',
      );
    }

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: order.length,
      onReorder: onReorder,
      itemBuilder: (context, i) {
        final ref = order[i];
        final module = resolveModuleRef(ref);
        return Padding(
          key: ValueKey(ref),
          padding: const EdgeInsets.only(bottom: 8),
          child: ReorderableDelayedDragStartListener(
            index: i,
            child: _TimelineRowEntrance(
              child: _TimelineRow(
                index: i,
                module: module,
                onRemove: () => onRemove(ref),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Drop-in entrance for a freshly-added timeline row — mounted once per
/// `ValueKey(ref)` in [_Timeline]'s `itemBuilder`, so [ReorderableListView]
/// preserves this widget's state (and skips the animation) across a drag
/// reorder, only replaying it for a module that's genuinely new.
class _TimelineRowEntrance extends StatefulWidget {
  const _TimelineRowEntrance({required this.child});

  final Widget child;

  @override
  State<_TimelineRowEntrance> createState() => _TimelineRowEntranceState();
}

class _TimelineRowEntranceState extends State<_TimelineRowEntrance>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  )..forward();
  late final _fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);
  late final _slide = Tween<Offset>(
    begin: const Offset(0, -0.2),
    end: Offset.zero,
  ).animate(_fade);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.index,
    required this.module,
    required this.onRemove,
  });

  final int index;
  final ModuleRef? module;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final style = module == null
        ? null
        : activityTypeStyles[module!.activity.type];
    final iconAsset = module == null
        ? null
        : gameIconAssetFor(module!.activity.type);
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.creamBorder, width: 1.2),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Narrow rows / large text keep just the number and the title;
          // the whole row still long-press drags.
          final compact = scaledExtent(context, constraints.maxWidth) < 330;
          return Row(
            children: [
              if (!compact) ...[
                const Icon(Icons.drag_indicator, color: AppColors.inkSoft),
                const SizedBox(width: 6),
              ],
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ),
              if (!compact) ...[
                const SizedBox(width: 10),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: style?.bg ?? AppColors.mint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: iconAsset != null
                      ? Padding(
                          padding: const EdgeInsets.all(4),
                          child: Image.asset(iconAsset, fit: BoxFit.contain),
                        )
                      : Icon(
                          style?.icon ?? Icons.help_outline,
                          size: 18,
                          color: style?.color ?? AppColors.inkSoft,
                        ),
                ),
              ],
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HubFitText(
                      module?.activity.title ?? 'Module no longer available',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    if (module != null)
                      HubFitText(
                        style?.label ?? '',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.inkSoft,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove'.tr,
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded, color: AppColors.coral),
              ),
            ],
          );
        },
      ),
    );
  }
}
