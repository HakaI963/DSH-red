// Portions derived from PiPilot (https://github.com/CikeSeven/pi_pilot), MIT, Copyright (c) 2026 CikeSeven. See THIRD_PARTY_NOTICES.md.

import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../state/composer_quote.dart' show splitQuote;
import '../../common/expand_reveal.dart';
import '../../common/fluid_bits.dart';
import '../../theme/app_icons.dart';
import '../../theme/theme.dart';
import '../media/generate_header.dart';
import '../media/media_format.dart' show mediaParamsLine;
import '../mention/mention_chip.dart';
import '../secret_mask.dart';
import 'message_actions.dart';
import 'quote_chip.dart';

/// User message: **a right-aligned soft bubble**, one shade deeper than the page — "pressed in" (Claude-style).
///
/// Forbidden pairings: on the bubble ground only primary / secondary text; tertiary text (4.32) and the accent color (4.22)
/// don't pass AA.
///
/// Long-press the bubble: copy / select text / edit and resend ([onEdit]) — the same menu as replies.
///
/// Messages starting with a quote block (quote follow-up) render the quote atop the bubble ([BubbleQuote])
/// with the body below; copy, select-text and edit still yield exactly what was sent.
///
/// Recognizable credentials (API keys, tokens, private keys, passwords in URLs) are masked only on screen
/// ([SecretText]); copying, selecting text and editing all get the original. Each segment of a sent message
/// carries a revealing eye; optimistic bubbles mask only.
class UserBubble extends StatelessWidget {
  const UserBubble({
    super.key,
    required this.text,
    this.attachments,
    this.pendingLabel,
    this.pendingIcon = AppIcons.queued,
    this.pendingActions = const [],
    this.onEdit,
  });

  final String text;

  /// Images and file cards, shown right-aligned above the bubble (Claude style:
  /// attachments aren't stuffed inside the bubble).
  final Widget? attachments;

  /// Non-empty = optimistic bubble (not yet echoed by DSH); shown below the bubble ("Sending" / "Queued").
  final String? pendingLabel;
  final IconData pendingIcon;

  /// Small text actions after the pending label ("Switch to interject", "Withdraw").
  final List<(String, VoidCallback)> pendingActions;

  /// "Edit and resend" in the long-press menu; null leaves it out (optimistic
  /// bubbles: they have "Withdraw" instead).
  final VoidCallback? onEdit;

  /// What the bubble shows: a generation request without its header.
  String get _shown => GenerateHeader.parse(text)?.description ?? text;

  Future<void> _menu(BuildContext context) async {
    final onEdit = this.onEdit;
    final action = await showMessageMenu(
      context,
      // The menu's top preview is display too, masked the same way; the preview strips `**` as bold,
      // so • is used here.
      text: maskSecrets(_shown, mark: '•'),
      actions: [MessageAction.copy, MessageAction.selectText, if (onEdit != null) MessageAction.edit],
    );
    if (!context.mounted || action == null) return;
    switch (action) {
      case MessageAction.copy:
        await copyMessage(context, _shown);
      case MessageAction.selectText:
        await showSelectTextSheet(context, _shown);
      case MessageAction.edit:
        onEdit?.call();
      case MessageAction.quote || MessageAction.share || MessageAction.regenerate || MessageAction.branch:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final surfaces = DshSurfaces.of(context);
    final style = AppType.chatBody(context, color: surfaces.onUserBubble);
    // A generation request (generation mode's parameter header on the first
    // line): the description is the bubble, the parameters a small line under
    // the bubble; the header itself is for the host's plugin.
    final generate = GenerateHeader.parse(text);
    final shown = generate?.description ?? text;
    final (:quote, :body) = splitQuote(shown);
    final interactive = pendingLabel == null;
    // Selecting goes through the menu ("Select text"): long-press is the menu.
    // `@` references draw as chips; text with a credential stays a plain
    // SecretText.
    Widget content = ReferenceText(quote == null ? shown : body, style: style, interactive: interactive);
    if (quote != null) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The quote is display too: credentials in it stay masked.
          BubbleQuote(maskSecrets(quote, mark: '•')),
          if (body.isNotEmpty) ...[const SizedBox(height: 6), content],
        ],
      );
    }

    // Its own semantics node, carrying the text and the long-press action.
    final bubble = Semantics(
      container: true,
      header: true,
      label: l10n.chatMe,
      child: HoldLift(
        onLongPress: () => _menu(context),
        child: DecoratedBox(
          decoration: ShapeDecoration(color: surfaces.userBubble, shape: AppShape.bubble),
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: content),
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth * 0.82;
        // Explicit nodes: the bubble's long-press node must not pull the
        // attachments' labels into one merged node.
        return Semantics(
          explicitChildNodes: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (attachments case final a?)
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: pendingLabel == null ? a : Opacity(opacity: 0.72, child: a),
                ),
              if (attachments != null && shown.trim().isNotEmpty) const SizedBox(height: 8),
              if (shown.trim().isNotEmpty)
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: AnimatedOpacity(
                    opacity: pendingLabel == null ? 1 : 0.72,
                    duration: AppMotion.of(context, AppMotion.quick),
                    child: bubble,
                  ),
                ),
              if (generate case (:final header, description: _))
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: shown.trim().isEmpty && attachments == null ? 0 : GenerateParamsLine.gap,
                      right: GenerateParamsLine.inset,
                    ),
                    child: GenerateParamsLine(header: header),
                  ),
                ),
              _PendingSlot(label: pendingLabel, icon: pendingIcon, actions: pendingActions),
            ],
          ),
        );
      },
    );
  }
}

