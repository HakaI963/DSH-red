// Portions derived from DeepSeek Harness (https://github.com/deepseek-ai/deepseek-harness), MIT, Copyright (c) 2026 DeepSeek. See THIRD_PARTY_NOTICES.md.
// Local changes: the phone actions (share, save to Downloads, copy path),
// thumbnails, and the "generated files" card for turns without deliverables.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../state/artifact_files.dart';
import '../../../state/artifacts.dart';
import '../../common/app_sheet.dart';
import '../../common/sheet_title_bar.dart';
import '../../session/workspace_files.dart' show formatBytes;
import '../../settings/settings_widgets.dart' show SettingsTile;
import '../../share/share_entry.dart' show shareArtifact;
import '../../theme/app_icons.dart';
import '../../theme/theme.dart';
import '../artifact_preview.dart';
import '../../common/expand_reveal.dart';
import 'change_card.dart' show copyPath;
import 'chat_card.dart';

/// The **artifact card** at a turn's end: files this turn delivered (`present`) or generated.
///
/// ```
/// ┌──────────────────────────────────────┐
/// │ ▣ Delivered 3 files                   │
/// │ [▦] Quarterly sales report.pdf       ⋯ │
/// │     quarterly summary                   │
/// │ [▤] trend.png                      ⋯ │
/// │     Image · PNG · 84.2 KB               │
/// │ All 6 files ⌄                           │
/// └──────────────────────────────────────┘
/// ```
///
/// Tap a row: images / Markdown / text preview in-app, everything else hands off to a phone app;
/// ⋯ or long-press: open, open with another app, share, save to "Downloads", copy path.
class ArtifactCard extends StatefulWidget {
  const ArtifactCard({super.key, required this.sessionId, required this.group});

  final String sessionId;
  final TurnArtifacts group;

  /// When folded, how many are listed at most (official Web uses 4 too).
  static const shownCount = 4;

  @override
  State<ArtifactCard> createState() => _ArtifactCardState();
}

class _ArtifactCardState extends State<ArtifactCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final files = widget.group.files;
    final collapsible = files.length > ArtifactCard.shownCount;
    final shown = collapsible ? files.sublist(0, ArtifactCard.shownCount) : files;
    final more = collapsible ? files.sublist(ArtifactCard.shownCount) : const <Artifact>[];
    final title = widget.group.delivered
        ? l10n.chatDeliveredFiles(files.length)
        : l10n.chatGeneratedFiles(files.length);

    ArtifactTile tile(Artifact file) =>
        ArtifactTile(key: ValueKey(file.path), sessionId: widget.sessionId, artifact: file);

    return ChatCard(
      icon: widget.group.delivered ? AppIcons.artifacts : AppIcons.generating,
      title: title,
      children: [
        for (final file in shown) tile(file),
        if (collapsible) ...[
          ExpandReveal(
            open: _expanded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [for (final file in more) tile(file)],
            ),
          ),
          ChatCardFooter(
            label: _expanded ? l10n.commonCollapse : l10n.chatAllFiles(files.length),
            icon: AppIcons.expand,
            expanded: _expanded,
            semanticsLabel: _expanded ? l10n.chatCollapseFileList : l10n.chatExpandAllFiles(files.length),
            onTap: () => setState(() => _expanded = !_expanded),
            iconTurns: _expanded ? 0.5 : 0,
          ),
        ] else
          const SizedBox(height: 8),
      ],
    );
  }
}

/// What a file action is doing right now.
enum _Busy { fetching, opening, saving }

/// One row per file: thumbnail / type icon, filename, description (or type · size), ⋯ actions.
///
/// An action's progress and result write themselves into the description line: a success note restores after 5 s (same as official),
/// a failure stays until the next attempt.
class ArtifactTile extends ConsumerStatefulWidget {
  const ArtifactTile({super.key, required this.sessionId, required this.artifact, this.dense = false});

  final String sessionId;
  final Artifact artifact;

  /// Used in the session details list: smaller side insets.
  final bool dense;

  @override
  ConsumerState<ArtifactTile> createState() => _ArtifactTileState();
}

class _ArtifactTileState extends ConsumerState<ArtifactTile> {
  _Busy? _busy;
  double? _progress;
  String? _note;
  bool _failed = false;
  Timer? _clear;

