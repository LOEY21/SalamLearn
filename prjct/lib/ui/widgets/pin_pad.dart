import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 4-digit PIN pad matching mockup Figure 4.2: soft outlined keys on
/// cream, teal-filled progress dots, shake on wrong entry.
class PinPad extends StatefulWidget {
  const PinPad({super.key, required this.onSubmit});

  /// Called with the 4-digit string; return false to shake and clear.
  final bool Function(String pin) onSubmit;

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
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _error
                        ? AppColors.danger
                        : (i < _entry.length
                            ? AppColors.teal
                            : Colors.transparent),
                    border: Border.all(
                      color: _error
                          ? AppColors.danger
                          : (i < _entry.length
                              ? AppColors.teal
                              : AppColors.mintBorder),
                      width: 2,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['', '0', '<'],
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final key in row)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    child: key.isEmpty
                        ? const SizedBox(width: 80, height: 80)
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

class _PinKey extends StatelessWidget {
  const _PinKey({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const CircleBorder(
        side: BorderSide(color: AppColors.mintBorder, width: 1.6),
      ),
      elevation: 1,
      shadowColor: AppColors.ink.withValues(alpha: 0.08),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 80,
          height: 80,
          child: Center(
            child: label == '<'
                ? const Icon(Icons.backspace_outlined,
                    color: AppColors.ink, size: 26)
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
