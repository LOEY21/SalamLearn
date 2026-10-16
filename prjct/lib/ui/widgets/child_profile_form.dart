import 'dart:io' show Platform;
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:flutter/services.dart';
import 'package:salamlearn/logic/localization/app_translations.dart';

import '../theme/app_colors.dart';
import 'learner_avatar.dart';
import 'soft_card.dart';

/// Shared building blocks for the parent-facing child profile forms —
/// "Create child profile" (`learner_setup_screen.dart`) and "Edit child
/// profile" (`edit_child_profile_screen.dart`) — in the Parent Hub's visual
/// language: teal patterned header, cream canvas, white sheets, Baloo 2
/// display type. Everything here reflows by available width and system
/// text size instead of truncating.

FontWeight _fw(double w) => FontWeight.values[(w / 100).round() - 1];

/// Display face (Baloo 2, variable font — the weight has to be set as an
/// explicit axis value, not just a [FontWeight]).
TextStyle displayText(
  double size, {
  double weight = 700,
  Color color = AppColors.ink,
  double height = 1.15,
}) => TextStyle(
  fontFamily: 'Baloo2Var',
  fontSize: size,
  fontWeight: _fw(weight),
  fontVariations: [FontVariation.weight(weight)],
  color: color,
  height: height,
);

/// Width available per unit of system text scale — layouts compare this to
/// a threshold so a phone at 200% text restacks like a narrower phone.
double scaledExtent(BuildContext context, double extent) =>
    extent / MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 3.0);

