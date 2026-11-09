// Portions derived from PiPilot (https://github.com/CikeSeven/pi_pilot), MIT, Copyright (c) 2026 CikeSeven. See THIRD_PARTY_NOTICES.md.

import 'package:flutter/material.dart';

import 'accent.dart';
import 'palette.dart';

/// re_highlight scope → TextStyle map (the "Mist" theme, light and dark).
///
/// Keys are highlight.js scopes (no `hljs-` prefix).
///
/// Direction: **quiet colour**. One hue per role, chroma 0.09–0.13 (Xcode / GitHub
/// themes are around 0.2); lightness is levelled so every colour clears ≥ 4.5 against the code well — no token class stands out:
///
/// | Role | Hue | Light | Dark |
/// |---|---|---|---|
/// | keyword | purple 300° | #6A499B | #C4ACF2 |
/// | string | green 150° | #336F43 | #97D2A2 |
/// | number / literal | amber 62° | #90561A | #F2BB8A |
/// | comment (italic) | grey-blue | #636975 | #868C97 |
/// | function / title | blue 258° | #2C5CA3 | #95BDF8 |
/// | type / class / built_in | cyan 205° | #006E77 | #85CFD8 |
/// | attr / property | rose 15° | #97464F | #ECA4A9 |
/// | meta / decorators | earth 80° | #726042 | #BFAF95 |
///
/// Variables, parameters and punctuation get no colour (or just the secondary text colour) — a screenful of colour is noise.
///
/// Role hues are semantic and never follow the palette; the neutral slots —
/// body, comments, punctuation — track [accent]'s neutrals (same lightness, so contrast against the code well is unchanged).
Map<String, TextStyle> dshHighlightTheme(Brightness brightness, [AppAccent accent = AppAccent.mist]) {
  final dark = brightness == Brightness.dark;
  final base = dark ? _dark : _light;
  final n = NeutralTones.forAccent(accent);
  if (identical(n, NeutralTones.defaults)) return base;
  return _tinted.putIfAbsent((dark, n), () {
    if (_tinted.length > 16) _tinted.clear();
    final root = dark ? n.paper : n.ink;
    final comment = dark ? n.commentDark : n.comment;
    final punct = dark ? n.paperMuted : n.inkMuted;
    return {
      ...base,
      'root': TextStyle(color: root),
      'comment': TextStyle(color: comment, fontStyle: FontStyle.italic),
      'quote': TextStyle(color: comment, fontStyle: FontStyle.italic),
      'operator': TextStyle(color: punct),
      'punctuation': TextStyle(color: punct),
    };
  });
}

final _tinted = <(bool, NeutralTones), Map<String, TextStyle>>{};

const _light = <String, TextStyle>{
  'root': TextStyle(color: Color(0xFF1E232E)),
  'keyword': TextStyle(color: Color(0xFF6A499B)),
  'doctag': TextStyle(color: Color(0xFF6A499B)),
  'template-tag': TextStyle(color: Color(0xFF6A499B)),
  'selector-tag': TextStyle(color: Color(0xFF6A499B)),
  'name': TextStyle(color: Color(0xFF6A499B)),
  'string': TextStyle(color: Color(0xFF336F43)),
  'regexp': TextStyle(color: Color(0xFF336F43)),
  'meta-string': TextStyle(color: Color(0xFF336F43)),
  'char.escape_': TextStyle(color: Color(0xFF336F43)),
  'number': TextStyle(color: Color(0xFF90561A)),
  'literal': TextStyle(color: Color(0xFF90561A)),
  'symbol': TextStyle(color: Color(0xFF90561A)),
  'bullet': TextStyle(color: Color(0xFF90561A)),
  'comment': TextStyle(color: Color(0xFF636975), fontStyle: FontStyle.italic),
  'quote': TextStyle(color: Color(0xFF636975), fontStyle: FontStyle.italic),
  'title': TextStyle(color: Color(0xFF2C5CA3)),
  'title.function_': TextStyle(color: Color(0xFF2C5CA3)),
  'function': TextStyle(color: Color(0xFF2C5CA3)),
  'section': TextStyle(color: Color(0xFF2C5CA3), fontWeight: FontWeight.w600),
  'link': TextStyle(color: Color(0xFF2C5CA3), decoration: TextDecoration.underline),
  'title.class_': TextStyle(color: Color(0xFF006E77)),
  'class-title': TextStyle(color: Color(0xFF006E77)),
  'type': TextStyle(color: Color(0xFF006E77)),
  'built_in': TextStyle(color: Color(0xFF006E77)),
  'selector-class': TextStyle(color: Color(0xFF006E77)),
  'selector-id': TextStyle(color: Color(0xFF006E77)),
  'attr': TextStyle(color: Color(0xFF97464F)),
  'attribute': TextStyle(color: Color(0xFF97464F)),
  'property': TextStyle(color: Color(0xFF97464F)),
  'selector-attr': TextStyle(color: Color(0xFF97464F)),
  'selector-pseudo': TextStyle(color: Color(0xFF97464F)),
  'meta': TextStyle(color: Color(0xFF726042)),
  'meta keyword': TextStyle(color: Color(0xFF726042)),
  'operator': TextStyle(color: Color(0xFF4F5562)),
  'punctuation': TextStyle(color: Color(0xFF4F5562)),
  'addition': TextStyle(color: Color(0xFF1F613C), backgroundColor: Color(0xFFDCF4E3)),
  'deletion': TextStyle(color: Color(0xFF923A37), backgroundColor: Color(0xFFFFE4E2)),
  'emphasis': TextStyle(fontStyle: FontStyle.italic),
  'strong': TextStyle(fontWeight: FontWeight.bold),
};

