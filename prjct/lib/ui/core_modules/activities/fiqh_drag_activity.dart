import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../data/models/curriculum/curriculum_models.dart';
import '../../theme/app_colors.dart';

/// FR-4.5: Fiqh & Taharah — three sub-games auto-selected by [activityId]:
///   *-fiqh-1  → Water Purity Sorter      (FR-4.5.1 / FR-4.5.2)
///   *-fiqh-2  → Fitrah Hygiene Match      (FR-4.5.3 / FR-4.5.4)
///   *-fiqh-3+ → Wudhu Ritual Sequencer    (FR-4.5.5 / FR-4.5.6)
class FiqhDragActivity extends StatefulWidget {
  const FiqhDragActivity({
    super.key,
    required this.items,
    required this.zones,
    required this.xp,
    required this.color,
    required this.onComplete,
    this.activityId = '',
  });

  final List<FiqhDragItem> items;
  final List<FiqhDropZone> zones;
  final int xp;
  final Color color;
  final void Function(int xp, double accuracyPct, int errors) onComplete;
  /// Activity ID used to derive which sub-game to render.
  final String activityId;

  FiqhMode get mode {
    if (activityId.contains('-fiqh-2')) {
      return FiqhMode.hygiene;
    }
    if (activityId.contains('-fiqh-3') ||
        activityId.contains('-fiqh-4') ||
        activityId.contains('-fiqh-5') ||
        activityId.contains('-fiqh-6')) {
      return FiqhMode.wudhu;
    }
    return FiqhMode.water;
  }

  @override
  State<FiqhDragActivity> createState() => _FiqhDragActivityState();
}

enum FiqhMode { water, hygiene, wudhu }

