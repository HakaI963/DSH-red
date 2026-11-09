import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../state/chat_state.dart';
import '../../theme/app_icons.dart';
import '../../theme/theme.dart';
import '../slash_palette.dart' show slashIconFor;
import 'command_result_text.dart';
import 'stream_row.dart';

/// A slash command's execution record: command icon + monospaced `/compact`, DSH's result text below.
///
/// Commands never enter the model's context, so they look like notice lines, not messages: no bubble, tertiary text;
/// failures in danger color, a small spinner at the row tail while executing.
class CommandRow extends StatelessWidget {
  const CommandRow({super.key, required this.notice});

  final CommandNotice notice;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final dsh = DshColors.of(context);
    final (tileBg, tileFg) = dsh.tool(ToolTone.neutral);
    final failed = notice.done && !notice.success;
    final text = notice.text?.trim();
    final result = !notice.done
        ? null
        : (text == null || text.isEmpty)
        ? (notice.success ? l10n.commonCompleted : l10n.chatCommandFailed)
        : commandResultCopy(notice) ?? text;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox.square(
            dimension: StreamRow.lead,
            child: DecoratedBox(
              decoration: ShapeDecoration(color: tileBg, shape: Squircle.border(StreamRow.lead * 0.32)),
              child: Icon(slashIconFor(notice.name), size: StreamRow.lead * 0.6, color: tileFg),
            ),
          ),
          const SizedBox(width: StreamRow.gap),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // The command line and the 24 glyph block are vertically centered.
                SizedBox(
                  height: StreamRow.lead,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      notice.line,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.mono(size: 13, height: 1.35, color: colors.onSurfaceVariant),
                    ),
                  ),
                ),
                if (result != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: SelectableText(
                      result,
                      style: StreamRow.detail(context)?.copyWith(height: 1.45, color: failed ? dsh.danger : null),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: StreamRow.lead,
            child: Center(
              child: AnimatedSwitcher(
                duration: AppMotion.of(context, AppMotion.quick),
                child: !notice.done
                    ? SizedBox.square(
                        key: const ValueKey('run'),
                        dimension: 14,
                        child: CircularProgressIndicator(strokeWidth: 1.8, color: colors.primary),
                      )
                    : failed
                    ? Icon(AppIcons.close, key: const ValueKey('fail'), size: 16, color: dsh.danger)
                    : const SizedBox.shrink(key: ValueKey('done')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
