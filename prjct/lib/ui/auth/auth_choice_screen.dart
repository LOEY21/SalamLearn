import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/remote/firebase_auth_gateway.dart';
import '../../logic/auth/session.dart';
import '../../logic/parent/children_providers.dart';
import '../theme/app_colors.dart';
import '../widgets/auth_loading_overlay.dart';
import '../widgets/learner_avatar.dart';
import '../widgets/role_icons.dart';

enum _Step { hub, signup, signin, activate }

/// Sign in / sign up flow shown right after a role is picked — copied
/// screen-for-screen from the approved HTML preview: one hub screen (Sign
/// Up / Sign In cards) leading to a role-aware sign-up form and a
/// role-aware sign-in form, all inside the same ambient-background shell.
/// No backend yet (standing project constraint) — sign-up/sign-in write
/// straight into the in-memory [SessionNotifier], same as the flows this
/// replaces.
class AuthChoiceScreen extends ConsumerStatefulWidget {
  const AuthChoiceScreen({super.key});

  @override
  ConsumerState<AuthChoiceScreen> createState() => _AuthChoiceScreenState();
}

class _AuthChoiceScreenState extends ConsumerState<AuthChoiceScreen>
    with TickerProviderStateMixin {
  _Step _step = _Step.hub;

  // Drives the hub's own entrance stagger (badge/heading/cards) — plays
  // once on first mount only. Returning to the hub via the back button
  // relies purely on AnimatedSwitcher's fade/slide, not a replayed stagger.
  late final AnimationController _hubC = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  Animation<double> _in(
    AnimationController controller,
    double start,
    double end, {
    Curve curve = Curves.easeOut,
  }) {
    return CurvedAnimation(
      parent: controller,
      curve: Interval(start, end, curve: curve),
    );
  }

  // Built once and reused for the lifetime of this screen — recreating
  // these in build() (which reran on every step change AND every
  // `ref.watch(sessionProvider)` update) leaked a fresh CurvedAnimation
  // listener onto the controller each time, with nothing ever disposing
  // the old ones — the earlier cause of the reported lag.
  late final badgeAnim = _in(_hubC, 0.10, 0.45, curve: Curves.easeOutBack);
  late final headingAnim = _in(_hubC, 0.18, 0.42);
  late final subheadAnim = _in(_hubC, 0.22, 0.46);
  late final card1Anim = _in(_hubC, 0.32, 0.58);
  late final card2Anim = _in(_hubC, 0.40, 0.66);
  late final footnoteAnim = _in(_hubC, 0.50, 0.72);

  void _goStep(_Step step) {
    setState(() => _step = step);
  }

  @override
  void dispose() {
    _hubC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final role = session.activeRole ?? UserRole.learner;
    final isLearner = role == UserRole.learner;
    final copy = _RoleCopy.of(role);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_step != _Step.hub) {
          _goStep(_Step.hub);
        } else {
          context.go('/roles');
        }
      },
      child: SafeArea(
        child: Stack(
          children: [
            // Screen content — a single stack layer, its own top
            // padding (not a real-layout back-button row) clears the
            // overlaid back button, matching the preview's
            // absolutely-positioned button.
            //
            // Transition: as simple as it gets. The outgoing screen is
            // removed instantly (reverseDuration: zero — no exit
            // animation, no crossfade overlap to fight the ambient
            // blobs or double-vision text), and the incoming screen
            // just fades in. One property, no slide, no scale.
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              reverseDuration: Duration.zero,
              switchInCurve: Curves.easeOut,
              layoutBuilder: (currentChild, previousChildren) => Stack(
                fit: StackFit.expand,
                children: [...previousChildren, ?currentChild],
              ),
              transitionBuilder: (child, animation) =>
                  FadeTransition(opacity: animation, child: child),
              child: switch (_step) {
                _Step.hub => _HubView(
                  key: const ValueKey('hub'),
                  isLearner: isLearner,
                  // Asatidz accounts are admin-provisioned only (see the
                  // admin web panel's "Add teacher" — the project owner
                  // decided teachers should never be able to self-register
                  // in-app). Parent self-signup is unaffected.
                  showSignUp: role != UserRole.asatidz,
                  copy: copy,
                  badgeAnim: badgeAnim,
                  headingAnim: headingAnim,
                  subheadAnim: subheadAnim,
                  card1Anim: card1Anim,
                  card2Anim: card2Anim,
                  footnoteAnim: footnoteAnim,
                  // Teacher-only: replaces the removed self-signup card
                  // with "Activate my account" (see `_ActivateView`) —
                  // admin-provisioned teachers still need one first-time
                  // step, just not a registration form.
                  isTeacherActivation: role == UserRole.asatidz,
                  onSignUp: () => _goStep(_Step.signup),
                  onActivate: () => _goStep(_Step.activate),
                  onSignIn: () => _goStep(_Step.signin),
                  onSwitchRole: () => context.go('/roles'),
                ),
                _Step.signup => _SignUpView(
                  key: const ValueKey('signup'),
                  role: role,
                  isLearner: isLearner,
                  copy: copy,
                ),
                _Step.signin => _SignInView(
                  key: const ValueKey('signin'),
                  role: role,
                  isLearner: isLearner,
                  copy: copy,
                  onCreateProfile: () => _goStep(_Step.signup),
                ),
                _Step.activate => const _ActivateView(
                  key: ValueKey('activate'),
                ),
              },
            ),
            // Back button overlay — off the hub it steps back to the hub;
            // on the hub itself it goes back to role selection (previously
            // only reachable via hardware back or the small footnote link
            // at the bottom of the hub).
            Positioned(
              top: 8,
              left: 12,
              child: IconButton(
                onPressed: _step == _Step.hub
                    ? () => context.go('/roles')
                    : () => _goStep(_Step.hub),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.ink,
                  side: const BorderSide(color: AppColors.creamBorder),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ============ Screen 1: role hub ============
class _HubView extends StatelessWidget {
  const _HubView({
    super.key,
    required this.isLearner,
    required this.showSignUp,
    required this.copy,
    required this.badgeAnim,
    required this.headingAnim,
    required this.subheadAnim,
    required this.card1Anim,
    required this.card2Anim,
    required this.footnoteAnim,
    this.isTeacherActivation = false,
    required this.onSignUp,
    required this.onActivate,
    required this.onSignIn,
    required this.onSwitchRole,
  });

  final bool isLearner;

  /// False for Asatidz — teacher accounts are admin-provisioned only (see
  /// the admin web panel's "Add teacher"), so the "Create an account" card
  /// and its divider are hidden entirely for that role; only "Sign in"
  /// remains reachable.
  final bool showSignUp;

  /// True only for Asatidz — shows an "Activate my account" card in place
  /// of the hidden self-signup card (see [showSignUp]'s doc), leading to
  /// [onActivate] / `_ActivateView` instead of a registration form.
  final bool isTeacherActivation;
  final _RoleCopy copy;
  final Animation<double> badgeAnim;
  final Animation<double> headingAnim;
  final Animation<double> subheadAnim;
  final Animation<double> card1Anim;
  final Animation<double> card2Anim;
  final Animation<double> footnoteAnim;
  final VoidCallback onSignUp;
  final VoidCallback onActivate;
  final VoidCallback onSignIn;
  final VoidCallback onSwitchRole;

  @override
  Widget build(BuildContext context) {
    // Mirrors the preview's `.screen{min-height:100%}` + `.actions{margin-
    // top:auto}`: top content stays put, the action cards get pushed toward
    // the bottom via the Spacer when the viewport is tall enough, and the
    // whole thing scrolls if it isn't. Without this, the cards just sat
    // wherever the fixed gaps landed, leaving an uneven empty gap.
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 72, 28, 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - 72 - 24,
            ),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: FadeTransition(
                      opacity: badgeAnim,
                      child: ScaleTransition(
                        scale: badgeAnim.drive(Tween(begin: 0.75, end: 1.0)),
                        child: _RoleBadge(
                          isLearner: isLearner,
                          icon: copy.icon,
                          size: 84,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _FadeUp(
                    animation: headingAnim,
                    child: Text(
                      copy.heading,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  _FadeUp(
                    animation: subheadAnim,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        copy.subtext,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textMuted,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Spacer(),
                  if (!isLearner && (showSignUp || isTeacherActivation)) ...[
                    _FadeUp(
                      animation: card1Anim,
                      child: isTeacherActivation
                          ? _AuthActionCard(
                              primary: true,
                              gold: false,
                              icon: Icons.mark_email_read_outlined,
                              title: 'New Account',
                              desc:
                                  'First time? Activate the account your school administrator created for you.',
                              onTap: onActivate,
                            )
                          : _AuthActionCard(
                              primary: true,
                              gold: isLearner,
                              icon: Icons.person_add_alt_1_rounded,
                              title: copy.signUpTitle,
                              desc: copy.signUpDesc,
                              onTap: onSignUp,
                            ),
                    ),
                    const SizedBox(height: 14),
                    FadeTransition(
                      opacity: card1Anim,
                      child: const Row(
                        children: [
                          Expanded(
                            child: Divider(
                              color: AppColors.creamBorder,
                              height: 1,
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              'OR',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textMuted,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Divider(
                              color: AppColors.creamBorder,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  _FadeUp(
                    animation: card2Anim,
                    child: _AuthActionCard(
                      primary: isLearner ? true : false,
                      gold: isLearner ? true : false,
                      icon: isLearner
                          ? Icons.face_rounded
                          : Icons.login_rounded,
                      title: isLearner
                          ? 'Choose Profile'
                          : isTeacherActivation
                          ? 'Already have an account'
                          : copy.signInTitle,
                      desc: isLearner
                          ? 'Select your profile and start learning!'
                          : copy.signInDesc,
                      onTap: onSignIn,
                    ),
                  ),
                  const SizedBox(height: 18),
                  FadeTransition(
                    opacity: footnoteAnim,
                    child: Center(
                      child: TextButton(
                        onPressed: onSwitchRole,
                        child: Text(
                          'Not ${copy.shortName}? Choose a different profile',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// ============ Screen 2: sign up ============
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

enum _PasswordStrength { none, weak, medium, strong }

/// Simple heuristic: length is weighted most heavily (a long passphrase
/// is stronger than a short mix of character classes), then rewards
/// mixing case, digits, and symbols. Not a substitute for Firebase Auth's
/// own 6-character minimum — this is purely an at-a-glance nudge on the
/// sign-up form, not a hard gate.
_PasswordStrength _scorePassword(String password) {
  if (password.isEmpty) return _PasswordStrength.none;
  if (password.length < 6) return _PasswordStrength.weak;

  var score = 0;
  if (password.length >= 6) score++;
  if (password.length >= 10) score++;
  if (RegExp(r'[a-z]').hasMatch(password)) score++;
  if (RegExp(r'[A-Z]').hasMatch(password)) score++;
  if (RegExp(r'[0-9]').hasMatch(password)) score++;
  if (RegExp(r'[!@#$%^&*(),.?":{}|<>_\-]').hasMatch(password)) score++;

  if (score <= 3) return _PasswordStrength.weak;
  if (score <= 4) return _PasswordStrength.medium;
  return _PasswordStrength.strong;
}

/// Three-segment bar + label, shown under the sign-up password field once
/// the user starts typing.
class _PasswordStrengthMeter extends StatelessWidget {
  const _PasswordStrengthMeter({required this.strength});

  final _PasswordStrength strength;

  @override
  Widget build(BuildContext context) {
    final int filled;
    final Color color;
    final String label;
    switch (strength) {
      case _PasswordStrength.none:
        filled = 0;
        color = AppColors.creamBorder;
        label = '';
      case _PasswordStrength.weak:
        filled = 1;
        color = AppColors.coral;
        label = 'Weak';
      case _PasswordStrength.medium:
        filled = 2;
        color = AppColors.gold;
        label = 'Medium';
      case _PasswordStrength.strong:
        filled = 3;
        color = AppColors.teal;
        label = 'Strong';
    }
    return Row(
      children: [
        for (var i = 0; i < 3; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i == 2 ? 0 : 4),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 4,
                decoration: BoxDecoration(
                  color: i < filled ? color : AppColors.creamBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _SignUpView extends ConsumerStatefulWidget {
  const _SignUpView({
    super.key,
    required this.role,
    required this.isLearner,
    required this.copy,
  });

  final UserRole role;
  final bool isLearner;
  final _RoleCopy copy;

  @override
  ConsumerState<_SignUpView> createState() => _SignUpViewState();
}

class _SignUpViewState extends ConsumerState<_SignUpView> {
  // Learner controllers
  final _firstNameC = TextEditingController();
  final _middleNameC = TextEditingController();
  final _lastNameC = TextEditingController();
  final _gradeC = TextEditingController();
  final _usernameC = TextEditingController();
  final _learnerPasswordC = TextEditingController();
  final _learnerConfirmPasswordC = TextEditingController();

  // Grownup controllers — first/middle/last so `ParentAccount.fullName`
  // (still one plain string) is built from three real fields instead of a
  // single free-text one, matching the same split already used on the
  // teacher's "Enroll student" form in `class_detail_screen.dart`.
  final _parentFirstNameC = TextEditingController();
  final _parentMiddleNameC = TextEditingController();
  final _parentLastNameC = TextEditingController();
  final _schoolC = TextEditingController();
  final _emailC = TextEditingController();
  final _mobileC = TextEditingController();
  final _passwordC = TextEditingController();
  final _confirmPasswordC = TextEditingController();

  int _age = 7;
  String _avatar = '🦁';
  String? _emailError;
  _PasswordStrength _passwordStrength = _PasswordStrength.none;

  static const _avatars = ['🦁', '🐼', '🐯', '🦊', '🐨', '🐰'];

  @override
  void dispose() {
    _firstNameC.dispose();
    _middleNameC.dispose();
    _lastNameC.dispose();
    _gradeC.dispose();
    _usernameC.dispose();
    _learnerPasswordC.dispose();
    _learnerConfirmPasswordC.dispose();

    _parentFirstNameC.dispose();
    _parentMiddleNameC.dispose();
    _parentLastNameC.dispose();
    _schoolC.dispose();
    _emailC.dispose();
    _mobileC.dispose();
    _passwordC.dispose();
    _confirmPasswordC.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 72, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: _RoleBadge(
              isLearner: widget.isLearner,
              icon: widget.copy.icon,
              size: 56,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            widget.isLearner ? 'Create my profile' : 'Create an account',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.isLearner
                ? 'Takes less than a minute.'
                : 'Fill out the form below to register.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 26),
          if (widget.isLearner)
            _learnerForm(context)
          else
            _grownupForm(context),
        ],
      ),
    );
  }

  Widget _learnerForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TextField(
          controller: _firstNameC,
          label: 'First name',
          inputFormatters: [_CapitalizeFirstLetterFormatter()],
        ),
        const SizedBox(height: 14),
        _TextField(
          controller: _middleNameC,
          label: 'Middle name (optional)',
          inputFormatters: [_CapitalizeFirstLetterFormatter()],
        ),
        const SizedBox(height: 14),
        _TextField(
          controller: _lastNameC,
          label: 'Last name',
          inputFormatters: [_CapitalizeFirstLetterFormatter()],
        ),
        const SizedBox(height: 14),
        _TextField(
          controller: _gradeC,
          label: 'Grade Level',
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'How old are you?',
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
        _TextField(
          controller: _usernameC,
          label: 'Username',
        ),
        const SizedBox(height: 14),
        _TextField(
          controller: _learnerPasswordC,
          label: 'Password',
          obscureText: true,
        ),
        const SizedBox(height: 14),
        _TextField(
          controller: _learnerConfirmPasswordC,
          label: 'Confirm Password',
          obscureText: true,
        ),
        const SizedBox(height: 16),
        const Text(
          'Pick an avatar',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1,
          children: [
            for (final a in _avatars)
              GestureDetector(
                onTap: () => setState(() => _avatar = a),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  decoration: BoxDecoration(
                    color: _avatar == a ? AppColors.goldTint : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: _avatar == a
                          ? AppColors.gold
                          : AppColors.creamBorder,
                      width: 2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(a, style: const TextStyle(fontSize: 26)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
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
              final password = _learnerPasswordC.text;
              final confirmPassword = _learnerConfirmPasswordC.text;

              if (firstName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter your first name')),
                );
                return;
              }
              if (lastName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter your last name')),
                );
                return;
              }
              if (gradeLevel.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter your grade level'),
                  ),
                );
                return;
              }
              if (username.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a username')),
                );
                return;
              }
              if (password.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a password')),
                );
                return;
              }
              if (password != confirmPassword) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Passwords do not match')),
                );
                return;
              }

              final fullName = _middleNameC.text.trim().isEmpty
                  ? '$firstName $lastName'
                  : '$firstName ${_middleNameC.text.trim()} $lastName';

              ref
                  .read(sessionProvider.notifier)
                  .createLearner(
                    name: fullName,
                    age: _age,
                    avatar: _avatar,
                    gradeLevel: gradeLevel,
                    username: username,
                    password: password,
                  )
                  .then((_) {
                    if (context.mounted) context.go('/hub');
                  });
            },
            child: const Text(
              'Start learning',
              style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _grownupForm(BuildContext context) {
    final isTeacher = widget.role == UserRole.asatidz;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TextField(
          controller: _parentFirstNameC,
          label: 'First name',
          inputFormatters: [_CapitalizeFirstLetterFormatter()],
        ),
        const SizedBox(height: 14),
        _TextField(
          controller: _parentMiddleNameC,
          label: 'Middle name (optional)',
          inputFormatters: [_CapitalizeFirstLetterFormatter()],
        ),
        const SizedBox(height: 14),
        _TextField(
          controller: _parentLastNameC,
          label: 'Last name',
          inputFormatters: [_CapitalizeFirstLetterFormatter()],
        ),
        const SizedBox(height: 14),
        if (isTeacher) ...[
          _TextField(
            controller: _schoolC,
            label: 'School',
          ),
          const SizedBox(height: 14),
        ],
        _TextField(
          controller: _emailC,
          label: 'Email address',
          keyboardType: TextInputType.emailAddress,
          errorText: _emailError,
          onChanged: (_) {
            if (_emailError != null) setState(() => _emailError = null);
          },
        ),
        const SizedBox(height: 14),
        _TextField(
          controller: _mobileC,
          label: 'Mobile number (optional)',
          keyboardType: TextInputType.phone,
          prefixText: '+63 ',
        ),
        const SizedBox(height: 14),
        _TextField(
          controller: _passwordC,
          label: 'Password',
          obscureText: true,
          onChanged: (value) =>
              setState(() => _passwordStrength = _scorePassword(value)),
        ),
        if (_passwordStrength != _PasswordStrength.none) ...[
          const SizedBox(height: 8),
          _PasswordStrengthMeter(strength: _passwordStrength),
        ],
        const SizedBox(height: 14),
        _TextField(
          controller: _confirmPasswordC,
          label: 'Confirm Password',
          obscureText: true,
        ),
        const SizedBox(height: 24),
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
            onPressed: () {
              final firstName = _parentFirstNameC.text.trim();
              final middleName = _parentMiddleNameC.text.trim();
              final lastName = _parentLastNameC.text.trim();
              final email = _emailC.text.trim();
              final school = _schoolC.text.trim();
              final password = _passwordC.text;
              final confirmPassword = _confirmPasswordC.text;

              if (firstName.isEmpty || lastName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter your first and last name'),
                  ),
                );
                return;
              }
              if (isTeacher && school.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter your school name'),
                  ),
                );
                return;
              }
              if (email.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter your email address'),
                  ),
                );
                return;
              }
              if (password.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a password')),
                );
                return;
              }
              if (password.length < 8 ||
                  !RegExp(r'[a-zA-Z]').hasMatch(password) ||
                  !RegExp(r'[0-9]').hasMatch(password)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Password must be at least 8 characters and include both letters and numbers',
                    ),
                  ),
                );
                return;
              }
              if (password != confirmPassword) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Passwords do not match')),
                );
                return;
              }

              final notifier = ref.read(sessionProvider.notifier);
              if (notifier.emailTaken(
                role: isTeacher ? UserRole.asatidz : UserRole.parent,
                email: email,
              )) {
                setState(
                  () => _emailError = 'This email is already registered',
                );
                return;
              }

              final target = isTeacher ? '/teacher' : '/parent';
              // `ParentAccount`/`TeacherAccount.fullName` is still one
              // plain string — the three fields above only exist so the
              // form itself asks for first/middle/last separately, same as
              // the teacher's "Enroll student" form.
              final fullName = [
                firstName,
                middleName,
                lastName,
              ].where((s) => s.isNotEmpty).join(' ');
              final mobileDigits = _mobileC.text.trim();
              // The field only ever collects the local digits (see the
              // `+63` prefix baked into its decoration below) — this is
              // where that gets turned into the real E.164-ish number.
              // Philippine mobile numbers are quoted with a leading 0
              // locally (e.g. 0912 345 6789); strip it before prefixing so
              // this doesn't produce "+630912..." if someone types it out
              // of habit.
              final mobile = mobileDigits.isEmpty
                  ? null
                  : '+63${mobileDigits.startsWith('0') ? mobileDigits.substring(1) : mobileDigits}';

              // Personal info is staged, not saved yet — the account only
              // gets created once they've entered + confirmed their own
              // PIN on the next screen (pin_setup_screen.dart).
              if (isTeacher) {
                notifier.stageTeacherRegistration(
                  fullName: fullName,
                  school: school,
                  email: email,
                  password: password,
                  mobileNumber: mobile,
                );
              } else {
                notifier.stageParentRegistration(
                  fullName: fullName,
                  email: email,
                  password: password,
                  mobileNumber: mobile,
                );
              }

              // Parent-only pre-PIN email verification gate (by request —
              // teacher registration keeps going straight to PIN setup).
              final nextPath = isTeacher
                  ? '/pin/setup?redirect=${Uri.encodeComponent(target)}'
                  : '/verify-email?redirect=${Uri.encodeComponent(target)}';
              context.go(nextPath);
            },
            child: const Text(
              'Create account',
              style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

/// ============ Screen 3: sign in ============
class _SignInView extends ConsumerWidget {
  const _SignInView({
    super.key,
    required this.role,
    required this.isLearner,
    required this.copy,
    required this.onCreateProfile,
  });

  final UserRole role;
  final bool isLearner;
  final _RoleCopy copy;
  final VoidCallback onCreateProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 72, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: _RoleBadge(isLearner: isLearner, icon: copy.icon, size: 56),
          ),
          const SizedBox(height: 14),
          Text(
            isLearner ? 'Choose your profile' : 'Sign in',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isLearner
                ? 'Tap your avatar to continue.'
                : 'Enter your PIN to access your dashboard.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 26),
          if (isLearner)
            _learnerSignIn(context, ref)
          else
            _grownupSignIn(context, ref),
        ],
      ),
    );
  }

  /// Every child connected to the active parent (FR-2.3) — not just
  /// whichever one happens to be "active" right now. A household with
  /// several kids needs to be able to pick any of them here, not just
  /// see the one from the last session.
  Widget _learnerSignIn(BuildContext context, WidgetRef ref) {
    final learners = ref.watch(parentLearnersProvider);
    if (learners.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.coralTint,
          border: Border.all(color: AppColors.coral, width: 1),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.coral, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'No profile yet. Please ask your Parent or Guardian to create your account.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final learner in learners)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: learner.id == null
                    ? null
                    : () {
                        ref
                            .read(sessionProvider.notifier)
                            .switchActiveLearner(learner.id!);
                        context.go('/hub');
                      },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(
                      color: AppColors.creamBorder,
                      width: 1.6,
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      LearnerAvatar(avatar: learner.avatar, size: 46),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              learner.name,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              'Age ${learner.age}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _grownupSignIn(BuildContext context, WidgetRef ref) {
    return _GrownupSignInForm(role: role);
  }
}

/// ============ Screen 4: activate admin-created (Teacher) account ============
/// First-time step for an admin-provisioned Asatidz account (see
/// `role_picker_screen`/`_HubView`'s "New Account" card — Teacher-only,
/// since teacher self-signup is disabled). Deliberately just an email
/// field: this triggers Firebase's own built-in password-reset email
/// (`FirebaseAuthGateway.sendPasswordResetEmail`) — no custom Cloud
/// Function/email service exists in this project, so the "set a new
/// password" step happens on Firebase's own hosted reset page (opened from
/// the email, in the phone's browser), not inside this screen. Once done,
/// the teacher comes back here and uses "Already have an account" (the
/// normal sign-in form) with their new password — that flow already routes
/// through PIN setup for a first-time device via `SessionNotifier.signIn`'s
/// `needsLocalPinSetup` path, so nothing else needs to change for that part.
class _ActivateView extends StatefulWidget {
  const _ActivateView({super.key});

  @override
  State<_ActivateView> createState() => _ActivateViewState();
}

class _ActivateViewState extends State<_ActivateView> {
  final _emailC = TextEditingController();
  bool _sending = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _emailC.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _emailC.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(
        () => _error = 'Enter the email your school administrator used.',
      );
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await FirebaseAuthGateway().sendPasswordResetEmail(email);
      if (mounted) {
        setState(() {
          _sending = false;
          _sent = true;
        });
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = e.code == 'user-not-found'
              ? "We don't have an account for that email — check with your administrator."
              : 'Could not send the activation email. Please try again.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error =
              'Could not send the activation email — check your connection.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 72, 28, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(
            child: _RoleBadge(
              isLearner: false,
              icon: graduationCapIcon,
              size: 56,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Activate your account',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _sent
                ? 'Check your inbox — tap the link to set your own password, then come back and sign in below.'
                : 'Enter the email your school administrator registered for you.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColors.textMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          if (!_sent) ...[
            TextField(
              controller: _emailC,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email',
                border: const OutlineInputBorder(),
                errorText: _error,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _sending ? null : _send,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.teal,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Send activation email',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ] else
            TextButton(
              onPressed: _send,
              child: const Text(
                'Resend email',
                style: TextStyle(color: AppColors.teal),
              ),
            ),
        ],
      ),
    );
  }
}

/// Email + password login (FR-2.1's first factor) — on success the PIN
/// gate (`/pin/verify`) is the *second* factor, not this screen. Locks out
/// after repeated wrong attempts so the PIN gate isn't the only line of
/// defense against guessing.
class _GrownupSignInForm extends ConsumerStatefulWidget {
  const _GrownupSignInForm({required this.role});

  final UserRole role;

  @override
  ConsumerState<_GrownupSignInForm> createState() => _GrownupSignInFormState();
}

class _GrownupSignInFormState extends ConsumerState<_GrownupSignInForm> {
  static const _maxAttempts = 5;
  static const _lockoutDuration = Duration(seconds: 30);

  final _emailC = TextEditingController();
  final _passwordC = TextEditingController();

  int _attempts = 0;
  DateTime? _lockedUntil;
  String? _error;
  Timer? _ticker;
  bool _submitting = false;

  @override
  void dispose() {
    _emailC.dispose();
    _passwordC.dispose();
    _ticker?.cancel();
    super.dispose();
  }

  Duration get _remainingLockout {
    final until = _lockedUntil;
    if (until == null) return Duration.zero;
    final remaining = until.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  bool get _isLocked => _remainingLockout > Duration.zero;

  void _startLockoutTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (!_isLocked) {
        timer.cancel();
        setState(() {
          _lockedUntil = null;
          _attempts = 0;
          _error = null;
        });
        return;
      }
      setState(() {});
    });
  }

  Future<void> _submit() async {
    if (_isLocked || _submitting) return;

    final email = _emailC.text.trim();
    final password = _passwordC.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Please enter your email and password');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    final result = await runWithAuthLoadingOverlay(
      AuthLoadingAction.signIn,
      () => ref
          .read(sessionProvider.notifier)
          .signIn(role: widget.role, email: email, password: password),
    );

    if (!mounted) return;
    final target = widget.role == UserRole.asatidz ? '/teacher' : '/parent';

    switch (result) {
      case SignInResult.success:
        setState(() {
          _submitting = false;
          _attempts = 0;
          _error = null;
        });
        context.go('/pin/verify?redirect=${Uri.encodeComponent(target)}');
      case SignInResult.needsLocalPinSetup:
        setState(() {
          _submitting = false;
          _attempts = 0;
          _error = null;
        });
        context.go('/pin/setup?redirect=${Uri.encodeComponent(target)}');
      case SignInResult.accountDeleted:
        setState(() {
          _submitting = false;
          _error =
              'This account has been removed by an administrator and '
              'can no longer be used. Please contact your school '
              'administrator if you believe this was a mistake.';
        });
      case SignInResult.invalidCredentials:
        setState(() {
          _submitting = false;
          _attempts++;
          if (_attempts >= _maxAttempts) {
            _lockedUntil = DateTime.now().add(_lockoutDuration);
            _error =
                'Too many failed attempts. Try again in ${_remainingLockout.inSeconds}s.';
            _startLockoutTicker();
          } else {
            final left = _maxAttempts - _attempts;
            _error =
                'Incorrect email or password ($left ${left == 1 ? 'try' : 'tries'} left)';
          }
        });
      case SignInResult.noInternet:
        // Distinct from a wrong password (and doesn't count against the
        // attempt lockout — not the user's fault) — this only happens on
        // a device with no local account for this email, since a local
        // match never touches the network at all.
        setState(() {
          _submitting = false;
          _error =
              'No internet connection. Connect to Wi-Fi or mobile '
              'data and try again.';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = _isLocked;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TextField(
          controller: _emailC,
          label: 'Email',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 14),
        _TextField(
          controller: _passwordC,
          label: 'Password',
          obscureText: true,
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            locked
                ? 'Too many failed attempts. Try again in ${_remainingLockout.inSeconds}s.'
                : _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColors.coral,
            ),
          ),
        ],
        const SizedBox(height: 20),
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
            onPressed: (locked || _submitting) ? null : _submit,
            child: Text(
              locked ? 'Locked (${_remainingLockout.inSeconds}s)' : 'Sign In',
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: _submitting ? null : () => _showForgotPasswordDialog(),
            child: const Text(
              'Forgot password?',
              style: TextStyle(fontSize: 12.5, color: AppColors.teal),
            ),
          ),
        ),
      ],
    );
  }

  /// Same reset mechanism as `_ActivateView`'s teacher activation (Firebase's
  /// own hosted password-reset email — no custom Cloud Function/mail
  /// provider needed). Prefills whatever the user already typed into the
  /// email field above so they don't have to type it twice.
  Future<void> _showForgotPasswordDialog() async {
    final sentEmail = await showDialog<String>(
      context: context,
      builder: (_) => _ForgotPasswordDialog(initialEmail: _emailC.text.trim()),
    );
    if (sentEmail == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Password reset email sent to $sentEmail.'),
        backgroundColor: AppColors.teal,
      ),
    );
  }
}

/// Content of the "Forgot password?" dialog, as its own [StatefulWidget] —
/// not a `StatefulBuilder` closure — so its [TextEditingController] is
/// disposed by the normal `State.dispose()` lifecycle (i.e. once Flutter
/// actually unmounts the dialog after its exit animation finishes) rather
/// than manually right after `showDialog` returns. `showDialog`'s Future
/// completes the instant `Navigator.pop()` is called — *before* the closing
/// fade-out transition finishes — so a manual dispose there was racing that
/// animation and killing the controller while it was still in use (surfaced
/// as "A TextEditingController was used after being disposed").
///
/// Pops with the sent-to email address on success so the caller can show its
/// own confirmation snackbar (`Navigator` can't show a `ScaffoldMessenger`
/// snackbar reliably from inside a dialog route), or with nothing on cancel.
class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog({required this.initialEmail});

  final String initialEmail;

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  late final _emailC = TextEditingController(text: widget.initialEmail);
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _emailC.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _emailC.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await FirebaseAuthGateway().sendPasswordResetEmail(email);
      if (mounted) Navigator.of(context).pop(email);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = e.code == 'user-not-found'
            ? "We don't have an account for that email."
            : 'Could not send the reset email. Please try again.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = 'Could not send the reset email — check your connection.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reset your password'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Enter your account email and we'll send you a link to reset your password.",
            style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _emailC,
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Email',
              border: const OutlineInputBorder(),
              errorText: _error,
            ),
            onSubmitted: (_) => _sending ? null : _send(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _sending ? null : _send,
          style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
          child: _sending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('Send reset link'),
        ),
      ],
    );
  }
}

