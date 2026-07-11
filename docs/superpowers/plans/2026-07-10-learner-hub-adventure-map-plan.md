# Learner Hub Adventure Map — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Learner Hub's module-grid Home tab with a scrollable illustrated Adventure Map (5 nodes over the supplied `bg 2.png` background), reskin the TopBar/BottomNav with a pill-stat/floating-nav visual language, and add two small new gameplay systems (XP and Noor Energy lives) that back the new stat pills.

**Architecture:** Two new Hive-backed Riverpod notifiers (`LearnerXpNotifier`, `NoorEnergyNotifier`) live in `lib/logic/learner/`, following this app's existing "thin Notifier over a Hive box key" pattern (same as `SessionNotifier`'s use of the `settings` box). The Adventure Map itself is a new screen (`lib/ui/student_hub/adventure_map_screen.dart`) that replaces `StudentHubScreen`'s body inside the existing `StatefulShellRoute` — routing, tab structure, and the downstream `/module/:id` screen are all unchanged; only the Home tab's presentation and the shared TopBar/BottomNav change.

**Tech Stack:** Flutter/Dart, Riverpod (`Notifier`/`NotifierProvider`), Hive (`settings` box, no new typed models needed), go_router (existing routes reused), bundled TTF fonts (no `google_fonts` package, per spec's offline-first requirement).

**Spec:** `docs/superpowers/specs/2026-07-10-learner-hub-adventure-map-design.md`

---

## Task 1: New AppColors tokens

**Files:**
- Modify: `prjct/lib/ui/theme/app_colors.dart`
- Test: `prjct/test/ui/theme/app_colors_test.dart` (new)

- [ ] **Step 1: Write the failing test**

```dart
// prjct/test/ui/theme/app_colors_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/ui/theme/app_colors.dart';

void main() {
  test('Adventure Map palette tokens have the spec-defined hex values', () {
    expect(AppColors.adventureBlue, const Color(0xFF72C9F8));
    expect(AppColors.adventurePurple, const Color(0xFF6C63D6));
    expect(AppColors.adventureGreen, const Color(0xFF5B9A1E));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd prjct && flutter test test/ui/theme/app_colors_test.dart`
Expected: FAIL — `AppColors.adventureBlue` (and the other two) undefined.

- [ ] **Step 3: Add the three tokens**

In `prjct/lib/ui/theme/app_colors.dart`, add inside `abstract final class AppColors { ... }`, after the existing `tealDark` line:

```dart
  // Adventure Map palette additions (2026-07-10 Learner Hub redesign spec).
  // Named `adventure*` to avoid colliding with the existing `mintGreen`
  // token, which is a different, already-used shade.
  static const adventureBlue = Color(0xFF72C9F8);
  static const adventurePurple = Color(0xFF6C63D6);
  static const adventureGreen = Color(0xFF5B9A1E);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd prjct && flutter test test/ui/theme/app_colors_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd prjct
git add lib/ui/theme/app_colors.dart test/ui/theme/app_colors_test.dart
git commit -m "Add Adventure Map palette tokens to AppColors"
```

---

## Task 2: LearnerXpNotifier (Hive-backed XP tracker)

**Files:**
- Create: `prjct/lib/logic/learner/learner_xp_provider.dart`
- Test: `prjct/test/logic/learner/learner_xp_provider_test.dart` (new)

`LearnerXpNotifier` reads/writes a single `int` under the `settings` Hive box key `'learnerXp'` — same box already used for `lastSyncedAt`, `activeLearnerId`, etc. (see `lib/data/local/hive_boxes.dart`). No new Hive typeId/adapter needed since it's a plain `int`, not a custom object.

- [ ] **Step 1: Write the failing test**

```dart
// prjct/test/logic/learner/learner_xp_provider_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:salamlearn/data/local/hive_boxes.dart';
import 'package:salamlearn/logic/learner/learner_xp_provider.dart';

void main() {
  setUp(() async {
    Hive.init('test/.hive_tmp');
    await Hive.openBox<dynamic>(HiveBoxes.settings);
  });

  tearDown(() async {
    await Hive.box<dynamic>(HiveBoxes.settings).clear();
    await Hive.close();
  });

  test('starts at 0 when nothing stored yet', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(learnerXpProvider), 0);
  });

  test('addXp increases the total and persists it to Hive', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(learnerXpProvider.notifier).addXp(50);

    expect(container.read(learnerXpProvider), 50);
    expect(Hive.box<dynamic>(HiveBoxes.settings).get('learnerXp'), 50);
  });

  test('addXp accumulates across multiple calls', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(learnerXpProvider.notifier);

    notifier.addXp(50);
    notifier.addXp(30);

    expect(container.read(learnerXpProvider), 80);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd prjct && flutter test test/logic/learner/learner_xp_provider_test.dart`
Expected: FAIL — `package:salamlearn/logic/learner/learner_xp_provider.dart` doesn't exist.

- [ ] **Step 3: Implement the notifier**

```dart
// prjct/lib/logic/learner/learner_xp_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../data/local/hive_boxes.dart';

/// Total XP the active learner has earned, persisted under the `settings`
/// Hive box (same box `SessionNotifier` uses for `lastSyncedAt` and
/// friends) — no dedicated Hive box or typed model needed for a single
/// running integer. Backs the Adventure Map TopBar's stars/XP pill.
class LearnerXpNotifier extends Notifier<int> {
  Box<dynamic> get _settings => Hive.box<dynamic>(HiveBoxes.settings);

  @override
  int build() => _settings.get('learnerXp') as int? ?? 0;

  /// Called when a module's DFD-simulator flow reaches `finished` (see
  /// `module_placeholder_screen.dart`'s `_runDfdSimulation`).
  void addXp(int amount) {
    final next = state + amount;
    state = next;
    _settings.put('learnerXp', next);
  }
}

final learnerXpProvider = NotifierProvider<LearnerXpNotifier, int>(
  LearnerXpNotifier.new,
);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd prjct && flutter test test/logic/learner/learner_xp_provider_test.dart`
Expected: PASS (all 3 tests)

- [ ] **Step 5: Commit**

```bash
cd prjct
git add lib/logic/learner/learner_xp_provider.dart test/logic/learner/learner_xp_provider_test.dart
git commit -m "Add Hive-backed LearnerXpNotifier"
```

---

## Task 3: NoorEnergyNotifier (Hive-backed daily-reset lives system)

**Files:**
- Create: `prjct/lib/logic/learner/noor_energy_provider.dart`
- Test: `prjct/test/logic/learner/noor_energy_provider_test.dart` (new)

Stores `noorEnergyCurrent` (int) and `noorEnergyLastResetDate` (ISO date string, date-only) under the `settings` box. On every read, if the stored reset date isn't today (local time), energy is refilled to max and the stored date is bumped — this is what gives the "come back tomorrow" recovery rule from the spec.

- [ ] **Step 1: Write the failing test**

```dart
// prjct/test/logic/learner/noor_energy_provider_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:salamlearn/data/local/hive_boxes.dart';
import 'package:salamlearn/logic/learner/noor_energy_provider.dart';

void main() {
  setUp(() async {
    Hive.init('test/.hive_tmp');
    await Hive.openBox<dynamic>(HiveBoxes.settings);
  });

  tearDown(() async {
    await Hive.box<dynamic>(HiveBoxes.settings).clear();
    await Hive.close();
  });

  test('starts full (5/5) with no stored state', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final state = container.read(noorEnergyProvider);
    expect(state.current, 5);
    expect(state.maxEnergy, 5);
    expect(state.hasEnergy, true);
  });

  test('consume decrements current and persists it', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(noorEnergyProvider.notifier);

    notifier.consume();

    expect(container.read(noorEnergyProvider).current, 4);
    expect(Hive.box<dynamic>(HiveBoxes.settings).get('noorEnergyCurrent'), 4);
  });

  test('consume never goes below 0', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(noorEnergyProvider.notifier);

    for (var i = 0; i < 10; i++) {
      notifier.consume();
    }

    expect(container.read(noorEnergyProvider).current, 0);
    expect(container.read(noorEnergyProvider).hasEnergy, false);
  });

  test('refills to max when the stored reset date is not today', () async {
    final settings = Hive.box<dynamic>(HiveBoxes.settings);
    await settings.put('noorEnergyCurrent', 1);
    await settings.put('noorEnergyLastResetDate', '2020-01-01');

    final container = ProviderContainer();
    addTearDown(container.dispose);

    final state = container.read(noorEnergyProvider);
    expect(state.current, 5);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd prjct && flutter test test/logic/learner/noor_energy_provider_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Implement the notifier**

```dart
// prjct/lib/logic/learner/noor_energy_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../data/local/hive_boxes.dart';

/// Immutable snapshot of the Noor Energy lives system — 5 max, one spent
/// per module opened from the Adventure Map, refilled once per calendar
/// day (see the design spec's "Data model additions" section for why a
/// full-daily-reset rule was chosen over hourly partial recovery).
class NoorEnergyState {
  const NoorEnergyState({required this.current, required this.maxEnergy});

  final int current;
  final int maxEnergy;

  bool get hasEnergy => current > 0;
}

class NoorEnergyNotifier extends Notifier<NoorEnergyState> {
  static const _maxEnergy = 5;

  Box<dynamic> get _settings => Hive.box<dynamic>(HiveBoxes.settings);

  String get _todayKey {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  @override
  NoorEnergyState build() {
    final lastReset = _settings.get('noorEnergyLastResetDate') as String?;
    if (lastReset != _todayKey) {
      // A new day (or first-ever launch) — refill and stamp today's date.
      _settings.put('noorEnergyCurrent', _maxEnergy);
      _settings.put('noorEnergyLastResetDate', _todayKey);
      return const NoorEnergyState(current: _maxEnergy, maxEnergy: _maxEnergy);
    }
    final current = _settings.get('noorEnergyCurrent') as int? ?? _maxEnergy;
    return NoorEnergyState(current: current, maxEnergy: _maxEnergy);
  }

  /// Called when the learner taps an unlocked Adventure Map node, before
  /// navigating into the module — a session-level cost per the spec, not
  /// a per-question cost.
  void consume() {
    if (state.current <= 0) return;
    final next = state.current - 1;
    state = NoorEnergyState(current: next, maxEnergy: state.maxEnergy);
    _settings.put('noorEnergyCurrent', next);
  }
}

final noorEnergyProvider =
    NotifierProvider<NoorEnergyNotifier, NoorEnergyState>(
  NoorEnergyNotifier.new,
);
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd prjct && flutter test test/logic/learner/noor_energy_provider_test.dart`
Expected: PASS (all 4 tests)

- [ ] **Step 5: Commit**

```bash
cd prjct
git add lib/logic/learner/noor_energy_provider.dart test/logic/learner/noor_energy_provider_test.dart
git commit -m "Add Hive-backed NoorEnergyNotifier with daily reset"
```

---

## Task 4: Award XP on module completion

**Files:**
- Modify: `prjct/lib/ui/core_modules/module_placeholder_screen.dart:257-266` (the "4. Award achievement badges" step in `_runDfdSimulation`)

- [ ] **Step 1: Add the import**

At the top of `prjct/lib/ui/core_modules/module_placeholder_screen.dart`, alongside the existing `import '../../logic/recent_module_provider.dart';`:

```dart
import '../../logic/learner/learner_xp_provider.dart';
```

- [ ] **Step 2: Award XP alongside the existing badge award**

Find this exact block (currently lines 257–266):

```dart
    // 4. Award achievement badges
    if (!mounted) return;
    setState(() {
      _simState = 'awardingBadges';
      _validationMsg = 'DFD: Updating achievement badges...';
    });
    ref
        .read(unlockedBadgesProvider.notifier)
        .unlockBadge('${widget.moduleId.toUpperCase()} Master');
    await Future<void>.delayed(const Duration(milliseconds: 1000));
```

Replace with:

```dart
    // 4. Award achievement badges
    if (!mounted) return;
    setState(() {
      _simState = 'awardingBadges';
      _validationMsg = 'DFD: Updating achievement badges...';
    });
    ref
        .read(unlockedBadgesProvider.notifier)
        .unlockBadge('${widget.moduleId.toUpperCase()} Master');
    ref.read(learnerXpProvider.notifier).addXp(50);
    await Future<void>.delayed(const Duration(milliseconds: 1000));
```

- [ ] **Step 3: Verify with flutter analyze**

Run: `cd prjct && flutter analyze`
Expected: 0 new issues versus the pre-existing baseline (run `flutter analyze` once before this change if you need to confirm the baseline count first).

- [ ] **Step 4: Manual verification**

Run: `cd prjct && flutter run` (or reuse an already-running debug build), open any module as a Learner, tap "Validate & Submit Answers," let the DFD flow finish. Then check the XP value increased:

```bash
# with the app running on an emulator/device, after completing one module:
adb shell run-as com.example.salamlearn ls  # (skip if adb run-as isn't set up; instead verify via the TopBar pill once Task 9 is built)
```

Since there's no UI showing XP yet (that's Task 9), confirm via a temporary `debugPrint(ref.read(learnerXpProvider))` in `_runDfdSimulation` right after the `addXp` call, run once, observe `50` in the console, then remove the debugPrint before committing.

- [ ] **Step 5: Commit**

```bash
cd prjct
git add lib/ui/core_modules/module_placeholder_screen.dart
git commit -m "Award 50 XP when a module's DFD-simulator flow completes"
```

---

## Task 5: Noor Energy gating + "resting" sheet

**Files:**
- Create: `prjct/lib/ui/student_hub/noor_energy_resting_sheet.dart`
- Test: `prjct/test/ui/student_hub/noor_energy_resting_sheet_test.dart` (new)

A standalone bottom-sheet widget shown instead of navigating to `/module/:id` when `noorEnergyProvider`'s `hasEnergy` is false. Wiring this into the actual node-tap handler happens in Task 11 (the Adventure Map screen doesn't exist yet); this task builds and tests the sheet in isolation so Task 11 can just call it.

- [ ] **Step 1: Write the failing test**

```dart
// prjct/test/ui/student_hub/noor_energy_resting_sheet_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/ui/student_hub/noor_energy_resting_sheet.dart';

void main() {
  testWidgets('shows the resting message and an OK button that dismisses it',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: SizedBox())),
      ),
    );
    final context = tester.element(find.byType(Scaffold));

    showNoorEnergyRestingSheet(context);
    await tester.pumpAndSettle();

    expect(find.textContaining('Noor Energy'), findsOneWidget);
    expect(find.text('OK'), findsOneWidget);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Noor Energy'), findsNothing);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd prjct && flutter test test/ui/student_hub/noor_energy_resting_sheet_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Implement the sheet**

