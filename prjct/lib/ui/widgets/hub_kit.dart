import 'dart:math';

import 'package:flutter/material.dart' hide Text, TextSpan;
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:salamlearn/logic/localization/app_translations.dart';

import '../theme/app_colors.dart';
import 'child_profile_form.dart'
    show KhatamPatternPainter, displayText, scaledExtent;
import 'mock_icons.dart';
import 'soft_card.dart';

/// Shared shell + building blocks for the Parent and Teacher hubs: teal
/// patterned header with a segmented tab switcher, a body that reflows from
/// one column (phones) to two (tablet landscape / desktop), and the list
/// rows, labels and text-fitting helpers both hubs compose with. Everything
/// reflows by available width and system text size instead of truncating.

/// Content width caps shared by the header and the tab bodies so their
/// edges line up at every window size.
const double hubPhoneMaxWidth = 600;
const double hubWideMaxWidth = 1120;

/// At or above this content width a [HubTabBody] splits into two columns.
const double hubTwoColumnMinWidth = 840;

/// One tab in a [HubTabs] switcher: optional raw SVG path markup (see
/// [MockIcons]) plus its label.
typedef HubTab = ({String? iconPath, String label});

/// Shrinks [style] just enough that the longest single word of [text] fits
/// in [maxWidth] at the current text scale, so a long name like
/// "Abdurrahman" wraps between words instead of being broken mid-word.
/// Never shrinks below [minFactor] of the original size.
TextStyle fitLongestWord(
  BuildContext context,
  String text,
  TextStyle style,
  double maxWidth, {
  double minFactor = 0.5,
}) {
  final scaler = MediaQuery.textScalerOf(context);
  // Measure what actually renders: the style merged over the inherited
  // DefaultTextStyle (which can add letter-spacing, etc.).
  final effective = DefaultTextStyle.of(context).style.merge(style);
  var widest = 0.0;
  for (final word in text.split(RegExp(r'\s+'))) {
    if (word.isEmpty) continue;
    final painter = TextPainter(
      text: TextSpan(text: word, style: effective),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();
    widest = max(widest, painter.width);
    painter.dispose();
  }
  if (widest <= maxWidth) return style;
  // 2% headroom so sub-pixel rounding can't tip the word over the edge.
  final factor = max(minFactor, maxWidth / widest * 0.98);
  return style.copyWith(fontSize: style.fontSize! * factor);
}

/// Text that shrinks just enough for its longest word to fit the width it
/// is given (see [fitLongestWord]) — for short labels in tight spots like
/// chips, where a mid-word break would be unreadable.
class HubFitText extends StatelessWidget {
  const HubFitText(this.text, {super.key, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Text(
        text,
        style: constraints.maxWidth.isFinite
            ? fitLongestWord(context, text, style, constraints.maxWidth)
            : style,
      ),
    );
  }
}

/// Page frame for a hub: cream canvas, [header] pinned above the tab panel
/// on tall windows; on short ones (phone in landscape, large system text)
/// the header scrolls away with the content instead of squeezing it.
/// [panelKey] should change with the active tab so the panel re-runs its
/// entrance.
class HubShell extends StatelessWidget {
  const HubShell({
    super.key,
    required this.header,
    required this.panelKey,
    required this.panel,
    this.floatingActionButton,
  });

  final Widget header;
  final Key panelKey;
  final Widget panel;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.cream,
        floatingActionButton: floatingActionButton,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final body = SafeArea(
              top: false,
              child: HubPanelRise(key: panelKey, child: panel),
            );
            if (scaledExtent(context, constraints.maxHeight) < 640) {
              return NestedScrollView(
                headerSliverBuilder: (context, _) => [
                  SliverToBoxAdapter(child: header),
                ],
                body: body,
              );
            }
            return Column(
              children: [
                header,
                Expanded(child: body),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Solid teal header block — [leading] badge, greeting, per-tab title, a
/// status pill and the segmented [HubTabs] switcher, over a faint
/// eight-point-star lattice (the khatam motif from madrasah tilework).
/// Bottom corners are rounded so the cream canvas tucks up underneath.
class HubHeader extends StatelessWidget {
  const HubHeader({
    super.key,
    required this.leading,
    required this.greeting,
    required this.title,
    required this.statusLabel,
    required this.tabs,
    required this.activeTab,
    required this.onTabChanged,
    required this.onSwitchUser,
    this.onLeadingTap,
    this.fade,
  });

  final Widget leading;
  final VoidCallback? onLeadingTap;
  final String greeting;
  final String title;
  final String statusLabel;
  final List<HubTab> tabs;
  final int activeTab;
  final ValueChanged<int> onTabChanged;
  final VoidCallback onSwitchUser;

  /// Optional entrance fade for the greeting row.
  final Animation<double>? fade;

  @override
  Widget build(BuildContext context) {
    final topRow = Row(
      children: [
        GestureDetector(
          onTap: onLeadingTap,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(
              color: AppColors.gold,
              shape: BoxShape.circle,
            ),
            child: leading,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: fitLongestWord(
                    context,
                    greeting,
                    TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                    constraints.maxWidth,
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  layoutBuilder: (current, previous) => Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Opacity(
                        opacity: 0,
                        child: Text(
                          ' \n ',
                          style: displayText(24, weight: 800),
                        ),
                      ),
                      ...previous,
                      ?current,
                    ],
                  ),
                  child: Text(
                    title,
                    key: ValueKey(title),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: fitLongestWord(
                      context,
                      title,
                      displayText(24, weight: 800, color: Colors.white),
                      constraints.maxWidth,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: 'Switch user'.tr,
          child: Material(
            color: Colors.white.withValues(alpha: 0.14),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onSwitchUser,
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: MockIcon(
                    MockIcons.swap,
                    size: 19,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );

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
                constraints: const BoxConstraints(maxWidth: hubWideMaxWidth),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 14, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (fade != null)
                        FadeTransition(opacity: fade!, child: topRow)
                      else
                        topRow,
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.tealDark.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: AppColors.mintGreen,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  statusLabel,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: HubTabs(
                            tabs: tabs,
                            active: activeTab,
                            onChanged: onTabChanged,
                          ),
                        ),
                      ),
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

/// Segmented tab switcher on the teal header: a white pill slides under
/// the active tab, inactive labels sit in translucent white.
class HubTabs extends StatelessWidget {
  const HubTabs({
    super.key,
    required this.tabs,
    required this.active,
    required this.onChanged,
  });

  final List<HubTab> tabs;
  final int active;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    // Grows with the system text size instead of clipping the labels; the
    // labels themselves scale down to fit a narrow share of the bar.
    final height = max(48.0, MediaQuery.textScalerOf(context).scale(15) + 30);
    final x = tabs.length < 2 ? 0.0 : -1 + active * 2 / (tabs.length - 1);
    return Container(
      height: height,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.tealDark.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutQuart,
            alignment: Alignment(x, 0),
            child: FractionallySizedBox(
              widthFactor: 1 / tabs.length,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (final (i, tab) in tabs.indexed)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == active,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => onChanged(i),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (tab.iconPath != null) ...[
                                  MockIcon(
                                    tab.iconPath!,
                                    size: 16,
                                    color: i == active
                                        ? AppColors.teal
                                        : Colors.white.withValues(alpha: 0.85),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Text(
                                  tab.label,
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: i == active
                                        ? AppColors.teal
                                        : Colors.white.withValues(alpha: 0.85),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One scrolling tab panel. Phones and portrait tablets get a single
/// centered column capped at [hubPhoneMaxWidth]; wider windows get [left]
/// and [right] side by side, capped at [hubWideMaxWidth], so cards never
/// stretch into long thin strips on a desktop monitor. On one column
/// [right] simply follows [left]. [rightWhenWide], when given, replaces
/// [right] in the two-column layout (e.g. a fuller tool list where there's
/// room for it).
class HubTabBody extends StatelessWidget {
  const HubTabBody({
    super.key,
    required this.left,
    required this.right,
    this.rightWhenWide,
  });

  final List<Widget> left;
  final List<Widget> right;
  final List<Widget>? rightWhenWide;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < hubTwoColumnMinWidth) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: hubPhoneMaxWidth),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
                children: [...left, ...right],
              ),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: hubWideMaxWidth),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: left,
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: rightWhenWide ?? right,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Sentence-case heading set on the cream canvas between sheets — instead
/// of all-caps tracked eyebrow labels.
class HubSectionLabel extends StatelessWidget {
  const HubSectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final label = Text(text, style: displayText(17, weight: 700));
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
      // Wrap: a trailing action drops under the label rather than
      // squeezing it on narrow screens / large text.
      child: trailing == null
          ? label
          : Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [label, trailing!],
            ),
    );
  }
}

/// Hairline between rows in a divided sheet, inset past the row icon.
class HubRowDivider extends StatelessWidget {
  const HubRowDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 1,
      indent: 56,
      color: AppColors.creamBorder,
    );
  }
}

/// One action as a list row: plain colored leading icon (no tinted chip),
/// title + supporting line, trailing control. Grouped several to a sheet
/// with [HubRowDivider]s instead of one card per action. When too narrow
/// (small phone, large text) the trailing control moves under the text.
class HubActionRow extends StatelessWidget {
  const HubActionRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.iconColor = AppColors.teal,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = scaledExtent(context, constraints.maxWidth) < 330;
        final text = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                color: AppColors.inkSoft,
              ),
            ),
          ],
        );
        final row = Row(
          crossAxisAlignment: stacked
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: iconColor),
            const SizedBox(width: 16),
            Expanded(child: text),
            if (!stacked) ...[const SizedBox(width: 12), trailing],
          ],
        );
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
          // Stacked, the action takes the row's full width under the text.
          child: stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [row, const SizedBox(height: 10), trailing],
                )
              : row,
        );
      },
    );
  }
}

