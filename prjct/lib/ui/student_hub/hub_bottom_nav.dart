import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum HubTab { home, leaderboard, backpack, profile }

/// Shared 4-tab nav for the Student Hub, Leaderboard, Backpack and Profile
/// screens — kept in one place since all four screens render it identically
/// and it needs to stay in sync as a single navigation surface, not several
/// copies that could drift.
class HubBottomNav extends StatelessWidget {
  const HubBottomNav({
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
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.creamBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _NavItem(
              icon: Icons.home_rounded,
              label: 'Home',
              active: active == HubTab.home,
              onTap: onHomeTap,
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.leaderboard_rounded,
              label: 'Leaderboard',
              active: active == HubTab.leaderboard,
              onTap: onLeaderboardTap,
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.backpack_rounded,
              label: 'Backpack',
              active: active == HubTab.backpack,
              onTap: onBackpackTap,
            ),
          ),
          Expanded(
            child: _NavItem(
              icon: Icons.person_rounded,
              label: 'Profile',
              active: active == HubTab.profile,
              onTap: onProfileTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.teal : AppColors.textMuted;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 21),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
