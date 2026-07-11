import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../logic/auth/session.dart';
import '../theme/app_colors.dart';

/// Creates the Learner entity (FR-2.3). Updated to mirror learner sign up fields.
class LearnerSetupScreen extends ConsumerStatefulWidget {
  const LearnerSetupScreen({super.key});

  @override
  ConsumerState<LearnerSetupScreen> createState() => _LearnerSetupScreenState();
}

class _LearnerSetupScreenState extends ConsumerState<LearnerSetupScreen>
    with TickerProviderStateMixin {
  final _firstNameC = TextEditingController();
  final _middleNameC = TextEditingController();
  final _lastNameC = TextEditingController();
  final _gradeC = TextEditingController();
  final _usernameC = TextEditingController();
  // Not the child's own credential — the Student Hub's own sign-in is
  // tap-an-avatar only, never a typed password. This re-confirms the
  // *parent's* existing account password, as proof the actual account
  // holder is the one creating this profile.
  final _parentPasswordC = TextEditingController();

  int _age = 7;
  String _avatar = 'boy_mascot'; // Default to boy mascot
  int _step = 0; // 0: Info, 1: Avatar selection

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
    _gradeC.dispose();
    _usernameC.dispose();
    _parentPasswordC.dispose();
    _mascotFloatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    void goBack() {
      if (_step == 1) {
        setState(() => _step = 0);
      } else {
        final from = GoRouterState.of(context).uri.queryParameters['from'];
        context.go(from == 'parent' ? '/parent' : '/hub');
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
            _step == 0 ? 'Create Learner Profile' : 'Choose Your Avatar',
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_step == 0) ...[
                  const _FieldLabel('First name'),
                  _TextField(controller: _firstNameC, hint: 'e.g. Amir'),
                  const SizedBox(height: 14),
                  const _FieldLabel('Middle name (optional)'),
                  _TextField(controller: _middleNameC, hint: 'e.g. Ahmad'),
                  const SizedBox(height: 14),
                  const _FieldLabel('Last name'),
                  _TextField(controller: _lastNameC, hint: 'e.g. Ali'),
                  const SizedBox(height: 14),
                  const _FieldLabel('Grade Level'),
                  _TextField(controller: _gradeC, hint: 'e.g. Grade 1'),
                  const SizedBox(height: 16),
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
                          fontWeight: FontWeight.w700,
                          color: AppColors.teal,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _age.toDouble(),
                    min: 5,
                    max: 11,
                    divisions: 6,
                    onChanged: (v) => setState(() => _age = v.round()),
                  ),
                  const SizedBox(height: 14),
                  const _FieldLabel('Username'),
                  _TextField(controller: _usernameC, hint: 'e.g. amir_ali'),
                  const SizedBox(height: 14),
                  const _FieldLabel('Confirm your password'),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      "Re-enter your own account password to confirm it's really "
                      'you creating this profile.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                  _TextField(
                    controller: _parentPasswordC,
                    hint: '••••••••',
                    obscureText: true,
                  ),
                  const SizedBox(height: 36),
                  SizedBox(
                    height: 54,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: AppColors.ink,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      onPressed: () {
                        final firstName = _firstNameC.text.trim();
                        final lastName = _lastNameC.text.trim();
                        final gradeLevel = _gradeC.text.trim();
                        final username = _usernameC.text.trim();
                        final parentPassword = _parentPasswordC.text;

                        if (firstName.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter first name'),
                            ),
                          );
                          return;
                        }
                        if (lastName.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter last name'),
                            ),
                          );
                          return;
                        }
                        if (gradeLevel.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter grade level'),
                            ),
                          );
                          return;
                        }
                        if (username.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter username'),
                            ),
                          );
                          return;
                        }
                        if (parentPassword.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please confirm your password'),
                            ),
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

                        // Validated! Move to Step 2 (Avatar Selection)
                        setState(() => _step = 1);
                      },
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Next: Choose Avatar',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  // Step 2: Mascot selection
                  const Center(
                    child: Text(
                      'Choose your mascot avatar',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Center(
                    child: Text(
                      'Select Amir or Zara to be your learning companion!',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
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
                              backgroundColor: AppColors.gold,
                              foregroundColor: AppColors.ink,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            onPressed: () {
                              final firstName = _firstNameC.text.trim();
                              final lastName = _lastNameC.text.trim();
                              final gradeLevel = _gradeC.text.trim();
                              final username = _usernameC.text.trim();

                              final fullName = _middleNameC.text.trim().isEmpty
                                  ? '$firstName $lastName'
                                  : '$firstName ${_middleNameC.text.trim()} $lastName';

                              final from = GoRouterState.of(
                                context,
                              ).uri.queryParameters['from'];
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
                                    if (context.mounted) {
                                      context.go(
                                        from == 'parent' ? '/parent' : '/hub',
                                      );
                                    }
                                  });
                            },
                            child: const Text(
                              'Create Profile',
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
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
    required this.hint,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
  });

  final TextEditingController? controller;
  final String hint;
  final bool obscureText;
  final TextInputType keyboardType;

  @override
  State<_TextField> createState() => _TextFieldState();
}

class _TextFieldState extends State<_TextField> {
  late bool _obscured;

  @override
  void initState() {
    super.initState();
    _obscured = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: _obscured,
      keyboardType: widget.keyboardType,
      decoration: InputDecoration(
        hintText: widget.hint,
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
          borderSide: const BorderSide(color: AppColors.teal, width: 1.6),
        ),
      ),
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
              // Transparent full-body PNG — sits directly on the card with
              // no inner rounded clip (the old ClipRRect cropped the
              // mascot's feet/hands). A soft tinted disc behind it grounds
              // the figure so it doesn't float, and the illustration itself
              // is much larger than before (was 130) so the child can
              // actually see who they're picking.
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
