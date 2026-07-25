import 'dart:async';

import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../logic/learner/learner_xp_provider.dart';
import '../../logic/learner/noor_energy_provider.dart';
import '../../logic/recent_module_provider.dart';
import '../theme/app_colors.dart';
import 'noor_energy_info_sheet.dart';
import 'tutorial/tutorial_anchors.dart';

/// Pill-style stat row replacing the Learner Hub's previous plain header —
/// see the Adventure Map design spec's "TopBar" section. Shown across the
/// Learner Hub via `HubShell`.
class AdventureMapTopBar extends ConsumerWidget {
  const AdventureMapTopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(learnerStreakProvider);
    final xp = ref.watch(learnerXpProvider);
    final energy = ref.watch(noorEnergyProvider);
    final anchors = ref.watch(tutorialAnchorsProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _Pill(
            key: anchors.streakPillKey,
            index: 0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.local_fire_department,
                  size: 16,
                  color: AppColors.coral,
                ),
                const SizedBox(width: 4),
                Text(
                  '$streak',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.coral,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          _Pill(
            index: 1,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded, size: 16, color: AppColors.gold),
                const SizedBox(width: 4),
                Text(
                  '$xp',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.gold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          _Pill(
            key: anchors.energyPillKey,
            index: 2,
            onTap: () => showNoorEnergyInfoSheet(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < energy.maxEnergy; i++) ...[
                  if (i > 0) const SizedBox(width: 2),
                  _Lantern(lit: i < energy.current),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatefulWidget {
  const _Pill({super.key, required this.index, required this.child, this.onTap});

  final int index;
  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_Pill> createState() => _PillState();
}

class _PillState extends State<_Pill> with SingleTickerProviderStateMixin {
  late final _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  Timer? _entranceTimer;

  @override
  void initState() {
    super.initState();
    _entranceTimer = Timer(Duration(milliseconds: 40 + widget.index * 50), () {
      if (mounted) _entrance.forward();
    });
  }

  @override
  void dispose() {
    _entranceTimer?.cancel();
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _entrance,
      builder: (context, child) {
        final t = const Cubic(0.34, 1.56, 0.64, 1.0).transform(_entrance.value);
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.scale(scale: 0.6 + 0.4 * t, child: child),
        );
      },
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.creamBorder, width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// A single Noor Energy lantern. Lit lanterns flicker gently (2200ms) —
/// unlit ("spent") ones sit dim and still.
class _Lantern extends StatefulWidget {
  const _Lantern({required this.lit});

  final bool lit;

  @override
  State<_Lantern> createState() => _LanternState();
}

class _LanternState extends State<_Lantern>
    with SingleTickerProviderStateMixin {
  late final _flicker = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  @override
  void initState() {
    super.initState();
    if (widget.lit) _flicker.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _Lantern oldWidget) {
    super.didUpdateWidget(oldWidget);
    // `AdventureMapTopBar` rebuilds this list with no keys, so Flutter
    // reuses each `_LanternState` by position as `noorEnergyProvider`
    // changes (e.g. right after `_onNodeTap` consumes one, or after the
    // daily reset restores them) — without this, a lantern that goes
    // lit->unlit keeps flickering forever with no visible effect, and one
    // that goes unlit->lit never starts.
    if (oldWidget.lit != widget.lit) {
      if (widget.lit) {
        _flicker.repeat(reverse: true);
      } else {
        _flicker.stop();
        _flicker.value = 0;
      }
    }
  }

  @override
  void dispose() {
    _flicker.dispose();
    super.dispose();
  }

  static const _asset = 'assets/images/noor_energy_moon.png';

  @override
  Widget build(BuildContext context) {
    if (!widget.lit) {
      return const Opacity(
        opacity: 0.28,
        child: Image(
          image: AssetImage(_asset),
          width: 16,
          height: 16,
        ),
      );
    }
    return AnimatedBuilder(
      animation: _flicker,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_flicker.value);
        return Transform.scale(scale: 1 + 0.12 * t, child: child);
      },
      child: const Image(
        image: AssetImage(_asset),
        width: 16,
        height: 16,
      ),
    );
  }
}
