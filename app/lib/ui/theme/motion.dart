// Portions derived from PiPilot (https://github.com/CikeSeven/pi_pilot), MIT, Copyright (c) 2026 CikeSeven. See THIRD_PARTY_NOTICES.md.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// Motion tokens. Principles: **quiet, short, finger-tracking**.
///
/// - Feedback (press, icon swaps) ≤ 160ms — too fast to feel like waiting;
/// - Structural (collapse, capsule morph, drawers) 240–340ms — slow enough to see where it came from;
/// - Ambient (install-progress breathing) 2.4s per cycle — slow enough not to intrude.
///
/// With the system's "remove animations" on, durations taken via [of] come back 0; looping
/// animations check [reduced] and park on their rest frame.
abstract final class AppMotion {
  /// Press scale, splash start; the wait before a list press shows, and its minimum hold once shown.
  static const press = Duration(milliseconds: 90);

  /// Cross-fades, icon swaps, the copy-done check.
  static const quick = Duration(milliseconds: 160);

  /// Small block expand / collapse, list items in and out.
  static const standard = Duration(milliseconds: 240);

  /// Thinking-block / tool-row collapse (big height changes need the extra beat, or they snap).
  static const collapse = Duration(milliseconds: 280);

  /// Capsule morphs (top-bar expand, model picker), drawer landings.
  static const emphasized = Duration(milliseconds: 340);

  /// Bottom sheet in / out (showModalBottomSheet only honours durations).
  static const sheetIn = Duration(milliseconds: 380);
  static const sheetOut = Duration(milliseconds: 260);

  /// After the sheet settles, the blur fades through.
  static const glassIn = Duration(milliseconds: 120);

  /// Page-level transitions, install-step switches.
  static const slow = Duration(milliseconds: 480);

  /// Ambient breathing (install-progress glow, connecting status dot).
  static const breath = Duration(milliseconds: 2400);

  /// Standard easing (M3 standard, same family as DSH Web's cubic-bezier(.4,0,.2,1)).
  static const std = Easing.standard;

  /// Enter: quick out, slow stop.
  static const enter = Easing.emphasizedDecelerate;

  /// Exit: slow start, quick out.
  static const exit = Easing.emphasizedAccelerate;

  /// Collapse / expand.
  static const collapseCurve = Curves.easeInOutCubic;

  /// Glides: drawers and capsule shifts — "follow the finger, then land" motion, iOS-style long-tail deceleration.
  static const glide = Cubic(0.32, 0.72, 0.0, 1.0);

  /// Springs, duration + bounce, on Apple's defaults: bounce 0 is the most general, 0.15 barely shows the
  /// overshoot, past 0.4 it turns theatrical. Press landings.
  static final pressSpring = SpringDescription.withDurationAndBounce(duration: const Duration(milliseconds: 150));

  /// The landing of size and position changes.
  static final layoutSpring = SpringDescription.withDurationAndBounce(duration: const Duration(milliseconds: 350));

  /// Landing after finger-tracking: sheets, back gestures.
  static final sheetSpring = SpringDescription.withDurationAndBounce(duration: const Duration(milliseconds: 500));

