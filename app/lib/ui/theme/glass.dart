import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../common/pressable.dart';
import '../common/ui_trace.dart';

import 'motion.dart';
import 'shapes.dart';
import 'surfaces.dart';

/// Glass surface: **blur what's behind → overlay a translucent fill → hairline stroke +
/// top rim highlight → drop shadow outside**.
///
/// ```dart
/// GlassSurface(
///   tier: GlassTier.chrome,
///   stadium: true,
///   onTap: openSessions,
///   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
///   child: Text('Fix duplicate login submits'),
/// )
/// ```
///
/// ## Performance rules
///
/// - Only [GlassTier.chrome] / [GlassTier.sheet] really blur by default; keep the
///   genuinely blurred elements on screen to at most 3 (top bar, composer, sheet).
/// - Several **non-overlapping** blurred pieces on one screen (top bar's left round
///   key + title capsule + right round key) go into one `BackdropGroup` with
///   [grouped] = true, so the engine samples the backdrop only once.
/// - Blurring uses `ImageFilterConfig.blur(bounded: true)`: sampling never crosses the
///   shape's edge, so outside colors can't "bleed" into the border (same as iOS).
/// - Degradation: when the theme has `DshSurfaces.blurEnabled == false` (the
///   "reduce transparency" setting / low-end devices) or system high contrast is on,
///   no `BackdropFilter` is created and a nearly opaque `fallbackFill` is used
///   instead — the look is "frosted paper", readability unchanged.
///
/// ## Why the shadow is painted separately
///
/// The glass interior is translucent: a plain `BoxShadow` drawn under the shape
/// would show through the glass and get blurred again, greying out the middle.
/// Here an even-odd clip draws the shadow only **outside** the shape.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    this.tier = GlassTier.card,
    this.borderRadius,
    this.circle = false,
    this.stadium = false,
    this.padding,
    this.blur,
    this.grouped = false,
    this.settled,
    this.style,
    this.onTap,
    this.onLongPress,
    this.child,
  }) : assert(!(circle && stadium), 'circle 与 stadium 只能二选一' /* l10n:keep developer-only assertion */);

  /// Material tier; decides the default fill / blur / shadow / corner radius.
  final GlassTier tier;

  /// Continuous corner radius. Defaults by tier: chrome / sheet use xl (28), card uses md (14),
  /// pill uses a capsule.
  final BorderRadiusGeometry? borderRadius;

  /// Circle (top-bar round keys, the send key's base).
  final bool circle;

  /// Capsule (the radius always equals half the height).
  final bool stadium;

  final EdgeInsetsGeometry? padding;

  /// Force blur on / off. null = follow the tier default and the theme master switch.
  final bool? blur;

  /// Shares one backdrop sample with other glass under the same `BackdropGroup`.
  final bool grouped;

  /// Glass that moves (a sheet rising or being dragged). 0 = moving: no backdrop sampling,
  /// opaque fill. As it settles toward 1: blur turns on immediately, hidden behind a nearly
  /// opaque fill, and the fill fades back into glass, so the blur doesn't pop in. Unlike
  /// `blur: false`, the blur layer stays in the tree during the switch and the subtree is
  /// not rebuilt. null = always glass.
  final double? settled;

  /// Overrides the theme's material (rare; e.g. an approval card swaps in a warning-tinted stroke).
  final GlassStyle? style;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? child;

  BorderRadiusGeometry get _radius =>
      borderRadius ??
      switch (tier) {
        GlassTier.chrome || GlassTier.sheet => AppShape.radiusXl,
        GlassTier.card => AppShape.radiusMd,
        GlassTier.pill => AppShape.radiusLg,
      };

  bool get _isStadium => stadium || (!circle && borderRadius == null && tier == GlassTier.pill);

  ShapeBorder get _shape {
    if (circle) return const CircleBorder();
    if (_isStadium) return const StadiumBorder();
    return RoundedSuperellipseBorder(borderRadius: _radius);
  }

  @override
  Widget build(BuildContext context) {
    final surfaces = DshSurfaces.of(context);
    final s = style ?? surfaces.glass(tier);
    final highContrast = MediaQuery.maybeHighContrastOf(context) ?? false;
    final reduce = !surfaces.blurEnabled || highContrast || uiTraceNoBlur;
    final useBlur = !reduce && (blur ?? s.blurs);
    if (uiTraceEnabled) {
      uiTrace('glass', 'build', {'tier': tier.name, 'blur': useBlur, 'grouped': grouped});
    }
    final fill = useBlur
        ? Color.lerp(s.fallbackFill, s.fill, settled ?? 1)!
        : (reduce || s.blurs ? s.fallbackFill : s.fill);
    final shape = _shape;
    final textDirection = Directionality.maybeOf(context);

    Widget content = child ?? const SizedBox.shrink();
    if (padding != null) content = Padding(padding: padding!, child: content);
    if (onTap != null || onLongPress != null) {
      // Press feedback on the content, not the glass: scaling a surface that
      // blurs would re-sample what is behind it at a new size every frame.
      content = Material(
        type: MaterialType.transparency,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          onLongPress: onLongPress,
          child: Pressable(behavior: HitTestBehavior.translucent, child: content),
        ),
      );
    }

    content = CustomPaint(
      foregroundPainter: _GlassEdgePainter(
        shape: shape,
        hairline: s.hairline,
        hairlineWidth: s.hairlineWidth,
        rim: s.rim,
        textDirection: textDirection,
      ),
      child: DecoratedBox(
        decoration: ShapeDecoration(shape: shape, color: fill),
        child: content,
      ),
    );

    if (useBlur) {
      final config = _filterFor(s.blurs ? s.blurSigma : 14, s.saturation);
      final sampling = settled != 0;
      content = grouped
          ? BackdropFilter.grouped(filterConfig: config, enabled: sampling, child: content)
          : BackdropFilter(filterConfig: config, enabled: sampling, child: content);
      content = _clip(content);
    }

    if (s.shadows.isNotEmpty) {
      content = CustomPaint(
        painter: _GlassShadowPainter(shape: shape, shadows: s.shadows, textDirection: textDirection),
        child: content,
      );
    }
    return content;
  }

  Widget _clip(Widget child) {
    if (circle) return ClipOval(child: child);
    if (_isStadium) {
      return ClipRRect(borderRadius: const BorderRadius.all(Radius.circular(999)), child: child);
    }
    return ClipRSuperellipse(borderRadius: _radius, child: child);
  }

  static ImageFilterConfig _filterFor(double sigma, double saturation) {
    final blur = ImageFilterConfig.blur(sigmaX: sigma, sigmaY: sigma, bounded: true);
    if (saturation == 1) return blur;
    return ImageFilterConfig.compose(outer: ImageFilterConfig(ColorFilter.matrix(_saturate(saturation))), inner: blur);
  }

  /// Saturation matrix that preserves luminance (Rec. 709 weights).
  static List<double> _saturate(double s) {
    final r = 0.2126 * (1 - s);
    final g = 0.7152 * (1 - s);
    final b = 0.0722 * (1 - s);
    return <double>[
      r + s, g, b, 0, 0, //
      r, g + s, b, 0, 0, //
      r, g, b + s, 0, 0, //
      0, 0, 0, 1, 0, //
    ];
  }
}

