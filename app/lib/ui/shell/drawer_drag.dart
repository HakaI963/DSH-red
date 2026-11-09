// Ported from PiPilot (https://github.com/CikeSeven/pi_pilot), MIT, Copyright (c) 2026 CikeSeven. See THIRD_PARTY_NOTICES.md.
//
// There is no PageView behind the chat here, so a leftward swipe while the
// drawer is closed is simply rejected and left to whatever else wants it: a
// code block's scroll, or the Quick entries panel's [QuickPanelDragRecognizer].

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// The drawer drag gesture recognizer: **one finger, held by the drawer throughout — swipe right to pull open, left to push back**.
///
/// Why write it instead of using `Scaffold.drawer`'s machinery:
///
/// The gesture arena is decided during the gesture's **start phase**. Watching `PageView`'s
/// leading overscroll and then calling `openDrawer()` is not enough: that only plays a fling animation while
/// this finger was already won by `PageView`'s horizontal drag recognizer — keep sliding without lifting and every pixel feeds `PageView`.
///
/// Mid-gesture repairs fail too: swapping `PageView.physics`, widening `drawerEdgeDragWidth` on the fly,
/// or calling `openDrawer()` afterwards can never hand an **already flying** pointer to another recognizer —
/// widening the drag zone only affects recognizers created after that.
///
/// So the right move is to compete from the start: this recognizer lives **inside** `PageView`'s pages
/// (as their descendant) and decides by direction on its own —
/// - drawer closed: once horizontal travel passes the slop, look at direction. **Left: reject immediately**, handing
///   the gesture to `PageView` for paging; **only right accepts**, starting to pull the drawer open.
/// - drawer open (or this gesture already accepted): the holder owns both directions and `PageView`
///   never gets this finger. So one finger swiping back left glides the progress smoothly from 1 to 0.
/// - Predominantly vertical travel always rejects, ceding to the chat list or the drawer's own list scroll.
///
/// One iron law of timing: **every direction call must wait until travel actually happens**, never
/// declare at the pointer-down instant. In the arena, whoever first `resolve(accepted)` makes
/// every other member receive `rejectGesture` — declaring victory at the down event while the drawer
/// is open would reject the drawer's InkWell TapGestureRecognizer on the spot, breaking taps on
/// conversations; vertical list scrolling inside dies the same way. Scrollable coexists with Tap
/// precisely because drag recognizers patiently wait past the slop, letting Tap win at release.
/// This recognizer keeps the same timing: if the finger never moved before release, declare nothing and the tap passes through whole.
class DrawerDragRecognizer extends OneSequenceGestureRecognizer {
  DrawerDragRecognizer({
    required this.isOpen,
    required this.onStart,
    required this.onDelta,
    required this.onEnd,
    super.debugOwner,
  });

  /// Whether the drawer is currently open (even partially).
  ///
  /// When open, drop the direction filter: the drawer holds both directions, otherwise a left-swipe closing
  /// halfway, then pushed right again, would have its gesture seized by `PageView`.
  final ValueGetter<bool> isOpen;

  final VoidCallback onStart;

  /// Horizontal delta (pixels, positive to the right).
  final ValueChanged<double> onDelta;

  /// Gesture end: carries the horizontal velocity (px/s, positive right) used to settle open or closed.
  final ValueChanged<double> onEnd;

  /// Travel to accumulate before judging horizontal intent.
  ///
  /// **Must be below `kTouchSlop` (18px)**. `PageView`'s horizontal drag recognizer
  /// declares victory at 18px, and whoever speaks first takes the pointer. With `kPanSlop` (36px),
  /// a real finger moving 5–20px per frame is already `PageView`'s at 18px and will never reach
  /// 36px. Tests must step like a real finger: a single 50px step crosses the line on the first move and hides the problem.
  ///
  /// 8px: speaks before `PageView`, yet enough to filter fingertip jitter at touchdown.
  /// Declaring early is safe — there is no page right of the chat, and swiping right only overscrolls anyway.
  static const double _slop = 8.0;

  /// The vertical yield threshold. List scrolling uses the system touch slop, kept slightly looser than the horizontal call
  /// so "want to scroll the list" is never mistaken for opening the drawer.
  static const double _verticalSlop = kTouchSlop;

  /// Which way the finger slides counts as "pull open": the drawer is on the left, so right.
  @protected
  double get openingSign => 1;

  /// While closed: is [distance] of pull-direction travel enough to speak (past [_slop])?
  @protected
  bool opensAfter(double distance, PointerDeviceKind kind) => true;

