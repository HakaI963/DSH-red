// The visible switch for per-conversation auto-approve.

import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../theme/theme.dart';
import 'permission_pill.dart' show PermissionPillMetrics;

/// "Auto-allowing ⓧ": a warning-colored mini pill floating over the input bar's top-left, as tall as the plugin pill
/// ([PermissionPillMetrics.height]).
///
/// Auto-allow means commands stop being asked one by one, so it must stay visible at all times and close with one tap.
/// Icons at both ends (✓✓ left, ⓧ right), equal left/right insets.
class AutoApprovePill extends StatelessWidget {
  const AutoApprovePill({super.key, required this.onDisable});

  final VoidCallback onDisable;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final dsh = DshColors.of(context);
    final fg = dsh.onWarningContainer;
    final style = theme.textTheme.labelMedium?.copyWith(color: fg);
    return Semantics(
      button: true,
      label: l10n.chatAutoApproveCommands,
      onTapHint: l10n.commonClose,
      onTap: onDisable,
      excludeSemantics: true,
      child: Material(
        color: Color.alphaBlend(dsh.warningContainer.withValues(alpha: 0.94), theme.colorScheme.surface),
        shape: StadiumBorder(side: BorderSide(color: dsh.warning.withValues(alpha: 0.35), width: 0.5)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onDisable,
          child: SizedBox(
            height: PermissionPillMetrics.height,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(AppIcons.autoApprove, size: 16, color: fg),
                  const SizedBox(width: 6),
                  Text(l10n.chatAutoApproving, style: style),
                  const SizedBox(width: 8),
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(color: fg.withValues(alpha: 0.12), shape: BoxShape.circle),
                    child: Icon(AppIcons.close, size: 12, color: fg),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