  /// A flung drawer: this is where the interface gets a little alive.
  static final flingSpring = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 500),
    bounce: 0.15,
  );

  // ── Springs used only in fluid mode ([fluid]): all carry a touch of bounce, fed to displacement and scale, never opacity ──

  /// Release bounce: coming back to 1 overshoots just slightly.
  static final releaseSpring = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 320),
    bounce: 0.45,
  );

  /// Dialog pop.
  static final popSpring = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 380),
    bounce: 0.2,
  );

  /// The segmented control's thumb landing.
  static final thumbSpring = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 320),
    bounce: 0.15,
  );

  /// A just-sent bubble rising out of the composer.
  static final riseSpring = SpringDescription.withDurationAndBounce(
    duration: const Duration(milliseconds: 420),
    bounce: 0.18,
  );

  /// The curve form of the same springs, for APIs that only take curve + duration.
  ///
  /// [popCurve] drives just a 10% scale; 1% off is invisible, so the route need not wait for the tail.
  static final popCurve = SpringCurve(popSpring, within: 0.01);
  static final thumbCurve = SpringCurve(thumbSpring);
  static final riseCurve = SpringCurve(riseSpring);

  /// A spring drives from [from] at [velocity] onto [to] and stops exactly on [to].
  ///
  /// [landing]: the target is on screen. Rushed too hard at a visible target, even a zero-bounce spring
  /// overshoots and comes back, so velocity is capped at the most that just misses it (only exact for
  /// zero-bounce springs). Pass false when the target is off screen (page exits, sheet dropping away) or
  /// a controller clamp will catch it — then the finger's speed goes through untouched.
  ///
  /// [extent]: total units this move covers (fractional controllers use 1, pixel-based ones pass pixels).
  /// 0.1% off counts as arrived without waiting for velocity to hit zero: under default tolerances the eye
  /// has long stopped, yet routes and gestures keep waiting.
  static SpringSimulation settle(
    SpringDescription spring,
    double from,
    double to,
    double velocity, {
    bool landing = true,
    double extent = 1,
  }) {
    var start = velocity;
    if (landing) {
      final limit = (to - from) * spring.damping / (2 * spring.mass);
      start = limit > 0 ? math.min(velocity, limit) : math.max(velocity, limit);
    }
    return SpringSimulation(
      spring,
      from,
      to,
      start,
      snapToEnd: true,
      tolerance: Tolerance(distance: 0.001 * extent, velocity: double.infinity),
    );
  }

  /// The rubber band when pulled too far: the finger pulls [x], the thing moves only this much — heavier the further, never past [limit].
  static double rubberBand(double x, {double limit = 48}) => (1 - 1 / (x * 0.55 / limit + 1)) * limit;

  /// Page-level step switches (onboarding steps, launch page → home).
  static const page = Duration(milliseconds: 300);

  /// Secondary page push in / out (iOS-style horizontal push).
  static const push = Duration(milliseconds: 300);

  /// Fluid-mode secondary pages: a card expanding into a page travels further.
  static const pushFluid = Duration(milliseconds: 360);

  /// Stagger first-appearance of list items (≤ 30ms, only the first [staggerLimit] items).
  static const stagger = Duration(milliseconds: 30);
  static const staggerLimit = 8;

  /// Upward offset on first appearance (logical pixels).
  static const rise = 8.0;

  /// Press scale: pressing shrinks to [pressScale], release returns to 1 (no overshoot), both on [pressSpring].
  static const pressScale = 0.97;

  /// Sheet rise: fast out, long-tail deceleration, as if lightly damped; no bounce.
  static const sheetRise = Cubic(0.2, 0.9, 0.25, 1.0);

  /// Sheet dismissal (used as reverseCurve: played backwards it starts slow, ends fast).
  static const sheetFall = Curves.easeOutCubic;

  /// Fluid mode: 设置 → 性能 → 灵动动效 ([AppMotionScope]); always off when the system removes animations.
  ///
  /// This tier adds only cheap effects — displacement, scale, press glow — no blur, no offscreen layers; with it off the UI is exactly as it would be with no such tier.
  static bool fluid(BuildContext context) =>
      !reduced(context) && (context.dependOnInheritedWidgetOfExactType<AppMotionScope>()?.fluid ?? false);

  /// Fluid mode bounces lists when pulled past the end; otherwise defer to platform default (null). Do not use on the chat list or the scrollables inside it: bounce swallows OverscrollNotification and `OverscrollForwarder` stops working.
  static ScrollPhysics? scrollPhysics(BuildContext context) =>
      fluid(context) ? const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()) : null;

  /// Whether the system asks for reduced animation.
  static bool reduced(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// Duration per system setting: returns 0 when animation is reduced.
  static Duration of(BuildContext context, Duration duration) => reduced(context) ? Duration.zero : duration;
}

/// Tells the subtree whether fluid mode ([AppMotion.fluid]) is on now. Mounted in `MaterialApp.builder`;
/// with none in the tree (tests, standalone previews) it is standard mode.
class AppMotionScope extends InheritedWidget {
  const AppMotionScope({super.key, required this.fluid, required super.child});

  final bool fluid;

  @override
  bool updateShouldNotify(AppMotionScope oldWidget) => fluid != oldWidget.fluid;
}

/// Converts a spring into a curve for APIs that only take "curve + duration" ([AnimatedSwitcher],
/// [AnimationStyle], implicit animations). [duration] is how long the spring takes to visually settle; pass it to the API alongside.
///
/// With bounce the value exceeds 1: usable for displacement and scale only, never opacity. To absorb finger
/// velocity or retarget mid-flight, use [AppMotion.settle], not this.
class SpringCurve extends Curve {
  /// [within]: how close to the target counts as settled.
  SpringCurve(SpringDescription spring, {double within = 0.002}) : this._(SpringSimulation(spring, 0, 1, 0), within);

  SpringCurve._(this._simulation, double within) : _seconds = _settleSeconds(_simulation, within);

  final SpringSimulation _simulation;
  final double _seconds;

  /// The matching animation duration.
  Duration get duration => Duration(microseconds: (_seconds * Duration.microsecondsPerSecond).round());

  /// The moment it enters [within] of the end and never leaves again.
  static double _settleSeconds(SpringSimulation simulation, double within) {
    const step = 0.004;
    var last = step;
    for (var t = step; t < 4; t += step) {
      if ((simulation.x(t) - 1).abs() > within) last = t + step;
    }
    return last;
  }

  @override
  double transformInternal(double t) => _simulation.x(t * _seconds);
}
