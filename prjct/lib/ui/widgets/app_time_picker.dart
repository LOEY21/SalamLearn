import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';

import '../theme/app_colors.dart';

/// Bottom-sheet time picker matching the hub's own card language (mint
/// highlight track, gold AM/PM toggle, flat teal/neutral buttons) —
/// replaces the stock Material clock-dial [showTimePicker] dialog, whose
/// OS chrome and dial widget don't match the rest of the app.
Future<TimeOfDay?> showAppTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
  String label = 'Select time',
}) {
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AppTimePickerSheet(initialTime: initialTime, label: label),
  );
}

class _AppTimePickerSheet extends StatefulWidget {
  const _AppTimePickerSheet({required this.initialTime, required this.label});

  final TimeOfDay initialTime;
  final String label;

  @override
  State<_AppTimePickerSheet> createState() => _AppTimePickerSheetState();
}

class _AppTimePickerSheetState extends State<_AppTimePickerSheet> {
  static const _itemExtent = 42.0;

  late int _hourIndex; // 0..11, representing hour-of-period 1..12
  late int _minute; // 0..59
  late bool _isAm;
  late final FixedExtentScrollController _hourController;
  late final FixedExtentScrollController _minuteController;

  @override
  void initState() {
    super.initState();
    final hourOfPeriod =
        widget.initialTime.hourOfPeriod == 0 ? 12 : widget.initialTime.hourOfPeriod;
    _hourIndex = hourOfPeriod - 1;
    _minute = widget.initialTime.minute;
    _isAm = widget.initialTime.period == DayPeriod.am;
    _hourController = FixedExtentScrollController(initialItem: _hourIndex);
    _minuteController = FixedExtentScrollController(initialItem: _minute);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  void _submit() {
    final hour24 = _isAm ? (_hourIndex + 1) % 12 : (_hourIndex + 1) % 12 + 12;
    Navigator.of(context).pop(TimeOfDay(hour: hour24, minute: _minute));
  }

  Widget _wheel({
    required FixedExtentScrollController controller,
    required int itemCount,
    required String Function(int index) itemLabel,
    required ValueChanged<int> onChanged,
  }) {
    return ListWheelScrollView.useDelegate(
      controller: controller,
      itemExtent: _itemExtent,
      diameterRatio: 1.4,
      perspective: 0.003,
      useMagnifier: true,
      magnification: 1.15,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: onChanged,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: itemCount,
        builder: (context, index) => Center(
          child: Text(
            itemLabel(index),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.tealDark,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.creamBorder,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Text(
              widget.label.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: _itemExtent * 4,
                  width: 64 * 2 + 20,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        height: _itemExtent,
                        decoration: BoxDecoration(
                          color: AppColors.mint,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.mintBorder),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 64,
                            child: _wheel(
                              controller: _hourController,
                              itemCount: 12,
                              itemLabel: (i) => (i + 1).toString().padLeft(2, '0'),
                              onChanged: (i) => setState(() => _hourIndex = i),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            ':',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textMuted,
                            ),
                          ),
                          const SizedBox(width: 4),
                          SizedBox(
                            width: 64,
                            child: _wheel(
                              controller: _minuteController,
                              itemCount: 60,
                              itemLabel: (i) => i.toString().padLeft(2, '0'),
                              onChanged: (i) => setState(() => _minute = i),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _AmPmButton(
                      label: 'AM',
                      active: _isAm,
                      onTap: () => setState(() => _isAm = true),
                    ),
                    const SizedBox(height: 6),
                    _AmPmButton(
                      label: 'PM',
                      active: !_isAm,
                      onTap: () => setState(() => _isAm = false),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.ink,
                      backgroundColor: AppColors.neutralTint,
                      side: BorderSide.none,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.teal,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Set time',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AmPmButton extends StatelessWidget {
  const _AmPmButton({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? AppColors.gold : AppColors.neutralTint,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          width: 52,
          padding: const EdgeInsets.symmetric(vertical: 9),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: active ? const Color(0xFF2B1E05) : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}