class _FiqhDragActivityState extends State<FiqhDragActivity>
    with TickerProviderStateMixin {
  final Map<String, String> _placedInZone = {};
  final Set<String> _wrongZone = {};
  int _wrongAttempts = 0;
  bool _success = false;
  /// Ordered slots for the Wudhu Sequencer (6 steps).
  final List<String?> _wudhuSlots = List.filled(6, null);

  late final _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  )..forward();

  static const _overshoot = Cubic(0.34, 1.56, 0.64, 1.0);

  bool get _allPlaced => widget.items.every(
    (i) => _placedInZone.values.contains(i.id),
  );

  /// One-to-one zone drop (hygiene match).
  void _handleDrop(FiqhDragItem item, FiqhDropZone zone) {
    if (_placedInZone.containsKey(zone.id) || _success) return;
    final correct = item.correctZoneId == zone.id;
    if (correct) {
      setState(() => _placedInZone[zone.id] = item.id);
      if (_allPlaced) _triggerSuccess();
    } else {
      _wrongAttempts++;
      setState(() => _wrongZone.add(zone.id));
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _wrongZone.remove(zone.id));
      });
    }
  }

  /// Many-to-bucket drop (water sorter) — each item has its own key.
  void _handleBucketDrop(FiqhDragItem item, FiqhDropZone zone) {
    if (_success || _placedInZone.values.contains(item.id)) return;
    final correct = item.correctZoneId == zone.id;
    if (correct) {
      setState(() => _placedInZone['${zone.id}_${item.id}'] = item.id);
      if (_allPlaced) _triggerSuccess();
    } else {
      _wrongAttempts++;
      setState(() => _wrongZone.add(zone.id));
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _wrongZone.remove(zone.id));
      });
    }
  }

  /// Ordered-slot drop (wudhu sequencer).
  void _handleWudhuDrop(FiqhDragItem item, int slotIndex) {
    if (_success) return;
    final correctSlot = int.tryParse(item.correctZoneId) ?? -1;
    if (correctSlot == slotIndex + 1) {
      setState(() => _wudhuSlots[slotIndex] = item.id);
      if (_wudhuSlots.every((s) => s != null)) _triggerSuccess();
    } else {
      _wrongAttempts++;
      setState(() => _wrongZone.add('slot$slotIndex'));
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _wrongZone.remove('slot$slotIndex'));
      });
    }
  }

  void _triggerSuccess() {
    setState(() => _success = true);
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      final totalAttempts = widget.items.length + _wrongAttempts;
      final accuracyPct = totalAttempts == 0
          ? 100.0
          : widget.items.length / totalAttempts * 100;
      widget.onComplete(widget.xp, accuracyPct, _wrongAttempts);
    });
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _entrance,
      builder: (context, child) {
        final e = _overshoot.transform(_entrance.value);
        return Opacity(
          opacity: e.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - e)),
            child: child,
          ),
        );
      },
      child: _success ? _buildSuccessScreen() : _buildGame(),
    );
  }

  Widget _buildGame() {
    switch (widget.mode) {
      case FiqhMode.water:
        return _WaterSorterGame(
          items: widget.items,
          zones: widget.zones,
          placedInZone: _placedInZone,
          wrongZone: _wrongZone,
          onDrop: _handleBucketDrop,
        );
      case FiqhMode.hygiene:
        return _HygieneMatchGame(
          items: widget.items,
          zones: widget.zones,
          placedInZone: _placedInZone,
          wrongZone: _wrongZone,
          onDrop: _handleDrop,
        );
      case FiqhMode.wudhu:
        return _WudhuSequencerGame(
          items: widget.items,
          wudhuSlots: _wudhuSlots,
          wrongZone: _wrongZone,
          onDrop: _handleWudhuDrop,
        );
    }
  }

  Widget _buildSuccessScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: Lottie.asset(
              'assets/lottie/milestone_burst.json',
              repeat: false,
              errorBuilder: (_, _, _) =>
                  const Text('🎉', style: TextStyle(fontSize: 80)),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            '🌟 MashaAllah! Well done!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppColors.adventureGreen,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'You earned ${widget.xp} XP! ⭐',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.gold,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// FR-4.5.1 / FR-4.5.2  WATER PURITY SORTER
// =============================================================================
class _WaterSorterGame extends StatefulWidget {
  const _WaterSorterGame({
    required this.items,
    required this.zones,
    required this.placedInZone,
    required this.wrongZone,
    required this.onDrop,
  });
  final List<FiqhDragItem> items;
  final List<FiqhDropZone> zones;
  final Map<String, String> placedInZone;
  final Set<String> wrongZone;
  final void Function(FiqhDragItem, FiqhDropZone) onDrop;
  @override
  State<_WaterSorterGame> createState() => _WaterSorterGameState();
}

class _WaterSorterGameState extends State<_WaterSorterGame> {
  final Set<String> _hovering = {};
  @override
  Widget build(BuildContext context) {
    final placed = widget.placedInZone.length;
    final total = widget.items.length;
    final tray = widget.items
        .where((i) => !widget.placedInZone.values.contains(i.id))
        .toList();
    final cleanZone = widget.zones.firstWhere(
      (z) => z.id == 'bucketA', orElse: () => widget.zones.first);
    final impureZone = widget.zones.firstWhere(
      (z) => z.id == 'bucketB', orElse: () => widget.zones.last);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Column(
        children: [
          _buildHeader(placed, total),
          const SizedBox(height: 12),
          Expanded(
            flex: 5,
            child: Row(
              children: [
                Expanded(child: _buildBucket(cleanZone, '🪣', const Color(0xFF0097A7), const Color(0xFFE0F7FA))),
                const SizedBox(width: 12),
                Expanded(child: _buildBucket(impureZone, '🗑️', const Color(0xFFD32F2F), const Color(0xFFFFEBEE))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (tray.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF0097A7).withValues(alpha: 0.2), width: 2),
              ),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 10, runSpacing: 10,
                children: tray.map((item) => _WaterSourceChip(item: item)).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(int placed, int total) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF1565C0), Color(0xFF0097A7)]),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: const Color(0xFF1565C0).withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0,4))],
      ),
      child: Row(children: [
        const Text('💧', style: TextStyle(fontSize: 26)),
        const SizedBox(width: 10),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Water Purity Sorter', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white)),
          Text('Sort each water source into the correct bucket!', style: TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w600)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
          child: Text('$placed/$total', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white)),
        ),
      ]),
    );
  }

  Widget _buildBucket(FiqhDropZone zone, String bucketEmoji, Color accent, Color bgColor) {
    final itemsHere = widget.items.where((i) =>
        widget.placedInZone.values.contains(i.id) && i.correctZoneId == zone.id).toList();
    final isWrong = widget.wrongZone.contains(zone.id);
    final isHovering = _hovering.contains(zone.id);

    return DragTarget<FiqhDragItem>(
      onWillAcceptWithDetails: (_) { setState(() => _hovering.add(zone.id)); return true; },
      onLeave: (_) => setState(() => _hovering.remove(zone.id)),
      onAcceptWithDetails: (details) { setState(() => _hovering.remove(zone.id)); widget.onDrop(details.data, zone); },
      builder: (context, candidate, rejected) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isWrong ? AppColors.coralTint : isHovering ? accent.withValues(alpha: 0.12) : bgColor,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: isWrong ? AppColors.coral : isHovering ? accent : accent.withValues(alpha: 0.35), width: isHovering ? 3 : 2),
            boxShadow: isHovering ? [BoxShadow(color: accent.withValues(alpha: 0.28), blurRadius: 12, offset: const Offset(0,4))] : [],
          ),
          child: Column(children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              decoration: BoxDecoration(color: accent, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
              child: Column(children: [
                Text(bucketEmoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(height: 4),
                Text(zone.label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white)),
              ]),
            ),
            Expanded(child: itemsHere.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.arrow_downward_rounded, size: 26, color: accent.withValues(alpha: 0.3)),
                  const SizedBox(height: 4),
                  Text('Drop here', style: TextStyle(fontSize: 10, color: accent.withValues(alpha: 0.4), fontWeight: FontWeight.w700)),
                ]))
              : Padding(
                  padding: const EdgeInsets.all(8),
                  child: Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center,
                    children: itemsHere.map((item) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10), border: Border.all(color: accent.withValues(alpha: 0.35), width: 1.5)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(item.emoji, style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 4),
                        Text(item.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: accent)),
                        const SizedBox(width: 4),
                        Icon(Icons.check_circle, size: 12, color: accent),
                      ]),
                    )).toList(),
                  ),
                )),
          ]),
        );
      },
    );
  }
}

