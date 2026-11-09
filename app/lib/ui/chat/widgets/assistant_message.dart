// Portions derived from PiPilot (https://github.com/CikeSeven/pi_pilot), MIT, Copyright (c) 2026 CikeSeven. See THIRD_PARTY_NOTICES.md.

import 'dart:async';

import 'package:dsh_client/dsh_client.dart';
import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../common/expand_reveal.dart';
import '../../common/fluid_bits.dart';
import '../../common/typing_indicator.dart';
import '../../theme/app_icons.dart';
import '../../theme/theme.dart';
import '../dsh_ui/dsh_ui.dart';
import '../../plugins/native/message_plugin_menu.dart';
import '../../share/share_entry.dart' show shareReply;
import '../render/markdown_body.dart';
import 'message_actions.dart';
import 'stream_row.dart';
import 'thinking_pill.dart';

/// The three dots hand off to the next content block: old fades out linearly, new fades in nudging up a bit (Grok's published numbers).
const _handOffOut = Duration(milliseconds: 90);
const _handOffIn = AppMotion.quick;
const _handOffCurve = Cubic(0.23, 1, 0.32, 1);
const _handOffRise = 3.0;

/// The first body paragraph after thinking fades in.
const _firstTextIn = Duration(milliseconds: 200);

/// Assistant message: **frameless full-width body** (Claude-style), no avatar, no nameplate.
///
/// ```
/// (Thinking process ⌄)
/// body Markdown…▍
/// ⚠ Response interrupted
/// ⧉ ⇪ ⑂ ↻ ⋯        ← only the last message of a turn (branch depends on whether DSH supports it;
///                    ↻ Answer again only on the conversation's very last reply)
/// ```
///
/// ⇪ and the menu's "Share" open the same share panel. Long-press or ⋯: the same message menu (Copy /
/// Select text / Quote / Share / Answer again / Branch from here). So the body no longer long-presses into selection directly; selection goes through the menu's
/// "Select text", and a selected passage can also be "Quoted" (Claude-style).
class AssistantMessage extends StatefulWidget {
  const AssistantMessage({
    super.key,
    required this.item,
    this.showActions = false,
    this.onBranch,
    this.branching = false,
    this.onRegenerate,
    this.regenerating = false,
    this.onQuote,
    this.footnote,
  });

  final AssistantChatItem item;

  /// Whether to show copy and other actions below the body (only the turn's last assistant body message does).
  final bool showActions;

  /// "Branch from here"; null = this is not the last reply of a finished turn.
  final VoidCallback? onBranch;

  /// Branching from here right now: the branch key spins and can't be tapped again.
  final bool branching;

  /// "Answer again"; null = this is not the conversation's last reply, or the prompt can't be sent a second time.
  final VoidCallback? onRegenerate;

  /// Preparing Answer again: the regenerate key spins and can't be tapped again.
  final bool regenerating;

  /// "Quote": the whole reply, or a passage picked in "Select text", dropped above the input field.
  final ValueChanged<String>? onQuote;

  /// The turn footnote (this turn ended at this reply), hung at the action row's right end.
  final Widget? footnote;

  @override
  State<AssistantMessage> createState() => _AssistantMessageState();
}

class _AssistantMessageState extends State<AssistantMessage> {
  Widget? _body;
  String? _bodyText;
  bool? _bodyStreaming;
  bool? _bodyReveal;

  /// This reply once waited here (drew the three dots). Only it gets the handoff wrapper: replies already present when opening
  /// the conversation, or rebuilt after scrolling back, never add this layer.
  bool _waited = false;

  /// The body began after thinking: the first paragraph fades in.
  bool _textAfterThinking = false;

  static bool _waiting(AssistantChatItem item) =>
      item.streaming && item.text.trimRight().isEmpty && item.reasoning.trim().isEmpty;

  /// This reply started empty here, so all of it can be revealed as it arrives. One
  /// mounted halfway (the chat opened mid-stream, scrolled back to) shows what is there.
  bool _startedEmpty = false;

  /// The fluid tier's reveal, once it started it stays for this reply: see
  /// [MarkdownBody.reveal].
  bool _reveal = false;

  @override
  void initState() {
    super.initState();
    _waited = _waiting(widget.item);
    _startedEmpty = widget.item.text.trimRight().isEmpty;
  }

  @override
  void didUpdateWidget(AssistantMessage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.item;
    final item = widget.item;
    _waited = _waited || _waiting(item);
    if (old.streaming &&
        old.text.trimRight().isEmpty &&
        old.reasoning.trim().isNotEmpty &&
        item.text.trimRight().isNotEmpty) {
      _textAfterThinking = true;
    }
  }

