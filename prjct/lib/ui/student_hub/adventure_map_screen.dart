import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../logic/auth/session.dart';
import '../../logic/learner/noor_energy_provider.dart';
import '../../logic/recent_module_provider.dart';
import '../../logic/teacher/teacher_providers.dart';
import '../core_modules/module_registry.dart';
import '../teacher_dashboard/teacher_dashboard_screen.dart' show progressionOverrideProvider;
import '../theme/app_colors.dart';
import 'adventure_map_top_bar.dart';
import 'noor_energy_resting_sheet.dart';

/// Matches module ids to the free-text module names teachers pick when
/// assigning homework — same matching rules `StudentHubScreen` used before
/// this screen replaced it (kept in sync here since assignment gating is
/// still module-name-based on the teacher side).
bool _doesModuleNameMatchId(String name, String id) {
  final cleanName = name.toLowerCase();
  return switch (id) {
    'tracing' => cleanName.contains('tracing') || cleanName.contains('alif'),
    'flashcards' =>
      cleanName.contains('song') ||
          cleanName.contains('practice') ||
          cleanName.contains('flashcards') ||
          cleanName.contains('sounds'),
    'recitation' =>
      cleanName.contains('recitation') ||
          cleanName.contains('pronunciation') ||
          cleanName.contains('ج') ||
          cleanName.contains('qur\'an') ||
          cleanName.contains('hadith'),
    'sorting' =>
      cleanName.contains('sequence') ||
          cleanName.contains('matcher') ||
          cleanName.contains('sort') ||
          cleanName.contains('match'),
    'stories' => cleanName.contains('stories') || cleanName.contains('story'),
    _ => false,
  };
}

// Final positions recorded from the approved Task 7 HTML preview
// (dumps/adventure_map_preview/preview.html, bg 2.png background,
// 390x1821 canvas). Fraction of the background image's height, 0=top
// 1=bottom.
const _nodePositions = <String, double>{
  'tracing': 0.824, // top: 1500px of 1821px canvas
  'flashcards': 0.620, // top: 1130px — "Sounds"
  'recitation': 0.439, // top: 800px — "Qur'an & Hadith" (current, approved)
  'stories': 0.258, // top: 470px
  'sorting': 0.077, // top: 140px — locked this phase
};

class AdventureMapScreen extends ConsumerStatefulWidget {
  const AdventureMapScreen({super.key});

  @override
  ConsumerState<AdventureMapScreen> createState() =>
      _AdventureMapScreenState();
}

class _AdventureMapScreenState extends ConsumerState<AdventureMapScreen> {
  final _scrollController = ScrollController();
  static const _mapHeight = 1800.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final currentId = ref.read(recentModuleProvider) ?? 'tracing';
      final fraction = _nodePositions[currentId] ?? 0.5;
      final target = (_mapHeight * fraction) - 300;
      _scrollController.jumpTo(target.clamp(0, _mapHeight));
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Same rule `StudentHubScreen` used before this screen replaced it, with
  /// its always-true fallthrough bug fixed: a module only unlocks when the
  /// debug override is on, or a teacher has actually assigned it (per class
  /// homework or this student's own assignment list) — otherwise it's
  /// locked, matching the "Locked by ustadzah" messaging learners already
  /// know from the old Home tab.
  bool _isModuleAssigned(String moduleId) {
    final override = ref.watch(progressionOverrideProvider);
    if (override) return true;

    final classHomeworks = ref.watch(classHomeworkProvider);
    final isClassAssigned = classHomeworks.any((hw) {
      final moduleName = hw['module'] as String? ?? '';
      return _doesModuleNameMatchId(moduleName, moduleId);
    });
    if (isClassAssigned) return true;

    final learner = ref.watch(sessionProvider).learner;
    if (learner != null) {
      final students = ref.watch(teacherRosterProvider);
      final currentStudent = students.firstWhere(
        (s) => s['learnerId'] == learner.id,
        orElse: () => <String, dynamic>{},
      );
      final studentAssigned =
          currentStudent['assignedModules'] as List<dynamic>? ?? [];
      final isStudentAssigned = studentAssigned.any((hw) {
        final moduleText = hw as String? ?? '';
        return _doesModuleNameMatchId(moduleText, moduleId);
      });
      if (isStudentAssigned) return true;
    }
    return false;
  }

  void _showLockedDialog(String moduleTitle) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.lock_outline_rounded,
          color: AppColors.coral,
          size: 44,
        ),
        title: Text('$moduleTitle is Locked'),
        content: const Text(
          'This module is not currently assigned by your teacher. Please ask your teacher or parent to assign it to you!',
        ),
        actions: [
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _onNodeTap(ModuleInfo module) {
    if (!_isModuleAssigned(module.id)) {
      _showLockedDialog(module.title);
      return;
    }
    final energy = ref.read(noorEnergyProvider);
    if (!energy.hasEnergy) {
      showNoorEnergyRestingSheet(context);
      return;
    }
    ref.read(noorEnergyProvider.notifier).consume();
    ref.read(recentModuleProvider.notifier).interactWith(module.id);
    context.go('/module/${module.id}');
  }

  @override
  Widget build(BuildContext context) {
    final currentId = ref.watch(recentModuleProvider) ?? 'tracing';

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _scrollController,
            child: SizedBox(
              height: _mapHeight,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      'assets/images/adventure_map/map_background.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                  for (final module in coreModules)
                    _MapNode(
                      module: module,
                      topFraction: _nodePositions[module.id] ?? 0.5,
                      mapHeight: _mapHeight,
                      isCurrent: module.id == currentId,
                      isAssigned: _isModuleAssigned(module.id),
                      onTap: () => _onNodeTap(module),
                    ),
                  _MascotAvatar(
                    topFraction: _nodePositions[currentId] ?? 0.5,
                    mapHeight: _mapHeight,
                  ),
                ],
              ),
            ),
          ),
          const SafeArea(child: AdventureMapTopBar()),
        ],
      ),
    );
  }
}

class _MapNode extends StatelessWidget {
  const _MapNode({
    required this.module,
    required this.topFraction,
    required this.mapHeight,
    required this.isCurrent,
    required this.isAssigned,
    required this.onTap,
  });

  final ModuleInfo module;
  final double topFraction;
  final double mapHeight;
  final bool isCurrent;
  final bool isAssigned;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final size = isCurrent ? 76.0 : 62.0;
    final color = isAssigned ? module.color : AppColors.textMuted;
    return Positioned(
      top: mapHeight * topFraction - size / 2,
      left: 130, // matches the approved Task 7 preview's .node { left: 130px }
      child: Semantics(
        button: true,
        label: isAssigned
            ? '${module.title} module'
            : '${module.title} module, locked by teacher',
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.16),
                border: Border.all(color: color, width: 4),
                boxShadow: isCurrent
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.4),
                          blurRadius: 16,
                          spreadRadius: 4,
                        ),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isAssigned ? module.icon : Icons.lock_rounded,
                        color: color,
                      ),
                      Text(
                        module.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
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

class _MascotAvatar extends StatelessWidget {
  const _MascotAvatar({required this.topFraction, required this.mapHeight});

  final double topFraction;
  final double mapHeight;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: mapHeight * topFraction - 120,
      left: 66, // sits just left of the node badge, matching the approved preview
      child: SizedBox(
        width: 60,
        height: 60,
        child: Lottie.asset('assets/lottie/owl_idle.json', repeat: true),
      ),
    );
  }
}
