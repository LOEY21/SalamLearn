import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:flutter/services.dart';
import 'package:salamlearn/logic/localization/app_translations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../logic/auth/session.dart';
import '../theme/app_colors.dart';

/// Parental consent (mockup Figure 4.7), redesigned per the approved
/// motion-design/ui-ux-pro-max HTML preview: itemized trust cards instead
/// of one dense paragraph, a full-width tappable consent row, and a
/// Corporate/Premium entrance (0% overshoot, MD3 ease-out) — deliberately
/// calmer than the Playful get-started/language screens since this is a
/// legal/trust moment, not a fun one. Themed coral ("warning sign") per the
/// approved warning-theme preview, so the disclosure reads as important
/// without becoming a literal error state (uses AppColors.coral, not
/// AppColors.danger).
class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key});

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen>
    with TickerProviderStateMixin {
  bool _agreed = false;

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  )..forward();

  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );

  Animation<double> _in(
    double start,
    double end, {
    Curve curve = Curves.easeOut,
  }) {
    return CurvedAnimation(
      parent: _c,
      curve: Interval(start, end, curve: curve),
    );
  }

  // Built once and reused — recreating these in build() (which reran on
  // every consent-checkbox tap via setState) leaked a fresh CurvedAnimation
  // listener onto `_c` each time, permanently, since nothing ever disposed
  // the discarded ones.
  late final banner = _in(0.0, 0.26);
  late final shield = _in(0.10, 0.45);
  late final shieldDraw = _in(0.26, 0.65, curve: Curves.easeOut);
  late final heading = _in(0.18, 0.42);
  late final subhead = _in(0.22, 0.46);
  // One shared fade for the whole numbered-sections policy block rather
  // than a separate CurvedAnimation per section (9 of them): more of those
  // would repeat the same per-item-listener leak this file's `_in` docs
  // already warn about, just at higher count.
  late final policy = _in(0.28, 0.6);
  late final chip = _in(0.42, 0.65);
  late final consentRow = _in(0.46, 0.70);
  late final timestamp = _in(0.50, 0.72);
  late final actions = _in(0.54, 0.80);

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((status) {
      if (status == AnimationStatus.completed) _glow.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) context.go('/language');
      },
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(26, 12, 26, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FadeTransition(
            opacity: banner,
            child: const _WarningBanner(),
          ),
          const SizedBox(height: 16),
          Center(
            child: FadeTransition(
              opacity: shield,
              child: ScaleTransition(
                scale: shield.drive(Tween(begin: 0.9, end: 1.0)),
                child: _ShieldBadge(glow: _glow, draw: shieldDraw),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _FadeUp(
            animation: heading,
            child: const Text(
              'Data Privacy Consent',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
          ),
          const SizedBox(height: 4),
          _FadeUp(
            animation: subhead,
            child: const Text(
              'Please read this form carefully. As the parent or legal '
              'guardian, your consent is required before SalamLearn can '
              "collect and process your child's personal data.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textMuted,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 4),
          FadeTransition(
            opacity: subhead,
            child: const Text(
              'Last updated: September 2026',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10.5,
                color: AppColors.textMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 20),
          _FadeUp(
            animation: policy,
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PolicySection(
                  number: 1,
                  title: 'Personal data we collect',
                  bullets: [
                    'Account details: full name, email address, mobile '
                        'number, and school (for teachers).',
                    'Child profile: name, age, grade level, avatar, and '
                        'username.',
                    'Learning activity: lesson progress, scores, accuracy, '
                        'and time spent on activities.',
                  ],
                ),
                _PolicySection(
                  number: 2,
                  title: 'Purpose of processing',
                  body:
                      "To create and manage accounts, show your child's "
                      'learning progress to you and their assigned teacher, '
                      'and adapt lessons to their level. Your data is never '
                      'used for advertising or sold.',
                ),
                _PolicySection(
                  number: 3,
                  title: 'Storage and security',
                  body:
                      'Data is stored on this device and, when an internet '
                      'connection is available, securely synced to our cloud '
                      'service (Google Firebase) so you can sign in on other '
                      'devices. PINs and passwords never leave this device.',
                ),
                _PolicySection(
                  number: 4,
                  title: 'Data sharing',
                  body:
                      "Progress is shared only with your child's teacher "
                      'once you join their class, and with our hosting '
                      'provider (Google Firebase). We do not share data with '
                      'advertisers or any other third party.',
                ),
                _PolicySection(
                  number: 5,
                  title: 'Data retention',
                  body:
                      'Data is kept for as long as the account is active. '
                      'You may delete a child profile or request deletion of '
                      'your data at any time.',
                ),
                _PolicySection(
                  number: 6,
                  title: 'Your rights',
                  body:
                      'Under the Data Privacy Act of 2012 (RA 10173), you '
                      'have the right to be informed, to access, correct, '
                      'and erase your data, to object to processing, to '
                      'withdraw consent at any time, and to file a complaint '
                      'with the National Privacy Commission.',
                ),
                _PolicySection(
                  number: 7,
                  title: "Children's privacy",
                  body:
                      'SalamLearn is built for learners aged 5–11. A '
                      'parent or guardian must complete this consent '
                      'before a child profile can be created.',
                ),
                _PolicySection(
                  number: 8,
                  title: 'Contact us',
                  child: _ContactCard(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: FadeTransition(opacity: chip, child: const _LegalChip()),
          ),
          const SizedBox(height: 18),
          _FadeUp(
            animation: consentRow,
            child: _ConsentRow(
              agreed: _agreed,
              onTap: () => setState(() => _agreed = !_agreed),
            ),
          ),
          const SizedBox(height: 8),
          FadeTransition(
            opacity: timestamp,
            child: const Text(
              'A timestamp is logged the moment you agree.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: 24),
          _FadeUp(
            animation: actions,
            offset: 16,
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textMuted,
                        side: const BorderSide(color: AppColors.creamBorder),
                      ),
                      onPressed: SystemNavigator.pop,
                      child: const Text('Decline'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.coral,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _agreed
                          ? () async {
                              await ref.read(sessionProvider.notifier).giveConsent();
                              if (context.mounted) context.go('/roles');
                            }
                          : null,
                      child: const Text('I agree'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Fades and slides its child upward as [animation] runs 0→1.
class _FadeUp extends StatelessWidget {
  const _FadeUp({
    required this.animation,
    required this.child,
    this.offset = 14,
  });

  final Animation<double> animation;
  final Widget child;
  final double offset;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, c) => Transform.translate(
          offset: Offset(0, (1 - animation.value) * offset),
          child: c,
        ),
        child: child,
      ),
    );
  }
}

/// Top attention banner ("Please read before continuing") — the primary
/// warning-sign cue, coral-tinted and bordered but not literal alarm-red.
class _WarningBanner extends StatelessWidget {
  const _WarningBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.coralTint,
        border: Border.all(color: AppColors.coral),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.coral),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'Please read before continuing',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.coral,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Warning-triangle hero with a slow ambient glow pulse once it lands —
/// still calm/deliberate (Corporate personality), just recolored coral so
/// the legal/trust moment reads as important rather than routine.
class _ShieldBadge extends StatelessWidget {
  const _ShieldBadge({required this.glow, required this.draw});

  final Animation<double> glow;
  final Animation<double> draw;

  @override
  Widget build(BuildContext context) {
    final pulse = CurvedAnimation(parent: glow, curve: Curves.easeInOut);
    return SizedBox(
      width: 92,
      height: 92,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: pulse,
              builder: (context, _) => Opacity(
                opacity: 0.5 + pulse.value * 0.4,
                child: Transform.scale(
                  scale: 0.94 + pulse.value * 0.14,
                  child: Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.coral.withValues(alpha: 0.20),
                          AppColors.coral.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.white, AppColors.creamDark],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.coral.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: AnimatedBuilder(
              animation: draw,
              builder: (context, _) => CustomPaint(
                size: const Size(34, 34),
                painter: _WarningTrianglePainter(
                  color: AppColors.coral,
                  progress: draw.value,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Warning triangle + exclamation mark, stroke-drawn in as [progress] runs
/// 0→1 (triangle outline first, then the exclamation stroke and dot),
/// echoing the preview's `stroke-dasharray`/`stroke-dashoffset` reveal.
class _WarningTrianglePainter extends CustomPainter {
  const _WarningTrianglePainter({required this.color, required this.progress});

  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    Offset p(double x, double y) => Offset(x * s, y * s);

    final triangle = Path()
      ..moveTo(p(12, 3).dx, p(12, 3).dy)
      ..lineTo(p(22, 20).dx, p(22, 20).dy)
      ..lineTo(p(2, 20).dx, p(2, 20).dy)
      ..close();

    final stem = Path()
      ..moveTo(p(12, 9.5).dx, p(12, 9.5).dy)
      ..lineTo(p(12, 14).dx, p(12, 14).dy);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 * s
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final triangleT = (progress / 0.7).clamp(0.0, 1.0);
    canvas.drawPath(_trim(triangle, triangleT), paint);

    if (progress > 0.55) {
      final stemT = ((progress - 0.55) / 0.3).clamp(0.0, 1.0);
      canvas.drawPath(_trim(stem, stemT), paint..strokeWidth = 2 * s);
    }

    if (progress > 0.85) {
      final dotOpacity = ((progress - 0.85) / 0.15).clamp(0.0, 1.0);
      canvas.drawCircle(
        p(12, 17),
        1.1 * s,
        Paint()..color = color.withValues(alpha: dotOpacity),
      );
    }
  }

  Path _trim(Path source, double t) {
    if (t >= 1) return source;
    if (t <= 0) return Path();
    final metrics = source.computeMetrics().toList();
    final result = Path();
    for (final metric in metrics) {
      result.addPath(metric.extractPath(0, metric.length * t), Offset.zero);
    }
    return result;
  }

  @override
  bool shouldRepaint(covariant _WarningTrianglePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

/// Numbered policy section: circle badge + title, then either a paragraph
/// ([body]), a bulleted list ([bullets]), or a fully custom [child] (used
/// once, for the contact card) — exactly one of the three is provided.
class _PolicySection extends StatelessWidget {
  const _PolicySection({
    required this.number,
    required this.title,
    this.body,
    this.bullets,
    this.child,
  });

  final int number;
  final String title;
  final String? body;
  final List<String>? bullets;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: AppColors.coral,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '$number',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 30),
            child:
                child ??
                (bullets != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final bullet in bullets!)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '•  $bullet',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                  height: 1.5,
                                ),
                              ),
                            ),
                        ],
                      )
                    : Text(
                        body!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                          height: 1.5,
                        ),
                      )),
          ),
        ],
      ),
    );
  }
}

/// Data Protection contact card closing out the numbered sections.
class _ContactCard extends StatelessWidget {
  const _ContactCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.creamBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Text.rich(
        TextSpan(
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textMuted,
            height: 1.5,
          ),
          children: [
            TextSpan(text: 'Reach our Data Protection contact anytime at '),
            TextSpan(
              text: 'privacy@salamlearn.app',
              style: TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextSpan(
              text:
                  '. We reply within 5 business days, as required under '
                  'RA 10173.',
            ),
          ],
        ),
      ),
    );
  }
}

/// Small "protected under RA 10173" legal badge chip.
class _LegalChip extends StatelessWidget {
  const _LegalChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.creamDark,
        border: Border.all(color: AppColors.coral),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fact_check_outlined, size: 13, color: AppColors.coral),
          SizedBox(width: 6),
          Text(
            'Protected under RA 10173 (Data Privacy Act)',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.coral,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-width tappable consent row (44px+ target) with an animated
/// checkmark, replacing the old plain [CheckboxListTile].
class _ConsentRow extends StatelessWidget {
  const _ConsentRow({required this.agreed, required this.onTap});

  final bool agreed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.coralTint,
            border: Border.all(color: AppColors.coral, width: 1.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: agreed ? AppColors.coral : Colors.transparent,
                  border: Border.all(color: AppColors.coral, width: 2),
                ),
                child: AnimatedScale(
                  scale: agreed ? 1.0 : 0.6,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: AnimatedOpacity(
                    opacity: agreed ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 160),
                    child: const Icon(
                      Icons.check,
                      size: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'I have read and understood this form, and I consent to '
                  "the collection and processing of my child's personal "
                  'data as described above.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.ink,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