  Artifact get _artifact => widget.artifact;

  @override
  void dispose() {
    _clear?.cancel();
    super.dispose();
  }

  void _report(String note, {bool failed = false}) {
    if (!mounted) return;
    _clear?.cancel();
    setState(() {
      _busy = null;
      _progress = null;
      _note = note;
      _failed = failed;
    });
    if (!failed) {
      _clear = Timer(const Duration(seconds: 5), () {
        if (mounted) setState(() => _note = null);
      });
    }
  }

  Future<void> _run(_Busy busy, Future<String?> Function(ArtifactFiles files) action) async {
    if (_busy != null) return;
    _clear?.cancel();
    setState(() {
      _busy = busy;
      _progress = null;
      _note = null;
      _failed = false;
    });
    try {
      final note = await action(ref.read(artifactFilesProvider));
      if (!mounted) return;
      if (note == null) {
        setState(() => _busy = null);
      } else {
        _report(note);
      }
    } catch (e) {
      _report(artifactErrorText(e), failed: true);
    }
  }

  void _onProgress(double? progress) {
    if (!mounted) return;
    setState(() {
      if (_busy != _Busy.saving) {
        _busy = _Busy.fetching;
      }
      _progress = progress;
    });
  }

  Future<void> _open({bool chooser = false}) => _run(_Busy.opening, (files) async {
    await files.open(widget.sessionId, _artifact, chooser: chooser, onProgress: _onProgress);
    return null;
  });

  Future<void> _save() => _run(_Busy.saving, (files) async {
    final where = await files.saveToDownloads(widget.sessionId, _artifact, onProgress: _onProgress);
    return where.startsWith('Download/')
        ? appL10n.chatSavedToDownloadsPath(where.substring('Download/'.length))
        : appL10n.chatSavedToPath(where);
  });

  void _tap() {
    final files = ref.read(artifactFilesProvider);
    if (artifactPreviewable(_artifact, officeToPdf: files.canConvertOffice)) {
      Navigator.of(context).push(ArtifactPreviewPage.route(sessionId: widget.sessionId, artifact: _artifact));
    } else {
      _open();
    }
  }

  Future<void> _menu() async {
    final files = ref.read(artifactFilesProvider);
    final action = await showArtifactMenu(
      context,
      artifact: _artifact,
      canFetch: files.canFetch,
      officeToPdf: files.canConvertOffice,
    );
    if (!mounted || action == null) return;
    switch (action) {
      case ArtifactAction.preview:
        _tap();
      case ArtifactAction.open:
        await _open();
      case ArtifactAction.openWith:
        await _open(chooser: true);
      case ArtifactAction.share:
        await shareArtifact(context, sessionId: widget.sessionId, artifact: _artifact);
      case ArtifactAction.save:
        await _save();
      case ArtifactAction.copyPath:
        if (mounted) await copyPath(context, _artifact.path);
    }
  }

