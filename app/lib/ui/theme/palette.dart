// Portions derived from PiPilot (https://github.com/CikeSeven/pi_pilot), MIT, Copyright (c) 2026 CikeSeven. See THIRD_PARTY_NOTICES.md.

import 'package:flutter/material.dart';

import 'accent.dart';
import 'oklch.dart';
import 'surfaces.dart';

/// The Mist Glass palette: **hand-built**, not `ColorScheme.fromSeed`.
///
/// Why not fromSeed: M3 tonalSpot pushes any seed into a high-chroma "modern app"
/// ramp, which erases exactly the low saturation wanted here. So every slot is set by hand.
///
/// ## Two print runs
///
/// - Light: morning-mist blue paper. The page is a very faint vertical gradient (top `#EBF1FE` → bottom `#F6F7FC`),
///   chroma ≤ 0.019.
/// - Dark: deep-sea slate. Lightness 0.23–0.25, the same tier as Claude dark — **not**
///   pure-black tech: bright text on pure black makes the eyes swim over long sessions.
/// - Neither run uses pure white / pure black for large surfaces; pure white appears only in glass highlights and primary-button text.
///
/// ## Ratios
///
/// 70% neutral surfaces (gradient + glass), 25% text and hairlines, ≤5% accent. The accent appears only on
/// the primary button, the send key, selected states, links and progress. Spread wider and it stops feeling quiet.
///
/// ## Palettes
///
/// The neutral constants here belong to the default palette (mist blue). When the user changes palette, page, glass and text
/// go through [NeutralTones] (same lightness, new tint); UI code always takes colours from the theme, never these
/// constants directly; dusk-purple tertiary and the error colour are semantic and do not rotate.
abstract final class DshPalette {
  // ══ Light: morning mist ══════════════════════════════════════════
  /// Page gradient top · morning-mist blue (same family as DSH official deepseek-50).
  static const mistTop = Color(0xFFEBF1FE);

  /// Page gradient bottom · near-white with a hint of violet.
  static const mistBottom = Color(0xFFF6F7FC);

  /// Opaque page floor (the gradient's midpoint; used when a gradient cannot be painted).
  static const mist = Color(0xFFF0F4FD);

  /// Surface ladder (opaque), for when glass is off or M3 widgets need solid colours.
  static const mistLowest = Color(0xFFFBFCFF);
  static const mistLow = Color(0xFFF6F9FE);
  static const mistContainer = Color(0xFFEEF1F9);
  static const mistHigh = Color(0xFFE7EBF4);
  static const mistHighest = Color(0xFFDFE4EE);

  /// Primary text · deep ink blue (≥ 13 on every light surface).
  static const ink = Color(0xFF1E232E);

  /// Secondary text (≥ 6.2).
  static const inkMuted = Color(0xFF4F5562);

  /// Tertiary text · timestamps, digests, placeholders (≥ 4.6, still fit to carry information).
  static const inkFaint = Color(0xFF646974);

  /// Disabled / pure decoration (about 2.5, **must not** carry essential information).
  static const inkGhost = Color(0xFFA1A5AC);

  /// Interactive bounds such as field outlines (non-text contrast ≥ 3).
  static const outlineLight = Color(0xFF7E838D);

  /// Dividers / hairline strokes (decorative).
  static const ruleLight = Color(0xFFDCE0E8);

  /// Cold-ink shadow base: shadows carry a little blue, cleaner than pure black.
  static const shadowInk = Color(0xFF0B152D);

  // ══ Dark: deep-sea slate ══════════════════════════════════════
  static const nightTop = Color(0xFF1D222C);
  static const nightBottom = Color(0xFF1B1C23);
  static const night = Color(0xFF1C1F28);
  static const nightLowest = Color(0xFF14171E);
  static const nightLow = Color(0xFF232730);
  static const nightContainer = Color(0xFF272C36);
  static const nightHigh = Color(0xFF2D323C);
  static const nightHighest = Color(0xFF343944);

  /// Primary text · mist white (not pure white; ≥ 10.5 on dark surfaces).
  static const paper = Color(0xFFE6E9F0);
  static const paperMuted = Color(0xFFB6BBC5);
  static const paperFaint = Color(0xFF9A9EA9);
  static const paperGhost = Color(0xFF656971);
  static const outlineDark = Color(0xFF737781);
  static const ruleDark = Color(0xFF343841);
  static const shadowNight = Color(0xFF03060D);

  // ══ Neutral helpers (semantic roles shared by both schemes) ═════════════════════
  /// Light secondary · slate blue-grey: secondary buttons, unselected emphasis.
  static const slate = Color(0xFF545E6F);
  static const slateContainer = Color(0xFFE2E6F0);

