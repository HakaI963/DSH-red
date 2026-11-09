// Portions derived from PiPilot (https://github.com/CikeSeven/pi_pilot), MIT, Copyright (c) 2026 CikeSeven. See THIRD_PARTY_NOTICES.md.

import 'dart:async';
import 'dart:math' as math;

import 'package:dsh_client/dsh_client.dart' show CotTranslationLimits;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../state/cot_translation_state.dart';
import '../../../state/sessions_state.dart';
import '../../common/expand_reveal.dart';
import '../../common/pressable.dart';
import '../../common/smooth_size.dart';
import '../../common/think_glyph.dart';
import '../../engine_settings/engine_settings_page.dart' show openSettingsPage;
import '../../theme/app_icons.dart';
import '../../theme/theme.dart';
import '../render/markdown_body.dart';
import 'stream_pacer.dart';
import 'stream_row.dart';

/// The thinking process: **one row with the very anatomy tool rows use**.
///
/// ```
/// ⚛ Thinking                                 ⌄   ← the orbit spins; below is the live window
/// │ a paragraph being written, wrapping naturally, lines scrolling up   ← at most three lines, always on the newest text
/// ⚛ Thought · the user wants tool calls folded back…     ⌄   ← after finishing: preview of the full text's first line
/// │ full text (secondary typography)
/// ```
///
/// While thinking streams, below is **a continuous run of at most three lines**: it follows the newest characters written;
/// each completed line nudges gently up, height stays fixed, and the list never jumps because thinking grew a few lines. Tap this row
/// to expand the full text; tap again to fall back to three lines; manually expanded full text also auto-collapses when the turn ends.
///
/// The live window and the full text **share one slot**: one block of content at a time, so switching never leaves
/// one fading out while another fades in, stacked.
///
/// The glyph block is brand blue (thinking is DeepSeek's brand moment); the rest keeps the process row's secondary color.
///
/// The folded inline preview follows official Web: once done, take the full text's first line, both with `**` stripped. Expanded
/// view is Markdown in secondary typography.
///
/// With the engine's "thinking-process machine translation" plugin on, a "Translate" pill joins above the expanded full text:
/// the translation replaces the source in place, with "View original" to switch back anytime (official cot-translation's behavior).
/// DeepSeek brand blue (the whale tail's own color).
const _brandBlue = Color(0xFF4D6BFE);

class ThinkingPill extends StatefulWidget {
  const ThinkingPill({
    super.key,
    required this.reasoning,
    this.active = false,
    this.streaming = false,
    this.growIn = false,
  });

  final String reasoning;

  /// The model is thinking right now (streaming, body not started yet).
  final bool active;

  /// This reply is still streaming: when the turn ends (streaming done) retract any expanded full text.
  final bool streaming;

  /// Appears right after the waiting three dots: the three-line live window grows from 0, not materializing in one frame —
  /// this row's height was already reserved by the three dots; the window can't reserve it any earlier.
  final bool growIn;

  @override
  State<ThinkingPill> createState() => _ThinkingPillState();
}

/// The one-line preview when folded (official ReasoningRow's rule): the full text's first line, `**` removed.
String thinkingPreview(String text) => _firstLine(text).replaceAll('**', '').trim();

String _firstLine(String text) {
  final trimmed = text.trimLeft();
  final newline = trimmed.indexOf('\n');
  return newline == -1 ? trimmed : trimmed.substring(0, newline);
}

class _ThinkingPillState extends State<ThinkingPill> {
  bool _expanded = false;

  /// The block painted during the collapse animation: folded, it should already be off the tree, but while the height
  /// retracts it must stay a bit longer, never blink out leaving a blank.
  Widget? _body;

  /// The translation and "translation or original": survives collapse and re-expansion.
  final _translation = _TranslationHolder();

  /// The first frame holds the window closed; it opens on the next so [ExpandReveal] has something to expand.
  late bool _windowHeld = widget.growIn;

