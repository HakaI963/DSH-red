// One shell for every card in the message stream (approval, question, changed
// files, delivered files), so they read as one family
// (docs/design/page-design.md §4: card radius 20, no rules between rows, 4-grid).

import 'package:flutter/material.dart';

import '../../theme/app_icons.dart';
import '../../theme/theme.dart';

/// The card's register: decides the title icon's color and the outer hairline.
enum ChatCardTone {
  /// Change card, artifact card: neutral; the title icon in secondary color.
  neutral,

  /// Approval card: waiting for you to let it through. Warning-colored icon + warning hairline — loud without big red blocks.
  attention,

  /// Question card: waiting for your answer. Info-colored icon + info hairline.
  ask,
}

/// Cards in the message stream: **one shared anatomy**.
///
/// ```
/// ┌──────────────────────────────────┐  card glass, radius 20
/// │ ▢ Title                    trailer │  top 16, icon 20 + 8 + titleSmall
/// │                                  │  8 below the title
/// │ content (no row dividers; row height does it) │  sides 16
/// │ footer / buttons                     │
/// └──────────────────────────────────┘
/// ```
///
/// [children] manage their own 16 sides and row heights; full-row tappable lines (files, artifacts, footer) use
/// an `InkWell` spanning the card width, ripple clipped to the card's corners.
class ChatCard extends StatelessWidget {
  const ChatCard({
    super.key,
    required this.icon,
    required this.title,
    required this.children,
    this.trailing,
    this.tone = ChatCardTone.neutral,
    this.titleMaxLines = 1,
  });

  final IconData icon;
  final String title;
  final Widget? trailing;
  final ChatCardTone tone;
  final List<Widget> children;
  final int titleMaxLines;

  /// The card's surrounding and title-row insets.
  static const inset = 16.0;

  /// The register color (title icon, outer hairline).
  static Color toneColor(BuildContext context, ChatCardTone tone) {
    final dsh = DshColors.of(context);
    return switch (tone) {
      ChatCardTone.neutral => Theme.of(context).colorScheme.onSurfaceVariant,
      ChatCardTone.attention => dsh.warning,
      ChatCardTone.ask => dsh.info,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = DshSurfaces.of(context);
    final accent = toneColor(context, tone);
    final style = tone == ChatCardTone.neutral
        ? null
        : surfaces.card.copyWith(hairline: accent.withValues(alpha: 0.45), hairlineWidth: 1);

    return GlassSurface(
      tier: GlassTier.card,
      borderRadius: AppShape.radiusLg,
      style: style,
      child: Material(
        type: MaterialType.transparency,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedSuperellipseBorder(borderRadius: AppShape.radiusLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(inset, inset, inset, 8),
              child: Row(
                crossAxisAlignment: titleMaxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                children: [
                  Icon(icon, size: 20, color: accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: titleMaxLines,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(height: 1.43),
                    ),
                  ),
                  if (trailing case final t?) ...[const SizedBox(width: 8), t],
                ],
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// The card footer: full row tappable, accent text at left, optional note + arrow at right. 44 tall.
class ChatCardFooter extends StatelessWidget {
  const ChatCardFooter({
    super.key,
    required this.label,
    required this.onTap,
    this.meta,
    this.icon = AppIcons.disclosure,
    this.semanticsLabel,
    this.expanded,
    this.iconTurns = 0,
  });

  final String label;
  final VoidCallback onTap;
  final String? meta;
  final IconData icon;
  final String? semanticsLabel;

  /// Expand / collapse footers pass the current state.
  final bool? expanded;

  /// Icon rotation (expand-style footer: 0 folded, 0.5 expanded), turning smoothly on change.
  final double iconTurns;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dsh = DshColors.of(context);
    return Semantics(
      button: true,
      expanded: expanded,
      label: semanticsLabel ?? label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(ChatCard.inset, 4, ChatCard.inset - 4, 4),
            child: Row(
              children: [
                Text(label, style: theme.textTheme.labelLarge?.copyWith(color: colors.primary)),
                const Spacer(),
                if (meta case final m?) ...[
                  Text(m, style: theme.textTheme.bodySmall?.copyWith(color: dsh.textTertiary)),
                  const SizedBox(width: 4),
                ],
                AnimatedRotation(
                  turns: iconTurns,
                  duration: AppMotion.of(context, AppMotion.collapse),
                  curve: AppMotion.collapseCurve,
                  child: Icon(icon, size: 20, color: dsh.textTertiary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