```dart
// prjct/lib/ui/student_hub/noor_energy_resting_sheet.dart
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Shown instead of opening a module when `NoorEnergyState.hasEnergy` is
/// false — matches the asset pack's "Noor Energy is resting" illustration
/// concept (owl mascot resting), restyled with this app's own components
/// rather than the reference bitmap directly.
void showNoorEnergyRestingSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.nightlight_round, size: 48, color: AppColors.gold),
          const SizedBox(height: 12),
          const Text(
            'Noor Energy is resting',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Come back tomorrow for more energy, or review what you\'ve already learned!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(sheetContext).pop(),
              style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
              child: const Text('OK'),
            ),
          ),
        ],
      ),
    ),
  );
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd prjct && flutter test test/ui/student_hub/noor_energy_resting_sheet_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd prjct
git add lib/ui/student_hub/noor_energy_resting_sheet.dart test/ui/student_hub/noor_energy_resting_sheet_test.dart
git commit -m "Add Noor Energy resting bottom sheet"
```

---

## Task 6: Prepare the map background asset

**Files:**
- Create: `prjct/assets/images/adventure_map/map_background.png`

- [ ] **Step 1: Copy the chosen background image into the project**

```bash
cp "C:/Users/Jude/Downloads/Designs-20260710T141643Z-2-001/Asset-Designs/bg 2.png" \
   "C:/Users/Jude/OneDrive/Documents/MODULES/CLAUDEOPEN/0000000000000000000/prjct/assets/images/adventure_map/map_background.png"
```