  /// Dark secondary. The tonal button floor is about 9% white over the glass card, lifting it off the card.
  static const slateLift = Color(0xFFB3BED2);
  static const onSlateLift = Color(0xFF1A2230);
  static const slateContainerDark = Color(0x17FFFFFF);

  /// tertiary · dusk purple: the accent for plan / goal / subagent — "the agent is planning".
  static const dusk = Color(0xFF6B578F);
  static const duskContainer = Color(0xFFECE5FB);
  static const onDuskContainer = Color(0xFF3B2C54);
  static const duskLift = Color(0xFFBEAEDE);
  static const onDuskLift = Color(0xFF251C36);
  static const duskContainerDark = Color(0xFF3E3451);
  static const onDuskContainerDark = Color(0xFFE4DDF3);

  // ══ Error (low-chroma brick rose, same values as DshColors' danger) ═══
  static const danger = Color(0xFFA54743);
  static const onDanger = Color(0xFFFDF9F8);
  static const dangerContainer = Color(0xFFFFE2E0);
  static const onDangerContainer = Color(0xFF642724);
  static const dangerLift = Color(0xFFE69089);
  static const onDangerLift = Color(0xFF331513);
  static const dangerContainerDark = Color(0xFF542C29);
  static const onDangerContainerDark = Color(0xFFF8D9D7);

  /// Scrim base colour (drawers, modal backdrop).
  static const scrim = Color(0xFF0B111F);

  /// The light scheme.
  ///
  /// `surface` is the opaque fallback; the real page background is the gradient painted by `AppBackdrop`,
  /// and cards / top bar / composer go through `GlassSurface`. The five `surfaceContainer*` steps still run
  /// "higher means deeper", serving glass-less M3 widgets (menus, dialogs, Chips).
  static ColorScheme lightScheme(AppAccent accent) {
    final n = NeutralTones.forAccent(accent);
    return ColorScheme(
      brightness: Brightness.light,
      primary: accent.seed,
      onPrimary: accent.onSeed,
      primaryContainer: accent.container,
      onPrimaryContainer: accent.onContainer,
      secondary: n.slate,
      onSecondary: const Color(0xFFFFFFFF),
      secondaryContainer: n.slateContainer,
      onSecondaryContainer: n.ink,
      // Dusk purple is the semantic colour of "the agent is planning"; it never rotates with the palette.
      tertiary: dusk,
      onTertiary: const Color(0xFFFFFFFF),
      tertiaryContainer: duskContainer,
      onTertiaryContainer: onDuskContainer,
      error: danger,
      onError: onDanger,
      errorContainer: dangerContainer,
      onErrorContainer: onDangerContainer,
      surface: n.mist,
      onSurface: n.ink,
      onSurfaceVariant: n.inkMuted,
      surfaceDim: n.mistHighest,
      surfaceBright: n.mistLowest,
      surfaceContainerLowest: n.mistLowest,
      surfaceContainerLow: n.mistLow,
      surfaceContainer: n.mistContainer,
      surfaceContainerHigh: n.mistHigh,
      surfaceContainerHighest: n.mistHighest,
      // Turn off M3 elevation tinting: hierarchy comes from glass and hairlines, not from dyeing surfaces with the primary.
      surfaceTint: Colors.transparent,
      inverseSurface: n.inverseSurface,
      onInverseSurface: n.onInverseSurface,
      inversePrimary: accent.seedDark,
      outline: n.outlineLight,
      outlineVariant: n.ruleLight,
      shadow: n.shadowInk,
      scrim: n.scrim,
    );
  }

  /// Dark scheme: deep-sea slate + a lightened primary (with deep ink text).
  static ColorScheme darkScheme(AppAccent accent) {
    final n = NeutralTones.forAccent(accent);
    return ColorScheme(
      brightness: Brightness.dark,
      primary: accent.seedDark,
      onPrimary: accent.onSeedDark,
      primaryContainer: accent.containerDark,
      onPrimaryContainer: accent.onContainerDark,
      secondary: n.slateLift,
      onSecondary: n.onSlateLift,
      secondaryContainer: slateContainerDark,
      onSecondaryContainer: n.paper,
      tertiary: duskLift,
      onTertiary: onDuskLift,
      tertiaryContainer: duskContainerDark,
      onTertiaryContainer: onDuskContainerDark,
      error: dangerLift,
      onError: onDangerLift,
      errorContainer: dangerContainerDark,
      onErrorContainer: onDangerContainerDark,
      surface: n.night,
      onSurface: n.paper,
      onSurfaceVariant: n.paperMuted,
      surfaceDim: n.nightLowest,
      surfaceBright: n.nightHighest,
      surfaceContainerLowest: n.nightLowest,
      surfaceContainerLow: n.nightLow,
      surfaceContainer: n.nightContainer,
      surfaceContainerHigh: n.nightHigh,
      surfaceContainerHighest: n.nightHighest,
      surfaceTint: Colors.transparent,
      inverseSurface: n.paper,
      onInverseSurface: n.ink,
      inversePrimary: accent.seed,
      outline: n.outlineDark,
      outlineVariant: n.ruleDark,
      shadow: n.shadowNight,
      scrim: const Color(0xFF000000),
    );
  }
}