const _dark = <String, TextStyle>{
  'root': TextStyle(color: Color(0xFFE6E9F0)),
  'keyword': TextStyle(color: Color(0xFFC4ACF2)),
  'doctag': TextStyle(color: Color(0xFFC4ACF2)),
  'template-tag': TextStyle(color: Color(0xFFC4ACF2)),
  'selector-tag': TextStyle(color: Color(0xFFC4ACF2)),
  'name': TextStyle(color: Color(0xFFC4ACF2)),
  'string': TextStyle(color: Color(0xFF97D2A2)),
  'regexp': TextStyle(color: Color(0xFF97D2A2)),
  'meta-string': TextStyle(color: Color(0xFF97D2A2)),
  'char.escape_': TextStyle(color: Color(0xFF97D2A2)),
  'number': TextStyle(color: Color(0xFFF2BB8A)),
  'literal': TextStyle(color: Color(0xFFF2BB8A)),
  'symbol': TextStyle(color: Color(0xFFF2BB8A)),
  'bullet': TextStyle(color: Color(0xFFF2BB8A)),
  'comment': TextStyle(color: Color(0xFF868C97), fontStyle: FontStyle.italic),
  'quote': TextStyle(color: Color(0xFF868C97), fontStyle: FontStyle.italic),
  'title': TextStyle(color: Color(0xFF95BDF8)),
  'title.function_': TextStyle(color: Color(0xFF95BDF8)),
  'function': TextStyle(color: Color(0xFF95BDF8)),
  'section': TextStyle(color: Color(0xFF95BDF8), fontWeight: FontWeight.w600),
  'link': TextStyle(color: Color(0xFF95BDF8), decoration: TextDecoration.underline),
  'title.class_': TextStyle(color: Color(0xFF85CFD8)),
  'class-title': TextStyle(color: Color(0xFF85CFD8)),
  'type': TextStyle(color: Color(0xFF85CFD8)),
  'built_in': TextStyle(color: Color(0xFF85CFD8)),
  'selector-class': TextStyle(color: Color(0xFF85CFD8)),
  'selector-id': TextStyle(color: Color(0xFF85CFD8)),
  'attr': TextStyle(color: Color(0xFFECA4A9)),
  'attribute': TextStyle(color: Color(0xFFECA4A9)),
  'property': TextStyle(color: Color(0xFFECA4A9)),
  'selector-attr': TextStyle(color: Color(0xFFECA4A9)),
  'selector-pseudo': TextStyle(color: Color(0xFFECA4A9)),
  'meta': TextStyle(color: Color(0xFFBFAF95)),
  'meta keyword': TextStyle(color: Color(0xFFBFAF95)),
  'operator': TextStyle(color: Color(0xFFB6BBC5)),
  'punctuation': TextStyle(color: Color(0xFFB6BBC5)),
  'addition': TextStyle(color: Color(0xFF98D5AC), backgroundColor: Color(0xFF1C3424)),
  'deletion': TextStyle(color: Color(0xFFF2A7A1), backgroundColor: Color(0xFF422423)),
  'emphasis': TextStyle(fontStyle: FontStyle.italic),
  'strong': TextStyle(fontWeight: FontWeight.bold),
};
