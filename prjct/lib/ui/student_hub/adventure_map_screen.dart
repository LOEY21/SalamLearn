import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../logic/learner/noor_energy_provider.dart';
import '../../logic/recent_module_provider.dart';
import '../core_modules/module_registry.dart';
import '../theme/app_colors.dart';
import 'adventure_map_top_bar.dart';
import 'noor_energy_resting_sheet.dart';

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

  void _onNodeTap(String moduleId) {
    final energy = ref.read(noorEnergyProvider);
    if (!energy.hasEnergy) {
      showNoorEnergyRestingSheet(context);
      return;
    }
    ref.read(noorEnergyProvider.notifier).consume();
    ref.read(recentModuleProvider.notifier).interactWith(moduleId);
    context.go('/module/$moduleId');
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
                      onTap: () => _onNodeTap(module.id),
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
    required this.onTap,
  });

  final ModuleInfo module;
  final double topFraction;
  final double mapHeight;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final size = isCurrent ? 76.0 : 62.0;
    return Positioned(
      top: mapHeight * topFraction - size / 2,
      left: 130, // matches the approved Task 7 preview's .node { left: 130px }
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: module.color.withValues(alpha: 0.16),
            border: Border.all(color: module.color, width: 4),
            boxShadow: isCurrent
                ? [
                    BoxShadow(
                      color: module.color.withValues(alpha: 0.4),
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
                  Icon(module.icon, color: module.color),
                  Text(
                    module.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: module.color,
                      fontWeight: FontWeight.bold,
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
