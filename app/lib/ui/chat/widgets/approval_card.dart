// Portions derived from PiPilot (https://github.com/CikeSeven/pi_pilot), MIT, Copyright (c) 2026 CikeSeven. See THIRD_PARTY_NOTICES.md.
// Layout after DSH Web's ApprovalPanel (warning hairline, warning strip, title,
// monospace command, right-aligned buttons).

import 'package:dsh_client/dsh_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/host_text.dart';
import '../../../l10n/l10n.dart';
import '../../common/risk_notice.dart';
import '../../theme/app_icons.dart';
import '../../theme/theme.dart';
import '../tool_view.dart';
import 'chat_card.dart';

typedef ApprovalResponder = Future<void> Function(ApprovalRequest request, ApprovalDecision decision);

/// "Allow for this chat": allow this once and auto-pass every later approval in this chat.
typedef ApprovalAllowAll = Future<void> Function(ApprovalRequest request);

/// The approval card: **the most eye-catching thing on screen, but not via big red**.
///
/// The local device has no bash sandbox, so the approval is the last gate. The shell and title row use [ChatCard]'s
/// "warning" register: a warning-colored shield + 1px warning hairline, and the title asks directly "Allow running this command?".
///
/// ```
/// ┌──────────────────────────────────┐
/// │ ⛉ Allow running this command?       │
/// │   run the login-related tests       │  note (secondary)
/// │ ┌──────────────────────────────┐ │
/// │ │ $ flutter test test/auth     │ │  command well
/// │ └──────────────────────────────┘ │
/// │   runs outside the sandbox: needs network │  reason (tertiary)
/// │ [    Deny    ]  [   Allow once   ] │  two equal-width keys; the accent goes only to "Allow once"
/// │        Allow for this chat           │  the wider grant demotes to a text button, to avoid mis-taps
/// └──────────────────────────────────┘
/// ```
class ApprovalCard extends StatefulWidget {
  const ApprovalCard({super.key, required this.request, required this.onRespond, this.onAllowAll, this.view});

  final ApprovalRequest request;
  final ApprovalResponder onRespond;

  /// "Allow for this chat" is hidden when null.
  final ApprovalAllowAll? onAllowAll;

  /// The matching tool call (if any, its command / path becomes the body).
  final ToolView? view;

  @override
  State<ApprovalCard> createState() => _ApprovalCardState();
}

class _ApprovalCardState extends State<ApprovalCard> {
  ApprovalDecision? _busy;

  Future<void> _respond(ApprovalDecision decision) async {
    if (_busy != null) return;
    HapticFeedback.selectionClick();
    setState(() => _busy = decision);
    await widget.onRespond(widget.request, decision);
    // On success the card vanishes with HostRequestCancelled; on failure it returns to clickable.
    if (mounted) setState(() => _busy = null);
  }

  Future<void> _allowAll() async {
    final allowAll = widget.onAllowAll;
    if (_busy != null || allowAll == null) return;
    HapticFeedback.selectionClick();
    // The whole conversation stops asking: said once, then trusted.
    if (!await confirmRisk(context, RiskNotices.allowForChat) || !mounted) return;
    setState(() => _busy = ApprovalDecision.allowOnce);
    await allowAll(widget.request);
    if (mounted) setState(() => _busy = null);
  }

  String get _title {
    final name = widget.view?.name ?? widget.request.toolName;
    return switch (name) {
      'bash' || 'pwsh' => appL10n.chatApproveCommand,
      'write' => appL10n.chatApproveWrite,
      'edit' || 'str_replace_editor' => appL10n.chatApproveEdit,
      'web_fetch' => appL10n.chatApproveWebpage,
      'web_search' => appL10n.chatApproveSearch,
      _ => appL10n.chatApproveTool(name),
    };
  }

  String? _reason(String locale) =>
      localizedHostText(widget.request.displayReason, locale: locale, fallback: widget.request.reason);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dsh = DshColors.of(context);
    final view = widget.view;
    final code = view?.command ?? (view?.path == null ? null : view!.path);
    final description = view?.arg('description')?.trim();
    final reason = _reason(l10n.localeName);
    const button = Size(0, 44);

    return ChatCard(
      icon: AppIcons.approval,
      title: _title,
      tone: ChatCardTone.attention,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(ChatCard.inset, 0, ChatCard.inset, ChatCard.inset),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (description != null && description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(description, style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant)),
                ),
              if (code != null && code.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                _CommandWell(text: code.trim(), isCommand: view?.command != null),
              ],
              if (reason != null) ...[
                const SizedBox(height: 8),
                Text(
                  reason,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: dsh.textTertiary),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy == null ? () => _respond(ApprovalDecision.reject) : null,
                      style: OutlinedButton.styleFrom(
                        minimumSize: button,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        side: BorderSide(color: colors.outline.withValues(alpha: 0.5)),
                      ),
                      child: _BusySwap(busy: _busy == ApprovalDecision.reject, child: Text(l10n.chatDecline)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy == null ? () => _respond(ApprovalDecision.allowOnce) : null,
                      style: FilledButton.styleFrom(
                        minimumSize: button,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: _BusySwap(
                        busy: _busy == ApprovalDecision.allowOnce,
                        color: colors.onPrimary,
                        child: Text(l10n.chatAllowOnce),
                      ),
                    ),
                  ),
                ],
              ),
              if (widget.onAllowAll != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Center(
                    child: TextButton(
                      onPressed: _busy == null ? _allowAll : null,
                      style: TextButton.styleFrom(
                        foregroundColor: colors.onSurfaceVariant,
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        textStyle: theme.textTheme.labelMedium?.copyWith(fontSize: 13),
                      ),
                      child: Text(l10n.chatAllowForChat),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CommandWell extends StatelessWidget {
  const _CommandWell({required this.text, required this.isCommand});

  final String text;
  final bool isCommand;

  @override
  Widget build(BuildContext context) {
    final dsh = DshColors.of(context);
    final style = AppType.mono(color: dsh.codeWellFg);
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: dsh.codeWellBg,
        shape: RoundedSuperellipseBorder(
          borderRadius: AppShape.radiusSm,
          side: BorderSide(color: dsh.codeWellBorder, width: 0.5),
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 148),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: SizedBox(
            width: double.infinity,
            child: SelectableText.rich(
              TextSpan(
                children: [
                  if (isCommand)
                    TextSpan(
                      text: r'$ ',
                      style: style.copyWith(color: dsh.lineNumberFg),
                    ),
                  TextSpan(text: displayPathIfPath(text, isCommand)),
                ],
              ),
              style: style,
            ),
          ),
        ),
      ),
    );
  }

  static String displayPathIfPath(String text, bool isCommand) => isCommand ? text : displayPath(text);
}

/// The button label and the small spinner crossfade (the button's width doesn't jump along).
class _BusySwap extends StatelessWidget {
  const _BusySwap({required this.busy, required this.child, this.color});

  final bool busy;
  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotion.of(context, AppMotion.quick),
      child: busy
          ? SizedBox.square(
              key: const ValueKey('busy'),
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          : KeyedSubtree(key: const ValueKey('idle'), child: child),
    );
  }
}
