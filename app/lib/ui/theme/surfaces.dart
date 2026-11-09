import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'accent.dart';
import 'palette.dart';

/// Glass tiers. Decide fill opacity, whether it blurs, the stroke and the shadow.
///
/// | Tier | Where it sits | Blur |
/// |---|---|---|
/// | [chrome] | top-bar capsules, round keys, composer, bottom bar — floating over scrolling content | yes |
/// | [sheet] | bottom sheets, menus, drawers | yes |
/// | [card] | settings cards, approval cards, tool groups — lying on the page background | no |
/// | [pill] | thinking pill, model capsule, status chips — small items in scrolling lists | no |
///
/// Only chrome / sheet really blur: what moves behind them is scrollable content, so blurring means something;
/// behind card / pill there is only a static gradient, and translucent white (or white light) already reads as "frosted" —
/// adding a `BackdropFilter` would just burn GPU (dozens in a list means dozens of blurs).
enum GlassTier { chrome, sheet, card, pill }

/// All parameters of one glass material.
@immutable
class GlassStyle {
  const GlassStyle({
    required this.fill,
    required this.fallbackFill,
    required this.hairline,
    required this.rim,
    this.blurSigma = 0,
    this.saturation = 1,
    this.hairlineWidth = 0.5,
    this.shadows = const [],
  });

  /// Fill while blur is on (with transparency).
  final Color fill;

  /// Fill while blur is off (low-end devices, power saving, "减少透明度", high-contrast mode).
  /// Must be near-opaque, otherwise text behind it bleeds through and disturbs reading once blur is gone.
  final Color fallbackFill;

  /// Hairline stroke: defines the glass edge. Cold ink 8% in light, white 9% in dark.
  final Color hairline;
  final double hairlineWidth;

  /// Start colour of the top-edge highlight, fading to transparent by 45% down — light falling on the glass rim from above.
  final Color rim;

  /// Gaussian blur σ (logical pixels). 0 = no blur.
  final double blurSigma;

  /// Saturation gain after the blur (1 = unchanged). iOS-style colour transmission: colours behind bleed through a touch fresher.
  final double saturation;

  /// Shadows painted only **outside** the shape (the glass interior stays clean).
  final List<BoxShadow> shadows;

  bool get blurs => blurSigma > 0;

  GlassStyle copyWith({
    Color? fill,
    Color? fallbackFill,
    Color? hairline,
    Color? rim,
    double? blurSigma,
    double? saturation,
    double? hairlineWidth,
    List<BoxShadow>? shadows,
  }) {
    return GlassStyle(
      fill: fill ?? this.fill,
      fallbackFill: fallbackFill ?? this.fallbackFill,
      hairline: hairline ?? this.hairline,
      rim: rim ?? this.rim,
      blurSigma: blurSigma ?? this.blurSigma,
      saturation: saturation ?? this.saturation,
      hairlineWidth: hairlineWidth ?? this.hairlineWidth,
      shadows: shadows ?? this.shadows,
    );
  }

  static GlassStyle lerp(GlassStyle a, GlassStyle b, double t) {
    return GlassStyle(
      fill: Color.lerp(a.fill, b.fill, t)!,
      fallbackFill: Color.lerp(a.fallbackFill, b.fallbackFill, t)!,
      hairline: Color.lerp(a.hairline, b.hairline, t)!,
      rim: Color.lerp(a.rim, b.rim, t)!,
      blurSigma: lerpDouble(a.blurSigma, b.blurSigma, t)!,
      saturation: lerpDouble(a.saturation, b.saturation, t)!,
      hairlineWidth: lerpDouble(a.hairlineWidth, b.hairlineWidth, t)!,
      shadows: BoxShadow.lerpList(a.shadows, b.shadows, t) ?? const [],
    );
  }
}

/// Page-material theme extension: backdrop gradient, glows, user bubble, the four glasses.
///
/// Unlike `DshColors`, these **follow the accent** (glows and bubble carry the primary hue)
/// and also whether blur is allowed.
class DshSurfaces extends ThemeExtension<DshSurfaces> {
  const DshSurfaces({
    required this.backdropTop,
    required this.backdropBottom,
    required this.glowPrimary,
    required this.glowSecondary,
    required this.userBubble,
    required this.onUserBubble,
    required this.scrim,
    required this.chrome,
    required this.sheet,
    required this.card,
    required this.pill,
    this.accent = AppAccent.mist,
    this.blurEnabled = true,
  });

