import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
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

/// Lets a parent or teacher edit their own details: full name, mobile
/// number and (teachers) school. Email is shown but not editable — it's
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
  late final _nameC = TextEditingController(text: _profile?.fullName ?? '');
  late final _mobileC = TextEditingController(
    text: _localMobile(_profile?.mobileNumber),
  );
  late final _schoolC = TextEditingController(text: _profile?.school ?? '');
  late final _emailC = TextEditingController(text: _profile?.email ?? '');

  String? _nameError;
  String? _mobileError;
  bool _saving = false;

  /// Stored as `+63` + the local digits (see registration); edited without
  /// the `+63`, which the field shows as a fixed prefix.
  static String _localMobile(String? stored) {
    if (stored == null) return '';
    return stored.startsWith('+63') ? stored.substring(3) : stored;
  }

  @override
  void dispose() {
    _nameC.dispose();
    _mobileC.dispose();
    _schoolC.dispose();
    _emailC.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameC.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    var digits = _mobileC.text.trim();
    if (digits.startsWith('0')) digits = digits.substring(1);
    setState(() {
      _nameError = name.isEmpty ? 'Please enter your full name' : null;
      _mobileError = digits.isNotEmpty && digits.length != 10
          ? 'Enter a 10-digit mobile number, e.g. 912 345 6789'
          : null;
    });
    if (_nameError != null || _mobileError != null) return;

    setState(() => _saving = true);
    final school = _schoolC.text.trim();
    final synced = await ref
        .read(sessionProvider.notifier)
        .updateActiveProfile(
          fullName: name,
          mobileNumber: digits.isEmpty ? null : '+63$digits',
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
        subtitle: 'Your name and contact details on this account.',
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
                const ChildFieldLabel('Full name'),
                ChildTextField(
                  controller: _nameC,
                  hint: 'e.g. Aisha Mohammad Santos',
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.name],
                  wrap: true,
                  onChanged: (_) {
                    if (_nameError != null) setState(() => _nameError = null);
                  },
                ),
                _FieldError(_nameError),
                const SizedBox(height: 16),
                const ChildFieldLabel('Mobile number (optional)'),
                ChildTextField(
                  controller: _mobileC,
                  hint: '912 345 6789',
                  prefixText: '+63 ',
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  autofillHints: const [AutofillHints.telephoneNumberNational],
                  onChanged: (_) {
                    if (_mobileError != null) {
                      setState(() => _mobileError = null);
                    }
                  },
                ),
                _FieldError(_mobileError),
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

class _FieldError extends StatelessWidget {
  const _FieldError(this.message);

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
