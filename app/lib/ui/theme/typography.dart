// Portions derived from PiPilot (https://github.com/CikeSeven/pi_pilot), MIT, Copyright (c) 2026 CikeSeven. See THIRD_PARTY_NOTICES.md.

import 'package:flutter/material.dart';

/// Typography contract: **system sans carries all text; monospace is for code only**.
///
/// ## Why no bundled CJK font and no serif headings
///
/// - Source Han Sans / Serif cost 10–20 MB per weight; the APK already carries a Linux runtime — no room for more;
/// - Chinese ROMs (MIUI/HyperOS, ColorOS, OriginOS, HarmonyOS) swap the system font
///   for MiSans, OPPO Sans, vivo Sans or HarmonyOS Sans — all high quality, with
///   matching Latin glyphs — following the system is the most harmonious choice;
/// - these ROMs generally **lack** Noto Serif CJK, so serif headings would render as
///   a mixed plate: "Latin serif, Chinese sans". Headings therefore use sans + size / colour layers.
///
/// ## Only two weights
///
/// AOSP / Pixel ship only Noto Sans CJK **Regular**; w500 rounds back to Regular and
/// w600+ becomes synthetic bold. Hierarchy therefore comes only from 400 / 600 plus
/// size and colour — never expect 500 vs 400 to read differently in Chinese. Large
/// display text uses 300 (airier on multi-weight systems, falls back to 400 without hurting readability).
///
/// ## Monospace
///
/// JetBrains Mono (OFL, Regular + Medium + Bold, about 0.8 MB). Android's
/// `monospace` is Droid Sans Mono / Cutive Mono depending on the device, with uneven
/// results; code is one of this app's main content types, so bundling is worth it. Falls back to system mono when missing.
///
/// ## Han glyph shapes
///
/// One CJK code point takes different regional glyphs (e.g. 「直」「写」). Always declare
/// `supportedLocales: [Locale('zh', 'CN'), ...]` in `MaterialApp` and wire up
/// `GlobalMaterialLocalizations`, or non-Chinese system languages will pick Japanese glyph shapes.
abstract final class AppType {
  /// Sans family. `null` = system default (Android: Roboto + the system CJK font).
  /// If a Latin UI font is ever bundled, this is the only place to change.
  static const String? sansFamily = null;

  /// Bundled mono family name (the family under pubspec `fonts:`).
  static const monoFamily = 'JetBrainsMono';

  /// Source operators remain separate glyphs (<=, !=, ->), not programming
  /// ligatures. This changes shaping only, never the text copied or selected.
  static const monoFeatures = [FontFeature.disable('calt'), FontFeature.disable('liga')];

  /// Monospace fallbacks: system mono → CJK (Chinese in code comments falls back to system sans).
  static const monoFallback = <String>['monospace', 'Noto Sans Mono CJK SC', 'Noto Sans CJK SC'];

  /// [t] with every style's glyph locale set to [locale] (null: unchanged).
  /// The English UI passes zh_CN so Chinese content keeps Chinese shapes.
  static TextTheme withGlyphLocale(TextTheme t, Locale? locale) {
    if (locale == null) return t;
    final s = TextStyle(locale: locale);
    return t.merge(
      TextTheme(
        displayLarge: s,
        displayMedium: s,
        displaySmall: s,
        headlineLarge: s,
        headlineMedium: s,
        headlineSmall: s,
        titleLarge: s,
        titleMedium: s,
        titleSmall: s,
        bodyLarge: s,
        bodyMedium: s,
        bodySmall: s,
        labelLarge: s,
        labelMedium: s,
        labelSmall: s,
      ),
    );
  }

  /// The single gateway for monospace styles — business code must no longer write fontFamily literals.
  static TextStyle mono({double size = 13, FontWeight? weight, Color? color, double height = 1.55}) {
    return TextStyle(
      fontFamily: monoFamily,
      fontFeatures: monoFeatures,
      fontFamilyFallback: monoFallback,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      leadingDistribution: TextLeadingDistribution.even,
    );
  }

  /// Tool / terminal output body.
  static TextStyle monoSmall({Color? color}) => mono(size: 12, color: color, height: 1.5);

