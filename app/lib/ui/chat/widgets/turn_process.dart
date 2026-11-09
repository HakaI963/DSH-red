// The whole-turn fold (DSH Web's foldCompletedTurns, dsh-TUI's settled groups)
// for the native chat list.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../theme/theme.dart';
import '../chat_rows.dart';
import 'stream_row.dart';

/// The collapsed process after a finished turn: one quiet summary line; tapping lists thinking,
/// tool calls and intermediate messages below as they were, under a left hairline saying "belongs to this turn" ([StreamThread]).
///
/// ```
/// ✓ Done · 7 tool calls · 1 message  ⌄
/// │ ⚛ thought · first look at pubspec…
/// │ ▣ read · lib/main.dart
/// ```
///
/// Elapsed time isn't written here: the turn footnote below the answer already has it.
///
/// Rows already present when opening the conversation "grow upward" inside the list (see ChatList's two sliver segments);
/// expanding naively would shove the summary line up. Here the expand animation is self-driven, and each frame, before layout,
/// adds the grown height back to the scroll position: the summary row stays put, content opens downward. When there isn't
/// a screenful above, scrolling tops out at the top (no blank left behind), and the summary only shifts up as far as content allows.
class TurnProcess extends StatefulWidget {
  const TurnProcess({
    super.key,
    required this.row,
    required this.buildRow,
    required this.gapBefore,
    this.settle = false,
  });

  final TurnProcessRow row;

  /// The turn just ended in plain view: appear first fully expanded, then collapse into the summary.
  final bool settle;

  /// How each row paints once expanded (it's the list's own rows).
  final Widget Function(ChatRow row) buildRow;

  /// Spacing between rows (the list's rules).
  final double Function(ChatRow row, ChatRow? previous) gapBefore;

  @override
  State<TurnProcess> createState() => _TurnProcessState();
}

/// Summary: `Done · 12 tool calls · 2 messages`; with only a few thinking stretches, `Done · 3 thinking stretches`.
String turnProcessLabel(TurnProcessRow row) {
  final thoughts = row.rows.whereType<AssistantRow>().where((r) => r.item.reasoning.trim().isNotEmpty).length;
  return [
    appL10n.commonCompleted,
    if (row.toolCalls > 0) appL10n.chatTurnToolCalls(row.toolCalls),
    if (row.messages > 0) appL10n.chatTurnMessages(row.messages),
    if (row.toolCalls == 0 && row.messages == 0 && thoughts > 0) appL10n.chatTurnThoughts(thoughts),
  ].join(' · ');
}

class _TurnProcessState extends State<TurnProcess> with SingleTickerProviderStateMixin {
  late final AnimationController _reveal = AnimationController(vsync: this, duration: AppMotion.collapse)
    ..addListener(_holdHeader)
    ..addStatusListener((status) {
      // Collapse finished: take the content off the tree.
      if (status == AnimationStatus.dismissed && mounted) setState(() {});
    });
  late final CurvedAnimation _factor = CurvedAnimation(parent: _reveal, curve: AppMotion.collapseCurve);
  late final Animation<double> _summaryFactor = ReverseAnimation(_factor);

  // Expanding vacates space before fading in; collapsing fades out before shrinking the height (same as ExpandReveal).
  late final CurvedAnimation _fade = CurvedAnimation(
    parent: _reveal,
    curve: const Interval(0.3, 1, curve: Curves.easeOut),
  );
  final _body = GlobalKey();

  /// Height already compensated in the scroll position (content can grow taller mid-animation, so account by height).
  double _held = 0;

  /// Automatic completion follows ChatList's content boundary, without the
  /// title compensation used when the person manually expands the process.
  late bool _settling = widget.settle;

  bool get _open => _reveal.status == AnimationStatus.forward || _reveal.status == AnimationStatus.completed;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reveal.duration = AppMotion.of(context, _settling ? AppMotion.standard : AppMotion.collapse);
    if (!_settling || !_reveal.isDismissed) return;
    if (_reveal.duration == Duration.zero) {
      _settling = false;
      return;
    }
    // Match the reply action row's reveal: the old process shrinks while
    // its summary and the actions grow by the same progress. Start in this
    // frame, too; a post-frame start would leave the actions one frame ahead.
    _factor.reverseCurve = AppMotion.std.flipped;
    _reveal.value = 1;
    _reveal.reverse().whenCompleteOrCancel(() {
      if (!mounted) return;
      _settling = false;
      _factor.reverseCurve = null;
      _reveal.duration = AppMotion.of(context, AppMotion.collapse);
    });
  }

  @override
  void dispose() {
    _fade.dispose();
    _factor.dispose();
    _reveal.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_open) {
      _reveal.reverse();
    } else {
      _reveal.forward();
    }
    setState(() {});
  }

  /// Each animation frame (before layout): in the upward-growing segment, subtract the height that grew from the scroll
  /// position. Content height is only known after the first layout; until then keep the debt, settle it post-frame.
  void _holdHeader() {
    if (!mounted || _settling) return;
    final box = _body.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      if (_factor.value > 0) {
        SchedulerBinding.instance.addPostFrameCallback((_) => _holdHeader());
      }
      return;
    }
    final shown = _factor.value * box.size.height;
    final delta = shown - _held;
    if (delta.abs() < 0.01) return;
    _held = shown;
    final sliver = context.findAncestorRenderObjectOfType<RenderSliver>();
    if (sliver == null || sliver.constraints.growthDirection != GrowthDirection.reverse) {
      return;
    }
    final position = Scrollable.maybeOf(context)?.position;
    if (position == null || !position.hasPixels) return;
    position.jumpTo(position.pixels - delta);
  }

  @override
  Widget build(BuildContext context) {
    final label = turnProcessLabel(widget.row);
    final rows = widget.row.rows;
    final open = _open;

    final header = Semantics(
      button: true,
      expanded: open,
      label: label,
      excludeSemantics: true,
      onTap: _toggle,
      child: StreamRowFrame(
        onTap: _toggle,
        child: Row(
          children: [
            StreamLead(child: Icon(AppIcons.completed, size: 18, color: DshColors.of(context).textTertiary)),
            const SizedBox(width: StreamRow.gap),
            Expanded(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: StreamRow.label(context)),
            ),
            const SizedBox(width: 4),
            StreamChevron(open: open),
          ],
        ),
      ),
    );

    Widget body() => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < rows.length; i++)
          Padding(
            key: ValueKey(rows[i].key),
            padding: EdgeInsets.only(top: i == 0 ? 0 : widget.gapBefore(rows[i], rows[i - 1])),
            child: widget.buildRow(rows[i]),
          ),
      ],
    );
    if (_settling) {
      // Keep the running rows' width and spacing until they disappear. Adding
      // the expanded thread's indent/padding would change their height at t=0.
      // The emerging summary becomes interactive when this brief handoff ends.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizeTransition(
            sizeFactor: _summaryFactor,
            alignment: AlignmentDirectional.topCenter,
            child: FadeTransition(
              opacity: _summaryFactor,
              child: IgnorePointer(child: header),
            ),
          ),
          SizeTransition(
            sizeFactor: _factor,
            alignment: AlignmentDirectional.topCenter,
            child: FadeTransition(
              opacity: _fade,
              child: KeyedSubtree(key: _body, child: body()),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        header,
        if (_reveal.status != AnimationStatus.dismissed)
          SizeTransition(
            sizeFactor: _factor,
            alignment: AlignmentDirectional.topCenter,
            child: FadeTransition(
              opacity: _fade,
              child: Padding(
                key: _body,
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: StreamThread(child: body()),
              ),
            ),
          ),
      ],
    );
  }
}
