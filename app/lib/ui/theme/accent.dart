// Portions derived from PiPilot (https://github.com/CikeSeven/pi_pilot), MIT, Copyright (c) 2026 CikeSeven. See THIRD_PARTY_NOTICES.md.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import 'oklch.dart';
import 'palette.dart';

/// One palette: the accent's light/dark colour scales, plus which tint the neutrals (page, glass, text)
/// get dyed towards. What cannot be enumerated (custom, follow-wallpaper) is derived on the spot by [AppAccent.derive].
///
/// ## Derivation rules (OKLCH, one ruler for every hue)
///
/// DeepSeek's brand blue `#4D6BFE` is OKLCH(0.59, 0.22, 270): saturation nearly maxed out,
/// harsh over large areas and long looking. The default [mist] keeps its hue (267°), presses
/// chroma down to 0.125, lightness 0.53, white text at 5.39. Every other preset only swaps hue and chroma and copies the lightness:
///
/// | Role | Lightness L | Chroma (× accent chroma) |
/// |---|---|---|
/// | seed / pressed | 0.53 / 0.47 | 1 / 0.95 |
/// | container / onContainer | 0.93 / 0.33 | 0.26 / 0.70 |
/// | bubble / glow | 0.918 / 0.819 | 0.29 / 0.68 |
/// | seedDark / pressedDark | 0.764 / 0.704 | 0.76 |
/// | onSeedDark | 0.231 | 0.39 |
/// | containerDark / onContainerDark | 0.361 / 0.909 | 0.51 / 0.24 |
/// | bubbleDark / glowDark | 0.314 / 0.52 | 0.29 / 0.72 |
///
/// - Light primary carries white text (≥ 4.5); the dark primary carries a same-hue deep ink (≥ 7).
/// - Neutrals: the mist-blue neutral ramp rotates as-is onto [tintHue], chroma multiplied by [tintChroma]
///   (see `NeutralTones`). Lightness stays, so no text level's contrast changes with the palette.
/// - [haze]: the glow at the page's bottom-left, a neighbour of the primary, giving the glass something to transmit.
///
/// Every preset's contrasts are verified item by item in `test/theme/palette_contrast_test.dart`.
@immutable
class AppAccent {
  const AppAccent({
    required this.id,
    this._label,
    required this.seed,
    required this.pressed,
    required this.container,
    required this.onContainer,
    required this.bubble,
    required this.glow,
    required this.seedDark,
    required this.pressedDark,
    required this.onSeedDark,
    required this.containerDark,
    required this.onContainerDark,
    required this.bubbleDark,
    required this.glowDark,
    required this.tintHue,
    required this.tintChroma,
    required this.haze,
    required this.hazeDark,
  });

  /// Persistence key: the preset name, or [customId] / [wallpaperId].
  final String id;

  /// Display name in the settings page.
  final String? _label;

  String get label =>
      _label ??
      switch (id) {
        'mist' => appL10n.phoneAccentMist,
        'daiqing' => appL10n.phoneAccentDaiqing,
        'dusk' => appL10n.phoneAccentDusk,
        'turquoise' => appL10n.phoneAccentTurquoise,
        'amber' => appL10n.phoneAccentAmber,
        'graphite' => appL10n.phoneAccentGraphite,
        _ => appL10n.phoneAccentCustom,
      };

  /// Light primary (the colour shown on the swatch). White text ≥ 4.5.
  final Color seed;

  /// Light pressed state.
  final Color pressed;

  /// Light: accent container / its foreground (≥ 7).
  final Color container;
  final Color onContainer;

  /// Light user bubble: one step deeper than the page (OKLCH L 0.918), like a patch gently pressed into the paper.
  /// Inside the bubble only primary / secondary text (≥ 5.8); tertiary text and the primary fail AA here.
  final Color bubble;

  /// Light background glow (multiply an alpha in when used).
  final Color glow;

  /// Dark primary: the lightened seed, paired with [onSeedDark] deep ink text.
  final Color seedDark;
  final Color pressedDark;
  final Color onSeedDark;
  final Color containerDark;
  final Color onContainerDark;
  final Color bubbleDark;
  final Color glowDark;

  /// The hue neutrals rotate onto (degrees). Mist blue's neutrals sit at [NeutralTones.baseHue].
  final double tintHue;