  /// Argument digests, command lines, path chips, diff stats.
  static TextStyle monoLabel({Color? color, FontWeight? weight}) =>
      mono(size: 12, color: color, weight: weight, height: 1.35);

  /// Chat body (user bubble and assistant text share one source; streaming → finished render never jumps size).
  ///
  /// [scale] / [height] come from user settings (suggest scale 0.85–1.3, height 1.5–1.9);
  /// the theme itself depends on no state.
  static TextStyle chatBody(BuildContext context, {double scale = 1, double? height, Color? color}) {
    final base = Theme.of(context).textTheme.bodyLarge ?? textTheme.bodyLarge!;
    return base.copyWith(fontSize: (base.fontSize ?? 16) * scale, height: height ?? base.height, color: color);
  }

  /// Welcome / empty-state headline: big and light, not bold.
  static TextStyle display({double size = 28, Color? color}) => TextStyle(
    fontFamily: sansFamily,
    fontSize: size,
    fontWeight: FontWeight.w300,
    height: 1.25,
    color: color,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Wordmark 「DSH」: sans bold + slight letter-spacing.
  static TextStyle wordmark({double size = 18, Color? color}) => TextStyle(
    fontFamily: sansFamily,
    fontSize: size,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.6,
    height: 1.2,
    color: color,
  );

  /// Section eyebrows (「最近会话」「引擎」): small size + letter-spacing, in place of heavy dividers.
  static TextStyle eyebrow({Color? color}) => TextStyle(
    fontFamily: sansFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
    height: 1.35,
    color: color,
    leadingDistribution: TextLeadingDistribution.even,
  );

  /// Tabular figures (timers, token counts, percentages) so changing digits never jitters width.
  static TextStyle tabular(TextStyle style) => style.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  static const _even = TextLeadingDistribution.even;

  /// Material 3 type scale (colours applied per scheme in app_theme).
  ///
  /// | Role | Size / leading | Used for |
  /// |---|---|---|
  /// | displaySmall | 28 / 1.25 w300 | welcome, install-finished headline |
  /// | headlineMedium | 22 / 1.3 w600 | page titles (settings, engine) |
  /// | headlineSmall | 20 / 1.35 w600 | dialog titles |
  /// | titleLarge | 18 / 1.4 w600 | sheet titles, top-bar session name (expanded) |
  /// | titleMedium | 16 / 1.45 w600 | card / list titles, body subheads |
  /// | titleSmall | 14 / 1.45 w600 | tool row names, group names |
  /// | bodyLarge | 16 / 1.65 | chat body |
  /// | bodyMedium | 14 / 1.55 | UI body |
  /// | bodySmall | 12 / 1.5 | captions, meta info |
  /// | labelLarge | 14 / 1.4 w600 | buttons |
  /// | labelMedium | 12 / 1.35 w600 | Chips, capsules |
  /// | labelSmall | 11 / 1.35 | timestamps, badges |
  static const textTheme = TextTheme(
    displayLarge: TextStyle(fontSize: 36, fontWeight: FontWeight.w300, height: 1.2, leadingDistribution: _even),
    displayMedium: TextStyle(fontSize: 32, fontWeight: FontWeight.w300, height: 1.2, leadingDistribution: _even),
    displaySmall: TextStyle(fontSize: 28, fontWeight: FontWeight.w300, height: 1.25, leadingDistribution: _even),
    headlineLarge: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, height: 1.3, leadingDistribution: _even),
    headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, height: 1.3, leadingDistribution: _even),
    headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, height: 1.35, leadingDistribution: _even),
    titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, height: 1.4, leadingDistribution: _even),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.45, leadingDistribution: _even),
    titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.45, leadingDistribution: _even),
    bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.65, leadingDistribution: _even),
    bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.55, leadingDistribution: _even),
    bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, height: 1.5, leadingDistribution: _even),
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 1.4,
      letterSpacing: 0.1,
      leadingDistribution: _even,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      height: 1.35,
      letterSpacing: 0.2,
      leadingDistribution: _even,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w400,
      height: 1.35,
      letterSpacing: 0.2,
      leadingDistribution: _even,
    ),
  );
}
