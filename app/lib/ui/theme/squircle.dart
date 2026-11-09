// Concept derived from PiPilot (https://github.com/CikeSeven/pi_pilot), MIT, Copyright (c) 2026 CikeSeven. See THIRD_PARTY_NOTICES.md.

import 'package:flutter/widgets.dart';

/// Continuous-curvature rounded corners (superellipse).
///
/// Plain rounded corners have a curvature jump where straight edge meets arc,
/// visible as a "kink" when zoomed; continuous curvature eases it — why iOS corners look softer.
///
/// Uses the engine-native `RoundedSuperellipseBorder`:
/// - the curve matches iOS continuous corners, not an approximate n=5 superellipse;
/// - Impeller has a dedicated fast path, so strokes and anti-aliasing are handled by the engine;
/// - supports `lerp`: shape animations via `AnimatedContainer` / `ShapeBorderTween` don't jump;
/// - strokes inset correctly per `strokeAlign`.
typedef SquircleBorder = RoundedSuperellipseBorder;

/// Shorthand constructors for the common squircle shapes.
abstract final class Squircle {
  /// A continuous-corner border with the same radius on all four corners.
  static RoundedSuperellipseBorder border(double radius, {BorderSide side = BorderSide.none}) =>
      RoundedSuperellipseBorder(borderRadius: BorderRadius.all(Radius.circular(radius)), side: side);

  /// Clips the subtree to a continuous corner radius (images, code wells, glass content).
  static Widget clip({required double radius, required Widget child, Clip clipBehavior = Clip.antiAlias}) =>
      ClipRSuperellipse(
        borderRadius: BorderRadius.all(Radius.circular(radius)),
        clipBehavior: clipBehavior,
        child: child,
      );
}
