import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:salamlearn/logic/localization/app_translations.dart';

import '../../logic/auth/session.dart';
import '../theme/app_colors.dart';
import 'pin_pad.dart';
import 'soft_card.dart';

/// Settings "Change PIN" row, shared by the Parent and Teacher dashboards.
/// Opens a sheet that walks current PIN -> new PIN -> confirm new PIN on
/// the same [PinPad] used by the PIN gate screens.
class ChangePinCard extends ConsumerWidget {
  const ChangePinCard({super.key, this.accentColor = AppColors.teal});

  final Color accentColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void open() {
      final left = ref.read(sessionProvider.notifier).pinChangeCooldown();
      if (left != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'You can change your PIN again in ${left.inHours}h ${left.inMinutes % 60}m.',
            ),
          ),
        );
        return;
      }
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => _ChangePinSheet(accentColor: accentColor),
      );
    }

    final button = OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.teal,
        side: const BorderSide(color: AppColors.teal),
      ),
      onPressed: open,
      child: const Text('Change'),
    );
    return SoftCard(
      padding: const EdgeInsets.all(18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Button moves under the text when it would squeeze the title
          // into mid-word breaks (narrow phone / large text).
          final scale = MediaQuery.textScalerOf(
            context,
          ).scale(1).clamp(1.0, 3.0);
          final stacked = constraints.maxWidth / scale < 300;
          return Row(
            crossAxisAlignment: stacked
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: AppColors.mint,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.lock_reset_rounded,
                  color: AppColors.teal,
                  size: 18,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Change PIN',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.ink,
                      ),
                    ),
                    const Text(
                      'Update the 4-digit PIN for this account (once a day)',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                    if (stacked) ...[const SizedBox(height: 10), button],
                  ],
                ),
              ),
              if (!stacked) button,
            ],
          );
        },
      ),
    );
  }
}

enum _PinStep { current, fresh, confirm }

class _ChangePinSheet extends ConsumerStatefulWidget {
  const _ChangePinSheet({required this.accentColor});

  final Color accentColor;

  @override
  ConsumerState<_ChangePinSheet> createState() => _ChangePinSheetState();
}

class _ChangePinSheetState extends ConsumerState<_ChangePinSheet> {
  _PinStep _step = _PinStep.current;
  String _newPin = '';
  String? _error;

  bool _onSubmit(String pin) {
    final notifier = ref.read(sessionProvider.notifier);
    switch (_step) {
      case _PinStep.current:
        if (!notifier.isCurrentPin(pin)) {
          setState(() => _error = 'Incorrect PIN. Try again.');
          return false;
        }
        setState(() {
          _step = _PinStep.fresh;
          _error = null;
        });
      case _PinStep.fresh:
        if (notifier.isCurrentPin(pin)) {
          setState(() => _error = 'Choose a PIN different from your current one.');
          return false;
        }
        setState(() {
          _newPin = pin;
          _step = _PinStep.confirm;
          _error = null;
        });
      case _PinStep.confirm:
        if (pin != _newPin) {
          setState(() => _error = "PINs don't match. Try again.");
          return false;
        }
        _save();
    }
    return true;
  }

  Future<void> _save() async {
    await ref.read(sessionProvider.notifier).changePin(_newPin);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('PIN changed successfully')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_step) {
      _PinStep.current => 'Enter current PIN',
      _PinStep.fresh => 'Enter new PIN',
      _PinStep.confirm => 'Confirm new PIN',
    };
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.creamBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _error ?? 'Step ${_step.index + 1} of 3',
              style: TextStyle(
                fontSize: 13,
                color: _error != null ? AppColors.coral : AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 20),
            PinPad(
              key: ValueKey(_step),
              accentColor: widget.accentColor,
              onSubmit: _onSubmit,
            ),
          ],
        ),
      ),
    );
  }
}
