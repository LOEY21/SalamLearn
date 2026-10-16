import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:salamlearn/logic/localization/app_translations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../logic/auth/session.dart';
import '../theme/app_colors.dart';
import '../widgets/child_profile_form.dart';

/// Creates the Learner entity (FR-2.3) as a 3-step setup: basic info,
/// profile details (nickname + parent password check), then companion.
/// Built from the shared child-form kit so it matches the Parent Hub and
/// the Edit Child Profile screen.
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

class _LearnerSetupScreenState extends ConsumerState<LearnerSetupScreen> {
  final _firstNameC = TextEditingController();
  final _middleNameC = TextEditingController();
  final _lastNameC = TextEditingController();
  final _usernameC = TextEditingController();

  // Confirms parent's password to authorize child profile creation.
  final _parentPasswordC = TextEditingController();

  String? _gradeLevel;
  int _age = 7;
  bool _submitting = false;
  String _avatar = 'boy_mascot'; // Default to boy mascot
  int _step = 0; // 0: Basic Info, 1: Profile details, 2: Avatar selection

  static const _steps = [
    (
      title: 'Basic info',
      subtitle: 'Tell us about your child to set up their Madrasah roadmap.',
    ),
    (
      title: 'Profile details',
      subtitle: 'Choose a nickname and confirm your parent password.',
    ),
    (
      title: 'Choose a companion',
      subtitle: "Pick Amir or Amira to be your child's learning companion.",
    ),
  ];

  @override
  void dispose() {
    _firstNameC.dispose();
    _middleNameC.dispose();
    _lastNameC.dispose();
    _usernameC.dispose();
    _parentPasswordC.dispose();
    super.dispose();
  }

  bool get _step0Complete =>
      _firstNameC.text.trim().isNotEmpty &&
      _lastNameC.text.trim().isNotEmpty &&
      (_gradeLevel ?? '').isNotEmpty;

  bool get _step1Complete =>
      _usernameC.text.trim().isNotEmpty && _parentPasswordC.text.isNotEmpty;

  void _onStep0Next() {
    final firstName = _firstNameC.text.trim();
    final lastName = _lastNameC.text.trim();
    final gradeLevel = _gradeLevel ?? '';

    if (firstName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter first name')));
      return;
    }
    if (lastName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter last name')));
      return;
    }
    if (gradeLevel.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter grade level')));
      return;
    }

    setState(() => _step = 1);
  }

  void _onStep1Next() {
    final username = _usernameC.text.trim();
    final parentPassword = _parentPasswordC.text;

    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a profile nickname')),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Incorrect password')));
      return;
    }

    setState(() => _step = 2);
  }

  Future<void> _submitProfile() async {
    if (_submitting) return;
    final firstName = _firstNameC.text.trim();
    final lastName = _lastNameC.text.trim();
    final gradeLevel = _gradeLevel ?? '';
    final username = _usernameC.text.trim();

    final fullName = _middleNameC.text.trim().isEmpty
        ? '$firstName $lastName'
        : '$firstName ${_middleNameC.text.trim()} $lastName';

    final router = GoRouter.of(context);
    final from = GoRouterState.of(context).uri.queryParameters['from'];
    setState(() => _submitting = true);
    try {
      await ref
          .read(sessionProvider.notifier)
          .createLearner(
            name: fullName,
            age: _age,
            avatar: _avatar,
            gradeLevel: gradeLevel,
            username: username,
          );
      if (mounted) router.go(from == 'parent' ? '/parent?tab=1' : '/hub');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _goBack() {
    if (_step > 0) {
      setState(() => _step--);
    } else {
      final from = GoRouterState.of(context).uri.queryParameters['from'];
      context.go(from == 'parent' ? '/parent?tab=1' : '/hub');
    }
  }

  Widget _stepBody() {
    return switch (_step) {
      0 => ChildFormSection(
        title: "Your child's details",
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ChildFieldLabel('First name'),
            ChildTextField(
              controller: _firstNameC,
              hint: 'e.g. Nurhana',
              onChanged: (_) => setState(() {}),
              inputFormatters: [_CapitalizeFirstLetterFormatter()],
            ),
            const SizedBox(height: 16),
            const ChildFieldLabel('Middle name (optional)'),
            ChildTextField(
              controller: _middleNameC,
              inputFormatters: [_CapitalizeFirstLetterFormatter()],
            ),
            const SizedBox(height: 16),
            const ChildFieldLabel('Last name'),
            ChildTextField(
              controller: _lastNameC,
              hint: 'e.g. Ali',
              onChanged: (_) => setState(() {}),
              inputFormatters: [_CapitalizeFirstLetterFormatter()],
            ),
            const SizedBox(height: 16),
            const ChildFieldLabel('Grade level'),
            GradePicker(
              value: _gradeLevel,
              onChanged: (v) => setState(() => _gradeLevel = v),
            ),
            const SizedBox(height: 18),
            ChildFieldLabel(
              'Age',
              trailing: Text(
                '$_age years old',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.teal,
                ),
              ),
            ),
            AgePicker(age: _age, onChanged: (a) => setState(() => _age = a)),
          ],
        ),
      ),
      1 => ChildFormSection(
        title: 'Profile',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ChildFieldLabel(
              'Profile nickname',
              helper: 'Shown on the Learner Hub and to the teacher.',
            ),
            ChildTextField(
              controller: _usernameC,
              hint: 'e.g. nurhana_ali',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 20),
            const ChildFieldLabel(
              'Confirm parent password',
              helper:
                  'Re-enter your account password to verify authority for '
                  'creating new profiles.',
            ),
            ChildTextField(
              controller: _parentPasswordC,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      _ => ChildFormSection(
        title: 'Learning companion',
        subtitle: 'You can change this later from Edit child profile.',
        child: CompanionPicker(
          avatar: _avatar,
          onChanged: (a) => setState(() => _avatar = a),
        ),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_step];
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _goBack();
      },
      child: ChildFormScaffold(
        header: ChildFormHeader(
          title: step.title,
          subtitle: step.subtitle,
          onBack: _goBack,
          step: _step,
          stepCount: _steps.length,
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOutQuart,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.06, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.topCenter,
                  children: [...previous, ?current],
                ),
                child: KeyedSubtree(key: ValueKey(_step), child: _stepBody()),
              ),
            ),
          ),
        ),
        bottomBar: ChildFormBottomBar(
          children: [
            if (_step > 0)
              ChildFormButton(
                label: 'Back',
                primary: false,
                onPressed: _goBack,
              ),
            switch (_step) {
              0 => ChildFormButton(
                label: 'Next: Profile details',
                icon: Icons.arrow_forward_rounded,
                onPressed: _step0Complete ? _onStep0Next : null,
              ),
              1 => ChildFormButton(
                label: 'Next',
                icon: Icons.arrow_forward_rounded,
                onPressed: _step1Complete ? _onStep1Next : null,
              ),
              _ => ChildFormButton(
                label: 'Create Profile',
                color: AppColors.gold,
                foreground: AppColors.ink,
                busy: _submitting,
                onPressed: _submitProfile,
              ),
            },
          ],
        ),
      ),
    );
  }
}
