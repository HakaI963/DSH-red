// Layer 2 of the run information, "Turn trajectory". The timeline reading (bars
// placed at their real start, model bars split into time-to-first-token and
// decoding, work in progress without an invented end) follows the official
// DSH trajectory overview.

import 'dart:math' as math;

import 'package:dsh_client/dsh_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../state/chat_state.dart';
import '../common/app_sheet.dart';
import '../common/expand_reveal.dart';
import '../common/sheet_title_bar.dart';
import '../common/think_glyph.dart';
import '../common/tool_glyph.dart';
import '../theme/app_icons.dart';
import '../theme/theme.dart';
import 'run_info.dart';
import 'step_detail_page.dart';
import 'usage_sheet.dart' show formatPercent, formatTokens;
import 'widgets/live_clock.dart';
import 'widgets/turn_failure_text.dart';

/// A half-screen sheet: how long each stretch of a turn took, laid out as a waterfall over real time.
Future<void> showTrajectorySheet(BuildContext context, {required String sessionId, required int turn}) {
  return showAppSheet<void>(
    context,
    isScrollControlled: true,
    builder: (_) => TrajectorySheet(sessionId: sessionId, turn: turn),
  );
}

class TrajectorySheet extends ConsumerWidget {
  const TrajectorySheet({super.key, required this.sessionId, required this.turn});

  final String sessionId;
  final int turn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final trace = ref.watch(chatProvider(sessionId).select((s) => s.turns.where((t) => t.turn == turn).lastOrNull));
    final items = ref.watch(chatProvider(sessionId).select((s) => s.items));
    final skew = ref.watch(chatProvider(sessionId).select((s) => s.clockSkew));
    final maxHeight = MediaQuery.sizeOf(context).height * 0.86;
    if (trace == null) {
      return SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SheetHeader(l10n.activityTraceTitle),
            Padding(
              padding: const EdgeInsets.fromLTRB(SheetTitleBar.inset, 8, SheetTitleBar.inset, 32),
              child: Text(
                l10n.activityTraceNotLoaded,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: DshColors.of(context).textTertiary),
              ),
            ),
          ],
        ),
      );
    }
    final tools = toolsById(items);

    // Half height at first; drag the list up for the rest of a long turn.
    // Short turns open at their own height and stop there.
    final rows = trajectoryRows(trace).length;
    final estimate = 150.0 + rows * 52 + 150;

    Widget body(Duration? elapsed) {
      final total = trace.duration ?? elapsed ?? Duration.zero;
      return LayoutBuilder(
        builder: (context, constraints) {
          final room = math.min(constraints.maxHeight, maxHeight);
          final full = (estimate / room).clamp(0.25, 1.0);
          final initial = math.min(full, 0.62);
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: initial * room / constraints.maxHeight,
            minChildSize: math.min(initial, 0.3) * room / constraints.maxHeight,
            maxChildSize: full * room / constraints.maxHeight,
            builder: (context, controller) => SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(trace: trace, total: total),
                  _Composition(trace: trace, total: total),
                  Expanded(
                    child: _EdgeFade(
                      child: _FollowTail(
                        controller: controller,
                        follow: trace.running,
                        child: SingleChildScrollView(
                          controller: controller,
                          padding: const EdgeInsets.only(top: 4, bottom: 8),
                          child: TrajectoryList(
                            trace: trace,
                            total: total,
                            tools: tools,
                            inset: 20,
                            onOpen: (span) =>
                                Navigator.of(context)
                                    .push(StepDetailPage.route(sessionId: sessionId, turn: trace.turn, span: span)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  TraceUsageFooter(trace: trace),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        },
      );
    }

    // A running turn's bars rescale as it goes: the whole body ticks (the
    // sheet is modal, the chat underneath does not rebuild).
    if (!trace.running) return body(null);
    return LiveElapsed(since: trace.start, skew: skew, builder: (context, elapsed) => body(elapsed));
  }
}

/// A running turn: on open it sits at the latest step, then follows the bottom; scroll up and it stops bothering you
/// (the official trajectory view likewise stays at the tail).
class _FollowTail extends StatefulWidget {
  const _FollowTail({required this.controller, required this.follow, required this.child});

  final ScrollController controller;
  final bool follow;
  final Widget child;

  @override
  State<_FollowTail> createState() => _FollowTailState();
}

class _FollowTailState extends State<_FollowTail> {
  bool _pinned = true;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_track);
    _stick();
  }

  @override
  void didUpdateWidget(_FollowTail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_track);
      widget.controller.addListener(_track);
    }
    _stick();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_track);
    super.dispose();
  }

  void _track() {
    final c = widget.controller;
    if (!c.hasClients || c.positions.length != 1) return;
    final p = c.position;
    _pinned = p.maxScrollExtent - p.pixels < 24;
  }

  void _stick() {
    if (!widget.follow || !_pinned) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = widget.controller;
      if (!mounted || !c.hasClients || c.positions.length != 1) return;
      final p = c.position;
      if (p.pixels != p.maxScrollExtent) p.jumpTo(p.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// A 12dp fade at both ends of the scroll area: content "sinks" under the card edge instead of being knife-cut.
class _EdgeFade extends StatelessWidget {
  const _EdgeFade({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) {
        final edge = rect.height <= 0 ? 0.0 : (12 / rect.height).clamp(0.0, 0.5);
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [Colors.transparent, Colors.black, Colors.black, Colors.transparent],
          stops: [0, edge, 1 - edge, 1],
        ).createShader(rect);
      },
      child: child,
    );
  }
}

