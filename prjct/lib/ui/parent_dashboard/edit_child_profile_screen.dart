import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/learner_profile.dart';
import '../../logic/auth/session.dart';
import '../theme/app_colors.dart';
import '../widgets/soft_card.dart';

/// Dedicated "Edit Child Profile" screen — split out of the Manage Profile
/// tab's inline card into its own route so editing a child isn't competing
/// for space with the child switcher, class-join section, and everything
/// else on that tab. Reached from the Manage Profile tab's compact entry
/// card; edits whichever learner is currently active (same as the card it
/// replaced), so switch children first via the tab's switcher if editing
/// a different one.
class EditChildProfileScreen extends ConsumerStatefulWidget {
  const EditChildProfileScreen({super.key});

  @override
  ConsumerState<EditChildProfileScreen> createState() => _EditChildProfileScreenState();
}

class _EditChildProfileScreenState extends ConsumerState<EditChildProfileScreen>
    with TickerProviderStateMixin {
  final _nameC = TextEditingController();
  final _gradeC = TextEditingController();
  final _usernameC = TextEditingController();
  late int _age;
  late String _avatar;

  late final AnimationController _mascotFloatController;

  @override
  void initState() {
    super.initState();
    _mascotFloatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (kIsWeb || !Platform.environment.containsKey('FLUTTER_TEST')) {
      _mascotFloatController.repeat(reverse: true);
    }
    _syncFrom(ref.read(sessionProvider).learner);
  }

  /// Repopulates the form from whichever learner is active at mount —
  /// this screen is only ever reached for one specific child at a time
  /// (unlike the old inline card, which had to resync on every switch
  /// since it stayed mounted underneath the switcher).
  void _syncFrom(LearnerProfile? p) {
    _nameC.text = p?.name ?? '';
    _age = p?.age ?? 7;
    _avatar = p?.avatar ?? 'boy_mascot';
    _gradeC.text = p?.gradeLevel ?? 'Grade 1';
    _usernameC.text = p?.username ?? '';
  }

  @override
  void dispose() {
    _nameC.dispose();
    _gradeC.dispose();
    _usernameC.dispose();
    _mascotFloatController.dispose();
    super.dispose();
  }

  void _goBack() => context.go('/parent');

  Future<void> _save(LearnerProfile learner) async {
    final name = _nameC.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name')),
      );
      return;
    }
    await ref.read(sessionProvider.notifier).updateLearnerProfile(
          name: name,
          age: _age,
          avatar: _avatar,
          gradeLevel: _gradeC.text.trim(),
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated successfully!')),
    );
  }

  void _confirmDelete(LearnerProfile learner) {
    final learnerId = learner.id;
    if (learnerId == null) return;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.warning_amber_rounded,
          color: AppColors.coral,
          size: 40,
        ),
        title: Text('Delete ${learner.name}\'s profile?'),
        content: const Text(
          'This permanently removes this child\'s profile and all their '
          'progress. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.coral),
            onPressed: () async {
              await ref.read(sessionProvider.notifier).deleteLearner(learnerId);
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${learner.name}\'s profile was deleted')),
              );
              context.go('/parent');
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final learner = ref.watch(sessionProvider.select((s) => s.learner));

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.neutralTint,
        appBar: AppBar(
          title: const Text('Edit Child Profile'),
          backgroundColor: Colors.white,
          foregroundColor: AppColors.ink,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _goBack,
          ),
        ),
        body: learner == null
            ? const Center(
                child: Text(
                  'No child profile selected.',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              )
            : SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: SoftCard(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _Label('Full Name'),
                            _Input(controller: _nameC, hint: 'e.g. Nurhana Ali'),
                            const SizedBox(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const _Label('Age'),
                                Text(
                                  '$_age years old',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.teal,
                                  ),
                                ),
                              ],
                            ),
                            Slider(
                              value: _age.toDouble(),
                              min: 5,
                              max: 11,
                              divisions: 6,
                              onChanged: (v) => setState(() => _age = v.round()),
                            ),
                            const SizedBox(height: 14),
                            const _Label('Grade Level'),
                            _Input(controller: _gradeC, hint: 'e.g. Grade 1'),
                            const SizedBox(height: 14),
                            const _Label('Username'),
                            _Input(controller: _usernameC, hint: 'e.g. nurhana_ali'),
                            const SizedBox(height: 14),
                            const _Label('Mascot Avatar'),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _AvatarSelectionCard(
                                    imagePath: 'assets/images/boy_mascot_full_body.jpg',
                                    label: 'Amir (Boy)',
                                    isSelected: _avatar == 'boy_mascot',
                                    themeColor: AppColors.teal,
                                    floatAnimation: _mascotFloatController,
                                    onTap: () => setState(() => _avatar = 'boy_mascot'),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: _AvatarSelectionCard(
                                    imagePath: 'assets/images/girl_mascot_full_body.jpg',
                                    label: 'Zara (Girl)',
                                    isSelected: _avatar == 'girl_mascot',
                                    themeColor: AppColors.gold,
                                    floatAnimation: _mascotFloatController,
                                    onTap: () => setState(() => _avatar = 'girl_mascot'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.teal,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () => _save(learner),
                              child: const Text('Save Changes'),
                            ),
                            const SizedBox(height: 20),
                            const Divider(height: 1, color: AppColors.creamBorder),
                            const SizedBox(height: 16),
                            Text(
                              'Danger Zone',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: AppColors.coral,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Permanently delete ${learner.name}\'s profile and '
                              'progress. This cannot be undone.',
                              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.coral,
                                side: const BorderSide(color: AppColors.coral),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.delete_outline_rounded, size: 18),
                              label: const Text('Delete Child Profile'),
                              onPressed: () => _confirmDelete(learner),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
    );
  }
}

class _Input extends StatelessWidget {
  const _Input({required this.controller, required this.hint});
  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.neutralTint,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.creamBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.creamBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.teal, width: 1.4),
        ),
      ),
    );
  }
}

class _AvatarSelectionCard extends StatelessWidget {
  const _AvatarSelectionCard({
    required this.imagePath,
    required this.label,
    required this.isSelected,
    required this.themeColor,
    required this.floatAnimation,
    required this.onTap,
  });

  final String imagePath;
  final String label;
  final bool isSelected;
  final Color themeColor;
  final Animation<double> floatAnimation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: isSelected ? 1.04 : 0.96,
        duration: const Duration(milliseconds: 250),
        curve: Curves.elasticOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? themeColor : AppColors.creamBorder,
              width: isSelected ? 3.0 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? themeColor.withValues(alpha: 0.12)
                    : const Color(0x06000000),
                blurRadius: isSelected ? 12 : 6,
                offset: Offset(0, isSelected ? 4 : 2),
              ),
            ],
          ),
          child: Column(
            children: [
              SizedBox(
                height: 100,
                child: AnimatedBuilder(
                  animation: floatAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(
                        0,
                        isSelected ? -5 * floatAnimation.value : 0,
                      ),
                      child: child,
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      imagePath,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: isSelected ? themeColor : AppColors.ink,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? themeColor : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? themeColor : AppColors.creamBorder,
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: isSelected
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 11,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
