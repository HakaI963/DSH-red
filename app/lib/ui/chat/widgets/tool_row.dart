// Portions derived from PiPilot (https://github.com/CikeSeven/pi_pilot), MIT, Copyright (c) 2026 CikeSeven. See THIRD_PARTY_NOTICES.md.

import 'dart:async';

import 'package:dsh_client/dsh_client.dart';
import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../common/expand_reveal.dart';
import '../../common/fluid_bits.dart';
import '../../common/overscroll_forwarder.dart';
import '../../common/smooth_size.dart';
import '../../common/tool_glyph.dart';
import '../../plugins/view/plugin_view.dart' show DshUiParsed, PluginToolCard;
import '../../theme/app_icons.dart';
import '../../theme/theme.dart';
import '../render/ansi_text.dart';
import '../render/code_block.dart';
import '../render/diff_view.dart';
import '../media/media_card.dart';
import '../tool_view.dart';
import '../turn_summary.dart';
import 'approval_card.dart';
import 'change_card.dart' show DiffCounts;
import 'stream_motion.dart';
import 'stream_row.dart';
import 'tool_images.dart';

const _kDetailMaxHeight = 280.0;

/// One tool call: **a 32dp single line**; tapping grows a code-well detail below.
///
/// ```
/// ▣ run · flutter test test/auth          ◌
/// ▣ edit · lib/auth/login_controller.dart   +18 −4
/// ```
///
/// Geometry in [StreamRow]: the icon block hugs the body's left edge, the row tail hugs the right.
/// Opens the subagent conversation [id]; false when it isn't known yet.
typedef SubagentOpener = bool Function(String id);

final _startedSubagent = RegExp(r'started subagent ([\w:.-]+)');

/// The child a `subagent` / `subagent_fork` call started, or the one a
/// `send_message` / `interrupt_agent` call talks to; null for other tools and
/// while the call has no answer yet.
String? subagentIdOf(ToolChatItem item, [ToolView? view]) {
  switch (item.name) {
    case 'subagent' || 'subagent_fork':
      if (item.meta case {'subagentId': final String id} when id.isNotEmpty) {
        return id;
      }
      return _startedSubagent.firstMatch(item.resultText)?.group(1);
    case 'send_message' || 'interrupt_agent':
      final id = ToolView.of(item, view).arg('agent_id');
      return id == null || id.isEmpty ? null : id;
    default:
      return null;
  }
}

class ToolRow extends StatefulWidget {
  const ToolRow({
    super.key,
    required this.item,
    required this.onRespond,
    this.onAllowAll,
    this.autoAnswered = const {},
    this.onOpenSubagent,
    this.card = ToolCardPlacement.inline,
  });

  final ToolChatItem item;
  final ApprovalResponder onRespond;

  /// With a native card (`meta["dsh-go/view"]`), where the card draws; see [ToolCardPlacement].
  /// Calls without cards are unaffected.
  final ToolCardPlacement card;

  /// The approval card's "Allow for this chat"; hidden when null.
  final ApprovalAllowAll? onAllowAll;

  /// An approval auto-allowed locally, waiting for the Host to retract: no card anymore, the row tail shows it as running.
  final Set<String> autoAnswered;

  /// The "Subagent · …" row: opens that subagent's conversation (expands details as usual while it isn't known yet).
  final SubagentOpener? onOpenSubagent;

  @override
  State<ToolRow> createState() => _ToolRowState();
}

class _ToolRowState extends State<ToolRow> {
  ToolView? _view;

  /// Expanded state once the user tapped; before any tap it follows content: native-card calls default to expanded
  /// (and expand along when the result arrives and the card appears); everything else defaults to folded.
  bool? _toggled;

  ToolView get view => _view = ToolView.of(widget.item, _view);

  bool _expandedFor(ToolView v) =>
      _toggled ?? (widget.card == ToolCardPlacement.inline && (v.pluginView is DshUiParsed || v.media != null));