/// Tiled eight-point stars (two overlapping squares, one turned 45°) in
/// near-transparent white — the khatam motif from madrasah tilework.
class KhatamPatternPainter extends CustomPainter {
  const KhatamPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const cell = 46.0;
    const r = 13.0;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final star = Path();
    for (final turn in [0.0, pi / 4]) {
      for (var k = 0; k < 4; k++) {
        final a = turn + k * pi / 2 + pi / 4;
        final p = Offset(cos(a) * r, sin(a) * r);
        if (k == 0) {
          star.moveTo(p.dx, p.dy);
        } else {
          star.lineTo(p.dx, p.dy);
        }
      }
      star.close();
    }
    for (var y = 0.0; y < size.height + cell; y += cell) {
      final offsetX = (y / cell).round().isOdd ? cell / 2 : 0.0;
      for (var x = -cell; x < size.width + cell; x += cell) {
        canvas.drawPath(star.shift(Offset(x + offsetX, y)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant KhatamPatternPainter oldDelegate) => false;
}

/// Teal header for the child forms: back button, title, supporting line,
/// and optionally the child's avatar or a step progress bar.
class ChildFormHeader extends StatelessWidget {
  const ChildFormHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onBack,
    this.avatar,
    this.step,
    this.stepCount,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final String? avatar;

  /// Zero-based current step; shows "Step n of m" + segments when set.
  final int? step;
  final int? stepCount;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      child: ColoredBox(
        color: AppColors.teal,
        child: CustomPaint(
          painter: const KhatamPatternPainter(),
          child: SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 18, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Tooltip(
                          message: 'Back'.tr,
                          child: Material(
                            color: Colors.white.withValues(alpha: 0.14),
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: onBack,
                              child: const SizedBox(
                                width: 44,
                                height: 44,
                                child: Icon(
                                  Icons.arrow_back_rounded,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (avatar != null) ...[
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: AppColors.gold,
                                  shape: BoxShape.circle,
                                ),
                                child: LearnerAvatar(avatar: avatar!, size: 52),
                              ),
                              const SizedBox(width: 14),
                            ],
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (step != null && stepCount != null)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Text(
                                        'Step ${step! + 1} of $stepCount',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white.withValues(
                                            alpha: 0.85,
                                          ),
                                        ),
                                      ),
                                    ),
                                  Text(
                                    title,
                                    style: displayText(
                                      26,
                                      weight: 800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    subtitle,
                                    style: TextStyle(
                                      fontSize: 14,
                                      height: 1.4,
                                      color: Colors.white.withValues(
                                        alpha: 0.88,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (step != null && stepCount != null) ...[
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: _StepSegments(step: step!, count: stepCount!),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepSegments extends StatelessWidget {
  const _StepSegments({required this.step, required this.count});

  final int step;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Step ${step + 1} of $count',
      child: Row(
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutQuart,
                height: 6,
                decoration: BoxDecoration(
                  color: i <= step
                      ? AppColors.gold
                      : Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Page frame for the child forms: header, scrolling form body and a
/// bottom action bar that rides above the keyboard. On short windows
/// (landscape phone, large text) the header scrolls away with the form
/// instead of squeezing it.
class ChildFormScaffold extends StatelessWidget {
  const ChildFormScaffold({
    super.key,
    required this.header,
    required this.body,
    this.bottomBar,
  });

  final Widget header;
  final Widget body;
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.cream,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final short = scaledExtent(context, constraints.maxHeight) < 640;
            final scrollBody = SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [if (short) header, body],
              ),
            );
            return Column(
              children: [
                if (!short) header,
                Expanded(child: scrollBody),
                ?bottomBar,
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Bottom action bar: buttons side by side, capped to the form's width.
class ChildFormBottomBar extends StatelessWidget {
  const ChildFormBottomBar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.creamBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  for (final (i, child) in children.indexed) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(child: child),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Primary / secondary button for [ChildFormBottomBar]. The label scales
/// down rather than clipping when space is tight.
class ChildFormButton extends StatelessWidget {
  const ChildFormButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.primary = true,
    this.color = AppColors.teal,
    this.foreground = Colors.white,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool primary;
  final Color color;
  final Color foreground;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final content = busy
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              color: primary ? foreground : color,
            ),
          )
        : FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, maxLines: 1),
                if (icon != null) ...[
                  const SizedBox(width: 6),
                  Icon(icon, size: 18),
                ],
              ],
            ),
          );
    const shape = StadiumBorder();
    const textStyle = TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800);
    final size = Size(
      64,
      max(52, MediaQuery.textScalerOf(context).scale(16) + 32),
    );
    return primary
        ? FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: color,
              foregroundColor: foreground,
              minimumSize: size,
              shape: shape,
              textStyle: textStyle,
            ),
            onPressed: busy ? null : onPressed,
            child: content,
          )
        : OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.ink,
              minimumSize: size,
              side: const BorderSide(color: AppColors.creamBorder, width: 1.6),
              shape: shape,
              textStyle: textStyle,
            ),
            onPressed: busy ? null : onPressed,
            child: content,
          );
  }
}

/// White sheet with a display-face heading — one group of fields.
class ChildFormSection extends StatelessWidget {
  const ChildFormSection({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.color = AppColors.surface,
    this.borderColor,
    this.titleColor = AppColors.ink,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Color color;
  final Color? borderColor;
  final Color titleColor;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      radius: 20,
      color: color,
      borderColor: borderColor,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: displayText(18, color: titleColor)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: AppColors.inkSoft,
              ),
            ),
          ],
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

/// Label above the control (not a floating label — those get cut off with
/// "…" at large text sizes), with an optional helper line under it.
class ChildFieldLabel extends StatelessWidget {
  const ChildFieldLabel(this.text, {super.key, this.helper, this.trailing});

  final String text;
  final String? helper;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 2,
            children: [
              Text(
                text,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              ?trailing,
            ],
          ),
          if (helper != null) ...[
            const SizedBox(height: 2),
            Text(
              helper!,
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                color: AppColors.inkSoft,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

InputDecoration _fieldDecoration({
  String? hint,
  Widget? suffix,
  bool readOnly = false,
  String? prefixText,
}) {
  OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: color, width: width),
  );
  return InputDecoration(
    hintText: hint?.tr,
    hintStyle: const TextStyle(color: AppColors.inkSoft),
    prefixText: prefixText,
    prefixStyle: const TextStyle(fontSize: 15.5, color: AppColors.inkSoft),
    filled: true,
    fillColor: readOnly ? AppColors.creamDark : AppColors.neutralTint,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    suffixIcon: suffix,
    border: border(AppColors.creamBorder, 1.4),
    enabledBorder: border(AppColors.creamBorder, 1.4),
    focusedBorder: border(AppColors.teal, 1.8),
  );
}

/// Text field for the child forms; label goes above via [ChildFieldLabel].
class ChildTextField extends StatefulWidget {
  const ChildTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.hint,
    this.obscureText = false,
    this.readOnly = false,
    this.keyboardType = TextInputType.text,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
    this.inputFormatters,
    this.autofillHints,
    this.wrap = false,
    this.prefixText,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hint;
  final bool obscureText;
  final bool readOnly;
  final TextInputType keyboardType;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;

  /// Fixed text before the value that isn't part of it (e.g. `+63 `).
  final String? prefixText;

  /// Grow onto more lines instead of scrolling sideways, so a long name is
  /// always fully visible. Read-only fields always wrap.
  final bool wrap;

  @override
  State<ChildTextField> createState() => _ChildTextFieldState();
}

class _ChildTextFieldState extends State<ChildTextField> {
  late bool _obscured = widget.obscureText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      obscureText: _obscured,
      readOnly: widget.readOnly,
      minLines: 1,
      maxLines: widget.obscureText
          ? 1
          : (widget.wrap || widget.readOnly ? null : 1),
      textInputAction: TextInputAction.next,
      keyboardType: widget.keyboardType,
      textCapitalization: widget.textCapitalization,
      onChanged: widget.onChanged,
      inputFormatters: widget.inputFormatters,
      autofillHints: widget.autofillHints,
      style: TextStyle(
        fontSize: 15.5,
        color: widget.readOnly ? AppColors.inkSoft : AppColors.ink,
      ),
      decoration: _fieldDecoration(
        hint: widget.hint,
        readOnly: widget.readOnly,
        prefixText: widget.prefixText,
        suffix: widget.obscureText
            ? IconButton(
                tooltip: _obscured ? 'Show password'.tr : 'Hide password'.tr,
                icon: Icon(
                  _obscured
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.inkSoft,
                  size: 20,
                ),
                onPressed: () => setState(() => _obscured = !_obscured),
              )
            : widget.readOnly
            ? const Icon(
                Icons.lock_outline_rounded,
                size: 18,
                color: AppColors.inkSoft,
              )
            : null,
      ),
    );
  }
}

/// Kinder + Grade 1–6 dropdown. A saved grade outside that list (older profiles
/// stored free text) is kept as an extra option rather than dropped.
class GradePicker extends StatelessWidget {
  const GradePicker({super.key, required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final grades = ['Kinder', for (var g = 1; g <= 6; g++) 'Grade $g'];
    if (value != null && value!.isNotEmpty && !grades.contains(value)) {
      grades.insert(0, value!);
    }
    return DropdownButtonFormField<String>(
      initialValue: value == null || value!.isEmpty ? null : value,
      isExpanded: true,
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: AppColors.inkSoft,
      ),
      style: const TextStyle(fontSize: 15.5, color: AppColors.ink),
      decoration: _fieldDecoration(hint: 'Select grade'),
      items: [
        for (final g in grades) DropdownMenuItem(value: g, child: Text(g)),
      ],
      onChanged: onChanged,
    );
  }
}

/// Age chips 5–11 (the curriculum's range) plus an "Other age" chip that
/// reveals a number field. Chips wrap onto more lines rather than shrink.
class AgePicker extends StatefulWidget {
  const AgePicker({super.key, required this.age, required this.onChanged});

  final int age;
  final ValueChanged<int> onChanged;

  @override
  State<AgePicker> createState() => _AgePickerState();
}

class _AgePickerState extends State<AgePicker> {
  late bool _custom = widget.age < 5 || widget.age > 11;
  late final _customC = TextEditingController(
    text: _custom ? '${widget.age}' : '',
  );

  @override
  void dispose() {
    _customC.dispose();
    super.dispose();
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    bool round = true,
  }) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.teal : AppColors.surface,
        shape: round
            ? CircleBorder(
                side: BorderSide(
                  color: selected ? AppColors.teal : AppColors.creamBorder,
                  width: 1.6,
                ),
              )
            : StadiumBorder(
                side: BorderSide(
                  color: selected ? AppColors.teal : AppColors.creamBorder,
                  width: 1.6,
                ),
              ),
        child: InkWell(
          customBorder: round ? const CircleBorder() : const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: round ? 6 : 16),
              child: Center(
                widthFactor: 1,
                child: Text(
                  label,
                  style: round
                      ? displayText(
                          18,
                          weight: 700,
                          color: selected ? Colors.white : AppColors.ink,
                        )
                      : TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: selected ? Colors.white : AppColors.ink,
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var a = 5; a <= 11; a++)
              _chip(
                label: '$a',
                selected: !_custom && widget.age == a,
                onTap: () {
                  setState(() => _custom = false);
                  widget.onChanged(a);
                },
              ),
            _chip(
              label: 'Other age',
              round: false,
              selected: _custom,
              onTap: () => setState(() => _custom = true),
            ),
          ],
        ),
        if (_custom) ...[
          const SizedBox(height: 12),
          ChildTextField(
            controller: _customC,
            hint: 'Enter age',
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (v) {
              final parsed = int.tryParse(v);
              if (parsed != null) widget.onChanged(parsed);
            },
          ),
        ],
      ],
    );
  }
}