  @override
  void initState() {
    super.initState();
    if (!_windowHeld) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _windowHeld = false);
    });
  }

  @override
  void didUpdateWidget(ThinkingPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Turn ended: the process folds into the summary; even full text expanded by hand doesn't stay outside.
    if (oldWidget.streaming && !widget.streaming) _expanded = false;
  }

  @override
  void dispose() {
    _translation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    // On dark grounds, brand blue gets a brightness boost so the glyph doesn't look muffled.
    final brand = dark ? Color.lerp(_brandBlue, Colors.white, 0.3)! : _brandBlue;
    final active = widget.active;
    // Thinking, or the full text is expanded: content lives below; the inline row doesn't repeat a preview line.
    final open = active || _expanded;
    final preview = open ? '' : thinkingPreview(widget.reasoning);
    final detail = StreamRow.detail(context);

    final header = Row(
      children: [
        SizedBox.square(
          dimension: StreamRow.lead,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: brand.withValues(alpha: dark ? 0.18 : 0.10),
              shape: Squircle.border(StreamRow.lead * 0.32),
            ),
            child: Center(
              // Its own layer: spinning repaints this glyph only, not the whole row.
              child: RepaintBoundary(
                child: ThinkGlyph(size: 15, color: brand, spinning: active),
              ),
            ),
          ),
        ),
        const SizedBox(width: StreamRow.gap),
        // The label swaps text directly, no crossfade: two words flashing in one spot would look worse.
        ThinkingLabel(active ? l10n.chatThinkingActive : l10n.chatThinking, active: active),
        if (preview.isNotEmpty) ...[
          const StreamDot(),
          Expanded(
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (rect) => LinearGradient(
                colors: const [Colors.black, Colors.transparent],
                stops: [((rect.width - 40) / rect.width).clamp(0.0, 1.0), 1],
              ).createShader(rect),
              child: Text(preview, maxLines: 1, softWrap: false, overflow: TextOverflow.clip, style: detail),
            ),
          ),
        ] else
          const Spacer(),
        const SizedBox(width: 4),
        StreamChevron(open: _expanded),
      ],
    );

    Widget reasoningBody() {
      if (!_expanded) return ThinkingTicker(text: widget.reasoning);
      // Once expanded, tapping the body collapses just like tapping the header. The gesture layer mounts only in the expanded state: the live
      // window must still allow long-press selection and list scrolling — no extra tap target there.
      void collapse() => setState(() => _expanded = false);
      return _hasProviderScope(context)
          ? _TranslatableReasoning(
              text: widget.reasoning.trim(),
              active: active,
              holder: _translation,
              onBodyTap: collapse,
            )
          : _CollapsibleReasoningBody(
              onCollapse: collapse,
              child: MarkdownBody(text: widget.reasoning.trim(), streaming: active, secondary: true, selectable: false),
            );
    }

    // The live window and the expanded full text share one slot: only one block paints at a time. Animating the two separately
    // would fade one out as the other fades in, two runs of text stacking and flickering.
    if (open) {
      _body = SmoothSize(
        // The streaming block's height jumps instantly per line. A height animation on top would combine with the text's upward
        // slide and the list's bottom-chasing — the faster the text, the more it reads as vertical jitter. Animate only when expanding / collapsing the full text.
        duration: active && !_expanded ? Duration.zero : AppMotion.of(context, AppMotion.quick),
        alignment: AlignmentDirectional.topCenter,
        child: StreamThread(
          child: Padding(padding: const EdgeInsets.only(top: 4, bottom: 8), child: reasoningBody()),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          expanded: _expanded,
          child: StreamRowFrame(onTap: () => setState(() => _expanded = !_expanded), child: header),
        ),
        // One slot: live window while thinking, full text when tapped, collapsed when the turn ends.
        ExpandReveal(open: open && !_windowHeld, child: _body ?? const SizedBox.shrink()),
      ],
    );
  }
}