  /// Neutrals' chroma multiplier (mist blue = 1; graphite near 0).
  final double tintChroma;

  /// Bottom-left glow (light / dark; multiply an alpha in when used).
  final Color haze;
  final Color hazeDark;

  /// Text on the light primary. White in every palette.
  Color get onSeed => const Color(0xFFFFFFFF);

  /// The primary for a brightness.
  Color seedFor(Brightness brightness) => brightness == Brightness.dark ? seedDark : seed;

  // ══ Presets ══════════════════════════════════════════════════════════════

  /// Default: Mist. DeepSeek's hue at low chroma.
  static const mist = AppAccent(
    id: 'mist',
    seed: Color(0xFF4B67B4),
    pressed: Color(0xFF3D569D),
    container: Color(0xFFDEE8FF),
    onContainer: Color(0xFF213262),
    bubble: Color(0xFFD9E4FD),
    glow: Color(0xFFABC3FC),
    seedDark: Color(0xFF97B1F0),
    pressedDark: Color(0xFF859EDC),
    onSeedDark: Color(0xFF121C34),
    containerDark: Color(0xFF2E3C5F),
    onContainerDark: Color(0xFFD8E1F6),
    bubbleDark: Color(0xFF293144),
    glowDark: Color(0xFF51679D),
    tintHue: NeutralTones.baseHue,
    tintChroma: 1,
    haze: Color(0xFFD5CBEB),
    hazeDark: Color(0xFF514765),
  );

  /// Daiqing: ink blue leaning cyan (238°), one step deeper than mist (L 0.47), chroma reined to 0.085.
  /// Neutrals carry a touch of lake teal; the glow pairs with periwinkle.
  static const daiqing = AppAccent(
    id: 'daiqing',
    seed: Color(0xFF236185),
    pressed: Color(0xFF145071),
    container: Color(0xFFDBEAF5),
    onContainer: Color(0xFF123950),
    bubble: Color(0xFFD6E7F3),
    glow: Color(0xFFA2CAE5),
    seedDark: Color(0xFF8CB9D7),
    pressedDark: Color(0xFF79A6C4),
    onSeedDark: Color(0xFF0D1F2B),
    containerDark: Color(0xFF274152),
    onContainerDark: Color(0xFFD5E3ED),
    bubbleDark: Color(0xFF26333C),
    glowDark: Color(0xFF466E88),
    tintHue: 238,
    tintChroma: 0.9,
    haze: Color(0xFFC7D0EC),
    hazeDark: Color(0xFF444C66),
  );

  /// Dusk: grey-toned lavender (300°, chroma 0.075). The glow pairs with a touch of grey rose.
  static const dusk = AppAccent(
    id: 'dusk',
    seed: Color(0xFF726291),
    pressed: Color(0xFF61517D),
    container: Color(0xFFEAE5F4),
    onContainer: Color(0xFF392F4C),
    bubble: Color(0xFFE6E1F1),
    glow: Color(0xFFC8BDE1),
    seedDark: Color(0xFFB8ABD2),
    pressedDark: Color(0xFFA598BF),
    onSeedDark: Color(0xFF1F1A29),
    containerDark: Color(0xFF40394F),
    onContainerDark: Color(0xFFE2DEEC),
    bubbleDark: Color(0xFF332F3B),
    glowDark: Color(0xFF6D6284),
    tintHue: 295,
    tintChroma: 0.85,
    haze: Color(0xFFE6C7D7),
    hazeDark: Color(0xFF5F4353),
  );

  /// Turquoise: low-saturation green-cyan (186°, chroma 0.068). Neutrals carry only thirty percent cyan, so they don't go green or grey;
  /// the glow pairs with sky blue.
  static const turquoise = AppAccent(
    id: 'turquoise',
    seed: Color(0xFF34766F),
    pressed: Color(0xFF296760),
    container: Color(0xFFDBECE9),
    onContainer: Color(0xFF123D39),
    bubble: Color(0xFFD6E8E6),
    glow: Color(0xFFA3CEC8),
    seedDark: Color(0xFF8DBEB7),
    pressedDark: Color(0xFF7BABA4),
    onSeedDark: Color(0xFF0D211F),
    containerDark: Color(0xFF274340),
    onContainerDark: Color(0xFFD6E5E2),
    bubbleDark: Color(0xFF263533),
    glowDark: Color(0xFF47726D),
    tintHue: 190,
    tintChroma: 0.7,
    haze: Color(0xFFB9D7E3),
    hazeDark: Color(0xFF34525E),
  );

