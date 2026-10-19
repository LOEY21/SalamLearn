import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:salamlearn/logic/localization/app_translations.dart';

import '../../logic/auth/session.dart';
import '../theme/app_colors.dart';
import '../widgets/child_profile_form.dart'
    show ChildFieldLabel, ChildFormBottomBar, ChildFormButton, ChildTextField;
import '../widgets/hub_kit.dart';
import '../widgets/soft_card.dart';

/// Settings → Account row that opens [PersonalInfoScreen]; shows the
/// account's current name. Shared by the Parent and Teacher hubs.
class PersonalInfoRow extends ConsumerWidget {
  const PersonalInfoRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(sessionProvider);
    final profile = ref.read(sessionProvider.notifier).activeProfile;
    if (profile == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: HubRowSheet(
        children: [
          HubNavRow(
            icon: Icons.badge_outlined,
            title: 'Personal information',
            subtitle: profile.fullName,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const PersonalInfoScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lets a parent or teacher edit their own details: first, middle and
/// last name and (teachers) school. Email is shown but not editable — it's
/// the sign-in identity, tied to the Firebase Auth account. Saves on this
/// device first, then syncs to the cloud when the account is linked.
class PersonalInfoScreen extends ConsumerStatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  ConsumerState<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends ConsumerState<PersonalInfoScreen> {
  late final _profile = ref.read(sessionProvider.notifier).activeProfile;
  late final _isTeacher =
      ref.read(sessionProvider).activeRole == UserRole.asatidz;
  late final _nameParts = _splitName(_profile?.fullName ?? '');
  late final _firstC = TextEditingController(text: _nameParts.first);
  late final _middleC = TextEditingController(text: _nameParts.middle);
  late final _lastC = TextEditingController(text: _nameParts.last);
  late final _schoolC = TextEditingController(text: _profile?.school ?? '');
  late final _emailC = TextEditingController(text: _profile?.email ?? '');
  late final TextEditingController? _employeeIdC = () {
    if (!_isTeacher) return null;
    final id = ref.read(sessionProvider.notifier).activeTeacherEmployeeId;
    return id == null ? null : TextEditingController(text: id);
  }();

  String? _firstError;
  String? _lastError;
  bool _saving = false;

  /// Registration joins first/middle/last into one stored `fullName`, so
  /// this splits it back: last word = last name, the word before it =
  /// middle name (3+ words), the rest = first name.
  // ponytail: guesses wrong for multi-word last names ("Dela Cruz") — the
  // user can fix it here; store the parts separately if that matters.
  static ({String first, String middle, String last}) _splitName(String full) {
    final words = full.trim().split(RegExp(r'\s+'));
    if (words.length < 2) return (first: words.first, middle: '', last: '');
    if (words.length == 2) return (first: words[0], middle: '', last: words[1]);
    return (
      first: words.sublist(0, words.length - 2).join(' '),
      middle: words[words.length - 2],
      last: words.last,
    );
  }

  static String _clean(TextEditingController c) =>
      c.text.trim().replaceAll(RegExp(r'\s+'), ' ');

  @override
  void dispose() {
    _firstC.dispose();
    _middleC.dispose();
    _lastC.dispose();
    _schoolC.dispose();
    _emailC.dispose();
    _employeeIdC?.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final first = _clean(_firstC);
    final last = _clean(_lastC);
    setState(() {
      _firstError = first.isEmpty ? 'Please enter your first name' : null;
      _lastError = last.isEmpty ? 'Please enter your last name' : null;
    });
    if (_firstError != null || _lastError != null) return;
    final name = [first, _clean(_middleC), last]
        .where((part) => part.isNotEmpty)
        .join(' ');

    setState(() => _saving = true);
    final school = _schoolC.text.trim();
    final synced = await ref
        .read(sessionProvider.notifier)
        .updateActiveProfile(
          fullName: name,
          // No longer editable here — keep whatever registration stored.
          mobileNumber: _profile?.mobileNumber,
          school: _isTeacher && school.isNotEmpty ? school : null,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          synced
              ? 'Personal information saved'
              : 'Saved on this device — it will sync when you are online',
        ),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return HubSubpage(
      header: HubSubpageHeader(
        title: 'Personal information',
        subtitle: 'Your name and details on this account.',
        onBack: () => Navigator.of(context).pop(),
      ),
      bottomBar: ChildFormBottomBar(
        children: [
          ChildFormButton(
            label: 'Save changes',
            icon: Icons.check_rounded,
            busy: _saving,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: HubListBody(
        maxWidth: 600,
        children: [
          SoftCard(
            radius: 20,
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const ChildFieldLabel('First name'),
                ChildTextField(
                  controller: _firstC,
                  hint: 'e.g. Aisha',
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.givenName],
                  wrap: true,
                  onChanged: (_) {
                    if (_firstError != null) setState(() => _firstError = null);
                  },
                ),
                SettingsFieldError(_firstError),
                const SizedBox(height: 16),
                const ChildFieldLabel('Middle name (optional)'),
                ChildTextField(
                  controller: _middleC,
                  hint: 'e.g. Mohammad',
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.middleName],
                  wrap: true,
                ),
                const SizedBox(height: 16),
                const ChildFieldLabel('Last name'),
                ChildTextField(
                  controller: _lastC,
                  hint: 'e.g. Santos',
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.familyName],
                  wrap: true,
                  onChanged: (_) {
                    if (_lastError != null) setState(() => _lastError = null);
                  },
                ),
                SettingsFieldError(_lastError),
                if (_isTeacher) ...[
                  const SizedBox(height: 16),
                  const ChildFieldLabel('School (optional)'),
                  ChildTextField(
                    controller: _schoolC,
                    hint: 'e.g. Madrasah Al-Hikmah',
                    textCapitalization: TextCapitalization.words,
                    wrap: true,
                  ),
                ],
              ],
            ),
          ),
          if (_profile?.email != null && _profile!.email!.isNotEmpty) ...[
            const SizedBox(height: 16),
            SoftCard(
              radius: 20,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_employeeIdC != null) ...[
                    const ChildFieldLabel(
                      'Employee ID',
                      helper: 'Given by your school administrator. Use it to sign in.',
                    ),
                    ChildTextField(controller: _employeeIdC, readOnly: true),
                    const SizedBox(height: 16),
                  ],
                  const ChildFieldLabel(
                    'Email address',
                    helper: 'Used to sign in, so it can\'t be changed here.',
                  ),
                  ChildTextField(controller: _emailC, readOnly: true),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SettingsFieldError extends StatelessWidget {
  const SettingsFieldError(this.message, {super.key});

  final String? message;

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 4),
      child: Text(
        message!,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.danger,
        ),
      ),
    );
  }
}