/// The thinking row's label. While thinking, a band of brightness sweeps the text slowly: travelling only between the label's grey and the body's deep,
/// never changing hue, never shifting position.
///
/// Cadence follows OpenAI's published Codex notes (matching its desktop): the first sweep [lead] after thinking starts,
/// each sweep lasting [sweep], one every [period]. Otherwise the controller is parked: no label repaints, no
/// [ShaderMask] mounted. Only one row sweeps on screen at a time: the one that started thinking later takes over. With system animations off,
/// it's simply static text.
///
/// Also moving are the spinning glyph and the scrolling live window. Three things competing for attention reads cheap: the window is information and
/// must not be touched; this sweep is the row's protagonist; the glyph steps back and turns very slowly (see [ThinkGlyph]).
class ThinkingLabel extends StatefulWidget {
  const ThinkingLabel(this.text, {super.key, this.active = false});

  final String text;
  final bool active;

  static const lead = Duration(milliseconds: 600);
  static const sweep = Duration(seconds: 1);
  static const period = Duration(seconds: 4);

  @override
  State<ThinkingLabel> createState() => _ThinkingLabelState();
}

class _ThinkingLabelState extends State<ThinkingLabel> with SingleTickerProviderStateMixin {
  /// Who holds the sweep right now.
  static _ThinkingLabelState? _owner;

  AnimationController? _sweep;
  Timer? _timer;

  void _sync() {
    final run = widget.active && !AppMotion.reduced(context);
    if (run == (_timer != null)) return;
    if (run) {
      _sweep ??= AnimationController(vsync: this, duration: ThinkingLabel.sweep);
      _timer = Timer(ThinkingLabel.lead, () {
        _timer = Timer.periodic(ThinkingLabel.period, (_) => _play());
        // Hand over inside the timer, not in build: parking someone else's controller dirties their subtree.
        _owner?._sweep?.reset();
        _owner = this;
        _play();
      });
    } else {
      _timer?.cancel();
      _timer = null;
      _sweep?.reset();
      _release();
    }
  }

  void _play() {
    // The holder finished: the sweep falls to this one, still thinking.
    _owner ??= this;
    if (identical(_owner, this)) _sweep!.forward(from: 0);
  }

  void _release() {
    if (identical(_owner, this)) _owner = null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(ThinkingLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) _sync();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sweep?.dispose();
    _release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = StreamRow.label(context);
    final label = Text(widget.text, style: style);
    final sweep = _sweep;
    if (sweep == null || _timer == null) return label;
    final muted = style?.color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    final bright = Theme.of(context).colorScheme.onSurface;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: sweep,
        child: label,
        builder: (context, child) {
          if (!sweep.isAnimating) return child!;
          return ShaderMask(
            blendMode: BlendMode.srcIn,
            // The bright band is exactly as wide as the label and travels from just outside its left to just outside its right: both ends rest in the static color, so start and stop never jump.
            shaderCallback: (rect) =>
                LinearGradient(colors: [muted, bright, muted])
                    .createShader(Rect.fromLTWH((2 * sweep.value - 1) * rect.width, 0, rect.width, rect.height)),
            child: child,
          );
        },
      ),
    );
  }
}

/// The expanded full text: the whole body is a collapse target, equivalent to tapping the header again.
///
/// The wrapping is deliberate: the body ships with text selection ([MarkdownBody]'s `selectable`), and the selection area
/// installs its own tap gesture and reaches pointers before outer wrappers — putting the gesture outside the selection
/// area directly means the selection area eats the tap. So here the body renders **without** the selection area, and this layer wraps
/// [SelectionArea] outside the collapse gesture: the collapse tap sits deeper and wins first; links and code-copy buttons in the body sit
/// deeper still and keep their own priority; long-press word selection and horizontal panning are left to the selection area
/// and scrolling to arbitrate.
class _CollapsibleReasoningBody extends StatelessWidget {
  const _CollapsibleReasoningBody({required this.onCollapse, required this.child});

  final VoidCallback onCollapse;
  final Widget child;