/// The title row: close at top left, "Turn trajectory · 47 s"; when the turn didn't end cleanly, an explanation below.
class _Header extends StatelessWidget {
  const _Header({required this.trace, required this.total});

  final TurnTrace trace;
  final Duration total;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final dsh = DshColors.of(context);
    final time = trace.running ? formatClock(total) : formatSpan(total);
    final reason = trace.endReason;
    final (String? note, Color? noteColor) = trace.running
        ? (l10n.commonInProgress, theme.colorScheme.primary)
        : switch (reason?.kind) {
            'aborted' => (l10n.commonStopped, dsh.textTertiary),
            'error' => (turnFailureText(reason?.error?.code), dsh.danger),
            'max-tokens' => (l10n.activityTraceOutputLimit, dsh.warning),
            'interrupted' => (l10n.activityTraceEngineRestarted, dsh.warning),
            'blocked' => (l10n.activityTraceBlocked, dsh.warning),
            _ => (null, null),
          };
    final titleStyle = theme.textTheme.titleLarge!;
    final secondary = theme.colorScheme.onSurfaceVariant;
    final showClose = SheetDismissScope.of(context) == SheetDismissal.button;
    // Same close strategy as SheetTitleBar; reserve space for it only when the close key is explicit.
    // The explanation hugs the title; without a close key both sides keep 20.
    final line = MediaQuery.textScalerOf(context).scale(titleStyle.fontSize!) * (titleStyle.height ?? 1.2);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, showClose ? 14 : 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: math.max(0, (44 - line) / 2)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: l10n.activityTraceHeading),
                        ...measureSpans(
                          time,
                          AppType.tabular(titleStyle.copyWith(color: secondary, fontWeight: FontWeight.w400)),
                          unitScale: 0.78,
                        ),
                      ],
                    ),
                    style: titleStyle,
                  ),
                  AnimatedSwitcher(
                    duration: AppMotion.of(context, AppMotion.quick),
                    child: note == null
                        ? const SizedBox(width: double.infinity)
                        : Align(
                            key: ValueKey(note),
                            alignment: Alignment.centerLeft,
                            child: Text(
                              note,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(color: noteColor),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
          if (showClose) const SizedBox(width: 8),
          if (showClose)
            Padding(
              padding: EdgeInsets.only(top: math.max(0, (line - 44) / 2)),
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

/// Digits and units set separately: digits in [number] (monospaced), units ("s", "min",
/// "%", "tokens"…) one size smaller in secondary color.
List<TextSpan> measureSpans(String text, TextStyle number, {double unitScale = 0.82, Color? unitColor}) {
  final unit = number.copyWith(
    fontSize: (number.fontSize ?? 14) * unitScale,
    color: unitColor ?? number.color,
    fontWeight: FontWeight.w400,
  );
  final spans = <TextSpan>[];
  for (final m in _measurePart.allMatches(text)) {
    final part = m[0]!;
    final numeric = RegExp(r'^[\d.,:<>+\-−—~]+$').hasMatch(part.trim());
    spans.add(TextSpan(text: part, style: numeric ? number : unit));
  }
  return spans;
}

final _measurePart = RegExp(r'[\d.,:<>+\-−—~]+|[^\d.,:<>+\-−—~]+');

/// One stacked bar: how much model / tools / waiting take, with a legend line below.
class _Composition extends StatelessWidget {
  const _Composition({required this.trace, required this.total});

  final TurnTrace trace;
  final Duration total;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dsh = DshColors.of(context);
    final parts = [
      (l10n.activityModel, trace.modelTime, colors.primary),
      (l10n.activityTools, trace.toolTime, toolBarColor(context, ToolTone.terminal)),
      (l10n.activityTraceWaiting, trace.waitTime, dsh.warning),
    ].where((p) => p.$2 > Duration.zero).toList();
    if (parts.isEmpty) return const SizedBox(height: 4);
    final sum = parts.fold(Duration.zero, (a, p) => a + p.$2);
    final scale = math.max(math.max(total.inMilliseconds, sum.inMilliseconds), 1);
    final label = theme.textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(3)),
            child: SizedBox(
              height: 6,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, (_, time, color)) in parts.indexed) ...[
                    if (i > 0) const SizedBox(width: 2),
                    Expanded(
                      flex: math.max(1, time.inMilliseconds * 1000 ~/ scale),
                      child: ColoredBox(color: color),
                    ),
                  ],
                  if (scale > sum.inMilliseconds)
                    Expanded(
                      flex: math.max(1, (scale - sum.inMilliseconds) * 1000 ~/ scale),
                      child: ColoredBox(color: colors.onSurface.withValues(alpha: 0.06)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              for (final (name, time, color) in parts)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text('$name ${formatSpan(time)}', style: AppType.tabular(label!)),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Tool-category colors on the time bar: between container and on-color so both themes read them.
Color toolBarColor(BuildContext context, ToolTone tone) {
  final (bg, fg) = DshColors.of(context).tool(tone);
  return Color.lerp(bg, fg, 0.42)!;
}

/// The trajectory row list (shared by the sheet and session details). [total] is the timeline's length.
class TrajectoryList extends StatefulWidget {
  const TrajectoryList({
    super.key,
    required this.trace,
    required this.total,
    required this.tools,
    this.onOpen,
    this.inset = 16,
  });

  final TurnTrace trace;
  final Duration total;
  final Map<String, ToolChatItem> tools;
  final ValueChanged<TraceSpan>? onOpen;

  /// Row content's side inset: 16 on a page, 20 in the sheet.
  final double inset;

  @override
  State<TrajectoryList> createState() => _TrajectoryListState();
}

class _TrajectoryListState extends State<TrajectoryList> {
  /// The expanded groups (keyed by the seq of the group's first stretch).
  final _expanded = <int>{};

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final trace = widget.trace;
    final rows = trajectoryRows(trace);
    if (rows.isEmpty) {
      return Padding(
        padding: EdgeInsets.fromLTRB(widget.inset, 8, widget.inset, 12),
        child: Text(
          l10n.activityTraceNoSteps,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: DshColors.of(context).textTertiary),
        ),
      );
    }
    final total = widget.total.inMilliseconds <= 0 ? const Duration(milliseconds: 1) : widget.total;
    final now = trace.start.add(widget.total);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in rows)
          switch (row) {
            SpanRow(:final span) => SpanTile(
              span: span,
              trace: trace,
              total: total,
              now: now,
              inset: widget.inset,
              tool: widget.tools[span.callId],
              onTap: widget.onOpen == null ? null : () => widget.onOpen!(span),
            ),
            SpanGroupRow(:final spans) => _GroupTile(
              spans: spans,
              trace: trace,
              total: total,
              now: now,
              inset: widget.inset,
              tools: widget.tools,
              expanded: _expanded.contains(spans.first.seq),
              onToggle: () => setState(() {
                if (!_expanded.remove(spans.first.seq)) {
                  _expanded.add(spans.first.seq);
                }
              }),
              onOpen: widget.onOpen,
            ),
          },
      ],
    );
  }
}