class _WaterSourceChip extends StatelessWidget {
  const _WaterSourceChip({required this.item});
  final FiqhDragItem item;
  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF0097A7).withValues(alpha: 0.35), width: 2),
        boxShadow: const [BoxShadow(color: Color(0x12000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(item.emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 6),
        Text(item.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.ink)),
      ]),
    );
    return Draggable<FiqhDragItem>(
      data: item,
      feedback: Material(color: Colors.transparent, child: Transform.scale(scale: 1.1, child: chip)),
      childWhenDragging: Opacity(opacity: 0.3, child: chip),
      child: chip,
    );
  }
}

// =============================================================================
// FR-4.5.3 / FR-4.5.4  FITRAH HYGIENE MATCH
// =============================================================================
class _HygieneMatchGame extends StatefulWidget {
  const _HygieneMatchGame({required this.items, required this.zones, required this.placedInZone, required this.wrongZone, required this.onDrop});
  final List<FiqhDragItem> items;
  final List<FiqhDropZone> zones;
  final Map<String, String> placedInZone;
  final Set<String> wrongZone;
  final void Function(FiqhDragItem, FiqhDropZone) onDrop;
  @override
  State<_HygieneMatchGame> createState() => _HygieneMatchGameState();
}

class _HygieneMatchGameState extends State<_HygieneMatchGame> {
  final Set<String> _hovering = {};
  static const Map<String, Offset> _zoneOffsets = {
    'mouth':    Offset(0.50, 0.22),
    'nails':    Offset(0.78, 0.55),
    'istinja':  Offset(0.50, 0.78),
  };

