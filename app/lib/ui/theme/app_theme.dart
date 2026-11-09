// Portions derived from PiPilot (https://github.com/CikeSeven/pi_pilot), MIT, Copyright (c) 2026 CikeSeven. See THIRD_PARTY_NOTICES.md.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'accent.dart';
import 'app_icons.dart';
import 'ink_glow.dart';
import 'page_transitions.dart';
import 'palette.dart';
import 'semantic_colors.dart';
import 'shapes.dart';
import 'squircle.dart';
import 'surfaces.dart';
import 'typography.dart';

/// Light theme.
///
/// [accent] is the whole palette (accent plus the neutral tint) — see `accent.dart`.
/// Turning [glassBlur] off makes every glass use a near-opaque fill (the "减少透明效果"
/// setting, or when the performance probe judges the device low-end).
///
/// [glyphLocale] pins the locale CJK glyphs are picked by (the English UI
/// passes zh_CN so Chinese content keeps Chinese shapes).
///
/// [instantPages] makes secondary pages push / pop with no duration (when the animation switch is off).
///
/// [fluid] is the fluid-motion mode: the default ripple becomes a press glow ([AppInkGlow]).
ThemeData buildLightTheme({
  AppAccent accent = AppAccent.mist,
  bool glassBlur = true,
  Locale? glyphLocale,
  bool instantPages = false,
  bool fluid = false,
}) => _build(
  DshPalette.lightScheme(accent),
  DshColors.forAccent(Brightness.light, accent),
  DshSurfaces.light(accent, blurEnabled: glassBlur),
  accent,
  glyphLocale,
  instantPages,
  fluid,
);

/// Dark theme.
ThemeData buildDarkTheme({
  AppAccent accent = AppAccent.mist,
  bool glassBlur = true,
  Locale? glyphLocale,
  bool instantPages = false,
  bool fluid = false,
}) => _build(
  DshPalette.darkScheme(accent),
  DshColors.forAccent(Brightness.dark, accent),
  DshSurfaces.dark(accent, blurEnabled: glassBlur),
  accent,
  glyphLocale,
  instantPages,
  fluid,
);

/// Edge-to-edge system bar style: status and navigation bars fully transparent, icons follow the brightness.
///
/// Pages that draw their own top bar (the chat page has no AppBar) must wrap themselves in
/// `AnnotatedRegion<SystemUiOverlayStyle>(value: dshSystemOverlay(...))`,
/// and `main()` must call `SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge)`.
SystemUiOverlayStyle dshSystemOverlay(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    statusBarBrightness: dark ? Brightness.dark : Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    systemNavigationBarContrastEnforced: false,
    systemStatusBarContrastEnforced: false,
  );
}