  String get _subtitle {
    final artifact = _artifact;
    return switch (_busy) {
      _Busy.fetching =>
        _progress == null ? appL10n.chatDownloading : appL10n.chatDownloadingPercent((_progress! * 100).round()),
      _Busy.opening => appL10n.chatOpening,
      _Busy.saving => appL10n.chatSavingToDownloads,
      null =>
        _note ??
            artifact.description ??
            [artifact.typeLabel, if (artifact.bytes case final b?) formatBytes(b)].join(' · '),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dsh = DshColors.of(context);
    final artifact = _artifact;
    final busy = _busy != null;
    final office = ref.watch(artifactFilesProvider.select((files) => files.canConvertOffice));
    final noteColor = _failed
        ? dsh.danger
        : _note != null
        ? dsh.success
        : dsh.textTertiary;

    return Semantics(
      button: true,
      label: l10n.chatArtifactSemantics(artifact.name, artifact.description ?? artifact.typeLabel),
      hint: artifactPreviewable(artifact, officeToPdf: office) ? l10n.chatPreview : l10n.chatOpenInPhoneApp,
      child: InkWell(
        onTap: busy ? null : _tap,
        onLongPress: busy ? null : _menu,
        child: Padding(
          // Right 6: the icon centres itself in the ⋯'s 40 tap cell so the glyph's right edge lands exactly on 16.
          padding: EdgeInsets.fromLTRB(widget.dense ? 12 : 16, 8, 6, 8),
          child: Row(
            children: [
              ArtifactThumb(sessionId: widget.sessionId, artifact: artifact),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      artifact.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.3,
                        fontWeight: FontWeight.w500,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    AnimatedSwitcher(
                      duration: AppMotion.of(context, AppMotion.quick),
                      layoutBuilder: (current, previous) =>
                          Stack(alignment: Alignment.centerLeft, children: [...previous, ?current]),
                      child: Text(
                        _subtitle,
                        key: ValueKey((_busy, _note, _failed)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.tabular(theme.textTheme.bodySmall!.copyWith(color: noteColor, height: 1.3)),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox.square(
                dimension: 40,
                child: busy
                    ? Center(
                        child: SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, value: _progress),
                        ),
                      )
                    : IconButton(
                        tooltip: l10n.chatMoreActions,
                        iconSize: 20,
                        color: dsh.textTertiary,
                        icon: const Icon(AppIcons.more),
                        onPressed: _menu,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A 40×40 file icon block; images swap in a thumbnail (when available).
class ArtifactThumb extends ConsumerWidget {
  const ArtifactThumb({super.key, required this.sessionId, required this.artifact, this.size = 40});

  final String sessionId;
  final Artifact artifact;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final image = artifact.kind == ArtifactKind.image
        ? ref.watch(artifactThumbnailProvider((sessionId, artifact.path))).value
        : null;
    final border = BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6), width: 0.5);
    if (image != null) {
      return SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: ShapeDecoration(shape: Squircle.border(10, side: border)),
          child: Squircle.clip(
            radius: 10,
            child: Image(
              image: ResizeImage(image, width: (size * MediaQuery.devicePixelRatioOf(context)).round()),
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => _icon(context),
            ),
          ),
        ),
      );
    }
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        // Official: icon ground block 50% white in light, 5% white in dark, plus a hairline ring.
        decoration: ShapeDecoration(
          color: Colors.white.withValues(alpha: dark ? 0.05 : 0.5),
          shape: Squircle.border(10, side: border),
        ),
        child: _icon(context),
      ),
    );
  }

  Widget _icon(BuildContext context) => Center(
    child: Icon(artifactIcon(artifact.kind), size: size * 0.5, color: artifactColor(context, artifact.kind)),
  );
}

IconData artifactIcon(ArtifactKind kind) => switch (kind) {
  ArtifactKind.image => AppIcons.image,
  ArtifactKind.pdf => AppIcons.pdf,
  ArtifactKind.document => AppIcons.document,
  ArtifactKind.spreadsheet => AppIcons.spreadsheet,
  ArtifactKind.slides => AppIcons.slides,
  ArtifactKind.archive => AppIcons.zip,
  ArtifactKind.audio => AppIcons.audioFile,
  ArtifactKind.video => AppIcons.videoFile,
  ArtifactKind.web => AppIcons.web,
  ArtifactKind.markdown => AppIcons.article,
  ArtifactKind.text => AppIcons.plainText,
  ArtifactKind.other => AppIcons.file,
};

/// Type colors follow office-software habits (PDF red, spreadsheet green, deck orange, document blue).
Color artifactColor(BuildContext context, ArtifactKind kind) {
  final dsh = DshColors.of(context);
  final colors = Theme.of(context).colorScheme;
  return switch (kind) {
    ArtifactKind.pdf => dsh.danger,
    ArtifactKind.spreadsheet => dsh.success,
    ArtifactKind.slides => dsh.warning,
    ArtifactKind.document => dsh.info,
    ArtifactKind.image || ArtifactKind.video || ArtifactKind.web => colors.primary,
    _ => colors.onSurfaceVariant,
  };
}

/// The artifact's actions.
enum ArtifactAction {
  preview(AppIcons.preview),
  open(AppIcons.openExternal),
  openWith(AppIcons.openWith),
  share(AppIcons.share),
  save(AppIcons.save),
  copyPath(AppIcons.copy);

  const ArtifactAction(this.icon);
  final IconData icon;

  String get label => switch (this) {
    ArtifactAction.preview => appL10n.chatPreview,
    ArtifactAction.open => appL10n.commonOpen,
    ArtifactAction.openWith => appL10n.commonOpenWith,
    ArtifactAction.share => appL10n.commonShare,
    ArtifactAction.save => appL10n.chatSaveToDownloads,
    ArtifactAction.copyPath => appL10n.chatCopyPath,
  };

  String? get hint => switch (this) {
    ArtifactAction.open => appL10n.chatOpenInDefaultApp,
    ArtifactAction.save => appL10n.chatDownloadsFolderHint,
    _ => null,
  };
}

/// The menu title follows [SheetTitleBar]'s dismissal policy. Description
/// and path sit directly below the name; only a button-only header reserves
/// a trailing close key.
class _MenuHead extends StatelessWidget {
  const _MenuHead({required this.name, required this.details});

  final String name;
  final List<Widget> details;

  static const _hit = 44.0;
  static const _slack = (_hit - SheetTitleBar.keySize) / 2;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = Theme.of(context).textTheme.titleLarge!;
    final line = MediaQuery.textScalerOf(context).scale(style.fontSize!) * (style.height ?? 1.2);
    final showClose = SheetDismissScope.of(context) == SheetDismissal.button;
    return Padding(
      padding: EdgeInsets.fromLTRB(SheetTitleBar.inset, 0, SheetTitleBar.inset - (showClose ? _slack : 0), 10),
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(top: math.max(0, (_hit - line) / 2), right: showClose ? _slack : 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  // Stops 8 before the key, like the bar's title.
                  padding: EdgeInsets.only(right: showClose ? _hit + 8 - _slack : 0),
                  child: Semantics(
                    header: true,
                    child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
                  ),
                ),
                ...details,
              ],
            ),
          ),
          if (showClose)
            Positioned(
              top: math.max(0, (line - _hit) / 2),
              right: 0,
              child: SheetIconButton(
                icon: AppIcons.close,
                tooltip: l10n.commonClose,
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
        ],
      ),
    );
  }
}