/// ---------- shared bits ----------

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({
    required this.isLearner,
    required this.icon,
    required this.size,
  });

  final bool isLearner;
  final Widget Function(Color color, {double size}) icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isLearner ? AppColors.gold : AppColors.teal,
        borderRadius: BorderRadius.circular(size * 0.31),
        boxShadow: [
          BoxShadow(
            color: (isLearner ? AppColors.gold : AppColors.teal).withValues(
              alpha: 0.28,
            ),
            blurRadius: size * 0.33,
            offset: Offset(0, size * 0.17),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: icon(Colors.white, size: size * 0.45),
    );
  }
}

class _TextField extends StatefulWidget {
  const _TextField({
    this.controller,
    required this.label,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.errorText,
    this.onChanged,
    this.prefixText,
    this.inputFormatters,
  });

  final TextEditingController? controller;

  /// Floats up into the border on focus (Material's built-in animation) —
  /// replaces the old static caption above the field, per the approved
  /// mp4 reference of the floating-label motion.
  final String label;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? inputFormatters;

  /// Fixed, non-editable prefix shown inside the field (e.g. `+63 ` for
  /// the Philippines-only mobile number field) — not part of the typed
  /// text, so the controller's value stays just the local digits.
  final String? prefixText;

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
          label: Text(widget.label),
          errorText: widget.errorText,
          errorMaxLines: 2,
          prefixText: widget.prefixText,
          prefixStyle: const TextStyle(
            color: AppColors.ink,
            fontWeight: FontWeight.w600,
          ),
          labelStyle: const TextStyle(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w700,
          ),
          floatingLabelStyle: const TextStyle(
            color: AppColors.teal,
            fontWeight: FontWeight.w700,
          ),
          filled: true,
          fillColor: Colors.white,
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
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.coral, width: 1.6),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.coral, width: 1.6),
          ),
        ),
      ),
    );
  }
}