- [ ] **Step 2: Confirm it's picked up (no pubspec change needed)**

`pubspec.yaml` already declares `assets/images/` as a blanket directory (`prjct/pubspec.yaml:87-89`), so the new `adventure_map/` subfolder is included automatically. Confirm with:

```bash
cd prjct && flutter pub get
```

Expected: completes with no errors (this step doesn't add a new dependency, just re-validates the asset manifest).

- [ ] **Step 3: Commit**

```bash
cd prjct
git add assets/images/adventure_map/map_background.png
git commit -m "Add Adventure Map background illustration asset"
```

---

## Task 7: HTML/CSS preview — approval gate (no Dart code)

**This task has no code steps.** Per this repo's standing process rule (`CLAUDE.md`: "New screens with any non-trivial animation get an HTML/CSS preview first... before Flutter code is written"), the Adventure Map screen cannot proceed to Flutter implementation (Tasks 9–12) until this is done and approved.

- [ ] **Step 1: Invoke the `motion-design` skill and build an HTML/CSS preview**

Build a static HTML/CSS page (saved under `dumps/`, per this project's established convention for design mocks — see memory note "Mock HTML location") showing:
- The `map_background.png` asset (from Task 6) as a scrollable background.
- 5 node badges (Locked/Available/Current/Completed states) positioned over the 5 illustrated destinations actually being used, each labeled with its corresponding existing module name (Tracing/Sounds/Qur'an & Hadith/Stories/Sort & Match).
- The owl mascot positioned at the "current" node with the bob + speech-bubble treatment.
- The new pill-style TopBar (streak/XP/Noor Energy) and floating BottomNav, both docked over the scrolling content.

- [ ] **Step 2: Show the preview to the project owner and get explicit approval**

Do not proceed to Task 8 until the owner has reviewed the HTML preview and approved the node positions, mascot placement, and TopBar/BottomNav look. Iterate on the HTML file (not Flutter code) based on feedback.

- [ ] **Step 3: Record the approved node coordinates**

Once approved, note the final `(x, y)` pixel position of each of the 5 nodes (relative to the background image's natural dimensions) and the mascot's default resting position — these values feed directly into Task 11's `AdventureMapScreen` implementation. Write them into this plan file's Task 11 section (edit this plan document) before starting Task 11, replacing the placeholder coordinates shown there.

---

## Task 8: Bundle fonts and register the Learner text theme

**Files:**
- Modify: `prjct/pubspec.yaml`
- Modify: `prjct/lib/ui/theme/app_theme.dart`
- Create: `prjct/assets/fonts/` (font files — see Step 1)

- [ ] **Step 1: Obtain the four font files**

These are Google Fonts and must be downloaded by a human with browser/network access (not fetchable from within this plan's execution environment as binary files). Download from https://fonts.google.com the following families, Regular + Bold/SemiBold weights as available, and place the `.ttf` files at:

```
prjct/assets/fonts/Fredoka-Bold.ttf
prjct/assets/fonts/Fredoka-Regular.ttf
prjct/assets/fonts/Baloo2-SemiBold.ttf
prjct/assets/fonts/Nunito-Regular.ttf
prjct/assets/fonts/Cairo-Regular.ttf
```

**This step blocks the rest of this task** — do not proceed to Step 2 until these files exist on disk.

- [ ] **Step 2: Register the fonts in pubspec.yaml**

In `prjct/pubspec.yaml`, replace the commented-out template fonts section (currently lines 97–115, all comments) with:

```yaml
  fonts:
    - family: Fredoka
      fonts:
        - asset: assets/fonts/Fredoka-Regular.ttf
        - asset: assets/fonts/Fredoka-Bold.ttf
          weight: 700
    - family: Baloo2
      fonts:
        - asset: assets/fonts/Baloo2-SemiBold.ttf
          weight: 600
    - family: Nunito
      fonts:
        - asset: assets/fonts/Nunito-Regular.ttf
    - family: Cairo
      fonts:
        - asset: assets/fonts/Cairo-Regular.ttf
```

- [ ] **Step 3: Add a `learnerTextTheme` to app_theme.dart**

In `prjct/lib/ui/theme/app_theme.dart`, add a new static method to `AppTheme`, after the existing `_textTheme` method:

```dart
  /// Kid-facing text theme for the Learner Hub subtree only — Fredoka for
  /// headings/stats, Nunito for body text, per the Adventure Map design
  /// spec's typography section. Parent/Teacher screens keep `light()`'s
  /// default Material text theme untouched.
  static TextTheme learnerTextTheme(TextTheme base) {
    return base.copyWith(
      displayLarge: base.displayLarge!.copyWith(
        fontFamily: 'Fredoka',
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
      headlineMedium: base.headlineMedium!.copyWith(
        fontFamily: 'Fredoka',
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
      titleLarge: base.titleLarge!.copyWith(
        fontFamily: 'Baloo2',
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
      bodyLarge: base.bodyLarge!.copyWith(
        fontFamily: 'Nunito',
        color: AppColors.ink,
      ),
      bodyMedium: base.bodyMedium!.copyWith(
        fontFamily: 'Nunito',
        color: AppColors.textMuted,
      ),
    );
  }
```

- [ ] **Step 4: Verify the app builds with the new fonts**

Run: `cd prjct && flutter analyze && flutter build apk --debug`
Expected: builds successfully with no font-loading errors in the output.

- [ ] **Step 5: Commit**

```bash
cd prjct
git add pubspec.yaml lib/ui/theme/app_theme.dart assets/fonts/
git commit -m "Bundle Adventure Map fonts and add learnerTextTheme"
```

---

## Task 9: Adventure Map TopBar

**Files:**
- Create: `prjct/lib/ui/student_hub/adventure_map_top_bar.dart`
- Test: `prjct/test/ui/student_hub/adventure_map_top_bar_test.dart` (new)

**Depends on Task 7's approved preview** for exact visual spacing/sizing — this task's test only verifies the pills display the correct *values*, not pixel-perfect layout, so it can be written before the preview is finalized; only the widget's internal styling needs revisiting after Task 7 if the approved preview differs from this first pass.

- [ ] **Step 1: Write the failing test**

```dart
// prjct/test/ui/student_hub/adventure_map_top_bar_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/ui/student_hub/adventure_map_top_bar.dart';

void main() {
  testWidgets('shows streak, XP, and Noor Energy values', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: AdventureMapTopBar()),
        ),
      ),
    );

    expect(find.text('5'), findsOneWidget); // default streak from learnerStreakProvider
    expect(find.text('0'), findsOneWidget); // default XP (nothing earned yet)
    expect(find.textContaining('5'), findsWidgets); // Noor Energy 5/5 somewhere
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd prjct && flutter test test/ui/student_hub/adventure_map_top_bar_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Implement the TopBar**

```dart
// prjct/lib/ui/student_hub/adventure_map_top_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../logic/learner/learner_xp_provider.dart';
import '../../logic/learner/noor_energy_provider.dart';
import '../../logic/recent_module_provider.dart';
import '../theme/app_colors.dart';

/// Pill-style stat row replacing the Learner Hub's previous plain header —
/// see the Adventure Map design spec's "TopBar" section. Shown across all
/// 4 Learner Hub tabs via `HubShell`.
class AdventureMapTopBar extends ConsumerWidget {
  const AdventureMapTopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(learnerStreakProvider);
    final xp = ref.watch(learnerXpProvider);
    final energy = ref.watch(noorEnergyProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _Pill(icon: Icons.local_fire_department, color: AppColors.coral, value: '$streak'),
          _Pill(icon: Icons.star_rounded, color: AppColors.gold, value: '$xp'),
          _Pill(
            icon: Icons.nightlight_round,
            color: AppColors.adventurePurple,
            value: '${energy.current}/${energy.maxEnergy}',
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.color, required this.value});

  final IconData icon;
  final Color color;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.creamBorder, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Color(0x1A000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd prjct && flutter test test/ui/student_hub/adventure_map_top_bar_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
cd prjct
git add lib/ui/student_hub/adventure_map_top_bar.dart test/ui/student_hub/adventure_map_top_bar_test.dart
git commit -m "Add Adventure Map pill-style TopBar"
```

---

## Task 10: Adventure Map BottomNav + wire into HubShell

**Files:**
- Create: `prjct/lib/ui/student_hub/adventure_map_bottom_nav.dart`
- Modify: `prjct/lib/ui/student_hub/hub_shell.dart:49-57`
- Test: `prjct/test/ui/student_hub/adventure_map_bottom_nav_test.dart` (new)

Keeps the exact same `HubTab` enum and 4-callback interface as the existing `HubBottomNav` (`prjct/lib/ui/student_hub/hub_bottom_nav.dart:11-25`) so `HubShell` only needs its one widget-construction line changed, not its navigation logic.

- [ ] **Step 1: Write the failing test**

```dart
// prjct/test/ui/student_hub/adventure_map_bottom_nav_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/ui/student_hub/adventure_map_bottom_nav.dart';
import 'package:salamlearn/ui/student_hub/hub_bottom_nav.dart';

void main() {
  testWidgets('tapping Backpack calls onBackpackTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdventureMapBottomNav(
            active: HubTab.home,
            onHomeTap: () {},
            onLeaderboardTap: () {},
            onBackpackTap: () => tapped = true,
            onProfileTap: () {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Backpack'));
    expect(tapped, true);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd prjct && flutter test test/ui/student_hub/adventure_map_bottom_nav_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Implement the floating pill nav**

```dart
// prjct/lib/ui/student_hub/adventure_map_bottom_nav.dart
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'hub_bottom_nav.dart' show HubTab;

/// Floating rounded-pill bottom nav replacing `HubBottomNav`'s flat bar —
/// same `HubTab`/callback contract, only the visual container changes.
/// See the Adventure Map design spec's "BottomNav" section.
class AdventureMapBottomNav extends StatelessWidget {
  const AdventureMapBottomNav({
    super.key,
    required this.active,
    required this.onHomeTap,
    required this.onLeaderboardTap,
    required this.onBackpackTap,
    required this.onProfileTap,
  });

  final HubTab active;
  final VoidCallback onHomeTap;
  final VoidCallback onLeaderboardTap;
  final VoidCallback onBackpackTap;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(color: Color(0x2E000000), blurRadius: 20, offset: Offset(0, 6)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _Item(icon: Icons.map_rounded, label: 'Home', active: active == HubTab.home, onTap: onHomeTap),
            _Item(
              icon: Icons.leaderboard_rounded,
              label: 'Ranks',
              active: active == HubTab.leaderboard,
              onTap: onLeaderboardTap,
            ),
            _Item(
              icon: Icons.backpack_rounded,
              label: 'Backpack',
              active: active == HubTab.backpack,
              onTap: onBackpackTap,
            ),
            _Item(icon: Icons.face_rounded, label: 'Me', active: active == HubTab.profile, onTap: onProfileTap),
          ],
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.icon, required this.label, required this.active, required this.onTap});

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.teal : AppColors.textMuted;
    return Material(
      color: active ? AppColors.mint : Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd prjct && flutter test test/ui/student_hub/adventure_map_bottom_nav_test.dart`
Expected: PASS

- [ ] **Step 5: Wire it into HubShell**

In `prjct/lib/ui/student_hub/hub_shell.dart`, add the import:

```dart
import 'adventure_map_bottom_nav.dart';
```

Replace the exact block at lines 49–57:

```dart
        bottomNavigationBar: SafeArea(
          child: HubBottomNav(
            active: HubTab.values[widget.navigationShell.currentIndex],
            onHomeTap: () => _switchTo(0),
            onLeaderboardTap: () => _switchTo(1),
            onBackpackTap: () => _switchTo(2),
            onProfileTap: () => _switchTo(3),
          ),
        ),
```

with:

```dart
        bottomNavigationBar: SafeArea(
          child: AdventureMapBottomNav(
            active: HubTab.values[widget.navigationShell.currentIndex],
            onHomeTap: () => _switchTo(0),
            onLeaderboardTap: () => _switchTo(1),
            onBackpackTap: () => _switchTo(2),
            onProfileTap: () => _switchTo(3),
          ),
        ),
```

The existing `import 'hub_bottom_nav.dart';` at the top of `hub_shell.dart` stays (still needed for the `HubTab` enum).

- [ ] **Step 6: Verify**

Run: `cd prjct && flutter analyze`
Expected: 0 new issues.

- [ ] **Step 7: Commit**

```bash
cd prjct
git add lib/ui/student_hub/adventure_map_bottom_nav.dart test/ui/student_hub/adventure_map_bottom_nav_test.dart lib/ui/student_hub/hub_shell.dart
git commit -m "Add floating-pill BottomNav and wire into HubShell"
```

---

## Task 11: Adventure Map screen (Home tab)

**Files:**
- Create: `prjct/lib/ui/student_hub/adventure_map_screen.dart`
- Modify: `prjct/lib/logic/router/app_router.dart` (swap `StudentHubScreen` for `AdventureMapScreen` on the `/hub` route)
- Test: `prjct/test/ui/student_hub/adventure_map_screen_test.dart` (new)

**Node coordinates below are placeholders from this plan's authoring pass — replace with the values recorded in Task 7 Step 3 before writing this task's implementation.** This is a real, working starting layout (evenly spaced down the map), not a stand-in for missing logic — only the exact pixel positions are expected to move once the HTML preview is approved.

- [ ] **Step 1: Write the failing test**

```dart
// prjct/test/ui/student_hub/adventure_map_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:salamlearn/ui/student_hub/adventure_map_screen.dart';

void main() {
  testWidgets('shows one node per core module', (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (_, _) => const AdventureMapScreen()),
        GoRoute(path: '/module/:id', builder: (_, state) => Text('module ${state.pathParameters['id']}')),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );

    expect(find.text('Tracing'), findsOneWidget);
    expect(find.text('Sounds'), findsOneWidget);
    expect(find.text('Stories'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd prjct && flutter test test/ui/student_hub/adventure_map_screen_test.dart`
Expected: FAIL — file doesn't exist.

- [ ] **Step 3: Implement the screen**

```dart
// prjct/lib/ui/student_hub/adventure_map_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import '../../logic/auth/session.dart';
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
  'tracing': 0.824,     // top: 1500px of 1821px canvas
  'flashcards': 0.620,  // top: 1130px — "Sounds"
  'recitation': 0.439,  // top: 800px — "Qur'an & Hadith" (current, approved)
  'stories': 0.258,     // top: 470px
  'sorting': 0.077,     // top: 140px — locked this phase
};

// All 5 nodes sit at the same horizontal position in the approved preview
// (.node { left: 130px } of a 390px-wide canvas — the path is drawn as a
// roughly straight vertical band in bg 2.png, not winding left-right).
const _nodeLeftFraction = 130 / 390;

class AdventureMapScreen extends ConsumerStatefulWidget {
  const AdventureMapScreen({super.key});

  @override
  ConsumerState<AdventureMapScreen> createState() => _AdventureMapScreenState();
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
                ? [BoxShadow(color: module.color.withValues(alpha: 0.4), blurRadius: 16, spreadRadius: 4)]
                : null,
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(module.icon, color: module.color),
              Text(module.title, style: TextStyle(fontSize: 10, color: module.color, fontWeight: FontWeight.bold)),
            ],
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd prjct && flutter test test/ui/student_hub/adventure_map_screen_test.dart`
Expected: PASS

- [ ] **Step 5: Wire into the router**

In `prjct/lib/logic/router/app_router.dart`, find the `/hub` route (inside the `StatefulShellRoute.indexedStack`'s first branch):

```dart
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/hub',
                builder: (_, _) => const StudentHubScreen(),
              ),
            ],
          ),
```

Replace with:

```dart
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/hub',
                builder: (_, _) => const AdventureMapScreen(),
              ),
            ],
          ),
```

Update the import at the top of the file from `import '../../ui/student_hub/student_hub_screen.dart';` to `import '../../ui/student_hub/adventure_map_screen.dart';` (remove the old import only if `StudentHubScreen` isn't referenced anywhere else in this file — check with `grep -n StudentHubScreen prjct/lib/logic/router/app_router.dart` first).

- [ ] **Step 6: Verify**

Run: `cd prjct && flutter analyze`
Expected: 0 new issues.

- [ ] **Step 7: Commit**

```bash
cd prjct
git add lib/ui/student_hub/adventure_map_screen.dart test/ui/student_hub/adventure_map_screen_test.dart lib/logic/router/app_router.dart
git commit -m "Add Adventure Map screen and route it as the Home tab"
```

---

## Task 12: Restyle Backpack/Profile tab chrome

**Note:** the Leaderboard tab was removed from the Learner Hub entirely (owner request, after Task 10) — `leaderboard_screen.dart`, its route, its `HubTab.leaderboard` value, and its test were deleted. This task now only covers the remaining 2 tabs.

**Files:**
- Modify: `prjct/lib/ui/student_hub/backpack_screen.dart`
- Modify: `prjct/lib/ui/student_hub/profile_screen.dart`

This task is a **visual-only pass** — no data/logic changes, so no new tests (existing widget tests for these 2 screens must still pass unchanged). Each screen's top-level `Scaffold` background and card styling gets updated to reference the new `AppColors.adventure*` tokens and `Fredoka`/`Baloo2` fonts from Tasks 1 and 8, matching the Adventure Map's visual language. Exact styling changes are visual-judgment calls made live against the running app (per the `impeccable` skill), not prescribable as exact diffs here — this step is deliberately open-ended on *how much* restyling, bounded by: content, data bindings, and navigation behavior in these 2 files must not change.

- [ ] **Step 1: Run the existing test suite for these 3 screens first, to capture the baseline**

Run: `cd prjct && flutter test test/ui/student_hub/`
Expected: note the pass/fail count — this is the baseline to preserve exactly through this task's changes.

- [ ] **Step 2: Restyle each screen's chrome**

Apply the new palette/typography tokens to each screen's cards, headers, and buttons, following the visual language established in Tasks 9–11 (pill shapes, rounded-28 nav-adjacent containers, `Fredoka`/`Baloo2` for headings). Use the `impeccable` skill for this pass.

- [ ] **Step 3: Re-run the test suite to confirm nothing broke**

Run: `cd prjct && flutter test test/ui/student_hub/`
Expected: same pass count as Step 1's baseline (styling changes must not change test outcomes, since the tests assert content/behavior, not pixel styling).

- [ ] **Step 4: Commit**

```bash
cd prjct
git add lib/ui/student_hub/backpack_screen.dart lib/ui/student_hub/profile_screen.dart
git commit -m "Restyle Backpack/Profile tabs to match Adventure Map visual language"
```

---

## Task 13: Final verification pass

**Files:** none (verification only)

- [ ] **Step 1: Full analyze + test run**

Run: `cd prjct && flutter analyze && flutter test`
Expected: 0 new analyze issues vs. this repo's pre-existing baseline; all tests pass including every new test file from Tasks 1–11.

- [ ] **Step 2: `hallmark` anti-AI-slop check**

Invoke the `hallmark` skill against the new Adventure Map screen and restyled tabs, comparing against the Task 7 approved HTML preview and the `Designs-20260710T141643Z-2-001` asset pack, per this repo's standing rule for any new/redesigned screen.

- [ ] **Step 3: `impeccable` polish pass**

Invoke the `impeccable` skill for a hierarchy/spacing/typography/states review of the Adventure Map screen and the 3 restyled tabs.

- [ ] **Step 4: `verify` skill drive-through on a running emulator**

Invoke the `verify` skill. Manually drive: Home tab loads scrolled to the current node → tap an unlocked node → Noor Energy decrements by 1 → module opens → complete it (Validate & Submit) → XP increases by 50 → back to Home → node now shows completed state → deplete all 5 Noor Energy by opening 5 modules → 6th tap shows the resting sheet instead of navigating → BottomNav switches correctly across all 3 tabs (Home/Backpack/Me — Leaderboard was removed) → TopBar pills stay correct across tab switches.

- [ ] **Step 5: Build and install on a connected device/emulator**

```bash
cd prjct
flutter build apk --debug
```

Then, via PowerShell (per this project's established adb workflow — Bash's `adb` isn't on PATH in this environment):

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" devices
& "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" -s <device-id> install -r "build\app\outputs\flutter-apk\app-debug.apk"
```

- [ ] **Step 6: Final commit (if Steps 2–4 produced any fixes)**

```bash
cd prjct
git add -A
git commit -m "Polish and verification fixes for Adventure Map redesign"
```