  /// One text builds its Markdown subtree once: while the list rebuilds every 32ms,
  /// unchanged messages reuse the same widget instance and Flutter won't walk into them again.
  Widget _markdown(String text, bool streaming) {
    final reveal = _reveal = _reveal || (streaming && _startedEmpty && AppMotion.fluid(context));
    if (_body == null || _bodyText != text || _bodyStreaming != streaming || _bodyReveal != reveal) {
      // Long-press opens the menu; selecting text is one of its entries.
      // repairBareViews: a model that forgets the ```dsh-ui fence still gets
      // its view drawn instead of a wall of JSON.
      _body = MarkdownBody(text: text, streaming: streaming, reveal: reveal, selectable: false, repairBareViews: true);
      _bodyText = text;
      _bodyStreaming = streaming;
      _bodyReveal = reveal;
    }
    if (!reveal) return _body!;
    // The reveal has no cursor: a long pause gets a quiet dot under the text instead.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _body!,
        if (streaming)
          PositionedDirectional(
            start: 1,
            bottom: -_StallDot.size - 6,
            child: _StallDot(text: text),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final item = widget.item;
    final text = item.text.trimRight();
    final reasoning = item.reasoning.trim();
    final streaming = item.streaming;

    if (text.isEmpty && reasoning.isEmpty) {
      if (streaming) {
        return _HandOff(
          waiting: true,
          child: Align(
            key: const ValueKey('dots'),
            alignment: Alignment.centerLeft,
            heightFactor: 1,
            child: Semantics(label: l10n.chatReplying, child: const TypingIndicator()),
          ),
        );
      }
      if (!item.interrupted) return const SizedBox.shrink();
    }

    final actions = widget.showActions && !streaming && text.isNotEmpty;
    final reply = HoldLift(
      behavior: HitTestBehavior.opaque,
      onLongPress: streaming || text.isEmpty ? null : () => _menu(text),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (reasoning.isNotEmpty) ...[
            ThinkingPill(
              reasoning: reasoning,
              active: streaming && text.isEmpty,
              streaming: streaming,
              growIn: _waited,
            ),
            if (text.isNotEmpty && !_textAfterThinking) const SizedBox(height: 8),
          ],
          if (text.isNotEmpty)
            _textAfterThinking ? _FirstTextIn(child: _markdown(text, streaming)) : _markdown(text, streaming),
          if (item.interrupted) const _InterruptedMark(),
          // At a turn's end it unfolds at the same pace as the pill on the input bar: however much the pill
          // retracts, this grows, so the answer is never pushed up and then dropped back. Turns already finished when opening the chat unfold directly.
          ExpandReveal(
            open: actions,
            duration: AppMotion.standard,
            curve: AppMotion.std,
            child: actions
                ? ReplyActionRow(
                    // Copy / share carry a one-line summary of each visual
                    // reply, never its raw JSON.
                    text: dshUiPlainText(text),
                    onBranch: widget.onBranch,
                    branching: widget.branching,
                    onShare: () => shareReply(context, widget.item),
                    onRegenerate: widget.onRegenerate,
                    regenerating: widget.regenerating,
                    onMore: () => _menu(text),
                    trailing: widget.footnote,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
    // A reply is one screen-reader group; paragraphs and headings inside are read normally.
    final message = Semantics(key: const ValueKey('reply'), container: true, explicitChildNodes: true, child: reply);
    return _waited ? _HandOff(waiting: false, child: message) : message;
  }

  Future<void> _menu(String markdown) async {
    final text = dshUiPlainText(markdown);
    final onBranch = widget.onBranch;
    final onRegenerate = widget.onRegenerate;
    final onQuote = widget.onQuote;
    final action = await showMessageMenu(
      context,
      text: text,
      // Plugins' items for this reply, under each plugin's name.
      extra: nativeMessageMenuGroups(context, widget.item, text: markdown),
      actions: [
        MessageAction.copy,
        MessageAction.selectText,
        if (onQuote != null) MessageAction.quote,
        MessageAction.share,
        if (onRegenerate != null && !widget.regenerating) MessageAction.regenerate,
        if (onBranch != null && !widget.branching) MessageAction.branch,
      ],
    );
    if (!mounted || action == null) return;
    switch (action) {
      case MessageAction.copy:
        await copyMessage(context, text);
      case MessageAction.selectText:
        await showSelectTextSheet(context, text, markdown: true, onQuote: onQuote);
      case MessageAction.quote:
        onQuote?.call(text);
      case MessageAction.share:
        await shareReply(context, widget.item);
      case MessageAction.regenerate:
        onRegenerate?.call();
      case MessageAction.branch:
        onBranch?.call();
      case MessageAction.edit:
        break;
    }
  }
}

/// The handoff between the waiting three dots and the content that follows: one slot, stacked layers crossfading.
///
/// While waiting it holds the thinking row's height: if thinking follows, the height is unchanged and a bottom-pinned list needs
/// no chase; if the shorter body follows, the few extra pixels are slowly given back during the fade-in.
class _HandOff extends StatelessWidget {
  const _HandOff({required this.waiting, required this.child});

  final bool waiting;
  final Widget child;

  static Widget _transition(Widget child, Animation<double> animation) => FadeTransition(
    opacity: animation,
    child: AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) => Transform.translate(
        // Only the incoming one rises; the outgoing one fades in place.
        offset: Offset(0, animation.status == AnimationStatus.reverse ? 0 : _handOffRise * (1 - animation.value)),
        child: child,
      ),
    ),
  );

  // passthrough: the reply gets the same constraints as without this layer (full row width; long-press hit spots don't shrink).
  static Widget _layout(Widget? current, List<Widget> previous) => Stack(
    fit: StackFit.passthrough,
    alignment: AlignmentDirectional.topStart,
    clipBehavior: Clip.none,
    children: [...previous, ?current],
  );

  @override
  Widget build(BuildContext context) {
    final body = AppType.chatBody(context);
    final line = MediaQuery.textScalerOf(context).scale(body.fontSize ?? 16) * (body.height ?? 1.65);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: waiting ? StreamRow.minHeight : line),
      duration: AppMotion.of(context, _handOffIn),
      curve: AppMotion.std,
      builder: (context, height, child) => ConstrainedBox(
        constraints: BoxConstraints(minHeight: height),
        child: child,
      ),
      child: AnimatedSwitcher(
        duration: AppMotion.of(context, _handOffIn),
        reverseDuration: AppMotion.of(context, _handOffOut),
        switchInCurve: _handOffCurve,
        switchOutCurve: Curves.linear,
        transitionBuilder: _transition,
        layoutBuilder: _layout,
        child: child,
      ),
    );
  }
}