/// One stretch: icon, title · summary, elapsed time, and below it a thin bar placed by real start/end.
/// Stretches waiting for your confirmation / answer get a warning-color ground — "slow" is often waiting on you.
class SpanTile extends StatelessWidget {
  const SpanTile({
    super.key,
    required this.span,
    required this.trace,
    required this.total,
    required this.now,
    this.tool,
    this.onTap,
    this.indent = 0,
    this.inset = 16,
  });

  final TraceSpan span;
  final TurnTrace trace;
  final Duration total;

  /// An in-progress stretch is measured up to here (Host time).
  final DateTime now;
  final ToolChatItem? tool;
  final VoidCallback? onTap;
  final double indent;

  /// Row content's side inset (the waiting stretch's ground reaches 8 further out).
  final double inset;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dsh = DshColors.of(context);
    final label = spanLabel(span, tool);
    final end = span.end ?? now;
    final duration = end.difference(span.start);
    final waiting = span.waiting;
    final failed = span.failed || (span.cutShort && span.kind == TraceKind.tool);
    final timeText = span.open ? formatClock(duration) : formatSpan(duration);

    final barColor = switch (span.kind) {
      TraceKind.model => colors.primary,
      TraceKind.approval || TraceKind.question => dsh.warning,
      TraceKind.tool => toolBarColor(context, ToolGlyphs.toneFor(span.toolName ?? '')),
    };
    final ttft = span.ttft;
    final head = ttft == null || duration.inMilliseconds <= 0
        ? null
        : (ttft.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

    final detailStyle = label.detailIsCode
        ? AppType.mono(size: 12, color: dsh.textTertiary, height: 1.3)
        : theme.textTheme.bodySmall?.copyWith(color: failed ? dsh.danger : dsh.textTertiary, height: 1.3);

    // A wait sits on a tinted squircle 8dp outside the rows' edge; its text
    // stays aligned with the rows around it.
    final edge = waiting ? 8.0 : inset;
    Widget content = Padding(
      padding: EdgeInsets.fromLTRB(edge + indent, 12, edge, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SpanGlyph(span: span, size: indent > 0 ? 20 : 24),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      label.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: waiting ? dsh.warning : colors.onSurface,
                        height: 1.3,
                      ),
                    ),
                    if (label.detail.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          label.detail,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: detailStyle,
                        ),
                      ),
                    ] else
                      const Spacer(),
                    const SizedBox(width: 8),
                    if (failed) ...[Icon(AppIcons.failed, size: 14, color: dsh.danger), const SizedBox(width: 2)],
                    Text(
                      timeText,
                      style: AppType.tabular(
                        theme.textTheme.labelSmall!.copyWith(
                          fontSize: 12,
                          color: waiting ? dsh.warning : colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TimelineBar(
                  start: span.start.difference(trace.start),
                  duration: duration,
                  total: total,
                  color: barColor,
                  head: head,
                  open: span.open,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (waiting) {
      content = Container(
        margin: EdgeInsets.symmetric(horizontal: inset - 8, vertical: 2),
        decoration: ShapeDecoration(
          color: dsh.warningContainer.withValues(alpha: 0.42),
          shape: Squircle.border(AppShape.md),
        ),
        child: content,
      );
    }

    return Semantics(
      button: onTap != null,
      label: l10n.activityTraceSpanSemantics(label.title, label.detail, formatSpan(duration)),
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(onTap: onTap, child: content),
    );
  }
}

/// A stretch's icon block: model is the accent thinking icon (the atomic one on official Web), reply is a
/// speech bubble, tools keep their category squares, waiting-on-you is warning-colored.
class SpanGlyph extends StatelessWidget {
  const SpanGlyph({super.key, required this.span, this.size = 24});

  final TraceSpan span;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dsh = DshColors.of(context);
    if (span.kind == TraceKind.tool) {
      return ToolGlyph(name: span.toolName ?? '', size: size);
    }
    // null = the thinking icon (not a font icon, painted on its own).
    final (IconData? icon, Color bg, Color fg) = switch (span.kind) {
      TraceKind.approval => (AppIcons.approval, dsh.warningContainer, dsh.onWarningContainer),
      TraceKind.question => (AppIcons.question, dsh.warningContainer, dsh.onWarningContainer),
      _ when span.toolCalls == 0 && span.hasText => (AppIcons.chat, colors.primaryContainer, colors.onPrimaryContainer),
      _ => (null, colors.primaryContainer, colors.onPrimaryContainer),
    };
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: bg,
          shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.all(Radius.circular(size * 0.32))),
        ),
        child: Center(
          child: icon == null ? ThinkGlyph(size: size * 0.62, color: fg) : Icon(icon, size: size * 0.6, color: fg),
        ),
      ),
    );
  }
}

