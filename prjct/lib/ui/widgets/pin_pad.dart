import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';

import '../theme/app_colors.dart';

/// 4-digit PIN pad — filled digit boxes (lift + accent border when filled)
/// above a borderless circular numpad, floating free on white rather than
/// inside a card. Shake + red boxes on wrong entry.
class PinPad extends StatefulWidget {
  const PinPad({
    super.key,
    required this.onSubmit,
    this.accentColor = AppColors.teal,
  });

  /// Called with the 4-digit string; return false to shake and clear.
  final bool Function(String pin) onSubmit;

  /// Filled-box border/shadow color — teal for the Parent gate, gold for
  /// Teacher/Learner.
  final Color accentColor;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> with SingleTickerProviderStateMixin {
  String _entry = '';
  bool _error = false;
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void _tap(String digit) {
    if (_entry.length >= 4) return;
    setState(() => _entry += digit);
    if (_entry.length == 4) {
      final ok = widget.onSubmit(_entry);
      if (!ok && mounted) {
        _shake.forward(from: 0);
        setState(() => _error = true);
        Future.delayed(const Duration(milliseconds: 420), () {
          if (mounted) {
            setState(() {
              _error = false;
              _entry = '';
            });
          }
        });
      }
    }
  }

  void _backspace() {
    if (_entry.isEmpty) return;
    setState(() => _entry = _entry.substring(0, _entry.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _shake,
          builder: (context, child) {
            final t = _shake.value;
            final dx = t == 0 ? 0.0 : (t * 4).floor().isEven ? 7.0 : -7.0;
            return Transform.translate(offset: Offset(dx, 0), child: child);
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < 4; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: _PinBox(
                    filled: i < _entry.length,
                    error: _error,
                    accentColor: widget.accentColor,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 30),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['', '0', '<'],
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final key in row)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 9),
                    child: key.isEmpty
                        ? const SizedBox(width: 76, height: 76)
                        : _PinKey(
                            label: key,
                            onTap: key == '<' ? _backspace : () => _tap(key),
                          ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PinBox extends StatelessWidget {
  const _PinBox({
    required this.filled,
    required this.error,
    required this.accentColor,
  });

  final bool filled;
  final bool error;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final borderColor = error
        ? AppColors.danger
        : (filled ? accentColor : AppColors.creamBorder);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      width: 46,
      height: 54,
      transform: Matrix4.translationValues(0, filled && !error ? -2 : 0, 0),
      decoration: BoxDecoration(
        color: error
            ? const Color(0xFFFEF2F2)
            : (filled ? AppColors.surface : AppColors.neutralTint),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: filled && !error
            ? [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.28),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: filled
          ? const Text(
              '•',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppColors.ink,
              ),
            )
          : null,
    );
  }
}

class _PinKey extends StatelessWidget {
  const _PinKey({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 76,
          height: 76,
          child: Center(
            child: label == '<'
                ? const Icon(Icons.backspace_outlined,
                    color: AppColors.textMuted, size: 26)
                : Text(
                    label,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