  @override
  Widget build(BuildContext context) {
    final v = view;
    // After a turn folds: only the card itself shows; the tool row is inside the process.
    if (widget.card == ToolCardPlacement.cardOnly) {
      if (v.media case final media?) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: MediaCard(meta: media),
        );
      }
      return switch (v.pluginView) {
        final DshUiParsed parse => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: PluginToolCard(parse: parse, fallback: const SizedBox.shrink(), details: false),
        ),
        _ => const SizedBox.shrink(),
      };
    }
    final expanded = _expandedFor(v);
    final request = widget.item.pendingApproval;
    final auto = request != null && widget.autoAnswered.contains(request.eventId);
    final pending = auto ? null : request;
    final opener = widget.onOpenSubagent;
    final child = opener == null ? null : subagentIdOf(widget.item, v);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _ToolHeader(
          view: v,
          autoAllowing: auto,
          expanded: expanded,
          opens: child != null,
          // The card is spread below (its title is the card itself): the row still carries the argument summary.
          titled: !(expanded && widget.card == ToolCardPlacement.inline && v.pluginView is DshUiParsed),
          onTap: () {
            if (child != null && opener!(child)) return;
            setState(() => _toggled = !expanded);
          },
        ),
        ExpandReveal(
          open: expanded,
          child: Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: switch (v.pluginView) {
              // Generated image / video: the media card (rows folded into the process don't paint it — the card is outside).
              _ when v.media != null && widget.card == ToolCardPlacement.inline => MediaCard(meta: v.media!),
              // The plugin tool brought a native card (meta["dsh-go/view"]); the row folded into
              // the process no longer paints the card (the card is outside).
              final parse? when widget.card == ToolCardPlacement.inline => PluginToolCard(
                parse: parse,
                fallback: ToolDetail(view: v),
              ),
              _ => ToolDetail(view: v),
            },
          ),
        ),
        if (pending != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: StreamFadeIn(
              key: ValueKey(pending.eventId),
              child: ApprovalCard(
                request: pending,
                view: v,
                onRespond: widget.onRespond,
                onAllowAll: widget.onAllowAll,
              ),
            ),
          ),
      ],
    );
  }
}

class _ToolHeader extends StatelessWidget {
  const _ToolHeader({
    required this.view,
    this.autoAllowing = false,
    required this.expanded,
    this.opens = false,
    this.titled = true,
    required this.onTap,
  });

  final ToolView view;
  final bool autoAllowing;
  final bool expanded;

  /// A tap opens another conversation: a chevron at the row's end.
  final bool opens;

  /// The summary uses the native card's title (if present).
  final bool titled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final dsh = DshColors.of(context);
    final status = view.item.status;
    final blocked = view.sandboxBlocked;
    final failed = status == ToolStatus.failed && !blocked;

    final title = titled ? view.pluginTitle : null;
    final summary = blocked ? l10n.chatToolNeedsApproval : title ?? view.summary;
    final summaryColor = failed ? dsh.danger : dsh.textTertiary;
    final summaryStyle = view.summaryIsCode && !blocked && title == null
        ? AppType.mono(size: 12.5, color: summaryColor, height: 1.3)
        : StreamRow.detail(context)?.copyWith(color: summaryColor);

    return Semantics(
      button: true,
      expanded: opens ? null : expanded,
      label: '${view.verb} $summary',
      child: StreamRowFrame(
        onTap: onTap,
        child: Row(
          children: [
            if (blocked) const _LockGlyph() else ToolGlyph(name: view.name, size: StreamRow.lead),
            const SizedBox(width: StreamRow.gap),
            Text(view.verb, style: StreamRow.label(context)),
            if (summary.isNotEmpty) ...[
              const StreamDot(),
              Expanded(
                child: Text(
                  summary,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: summaryStyle,
                ),
              ),
            ] else
              const Spacer(),
            const SizedBox(width: 8),
            SmoothSize(
              duration: AppMotion.of(context, AppMotion.quick),
              alignment: Alignment.centerRight,
              child: AppMotion.fluid(context)
                  ? _FluidTrail(view: view, autoAllowing: autoAllowing)
                  : AnimatedSwitcher(
                      duration: AppMotion.of(context, AppMotion.quick),
                      layoutBuilder: (current, previous) =>
                          Stack(alignment: Alignment.centerRight, children: [...previous, ?current]),
                      child: _StatusTrail(
                        key: ValueKey(_trailKind(view, autoAllowing)),
                        view: view,
                        autoAllowing: autoAllowing,
                      ),
                    ),
            ),
            if (opens) ...[const SizedBox(width: 4), Icon(AppIcons.disclosure, size: 16, color: dsh.textTertiary)],
          ],
        ),
      ),
    );
  }
}

