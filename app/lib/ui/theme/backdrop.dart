// Concept derived from PiPilot (https://github.com/CikeSeven/pi_pilot), MIT, Copyright (c) 2026 CikeSeven. See THIRD_PARTY_NOTICES.md.

import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'backdrop_frame.dart';
import 'surfaces.dart';

/// Full-screen page background: **vertical mist-blue gradient + two very faint glows**.
///
/// - Base layer: a `backdropTop → backdropBottom` vertical gradient (light-mode chroma ≤ 0.019).
/// - Top right: a primary-colour glow (follows the accent). Bottom left: a dusk-purple glow. Alphas stay
///   in 0.25–0.42, painted in large-radius radial gradients — the eye reads "a bit of luminosity", not two circles.
/// - The glows give the glass something to "transmit"; on a flat background glass looks like a white block.
///
/// **Every page in one theme shares the same backdrop** —
/// switching tabs leaves the background still and only the foreground changes; that is the key to smooth transitions.
///
/// Carries a transparent `Material` inside: `InkWell` ripples in the subtree paint **above** the background.
/// (If the ripple host were the Scaffold under the backdrop, the opaque gradient would cover the ripples entirely.)
///
/// Given a [picture] (custom wallpaper, lib/ui/wallpaper/wallpaper_backdrop.dart) it paints that
/// pre-baked image instead of the gradient; [BackdropVeil]s in the subtree paint the same image.
class AppBackdrop extends StatelessWidget {
  const AppBackdrop({super.key, required this.child, this.glow = true, this.picture});

  final Widget child;

  /// Whether to paint the glows. Scenes with their own background (full-screen WebView, install pages) can turn them off.
  final bool glow;

  /// A picture in place of the gradient; null: the gradient.
  final BackdropPicture? picture;

  @override
  Widget build(BuildContext context) {
    final s = DshSurfaces.of(context);
    return _BackdropScope(
      picture: picture,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _BackdropPainter(
                    top: s.backdropTop,
                    bottom: s.backdropBottom,
                    glowPrimary: glow ? s.glowPrimary : null,
                    glowSecondary: glow ? s.glowSecondary : null,
                    picture: picture,
                  ),
                ),
              ),
            ),
          ),
          Material(type: MaterialType.transparency, child: child),
        ],
      ),
    );
  }
}

/// What [AppBackdrop] paints instead of its gradient: [image], baked to the screen's size (the
/// custom wallpaper), faded in at [fade] over [from] (the picture it replaces; null: the
/// gradient). [image] null fades back to the gradient. The images belong to whoever made this;
/// they must outlive it.
@immutable
class BackdropPicture {
  const BackdropPicture({required this.image, this.from, this.fade = kAlwaysCompleteAnimation});

  final ui.Image? image;
  final ui.Image? from;
  final Animation<double> fade;

  @override
  bool operator ==(Object other) =>
      other is BackdropPicture && other.image == image && other.from == from && other.fade == fade;

  @override
  int get hashCode => Object.hash(image, from, fade);
}

/// The picture of the nearest [AppBackdrop], for the [BackdropVeil]s over it.
class _BackdropScope extends InheritedWidget {
  const _BackdropScope({required this.picture, required super.child});

  final BackdropPicture? picture;

  static BackdropPicture? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_BackdropScope>()?.picture;

  @override
  bool updateShouldNotify(_BackdropScope old) => old.picture != picture;
}

/// A corner of the [AppBackdrop]: the same background, painting only the bottom [solidHeight] + [feather] band —
/// solid for [solidHeight] at the bottom, easing out over [feather] going up.
///
/// Layered above the scrolling content and below the floating controls (composer, thinking pill): content fades
/// as it slides behind them, the gaps show only the backdrop — the base colour neither flickers with the scrolled
/// content nor leaves a hard seam. No mask cuts the content itself because glass cards must sample the real backdrop.
///
/// The gradient and glows are computed for the full screen size (as in [AppBackdrop]) and painted from the page
/// top, keeping only this band, so they line up seamlessly with the real backdrop; they still match when the keyboard
/// makes the page shorter. Requires filling the whole page, aligned to its top-left corner. In a split layout a column
/// (wide-screen chat or detail pane) learns its place in the full backdrop from [BackdropFrame] and lines up the same way.
class BackdropVeil extends StatelessWidget {
  const BackdropVeil({super.key, required this.solidHeight, this.feather = 14, this.glow = true}) : fromTop = false;

  /// Top variant: solid from the top edge down [height], then easing out over [feather] below (behind the page
  /// top bar). Likewise must fill the whole page, aligned to its top-left corner.
  BackdropVeil.top({super.key, required double height, this.feather = 14, this.glow = true})
    : solidHeight = _FixedHeight(height),
      fromTop = true;

  /// Height solid from the bottom edge. The page layout writes it as floating controls are placed: the veil
  /// paints after layout without a rebuild, so this frame already uses the new height and fits the controls exactly.
  final ValueListenable<double> solidHeight;

  /// Fade-out height beyond the solid region (above it in the bottom variant, below it in the top variant).
  final double feather;
  final bool glow;

  /// The top variant ([BackdropVeil.top]).
  final bool fromTop;

  @override
  Widget build(BuildContext context) {
    final s = DshSurfaces.of(context);
    final frame = BackdropFrame.maybeOf(context);
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _VeilPainter(
          solidHeight: solidHeight,
          feather: feather,
          fromTop: fromTop,
          backdrop: _BackdropPainter(
            top: s.backdropTop,
            bottom: s.backdropBottom,
            glowPrimary: glow ? s.glowPrimary : null,
            glowSecondary: glow ? s.glowSecondary : null,
            area: frame?.area ?? MediaQuery.sizeOf(context),
            origin: frame?.origin ?? Offset.zero,
            picture: _BackdropScope.of(context),
          ),
        ),
      ),
    );
  }
}