  @override
  Widget build(BuildContext context) {
    final tray = widget.items.where((i) => !widget.placedInZone.values.contains(i.id)).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF2E7D32), Color(0xFF00897B)]), borderRadius: BorderRadius.circular(18)),
          child: const Row(children: [
            Text('🧼', style: TextStyle(fontSize: 24)),
            SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Fitrah Hygiene Match', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white)),
              Text('Drag each hygiene tool to where it belongs!', style: TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w600)),
            ])),
          ]),
        ),
        const SizedBox(height: 12),
        Expanded(flex: 5, child: LayoutBuilder(builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          return Stack(children: [
            Container(
              width: w, height: h,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFF1F8E9), Color(0xFFE8F5E9)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.18), width: 2),
              ),
            ),
            Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('👦🏽', style: TextStyle(fontSize: 58)),
              const SizedBox(height: 2),
              Container(
                width: 68, height: 76,
                decoration: BoxDecoration(color: const Color(0xFF5D4037).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF5D4037).withValues(alpha: 0.18), width: 1.5)),
                child: const Center(child: Text('👕', style: TextStyle(fontSize: 38))),
              ),
              const Text('👖', style: TextStyle(fontSize: 34)),
            ])),
            for (final zone in widget.zones) _buildZoneOverlay(zone, w, h),
            for (final zone in widget.zones) _buildZoneLabel(zone, w, h),
          ]);
        })),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.18), width: 1.5)),
          child: tray.isEmpty
            ? const Center(child: Text('✅ All tools placed!', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.adventureGreen)))
            : Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: tray.map((item) => _HygieneTool(item: item)).toList()),
        ),
      ]),
    );
  }

  Widget _buildZoneOverlay(FiqhDropZone zone, double w, double h) {
    final pos = _zoneOffsets[zone.id] ?? const Offset(0.5, 0.5);
    const size = 54.0;
    final isFilled = widget.placedInZone.containsKey(zone.id);
    final isWrong = widget.wrongZone.contains(zone.id);
    final isHovering = _hovering.contains(zone.id);
    final placedItem = isFilled ? widget.items.firstWhere((i) => i.id == widget.placedInZone[zone.id], orElse: () => widget.items.first) : null;

    return Positioned(
      left: w * pos.dx - size / 2,
      top: h * pos.dy - size / 2,
      child: DragTarget<FiqhDragItem>(
        onWillAcceptWithDetails: (_) { setState(() => _hovering.add(zone.id)); return !isFilled; },
        onLeave: (_) => setState(() => _hovering.remove(zone.id)),
        onAcceptWithDetails: (details) { setState(() => _hovering.remove(zone.id)); widget.onDrop(details.data, zone); },
        builder: (context, candidate, rejected) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: size, height: size,
            decoration: BoxDecoration(
              color: isWrong ? AppColors.coralTint : isFilled ? const Color(0xFFC8E6C9) : isHovering ? const Color(0xFFB3E5FC) : Colors.white.withValues(alpha: 0.7),
              shape: BoxShape.circle,
              border: Border.all(color: isWrong ? AppColors.coral : isFilled ? AppColors.adventureGreen : isHovering ? const Color(0xFF0097A7) : const Color(0xFF2E7D32).withValues(alpha: 0.4), width: 2.5),
              boxShadow: (isHovering || isFilled) ? [BoxShadow(color: (isFilled ? AppColors.adventureGreen : const Color(0xFF0097A7)).withValues(alpha: 0.28), blurRadius: 10, offset: const Offset(0,3))] : [],
            ),
            alignment: Alignment.center,
            child: isFilled
              ? Text(placedItem!.emoji, style: const TextStyle(fontSize: 24))
              : Text(zone.icon ?? '?', style: const TextStyle(fontSize: 22)),
          );
        },
      ),
    );
  }

  Widget _buildZoneLabel(FiqhDropZone zone, double w, double h) {
    final pos = _zoneOffsets[zone.id] ?? const Offset(0.5, 0.5);
    final isFilled = widget.placedInZone.containsKey(zone.id);
    return Positioned(
      left: w * pos.dx - 42,
      top: h * pos.dy + 30,
      child: Container(
        width: 84,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(color: isFilled ? AppColors.adventureGreen.withValues(alpha: 0.9) : Colors.black54, borderRadius: BorderRadius.circular(8)),
        child: Text(zone.label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
      ),
    );
  }
}

class _HygieneTool extends StatelessWidget {
  const _HygieneTool({required this.item});
  final FiqhDragItem item;
  @override
  Widget build(BuildContext context) {
    final chip = Container(
      width: 78, height: 78,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFF2E7D32).withValues(alpha: 0.28), width: 2), boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 6, offset: Offset(0, 2))]),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(item.emoji, style: const TextStyle(fontSize: 30)),
        const SizedBox(height: 3),
        Text(item.label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.ink)),
      ]),
    );
    return Draggable<FiqhDragItem>(
      data: item,
      feedback: Material(color: Colors.transparent, child: Transform.scale(scale: 1.1, child: chip)),
      childWhenDragging: Opacity(opacity: 0.25, child: chip),
      child: chip,
    );
  }
}

// =============================================================================
// FR-4.5.5 / FR-4.5.6  WUDHU RITUAL SEQUENCER
// =============================================================================
class _WudhuSequencerGame extends StatefulWidget {
  const _WudhuSequencerGame({required this.items, required this.wudhuSlots, required this.wrongZone, required this.onDrop});
  final List<FiqhDragItem> items;
  final List<String?> wudhuSlots;
  final Set<String> wrongZone;
  final void Function(FiqhDragItem, int) onDrop;
  @override
  State<_WudhuSequencerGame> createState() => _WudhuSequencerGameState();
}