/// The refused first attempt: a neutral lock, not a red cross.
class _LockGlyph extends StatelessWidget {
  const _LockGlyph();

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = DshColors.of(context).tool(ToolTone.neutral);
    const size = StreamRow.lead;
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: ShapeDecoration(color: bg, shape: Squircle.border(size * 0.32)),
        child: Icon(AppIcons.lock, size: size * 0.6, color: fg),
      ),
    );
  }
}

/// The fluid tier's trail. Running is a thin slow arc in the row's own quiet colour; a
/// tool that just succeeded draws a check for a moment and then goes quiet, as a
/// finished row is. Only one seen finishing: a row built finished stays empty.
class _FluidTrail extends StatefulWidget {
  const _FluidTrail({required this.view, required this.autoAllowing});

  final ToolView view;
  final bool autoAllowing;

  @override
  State<_FluidTrail> createState() => _FluidTrailState();
}

class _FluidTrailState extends State<_FluidTrail> {
  static const _checkFor = Duration(milliseconds: 900);

  Timer? _hold;
  bool _justDone = false;

  @override
  void didUpdateWidget(_FluidTrail old) {
    super.didUpdateWidget(old);
    final before = _trailKind(old.view, old.autoAllowing);
    final now = _trailKind(widget.view, widget.autoAllowing);
    if (before == 'spinner' && now == 'empty' && widget.view.item.status == ToolStatus.succeeded) {
      _justDone = true;
      _hold?.cancel();
      _hold = Timer(_checkFor, () {
        if (mounted) setState(() => _justDone = false);
      });
    } else if (now != 'empty') {
      _hold?.cancel();
      _justDone = false;
    }
  }

  @override
  void dispose() {
    _hold?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dsh = DshColors.of(context);
    final kind = _trailKind(widget.view, widget.autoAllowing);
    final Widget child = switch (kind) {
      'spinner' => QuietArc(key: const ValueKey('spinner'), color: dsh.textTertiary),
      'empty' when _justDone => DrawnCheck(key: const ValueKey('done'), size: 14, color: dsh.textTertiary),
      _ => _StatusTrail(key: ValueKey(kind), view: widget.view, autoAllowing: widget.autoAllowing),
    };
    return AnimatedSwitcher(
      duration: AppMotion.of(context, AppMotion.standard),
      switchInCurve: AppMotion.std,
      switchOutCurve: AppMotion.std,
      layoutBuilder: (current, previous) => Stack(alignment: Alignment.centerRight, children: [...previous, ?current]),
      child: child,
    );
  }
}

/// Which kind the row tail draws: only kind changes crossfade — streaming → running is still
/// the same little spinner, no flash.
String _trailKind(ToolView view, bool autoAllowing) => switch (view.item.status) {
  ToolStatus.streaming || ToolStatus.running => 'spinner',
  ToolStatus.awaitingApproval when autoAllowing => 'spinner',
  ToolStatus.failed when view.sandboxBlocked => 'empty',
  ToolStatus.succeeded when view.diffCounts == null => 'empty',
  final status => status.name,
};

/// Row-tail status: running spinner / failure ✕ / refused / cancelled / diff stats. Success stays quiet by default.
class _StatusTrail extends StatelessWidget {
  const _StatusTrail({super.key, required this.view, this.autoAllowing = false});