/// One stretch on the timeline: drawn from its real start to end over a pale track; even 3dp stays visible.
/// A model stretch's [head] (wait before the first token) paints one shade paler. An in-progress stretch's right end is dashed.
class TimelineBar extends StatelessWidget {
  const TimelineBar({
    super.key,
    required this.start,
    required this.duration,
    required this.total,
    required this.color,
    this.head,
    this.open = false,
    this.height = 4,
  });

  final Duration start;
  final Duration duration;
  final Duration total;
  final Color color;

  /// 0..1: how much of the front of this stretch is pre-first-token waiting.
  final double? head;
  final bool open;
  final double height;

  @override
  Widget build(BuildContext context) {
    final track = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06);
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _BarPainter(
          start: start.inMilliseconds / total.inMilliseconds,
          length: duration.inMilliseconds / total.inMilliseconds,
          color: color,
          track: track,
          head: head,
          open: open,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  const _BarPainter({
    required this.start,
    required this.length,
    required this.color,
    required this.track,
    required this.head,
    required this.open,
  });

  final double start;
  final double length;
  final Color color;
  final Color track;
  final double? head;
  final bool open;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = Radius.circular(size.height / 2);
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, radius), Paint()..color = track);
    final width = size.width;
    final left = (start.clamp(0.0, 1.0) * width).clamp(0.0, width - 3);
    final barWidth = math.max(3.0, length.clamp(0.0, 1.0) * width);
    final right = math.min(width, left + barWidth);
    final rect = Rect.fromLTRB(left, 0, right, size.height);
    final rrect = RRect.fromRectAndRadius(rect, radius);
    canvas.save();
    canvas.clipRRect(rrect);
    if (open) {
      // Still going: the end fades out instead of claiming a length.
      canvas.drawRect(
        rect,
        Paint()..shader = LinearGradient(colors: [color, color.withValues(alpha: 0.2)]).createShader(rect),
      );
    } else {
      // A model request: the wait for the first token is the pale head.
      final split = left + rect.width * (head ?? 0).clamp(0.0, 1.0);
      if (split > left) {
        canvas.drawRect(Rect.fromLTRB(left, 0, split, size.height), Paint()..color = color.withValues(alpha: 0.32));
      }
      canvas.drawRect(Rect.fromLTRB(split, 0, right, size.height), Paint()..color = color);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.start != start ||
      old.length != length ||
      old.color != color ||
      old.track != track ||
      old.head != head ||
      old.open != open;
}