  /// Top / bottom of the page's vertical gradient.
  final Color backdropTop;
  final Color backdropBottom;

  /// Top-right primary glow (alpha included).
  final Color glowPrimary;

  /// Bottom-left glow (alpha included): a neighbour of the primary — Mist blue pairs with dusk purple.
  final Color glowSecondary;

  /// User bubble: the primary tint one step deeper than the page (Claude-style "pressed-in" soft bubble).
  final Color userBubble;
  final Color onUserBubble;

  /// Drawer / modal scrim (alpha included).
  final Color scrim;

  final GlassStyle chrome;
  final GlassStyle sheet;
  final GlassStyle card;
  final GlassStyle pill;

  /// Which palette this material came from. Places that build their own theme outside the
  /// app theme (share cards, the terminal page) use it to rebuild for the current palette instead of falling back to the default.
  final AppAccent accent;

  /// Master switch. When off, every [GlassTier] uses `fallbackFill` and no
  /// `BackdropFilter` is created. Driven by the "减少透明效果" setting or the performance probe.
  final bool blurEnabled;

  static DshSurfaces of(BuildContext context) => Theme.of(context).extension<DshSurfaces>()!;

  GlassStyle glass(GlassTier tier) => switch (tier) {
    GlassTier.chrome => chrome,
    GlassTier.sheet => sheet,
    GlassTier.card => card,
    GlassTier.pill => pill,
  };

