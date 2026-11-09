// TODO: replace [StreamPress] / [StreamFadeIn] with the shared Pressable /
// FadeSlideIn (`ui/common/`) and delete this file.

import 'package:flutter/widgets.dart';

import '../../theme/motion.dart';

/// Press feedback: scales down to 0.97 while held, back to 1 on release (never overshoots 1).
///
/// Uses the tap recognizer inside the gesture arena (not raw pointers): scrolling in a list won't make it shrink
/// at every finger touch; `InkWell`s and buttons inside sit deeper and keep taps as usual — this layer only follows the scale.
class StreamPress extends StatefulWidget {
  const StreamPress({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  State<StreamPress> createState() => _StreamPressState();
}

class _StreamPressState extends State<StreamPress> {
  bool _down = false;

  void _set(bool down) {
    if (_down != down && mounted) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      // Feedback only: the child owns the tap, also for screen readers.
      excludeFromSemantics: true,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: AppMotion.of(context, _down ? AppMotion.press : AppMotion.quick),
        curve: AppMotion.std,
        child: widget.child,
      ),
    );
  }
}

/// First appearance: fade in + rise 8, height grows 0 to full, played once; [index] staggers each item 30ms
/// later (up to 8 items). With [enabled] false it simply starts in the final state.
///
/// The height grows along too: while bottom-following, the content above shifts up smoothly instead of the whole list
/// jerking up a notch when a new row appears (most visible with cards and whole replies).
///
/// [rise]: a just-sent bubble. On the lively motion tier it springs up from the composer's direction; height keeps its original pacing.
class StreamFadeIn extends StatefulWidget {
  const StreamFadeIn({super.key, required this.child, this.enabled = true, this.index = 0, this.rise = false});

  final Widget child;
  final bool enabled;
  final int index;
  final bool rise;

  @override
  State<StreamFadeIn> createState() => _StreamFadeInState();
}

class _StreamFadeInState extends State<StreamFadeIn> with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  Animation<double>? _t;

  /// The rise progress, which may exceed 1; null when not rising — then the whole tree gains no extra layer.
  Animation<double>? _lift;

  /// The bubble's rise distance, roughly from the composer to the list's bottom.
  static const _riseBy = 36.0;
  static const _riseScale = 0.94;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null || !widget.enabled || AppMotion.reduced(context)) {
      return;
    }
    final delay = Duration(milliseconds: 30 * widget.index.clamp(0, 7));
    final rise = widget.rise && AppMotion.fluid(context);
    final total = delay + (rise ? AppMotion.riseCurve.duration : AppMotion.standard);
    final controller = AnimationController(vsync: this, duration: total);
    _controller = controller;
    final start = delay.inMicroseconds / total.inMicroseconds;
    if (rise) {
      _lift = CurvedAnimation(
        parent: controller,
        curve: Interval(start, 1, curve: AppMotion.riseCurve),
      );
    }
    _t = CurvedAnimation(
      parent: controller,
      curve: Interval(
        start,
        // Height and opacity animate as before; only the rise spring runs its full course.
        rise ? (delay + AppMotion.standard).inMicroseconds / total.inMicroseconds : 1,
        // The same curve as the pill rising / retracting on the input bar: when a new row grows and the pill retracts
        // at once, content moves in one direction only — never pushed up then dropped back.
        curve: AppMotion.std,
      ),
    );
    controller.forward();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    if (t == null) return widget.child;
    return AnimatedBuilder(
      animation: t,
      child: widget.child,
      builder: (context, child) {
        // Same wrappers before and after the end: swapping them for the bare
        // child would rebuild the row and lose its state (an open tool row,
        // a bubble easing out of "Sending"). At rest they paint nothing extra.
        final v = t.value.clamp(0.0, 1.0);
        final lift = _lift?.value;
        return ClipRect(
          // A rising bubble emerges from below and must not be clipped by its own still-growing row.
          clipBehavior: v < 1 && lift == null ? Clip.hardEdge : Clip.none,
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: v,
            // Align loosens the row's full width; give it back, or a narrow
            // row (the user bubble) drifts to the middle.
            child: SizedBox(
              width: double.infinity,
              child: Opacity(
                opacity: v,
                child: lift == null
                    ? Transform.translate(offset: Offset(0, 8 * (1 - v)), child: child)
                    : Transform.translate(
                        offset: Offset(0, _riseBy * (1 - lift)),
                        child: Transform.scale(
                          scale: _riseScale + (1 - _riseScale) * lift,
                          alignment: AlignmentDirectional.bottomEnd,
                          child: child,
                        ),
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}