/// A fixed height for [BackdropVeil.top].
class _FixedHeight implements ValueListenable<double> {
  const _FixedHeight(this.value);

  @override
  final double value;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}

  @override
  bool operator ==(Object other) => other is _FixedHeight && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

/// One band of the [BackdropVeil]: solid at the bottom, easing out upward (mirrored for the top variant).
class _VeilPainter extends CustomPainter {
  _VeilPainter({required this.solidHeight, required this.feather, required this.backdrop, this.fromTop = false})
    : super(repaint: backdrop.picture == null ? solidHeight : Listenable.merge([solidHeight, backdrop.picture!.fade]));

  final ValueListenable<double> solidHeight;
  final double feather;
  final _BackdropPainter backdrop;
  final bool fromTop;

  @override
  void paint(Canvas canvas, Size size) {
    final band = (solidHeight.value + feather).clamp(0.0, size.height);
    if (band <= 0) return;
    final rect = fromTop
        ? Rect.fromLTWH(0, 0, size.width, band)
        : Rect.fromLTWH(0, size.height - band, size.width, band);
    final fade = (feather / band).clamp(0.0, 1.0);
    // Eased ramp: a linear one reads as a crease at both ends.
    const samples = 8;
    final stops = <double>[];
    final colors = <Color>[];
    if (fromTop) {
      stops.add(0);
      colors.add(Colors.black);
    }
    for (var i = 0; i <= samples; i++) {
      final t = i / samples;
      stops.add(fromTop ? 1 - fade + fade * t : fade * t);
      final alpha = Curves.easeInOutCubic.transform(t);
      colors.add(Colors.black.withValues(alpha: fromTop ? 1 - alpha : alpha));
    }
    if (!fromTop) {
      stops.add(1);
      colors.add(Colors.black);
    }

    canvas.saveLayer(rect, Paint());
    canvas.clipRect(rect);
    // The whole backdrop from the page's top, so the band lines up with it.
    backdrop.paint(canvas, size);
    canvas.drawRect(
      rect,
      Paint()
        ..blendMode = BlendMode.dstIn
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
          stops: stops,
        ).createShader(rect),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_VeilPainter old) =>
      old.solidHeight != solidHeight ||
      old.feather != feather ||
      old.fromTop != fromTop ||
      backdrop.shouldRepaint(old.backdrop);
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter({
    required this.top,
    required this.bottom,
    this.glowPrimary,
    this.glowSecondary,
    this.area,
    this.origin = Offset.zero,
    this.picture,
  }) : super(repaint: picture?.fade);

  final Color top;
  final Color bottom;
  final Color? glowPrimary;
  final Color? glowSecondary;

  /// The whole backdrop's size when this paints only a band of it.
  final Size? area;

  /// Where the canvas sits inside [area] (a column of a split layout).
  final Offset origin;

  /// A picture in place of the gradient.
  final BackdropPicture? picture;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final size = area ?? canvasSize;
    if (area != null) {
      // Only the band: CustomPaint does not clip what is drawn outside it.
      canvas.save();
      canvas.clipRect(Offset.zero & canvasSize);
      canvas.translate(-origin.dx, -origin.dy);
    }
    final picture = this.picture;
    if (picture == null) {
      _gradient(canvas, size);
    } else {
      final t = picture.fade.value;
      if (t < 1) _layer(canvas, size, picture.from);
      if (t > 0) {
        final fading = t < 1;
        if (fading) canvas.saveLayer(Offset.zero & size, Paint()..color = Color.fromRGBO(0, 0, 0, t));
        _layer(canvas, size, picture.image);
        if (fading) canvas.restore();
      }
    }
    if (area != null) canvas.restore();
  }

  void _layer(Canvas canvas, Size size, ui.Image? image) {
    if (image == null) {
      _gradient(canvas, size);
      return;
    }
    // Baked to the screen's shape; covers whatever else this is asked to fill.
    final w = image.width.toDouble();
    final h = image.height.toDouble();
    final scale = size.isEmpty ? 1.0 : (w / size.width < h / size.height ? w / size.width : h / size.height);
    final src = Rect.fromCenter(center: Offset(w / 2, h / 2), width: size.width * scale, height: size.height * scale);
    canvas.drawImageRect(image, src, Offset.zero & size, Paint()..filterQuality = FilterQuality.medium);
  }

  void _gradient(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, bottom],
        ).createShader(rect),
    );
    final longest = size.longestSide;
    if (glowPrimary case final color?) {
      _glow(canvas, Offset(size.width * 0.92, 0), longest * 0.62, color);
    }
    if (glowSecondary case final color?) {
      _glow(canvas, Offset(0, size.height), longest * 0.55, color);
    }
  }

  void _glow(Canvas canvas, Offset center, double radius, Color color) {
    final bounds = Rect.fromCircle(center: center, radius: radius);
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
          stops: const [0, 1],
        ).createShader(bounds),
    );
  }

  @override
  bool shouldRepaint(_BackdropPainter old) =>
      old.top != top ||
      old.bottom != bottom ||
      old.glowPrimary != glowPrimary ||
      old.glowSecondary != glowSecondary ||
      old.area != area ||
      old.origin != origin ||
      old.picture != picture;
}
