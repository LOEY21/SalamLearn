import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../logic/auth/session.dart';
import '../theme/app_colors.dart';

/// Creates the Learner entity (FR-2.3). Redesigned into a premium, progressive
/// 3-step setup wizard to optimize child profile onboarding.
class LearnerSetupScreen extends ConsumerStatefulWidget {
  const LearnerSetupScreen({super.key});

  @override
  ConsumerState<LearnerSetupScreen> createState() => _LearnerSetupScreenState();
}

/// Capitalizes just the first character typed into a name field, leaving
/// the rest alone (these are single-word first/middle/last-name boxes).
class _CapitalizeFirstLetterFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;
    final capitalized = text[0].toUpperCase() + text.substring(1);
    if (capitalized == text) return newValue;
    return newValue.copyWith(text: capitalized);
  }
}

class _LearnerSetupScreenState extends ConsumerState<LearnerSetupScreen>
    with TickerProviderStateMixin {
  final _firstNameC = TextEditingController();
  final _middleNameC = TextEditingController();
  final _lastNameC = TextEditingController();
  final _usernameC = TextEditingController();
  final _customAgeC = TextEditingController();

  // Confirms parent's password to authorize child profile creation.
  final _parentPasswordC = TextEditingController();

  String? _gradeLevel;
  int _age = 7;
  bool _isCustomAge = false;
  String _avatar = 'boy_mascot'; // Default to boy mascot
  int _step = 0; // 0: Basic Info, 1: Security, 2: Avatar selection

  late final AnimationController _mascotFloatController;

  @override
  void initState() {
    super.initState();
    _mascotFloatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (kIsWeb || !Platform.environment.containsKey('FLUTTER_TEST')) {
      _mascotFloatController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _firstNameC.dispose();
    _middleNameC.dispose();
    _lastNameC.dispose();
    _usernameC.dispose();
    _customAgeC.dispose();
    _parentPasswordC.dispose();
    _mascotFloatController.dispose();
    super.dispose();
  }

  void _onStep0Next() {
    final firstName = _firstNameC.text.trim();
    final lastName = _lastNameC.text.trim();
    final gradeLevel = _gradeLevel ?? '';

    if (firstName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter first name')),
      );
      return;
    }
    if (lastName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter last name')),
      );
      return;
    }
    if (gradeLevel.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter grade level')),
      );
      return;
    }

    setState(() => _step = 1);
  }

  void _onStep1Next() {
    final username = _usernameC.text.trim();
    final parentPassword = _parentPasswordC.text;

    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter username')),
      );
      return;
    }
    if (parentPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please confirm your password')),
      );
      return;
    }
    if (!ref
        .read(sessionProvider.notifier)
        .verifyActiveParentPassword(parentPassword)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incorrect password')),
      );
      return;
    }

    setState(() => _step = 2);
  }

  void _submitProfile() {
    final firstName = _firstNameC.text.trim();
    final lastName = _lastNameC.text.trim();
    final gradeLevel = _gradeLevel ?? '';
    final username = _usernameC.text.trim();

    final fullName = _middleNameC.text.trim().isEmpty
        ? '$firstName $lastName'
        : '$firstName ${_middleNameC.text.trim()} $lastName';

    final router = GoRouter.of(context);
    final from = GoRouterState.of(context).uri.queryParameters['from'];
    ref
        .read(sessionProvider.notifier)
        .createLearner(
          name: fullName,
          age: _age,
          avatar: _avatar,
          gradeLevel: gradeLevel,
          username: username,
        )
        .then((_) {
          if (!mounted) return;
          router.go(from == 'parent' ? '/parent?tab=1' : '/hub');
        });
  }

  @override
  Widget build(BuildContext context) {
    void goBack() {
      if (_step > 0) {
        setState(() => _step--);
      } else {
        final from = GoRouterState.of(context).uri.queryParameters['from'];
        context.go(from == 'parent' ? '/parent?tab=1' : '/hub');
      }
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) goBack();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(
            _step == 0
                ? 'Basic Info'
                : (_step == 1 ? 'Account Setup' : 'Choose Your Companion'),
          ),
          backgroundColor: Colors.white,
          foregroundColor: AppColors.ink,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: goBack,
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Stepper progress indicator bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: _buildStepper(),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.15, 0.0),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        ),
                      ),
                      child: FadeTransition(
                        opacity: animation,
                        child: child,
                      ),
                    );
                  },
                  child: SingleChildScrollView(
                    key: ValueKey<int>(_step),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                    child: _buildCurrentStepView(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepper() {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          // Progress bar spans half screen for Step 1, full screen for Step 2.
          final progressWidth = totalWidth * (_step / 2.0);

          return Stack(
            alignment: Alignment.center,
            children: [
              // Unfilled progress indicator line
              Container(
                height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: AppColors.creamBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Filled progress indicator line
              Positioned(
                left: 20,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                  height: 4,
                  width: progressWidth > 40 ? progressWidth - 40 : 0,
                  decoration: BoxDecoration(
                    color: AppColors.teal,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // The circular progress step dots
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStepDot(0, '1'),
                  _buildStepDot(1, '2'),
                  _buildStepDot(2, '3'),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStepDot(int step, String label) {
    final isActive = _step == step;
    final isCompleted = _step > step;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isCompleted
            ? AppColors.teal
            : (isActive ? Colors.white : AppColors.surface),
        border: Border.all(
          color: (isActive || isCompleted) ? AppColors.teal : AppColors.creamBorder,
          width: 3,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppColors.teal.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: isCompleted
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
          : Text(
              label,
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 14,
                fontWeight: FontWeight.w900,
                color: isCompleted
                    ? Colors.white
                    : (isActive ? AppColors.teal : AppColors.textMuted),
              ),
            ),
    );
  }

  Widget _buildAgeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.spaceBetween,
          children: [
            for (int age = 5; age <= 11; age++)
              GestureDetector(
                onTap: () => setState(() {
                  _age = age;
                  _isCustomAge = false;
                }),
                child: AnimatedScale(
                  scale: !_isCustomAge && _age == age ? 1.15 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: !_isCustomAge && _age == age
                          ? AppColors.teal
                          : Colors.white,
                      border: Border.all(
                        color: !_isCustomAge && _age == age
                            ? AppColors.teal
                            : AppColors.creamBorder,
                        width: 2,
                      ),
                      boxShadow: !_isCustomAge && _age == age
                          ? [
                              BoxShadow(
                                color: AppColors.teal.withValues(alpha: 0.25),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$age',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: !_isCustomAge && _age == age
                            ? Colors.white
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
            GestureDetector(
              onTap: () => setState(() => _isCustomAge = true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: _isCustomAge ? AppColors.teal : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isCustomAge ? AppColors.teal : AppColors.creamBorder,
                    width: 2,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Please specify',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: _isCustomAge ? Colors.white : AppColors.textMuted,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_isCustomAge) ...[
          const SizedBox(height: 12),
          _TextField(
            controller: _customAgeC,
            label: 'Age',
            hint: 'Enter age',
            keyboardType: TextInputType.number,
            onChanged: (v) {
              final parsed = int.tryParse(v);
              if (parsed != null) setState(() => _age = parsed);
            },
          ),
        ],
      ],
    );
  }

  Widget _buildCurrentStepView() {
    switch (_step) {
      case 0:
        return Column(
          key: const ValueKey<int>(0),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _StepHeader(
              title: 'Basic Learner Info',
              subtitle: 'Tell us about your child to customize their Madrasah roadmap.',
            ),
            _TextField(
              controller: _firstNameC,
              label: 'First Name',
              inputFormatters: [_CapitalizeFirstLetterFormatter()],
            ),
            const SizedBox(height: 14),
            _TextField(
              controller: _middleNameC,
              label: 'Middle Name (optional)',
              inputFormatters: [_CapitalizeFirstLetterFormatter()],
            ),
            const SizedBox(height: 14),
            _TextField(
              controller: _lastNameC,
              label: 'Last Name',
              inputFormatters: [_CapitalizeFirstLetterFormatter()],
            ),
            const SizedBox(height: 14),
            const _FieldLabel('Grade Level'),
            _GradeDropdown(
              value: _gradeLevel,
              onChanged: (v) => setState(() => _gradeLevel = v),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Age',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                Text(
                  '$_age years old',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: AppColors.teal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildAgeSelector(),
            const SizedBox(height: 36),
            SizedBox(
              height: 54,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                onPressed: _onStep0Next,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Next: Account Setup',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 18),
                  ],
                ),
              ),
            ),
          ],
        );
      case 1:
        return Column(
          key: const ValueKey<int>(1),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _StepHeader(
              title: 'Account Security',
              subtitle: 'Define a child username and verify parent credentials.',
            ),
            _TextField(
              controller: _usernameC,
              label: 'Username',
            ),
            const SizedBox(height: 24),
            const _FieldLabel('Confirm Parent Password'),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                "Re-enter your account password to verify authority for creating new profiles.",
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            _TextField(
              controller: _parentPasswordC,
              obscureText: true,
            ),
            const SizedBox(height: 36),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 54,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.ink,
                        side: const BorderSide(
                          color: AppColors.creamBorder,
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      onPressed: () => setState(() => _step = 0),
                      child: const Text(
                        'Back',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 54,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.teal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      onPressed: _onStep1Next,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Next',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      case 2:
      default:
        return Column(
          key: const ValueKey<int>(2),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _StepHeader(
              title: 'Choose Your Companion',
              subtitle: 'Select Amir or Zara to be your child\'s learning companion!',
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _AvatarSelectionCard(
                    imagePath: 'assets/images/boy_mascot_full_body.png',
                    label: 'Amir (Boy Mascot)',
                    isSelected: _avatar == 'boy_mascot',
                    themeColor: AppColors.teal,
                    floatAnimation: _mascotFloatController,
                    onTap: () => setState(() => _avatar = 'boy_mascot'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _AvatarSelectionCard(
                    imagePath: 'assets/images/girl_mascot_full_body.png',
                    label: 'Zara (Girl Mascot)',
                    isSelected: _avatar == 'girl_mascot',
                    themeColor: AppColors.gold,
                    floatAnimation: _mascotFloatController,
                    onTap: () => setState(() => _avatar = 'girl_mascot'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 48),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 54,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.ink,
                        side: const BorderSide(
                          color: AppColors.creamBorder,
                          width: 2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      onPressed: () => setState(() => _step = 1),
                      child: const Text(
                        'Back',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: 54,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.ink,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      onPressed: _submitProfile,
                      child: const Text(
                        'Create Profile',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
    }
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
    );
  }
}

class _TextField extends StatefulWidget {
  const _TextField({
    this.controller,
    this.label,
    this.hint,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.onChanged,
    this.inputFormatters,
  });

  final TextEditingController? controller;

  /// Floats up into the border on focus when set; falls back to a plain
  /// hint (no float) when omitted, e.g. the inline custom-age field.
  final String? label;
  final String? hint;
  final bool obscureText;
  final TextInputType keyboardType;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? inputFormatters;

  @override
  State<_TextField> createState() => _TextFieldState();
}

class _TextFieldState extends State<_TextField> {
  late bool _obscured;
  final _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _obscured = widget.obscureText;
    _focusNode.addListener(() {
      setState(() => _focused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: AppColors.teal.withValues(alpha: 0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        obscureText: _obscured,
        keyboardType: widget.keyboardType,
        onChanged: widget.onChanged,
        inputFormatters: widget.inputFormatters,
        decoration: InputDecoration(
          label: widget.label == null ? null : Text(widget.label!),
          hintText: widget.hint,
          labelStyle: const TextStyle(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w700,
          ),
          floatingLabelStyle: const TextStyle(
            color: AppColors.teal,
            fontWeight: FontWeight.w700,
          ),
          filled: true,
          fillColor: AppColors.neutralTint,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          suffixIcon: widget.obscureText
              ? IconButton(
                  icon: Icon(
                    _obscured
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscured = !_obscured),
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: AppColors.creamBorder,
              width: 1.4,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: AppColors.creamBorder,
              width: 1.4,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.teal, width: 1.8),
          ),
        ),
      ),
    );
  }
}

class _GradeDropdown extends StatelessWidget {
  const _GradeDropdown({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textMuted),
      decoration: InputDecoration(
        hintText: 'Select grade',
        filled: true,
        fillColor: AppColors.neutralTint,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.creamBorder, width: 1.4),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.creamBorder, width: 1.4),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.teal, width: 1.6),
        ),
      ),
      items: [
        for (int grade = 1; grade <= 6; grade++)
          DropdownMenuItem(value: 'Grade $grade', child: Text('Grade $grade')),
      ],
      onChanged: onChanged,
    );
  }
}

class _AvatarSelectionCard extends StatelessWidget {
  const _AvatarSelectionCard({
    required this.imagePath,
    required this.label,
    required this.isSelected,
    required this.themeColor,
    required this.floatAnimation,
    required this.onTap,
  });

  final String imagePath;
  final String label;
  final bool isSelected;
  final Color themeColor;
  final Animation<double> floatAnimation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: isSelected ? 1.04 : 0.96,
        duration: const Duration(milliseconds: 250),
        curve: Curves.elasticOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected ? themeColor : AppColors.creamBorder,
              width: isSelected ? 3.0 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? themeColor.withValues(alpha: 0.15)
                    : const Color(0x06000000),
                blurRadius: isSelected ? 16 : 8,
                offset: Offset(0, isSelected ? 6 : 4),
              ),
            ],
          ),
          child: Column(
            children: [
              SizedBox(
                height: 180,
                child: AnimatedBuilder(
                  animation: floatAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(
                        0,
                        isSelected ? -6 * floatAnimation.value : 0,
                      ),
                      child: child,
                    );
                  },
                  child: Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          height: 22,
                          margin: const EdgeInsets.symmetric(horizontal: 18),
                          decoration: BoxDecoration(
                            color: themeColor.withValues(
                              alpha: isSelected ? 0.16 : 0.08,
                            ),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Image.asset(imagePath, fit: BoxFit.contain),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: isSelected ? themeColor : AppColors.ink,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? themeColor : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? themeColor : AppColors.creamBorder,
                    width: 2,
                  ),
                ),
                alignment: Alignment.center,
                child: isSelected
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 13,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