  @override
  Widget build(BuildContext context) => SelectionArea(
    child: Semantics(
      button: true,
      hint: context.l10n.commonCollapse,
      onTap: onCollapse,
      child: GestureDetector(
        // When the body is shorter than a line, the whitespace right of it counts as body too: tapping there collapses as well.
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: onCollapse,
        child: child,
      ),
    ),
  );
}

/// The live window for streaming thinking: **one continuous run of text**, a window always three lines tall, characters entering from the
/// bottom; each completed line slides the whole run up at constant speed. No row splitting, no per-line effects — adjacent frames never
/// paint two copies of text stacked, and reading needs no horizontal hunting.
///
/// The block height never changes: the list doesn't chase the bottom line by line while streaming, and fast writing never jitters.
/// Under three lines the text sits at the window's top with empty space after; once a line fills, upward motion starts naturally.
class ThinkingTicker extends StatelessWidget {
  const ThinkingTicker({super.key, required this.text});

  final String text;

  /// The window's line count (the TUI's PREVIEW_ROWS).
  static const rows = 3;

  @override
  Widget build(BuildContext context) {
    if (AppMotion.fluid(context)) return _FluidTicker(text: text);
    final style = StreamRow.detail(context);
    final scaler = MediaQuery.textScalerOf(context);
    final lineHeight = scaler.scale(style?.fontSize ?? 13) * (style?.height ?? 1.3);
    final shown = thinkingTickerText(text);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // Measure once: window height = min(content height, three lines).
        final painter = TextPainter(
          text: TextSpan(text: shown, style: style),
          textDirection: Directionality.of(context),
          textScaler: scaler,
        )..layout(maxWidth: width);
        final textHeight = painter.height;
        // Measure on every publish: layout objects hold native resources and must not wait for GC.
        painter.dispose();
        final window = lineHeight * ThinkingTicker.rows;
        // Always three lines tall: block height constant while streaming, so no line-by-line bottom chasing and no jitter under fast writing.
        final height = window;
        // The overflow pushes upward; what shows is always the last three lines. Completing a line moves the target by
        // exactly one line, nudged smoothly by AnimatedContainer — no content swap, no stacked glyphs.
        final shift = (textHeight - window).clamp(0.0, double.infinity);
        return SizedBox(
          width: width,
          height: height,
          child: ClipRect(
            child: AnimatedContainer(
              duration: AppMotion.of(context, AppMotion.quick),
              // Constant-speed rise: retarget on every line change — an easing curve would restart its ramp at each line's beginning and settle again at each end,
              // which stitched together looks like a stutter.
              curve: Curves.linear,
              transform: Matrix4.translationValues(0, -shift, 0),
              child: OverflowBox(
                alignment: AlignmentDirectional.topStart,
                minHeight: 0,
                maxHeight: double.infinity,
                child: SizedBox(
                  width: width,
                  child: Text(shown, style: style),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The text shown in the live window: bold markers removed, blank runs compressed, leading and trailing whitespace trimmed.
///
/// Keep only the last paragraph: earlier characters sit outside the window and needn't take part in layout (however long thinking runs, every frame stays fast).
String thinkingTickerText(String text) {
  var tail = text.trimRight();
  if (tail.length > _tickerChars) tail = tail.substring(tail.length - _tickerChars);
  return tail.replaceAll('**', '').replaceAll(_blankRun, '\n').trimLeft();
}

/// At most this many characters from the tail are laid out.
const _tickerChars = 2000;

/// The fluid window's text. [thinkingTickerText] drops a character off the front for
/// every new one, and past [_tickerChars] that rewraps everything on every update. Here
/// the cut stands still for [_fluidCutStep] characters, and lands on a line break when
/// there is one, so the last lines keep their wrapping.
@visibleForTesting
String fluidTickerText(String text) {
  var tail = text.trimRight();
  if (tail.length > _tickerChars) {
    var cut = ((tail.length - _tickerChars) ~/ _fluidCutStep + 1) * _fluidCutStep;
    cut = math.min(cut, tail.length);
    final breakAt = tail.indexOf('\n', cut);
    if (breakAt >= 0 && breakAt - cut < _fluidCutStep) cut = breakAt + 1;
    tail = tail.substring(cut);
  }
  return tail.replaceAll('**', '').replaceAll(_blankRun, '\n').trimLeft();
}

const _fluidCutStep = 600;

/// [ThinkingTicker] on the fluid tier: the same three-line window, in continuous
/// motion. What made the plain one stutter: text arrives in lumps, each new line starts
/// its own 160ms move and then stops dead, and a long thought rewraps on every update.
///
/// Here the text is paced ([StreamPacer]), and the window holds the text by its bottom
/// edge: a new line only adds to how far the text still has to rise, and that distance
/// is worked off at a speed matched to how fast lines are coming. Between updates only
/// a transform changes; the text isn't laid out again. Lines leave through a soft edge.
class _FluidTicker extends StatefulWidget {
  const _FluidTicker({required this.text});

  final String text;

  @override
  State<_FluidTicker> createState() => _FluidTickerState();
}

class _FluidTickerState extends State<_FluidTicker> with SingleTickerProviderStateMixin {
  /// Text to show at most this often; the motion in between runs every frame.
  static const _publishEvery = 1 / 30;
  static const _minSettle = 0.09;
  static const _maxSettle = 0.45;

  late final Ticker _ticker = createTicker(_tick);
  // Not lazily: made at the first growth, it would take that growth as already shown.
  late final StreamPacer _pacer;

  /// How far the text still has to rise. Only ever a transform.
  final _behind = ValueNotifier(0.0);
  late String _shown = fluidTickerText(widget.text);

  Duration _last = Duration.zero;
  double _sincePublish = 0;
  double _height = -1;
  double _width = -1;
  double _lineHeight = -1;
  double _sinceLine = 1;

  /// How long the last lines took to come: what the rise is paced by.
  double _settle = 0.2;

  @override
  void initState() {
    super.initState();
    _pacer = StreamPacer(shown: widget.text.length);
  }

  @override
  void didUpdateWidget(_FluidTicker old) {
    super.didUpdateWidget(old);
    if (!widget.text.startsWith(old.text)) {
      _pacer.reset(widget.text.length);
      _shown = fluidTickerText(widget.text);
      // Different text, not more of it: nothing to rise.
      _height = -1;
    }
    if (!_ticker.isActive) {
      _last = Duration.zero;
      unawaited(_ticker.start());
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _behind.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    final seconds = (elapsed - _last).inMicroseconds / Duration.microsecondsPerSecond;
    _last = elapsed;
    _sinceLine += seconds;
    _pacer.advance(seconds, widget.text.length);
    _sincePublish += seconds;
    final behind = _behind.value;
    if (behind > 0.1) {
      _behind.value = behind * math.exp(-seconds / _settle);
    } else if (behind != 0) {
      _behind.value = 0;
    }
    // The last of it goes out at once: the ticker is about to stop.
    if (_sincePublish >= _publishEvery || _pacer.caughtUp(widget.text.length)) {
      _sincePublish = 0;
      final next = fluidTickerText(widget.text.substring(0, _pacer.shown));
      if (next != _shown) setState(() => _shown = next);
    }
    if (_pacer.caughtUp(widget.text.length) && _behind.value == 0) _ticker.stop();
  }

  /// Text height at [width], with what growing by a line means for the motion.
  double _measure(TextStyle? style, TextScaler scaler, double width, double lineHeight, double window, String text) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: scaler,
    )..layout(maxWidth: width);
    final height = painter.height;
    painter.dispose();
    // Only what goes past the window has to rise: below that the text grows into the
    // space it has, and any distance saved up would jump when the window fills.
    final past = math.max(_height, window);
    // A wider line or larger type grows the text too, but that isn't a new line.
    if (_width == width && _lineHeight == lineHeight && _height >= 0 && height > past) {
      final added = height - past;
      if (added < lineHeight * 3) {
        _settle = (0.5 * _settle + 0.5 * _sinceLine * 0.5).clamp(_minSettle, _maxSettle);
        _sinceLine = 0;
      }
      // Set during build for the transform below it: nothing has painted yet. A big lump
      // rises too, from no further down than the window is tall.
      _behind.value = math.min(_behind.value + added, window);
    }
    _height = height;
    _width = width;
    _lineHeight = lineHeight;
    return height;
  }

  @override
  Widget build(BuildContext context) {
    final style = StreamRow.detail(context);
    final scaler = MediaQuery.textScalerOf(context);
    final lineHeight = scaler.scale(style?.fontSize ?? 13) * (style?.height ?? 1.3);
    final window = lineHeight * ThinkingTicker.rows;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = _measure(style, scaler, width, lineHeight, window, _shown);
        final overflows = height > window;
        final text = OverflowBox(
          // Short of a full window it starts at the top; past that, by the bottom edge.
          alignment: overflows ? AlignmentDirectional.bottomStart : AlignmentDirectional.topStart,
          minHeight: 0,
          maxHeight: double.infinity,
          child: SizedBox(
            width: width,
            child: Text(_shown, style: style),
          ),
        );
        return SizedBox(
          width: width,
          height: window,
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (rect) {
              final soft = overflows ? (lineHeight * 0.7 / rect.height).clamp(0.0, 0.5) : 0.0;
              return LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: const [Color(0x00000000), Color(0xFF000000)],
                stops: [0, soft == 0 ? 0.001 : soft],
              ).createShader(rect);
            },
            child: ClipRect(
              child: ValueListenableBuilder<double>(
                valueListenable: _behind,
                child: text,
                // Under a full window the text is just growing downward: nothing to rise.
                builder: (context, behind, child) =>
                    Transform.translate(offset: Offset(0, overflows ? behind : 0), child: child),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Several consecutive blank lines collapse into one.
final _blankRun = RegExp(r'\n[ \t]*(\n[ \t]*)+');

/// Golden and geometry tests pump the pill without a ProviderScope; there is
/// no engine to ask then, so the plain text shows.
bool _hasProviderScope(BuildContext context) {
  try {
    ProviderScope.containerOf(context, listen: false);
    return true;
  } on StateError {
    return false;
  }
}

/// The translation state of one thinking stretch, kept on [_ThinkingPillState] (collapsing tears down the expanded
/// subtree; the translation must not vanish with it).
class _TranslationHolder {
  ReasoningTranslation? controller;

  /// The UI language when [controller] started translating; once the UI language changes, the old translation stops being reused.
  String? language;

  /// Currently viewing the translation (false = the user switched back to the original).
  bool showTranslation = false;

  void reset() {
    controller?.dispose();
    controller = null;
    showTranslation = false;
  }

  void dispose() => controller?.dispose();
}

/// The expanded full text + translation toolbar. When the plugin is off, the current model's thinking is already in Chinese, or
/// the engine isn't connected, there's only the full text.
class _TranslatableReasoning extends ConsumerStatefulWidget {
  const _TranslatableReasoning({
    required this.text,
    required this.active,
    required this.holder,
    required this.onBodyTap,
  });

  final String text;
  final bool active;
  final _TranslationHolder holder;

  /// Tap the body to collapse (equivalent to tapping the header); toolbar buttons aren't affected by this gesture layer.
  final VoidCallback onBodyTap;

  @override
  ConsumerState<_TranslatableReasoning> createState() => _TranslatableReasoningState();
}

class _TranslatableReasoningState extends ConsumerState<_TranslatableReasoning> {
  ReasoningTranslation? _listening;

  @override
  void initState() {
    super.initState();
    _listen(widget.holder.controller);
  }

  @override
  void didUpdateWidget(_TranslatableReasoning old) {
    super.didUpdateWidget(old);
    _listen(widget.holder.controller);
    if (old.text != widget.text || old.active != widget.active) {
      widget.holder.controller?.update(widget.text, running: widget.active);
    }
  }

  @override
  void dispose() {
    _listening?.removeListener(_changed);
    super.dispose();
  }

  void _listen(ReasoningTranslation? controller) {
    if (identical(controller, _listening)) return;
    _listening?.removeListener(_changed);
    _listening = controller?..addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _start(CotTranslationLimits limits, ReasoningTranslator translator) {
    final holder = widget.holder;
    final sessionId = ref.read(currentSessionProvider);
    holder.language = reasoningUiLanguage;
    final controller = holder.controller ??= ReasoningTranslation(
      maxTextChars: limits.maxTextChars,
      translate: (text) => translator(text, limits: limits, sessionId: sessionId),
    );
    _listen(controller);
    setState(() => holder.showTranslation = true);
    controller.update(widget.text, running: widget.active);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final holder = widget.holder;
    if (holder.controller != null && holder.language != reasoningUiLanguage) holder.reset();
    final controller = holder.controller;
    final limits = ref.watch(cotTranslationProvider).value;
    final translator = ref.watch(reasoningTranslatorProvider);
    final offered =
        limits != null &&
        translator != null &&
        reasoningNeedsTranslation(widget.text, limits.targetFor(reasoningUiLanguage));
    final failed = controller?.failed ?? false;
    final showing = holder.showTranslation && controller != null && !failed;
    final body = _CollapsibleReasoningBody(
      onCollapse: widget.onBodyTap,
      child: MarkdownBody(
        text: showing ? controller.text.trim() : widget.text,
        streaming: widget.active,
        secondary: true,
        // The SelectionArea is wrapped outside the collapse gesture by _CollapsibleReasoningBody, so single taps can collapse.
        selectable: false,
      ),
    );
    if (controller == null && !offered) return body;

    final tools = <Widget>[
      if (controller == null)
        _TranslateChip(icon: AppIcons.translate, label: l10n.chatTranslate, onTap: () => _start(limits!, translator!))
      else if (failed) ...[
        Text(
          l10n.chatTranslationUnavailable,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(color: DshColors.of(context).textTertiary),
        ),
        const SizedBox(width: 8),
        _TranslateChip(icon: AppIcons.retry, label: l10n.commonRetry, onTap: controller.retry),
      ] else
        _TranslateChip(
          icon: AppIcons.translate,
          label: showing ? l10n.chatViewOriginal : l10n.chatViewTranslation,
          onTap: () => setState(() => holder.showTranslation = !holder.showTranslation),
        ),
      if (controller != null && controller.pending && !failed) ...[
        const SizedBox(width: 10),
        Semantics(
          label: l10n.chatTranslating,
          child: SizedBox.square(
            dimension: 12,
            child: CircularProgressIndicator(strokeWidth: 1.6, color: DshColors.of(context).textTertiary),
          ),
        ),
      ],
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(mainAxisSize: MainAxisSize.min, children: tools),
        ),
        body,
      ],
    );
  }
}

/// The mini pill on the toolbar: equal 10 insets both sides, icon 14, text 12.5.
class _TranslateChip extends StatelessWidget {
  const _TranslateChip({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Held down: Translation settings (target language, translation service).
  void _settings(BuildContext context) => unawaited(openSettingsPage(context, 'cot-translation'));

  static const height = 26.0;
  static const padding = 10.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final fg = theme.colorScheme.onSurfaceVariant;
    return Pressable(
      onTap: onTap,
      onLongPress: () => _settings(context),
      semanticLabel: label,
      child: Container(
        constraints: const BoxConstraints(minHeight: height),
        padding: const EdgeInsets.symmetric(horizontal: padding),
        decoration: ShapeDecoration(
          color: dark ? Colors.white.withValues(alpha: 0.08) : theme.colorScheme.onSurface.withValues(alpha: 0.06),
          shape: const StadiumBorder(),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
            Text(label, style: theme.textTheme.labelMedium?.copyWith(fontSize: 12.5, height: 1.2, color: fg)),
          ],
        ),
      ),
    );
  }
}
