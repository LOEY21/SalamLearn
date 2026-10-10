import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:salamlearn/logic/localization/app_translations.dart';

import '../../data/models/lesson_folder.dart';
import '../../data/repositories/lesson_folder_repository.dart';
import '../../logic/teacher/teacher_providers.dart';
import '../theme/app_colors.dart';
import '../widgets/hub_kit.dart';

/// FR-6.8 Custom Lesson Builder — entry screen listing the active class's
/// saved lesson folders (each an ordered sequence of existing curriculum
/// modules), with a way to create a new one. Reached from the teacher
/// dashboard's Home-tab "Class tools". Built on the hub kit's sub-page
/// frame, matching the Teacher Hub.
class ModuleLibraryScreen extends ConsumerWidget {
  const ModuleLibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeClass = ref.watch(teacherClassControllerProvider);
    final folderCount = activeClass == null
        ? 0
        : ref.watch(classLessonFoldersProvider(activeClass.id)).length;

    return HubSubpage(
      header: HubSubpageHeader(
        title: 'Module Library',
        subtitle:
            'Sequence curriculum modules into lesson folders to '
            'present in class.',
        onBack: () => context.pop(),
        bottom: activeClass == null
            ? null
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  HubHeaderChip(
                    icon: Icons.groups_outlined,
                    label: activeClass.name,
                  ),
                  HubHeaderChip(
                    icon: Icons.folder_copy_outlined,
                    label: '$folderCount folder${folderCount == 1 ? '' : 's'}',
                  ),
                ],
              ),
      ),
      body: HubListBody(
        children: [
          if (activeClass == null)
            HubEmptyState(
              icon: Icons.folder_open_outlined,
              title: 'Create a class first',
              message: 'Lesson folders are scoped to one class at a time.',
              action: FilledButton(
                onPressed: () => context.go('/teacher/classes'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  minimumSize: const Size(64, 48),
                  shape: const StadiumBorder(),
                ),
                child: const Text('Go to Classroom'),
              ),
            )
          else
            _FolderList(classId: activeClass.id),
        ],
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
        content: Text(
          '"${folder.name}" will be removed. This can\'t be undone.',
        ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const HubSectionLabel('Lesson folders'),
        if (folders.isEmpty)
          const HubEmptyState(
            icon: Icons.folder_copy_outlined,
            title: 'Start your first folder',
            message:
                'No lesson folders yet. Sequence a few modules into one below '
                'to speed up how you present class content.',
          )
        else
          HubRowSheet(
            children: [
              for (final folder in folders)
                InkWell(
                  onTap: () => context.push(
                    '/teacher/module-library/builder?folderId=${folder.id}',
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 60),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 10, 6, 10),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.folder_copy_outlined,
                            color: AppColors.gold,
                            size: 22,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                HubFitText(
                                  folder.name,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.ink,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${folder.itemRefs.length} module'
                                  '${folder.itemRefs.length == 1 ? '' : 's'}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.inkSoft,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Delete folder'.tr,
                            onPressed: () =>
                                _confirmDelete(context, ref, folder),
                            icon: const Icon(
                              Icons.delete_outline,
                              size: 22,
                              color: AppColors.coral,
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 22,
                            color: AppColors.inkSoft,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => context.push('/teacher/module-library/builder'),
          icon: const Icon(Icons.add_rounded),
          label: const Text('New lesson folder'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.teal,
            minimumSize: const Size(64, 52),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