  final ToolView view;

  /// Waiting for confirmation but auto-passed by "Allow for this chat": it simply looks like it's running.
  final bool autoAllowing;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dsh = DshColors.of(context);
    final label = theme.textTheme.labelSmall?.copyWith(fontSize: 12);

    switch (view.item.status) {
      case ToolStatus.streaming || ToolStatus.running:
      case ToolStatus.awaitingApproval when autoAllowing:
        return SizedBox.square(
          dimension: 14,
          child: CircularProgressIndicator(strokeWidth: 1.8, color: colors.primary),
        );
      case ToolStatus.awaitingApproval:
        return Text(l10n.commonWaitingApproval, style: label?.copyWith(color: dsh.warning));
      case ToolStatus.failed:
        if (view.sandboxBlocked) return const SizedBox.shrink();
        return Icon(AppIcons.failed, size: 16, color: dsh.danger);
      case ToolStatus.denied:
        return Text(l10n.commonDeclined, style: label?.copyWith(color: dsh.warning));
      case ToolStatus.cancelled:
        return Text(l10n.commonCancelled, style: label?.copyWith(color: dsh.textTertiary));
      case ToolStatus.succeeded:
        final counts = view.diffCounts;
        if (counts == null) return const SizedBox.shrink();
        return DiffCounts(added: counts.added, removed: counts.removed);
    }
  }
}

/// Tool details: arguments + result, laid out in code wells. Rendering is picked per tool type:
/// read line numbers, edit/write diff, write's new-file code, bash ANSI output.
class ToolDetail extends StatelessWidget {
  const ToolDetail({super.key, required this.view});

  final ToolView view;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final dsh = DshColors.of(context);
    final item = view.item;
    final monoStyle = AppType.monoSmall(color: dsh.codeWellFg);