/// Amir / Amira companion picker. Side by side when there's room, stacked
/// on the narrowest screens or at very large text sizes. The selected
/// mascot gently floats (skipped under reduced motion and in tests).
class CompanionPicker extends StatefulWidget {
  const CompanionPicker({
    super.key,
    required this.avatar,
    required this.onChanged,
    this.compact = false,
  });

  final String avatar;
  final ValueChanged<String> onChanged;

  /// Shorter mascot art — for the edit screen, where the picker shares the
  /// page with the rest of the form.
  final bool compact;

  @override
  State<CompanionPicker> createState() => _CompanionPickerState();
}

class _CompanionPickerState extends State<CompanionPicker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animate =
        !MediaQuery.disableAnimationsOf(context) &&
        (kIsWeb || !Platform.environment.containsKey('FLUTTER_TEST'));
    if (animate && !_float.isAnimating) {
      _float.repeat(reverse: true);
    } else if (!animate) {
      _float.stop();
    }
  }

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cards = [
      _CompanionCard(
        imagePath: 'assets/images/boy_mascot_full_body.png',
        name: 'Amir',
        detail: 'Boy companion',
        selected: widget.avatar == 'boy_mascot',
        color: AppColors.teal,
        float: _float,
        artHeight: widget.compact ? 120 : 170,
        onTap: () => widget.onChanged('boy_mascot'),
      ),
      _CompanionCard(
        imagePath: 'assets/images/girl_mascot_full_body.png',
        name: 'Amira',
        detail: 'Girl companion',
        selected: widget.avatar == 'girl_mascot',
        color: AppColors.gold,
        float: _float,
        artHeight: widget.compact ? 120 : 170,
        onTap: () => widget.onChanged('girl_mascot'),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        if (scaledExtent(context, constraints.maxWidth) < 260) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [cards[0], const SizedBox(height: 12), cards[1]],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 12),
            Expanded(child: cards[1]),
          ],
        );
      },
    );
  }
}

class _CompanionCard extends StatelessWidget {
  const _CompanionCard({
    required this.imagePath,
    required this.name,
    required this.detail,
    required this.selected,
    required this.color,
    required this.float,
    required this.artHeight,
    required this.onTap,
  });

  final String imagePath;
  final String name;
  final String detail;
  final bool selected;
  final Color color;
  final Animation<double> float;
  final double artHeight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = color == AppColors.teal ? AppColors.mint : AppColors.goldTint;
    return Semantics(
      button: true,
      selected: selected,
      label: '$name, $detail',
      child: Material(
        color: selected ? tint : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: selected ? color : AppColors.creamBorder,
            width: selected ? 2.4 : 1.4,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
            child: Column(
              children: [
                SizedBox(
                  height: artHeight,
                  child: AnimatedBuilder(
                    animation: float,
                    builder: (context, child) => Transform.translate(
                      offset: Offset(0, selected ? -6 * float.value : 0),
                      child: child,
                    ),
                    child: Image.asset(imagePath, fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected ? color : Colors.transparent,
                        border: Border.all(
                          color: selected ? color : AppColors.creamBorder,
                          width: 2,
                        ),
                      ),
                      child: selected
                          ? const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 14,
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(name, style: displayText(18, weight: 800)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
