import 'package:dsh_client/dsh_client.dart';
import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../state/subscriptions_state.dart' show subscriptionLabel;
import '../../common/expand_reveal.dart';
import '../../onboarding/api_key_page.dart';
import '../../providers/providers_page.dart';
import '../../providers/subscription_sheet.dart';
import '../../theme/app_icons.dart';
import '../../theme/theme.dart';
import 'stream_row.dart';
import 'turn_failure_text.dart';

/// pi-ai's wording when a subscription's stored grant can't be refreshed
/// (revoked, expired, signed out elsewhere) or is gone from its route.
final _grantLost = RegExp(
  r'OAuth (?:refresh failed|refresh returned a token that expires too soon'
  r'|auth derivation failed) for ([\w.-]+)'
  r'|no credential for provider route "([\w.-]+)"',
);

/// The subscription (ChatGPT, Claude) whose sign-in a turn [failure] says
/// has lapsed; null for any other failure.
Subscription? lapsedSubscription(LlmFailure? failure, [String text = '']) {
  for (final source in [?failure?.message, text]) {
    final m = _grantLost.firstMatch(source);
    if (m == null) continue;
    return Subscription.fromWire(m.group(1) ?? m.group(2));
  }
  return null;
}

/// A key at a notice line's tail ("Retry", "Continue").
typedef NoticeAction = ({String label, VoidCallback onPressed});

/// The notice line at a turn's end: error / stopped / retry / output cap…
///
/// Same geometry as process rows ([StreamRow]): icon centered in the 24 glyph column, text starts at 32.
/// On error the glyph is a small square on a sheer danger ground and the text is danger-colored; otherwise just a tertiary text line,
/// reading uninterrupted. One with error details expands the raw error code and message underneath on tap.
class NoticeRow extends StatefulWidget {
  const NoticeRow({super.key, required this.item, this.action});

  final NoticeChatItem item;
  final NoticeAction? action;

  @override
  State<NoticeRow> createState() => _NoticeRowState();
}

class _NoticeRowState extends State<NoticeRow> {
  bool _expanded = false;
  NoticeChatItem get item => widget.item;

  static final _retryCount = RegExp(r'\((\d+)(?:/(\d+))?\)');