class _WudhuSequencerGameState extends State<_WudhuSequencerGame> {
  final Set<int> _hovering = {};

  @override
  Widget build(BuildContext context) {
    final placedIds = widget.wudhuSlots.whereType<String>().toSet();
    final tray = widget.items.where((i) => !placedIds.contains(i.id)).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF283593)]), borderRadius: BorderRadius.circular(18)),
          child: const Row(children: [
            Text('🚿', style: TextStyle(fontSize: 24)),
            SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Wudhu Sequencer', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white)),
              Text('Place the Wudhu steps in the correct order!', style: TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w600)),
            ])),
          ]),
        ),
        const SizedBox(height: 12),
        Expanded(flex: 3, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('Steps in order →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
          const SizedBox(height: 8),
          Row(children: List.generate(3, (i) => _buildSlot(i))),
          const SizedBox(height: 8),
          Row(children: List.generate(3, (i) => _buildSlot(i + 3))),
        ])),
        const SizedBox(height: 10),
        Expanded(flex: 3, child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(color: const Color(0xFF1A237E).withValues(alpha: 0.05), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFF1A237E).withValues(alpha: 0.15), width: 2)),
          child: tray.isEmpty
            ? const Center(child: Text('✅ All steps placed!', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.adventureGreen)))
            : Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: tray.map((item) => _WudhuStepCard(item: item)).toList()),
        )),
      ]),
    );
  }

  Widget _buildSlot(int index) {
    final slotNum = index + 1;
    final placedId = widget.wudhuSlots[index];
    final isFilled = placedId != null;
    final isWrong = widget.wrongZone.contains('slot$index');
    final isHovering = _hovering.contains(index);
    final placedItem = isFilled ? widget.items.firstWhere((i) => i.id == placedId, orElse: () => widget.items.first) : null;

    return Expanded(child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: DragTarget<FiqhDragItem>(
        onWillAcceptWithDetails: (_) { setState(() => _hovering.add(index)); return !isFilled; },
        onLeave: (_) => setState(() => _hovering.remove(index)),
        onAcceptWithDetails: (details) { setState(() => _hovering.remove(index)); widget.onDrop(details.data, index); },
        builder: (context, candidate, rejected) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 80,
            decoration: BoxDecoration(
              color: isWrong ? AppColors.coralTint : isFilled ? const Color(0xFFE8EAF6) : isHovering ? const Color(0xFFE3F2FD) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isWrong ? AppColors.coral : isFilled ? const Color(0xFF1A237E) : isHovering ? const Color(0xFF1565C0) : const Color(0xFF1A237E).withValues(alpha: 0.2), width: isFilled || isHovering ? 2.5 : 1.5),
              boxShadow: isHovering ? [BoxShadow(color: const Color(0xFF1565C0).withValues(alpha: 0.22), blurRadius: 8, offset: const Offset(0,3))] : [],
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 20, height: 20,
                decoration: BoxDecoration(color: isFilled ? AppColors.adventureGreen : const Color(0xFF1A237E).withValues(alpha: 0.6), shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text('$slotNum', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white)),
              ),
              const SizedBox(height: 4),
              if (isFilled) ...[
                Text(placedItem!.emoji, style: const TextStyle(fontSize: 20)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(placedItem.label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: Color(0xFF1A237E))),
                ),
              ] else
                Icon(Icons.add_circle_outline, size: 18, color: const Color(0xFF1A237E).withValues(alpha: 0.28)),
            ]),
          );
        },
      ),
    ));
  }
}

class _WudhuStepCard extends StatelessWidget {
  const _WudhuStepCard({required this.item});
  final FiqhDragItem item;
  @override
  Widget build(BuildContext context) {
    final chip = Container(
      width: 76, height: 70,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFF1A237E).withValues(alpha: 0.22), width: 2), boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 5, offset: Offset(0, 2))]),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(item.emoji, style: const TextStyle(fontSize: 26)),
        const SizedBox(height: 3),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: Text(item.label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: AppColors.ink))),
      ]),
    );
    return Draggable<FiqhDragItem>(
      data: item,
      feedback: Material(color: Colors.transparent, child: Transform.scale(scale: 1.1, child: chip)),
      childWhenDragging: Opacity(opacity: 0.25, child: chip),
      child: chip,
    );
  }
}