/// One artifact's action menu. [canFetch] = false (the connection can't read files) means copy-path only;
/// [officeToPdf]: the Host can convert Office files to PDF for preview.
Future<ArtifactAction?> showArtifactMenu(
  BuildContext context, {
  required Artifact artifact,
  required bool canFetch,
  bool officeToPdf = false,
}) {
  final l10n = context.l10n;
  HapticFeedback.selectionClick();
  return showAppSheet<ArtifactAction>(
    context,
    isScrollControlled: true,
    builder: (sheet) {
      final theme = Theme.of(sheet);
      final dsh = DshColors.of(sheet);
      final actions = [
        if (canFetch && artifactPreviewable(artifact, officeToPdf: officeToPdf)) ArtifactAction.preview,
        if (canFetch) ...[
          ArtifactAction.open,
          ArtifactAction.openWith,
          ArtifactAction.share,
        ],
        if (canFetch && !artifact.inPhoneDownloads) ArtifactAction.save,
        ArtifactAction.copyPath,
      ];
      return SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _MenuHead(
                name: artifact.name,
                details: [
                  if (artifact.description case final description?)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        description,
                        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    artifact.path,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.mono(size: 12, height: 1.4, color: dsh.textTertiary),
                  ),
                  if (artifact.inPhoneDownloads)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        l10n.chatAlreadyInDownloads,
                        style: theme.textTheme.bodySmall?.copyWith(color: dsh.textTertiary),
                      ),
                    ),
                  if (!canFetch)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        l10n.chatArtifactCopyPathOnly,
                        style: theme.textTheme.bodySmall?.copyWith(color: dsh.textTertiary),
                      ),
                    ),
                ],
              ),
              SheetGroup(
                children: [
                  for (final action in actions)
                    // Secondary sheet: line icons, secondary color, no color ground (page-design §4).
                    SettingsTile(
                      icon: action.icon,
                      tinted: false,
                      title: action.label,
                      subtitle: action.hint,
                      chevron: false,
                      onTap: () => Navigator.pop(sheet, action),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      );
    },
  );
}