    final sections = <Widget>[];
    void section(String title, Widget body) {
      if (sections.isNotEmpty) {
        sections.add(Divider(height: 1, thickness: 0.5, color: dsh.codeWellBorder));
      }
      sections.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Text(
            title,
            style: AppType.eyebrow(color: dsh.textTertiary).copyWith(fontSize: 11, letterSpacing: 0.4),
          ),
        ),
      );
      sections.add(body);
    }

    Widget scrollWell(Widget child) => ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: _kDetailMaxHeight),
      child: OverscrollForwarder(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: SizedBox(width: double.infinity, child: child),
        ),
      ),
    );

    // —— Arguments ——
    if (view.command case final command?) {
      section(
        l10n.chatCommand,
        scrollWell(
          SelectableText.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: r'$ ',
                  style: monoStyle.copyWith(color: dsh.lineNumberFg),
                ),
                TextSpan(text: command),
              ],
            ),
            style: monoStyle,
          ),
        ),
      );
    } else if (view.isFileTool && view.path != null) {
      // File-family tools: the big old/new texts in arguments already surface in the diff below,
      // so only the path shows here (read adds the line range too).
      final window = view.readWindow;
      final last = window == null ? 0 : window.firstLine + '\n'.allMatches(window.code).length;
      // "· lines 40–44" never breaks apart on its own, nor splits from the path (when wrapping,
      // the whole run moves with the path's last segment to the next line; no line may start with "·"):
      // non-breaking spaces, word joiners on both sides of the dash.
      final lines = window == null ? '' : l10n.chatToolLineRange(window.firstLine, last);
      section(
        l10n.chatFile,
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: SelectableText.rich(
            TextSpan(
              style: monoStyle,
              children: [
                TextSpan(text: displayPath(view.path!)),
                TextSpan(
                  text: lines,
                  style: TextStyle(color: dsh.textTertiary),
                ),
              ],
            ),
          ),
        ),
      );
    } else if (item.arguments.trim().isNotEmpty && item.arguments.trim() != '{}') {
      section(l10n.chatParameters, scrollWell(SelectableText(view.prettyArguments, style: monoStyle)));
    }

    // —— Result ——
    var imagesShown = false;
    final resultTitle = view.isTerminal ? l10n.chatOutput : l10n.chatResult;
    if (view.sandboxBlocked) {
      // The sandbox-stopped first attempt: the leading lock already says it, so no extra paragraph.
    } else if (view.failureText case final failure?) {
      section(
        l10n.chatError,
        scrollWell(
          AnsiText(
            text: failure,
            style: monoStyle.copyWith(color: dsh.danger),
          ),
        ),
      );
    } else if (item.status == ToolStatus.succeeded) {
      if (view.diff case final lines? when lines.isNotEmpty) {
        section(l10n.chatChanges, DiffView(lines: lines, maxHeight: _kDetailMaxHeight, embedded: true));
      } else if (view.readWindow case final window?) {
        section(
          resultTitle,
          CodeBlock(
            code: window.code,
            language: window.language,
            showLineNumbers: true,
            firstLineNumber: window.firstLine,
            maxHeight: _kDetailMaxHeight,
            embedded: true,
            dense: true,
          ),
        );
      } else if (view.writtenContent case final content? when content.isNotEmpty) {
        final p = view.path;
        section(
          l10n.chatContent,
          CodeBlock(
            code: content,
            language: p == null ? null : languageForPath(p),
            maxHeight: _kDetailMaxHeight,
            embedded: true,
            dense: true,
          ),
        );
      } else {
        // Images belong to the result: under its text, or in its place.
        final text = view.resultText.trimRight();
        final images = view.hasImages
            ? Padding(
                padding: EdgeInsets.fromLTRB(12, text.isEmpty ? 4 : 0, 12, 12),
                child: ToolImages(view: view),
              )
            : null;
        imagesShown = images != null;
        section(
          resultTitle,
          text.isEmpty
              ? images ??
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                      child: Text(
                        l10n.chatNoOutput,
                        style: theme.textTheme.bodySmall?.copyWith(color: dsh.textTertiary),
                      ),
                    )
              : images == null
              ? scrollWell(AnsiText(text: text, style: monoStyle))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    scrollWell(AnsiText(text: text, style: monoStyle)),
                    images,
                  ],
                ),
        );
      }
    } else if (item.status == ToolStatus.denied) {
      section(
        resultTitle,
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: Text(l10n.chatToolDeclined, style: theme.textTheme.bodySmall?.copyWith(color: dsh.textTertiary)),
        ),
      );
    }

    if (view.hasImages && !imagesShown) {
      sections.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: ToolImages(view: view),
        ),
      );
    }

    if (sections.isEmpty) {
      section(
        l10n.commonStatus,
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: Text(
            view.isActive ? l10n.chatToolRunning : l10n.chatNoDetails,
            style: theme.textTheme.bodySmall?.copyWith(color: dsh.textTertiary),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: ShapeDecoration(
        color: dsh.codeWellBg,
        shape: RoundedSuperellipseBorder(
          borderRadius: AppShape.radiusMd,
          side: BorderSide(color: dsh.codeWellBorder, width: 0.5),
        ),
      ),
      child: Squircle.clip(
        radius: AppShape.md,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: sections,
        ),
      ),
    );
  }
}

/// Runs of ≥ 3 tool calls: **a one-line summary** — "ran 2 commands · read 3 files".
///
/// The running / awaiting-confirmation line always stays visible below the summary (live progress can't hide);
/// expanded, all rows hang under a left hairline ([StreamThread]).
class ToolGroup extends StatefulWidget {
  const ToolGroup({
    super.key,
    required this.tools,
    required this.onRespond,
    this.onAllowAll,
    this.autoAnswered = const {},
    this.onOpenSubagent,
    this.live = false,
  });

  final List<ToolChatItem> tools;
  final bool live;
  final ApprovalResponder onRespond;
  final ApprovalAllowAll? onAllowAll;
  final Set<String> autoAnswered;
  final SubagentOpener? onOpenSubagent;

  @override
  State<ToolGroup> createState() => _ToolGroupState();
}