/// Hairline stroke + top rim highlight. The stroke is drawn inside the shape, so clipping
/// never cuts it in half.
class _GlassEdgePainter extends CustomPainter {
  _GlassEdgePainter({
    required this.shape,
    required this.hairline,
    required this.hairlineWidth,
    required this.rim,
    required this.textDirection,
  });

  final ShapeBorder shape;
  final Color hairline;
  final double hairlineWidth;
  final Color rim;
  final TextDirection? textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final width = math.max(hairlineWidth, 0.5);
    final path = shape.getOuterPath(rect.deflate(width / 2), textDirection: textDirection);
    if (hairline.a > 0) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..color = hairline,
      );
    }
    if (rim.a > 0) {
      final highlight = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(width, 0.8)
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [rim, rim.withValues(alpha: 0)],
          stops: const [0, 0.45],
        ).createShader(rect);
      canvas.drawPath(path, highlight);
    }
  }

  @override
  bool shouldRepaint(_GlassEdgePainter old) =>
      old.shape != shape ||
      old.hairline != hairline ||
      old.hairlineWidth != hairlineWidth ||
      old.rim != rim ||
      old.textDirection != textDirection;
}

/// The drop shadow, drawn only outside the shape.
class _GlassShadowPainter extends CustomPainter {
  _GlassShadowPainter({required this.shape, required this.shadows, required this.textDirection});

