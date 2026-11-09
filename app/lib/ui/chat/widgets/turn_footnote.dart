// The quiet per-turn footnote (duration, steps, cost, tokens) that opens the
// turn's trajectory.

import 'package:dsh_client/dsh_client.dart';
import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../plugins/native/native_model.dart' show NativeTurnNotes;
import '../../plugins/native/native_tone.dart';
import '../../theme/app_icons.dart';
import '../../theme/theme.dart';
import '../run_info.dart';
import '../usage_sheet.dart' show formatTokens;

/// The **turn footnote** after a finished turn: `47 s · 12 steps · ≈¥0.03 · 360K tokens ›`.
///
/// When space is tight it drops tokens, steps, cost in that order; the duration always stays. Tap opens this turn's trajectory.
class TurnFootnote extends StatelessWidget {
  const TurnFootnote({super.key, required this.trace, this.onTap, this.notes});

  final TurnTrace trace;
  final VoidCallback? onTap;

  /// What plugins say about this turn (`turn.note`): the first thing to go when it doesn't fit.
  final NativeTurnNotes? notes;

  /// Forms from full to spare (use the first that fits).
  static List<String> variants(TurnTrace trace, {String? note}) {
    final duration = trace.duration;
    final time = duration == null ? appL10n.commonInProgress : formatSpan(duration);
    final steps = trace.steps > 0 ? appL10n.chatTurnSteps(trace.steps) : null;
    final cost = turnCostLabel(trace);
    final tokens = trace.usage.isEmpty ? null : '${formatTokens(trace.usage.total)} tokens';
    String join(List<String?> parts) => parts.whereType<String>().join(' · ');
    return [
      if (note != null) join([time, steps, cost, tokens, note]),
      join([time, steps, cost, tokens]),
      join([time, steps, cost]),
      join([time, cost]),
      time,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final dsh = DshColors.of(context);
    final style = AppType.tabular(
      theme.textTheme.labelSmall!.copyWith(fontSize: 12, color: dsh.textTertiary, height: 1.3),
    );
    final notes = this.notes;
    final options = variants(trace, note: notes?.text);
    return Semantics(
      button: onTap != null,
      label: l10n.chatTurnFootnoteSemantics(options.first),
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        customBorder: Squircle.border(AppShape.sm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 36),
          // Placed inside the Bleed(8) action row: left 8 makes the text hug the body's left edge; right 4 is optical compensation —
          // the arrow glyph carries ~5 of its own whitespace inside the 16 cell, so the stroke lands flush with the body's right edge.
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final room = constraints.maxWidth - 16;
                final text = options.firstWhere((o) => _width(context, o, style) <= room, orElse: () => options.last);
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: notes != null && text == options.first
                          ? _noted(text, notes, style, dsh)
                          : Text(text, maxLines: 1, softWrap: false, overflow: TextOverflow.fade, style: style),
                    ),
                    Icon(AppIcons.disclosure, size: 16, color: dsh.textTertiary),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// [text] ends with the notes: each in the tone its plugin asked for, the rest as it always is.
  static Widget _noted(String text, NativeTurnNotes notes, TextStyle style, DshColors dsh) => Text.rich(
    TextSpan(
      children: [
        TextSpan(text: text.substring(0, text.length - notes.text.length)),
        for (final (i, note) in notes.notes.indexed) ...[
          if (i > 0) const TextSpan(text: ' · '),
          TextSpan(
            text: note.text,
            style: TextStyle(color: nativeToneColor(dsh, note.tone)),
          ),
        ],
      ],
    ),
    maxLines: 1,
    softWrap: false,
    overflow: TextOverflow.fade,
    style: style,
  );

  static double _width(BuildContext context, String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }
}