/// Fades and slides its child upward as [animation] runs 0→1.
class _FadeUp extends StatelessWidget {
  const _FadeUp({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, c) => Transform.translate(
          offset: Offset(0, (1 - animation.value) * 14),
          child: c,
        ),
        child: child,
      ),
    );
  }
}

/// Big tappable action card — primary (filled) for the sign-up path,
/// secondary (outlined) for sign-in.
class _AuthActionCard extends StatelessWidget {
  const _AuthActionCard({
    required this.primary,
    required this.gold,
    required this.icon,
    required this.title,
    required this.desc,
    required this.onTap,
  });

  final bool primary;
  final bool gold;
  final IconData icon;
  final String title;
  final String desc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = primary
        ? (gold ? AppColors.gold : AppColors.teal)
        : Colors.white;
    final fg = primary ? (gold ? AppColors.ink : Colors.white) : AppColors.ink;
    final descColor = primary
        ? (gold ? AppColors.ink.withValues(alpha: 0.65) : Colors.white70)
        : AppColors.textMuted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            border: primary
                ? null
                : Border.all(color: AppColors.creamBorder, width: 1.6),
            boxShadow: primary
                ? [
                    BoxShadow(
                      color: bg.withValues(alpha: 0.28),
                      blurRadius: 26,
                      offset: const Offset(0, 14),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: primary
                      ? Colors.white.withValues(alpha: 0.18)
                      : AppColors.mint,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  size: 22,
                  color: primary ? fg : AppColors.teal,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: fg,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      desc,
                      style: TextStyle(fontSize: 12, color: descColor),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: fg),
            ],
          ),
        ),
      ),
    );
  }
}