  /// Amber: restrained golden brown (70°, chroma 0.082, L 0.54). The page turns to oat paper and dark mode to
  /// warm charcoal, keeping seventy-five percent of the chroma; the glow pairs with apricot pink.
  static const amber = AppAccent(
    id: 'amber',
    seed: Color(0xFF8D6636),
    pressed: Color(0xFF7A5528),
    container: Color(0xFFF2E6D9),
    onContainer: Color(0xFF483011),
    bubble: Color(0xFFEEE2D3),
    glow: Color(0xFFDCBE9D),
    seedDark: Color(0xFFCCAC87),
    pressedDark: Color(0xFFB99975),
    onSeedDark: Color(0xFF271A0C),
    containerDark: Color(0xFF4C3A25),
    onContainerDark: Color(0xFFEADFD3),
    bubbleDark: Color(0xFF392F24),
    glowDark: Color(0xFF7F6343),
    tintHue: 75,
    tintChroma: 0.75,
    haze: Color(0xFFEAC8C1),
    hazeDark: Color(0xFF64443D),
  );

  /// Graphite: neutral grey. The primary runs near-black in light (L 0.30) and near-white in dark (L 0.93),
  /// neutrals keep just a chill note. Black-and-white like a system settings app.
  static const graphite = AppAccent(
    id: 'graphite',
    seed: Color(0xFF2C2E32),
    pressed: Color(0xFF1D1F23),
    container: Color(0xFFE3E6EC),
    onContainer: Color(0xFF2C2E32),
    bubble: Color(0xFFE0E3E8),
    glow: Color(0xFFBBBEC3),
    seedDark: Color(0xFFE5E8ED),
    pressedDark: Color(0xFFCED1D6),
    onSeedDark: Color(0xFF191B1E),
    containerDark: Color(0xFF3B3D41),
    onContainerDark: Color(0xFFDEE1E7),
    bubbleDark: Color(0xFF2E3034),
    glowDark: Color(0xFF616368),
    tintHue: 262,
    tintChroma: 0.25,
    haze: Color(0xFFCED1D6),
    hazeDark: Color(0xFF4A4D52),
  );

  /// Order in the settings page.
  static const presets = [mist, daiqing, dusk, turquoise, amber, graphite];

  static const customId = 'custom';
  static const wallpaperId = 'wallpaper';

  /// The preset with [id]; unknown / missing falls back to mist (forward-compatible with old values).
  static AppAccent preset(String? id) {
    for (final p in presets) {
      if (p.id == id) return p;
    }
    return mist;
  }

  // ══ Derived: custom colours and follow-the-wallpaper ═══════════════════════════════════════════

  /// Accent chroma cap: beyond this it stops feeling quiet (mist blue 0.125).
  static const maxChroma = 0.13;

  /// Lightness of hue-bar and suggested colours (same as mist blue).
  static const lightSeedL = 0.53;

  /// How much lighter the dark primary is than the light one (mist blue 0.53 → 0.764).
  static const darkLift = 0.234;

  /// Derives the whole palette from any single colour: take its hue, chroma (capped at [maxChroma]) and
  /// lightness (clamped to 0.30–0.60, dark lifted further by [darkLift]), compute each role
  /// from the table above; the light and dark primaries each pass through [guard], nudged to compliance by the shortest move from the pick.
  ///
  /// Neutrals rotate onto the same hue, chroma scaled from the accent's (a near-grey pick yields a near-grey page).
  factory AppAccent.derive(Color pick, {String id = customId, String? label}) {
    final key = (pick.toARGB32(), id, label);
    final hit = _derived[key];
    if (hit != null) return hit;
    if (_derived.length > 64) _derived.clear();
    return _derived[key] = AppAccent._derive(pick, id: id, label: label);
  }

  static final _derived = <(int, String, String?), AppAccent>{};

