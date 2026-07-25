import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Currently active Learner Hub tab (Home/Backpack/Profile) — updated by
/// `HubShell._switchTo`. `HubShell` uses `StatefulNavigationShell`'s
/// `IndexedStack`, which only hides/shows each branch rather than
/// disposing and remounting it, so `AdventureMapScreen`'s own
/// `initState`/`build` never rerun on a tab switch. It watches this
/// instead to notice every time it becomes the visible tab again.
class ActiveHubTabIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void set(int index) => state = index;
}

final activeHubTabIndexProvider =
    NotifierProvider<ActiveHubTabIndexNotifier, int>(
      ActiveHubTabIndexNotifier.new,
    );