class _ToolGroupState extends State<ToolGroup> {
  bool _expanded = false;

  /// The batch left outside when folded: the newest calls and still-running ones. Even when this batch finishes it stays
  /// until the next batch arrives and swaps out smoothly, instead of retracting first and growing back.
  late List<String> _liveKeys = [
    for (final tool in widget.tools)
      if (_active(tool)) tool.key,
  ];

  @override
  void initState() {
    super.initState();
    if (_liveKeys.isEmpty && widget.live) _liveKeys = [widget.tools.last.key];
  }

  @override
  void didUpdateWidget(ToolGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previous = {for (final tool in oldWidget.tools) tool.key};
    final added = widget.tools.where((tool) => !previous.contains(tool.key));
    if (added.isNotEmpty) {
      _liveKeys = [
        for (final tool in widget.tools)
          if (!previous.contains(tool.key) || _active(tool)) tool.key,
      ];
    }
  }

  static bool _active(ToolChatItem t) => switch (t.status) {
    ToolStatus.streaming || ToolStatus.running || ToolStatus.awaitingApproval => true,
    _ => t.pendingApproval != null,
  };

  ToolRow _row(ToolChatItem tool) => ToolRow(
    key: ValueKey(tool.key),
    item: tool,
    onRespond: widget.onRespond,
    onAllowAll: widget.onAllowAll,
    autoAnswered: widget.autoAnswered,
    onOpenSubagent: widget.onOpenSubagent,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final dsh = DshColors.of(context);
    final tools = widget.tools;
    final active = tools.where(_active).toList();
    final shown = tools.where((tool) => _liveKeys.contains(tool.key) || _active(tool)).toList();
    final summary = summarizeTools(tools);
    final failed = summary.failed;

    void toggle() => setState(() => _expanded = !_expanded);
    final header = Semantics(
      button: true,
      expanded: _expanded,
      label: failed > 0 ? l10n.chatToolFailures(summary.label, failed) : summary.label,
      excludeSemantics: true,
      onTap: toggle,
      child: StreamRowFrame(
        onTap: toggle,
        child: Row(
          children: [
            ToolGlyph(name: _leadingTool(tools), size: StreamRow.lead),
            const SizedBox(width: StreamRow.gap),
            Expanded(
              child: Text(summary.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: StreamRow.label(context)),
            ),
            if (failed > 0) ...[
              const SizedBox(width: 8),
              Icon(AppIcons.failed, size: 14, color: dsh.danger),
              Text('$failed', style: AppType.tabular(AppType.monoLabel(color: dsh.danger))),
            ],
            const SizedBox(width: 4),
            StreamChevron(open: _expanded),
          ],
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        header,
        ExpandReveal(
          open: _expanded,
          child: StreamThread(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [for (final tool in tools) _row(tool)],
            ),
          ),
        ),
        // The live rows outside while folded; when expanded they sit under the hairline, so this layer retracts.
        ExpandReveal(
          open: !_expanded && (active.isNotEmpty || (widget.live && shown.isNotEmpty)),
          child: SmoothSize(
            duration: AppMotion.of(context, AppMotion.collapse),
            curve: AppMotion.collapseCurve,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: AppMotion.of(context, AppMotion.quick),
              layoutBuilder: (current, previous) =>
                  Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
              child: Column(
                key: ValueKey(_liveKeys.join('|')),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [for (final tool in shown) _row(tool)],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The category square before the summary: the category of the summary's first span (the summary orders commands → file edits →
/// file reads → …), first call within that category. Counts are already spelled out with the other categories in text.
String _leadingTool(List<ToolChatItem> tools) {
  const order = [
    ToolKind.command,
    ToolKind.edit,
    ToolKind.read,
    ToolKind.search,
    ToolKind.web,
    ToolKind.agent,
    ToolKind.todo,
    ToolKind.other,
  ];
  for (final kind in order) {
    for (final tool in tools) {
      if (toolKindOf(tool) == kind) return tool.name;
    }
  }
  return tools.first.name;
}
