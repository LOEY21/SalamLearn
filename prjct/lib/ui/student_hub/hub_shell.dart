import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'adventure_map_bottom_nav.dart';
import 'hub_bottom_nav.dart';

/// Shell for the Home / Backpack / Profile tabs, backing
/// `StatefulShellRoute.indexedStack` in the router. Each branch's
/// Navigator (and therefore its scroll position, animation controllers,
/// selected range, etc.) stays alive underneath an `IndexedStack` — tabs
/// never rebuild on switch, only the visible one changes. A brief fade
/// gives the switch a soft crossfade instead of an instant, jarring cut.
class HubShell extends StatefulWidget {
  const HubShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<HubShell> createState() => _HubShellState();
}

class _HubShellState extends State<HubShell> {
  static const _fadeDuration = Duration(milliseconds: 140);
  double _opacity = 1;

  void _switchTo(int index) {
    if (index == widget.navigationShell.currentIndex) return;
    setState(() => _opacity = 0);
    Future.delayed(_fadeDuration, () {
      widget.navigationShell.goBranch(index);
      if (mounted) setState(() => _opacity = 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    // PopScope blocks the system back gesture: the learner cannot exit
    // to role selection without a grown-up (role lock requirement) — this
    // now guards all 4 tabs uniformly since they share this one Scaffold.
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: AnimatedOpacity(
          duration: _fadeDuration,
          curve: Curves.easeOut,
          opacity: _opacity,
          child: widget.navigationShell,
        ),
        bottomNavigationBar: SafeArea(
          child: AdventureMapBottomNav(
            active: HubTab.values[widget.navigationShell.currentIndex],
            onHomeTap: () => _switchTo(0),
            onBackpackTap: () => _switchTo(1),
            onProfileTap: () => _switchTo(2),
          ),
        ),
      ),
    );
  }
}