/// All neutrals under one palette: page gradients, surface ladder, every text level,
/// hairlines, shadows, code wells, terminal.
///
/// [defaults] are the constants in [DshPalette]; other palettes get them from [of], which rotates
/// the whole ramp onto `AppAccent.tintHue` and multiplies chroma by `AppAccent.tintChroma`, **lightness untouched**
/// — so text contrast and glass layering come out the same in every palette (the tests verify each one).
@immutable
class NeutralTones {
  const NeutralTones({
    required this.mistTop,
    required this.mistBottom,
    required this.mist,
    required this.mistLowest,
    required this.mistLow,
    required this.mistContainer,
    required this.mistHigh,
    required this.mistHighest,
    required this.ink,
    required this.inkMuted,
    required this.inkFaint,
    required this.inkGhost,
    required this.outlineLight,
    required this.ruleLight,
    required this.shadowInk,
    required this.slate,
    required this.slateContainer,
    required this.inverseSurface,
    required this.onInverseSurface,
    required this.scrim,
    required this.codeWell,
    required this.codeWellHeader,
    required this.codeWellBorder,
    required this.lineNumber,
    required this.comment,
    required this.nightTop,
    required this.nightBottom,
    required this.night,
    required this.nightLowest,
    required this.nightLow,
    required this.nightContainer,
    required this.nightHigh,
    required this.nightHighest,
    required this.paper,
    required this.paperMuted,
    required this.paperFaint,
    required this.paperGhost,
    required this.outlineDark,
    required this.ruleDark,
    required this.shadowNight,
    required this.slateLift,
    required this.onSlateLift,
    required this.smoke,
    required this.sheetDark,
    required this.codeWellDark,
    required this.codeWellHeaderDark,
    required this.codeWellBorderDark,
    required this.lineNumberDark,
    required this.commentDark,
    required this.terminal,
    required this.terminalKey,
  });

  final Color mistTop, mistBottom, mist, mistLowest, mistLow, mistContainer, mistHigh, mistHighest;
  final Color ink, inkMuted, inkFaint, inkGhost, outlineLight, ruleLight, shadowInk;
  final Color slate, slateContainer, inverseSurface, onInverseSurface, scrim;

  /// Light code well: floor, header bar, border, line numbers; code comments.
  final Color codeWell, codeWellHeader, codeWellBorder, lineNumber, comment;

  final Color nightTop, nightBottom, night, nightLowest, nightLow, nightContainer, nightHigh, nightHighest;
  final Color paper, paperMuted, paperFaint, paperGhost, outlineDark, ruleDark, shadowNight;
  final Color slateLift, onSlateLift;

  /// Dark glass: chrome's smoke grey, the sheet floor.
  final Color smoke, sheetDark;

  final Color codeWellDark, codeWellHeaderDark, codeWellBorderDark, lineNumberDark, commentDark;

  /// Terminal card (dark floor even in light mode) and its key background.
  final Color terminal, terminalKey;

  /// The hue the mist-blue neutrals sit on.
  static const baseHue = 266.0;

  /// Mist blue's neutrals (the [DshPalette] constants themselves).
  static const defaults = NeutralTones(
    mistTop: DshPalette.mistTop,
    mistBottom: DshPalette.mistBottom,
    mist: DshPalette.mist,
    mistLowest: DshPalette.mistLowest,
    mistLow: DshPalette.mistLow,
    mistContainer: DshPalette.mistContainer,
    mistHigh: DshPalette.mistHigh,
    mistHighest: DshPalette.mistHighest,
    ink: DshPalette.ink,
    inkMuted: DshPalette.inkMuted,
    inkFaint: DshPalette.inkFaint,
    inkGhost: DshPalette.inkGhost,
    outlineLight: DshPalette.outlineLight,
    ruleLight: DshPalette.ruleLight,
    shadowInk: DshPalette.shadowInk,
    slate: DshPalette.slate,
    slateContainer: DshPalette.slateContainer,
    inverseSurface: Color(0xFF252A35),
    onInverseSurface: Color(0xFFECEEF4),
    scrim: DshPalette.scrim,
    codeWell: Color(0xFFEDF0F6),
    codeWellHeader: Color(0xFFE7EBF3),
    codeWellBorder: Color(0xFFDBDEE5),
    lineNumber: Color(0xFF7D8088),
    comment: Color(0xFF636975),
    nightTop: DshPalette.nightTop,
    nightBottom: DshPalette.nightBottom,
    night: DshPalette.night,
    nightLowest: DshPalette.nightLowest,
    nightLow: DshPalette.nightLow,
    nightContainer: DshPalette.nightContainer,
    nightHigh: DshPalette.nightHigh,
    nightHighest: DshPalette.nightHighest,
    paper: DshPalette.paper,
    paperMuted: DshPalette.paperMuted,
    paperFaint: DshPalette.paperFaint,
    paperGhost: DshPalette.paperGhost,
    outlineDark: DshPalette.outlineDark,
    ruleDark: DshPalette.ruleDark,
    shadowNight: DshPalette.shadowNight,
    slateLift: DshPalette.slateLift,
    onSlateLift: DshPalette.onSlateLift,
    smoke: Color(0xFF292E39),
    sheetDark: Color(0xFF232832),
    codeWellDark: Color(0xFF14171E),
    codeWellHeaderDark: Color(0xFF1A1E26),
    codeWellBorderDark: Color(0xFF2F333A),
    lineNumberDark: Color(0xFF71747D),
    commentDark: Color(0xFF868C97),
    terminal: Color(0xFF12151C),
    terminalKey: Color(0xFF262A33),
  );

