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
    required this.onBackpackTap,
    required this.onProfileTap,
  });

  final HubTab active;
  final VoidCallback onHomeTap;
  final VoidCallback onBackpackTap;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(color: Color(0x47000000), blurRadius: 24, offset: Offset(0, 10)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _Item(icon: Icons.map_rounded, label: 'Home', active: active == HubTab.home, onTap: onHomeTap),
            ),
            Expanded(
              child: _Item(
                icon: Icons.backpack_rounded,
                label: 'Backpack',
                active: active == HubTab.backpack,
                onTap: onBackpackTap,
              ),
            ),
            Expanded(
              child: _Item(icon: Icons.face_rounded, label: 'Me', active: active == HubTab.profile, onTap: onProfileTap),
            ),
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
          padding: const EdgeInsets.symmetric(vertical: 6),
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
