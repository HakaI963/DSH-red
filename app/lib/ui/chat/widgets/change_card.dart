import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../theme/theme.dart';
import '../diff_page.dart';
import '../turn_summary.dart';
import 'chat_card.dart';
import '../../common/brief_notice.dart';

/// The **change card** at a turn's end: which files changed, each with +/−, and the entry to the change detail page.
///
/// ```
/// ┌──────────────────────────────────────┐
/// │ ▤ Changed 5 files              +31 −6 │  ChatCard title row
/// │ ▢ login_controller.dart  app/l… +18 −4│  40 per row, no dividers
/// │ ▢ README.md  New                     +6 │
/// │ ▢ CHANGELOG.md                  +1 −1 │
/// │ View changes        2 more files  ›  │  ChatCardFooter
/// └──────────────────────────────────────┘
/// ```
///
/// Lists at most [shownCount] files; tapping a file opens that one directly, tapping the footer starts from the first.
class ChangeCard extends StatelessWidget {
  const ChangeCard({super.key, required this.files});

  final List<FileChange> files;

  /// How many files the card shows at most.
  static const shownCount = 3;

  void _open(BuildContext context, int index) {
    Navigator.of(context).push(ChangeDiffPage.route(files, initialIndex: index));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final added = files.fold(0, (sum, f) => sum + f.added);
    final removed = files.fold(0, (sum, f) => sum + f.removed);
    final shown = files.length <= shownCount ? files : files.sublist(0, shownCount);
    final hidden = files.length - shown.length;

    return ChatCard(
      icon: AppIcons.diff,
      title: l10n.chatChangedFiles(files.length),
      // One file: its row already carries the counts.
      trailing: files.length > 1 ? DiffCounts(added: added, removed: removed) : null,
      children: [
        for (final (i, file) in shown.indexed) _FileRow(file: file, onTap: () => _open(context, i)),
        ChatCardFooter(
          label: l10n.chatViewChanges,
          meta: hidden > 0 ? l10n.chatMoreFiles(hidden) : null,
          semanticsLabel: hidden > 0 ? l10n.chatViewMoreChanges(hidden) : l10n.chatViewChanges,
          onTap: () => _open(context, 0),
        ),
      ],
    );
  }
}

/// One file per row: filename, directory (weakened, elidable), +/−.
class _FileRow extends StatelessWidget {
  const _FileRow({required this.file, required this.onTap});

  final FileChange file;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dsh = DshColors.of(context);
    final directory = file.directory;
    void copy() => copyPath(context, file.path);

    return Semantics(
      button: true,
      label: l10n.chatFileChangeSemantics(file.shownPath, file.added, file.removed),
      excludeSemantics: true,
      onTap: onTap,
      onLongPress: copy,
      child: InkWell(
        onTap: onTap,
        onLongPress: copy,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 40),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: ChatCard.inset),
            child: Row(
              children: [
                Icon(
                  file.created ? AppIcons.fileNew : AppIcons.document,
                  size: 20,
                  color: file.created ? dsh.success : dsh.textTertiary,
                ),
                const SizedBox(width: 8),
                // One line: the name, then the directory, which gives way
                // first when the line runs out.
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: file.fileName),
                        if (file.created)
                          TextSpan(
                            text: l10n.chatNewFileSuffix,
                            style: theme.textTheme.labelSmall?.copyWith(color: dsh.success),
                          ),
                        if (directory.isNotEmpty)
                          TextSpan(
                            text: '  $directory',
                            style: AppType.mono(size: 11.5, height: 1.35, color: dsh.textTertiary),
                          ),
                      ],
                    ),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.3, color: colors.onSurface),
                  ),
                ),
                const SizedBox(width: 8),
                DiffCounts(added: file.added, removed: file.removed),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `+18 −4` in tabular figures; a zero side is dropped (both zero shows `+0`).
class DiffCounts extends StatelessWidget {
  const DiffCounts({super.key, required this.added, required this.removed});

  final int added;
  final int removed;

  @override
  Widget build(BuildContext context) {
    final dsh = DshColors.of(context);
    final mono = AppType.tabular(AppType.monoLabel(weight: FontWeight.w500));
    return Text.rich(
      TextSpan(
        children: [
          if (added > 0 || removed == 0)
            TextSpan(
              text: '+$added',
              style: mono.copyWith(color: dsh.success),
            ),
          if (removed > 0)
            TextSpan(
              text: '${added > 0 ? ' ' : ''}−$removed',
              style: mono.copyWith(color: dsh.danger),
            ),
        ],
      ),
    );
  }
}

/// Copies the full path and shows a light toast.
Future<void> copyPath(BuildContext context, String path) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.maybeOf(context);
  await Clipboard.setData(ClipboardData(text: path));
  HapticFeedback.selectionClick();
  messenger?.showBriefNotice(l10n.chatPathCopied);
}