  static final _cache = <(double, double), NeutralTones>{};

  static NeutralTones forAccent(AppAccent accent) => of(tintHue: accent.tintHue, tintChroma: accent.tintChroma);

  /// The neutrals of the current theme's palette.
  static NeutralTones current(BuildContext context) =>
      forAccent(Theme.of(context).extension<DshSurfaces>()?.accent ?? AppAccent.mist);

  /// Moves a mist-tuned neutral onto [accent]'s tint (stray greys,
  /// e.g. the 「其他」 slice in charts).
  static Color tint(Color mistNeutral, AppAccent accent) =>
      retint(mistNeutral, hueShift: accent.tintHue - baseHue, chromaScale: accent.tintChroma);

  /// The whole neutral ramp rotated to [tintHue] with chroma multiplied by [tintChroma]. Results are cached per argument pair.
  static NeutralTones of({required double tintHue, required double tintChroma}) {
    if (tintHue == baseHue && tintChroma == 1) return defaults;
    return _cache.putIfAbsent((tintHue, tintChroma), () {
      if (_cache.length > 32) _cache.clear();
      final shift = tintHue - baseHue;
      Color t(Color c) => retint(c, hueShift: shift, chromaScale: tintChroma);
      const m = defaults;
      return NeutralTones(
        mistTop: t(m.mistTop),
        mistBottom: t(m.mistBottom),
        mist: t(m.mist),
        mistLowest: t(m.mistLowest),
        mistLow: t(m.mistLow),
        mistContainer: t(m.mistContainer),
        mistHigh: t(m.mistHigh),
        mistHighest: t(m.mistHighest),
        ink: t(m.ink),
        inkMuted: t(m.inkMuted),
        inkFaint: t(m.inkFaint),
        inkGhost: t(m.inkGhost),
        outlineLight: t(m.outlineLight),
        ruleLight: t(m.ruleLight),
        shadowInk: t(m.shadowInk),
        slate: t(m.slate),
        slateContainer: t(m.slateContainer),
        inverseSurface: t(m.inverseSurface),
        onInverseSurface: t(m.onInverseSurface),
        scrim: t(m.scrim),
        codeWell: t(m.codeWell),
        codeWellHeader: t(m.codeWellHeader),
        codeWellBorder: t(m.codeWellBorder),
        lineNumber: t(m.lineNumber),
        comment: t(m.comment),
        nightTop: t(m.nightTop),
        nightBottom: t(m.nightBottom),
        night: t(m.night),
        nightLowest: t(m.nightLowest),
        nightLow: t(m.nightLow),
        nightContainer: t(m.nightContainer),
        nightHigh: t(m.nightHigh),
        nightHighest: t(m.nightHighest),
        paper: t(m.paper),
        paperMuted: t(m.paperMuted),
        paperFaint: t(m.paperFaint),
        paperGhost: t(m.paperGhost),
        outlineDark: t(m.outlineDark),
        ruleDark: t(m.ruleDark),
        shadowNight: t(m.shadowNight),
        slateLift: t(m.slateLift),
        onSlateLift: t(m.onSlateLift),
        smoke: t(m.smoke),
        sheetDark: t(m.sheetDark),
        codeWellDark: t(m.codeWellDark),
        codeWellHeaderDark: t(m.codeWellHeaderDark),
        codeWellBorderDark: t(m.codeWellBorderDark),
        lineNumberDark: t(m.lineNumberDark),
        commentDark: t(m.commentDark),
        terminal: t(m.terminal),
        terminalKey: t(m.terminalKey),
      );
    });
  }
}

/// WCAG 2.x relative-luminance contrast ratio. For tests and runtime assertions.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}