/// The mist-blue glass theme. Three iron rules:
///
/// 1. **Hierarchy comes from material, not shadow.** The page is a gradient; things floating
///    over content (top bar, composer, sheets) are real blurred glass, things lying on the
///    page (cards, capsules) are translucent white; M3 elevation is always 0 and `surfaceTint` transparent. The only shadow is on the glass rim, and faint.
/// 2. **Hairlines are the skeleton.** Cards, Chips, fields and dialogs all carry a 0.5–1px line;
///    it is quieter than shadow and, on a light mist-blue base, clearer than a solid block.
/// 3. **Continuous corners.** Everything goes through `AppShape`'s five steps + pill; never hand-write radii.
ThemeData _build(
  ColorScheme scheme,
  DshColors colors,
  DshSurfaces surfaces,
  AppAccent accent,
  Locale? glyphLocale,
  bool instantPages,
  bool fluid,
) {
  // iOS-style horizontal push, the outgoing page sliding left and dimming; the system predictive back and the edge
  // right-swipe both track the finger (see page_transitions.dart). One builder for every platform — secondary pages' look is decided here alone.
  final pages = instantPages
      ? const AppPageTransitionsBuilder.instant()
      : fluid
      ? const AppPageTransitionsBuilder.fluid()
      : const AppPageTransitionsBuilder();
  final transitions = PageTransitionsTheme(builders: {for (final platform in TargetPlatform.values) platform: pages});

  final isDark = scheme.brightness == Brightness.dark;
  final hairline = scheme.outlineVariant;
  // Switch knob: normally one light knob. When the primary itself is near-white (graphite in dark mode) the on-state
  // track and a light knob blur into one, so on uses a dark ink knob on the primary and puts the primary back in the check.
  final lightKnob = isDark ? scheme.onSurface : Colors.white;
  final knobBlends = contrastRatio(lightKnob, scheme.primary) < 1.6;
  final onKnob = knobBlends ? scheme.onPrimary : lightKnob;
  final checkOn = knobBlends ? scheme.primary : (isDark ? scheme.inversePrimary : scheme.primary);
  final textTheme = AppType.withGlyphLocale(
    AppType.textTheme,
    glyphLocale,
  ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
  // Field / Chip fill: the same value as the card glass, so forms read as growing out of the page.
  final fieldFill = surfaces.card.fallbackFill;
  // Popups (dialogs, menus) use an opaque surface: they sit on a scrim — no need to see through, and they shouldn't.
  final popupFill = isDark ? scheme.surfaceContainerHigh : scheme.surfaceContainerLowest;

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    canvasColor: scheme.surface,
    textTheme: textTheme,
    extensions: [colors, surfaces],
    pageTransitionsTheme: transitions,
    visualDensity: VisualDensity.standard,
    // Ripples stay, but more restrained.
    splashFactory: fluid ? AppInkGlow.splashFactory : null,
    splashColor: scheme.primary.withValues(alpha: 0.08),
    highlightColor: scheme.primary.withValues(alpha: 0.04),
    hoverColor: scheme.onSurface.withValues(alpha: 0.04),
    focusColor: scheme.primary.withValues(alpha: 0.12),
    iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 22),

    // Top bar transparent: the page background is the app bar's background; glass or a hairline provides separation where needed.
    appBarTheme: AppBarThemeData(
      backgroundColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      titleTextStyle: textTheme.titleMedium?.copyWith(fontSize: 17),
      systemOverlayStyle: dshSystemOverlay(scheme.brightness),
    ),

    // Card = translucent white glass (no blur) + 0.5px hairline + zero shadow.
    cardTheme: CardThemeData(
      color: surfaces.card.fill,
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: AppShape.outlined(hairline, width: 0.5),
    ),

    // Text field: a sliver of glass growing out of the page. Stroke uses outline (≥ 3:1, WCAG 1.4.11),
    // switching to the primary on focus.
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: fieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: AppShape.radiusMd,
        borderSide: BorderSide(color: scheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppShape.radiusMd,
        borderSide: BorderSide(color: scheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppShape.radiusMd,
        borderSide: BorderSide(color: scheme.primary, width: 1.6),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: AppShape.radiusMd,
        borderSide: BorderSide(color: hairline),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppShape.radiusMd,
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppShape.radiusMd,
        borderSide: BorderSide(color: scheme.error, width: 1.6),
      ),
      hintStyle: TextStyle(color: colors.textTertiary),
      labelStyle: TextStyle(color: scheme.onSurfaceVariant),
      floatingLabelStyle: TextStyle(color: scheme.primary),
      helperStyle: TextStyle(color: colors.textTertiary),
      prefixIconColor: scheme.onSurfaceVariant,
      suffixIconColor: scheme.onSurfaceVariant,
    ),

    // Primary button: solid primary + continuous corner (not a pill). Pressing deepens one step, not just a ripple.
    filledButtonTheme: FilledButtonThemeData(
      style:
          // No background here: a theme colour would override every
          // FilledButton.tonal too (they would render as solid primary). The
          // variants' own defaults give primary / secondaryContainer.
          FilledButton.styleFrom(
            minimumSize: const Size(64, 50),
            padding: const EdgeInsets.symmetric(horizontal: 24),
            elevation: 0,
            shape: AppShape.card,
            textStyle: textTheme.labelLarge?.copyWith(fontSize: 15),
          ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(64, 50),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        elevation: 0,
        backgroundColor: fieldFill,
        foregroundColor: scheme.onSurface,
        shape: AppShape.outlined(hairline),
        textStyle: textTheme.labelLarge?.copyWith(fontSize: 15),
      ),
    ),

    // Secondary button: the stroke is 40% of outline — visible on cards and popups alike, yet quieter
    // than the primary (the hairline colour nearly matches a light popup's fill). Disabled halves the stroke.
    outlinedButtonTheme: OutlinedButtonThemeData(
      style:
          OutlinedButton.styleFrom(
            minimumSize: const Size(64, 50),
            padding: const EdgeInsets.symmetric(horizontal: 22),
            foregroundColor: scheme.onSurface,
            shape: AppShape.card,
            textStyle: textTheme.labelLarge?.copyWith(fontSize: 15),
          ).copyWith(
            side: WidgetStateProperty.resolveWith(
              (states) => BorderSide(
                color: scheme.outline.withValues(alpha: states.contains(WidgetState.disabled) ? 0.2 : 0.4),
              ),
            ),
          ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 40),
        foregroundColor: scheme.primary,
        shape: Squircle.border(AppShape.sm),
        textStyle: textTheme.labelLarge,
      ),
    ),

    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(44, 44), foregroundColor: scheme.onSurfaceVariant),
    ),

    chipTheme: ChipThemeData(
      shape: Squircle.border(AppShape.sm),
      side: BorderSide(color: hairline),
      backgroundColor: fieldFill,
      selectedColor: scheme.primaryContainer,
      checkmarkColor: scheme.onPrimaryContainer,
      labelStyle: textTheme.labelMedium?.copyWith(color: scheme.onSurface),
      secondaryLabelStyle: textTheme.labelMedium?.copyWith(color: scheme.onPrimaryContainer),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    ),

    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: fieldFill,
        selectedBackgroundColor: scheme.primaryContainer,
        selectedForegroundColor: scheme.onPrimaryContainer,
        foregroundColor: scheme.onSurfaceVariant,
        side: BorderSide(color: hairline),
        minimumSize: const Size(0, 44),
        shape: Squircle.border(AppShape.sm),
      ),
    ),

    searchBarTheme: SearchBarThemeData(
      elevation: const WidgetStatePropertyAll(0),
      backgroundColor: WidgetStatePropertyAll(fieldFill),
      surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      shape: WidgetStatePropertyAll(AppShape.outlined(hairline, radius: AppShape.md)),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16)),
      hintStyle: WidgetStatePropertyAll(textTheme.bodyLarge?.copyWith(color: colors.textTertiary)),
      constraints: const BoxConstraints(minHeight: 48),
    ),

    // Badge defaults to the primary: the default error red makes "current" read like a failure.
    badgeTheme: BadgeThemeData(
      backgroundColor: scheme.primary,
      textColor: scheme.onPrimary,
      largeSize: 18,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      textStyle: AppType.tabular(textTheme.labelSmall!.copyWith(fontWeight: FontWeight.w600)),
    ),

    // Expansion tiles draw no frame: they usually already sit inside a card.
    expansionTileTheme: ExpansionTileThemeData(
      shape: const Border(),
      collapsedShape: const Border(),
      backgroundColor: Colors.transparent,
      collapsedBackgroundColor: Colors.transparent,
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding: const EdgeInsets.only(bottom: 8),
      iconColor: scheme.onSurfaceVariant,
      collapsedIconColor: scheme.onSurfaceVariant,
    ),

    dialogTheme: DialogThemeData(
      // Material's 560 cap: a confirm keeps its shape on a tablet.
      constraints: const BoxConstraints(minWidth: 280, maxWidth: 560),
      elevation: 0,
      backgroundColor: popupFill,
      surfaceTintColor: Colors.transparent,
      barrierColor: surfaces.scrim,
      shape: AppShape.outlined(hairline, radius: AppShape.xl, width: 0.5),
      titleTextStyle: textTheme.headlineSmall,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
    ),

    // Sheets are opaque by default; for a glass sheet use `showAppSheet(glass: true)` from
    // common/app_sheet.dart (transparent background + GlassSurface).
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: surfaces.sheet.fallbackFill,
      modalBackgroundColor: surfaces.sheet.fallbackFill,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      modalElevation: 0,
      modalBarrierColor: surfaces.scrim,
      dragHandleColor: scheme.onSurfaceVariant.withValues(alpha: 0.35),
      dragHandleSize: const Size(36, 4),
      clipBehavior: Clip.antiAlias,
      shape: AppShape.sheet,
      showDragHandle: true,
    ),

    snackBarTheme: SnackBarThemeData(
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: scheme.onInverseSurface),
      actionTextColor: scheme.inversePrimary,
      insetPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      shape: AppShape.card,
    ),

    dividerTheme: DividerThemeData(color: hairline, thickness: 0.5, space: 1),

    // The 2024 M3 progress indicator (gapped track + end caps), a thin primary bar.
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.primary.withValues(alpha: 0.16),
      circularTrackColor: scheme.primary.withValues(alpha: 0.16),
      stopIndicatorColor: scheme.primary,
      linearMinHeight: 4,
      borderRadius: AppShape.radiusXs,
      // ignore: deprecated_member_use
      year2023: false,
    ),

    popupMenuTheme: PopupMenuThemeData(
      color: popupFill,
      surfaceTintColor: Colors.transparent,
      elevation: 2,
      shadowColor: scheme.shadow.withValues(alpha: 0.5),
      shape: AppShape.outlined(hairline, width: 0.5),
      textStyle: textTheme.bodyMedium,
    ),

    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(popupFill),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        elevation: const WidgetStatePropertyAll(2),
        shadowColor: WidgetStatePropertyAll(scheme.shadow.withValues(alpha: 0.5)),
        shape: WidgetStatePropertyAll(AppShape.outlined(hairline, width: 0.5)),
      ),
    ),

    listTileTheme: ListTileThemeData(
      iconColor: scheme.onSurfaceVariant,
      titleTextStyle: textTheme.bodyLarge,
      subtitleTextStyle: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      selectedColor: scheme.onPrimaryContainer,
      selectedTileColor: scheme.primaryContainer,
      minVerticalPadding: 10,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      shape: AppShape.card,
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      shape: AppShape.bubble,
    ),

    // Drawer defaults to the opaque fallback; the session drawer paints itself with sheet glass.
    drawerTheme: DrawerThemeData(
      backgroundColor: surfaces.sheet.fallbackFill,
      surfaceTintColor: Colors.transparent,
      scrimColor: surfaces.scrim,
      elevation: 0,
      width: 320,
      shape: const SquircleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(AppShape.xl),
          bottomRight: Radius.circular(AppShape.xl),
        ),
      ),
    ),

    // Bottom bar transparent: the shell seats it inside chrome glass.
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      indicatorColor: scheme.primaryContainer,
      indicatorShape: const StadiumBorder(),
      elevation: 0,
      height: 64,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: states.contains(WidgetState.selected) ? scheme.onSurface : scheme.onSurfaceVariant,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 22,
          color: states.contains(WidgetState.selected) ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
        ),
      ),
    ),

    tabBarTheme: TabBarThemeData(
      labelColor: scheme.onSurface,
      unselectedLabelColor: scheme.onSurfaceVariant,
      indicatorColor: scheme.primary,
      dividerColor: Colors.transparent,
      labelStyle: textTheme.titleSmall,
      unselectedLabelStyle: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w400),
    ),

    // iOS-style switch: both states share one light round knob; on = primary track, off = a visible
    // neutral track. Disabled starts no new palette — the whole control fades, set instantly apart from "off".
    switchTheme: SwitchThemeData(
      // The off state gets a transparent icon too: M3 only draws the off knob as big as the on one when there is an icon.
      // The check uses one step deeper than the primary (the dark theme's primary is too light on a pale knob).
      thumbIcon: WidgetStateProperty.resolveWith(
        (states) => Icon(
          AppIcons.selected,
          size: 14,
          color: states.contains(WidgetState.selected)
              ? checkOn.withValues(alpha: states.contains(WidgetState.disabled) ? 0.5 : 1)
              : Colors.transparent,
        ),
      ),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      trackColor: WidgetStateProperty.resolveWith((states) {
        final disabled = states.contains(WidgetState.disabled);
        if (states.contains(WidgetState.selected)) {
          return scheme.primary.withValues(alpha: disabled ? 0.38 : 1);
        }
        // The off track is about 1.5:1 on a card: recognisable as a switch, not like a disabled one.
        return scheme.onSurface.withValues(alpha: disabled ? 0.09 : 0.22);
      }),
      thumbColor: WidgetStateProperty.resolveWith((states) {
        final knob = states.contains(WidgetState.selected) ? onKnob : lightKnob;
        if (!states.contains(WidgetState.disabled)) return knob;
        return knob.withValues(alpha: isDark ? 0.5 : 0.8);
      }),
    ),

    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: scheme.inverseSurface, borderRadius: AppShape.radiusSm),
      textStyle: textTheme.bodySmall?.copyWith(color: scheme.onInverseSurface),
      waitDuration: const Duration(milliseconds: 400),
    ),

    textSelectionTheme: TextSelectionThemeData(
      cursorColor: scheme.primary,
      selectionColor: scheme.primary.withValues(alpha: isDark ? 0.28 : 0.24),
      selectionHandleColor: scheme.primary,
    ),

    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStatePropertyAll(scheme.onSurfaceVariant.withValues(alpha: 0.35)),
      radius: const Radius.circular(999),
      thickness: const WidgetStatePropertyAll(4),
      crossAxisMargin: 2,
    ),
  );
}