/// Consecutive tool calls within one step: a summary row, tap to open them one by one.
class _GroupTile extends StatelessWidget {
  const _GroupTile({
    required this.spans,
    required this.trace,
    required this.total,
    required this.now,
    required this.tools,
    required this.expanded,
    required this.onToggle,
    this.onOpen,
    this.inset = 16,
  });

  final List<TraceSpan> spans;
  final TurnTrace trace;
  final Duration total;
  final DateTime now;
  final Map<String, ToolChatItem> tools;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<TraceSpan>? onOpen;
  final double inset;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dsh = DshColors.of(context);
    final start = spans.first.start;
    final end = spans.map((s) => s.end ?? now).reduce((a, b) => a.isAfter(b) ? a : b);
    final duration = end.difference(start);
    final failed = spans.where((s) => s.failed).length;
    final label = groupLabel(spans, tools);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          expanded: expanded,
          label: l10n.activityTraceGroupSemantics(label, formatSpan(duration)),
          excludeSemantics: true,
          onTap: onToggle,
          child: InkWell(
            onTap: onToggle,
            child: Padding(
              padding: EdgeInsets.fromLTRB(inset, 12, inset, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Stack(spans: spans),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurface, height: 1.3),
                              ),
                            ),
                            if (failed > 0) ...[
                              const SizedBox(width: 6),
                              Icon(AppIcons.failed, size: 14, color: dsh.danger),
                              Text('$failed', style: AppType.monoLabel(color: dsh.danger)),
                            ],
                            const SizedBox(width: 8),
                            Text(
                              formatSpan(duration),
                              style: AppType.tabular(
                                theme.textTheme.labelSmall!.copyWith(fontSize: 12, color: colors.onSurfaceVariant),
                              ),
                            ),
                            const SizedBox(width: 2),
                            AnimatedRotation(
                              turns: expanded ? 0.5 : 0,
                              duration: AppMotion.of(context, AppMotion.collapse),
                              curve: AppMotion.collapseCurve,
                              child: Icon(AppIcons.expand, size: 16, color: colors.onSurfaceVariant),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 4,
                          child: Stack(
                            children: [
                              for (final span in spans)
                                Positioned.fill(
                                  child: TimelineBar(
                                    start: span.start.difference(trace.start),
                                    duration: (span.end ?? now).difference(span.start),
                                    total: total,
                                    color: toolBarColor(context, ToolGlyphs.toneFor(span.toolName ?? '')),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        ExpandReveal(
          open: expanded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final span in spans)
                SpanTile(
                  span: span,
                  trace: trace,
                  total: total,
                  now: now,
                  tool: tools[span.callId],
                  indent: 16,
                  inset: inset,
                  onTap: onOpen == null ? null : () => onOpen!(span),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A group's icon: the first two categories' tool squares, offset-stacked.
class _Stack extends StatelessWidget {
  const _Stack({required this.spans});

  final List<TraceSpan> spans;

  @override
  Widget build(BuildContext context) {
    final names = <String>[];
    final tones = <ToolTone>{};
    for (final span in spans) {
      final name = span.toolName ?? '';
      if (tones.add(ToolGlyphs.toneFor(name))) names.add(name);
      if (names.length == 2) break;
    }
    if (names.length == 1) return ToolGlyph(name: names.single, size: 24);
    final ring = DshSurfaces.of(context).sheet.fallbackFill;
    return SizedBox(
      width: 24,
      height: 24,
      child: Stack(
        children: [
          Positioned(left: 0, top: 0, child: ToolGlyph(name: names[0], size: 17)),
          Positioned(
            right: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: ShapeDecoration(
                shape: RoundedSuperellipseBorder(
                  borderRadius: const BorderRadius.all(Radius.circular(6.5)),
                  side: BorderSide(color: ring, width: 1.5),
                ),
              ),
              child: ToolGlyph(name: names[1], size: 17),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sheet footer: input (cache included), cache hit, output, first token; when unit prices are known, plus estimated cost.
class TraceUsageFooter extends StatelessWidget {
  const TraceUsageFooter({super.key, required this.trace, this.margin});

  final TurnTrace trace;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final dsh = DshColors.of(context);
    final usage = trace.usage;
    final hit = usage.cacheHitRate;
    final ttft = trace.ttft;
    final cost = turnCostLabel(trace);
    final stats = [
      (l10n.activityInput, usage.isEmpty ? '—' : formatTokens(usage.input)),
      (l10n.activityCacheHit, hit == null ? '—' : formatPercent(hit)),
      (l10n.activityOutput, usage.isEmpty ? '—' : formatTokens(usage.output)),
      if (ttft != null) (l10n.activityFirstToken, formatSpan(ttft)),
    ];
    final numberStyle = AppType.tabular(
      theme.textTheme.titleMedium!.copyWith(fontSize: 16, height: 1.3, fontWeight: FontWeight.w500),
    );
    return SheetGroup(
      margin: margin ?? const EdgeInsets.fromLTRB(20, 8, 20, 0),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              for (final (label, value) in stats)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedSwitcher(
                        duration: AppMotion.of(context, AppMotion.quick),
                        layoutBuilder: (current, previous) =>
                            Stack(alignment: Alignment.centerLeft, children: [...previous, ?current]),
                        child: Text.rich(
                          TextSpan(
                            children: measureSpans(value, numberStyle, unitColor: theme.colorScheme.onSurfaceVariant),
                          ),
                          key: ValueKey(value),
                          maxLines: 1,
                        ),
                      ),
                      Text(
                        label,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Text(
            [
              if (cost != null) l10n.activityTraceEstimatedCost(cost),
              if (usage.reasoning > 0) l10n.activityTraceReasoningTokens(formatTokens(usage.reasoning)),
              l10n.activityUsageInputIncludesCache,
            ].join(' · '),
            style: theme.textTheme.bodySmall?.copyWith(color: dsh.textTertiary),
          ),
        ),
      ],
    );
  }
}