  /// The velocity [onEnd] receives at gesture end ([PointerUpEvent] or [PointerCancelEvent]).
  @protected
  double endVelocity(PointerEvent event) => _velocity?.getVelocity().pixelsPerSecond.dx ?? 0;

  Offset _accum = Offset.zero;
  bool _accepted = false;
  VelocityTracker? _velocity;

  @override
  String get debugDescription => 'drawer drag';

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _accum = Offset.zero;
    _accepted = false;
    _velocity = VelocityTracker.withKind(event.kind);
    startTrackingPointer(event.pointer, event.transform);
    // Even with the drawer open you **must not** speak here: accepting immediately makes the arena reject
    // the TapGestureRecognizer at the same point, and drawer rows stop responding (see the class docs). Direction
    // is always deferred to the first PointerMoveEvent; taps without travel before release pass through untouched.
  }

  @override
  void handleEvent(PointerEvent event) {
    _velocity?.addPosition(event.timeStamp, event.localPosition);

    if (event is PointerMoveEvent) {
      if (_accepted) {
        onDelta(event.delta.dx);
        return;
      }
      _accum += event.delta;
      // Predominantly vertical: scrolling the chat list (or the drawer's list) — yield.
      if (_accum.dy.abs() > _verticalSlop && _accum.dy.abs() > _accum.dx.abs()) {
        resolve(GestureDisposition.rejected);
        stopTrackingPointer(event.pointer);
        return;
      }
      if (_accum.dx.abs() < _slop) return;
      // Horizontal intent established. With the drawer open both directions are the drawer's (right keeps opening, left pushes back);
      // while closed only right counts — left is paging, give it to PageView.
      final open = isOpen();
      final towards = _accum.dx * openingSign;
      if (open || towards > 0) {
        if (!open && !opensAfter(towards, event.kind)) return;
        _accepted = true;
        onStart();
        resolve(GestureDisposition.accepted);
        // Travel banked during the slop must not be dropped, or the drawer "jumps" before catching the finger.
        onDelta(_accum.dx);
      } else {
        resolve(GestureDisposition.rejected);
        stopTrackingPointer(event.pointer);
      }
      return;
    }

    if (event is PointerUpEvent || event is PointerCancelEvent) {
      if (_accepted) {
        onEnd(endVelocity(event));
      }
      stopTrackingPointer(event.pointer);
      _accepted = false;
    }
  }

  /// The arena declared us the winner (possibly by default after others bowed out).
  ///
  /// **Must not double as "start tracking" here.** With tiny travel or a plain click the horizontal intent
  /// hasn't been judged; PageView also gave up for lack of slop — the arena awards victory
  /// by default to us, the only member left. Starting to track here would fling the drawer open
  /// after a light tap and release.
  ///
  /// So we only act on paths in [handleEvent] that actually judged rightward intent (or the drawer was open);
  /// a passive win does nothing.
  @override
  void acceptGesture(int pointer) {}

  @override
  void rejectGesture(int pointer) {
    stopTrackingPointer(pointer);
    _accepted = false;
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}
}

/// The right quick-entry panel's drag: the drawer mirrored — **pulls open leftward**, pushes back right, one finger
/// held throughout; vertical yielding and "never speak at pointer down" are the same.
///
/// One difference: while closed, a left pull must pass the device's touch slop (strictly greater) before speaking. Horizontal
/// scrolling code blocks, tables, charts and card stacks use the same threshold and the same comparison, and events
/// go to the innermost recognizer first — so whenever such content is under the finger, it wins first: leftward
/// pans stay theirs and must not be stolen by the panel. The recognizer needn't know what's under the finger. Android's
/// slop is ~8dp, the same as the drawer's call distance; [gestureSettings] must come from MediaQuery like `Scrollable`'s,
/// or the two thresholds disagree.
///
/// When the system takes the finger away (edge-back gesture) there is no "flick": look only at how far it pulled, otherwise leftward
/// velocity would fling the panel open.
class QuickPanelDragRecognizer extends DrawerDragRecognizer {
  QuickPanelDragRecognizer({
    required super.isOpen,
    required super.onStart,
    required super.onDelta,
    required super.onEnd,
    super.debugOwner,
  });

  @override
  double get openingSign => -1;

  @override
  bool opensAfter(double distance, PointerDeviceKind kind) => distance > computeHitSlop(kind, gestureSettings);

  @override
  double endVelocity(PointerEvent event) => event is PointerCancelEvent ? 0 : super.endVelocity(event);

  @override
  String get debugDescription => 'quick panel drag';
}
