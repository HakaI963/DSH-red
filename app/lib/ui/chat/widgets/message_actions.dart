// Message actions after DSH Web's `MessageIconActions` (copy, branch).
// The menu every message opens (long-press, or ⋯ in a reply's row) is in
// `message_menu.dart`.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/l10n.dart';
import '../../common/bleed.dart';
import '../../common/fluid_bits.dart';
import '../../theme/app_icons.dart';
import '../../theme/theme.dart';
import 'message_menu.dart';
import '../../common/brief_notice.dart';

export 'message_menu.dart';

/// Copies [text]; [toast] confirms it when nothing else on screen does.
Future<void> copyMessage(BuildContext context, String text, {bool toast = true}) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.maybeOf(context);
  HapticFeedback.lightImpact();
  await Clipboard.setData(ClipboardData(text: text));
  if (toast) {
    messenger?.showBriefNotice(l10n.commonCopied);
  }
}

/// Quiet icons under the last reply of a turn: copy, share ([onShare], the
/// share panel), branch ([onBranch]), "Answer again" ([onRegenerate], the
/// conversation's last reply only) and ⋯ ([onMore]), which opens the same
/// menu as a long-press (select, quote…). [trailing] (the turn footnote)
/// sits at the row's right end.
class ReplyActionRow extends StatefulWidget {
  const ReplyActionRow({
    super.key,
    required this.text,
    this.onShare,
    this.onBranch,
    this.branching = false,
    this.onRegenerate,
    this.regenerating = false,
    this.onMore,
    this.trailing,
  });

  final String text;

  /// "Share": the share panel for this reply.
  final VoidCallback? onShare;
  final VoidCallback? onBranch;

  /// Branching right now: the branch key spins and can't be tapped again.
  final bool branching;

  /// "Answer again"; null leaves the key out.
  final VoidCallback? onRegenerate;

  /// Preparing Answer again (reading the original images, forking): the regenerate key spins and can't be tapped again.
  final bool regenerating;

  /// ⋯: the message menu.
  final VoidCallback? onMore;
  final Widget? trailing;

  @override
  State<ReplyActionRow> createState() => _ReplyActionRowState();
}

class _ReplyActionRowState extends State<ReplyActionRow> {
  bool _copied = false;

  void _copy() {
    copyMessage(context, widget.text, toast: false);
    setState(() => _copied = true);
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final muted = DshColors.of(context).textTertiary;
    // 36 round keys, 20 icons: 8 around each icon; together with the Bleed's 8 this makes the first icon
    // flush with the body's left edge and the footnote's arrow flush with its right.
    final style = IconButton.styleFrom(
      minimumSize: const Size.square(_button),
      maximumSize: const Size.square(_button),
      padding: EdgeInsets.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      foregroundColor: muted,
      iconSize: 20,
    );
    // In-place icon swap (check, spinner): fades in scaling from 0.7.
    Widget swap(Widget child) => AnimatedSwitcher(
      duration: AppMotion.of(context, AppMotion.quick),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: Tween(begin: 0.7, end: 1.0).animate(animation), child: child),
      ),
      child: child,
    );
    // In progress: the spinner in place; the key can't be tapped.
    Widget busyKey(MessageAction action, VoidCallback onTap, bool busy) => IconButton(
      tooltip: action.label,
      onPressed: busy
          ? null
          : () {
              HapticFeedback.lightImpact();
              onTap();
            },
      style: style,
      icon: swap(
        busy
            ? SizedBox.square(
                key: ValueKey('${action.name}-busy'),
                dimension: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: muted),
              )
            : Icon(action.icon, key: ValueKey(action.name)),
      ),
    );
    final onShare = widget.onShare;
    final onBranch = widget.onBranch;
    final onRegenerate = widget.onRegenerate;
    final onMore = widget.onMore;
    final icons = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: _copied ? l10n.commonCopied : l10n.commonCopy,
          onPressed: _copy,
          style: style.copyWith(foregroundColor: WidgetStatePropertyAll(_copied ? colors.primary : muted)),
          icon: swap(
            _copied && AppMotion.fluid(context)
                ? const DrawnCheck(key: ValueKey(true))
                : Icon(_copied ? AppIcons.done : AppIcons.copy, key: ValueKey(_copied)),
          ),
        ),
        if (onShare != null)
          IconButton(
            key: const ValueKey('reply-share'),
            tooltip: l10n.commonShare,
            onPressed: () {
              HapticFeedback.lightImpact();
              onShare();
            },
            style: style,
            icon: const Icon(AppIcons.share),
          ),
        if (onBranch != null) busyKey(MessageAction.branch, onBranch, widget.branching),
        if (onRegenerate != null) busyKey(MessageAction.regenerate, onRegenerate, widget.regenerating),
        if (onMore != null)
          IconButton(tooltip: l10n.commonMore, onPressed: onMore, style: style, icon: const Icon(AppIcons.more)),
      ],
    );
    final trailing = widget.trailing;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Bleed(
        horizontal: 8,
        child: Row(
          children: [
            icons,
            if (trailing != null) ...[
              const SizedBox(width: 8),
              Expanded(
                child: Align(alignment: Alignment.centerRight, child: trailing),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static const _button = 36.0;
}
