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