/// A tappable navigation row in a divided sheet: icon, title, optional
/// supporting line, chevron. The whole row is the tap target.
class HubNavRow extends StatelessWidget {
  const HubNavRow({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.iconColor = AppColors.teal,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
          child: Row(
            children: [
              Icon(icon, size: 22, color: iconColor),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: AppColors.inkSoft,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// White sheet holding [HubNavRow]s / [HubActionRow]s with dividers.
class HubRowSheet extends StatelessWidget {
  const HubRowSheet({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      radius: 20,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            children: [
              for (final (i, child) in children.indexed) ...[
                if (i > 0) const HubRowDivider(),
                child,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact trailing action for a [HubActionRow] — keep [label] to a word
/// or two; the row's title already says what the action does.
class HubRowButton extends StatelessWidget {
  const HubRowButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = AppColors.teal,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        minimumSize: const Size(64, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        side: BorderSide(color: color.withValues(alpha: 0.45), width: 1.4),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
      ),
      onPressed: busy ? null : onPressed,
      child: busy
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          // One line that shrinks, rather than a label broken mid-word.
          : FittedBox(fit: BoxFit.scaleDown, child: Text(label)),
    );
  }
}

/// Tab-panel entrance — fade + slight slide-up. Like the HTML mock's
/// per-panel "rise", the outgoing panel is removed immediately (no
/// crossfade overlap). Skipped when the system asks for reduced motion.
class HubPanelRise extends StatefulWidget {
  const HubPanelRise({super.key, required this.child});

  final Widget child;

  @override
  State<HubPanelRise> createState() => _HubPanelRiseState();
}

class _HubPanelRiseState extends State<HubPanelRise>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  )..forward();
  late final _curved = CurvedAnimation(
    parent: _c,
    curve: const Cubic(0.2, 0.7, 0.3, 1.0),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return FadeTransition(
      opacity: _curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.03),
          end: Offset.zero,
        ).animate(_curved),
        child: widget.child,
      ),
    );
  }
}

/// Staggered entrance (fade + slide-up) for one section of a tab panel.
/// Skipped when the system asks for reduced motion.
class HubStaggerFadeIn extends StatefulWidget {
  const HubStaggerFadeIn({super.key, required this.delay, required this.child});

  final Duration delay;
  final Widget child;

  @override
  State<HubStaggerFadeIn> createState() => _HubStaggerFadeInState();
}

class _HubStaggerFadeInState extends State<HubStaggerFadeIn>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 280),
  );
  late final _fade = CurvedAnimation(
    parent: _c,
    curve: const Cubic(0.2, 0.7, 0.3, 1.0),
  );
  late final _slide = Tween<Offset>(
    begin: const Offset(0, 0.04),
    end: Offset.zero,
  ).animate(_fade);

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

/// Teal header for a page opened from a hub (Classroom Management, Class
/// Health, Home Mode Insights, Module Library…): back button, title,
/// supporting line, optional trailing [actions], and an optional [bottom]
/// control (chips, a segmented switch). Same lattice and rounded bottom as
/// [HubHeader].
class HubSubpageHeader extends StatelessWidget {
  const HubSubpageHeader({
    super.key,
    required this.title,
    required this.onBack,
    this.subtitle,
    this.actions = const [],
    this.bottom,
    this.backIcon = Icons.arrow_back_rounded,
    this.backTooltip = 'Back',
  });