/// The first body paragraph after thinking: fades in while its top spacing grows from 0 to full. The thinking window is
/// collapsing right now — one side retracts as the other grows, so a bottom-pinned list moves in one direction only, never up-and-back.
class _FirstTextIn extends StatelessWidget {
  const _FirstTextIn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: AppMotion.of(context, _firstTextIn),
    curve: AppMotion.collapseCurve,
    builder: (context, t, child) => ClipRect(
      // Once settled: the same wrapper, no clipping (code blocks in the body may overflow sideways).
      clipBehavior: t < 1 ? Clip.hardEdge : Clip.none,
      child: Align(
        alignment: Alignment.topCenter,
        heightFactor: t,
        child: SizedBox(
          width: double.infinity,
          child: Opacity(opacity: t, child: child),
        ),
      ),
    ),
    child: Padding(padding: const EdgeInsets.only(top: 8), child: child),
  );
}

/// Cancelled / interrupted: a small danger-color line at the body's end; the body color stays untouched.
class _InterruptedMark extends StatelessWidget {
  const _InterruptedMark();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final danger = DshColors.of(context).danger;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.stopped, size: 16, color: danger),
          const SizedBox(width: 4),
          Text(
            l10n.chatInterrupted,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: danger, height: 1.3),
          ),
        ],
      ),
    );
  }
}

/// A reply that has gone quiet but isn't over: after a moment with no new text, one
/// small dot breathes where the next line would start. New text puts it away.
class _StallDot extends StatefulWidget {
  const _StallDot({required this.text});

  /// What has arrived so far: a change is the stream moving.
  final String text;

  static const size = 5.0;
  static const _after = Duration(milliseconds: 900);

  @override
  State<_StallDot> createState() => _StallDotState();
}

class _StallDotState extends State<_StallDot> with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(vsync: this, duration: AppMotion.breath ~/ 2);
  late final Animation<double> _level = Tween(
    begin: 0.25,
    end: 1.0,
  ).animate(CurvedAnimation(parent: _breath, curve: Curves.easeInOut));
  Timer? _wait;
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    _arm();
  }

  void _arm() {
    _wait?.cancel();
    _wait = Timer(_StallDot._after, () {
      if (!mounted) return;
      setState(() => _shown = true);
      unawaited(_breath.repeat(reverse: true));
    });
  }

  @override
  void didUpdateWidget(_StallDot old) {
    super.didUpdateWidget(old);
    if (old.text == widget.text) return;
    _breath.stop();
    if (_shown) setState(() => _shown = false);
    _arm();
  }

  @override
  void dispose() {
    _wait?.cancel();
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = DshColors.of(context).textTertiary;
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: _shown ? 1 : 0,
        duration: AppMotion.of(context, AppMotion.standard),
        child: RepaintBoundary(
          child: FadeTransition(
            opacity: _level,
            child: Container(
              width: _StallDot.size,
              height: _StallDot.size,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
        ),
      ),
    );
  }
}
