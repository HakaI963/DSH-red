// Portions derived from PiPilot (https://github.com/CikeSeven/pi_pilot), MIT, Copyright (c) 2026 CikeSeven. See THIRD_PARTY_NOTICES.md.
// Local changes: chrome-tier glass with a 28 radius; a solid primary send
// key; model picking lives in the header chip; one send action, since DSH
// queues prompts sent mid-turn.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../l10n/l10n.dart';
import '../common/expand_reveal.dart';
import '../common/smooth_size.dart';
import '../pets/pet_perch.dart';
import '../settings/voice_settings_page.dart';
import '../theme/app_icons.dart';
import '../theme/theme.dart';
import 'voice/voice_controller.dart';
import 'voice/voice_widgets.dart';

/// The editor's line height, as a multiple of its font size.
const _lineHeight = 1.45;

/// The input bar: chrome glass + 28 radius, auto-grows from 1 to 6 lines, send / stop at the bottom right.
///
/// The two 36 round keys are the pill's "end caps": [_keyGap] all around, single line = 48 tall,
/// radius 28 = key radius 20 + 8, so round keys share the pill's end centers; text sits centred in 40.
/// With multiple lines the keys stick to the bottom; edges stay 8 at bottom and sides.
///
/// Voice ([voice]): with an empty draft the send key is a microphone (a tinted round like the + key);
/// while dictating, + becomes ✕ (cancel), the send key becomes a tinted stop key, the recognition
/// result shows where the text is, and a volume meter sits left of stop. All four keys keep the same position and size.
class Composer extends StatefulWidget {
  const Composer({
    super.key,
    this.footer,
    this.keyboardInset = 0,
    required this.controller,
    required this.connected,
    required this.running,
    required this.onSend,
    required this.onStop,
    this.focusNode,
    this.busy = false,
    this.stopping = false,
    this.sessionReady = true,
    this.accessory,
    this.leading,
    this.tray,
    this.hasAttachments = false,
    this.onSendOptions,
    this.voice,
    this.onKeyEvent,
    this.placeholder,
    this.waiting = false,
    this.waitHint,
    this.onContentInserted,
    this.maxLines = 6,
    this.hardwareEnterSends = false,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;

  /// DSH is connected. While disconnected you can still type, but not send.
  final bool connected;

  /// A turn is generating: with empty input the send key becomes the stop key.
  final bool running;

  /// Creating the session / submitting: blocks rapid re-taps.
  final bool busy;

  /// Stop was asked for: the stop key turns busy until the turn ends.
  final bool stopping;

  /// Ordinary send/stop controls require an applied session snapshot.
  final bool sessionReady;
  final VoidCallback onSend;
  final VoidCallback onStop;

  /// The small piece left of the send key (the context ring), 40dp tall, bottom-aligned.
  final Widget? accessory;

  /// The 40dp piece left of the input field (+ attachments).
  final Widget? leading;

  /// The strip above the input field (quote, attachments pending send): expands when present, collapses when removed.
  final Widget? tray;

  /// With attachments you can send even without text.
  final bool hasAttachments;

  /// Long-press the send key: mid-generation choose interject / stop and handle first / queue.
  final VoidCallback? onSendOptions;

  /// Voice input; no microphone when null or unavailable.
  final VoiceInputController? voice;

  /// Hardware keys in the text field first go here (the `@` picker's
  /// arrows / Enter / Esc).
  final FocusOnKeyEventCallback? onKeyEvent;

  /// The idle hint ("Message Chief…" in a Bot chat); "Message DSH…"
  /// by default.
  final String? placeholder;

  /// An approval or a question is waiting: the stop key steps back (the
  /// card's button is the one primary key) and the hint stops saying the
  /// turn is generating.
  final bool waiting;

  /// What the placeholder says while [waiting] ("Waiting for your answer"); null keeps the
  /// plain one.
  final String? waitHint;

  /// Images from the keyboard (screenshots, stickers); null takes none.
  final ValueChanged<KeyboardInsertedContent>? onContentInserted;

  /// Visible editor lines. Multiline text remains scrollable when limited.
  final int maxLines;

  /// Opt-in physical Enter-to-send; never changes the software IME action.
  final bool hardwareEnterSends;

  /// Shown beside the keys while the field is being typed in: the capsule opens into a
  /// rounded rectangle, the text on a line of its own and the keys and this in a row
  /// below. It closes again when the keyboard goes. Null: the capsule stays as it is.
  final Widget? footer;

  /// The keyboard's height, from a page that still knows it: how [footer] tells the
  /// keyboard going down from the field losing focus.
  final double keyboardInset;

  /// Editor lines for a page whose [pageContext] still carries the keyboard
  /// inset: six, or as many as fit in two fifths of the height above the
  /// keyboard at the current text size, never under two (two keep newlines
  /// and the field's own scrolling). A phone on its side with the keyboard
  /// up, or very large text, would otherwise push the chat to nothing; an
  /// upright phone under a tall keyboard keeps six up to about 1.2× text.
  static int linesFor(BuildContext pageContext) {
    final available = MediaQuery.sizeOf(pageContext).height - MediaQuery.viewInsetsOf(pageContext).bottom;
    final line = MediaQuery.textScalerOf(pageContext).scale(_fontSize) * _lineHeight;
    if (line <= 0 || available <= 0) return 2;
    return (available * 0.4 / line).floor().clamp(2, 6);
  }

  @override
  State<Composer> createState() => _ComposerState();
}

const double _keySize = 36;
const double _keyGap = 6;

/// The composer's own text, a step under body text.
const double _fontSize = 15.0;

class _ComposerState extends State<Composer> with SingleTickerProviderStateMixin {
  Duration? _lastEscape;

  // One value for everything that moves when the composer opens: the corners, the text's
  // width, the height, the keys and the footer's fade. One motion, not several in step.
  late final AnimationController _openController = AnimationController(vsync: this, duration: AppMotion.collapse);
  late final Animation<double> _open = CurvedAnimation(parent: _openController, curve: AppMotion.collapseCurve);

  /// The keyboard went down with the field still focused.
  bool _keyboardDown = false;
  double _keyboardPeak = 0;

  void _syncOpen() {
    if (!mounted || widget.footer == null) return;
    // A page or sheet over it (the model sheet) takes the focus and the keyboard for a
    // moment: they come back with it, and the composer waits as it is.
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    final open = (widget.focusNode?.hasFocus ?? false) && !_keyboardDown;
    _openController.duration = AppMotion.of(context, AppMotion.collapse);
    if (open && _openController.status != AnimationStatus.forward && !_openController.isCompleted) {
      unawaited(_openController.forward());
    } else if (!open && _openController.status != AnimationStatus.reverse && !_openController.isDismissed) {
      unawaited(_openController.reverse());
    }
  }

  void _focusChanged() {
    if (widget.focusNode?.hasFocus ?? false) _keyboardDown = false;
    _syncOpen();
  }

  void _keyboardMoved(double before) {
    final inset = widget.keyboardInset;
    if (inset == before || !(ModalRoute.of(context)?.isCurrent ?? true)) return;
    if (inset > before) {
      _keyboardDown = false;
      if (inset > _keyboardPeak) _keyboardPeak = inset;
    } else if (inset < _keyboardPeak * 0.5) {
      // Most of the way down, so not the keyboard just changing height.
      _keyboardDown = true;
      _keyboardPeak = 0;
    }
    _syncOpen();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncOpen());
  }

  /// The last tray shown: it stays while the tray folds away.
  late Widget? _tray = widget.tray;

  void _send() {
    if (!widget.connected || !widget.sessionReady || widget.busy) return;
    HapticFeedback.lightImpact();
    widget.onSend();
  }

  void _stop() {
    if (!widget.connected || !widget.sessionReady || widget.busy || widget.stopping) return;
    HapticFeedback.mediumImpact();
    widget.onStop();
  }

  /// Hardware keyboards: Ctrl/⌘+Enter sends; optionally plain Enter does too.
  /// Shift+Enter remains a new line. IME composition never sends.
  /// Two consecutive Esc presses within 500 ms stop the turn. The pair is
  /// local to the focused, eligible editor; a single Esc never leaves it.
  KeyEventResult _hardwareKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final composing = widget.controller.value.composing;
    if (composing.isValid && !composing.isCollapsed) {
      _lastEscape = null;
      return KeyEventResult.ignored;
    }
    final keys = HardwareKeyboard.instance;
    final key = event.logicalKey;
    if (key != LogicalKeyboardKey.escape) _lastEscape = null;
    final sendEnter =
        keys.isControlPressed ||
        keys.isMetaPressed ||
        (widget.hardwareEnterSends && !keys.isShiftPressed && !keys.isAltPressed);
    if (sendEnter && (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter)) {
      if (event is KeyRepeatEvent) return KeyEventResult.handled;
      final draft = widget.controller.text.trim().isNotEmpty || widget.hasAttachments;
      final dictating = widget.voice?.active ?? false;
      if (draft && widget.connected && !widget.busy && !dictating) _send();
      return KeyEventResult.handled;
    }
    if (event is KeyRepeatEvent) return KeyEventResult.ignored;
    if (key != LogicalKeyboardKey.escape || !widget.running) {
      _lastEscape = null;
      return KeyEventResult.ignored;
    }
    if (!widget.sessionReady || !widget.connected || widget.busy || widget.stopping) {
      _lastEscape = null;
      return KeyEventResult.handled;
    }
    final last = _lastEscape;
    _lastEscape = event.timeStamp;
    if (last != null && event.timeStamp - last <= const Duration(milliseconds: 500)) {
      _lastEscape = null;
      _stop();
    }
    return KeyEventResult.handled;
  }