  final String title;
  final String? subtitle;
  final VoidCallback onBack;
  final List<Widget> actions;
  final Widget? bottom;
  final IconData backIcon;
  final String backTooltip;

  @override
  Widget build(BuildContext context) {
    Widget circle(Widget child) => Material(
      color: Colors.white.withValues(alpha: 0.14),
      shape: const CircleBorder(),
      child: child,
    );
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
                constraints: const BoxConstraints(maxWidth: hubWideMaxWidth),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 12, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Tooltip(
                            message: backTooltip.tr,
                            child: circle(
                              InkWell(
                                customBorder: const CircleBorder(),
                                onTap: onBack,
                                child: SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: Icon(backIcon, color: Colors.white),
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),
                          for (final (i, action) in actions.indexed) ...[
                            if (i > 0) const SizedBox(width: 8),
                            circle(action),
                          ],
                        ],
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.only(left: 8, right: 6),
                        child: LayoutBuilder(
                          builder: (context, constraints) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: fitLongestWord(
                                  context,
                                  title,
                                  displayText(
                                    26,
                                    weight: 800,
                                    color: Colors.white,
                                  ),
                                  constraints.maxWidth,
                                ),
                              ),
                              if (subtitle != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  subtitle!,
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.4,
                                    color: Colors.white.withValues(alpha: 0.88),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      if (bottom != null) ...[
                        const SizedBox(height: 14),
                        Padding(
                          padding: const EdgeInsets.only(left: 8, right: 6),
                          child: bottom!,
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

/// White icon button for [HubSubpageHeader.actions].
class HubHeaderAction extends StatelessWidget {
  const HubHeaderAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip.tr,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

/// Translucent pill for a header's [HubSubpageHeader.bottom] row — a count
/// or context ("3 classes", "Grade 1 - Section A").
class HubHeaderChip extends StatelessWidget {
  const HubHeaderChip({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.tealDark.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.goldSoft),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Page frame for a hub sub-page: cream canvas, [header] pinned on tall
/// windows and scrolling away with the content on short ones (landscape
/// phone, large text), then [body] (usually a [HubTabBody] or
/// [HubListBody]).
class HubSubpage extends StatefulWidget {
  const HubSubpage({
    super.key,
    required this.header,
    required this.body,
    this.floatingActionButton,
    this.bottomBar,
  });

  final Widget header;
  final Widget body;
  final Widget? floatingActionButton;

  /// Pinned action bar under the content (e.g. a Save button).
  final Widget? bottomBar;

  @override
  State<HubSubpage> createState() => _HubSubpageState();
}

class _HubSubpageState extends State<HubSubpage> {
  /// Layout picked while the keyboard was closed. Opening the keyboard
  /// shrinks the page, and swapping layouts then would rebuild the focused
  /// field and close the keyboard straight away.
  bool? _short;

  @override
  Widget build(BuildContext context) {
    final header = widget.header;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.cream,
        floatingActionButton: widget.floatingActionButton,
        bottomNavigationBar: widget.bottomBar,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final content = SafeArea(top: false, child: widget.body);
            if (!keyboardOpen || _short == null) {
              _short = scaledExtent(context, constraints.maxHeight) < 640;
            }
            if (_short!) {
              return NestedScrollView(
                headerSliverBuilder: (context, _) => [
                  SliverToBoxAdapter(child: header),
                ],
                body: content,
              );
            }
            return Column(
              children: [
                header,
                Expanded(child: content),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// One centered scrolling column for list-style pages (capped at
/// [maxWidth] so rows don't stretch across a desktop monitor).
class HubListBody extends StatelessWidget {
  const HubListBody({super.key, required this.children, this.maxWidth = 720});

  final List<Widget> children;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
          children: children,
        ),
      ),
    );
  }
}

/// Empty state sheet: icon, display-face title, supporting line and an
/// optional action.
class HubEmptyState extends StatelessWidget {
  const HubEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppColors.teal),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: displayText(19)),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: AppColors.inkSoft,
            ),
          ),
          if (action != null) ...[const SizedBox(height: 18), action!],
        ],
      ),
    );
  }
}

/// Segmented switch for use on a teal header — [HubTabs] without icons.
class HubSegmented extends StatelessWidget {
  const HubSegmented({
    super.key,
    required this.labels,
    required this.active,
    required this.onChanged,
  });

  final List<String> labels;
  final int active;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: HubTabs(
        tabs: [for (final l in labels) (iconPath: null, label: l)],
        active: active,
        onChanged: onChanged,
      ),
    );
  }
}
