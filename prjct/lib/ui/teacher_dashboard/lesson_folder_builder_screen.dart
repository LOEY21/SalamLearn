import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/curriculum/curriculum_models.dart';
import '../../data/repositories/lesson_folder_repository.dart';
import '../../logic/auth/session.dart';
import '../../logic/teacher/teacher_providers.dart';
import '../theme/app_colors.dart';
import 'module_library_data.dart';

/// FR-6.8 Custom Lesson Builder — pick pre-existing modules (tracing,
/// sorting, etc.) from the curriculum, sequence them into an ordered
/// timeline, and save the sequence into a named folder. Reached from
/// `module_library_screen.dart`; `folderId` is null when creating a new
/// folder, set when editing an existing one.
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
  final List<String> _order = [];
  ActivityType? _typeFilter;

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lesson folder saved!')),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.folderId != null;

    final visibleModules = _typeFilter == null
        ? allModuleRefs
        : allModuleRefs
              .where((m) => m.activity.type == _typeFilter)
              .toList();

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _BuilderAppBar(
              title: isEditing ? 'Edit Lesson Folder' : 'Build Lesson Folder',
              onBack: () => context.pop(),
              selectedCount: _order.length,
            ),
            const Divider(height: 1, color: AppColors.creamBorder),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                children: [
                  const _SectionLabel('Folder name'),
                  TextField(
                    controller: _nameC,
                    decoration: InputDecoration(
                      hintText: 'e.g. Week 4: Wudhu',
                      filled: true,
                      fillColor: AppColors.neutralTint,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.creamBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.teal,
                          width: 1.4,
                        ),
                      ),
                    ),
                  ),
                  const _SectionLabel('Module library'),
                  _TypeFilterChips(
                    selected: _typeFilter,
                    onSelect: (type) => setState(() => _typeFilter = type),
                  ),
                  const SizedBox(height: 4),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: visibleModules.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 9,
                      crossAxisSpacing: 9,
                      childAspectRatio: 1.35,
                    ),
                    itemBuilder: (context, i) {
                      final module = visibleModules[i];
                      final orderIndex = _order.indexOf(module.ref);
                      return _ModuleTile(
                        module: module,
                        added: orderIndex != -1,
                        orderIndex: orderIndex == -1 ? null : orderIndex,
                        onTap: () => _toggle(module),
                      );
                    },
                  ),
                  const _SectionLabel('Timeline (drag to reorder)'),
                  _Timeline(
                    order: _order,
                    onReorder: _reorder,
                    onRemove: _remove,
                  ),
                  const SizedBox(height: 90),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.teal,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Save lesson folder',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BuilderAppBar extends StatelessWidget {
  const _BuilderAppBar({
    required this.title,
    required this.onBack,
    required this.selectedCount,
  });

  final String title;
  final VoidCallback onBack;
  final int selectedCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 18, 4),
      child: Row(
        children: [
          Material(
            color: AppColors.neutralTint,
            borderRadius: BorderRadius.circular(11),
            child: InkWell(
              borderRadius: BorderRadius.circular(11),
              onTap: onBack,
              child: const SizedBox(
                width: 34,
                height: 34,
                child: Icon(
                  Icons.arrow_back_rounded,
                  size: 18,
                  color: AppColors.ink,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'CUSTOM LESSON BUILDER',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: AppColors.textMuted,
                  ),
                ),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _SelectedCountPill(count: selectedCount),
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.mint,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.mintBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, size: 12, color: AppColors.teal),
            const SizedBox(width: 5),
            Text(
              '$count selected',
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: AppColors.tealDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: AppColors.textMuted,
        ),
      ),
    );
  }
}

class _TypeFilterChips extends StatelessWidget {
  const _TypeFilterChips({required this.selected, required this.onSelect});

  final ActivityType? selected;
  final ValueChanged<ActivityType?> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _chip(context, null, 'All'),
          for (final type in activityTypeStyles.keys)
            _chip(context, type, activityTypeStyles[type]!.label),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, ActivityType? type, String label) {
    final isSelected = selected == type;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onSelect(type),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: isSelected ? Colors.white : AppColors.textMuted,
        ),
        selectedColor: AppColors.teal,
        backgroundColor: Colors.white,
        side: BorderSide(
          color: isSelected ? AppColors.teal : AppColors.creamBorder,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
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
            borderRadius: BorderRadius.circular(16),
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: added ? AppColors.mint : Colors.white,
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
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: added ? Colors.white : style.bg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Icon(style.icon, size: 16, color: style.color),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        module.activity.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${module.destinationName} · ${style.label}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textMuted,
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
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: style.color,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.check,
                            size: 13,
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
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: AppColors.gold,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${(orderIndex ?? 0) + 1}',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
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
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.creamBorder, width: 1.4),
        ),
        child: const Text(
          'Tap modules above to add them here, then drag to reorder.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
      );
    }

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: order.length,
      onReorder: onReorder,
      itemBuilder: (context, i) {
        final ref = order[i];
        final module = resolveModuleRef(ref);
        return Padding(
          key: ValueKey(ref),
          padding: const EdgeInsets.only(bottom: 8),
          child: _TimelineRowEntrance(
            child: _TimelineRow(
              index: i,
              module: module,
              onRemove: () => onRemove(ref),
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
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.creamBorder, width: 1.4),
      ),
      child: Row(
        children: [
          const Icon(Icons.drag_indicator, color: AppColors.creamBorder),
          const SizedBox(width: 6),
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: AppColors.gold,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: style?.bg ?? AppColors.mint,
              borderRadius: BorderRadius.circular(9),
            ),
            alignment: Alignment.center,
            child: Icon(
              style?.icon ?? Icons.help_outline,
              size: 14,
              color: style?.color ?? AppColors.textMuted,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  module?.activity.title ?? 'Module no longer available',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (module != null)
                  Text(
                    style?.label ?? '',
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onRemove,
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.close, size: 16, color: AppColors.coral),
            ),
          ),
        ],
      ),
    );
  }
}
