import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/class_section.dart';
import '../../data/models/lesson_folder.dart';
import '../../data/repositories/lesson_folder_repository.dart';
import '../../logic/teacher/teacher_providers.dart';
import '../theme/app_colors.dart';
import '../widgets/soft_card.dart';

/// FR-6.8 Custom Lesson Builder — entry screen listing the active class's
/// saved lesson folders (each an ordered sequence of existing curriculum
/// modules), with a way to create a new one. Reached from the teacher
/// dashboard's Home-tab "Class tools" grid (see
/// `teacher_dashboard_screen.dart`'s `_ActionColumn`).
///
/// Flat appbar + mint hero-chip + SoftCard rows, matching the approved
/// top-tab dashboard mock (dumps/module_library_redesign_mock.html)
/// rather than the old teal AppBar on a cream background.
class ModuleLibraryScreen extends ConsumerWidget {
  const ModuleLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeClass = ref.watch(teacherClassControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _LibraryAppBar(onBack: () => context.pop()),
            if (activeClass != null) _LibraryChips(section: activeClass),
            const Divider(height: 1, color: AppColors.creamBorder),
            Expanded(
              child: activeClass == null
                  ? _NoClassState(onCreateClass: () => context.go('/teacher/classes'))
                  : _FolderList(classId: activeClass.id),
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryAppBar extends StatelessWidget {
  const _LibraryAppBar({required this.onBack});

  final VoidCallback onBack;

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
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'CUSTOM LESSON BUILDER',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: AppColors.textMuted,
                  ),
                ),
                Text(
                  'Module Library',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryChips extends ConsumerWidget {
  const _LibraryChips({required this.section});

  final ClassSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folderCount = ref.watch(classLessonFoldersProvider(section.id)).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          _HeroChip(icon: Icons.groups_outlined, value: section.name),
          _HeroChip(
            icon: Icons.folder_copy_outlined,
            value: '$folderCount folder${folderCount == 1 ? '' : 's'}',
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.mint,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.mintBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.tealDark),
          const SizedBox(width: 5),
          Text(
            value,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: AppColors.tealDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoClassState extends StatelessWidget {
  const _NoClassState({required this.onCreateClass});

  final VoidCallback onCreateClass;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.folder_open_outlined,
              size: 40,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 12),
            const Text(
              'Create a class first',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 6),
            const Text(
              'Lesson folders are scoped to one class at a time.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: onCreateClass,
              style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
              child: const Text('Go to Classroom'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FolderList extends ConsumerWidget {
  const _FolderList({required this.classId});

  final String classId;

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    LessonFolder folder,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete folder?'),
        content: Text('"${folder.name}" will be removed. This can\'t be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await LessonFolderRepository().delete(folder.id);
    ref.invalidate(classLessonFoldersProvider(classId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(classLessonFoldersProvider(classId));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        if (folders.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'No lesson folders yet. Sequence a few modules into one below '
              'to speed up how you present class content.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
            ),
          )
        else
          for (final folder in folders)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: SoftCard(
                padding: const EdgeInsets.all(13),
                radius: 16,
                onTap: () => context.push(
                  '/teacher/module-library/builder?folderId=${folder.id}',
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.goldTint,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.folder_copy_outlined,
                        color: AppColors.gold,
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            folder.name,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${folder.itemRefs.length} module'
                            '${folder.itemRefs.length == 1 ? '' : 's'}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(9),
                        onTap: () => _confirmDelete(context, ref, folder),
                        child: const SizedBox(
                          width: 30,
                          height: 30,
                          child: Icon(
                            Icons.delete_outline,
                            size: 15,
                            color: AppColors.coral,
                          ),
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => context.push('/teacher/module-library/builder'),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: AppColors.mint,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.teal, width: 1.6),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, color: AppColors.tealDark, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'New lesson folder',
                      style: TextStyle(
                        color: AppColors.tealDark,
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
