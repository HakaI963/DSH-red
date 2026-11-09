// Launch screen motion: one timeline, counted from the moment the system splash hands over to the app.
//
//   0 ms      the icon sits where the system drew it: 160 × 160, screen center
//             (when the system phase drew no icon, it fades in over 0–320 ms, Cubic(.2, 0, 0, 1), settling as it fades)
//   0–640     settle: shrink to 0.8, lift up to free half a line for the wordmark (Cubic(.4, 0, .2, 1): start from rest, long tail deceleration)
//   200–640   wordmark "DSH Go": opacity 0 → 1, rising 10 from below (Cubic(0, 0, .2, 1))
//   560–1360  a thin light sweeps across the icon once, left to right (Cubic(.45, 0, .55, 1))
//   from 1360 at rest, waiting for the UI to be ready
//   UI ready   the whole layer fades out over 300 ms (AppMotion.std); this can come at any time, without waiting for the animation to finish
//
// When the system asks to reduce motion there is only the still icon, and the UI cuts straight in when ready.

import 'package:flutter/animation.dart';

/// Where things are at one moment of the launch timeline.
class LaunchFrame {
  const LaunchFrame({
    required this.icon,
    required this.wordmarkOpacity,
    required this.wordmarkRise,
    required this.sweep,
    this.iconFade = 1,
  });

  /// The icon's square, logical pixels in the screen.
  final Rect icon;

  /// 0 → 1 as the wordmark comes in.
  final double wordmarkOpacity;

  /// How far below its resting place the wordmark is (logical pixels).
  final double wordmarkRise;

  /// The light band's progress across the icon (0 → 1), or null when it isn't on it.
  final double? sweep;

  /// 0 → 1 as the icon comes in, for a launch whose system picture had none.
  final double iconFade;
}

/// The launch lockup: the icon where the system left it, and where it settles above the
/// wordmark.
class LaunchLayout {
  LaunchLayout({required this.cover, this.wordmarkHeight = LaunchMotion.wordmarkSize * LaunchMotion.wordmarkLine});

  /// The icon as the system drew it (logical pixels, in the screen).
  final Rect cover;

  /// The wordmark's line height.
  final double wordmarkHeight;

  /// Icon and wordmark together are centred where the icon was: the icon rises by half of
  /// what the wordmark adds.
  double get rise => (LaunchMotion.wordmarkGap + wordmarkHeight) / 2;

  /// The icon at rest.
  Rect get settled => Rect.fromCenter(
    center: cover.center.translate(0, -rise),
    width: cover.width * LaunchMotion.settledScale,
    height: cover.height * LaunchMotion.settledScale,
  );

  /// Top of the wordmark's line at rest.
  double get wordmarkTop => settled.bottom + LaunchMotion.wordmarkGap;

  /// The lockup at [t] since the launch screen took over.
  LaunchFrame at(Duration t) {
    final ms = t.inMicroseconds / 1000;
    final s = LaunchMotion.settleCurve.transform(_progress(ms, LaunchMotion.settle));
    final w = _progress(ms, LaunchMotion.wordmark);
    final sweep = _progress(ms, LaunchMotion.sweep);
    return LaunchFrame(
      icon: Rect.lerp(cover, settled, s)!,
      wordmarkOpacity: LaunchMotion.wordmarkFade.transform(w),
      wordmarkRise: LaunchMotion.wordmarkRiseBy * (1 - LaunchMotion.wordmarkRiseCurve.transform(w)),
      sweep: sweep <= 0 || sweep >= 1 ? null : LaunchMotion.sweepCurve.transform(sweep),
      iconFade: LaunchMotion.iconFadeCurve.transform(_progress(ms, LaunchMotion.iconIn)),
    );
  }

  static double _progress(double ms, (int, int) span) {
    final (start, end) = span;
    if (ms <= start) return 0;
    if (ms >= end) return 1;
    return (ms - start) / (end - start);
  }
}

abstract final class LaunchMotion {
  /// The icon's settle (ms from the hand-over).
  static const settle = (0, 640);

  /// The wordmark coming in.
  static const wordmark = (200, 640);

  /// The light crossing the icon.
  static const sweep = (560, 1360);

  /// The icon coming in, when the system's picture had none.
  static const iconIn = (0, 320);

  /// Everything has come to rest.
  static const total = Duration(milliseconds: 1360);

  /// The whole layer fading away once the app is usable.
  static const leave = Duration(milliseconds: 300);

  /// A custom launch screen fading in over the system's picture.
  static const customIn = Duration(milliseconds: 360);

  /// From rest, a long gentle landing: no jolt where the still system splash ends.
  static const settleCurve = Cubic(0.4, 0.0, 0.2, 1.0);
  static const wordmarkFade = Cubic(0.0, 0.0, 0.2, 1.0);
  static const wordmarkRiseCurve = Cubic(0.2, 0.0, 0.0, 1.0);
  static const sweepCurve = Cubic(0.45, 0.0, 0.55, 1.0);
  static const iconFadeCurve = Cubic(0.2, 0.0, 0.0, 1.0);

  /// The system's launch icon square on AOSP (launch/LaunchGeometry.kt): where a preview
  /// without a measured splash puts it.
  static const iconSize = 160.0;

  /// The icon at rest, against the 160 dp it starts at.
  static const settledScale = 0.8;

  /// Icon to wordmark.
  static const wordmarkGap = 18.0;

  /// The wordmark: AppType.wordmark at this size, its line this many times the size.
  static const wordmarkSize = 26.0;
  static const wordmarkLine = 1.2;

  /// The wordmark starts this far below its place.
  static const wordmarkRiseBy = 10.0;

  /// The light band: its width against the icon's, its tilt, its brightest white.
  static const sweepWidth = 0.34;
  static const sweepTilt = 0.32; // radians, about 18°
  static const sweepPeak = 0.26;
}
