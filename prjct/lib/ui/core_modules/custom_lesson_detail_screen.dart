import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories/custom_lesson_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/soft_card.dart';

/// Read-only view of one teacher-authored freeform lesson (title +
/// instructions + body) — reached from the Student Hub's "From Your
/// Teacher" section. No interactive grading, matching the "freeform
/// lesson" scope this feature was built to (unlike the five core modules,
/// which have real mechanics).
class CustomLessonDetailScreen extends StatelessWidget {
  const CustomLessonDetailScreen({super.key, required this.lessonId});

  final String lessonId;

  @override
  Widget build(BuildContext context) {
    final lesson = CustomLessonRepository().findById(lessonId);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) context.go('/hub');
      },
      child: Scaffold(
        backgroundColor: AppColors.neutralTint,
        appBar: AppBar(
          title: Text(lesson?.title ?? 'Lesson'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/hub'),
          ),
        ),
        body: lesson == null
            ? const Center(
                child: Text(
                  'This lesson is no longer available.',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              )
            : SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (lesson.instructions.isNotEmpty)
                        SoftCard(
                          color: AppColors.goldTint,
                          borderColor: AppColors.goldSoft,
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.lightbulb_outline_rounded,
                                size: 20,
                                color: AppColors.gold,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  lesson.instructions,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.ink,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      SoftCard(
                        padding: const EdgeInsets.all(18),
                        child: Text(
                          lesson.body,
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.ink,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