  @override
  void initState() {
    super.initState();
    widget.voice?.onMessage = _voiceMessage;
    widget.focusNode?.addListener(_focusChanged);
  }

  @override
  void didUpdateWidget(Composer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessionReady != widget.sessionReady ||
        oldWidget.connected != widget.connected ||
        oldWidget.running != widget.running ||
        oldWidget.controller != widget.controller ||
        oldWidget.focusNode != widget.focusNode ||
        oldWidget.busy != widget.busy ||
        oldWidget.stopping != widget.stopping) {
      _lastEscape = null;
    }
    _tray = widget.tray ?? _tray;
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode?.removeListener(_focusChanged);
      widget.focusNode?.addListener(_focusChanged);
    }
    if (oldWidget.keyboardInset != widget.keyboardInset) _keyboardMoved(oldWidget.keyboardInset);
    if ((oldWidget.footer == null) != (widget.footer == null)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncOpen());
    }
    if (oldWidget.voice != widget.voice) {
      if (oldWidget.voice?.onMessage == _voiceMessage) {
        oldWidget.voice?.onMessage = null;
      }
      widget.voice?.onMessage = _voiceMessage;
    }
  }

  @override
  void dispose() {
    widget.focusNode?.removeListener(_focusChanged);
    _openController.dispose();
    if (widget.voice?.onMessage == _voiceMessage) {
      widget.voice?.onMessage = null;
    }
    super.dispose();
  }

  void _voiceMessage(VoiceMessage message) {
    if (!mounted) return;
    final voice = widget.voice;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message.text),
          persist: false,
          action: message.openSettings && voice != null
              ? SnackBarAction(label: appL10n.chatGoToSettings, onPressed: () => voice.bridge.openSettings())
              : message.change
              ? SnackBarAction(
                  label: appL10n.nearbyChange,
                  onPressed: () =>
                      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const VoiceSettingsPage())),
                )
              : null,
        ),
      );
  }

  void _startVoice() {
    final voice = widget.voice;
    if (voice == null) return;
    // Dictation shows the text in the field; the keyboard only covers it.
    (widget.focusNode ?? FocusManager.instance.primaryFocus)?.unfocus();
    voice.start();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final dsh = DshColors.of(context);
    final textStyle = theme.textTheme.bodyLarge?.copyWith(fontSize: _fontSize, height: _lineHeight);
    // One line centred in the keys' 40: the padding that makes it so, at
    // the current text size (very large text just grows the row).
    final line = MediaQuery.textScalerOf(context).scale(_fontSize) * _lineHeight;
    final textPad = math.max(4.0, (_keySize - line) / 2);
    final voice = widget.voice;
    voice?.ensureFresh();

    // The chat page's pet stands on the composer's top edge (outside a pet
    // stage this is a plain pass-through).
    return PetPerch(
      kind: PerchKind.composer,
      child: _ComposerGlass(
        open: widget.footer == null ? null : _open,
        child: ListenableBuilder(
          listenable: Listenable.merge([widget.controller, ?voice]),
          builder: (context, _) {
            final value = widget.controller.value;
            final phase = voice?.phase ?? VoicePhase.idle;
            final dictating = phase == VoicePhase.listening || phase == VoicePhase.transcribing;
            final empty = value.text.trim().isEmpty && !widget.hasAttachments;
            final showStop = widget.running && empty && !dictating;
            final showMic = !dictating && !showStop && empty && !widget.busy && (voice?.available ?? false);
            final enabled = !widget.busy && widget.connected && widget.sessionReady && (showStop || !empty);
            final waiting = widget.waiting || widget.waitHint != null;
            final hint = switch (phase) {
              VoicePhase.listening => l10n.chatListeningEllipsis,
              VoicePhase.transcribing => l10n.chatTranscribingEllipsis,
              _ =>
                !widget.connected
                    ? l10n.chatConnectToSend
                    : !widget.sessionReady
                    ? l10n.stateChatSynchronizing
                    : widget.waitHint ??
                          (widget.running && !waiting
                              ? l10n.chatGeneratingSteerHint
                              : widget.placeholder ?? l10n.chatComposerHint),
            };
            final leading = dictating
                ? VoiceCancelKey(key: const ValueKey('voice-cancel'), onPressed: voice!.cancel)
                : widget.leading;
            final accessory = dictating
                ? VoiceWaveform(level: voice!.level, active: phase == VoicePhase.listening)
                : widget.accessory;

            final _KeyMode mode;
            if (dictating) {
              mode = _KeyMode.stopVoice;
            } else if (showStop) {
              mode = _KeyMode.stopRun;
            } else if (showMic) {
              mode = _KeyMode.mic;
            } else {
              mode = _KeyMode.send;
            }
            final keyBusy =
                widget.busy ||
                (showStop && widget.stopping) ||
                phase == VoicePhase.transcribing ||
                phase == VoicePhase.starting;

            final leadingKey = leading == null
                ? null
                : AnimatedSwitcher(
                    duration: AppMotion.of(context, AppMotion.quick),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: ScaleTransition(scale: anim, child: child),
                    ),
                    child: KeyedSubtree(key: ValueKey(dictating), child: leading),
                  );
            final field = Focus(
              canRequestFocus: false,
              skipTraversal: true,
              onKeyEvent: _hardwareKey,
              onFocusChange: (hasFocus) {
                if (!hasFocus) _lastEscape = null;
              },
              child: Focus(
                canRequestFocus: false,
                skipTraversal: true,
                onKeyEvent: widget.onKeyEvent,
                child: TextField(
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  contentInsertionConfiguration: switch (widget.onContentInserted) {
                    final onInserted? => ContentInsertionConfiguration(
                      onContentInserted: onInserted,
                      allowedMimeTypes: const ['image/png', 'image/jpeg', 'image/gif', 'image/webp'],
                    ),
                    null => null,
                  },
                  readOnly: dictating || phase == VoicePhase.starting,
                  minLines: 1,
                  maxLines: widget.maxLines,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  textCapitalization: TextCapitalization.sentences,
                  style: textStyle,
                  cursorColor: theme.colorScheme.primary,
                  decoration: InputDecoration(
                    hintText: hint,
                    hintMaxLines: 1,
                    hintStyle: theme.textTheme.bodyLarge?.copyWith(
                      fontSize: _fontSize,
                      color: dsh.textTertiary,
                      height: 1.45,
                    ),
                    filled: false,
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: textPad),
                  ),
                ),
              ),
            );
            final sendKey = _SendButton(
              mode: mode,
              busy: keyBusy,
              quiet: showStop && waiting && !widget.stopping,
              enabled: switch (mode) {
                _KeyMode.mic => true,
                _KeyMode.stopVoice => phase == VoicePhase.listening,
                _ => enabled,
              },
              onLongPress: mode != _KeyMode.send || !enabled ? null : widget.onSendOptions,
              onTap: () {
                switch (mode) {
                  case _KeyMode.stopRun:
                    _stop();
                  case _KeyMode.send:
                    _send();
                  case _KeyMode.mic:
                    _startVoice();
                  case _KeyMode.stopVoice:
                    voice?.stop();
                }
              },
            );
            final footer = widget.footer;
            final row = footer == null
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (leadingKey != null) ...[leadingKey, const SizedBox(width: 8)],
                      Expanded(child: field),
                      const SizedBox(width: 8),
                      if (accessory != null) ...[accessory, const SizedBox(width: 2)],
                      sendKey,
                    ],
                  )
                : _ComposerRows(
                    open: _open,
                    // A new line grows the glass here: opening is its own motion, with no
                    // second one chasing it.
                    text: SmoothSize(
                      duration: AppMotion.of(context, AppMotion.quick),
                      curve: AppMotion.std,
                      alignment: Alignment.bottomCenter,
                      child: field,
                    ),
                    leading: leadingKey ?? const SizedBox.shrink(),
                    footer: FadeTransition(opacity: _open, child: footer),
                    // Exactly a key tall, whatever sits beside the key: the row's height is
                    // what keeps the gaps around it even.
                    trailing: SizedBox(
                      height: _keySize,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (accessory != null) ...[accessory, const SizedBox(width: _keyGap)],
                          sendKey,
                        ],
                      ),
                    ),
                  );
            // The tray unfolds above the text and folds away again: the
            // glass grows and shrinks, the text row never jumps.
            final content = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ExpandReveal(
                  open: widget.tray != null,
                  child: Padding(padding: const EdgeInsets.fromLTRB(_keyGap, 2, _keyGap, _keyGap), child: _tray),
                ),
                // A new line grows the glass instead of popping it: anchored
                // at the bottom, where the caret and the keys stay put.
                if (footer != null)
                  row
                else
                  SmoothSize(
                    duration: AppMotion.of(context, AppMotion.quick),
                    curve: AppMotion.std,
                    alignment: Alignment.bottomCenter,
                    child: row,
                  ),
              ],
            );
            // Dictating: the pet steps away from the voice controls.
            return PetCover(
              active: dictating,
              child: Padding(
                padding: EdgeInsets.fromLTRB(leading == null ? 18 : _keyGap, _keyGap, _keyGap, _keyGap),
                child: content,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The composer's glass. With [open], its corners tighten as the composer opens, from
/// the capsule into a rounded rectangle.
class _ComposerGlass extends StatelessWidget {
  const _ComposerGlass({required this.open, required this.child});

  final Animation<double>? open;
  final Widget child;

  static const _opened = BorderRadius.all(Radius.circular(AppShape.lg));

  @override
  Widget build(BuildContext context) {
    final open = this.open;
    if (open == null) return GlassSurface(tier: GlassTier.chrome, borderRadius: AppShape.radiusXl, child: child);
    return AnimatedBuilder(
      animation: open,
      builder: (context, child) => GlassSurface(
        tier: GlassTier.chrome,
        borderRadius: BorderRadius.lerp(AppShape.radiusXl, _opened, open.value),
        child: child,
      ),
      child: child,
    );
  }
}

/// A phone's composer, between one row and two, as [open] goes from 0 to 1:
///
/// ```
/// (+) text…          (key)      →      text…
///                                      (+) (footer)      (key)
/// ```
///
/// It lays out rather than rebuilds on every step, and the keys travel with the bottom
/// edge, so they slide down as the text takes the width.
class _ComposerRows extends MultiChildRenderObjectWidget {
  _ComposerRows({
    required this.open,
    required Widget text,
    required Widget leading,
    required Widget footer,
    required Widget trailing,
  }) : super(children: [text, leading, footer, trailing]);

  final Animation<double> open;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderComposerRows(open);

  @override
  void updateRenderObject(BuildContext context, _RenderComposerRows renderObject) => renderObject.open = open;
}

class _ComposerRowsParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderComposerRows extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _ComposerRowsParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _ComposerRowsParentData> {
  _RenderComposerRows(this._open);

  /// Beside the text, on one row.
  static const _gap = 8.0;

  /// Between the pieces of the second row: what the glass leaves around them.
  static const _rowGap = _keyGap;

  /// The text's own inset once it has the line to itself.
  static const _inset = 8.0;

  /// Between the text and the row under it.
  static const _rows = 2.0;

  Animation<double> _open;
  set open(Animation<double> value) {
    if (identical(value, _open)) return;
    if (attached) _open.removeListener(markNeedsLayout);
    _open = value;
    if (attached) _open.addListener(markNeedsLayout);
    markNeedsLayout();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _open.addListener(markNeedsLayout);
  }

  @override
  void detach() {
    _open.removeListener(markNeedsLayout);
    super.detach();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _ComposerRowsParentData) child.parentData = _ComposerRowsParentData();
  }

  /// The footer answers and is read out once it is mostly there.
  bool get _footerLive => _open.value > 0.5;

  double _textWidth(double width, double leading, double trailing) {
    final rest = width - (leading > 0 ? leading + _gap : 0) - _gap - trailing;
    return math.max(0.0, ui.lerpDouble(rest, width - 2 * _inset, _open.value)!);
  }

  Size _measure(BoxConstraints constraints, ChildLayouter layoutChild) {
    final [text, leading, footer, trailing] = getChildrenAsList();
    final width = constraints.maxWidth;
    final loose = BoxConstraints(maxWidth: width);
    final lead = layoutChild(leading, loose);
    final trail = layoutChild(trailing, loose);
    final foot = layoutChild(
      footer,
      BoxConstraints(maxWidth: math.max(0.0, width - lead.width - trail.width - 2 * _rowGap)),
    );
    final field = layoutChild(text, BoxConstraints.tightFor(width: _textWidth(width, lead.width, trail.width)));
    final keys = math.max(math.max(lead.height, trail.height), foot.height);
    final height = ui.lerpDouble(math.max(field.height, keys), field.height + _rows + keys, _open.value)!;
    return constraints.constrain(Size(width, height));
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _measure(constraints, ChildLayoutHelper.dryLayoutChild);

  @override
  void performLayout() {
    size = _measure(constraints, ChildLayoutHelper.layoutChild);
    final [text, leading, footer, trailing] = getChildrenAsList();
    final t = _open.value;
    void place(RenderBox child, double x, double y) =>
        (child.parentData! as _ComposerRowsParentData).offset = Offset(x, y);
    final restX = leading.size.width > 0 ? leading.size.width + _gap : 0.0;
    final keys = math.max(math.max(leading.size.height, trailing.size.height), footer.size.height);
    final restTop = math.max(0.0, math.max(text.size.height, keys) - text.size.height);
    place(text, ui.lerpDouble(restX, _inset, t)!, ui.lerpDouble(restTop, 0, t)!);
    // On one centre line, whatever their heights.
    double centred(RenderBox child) => size.height - keys + (keys - child.size.height) / 2;
    place(leading, 0, centred(leading));
    place(footer, leading.size.width + _rowGap, centred(footer));
    place(trailing, size.width - trailing.size.width, centred(trailing));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    for (final child in getChildrenAsList()) {
      if (child == childAfter(childAfter(firstChild!)!) && _open.value == 0) continue;
      context.paintChild(child, (child.parentData! as _ComposerRowsParentData).offset + offset);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final footer = childAfter(childAfter(firstChild!)!);
    for (final child in getChildrenAsList().reversed) {
      if (child == footer && !_footerLive) continue;
      final hit = result.addWithPaintOffset(
        offset: (child.parentData! as _ComposerRowsParentData).offset,
        position: position,
        hitTest: (result, transformed) => child.hitTest(result, position: transformed),
      );
      if (hit) return true;
    }
    return false;
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    final footer = childAfter(childAfter(firstChild!)!);
    for (final child in getChildrenAsList()) {
      if (child != footer || _footerLive) visitor(child);
    }
  }
}

/// What the right-hand key does.
enum _KeyMode {
  /// ↑ send.
  send,

  /// ■ stop the running turn.
  stopRun,

  /// 🎙 start dictating (draft empty).
  mic,

  /// ■ stop dictating and keep the text.
  stopVoice,
}

/// The 40 round key: ↑ send / ■ stop (solid, tinted); 🎙 the mic is a tinted round like the + key.
/// When disabled, a background at onSurface 12%.
class _SendButton extends StatefulWidget {
  const _SendButton({
    required this.mode,
    required this.busy,
    required this.enabled,
    required this.onTap,
    this.onLongPress,
    this.quiet = false,
  });

  final _KeyMode mode;

  /// Drawn like the mic key (something else on screen is primary).
  final bool quiet;
  final bool busy;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final fluid = AppMotion.fluid(context);
    final enabled = widget.enabled && !widget.busy;
    final mode = widget.mode;
    final mic = mode == _KeyMode.mic || widget.quiet;
    final active = enabled || widget.busy;
    final bg = mic
        ? colors.onSurface.withValues(alpha: 0.06)
        : active
        ? colors.primary
        : colors.onSurface.withValues(alpha: 0.12);
    final fg = mic
        ? colors.onSurface
        : active
        ? colors.onPrimary
        : colors.onSurface.withValues(alpha: 0.38);
    final (icon, size, label) = switch (mode) {
      _KeyMode.send => (AppIcons.send, 20.0, l10n.commonSend),
      _KeyMode.stopRun => (AppIcons.stopGenerating, 18.0, l10n.chatStopGenerating),
      _KeyMode.mic => (AppIcons.voice, 20.0, l10n.chatVoiceInput),
      _KeyMode.stopVoice => (AppIcons.stopGenerating, 18.0, l10n.chatStopVoiceInput),
    };
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.busy && mode == _KeyMode.stopRun ? l10n.commonStopping : label,
      child: GestureDetector(
        onTap: enabled ? widget.onTap : null,
        onLongPress: widget.onLongPress == null
            ? null
            : () {
                setState(() => _pressed = false);
                HapticFeedback.mediumImpact();
                widget.onLongPress!();
              },
        onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.9 : 1,
          duration: fluid && !_pressed ? AppMotion.thumbCurve.duration : AppMotion.of(context, AppMotion.press),
          curve: fluid && !_pressed ? AppMotion.thumbCurve : AppMotion.std,
          child: AnimatedContainer(
            duration: AppMotion.of(context, AppMotion.quick),
            width: _keySize,
            height: _keySize,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: AnimatedSwitcher(
              duration: fluid ? AppMotion.standard : AppMotion.of(context, AppMotion.quick),
              switchInCurve: fluid ? Curves.linear : AppMotion.enter,
              switchOutCurve: Curves.linear,
              transitionBuilder: (child, anim) =>
                  fluid ? _FluidKeySwap(animation: anim, child: child) : ScaleTransition(scale: anim, child: child),
              child: widget.busy
                  ? Padding(
                      key: const ValueKey('busy'),
                      padding: const EdgeInsets.all(11),
                      child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                    )
                  : Icon(icon, key: ValueKey(mode), size: size, color: fg),
            ),
          ),
        ),
      ),
    );
  }
}

/// The fluid send key's icon swap: the plane that was sent flies off up and to the
/// right, and what comes next pops in on a spring.
class _FluidKeySwap extends StatelessWidget {
  const _FluidKeySwap({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  static const _flight = 16.0;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: animation,
    child: child,
    builder: (context, child) {
      final v = animation.value.clamp(0.0, 1.0);
      final leaving = animation.status == AnimationStatus.reverse;
      final flies = leaving && this.child.key == const ValueKey(_KeyMode.send);
      final away = flies ? _flight * Curves.easeIn.transform(1 - v) : 0.0;
      final scale = flies
          ? 1.0
          : leaving
          ? 0.4 + 0.6 * v
          : 0.4 + 0.6 * AppMotion.thumbCurve.transform(v);
      return Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(away, -away),
          child: Transform.scale(scale: scale, child: child),
        ),
      );
    },
  );
}