  /// Light: morning-mist gradient + white glass. Gradient, shadows and solid fallbacks follow the palette's neutrals;
  /// the glass itself is white and the highlight too — change the palette, it is still glass.
  factory DshSurfaces.light(AppAccent accent, {bool blurEnabled = true}) {
    final n = NeutralTones.forAccent(accent);
    final ink = n.shadowInk;
    const white = Color(0xFFFFFFFF);
    return DshSurfaces(
      backdropTop: n.mistTop,
      backdropBottom: n.mistBottom,
      glowPrimary: accent.glow.withValues(alpha: 0.42),
      glowSecondary: accent.haze.withValues(alpha: 0.38),
      userBubble: accent.bubble,
      onUserBubble: n.ink,
      scrim: n.scrim.withValues(alpha: 0.32),
      accent: accent,
      blurEnabled: blurEnabled,
      chrome: GlassStyle(
        fill: white.withValues(alpha: 0.70),
        fallbackFill: n.mistLowest.withValues(alpha: 0.96),
        hairline: ink.withValues(alpha: 0.08),
        rim: white.withValues(alpha: 0.85),
        blurSigma: 18,
        saturation: 1.3,
        shadows: [
          BoxShadow(color: ink.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 8)),
          BoxShadow(color: ink.withValues(alpha: 0.05), blurRadius: 3, offset: const Offset(0, 1)),
        ],
      ),
      sheet: GlassStyle(
        fill: n.mistLow.withValues(alpha: 0.82),
        fallbackFill: n.mistLow,
        hairline: ink.withValues(alpha: 0.07),
        rim: white.withValues(alpha: 0.90),
        blurSigma: 24,
        saturation: 1.4,
        shadows: [BoxShadow(color: ink.withValues(alpha: 0.10), blurRadius: 32, offset: const Offset(0, 8))],
      ),
      card: GlassStyle(
        fill: white.withValues(alpha: 0.62),
        fallbackFill: white.withValues(alpha: 0.72),
        hairline: ink.withValues(alpha: 0.06),
        rim: white.withValues(alpha: 0.70),
      ),
      pill: GlassStyle(
        fill: white.withValues(alpha: 0.55),
        fallbackFill: white.withValues(alpha: 0.66),
        hairline: ink.withValues(alpha: 0.07),
        rim: white.withValues(alpha: 0.75),
      ),
    );
  }

  /// Dark: deep-sea slate gradient + smoke-grey glass (slate and smoke follow the palette's neutrals).
  factory DshSurfaces.dark(AppAccent accent, {bool blurEnabled = true}) {
    final n = NeutralTones.forAccent(accent);
    const white = Color(0xFFFFFFFF);
    const black = Color(0xFF000000);
    // In Mist blue this is OKLCH(0.30, 0.022, 266): a slate grey one step above the page.
    final smoke = n.smoke;
    return DshSurfaces(
      backdropTop: n.nightTop,
      backdropBottom: n.nightBottom,
      glowPrimary: accent.glowDark.withValues(alpha: 0.28),
      glowSecondary: accent.hazeDark.withValues(alpha: 0.24),
      userBubble: accent.bubbleDark,
      onUserBubble: n.paper,
      scrim: black.withValues(alpha: 0.48),
      accent: accent,
      blurEnabled: blurEnabled,
      chrome: GlassStyle(
        fill: smoke.withValues(alpha: 0.72),
        fallbackFill: smoke.withValues(alpha: 0.97),
        hairline: white.withValues(alpha: 0.09),
        rim: white.withValues(alpha: 0.12),
        blurSigma: 18,
        saturation: 1.2,
        shadows: [
          BoxShadow(color: black.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 8)),
          BoxShadow(color: black.withValues(alpha: 0.25), blurRadius: 3, offset: const Offset(0, 1)),
        ],
      ),
      sheet: GlassStyle(
        fill: n.sheetDark.withValues(alpha: 0.86),
        fallbackFill: n.sheetDark,
        hairline: white.withValues(alpha: 0.08),
        rim: white.withValues(alpha: 0.10),
        blurSigma: 24,
        saturation: 1.2,
        shadows: [BoxShadow(color: black.withValues(alpha: 0.40), blurRadius: 32, offset: const Offset(0, 8))],
      ),
      card: GlassStyle(
        fill: white.withValues(alpha: 0.05),
        fallbackFill: white.withValues(alpha: 0.06),
        hairline: white.withValues(alpha: 0.07),
        rim: white.withValues(alpha: 0.06),
      ),
      pill: GlassStyle(
        fill: white.withValues(alpha: 0.06),
        fallbackFill: white.withValues(alpha: 0.07),
        hairline: white.withValues(alpha: 0.08),
        rim: white.withValues(alpha: 0.08),
      ),
    );
  }

  @override
  DshSurfaces copyWith({
    Color? backdropTop,
    Color? backdropBottom,
    Color? glowPrimary,
    Color? glowSecondary,
    Color? userBubble,
    Color? onUserBubble,
    Color? scrim,
    GlassStyle? chrome,
    GlassStyle? sheet,
    GlassStyle? card,
    GlassStyle? pill,
    AppAccent? accent,
    bool? blurEnabled,
  }) {
    return DshSurfaces(
      backdropTop: backdropTop ?? this.backdropTop,
      backdropBottom: backdropBottom ?? this.backdropBottom,
      glowPrimary: glowPrimary ?? this.glowPrimary,
      glowSecondary: glowSecondary ?? this.glowSecondary,
      userBubble: userBubble ?? this.userBubble,
      onUserBubble: onUserBubble ?? this.onUserBubble,
      scrim: scrim ?? this.scrim,
      chrome: chrome ?? this.chrome,
      sheet: sheet ?? this.sheet,
      card: card ?? this.card,
      pill: pill ?? this.pill,
      accent: accent ?? this.accent,
      blurEnabled: blurEnabled ?? this.blurEnabled,
    );
  }

  @override
  DshSurfaces lerp(DshSurfaces? other, double t) {
    if (other is! DshSurfaces) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return DshSurfaces(
      backdropTop: mix(backdropTop, other.backdropTop),
      backdropBottom: mix(backdropBottom, other.backdropBottom),
      glowPrimary: mix(glowPrimary, other.glowPrimary),
      glowSecondary: mix(glowSecondary, other.glowSecondary),
      userBubble: mix(userBubble, other.userBubble),
      onUserBubble: mix(onUserBubble, other.onUserBubble),
      scrim: mix(scrim, other.scrim),
      chrome: GlassStyle.lerp(chrome, other.chrome, t),
      sheet: GlassStyle.lerp(sheet, other.sheet, t),
      card: GlassStyle.lerp(card, other.card, t),
      pill: GlassStyle.lerp(pill, other.pill, t),
      accent: t < 0.5 ? accent : other.accent,
      blurEnabled: t < 0.5 ? blurEnabled : other.blurEnabled,
    );
  }
}