  (IconData, String) _content(Subscription? lapsed) {
    final failure = item.failure;
    switch (item.kind) {
      case 'error':
        if (lapsed != null) {
          return (AppIcons.noApiKey, appL10n.chatSubscriptionExpired(subscriptionLabel(lapsed)));
        }
        if (failure?.code == 'MISSING_CREDENTIAL') {
          // pi-ai routes are the Model channels; the bare one is DeepSeek's key.
          if (failure!.message.startsWith('llm-pi-ai')) {
            return (AppIcons.noApiKey, appL10n.chatProviderKeyMissing);
          }
          return (AppIcons.noApiKey, appL10n.chatDeepSeekKeyMissing);
        }
        return (AppIcons.error, turnFailureText(failure?.code));
      case 'aborted':
        return (AppIcons.stopped, appL10n.commonStopped);
      case 'max-tokens':
        return (AppIcons.outputLimit, appL10n.chatOutputLimitReached);
      case 'blocked':
        return (AppIcons.blocked, appL10n.chatTurnBlocked);
      case 'interrupted':
        return (AppIcons.restart, appL10n.chatTurnEngineRestarted);
      case 'retry':
        final m = _retryCount.firstMatch(item.text);
        final text = m == null
            ? appL10n.chatRequestRetrying
            : m.group(2) == null
            ? appL10n.chatRequestRetryAttempt(int.parse(m.group(1)!))
            : appL10n.chatRequestRetryLimit(int.parse(m.group(1)!), int.parse(m.group(2)!));
        return (AppIcons.retry, text);
      default:
        return (AppIcons.info, item.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final dsh = DshColors.of(context);
    final isError = item.kind == 'error';
    final lapsed = isError ? lapsedSubscription(item.failure, item.text) : null;
    final (icon, text) = _content(lapsed);
    final style = StreamRow.detail(context)?.copyWith(height: 1.45, color: isError ? dsh.danger : null);

    // At most one key per line: expired login and missing key have their own destinations; the rest use what the list gives.
    final NoticeAction? action;
    if (lapsed != null) {
      action = (label: l10n.chatSignInAgain, onPressed: () => showSubscriptionLogin(context, lapsed));
    } else if (isError && item.failure?.code == 'MISSING_CREDENTIAL') {
      final pi = item.failure!.message.startsWith('llm-pi-ai');
      action = (
        label: l10n.chatGoToSettings,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => pi ? const ProvidersPage() : const ApiKeyPage(onboarding: false)),
        ),
      );
    } else {
      action = widget.action;
    }
    final failure = item.failure;
    final details = failure == null ? null : '${failure.code}\n${failure.message}'.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        StreamRowFrame(
          onTap: details == null ? null : () => setState(() => _expanded = !_expanded),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox.square(
                dimension: StreamRow.lead,
                child: DecoratedBox(
                  // On error the glyph block gets a sheer danger ground (same shape as tool icon blocks); others get no ground.
                  decoration: ShapeDecoration(
                    color: isError ? dsh.dangerContainer : null,
                    shape: Squircle.border(StreamRow.lead * 0.32),
                  ),
                  child: Icon(
                    icon,
                    size: isError ? StreamRow.lead * 0.6 : 16,
                    color: isError ? dsh.onDangerContainer : dsh.textTertiary,
                  ),
                ),
              ),
              const SizedBox(width: StreamRow.gap),
              Expanded(
                // The text's first line and the 24 glyph cell are vertically centered.
                child: Padding(
                  padding: const EdgeInsets.only(top: 2.5),
                  child: Text(text, style: style),
                ),
              ),
              AnimatedSwitcher(
                duration: AppMotion.of(context, AppMotion.quick),
                child: action == null
                    ? const SizedBox.shrink()
                    : Padding(
                        key: ValueKey(action.label),
                        padding: const EdgeInsets.only(left: 8),
                        child: _NoticeKey(label: action.label, onPressed: action.onPressed),
                      ),
              ),
            ],
          ),
        ),
        ExpandReveal(
          open: _expanded,
          child: Padding(
            padding: const EdgeInsets.only(left: StreamRow.indent, bottom: 8),
            child: SelectableText(details ?? '', style: StreamRow.detail(context)),
          ),
        ),
      ],
    );
  }
}

/// The row-tail key: a pill as tall as the glyph cell (24).
class _NoticeKey extends StatelessWidget {
  const _NoticeKey({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: StreamRow.lead,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          minimumSize: const Size(0, StreamRow.lead),
          tapTargetSize: MaterialTapTargetSize.padded,
          visualDensity: VisualDensity.compact,
          shape: const StadiumBorder(),
          textStyle: theme.textTheme.labelLarge?.copyWith(fontSize: 13),
        ),
        child: Text(label),
      ),
    );
  }
}

/// The inline banner of `ChatState.error`: floats above the input bar, dismissible.
/// [info] is for `ChatState.notice`: a hint, not a failure — info color and icon instead.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message, this.onDismiss, this.info = false, this.action});

  final String message;
  final VoidCallback? onDismiss;
  final bool info;
  final NoticeAction? action;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final dsh = DshColors.of(context);
    final container = info ? dsh.infoContainer : dsh.dangerContainer;
    final accent = info ? dsh.info : dsh.danger;
    final onContainer = info ? dsh.onInfoContainer : dsh.onDangerContainer;
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: Color.alphaBlend(container.withValues(alpha: 0.92), theme.colorScheme.surface),
          shape: Squircle.border(AppShape.md, side: BorderSide(color: accent.withValues(alpha: 0.3), width: 0.5)),
          shadows: [
            BoxShadow(
              color: NeutralTones.current(context).shadowInk.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
          child: Row(
            children: [
              Icon(info ? AppIcons.info : AppIcons.error, size: 17, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: onContainer),
                ),
              ),
              if (action case final action?)
                TextButton(
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48), foregroundColor: onContainer),
                  onPressed: action.onPressed,
                  child: Text(action.label),
                ),
              if (onDismiss != null)
                IconButton(
                  tooltip: l10n.commonClose,
                  onPressed: onDismiss,
                  iconSize: 18,
                  style: IconButton.styleFrom(minimumSize: const Size(40, 40), foregroundColor: onContainer),
                  icon: const Icon(AppIcons.close),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