  final ShapeBorder shape;
  final List<BoxShadow> shadows;
  final TextDirection? textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    var extent = 0.0;
    for (final s in shadows) {
      extent = math.max(extent, s.blurRadius * 2 + s.spreadRadius.abs() + s.offset.distance);
    }
    final outside = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(rect.inflate(extent + 2))
      ..addPath(shape.getOuterPath(rect, textDirection: textDirection), Offset.zero);
    canvas.save();
    canvas.clipPath(outside);
    for (final s in shadows) {
      canvas.drawPath(
        shape.getOuterPath(rect.shift(s.offset).inflate(s.spreadRadius), textDirection: textDirection),
        s.toPaint(),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlassShadowPainter old) =>
      old.shape != shape || !_sameShadows(old.shadows, shadows) || old.textDirection != textDirection;

  static bool _sameShadows(List<BoxShadow> a, List<BoxShadow> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// The glass of a panel that slides in and out on [motion] (0..1): an opaque fill while it
/// moves, since a moving blur re-samples what is behind it every frame, and glass at rest.
/// Between the two it fades over [AppMotion.glassIn]: the fill and the glass differ, most in
/// a light theme, and a cut between them flashes. The blur stays in the tree throughout, so
/// the panel's content is not rebuilt either.
class SlidingGlass extends StatefulWidget {
  const SlidingGlass({super.key, required this.motion, required this.tier, required this.borderRadius, this.child});

  final Animation<double> motion;
  final GlassTier tier;
  final BorderRadiusGeometry borderRadius;
  final Widget? child;

  @override
  State<SlidingGlass> createState() => _SlidingGlassState();
}

class _SlidingGlassState extends State<SlidingGlass> with SingleTickerProviderStateMixin {
  late final AnimationController _settled = AnimationController(
    vsync: this,
    duration: AppMotion.glassIn,
    value: widget.motion.value == 1 ? 1 : 0,
  );

  @override
  void initState() {
    super.initState();
    widget.motion.addListener(_sync);
  }

  @override
  void didUpdateWidget(SlidingGlass old) {
    super.didUpdateWidget(old);
    if (identical(old.motion, widget.motion)) return;
    old.motion.removeListener(_sync);
    widget.motion.addListener(_sync);
    _sync();
  }

  @override
  void dispose() {
    widget.motion.removeListener(_sync);
    _settled.dispose();
    super.dispose();
  }

  void _sync() {
    final value = widget.motion.value;
    if (value == 0) {
      // Out of sight: nothing to fade, and no reason to keep sampling.
      if (_settled.value != 0) _settled.value = 0;
    } else if (AppMotion.reduced(context)) {
      _settled.value = value == 1 ? 1 : 0;
    } else if (value == 1) {
      if (!_settled.isForwardOrCompleted) _settled.forward();
    } else if (_settled.isForwardOrCompleted) {
      _settled.reverse();
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _settled,
    builder: (context, child) =>
        GlassSurface(tier: widget.tier, borderRadius: widget.borderRadius, settled: _settled.value, child: child),
    child: widget.child,
  );
}

/// [child]'s glass without its blur, for chrome floating over a web page: the page is a
/// native view, which a backdrop filter can't see. It would blur whatever Flutter drew
/// underneath instead, and show it through the key as a band.
class GlassOverNativeView extends StatelessWidget {
  const GlassOverNativeView({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaces = DshSurfaces.of(context);
    if (!surfaces.blurEnabled) return child;
    return Theme(
      data: theme.copyWith(
        extensions: [
          for (final e in theme.extensions.values)
            if (e is! DshSurfaces) e,
          surfaces.copyWith(blurEnabled: false),
        ],
      ),
      child: child,
    );
  }
}