/// Where [_PendingMeta] sits: on echo (same row, label turning null) this line and the pill on the input bar
/// collapse at the same pace, and the bubble lands smoothly instead of snapping a notch shorter. While collapsing it still paints
/// the last known state.
class _PendingSlot extends StatefulWidget {
  const _PendingSlot({required this.label, required this.icon, required this.actions});

  final String? label;
  final IconData icon;
  final List<(String, VoidCallback)> actions;

  @override
  State<_PendingSlot> createState() => _PendingSlotState();
}

class _PendingSlotState extends State<_PendingSlot> {
  late _PendingMeta? _last = _meta();

  _PendingMeta? _meta() => switch (widget.label) {
    final label? => _PendingMeta(label: label, icon: widget.icon, actions: widget.actions),
    null => null,
  };

  @override
  void didUpdateWidget(_PendingSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Echoed: keep the last line (without its buttons) while it folds away.
    _last =
        _meta() ??
        switch (_last) {
          final last? => _PendingMeta(label: last.label, icon: last.icon, actions: const []),
          null => null,
        };
  }

  @override
  Widget build(BuildContext context) => ExpandReveal(
    open: widget.label != null,
    duration: AppMotion.standard,
    curve: AppMotion.std,
    child: Align(alignment: Alignment.centerRight, child: _last ?? const SizedBox.shrink()),
  );
}

/// The line under an optimistic bubble: status ("Queued · sends after this turn") + text actions.
///
/// The right end aligns with the bubble's straight edge (8 indent): status only — the status text keeps 8; with actions —
/// the last action brings its own 8 per side tap area, so its text likewise rests at 8.
class _PendingMeta extends StatelessWidget {
  const _PendingMeta({required this.label, required this.icon, required this.actions});

  final String label;
  final IconData icon;
  final List<(String, VoidCallback)> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = DshColors.of(context).textTertiary;
    final style = theme.textTheme.labelSmall?.copyWith(color: muted);
    return Padding(
      padding: EdgeInsets.only(top: actions.isEmpty ? 4 : 0, right: actions.isEmpty ? 8 : 0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: muted),
          const SizedBox(width: 4),
          Text(label, style: style),
          for (final (text, onTap) in actions) ...[
            const SizedBox(width: 4),
            TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                tapTargetSize: MaterialTapTargetSize.padded,
                visualDensity: VisualDensity.compact,
                textStyle: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              child: Text(text),
            ),
          ],
        ],
      ),
    );
  }
}

/// "Image · 3:4 · 2 pieces" under a generation request: the pending line's look
/// (12 icon, small tertiary text), its right end 8 in from the bubble's
/// straight edge.
class GenerateParamsLine extends StatelessWidget {
  const GenerateParamsLine({super.key, required this.header});

  final GenerateHeader header;

  /// Bubble → line.
  static const gap = 4.0;

  /// The bubble's right edge → the line's end.
  static const inset = 8.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = DshColors.of(context).textTertiary;
    final video = header.kind == GenerateKind.video;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(video ? AppIcons.generateVideo : AppIcons.generateImage, size: 12, color: muted),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            mediaParamsLine(
              video: video,
              aspect: header.aspect,
              count: header.count,
              seconds: header.seconds,
              resolution: header.resolution,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.tabular(theme.textTheme.labelSmall!.copyWith(color: muted)),
          ),
        ),
      ],
    );
  }
}
