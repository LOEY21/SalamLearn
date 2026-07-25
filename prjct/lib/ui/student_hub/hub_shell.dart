import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../logic/auth/session.dart';
import '../../logic/learner/hub_tab_provider.dart';
import '../../logic/learner/map_zoom_provider.dart';
import '../../logic/recent_module_provider.dart';
import '../theme/app_colors.dart';
import 'adventure_map_bottom_nav.dart';
import 'hub_bottom_nav.dart';
import 'tutorial/tutorial_anchors.dart';

/// Shell for the Home / Backpack / Profile tabs, backing
/// `StatefulShellRoute.indexedStack` in the router. Each branch's
/// Navigator (and therefore its scroll position, animation controllers,
/// selected range, etc.) stays alive underneath an `IndexedStack` — tabs
/// never rebuild on switch, only the visible one changes. A brief fade
/// gives the switch a soft crossfade instead of an instant, jarring cut.
class HubShell extends ConsumerStatefulWidget {
  const HubShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<HubShell> createState() => _HubShellState();
}

class _HubShellState extends ConsumerState<HubShell> {
  static const _fadeDuration = Duration(milliseconds: 140);
  double _opacity = 1;

  @override
  void initState() {
    super.initState();
    // Only the Learner Hub goes fullscreen immersive (locked-down child
    // experience, no system chrome to accidentally exit through) — Parent
    // and Teacher screens keep the normal status/nav bars (see main.dart's
    // default). Restored on dispose so leaving the hub (PIN gate, role
    // switch, etc.) doesn't leave Parent/Teacher stuck in immersive mode.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _switchTo(int index) {
    if (index == widget.navigationShell.currentIndex) return;
    setState(() => _opacity = 0);
    Future.delayed(_fadeDuration, () {
      widget.navigationShell.goBranch(index);
      ref.read(activeHubTabIndexProvider.notifier).set(index);
      if (mounted) setState(() => _opacity = 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final learnerAvatar = ref.watch(sessionProvider).learner?.avatar;
    final hasNewBackpackItem =
        ref.watch(unlockedBadgesProvider).length >
        ref.watch(seenBadgeCountProvider);
    // Mirrors `AdventureMapScreen`'s own top-bar fade so both chrome layers
    // clear out together while the learner pinch-zooms the map (in either
    // direction), and come back together on release.
    final chromeFade = ref.watch(mapZoomProvider);
    final anchors = ref.watch(tutorialAnchorsProvider);
    // PopScope blocks the system back gesture: the learner cannot exit
    // to role selection without a grown-up (role lock requirement) — this
    // now guards all 4 tabs uniformly since they share this one Scaffold.
    return PopScope(
      canPop: false,
      child: Scaffold(
        // Was `Colors.white`: every tab's real background is cream-toned
        // (AppColors.cream/neutralTint), so during the crossfade dip below
        // the white showed through as a one-frame flash against them.
        // Matching the shared cream tone here makes the fade genuinely
        // invisible instead of a colour pop on every tab switch.
        backgroundColor: AppColors.cream,
        // The floating pill nav reserves no opaque strip of its own — it
        // floats with margin over whatever's beneath it. Without
        // `extendBody`, Scaffold shortens `body` to end right above it,
        // which on Home cuts the scrollable Adventure Map short well
        // before its actual bottom. `extendBody: true` lets each tab's
        // content draw the full screen height; the map screen itself adds
        // matching bottom padding so its own real content doesn't end up
        // permanently hidden under the nav bar.
        extendBody: true,
        body: AnimatedOpacity(
          duration: _fadeDuration,
          curve: Curves.easeOut,
          opacity: _opacity,
          child: widget.navigationShell,
        ),
        bottomNavigationBar: IgnorePointer(
          ignoring: chromeFade < 0.5,
          child: Opacity(
            opacity: chromeFade,
            child: Transform.translate(
              offset: Offset(0, 16 * (1 - chromeFade)),
              child: SafeArea(
                child: AdventureMapBottomNav(
                  active: HubTab.values[widget.navigationShell.currentIndex],
                  onHomeTap: () => _switchTo(0),
                  onBackpackTap: () => _switchTo(1),
                  onProfileTap: () => _switchTo(2),
                  learnerAvatar: learnerAvatar,
                  showBackpackBadge: hasNewBackpackItem,
                  backpackKey: anchors.backpackTabKey,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