  factory AppAccent._derive(Color pick, {required String id, required String? label}) {
    final o = Oklch.fromColor(pick);
    final c = math.min(o.c, maxChroma);
    final h = o.h;
    final k = math.min(1.0, c / 0.1255);
    final tintChroma = 0.8 * k;
    final neutrals = NeutralTones.of(tintHue: h, tintChroma: tintChroma);
    Color tone(double l, double ratio) => Oklch(l, c * ratio, h).toColor();

    final onSeedDark = tone(0.231, 0.39);
    final lightL = o.l.clamp(0.30, 0.60);
    final seed = guard(
      Oklch(lightL, c, h),
      brightness: Brightness.light,
      surface: neutrals.mistHighest,
      onAccent: const Color(0xFFFFFFFF),
    );
    final seedDark = guard(
      Oklch(math.min(0.93, lightL + darkLift), c * 0.76, h),
      brightness: Brightness.dark,
      surface: neutrals.nightHighest,
      onAccent: onSeedDark,
    );
    final sl = Oklch.fromColor(seed).l;
    final sdl = Oklch.fromColor(seedDark).l;
    return AppAccent(
      id: id,
      label: label,
      seed: seed,
      pressed: tone(sl - 0.06, 0.95),
      container: tone(0.93, 0.26),
      onContainer: tone(0.33, 0.70),
      bubble: tone(0.918, 0.29),
      glow: tone(0.819, 0.68),
      seedDark: seedDark,
      pressedDark: tone(sdl - 0.06, 0.76),
      onSeedDark: onSeedDark,
      containerDark: tone(0.361, 0.51),
      onContainerDark: tone(0.909, 0.24),
      bubbleDark: tone(0.314, 0.29),
      glowDark: tone(0.52, 0.72),
      tintHue: h,
      tintChroma: tintChroma,
      haze: Oklch(0.86, 0.045 * k, h + 33).toColor(),
      hazeDark: Oklch(0.42, 0.05 * k, h + 33).toColor(),
    );
  }

  /// Minimum contrast of the accent against its floor (WCAG 1.4.11 non-text).
  static const minOnSurface = 3.0;

  /// Minimum contrast of text on the accent (WCAG 1.4.3 body).
  static const minText = 4.5;

  /// Contrast guard: hue and chroma stay put, only [start]'s lightness moves until
  ///
  /// - accent vs [surface] ≥ [minOnSurface] (3:1), and
  /// - [onAccent] vs accent ≥ [minText] (4.5:1).
  ///
  /// Light walks darker (white text on top), dark walks brighter (deep ink on top); already
  /// compliant returns untouched. A 24-step bisection landing on the passing lightness closest to the start.
  static Color guard(Oklch start, {required Brightness brightness, required Color surface, required Color onAccent}) {
    bool ok(Color c) => contrastRatio(c, surface) >= minOnSurface && contrastRatio(onAccent, c) >= minText;
    final first = start.toColor();
    if (ok(first)) return first;
    final dark = brightness == Brightness.dark;
    // Light: find the largest passing lightness in [0, start.l]; dark: the smallest in [start.l, 1].
    var pass = dark ? 1.0 : 0.0;
    var fail = start.l;
    for (var i = 0; i < 24; i++) {
      final mid = (pass + fail) / 2;
      if (ok(start.copyWith(l: mid).toColor())) {
        pass = mid;
      } else {
        fail = mid;
      }
    }
    return start.copyWith(l: pass).toColor();
  }

  /// [pick]'s guarded primary under [brightness]: the settings page paints swatches and the hue bar with it directly.
  static Color guardedSeed(Color pick, Brightness brightness) => AppAccent.derive(pick).seedFor(brightness);

  /// Colour for the hue bar / suggestions: [hue] degrees, mist blue's chroma and lightness.
  static Color hueColor(double hue, {double chroma = 0.11}) => Oklch(lightSeedL, chroma, hue).toColor();

  @override
  bool operator ==(Object other) =>
      other is AppAccent &&
      other.id == id &&
      other.seed == seed &&
      other.seedDark == seedDark &&
      other.tintHue == tintHue &&
      other.tintChroma == tintChroma;

  @override
  int get hashCode => Object.hash(id, seed, seedDark, tintHue, tintChroma);

  @override
  String toString() => 'AppAccent($id)';
}
