// Portions derived from PiPilot (https://github.com/CikeSeven/pi_pilot), MIT, Copyright (c) 2026 CikeSeven. See THIRD_PARTY_NOTICES.md.

import 'package:flutter/material.dart';

import 'squircle.dart';

/// Corner-radius vocabulary: **five steps + pill**, all continuous curvature.
///
/// Adjacent steps differ by about 1.4x — clearly distinct to the eye — and each step has a fixed use:
///
/// | Step | Radius | Used for |
/// |---|---|---|
/// | xs | 6 | inline code, badges, progress-bar caps |
/// | sm | 10 | Chips, tool icon tiles, small buttons, menu-item highlights |
/// | md | 14 | cards, code wells, text fields, menus, primary buttons |
/// | lg | 20 | user bubbles, approval cards, settings group cards |
/// | xl | 28 | composer, bottom sheets, dialogs |
/// | pill | — | top-bar capsules, model capsules, send key, thinking pill (StadiumBorder) |
///
/// DSH official web uses 4/8/12/16/20/28 (panel = 28); this scales the ladder up a
/// little for touch, but keeps 28 as the outermost container radius, matching the official composer.
abstract final class AppShape {
  static const xs = 6.0;
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 20.0;
  static const xl = 28.0;

  static const radiusXs = BorderRadius.all(Radius.circular(xs));
  static const radiusSm = BorderRadius.all(Radius.circular(sm));
  static const radiusMd = BorderRadius.all(Radius.circular(md));
  static const radiusLg = BorderRadius.all(Radius.circular(lg));
  static const radiusXl = BorderRadius.all(Radius.circular(xl));

  /// Cards / code wells / menus.
  static const card = SquircleBorder(borderRadius: radiusMd);

  /// User bubbles / approval cards.
  static const bubble = SquircleBorder(borderRadius: radiusLg);

  /// Dialogs / composer.
  static const dialog = SquircleBorder(borderRadius: radiusXl);

  /// Bottom sheet: only the top two corners.
  static const sheet = SquircleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(xl)));

  /// Pill (radius follows height, always a half-round end cap).
  static const pill = StadiumBorder();

  /// Continuous corner with a hairline stroke.
  static SquircleBorder outlined(Color color, {double radius = md, double width = 1}) => SquircleBorder(
    borderRadius: BorderRadius.all(Radius.circular(radius)),
    side: BorderSide(color: color, width: width),
  );
}

/// Spacing ladder (mostly multiples of 4; 2/6 for tight inline rows).
///
/// Page side padding 16 (phone); between messages 8 within a turn, 24 across turns; card padding 14–16.
abstract final class AppSpace {
  static const xxs = 2.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;

  /// Page horizontal padding.
  static const gutter = 16.0;

  /// Vertical spacing inside one turn (tool rows ↔ body text).
  static const inTurn = 8.0;

  /// Vertical spacing across turns (previous answer → next user message).
  static const betweenTurns = 24.0;

  /// Max reading width for body text (centred on tablets / landscape / unfolded foldables).
  /// Same tier as DSH official's `--dsh-chat-content-width: 748px`.
  static const readingWidth = 720.0;

  /// Distance from each side of the reading column for controls floating over it (composer,
  /// todo / goal bars, slash panel, empty-state suggestions): 12 like phone screen edges, so each is 4 wider than the text.
  static const floatInset = 12.0;

  /// Max width of those controls: the reading column minus [floatInset] on both sides.
  static const floatingWidth = readingWidth - 2 * floatInset;
}
