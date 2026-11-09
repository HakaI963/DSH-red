import 'package:flutter/widgets.dart';

/// Animation clock that absorbs frame stalls.
///
/// Animations run on the wall clock: one frame stalled for 150ms (a new page's first layout, shader compilation) makes
/// the next jump to mid-flight, swallowing the opening — it reads as a hitch. This clock advances at most [maxStep] per
/// frame: after a stall the animation resumes where it froze, arriving late but never jumping.
///
/// Applies to every animation in the app at almost no cost. Sustained rates under 30 FPS slow animations down instead of
/// skipping ahead. [maxStep] is an absolute duration, not tied to the refresh rate: 60 FPS on a 120Hz screen is not slowed.
///
/// Only changes the time animations see: `Timer`, `DateTime` and pointer event timestamps are unaffected.
class FrameClock {
  FrameClock({this.maxStep = const Duration(milliseconds: 34)});

  /// The one used by [SteadyFrameBinding]; `lib/app.dart` sets [enabled] from the fluid-motion switch.
  static final instance = FrameClock();

  final Duration maxStep;

  /// When off, no new jump amount accumulates; already-skipped time keeps being subtracted, so it never snaps back or forward.
  bool enabled = false;

  Duration? _last;
  Duration _skipped = Duration.zero;

  /// Turns a frame's raw timestamp into the timestamp animations see.
  Duration adjust(Duration raw) {
    final last = _last;
    _last = raw;
    if (enabled && last != null) {
      final step = raw - last;
      if (step > maxStep) _skipped += step - maxStep;
    }
    return raw - _skipped;
  }

  @visibleForTesting
  void reset() {
    _last = null;
    _skipped = Duration.zero;
    enabled = false;
  }
}

/// Plugs [FrameClock] into frame scheduling. Must be created before any other binding, and only once.
class SteadyFrameBinding extends WidgetsFlutterBinding {
  @override
  void handleBeginFrame(Duration? rawTimeStamp) {
    super.handleBeginFrame(rawTimeStamp == null ? null : FrameClock.instance.adjust(rawTimeStamp));
  }
}