/// Per-role copy for the hub / sign-up / sign-in screens.
class _RoleCopy {
  const _RoleCopy({
    required this.icon,
    required this.heading,
    required this.subtext,
    required this.signUpTitle,
    required this.signUpDesc,
    required this.signInTitle,
    required this.signInDesc,
    required this.shortName,
  });

  final Widget Function(Color color, {double size}) icon;
  final String heading;
  final String subtext;
  final String signUpTitle;
  final String signUpDesc;
  final String signInTitle;
  final String signInDesc;
  final String shortName;

  static _RoleCopy of(UserRole role) {
    switch (role) {
      case UserRole.learner:
        return _RoleCopy(
          icon: backpackIcon,
          heading: 'Continue as Learner',
          subtext: 'Play, practice, and earn streaks — made just for you.',
          signUpTitle: 'Create my profile',
          signUpDesc: 'New here? Set up in under a minute',
          signInTitle: 'I already have a profile',
          signInDesc: 'Pick up right where you left off',
          shortName: 'Learner',
        );
      case UserRole.parent:
        return _RoleCopy(
          icon: familyIcon,
          heading: 'Continue as Parent/Guardian',
          subtext:
              "Track your child's progress and manage their profile & privacy.",
          signUpTitle: 'Create an account',
          signUpDesc: "First time here? Set up your child's profile",
          signInTitle: 'Sign in',
          signInDesc: 'Use your PIN to access your dashboard',
          shortName: 'Parent/Guardian',
        );
      case UserRole.asatidz:
        return _RoleCopy(
          icon: graduationCapIcon,
          heading: 'Continue as Asatidz',
          subtext:
              'Manage your classes, cast lessons, and track student mastery.',
          signUpTitle: 'Create an account',
          signUpDesc: 'New teacher? Register your class',
          signInTitle: 'Sign in',
          signInDesc: 'Use your PIN to access your dashboard',
          shortName: 'Asatidz',
        );
    }
  }
}
