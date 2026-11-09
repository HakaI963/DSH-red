// Portions derived from PiPilot (https://github.com/CikeSeven/pi_pilot), MIT, Copyright (c) 2026 CikeSeven. See THIRD_PARTY_NOTICES.md.

import 'package:flutter/material.dart';

import '../../theme/semantic_colors.dart';

/// CSI sequence (ESC[ ... final byte). Everything non-SGR (final byte ≠ m) is stripped, never rendered.
final _csi = RegExp('\x1B\\[([0-9;?]*)([A-Za-z])');

/// OSC sequence (ESC] ... BEL / ESC\), e.g. terminal title, hyperlinks. Stripped outright.
final _osc = RegExp('\x1B\\][^\x07\x1B]*(?:\x07|\x1B\\\\)');

/// Strip all ANSI escapes (for copy / plain-text use).
String stripAnsi(String input) => input.replaceAll(_osc, '').replaceAll(_csi, '');

/// Whether the text holds any ANSI escapes (if none, take the plain-text fast path).
bool hasAnsi(String input) => input.contains('\x1B');

class _SgrState {
  Color? fg;
  Color? bg;
  bool bold = false;
  bool italic = false;
  bool underline = false;

  void reset() {
    fg = null;
    bg = null;
    bold = false;
    italic = false;
    underline = false;
  }

  TextStyle apply(TextStyle base) => base.copyWith(
    color: fg ?? base.color,
    backgroundColor: bg ?? base.backgroundColor,
    fontWeight: bold ? FontWeight.w600 : base.fontWeight,
    fontStyle: italic ? FontStyle.italic : base.fontStyle,
    decoration: underline ? TextDecoration.underline : base.decoration,
  );
}

/// Parse SGR-colored text into TextSpans. [ansi16] is the palette for SGR 30-37 / 90-97.
TextSpan parseAnsi(String input, TextStyle base, List<Color> ansi16) {
  final source = input.replaceAll(_osc, '');
  if (!hasAnsi(source)) return TextSpan(text: source, style: base);
  final children = <TextSpan>[];
  final sgr = _SgrState();
  var last = 0;
  void flushText(int end) {
    if (end > last) {
      children.add(TextSpan(text: source.substring(last, end), style: sgr.apply(base)));
    }
  }

  for (final m in _csi.allMatches(source)) {
    flushText(m.start);
    last = m.end;
    if (m[2] != 'm') continue;
    final params = (m[1]!.isEmpty ? '0' : m[1]!).split(';').map((s) => int.tryParse(s) ?? 0).toList();
    var i = 0;
    while (i < params.length) {
      final code = params[i];
      switch (code) {
        case 0:
          sgr.reset();
        case 1:
          sgr.bold = true;
        case 3:
          sgr.italic = true;
        case 4:
          sgr.underline = true;
        case 22:
          sgr.bold = false;
        case 23:
          sgr.italic = false;
        case 24:
          sgr.underline = false;
        case 39:
          sgr.fg = null;
        case 49:
          sgr.bg = null;
        case >= 30 && <= 37:
          sgr.fg = ansi16[code - 30];
        case >= 90 && <= 97:
          sgr.fg = ansi16[code - 82];
        case >= 40 && <= 47:
          sgr.bg = ansi16[code - 40].withValues(alpha: 0.18);
        case >= 100 && <= 107:
          sgr.bg = ansi16[code - 92].withValues(alpha: 0.18);
        case 38 || 48:
          final (color, consumed) = _extendedColor(params, i, ansi16);
          if (code == 38) {
            sgr.fg = color ?? sgr.fg;
          } else {
            sgr.bg = color?.withValues(alpha: 0.18) ?? sgr.bg;
          }
          i += consumed;
        default:
          break;
      }
      i++;
    }
  }
  flushText(source.length);
  return TextSpan(style: base, children: children);
}

/// 38;5;n (xterm256) / 38;2;r;g;b (truecolor). Returns (color, extra parameters consumed).
(Color?, int) _extendedColor(List<int> params, int i, List<Color> ansi16) {
  if (i + 1 >= params.length) return (null, 0);
  switch (params[i + 1]) {
    case 5:
      if (i + 2 >= params.length) return (null, 1);
      return (_xterm256(params[i + 2], ansi16), 2);
    case 2:
      if (i + 4 >= params.length) return (null, params.length - i - 1);
      return (
        Color.fromARGB(255, params[i + 2].clamp(0, 255), params[i + 3].clamp(0, 255), params[i + 4].clamp(0, 255)),
        4,
      );
    default:
      return (null, 0);
  }
}

Color? _xterm256(int n, List<Color> ansi16) {
  if (n < 0 || n > 255) return null;
  if (n < 16) return ansi16[n];
  if (n < 232) {
    // 6×6×6 color cube
    final v = n - 16;
    const steps = [0, 95, 135, 175, 215, 255];
    return Color.fromARGB(255, steps[v ~/ 36], steps[(v % 36) ~/ 6], steps[v % 6]);
  }
  final gray = 8 + (n - 232) * 10;
  return Color.fromARGB(255, gray, gray, gray);
}

/// Selectable text with ANSI coloring; parse results memoized by (text, palette).
///
/// Only ever lay this on a code well ([DshColors.codeWellBg]): the ANSI palette is tuned for contrast against the well bottom.
class AnsiText extends StatefulWidget {
  const AnsiText({super.key, required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  State<AnsiText> createState() => _AnsiTextState();
}

class _AnsiTextState extends State<AnsiText> {
  TextSpan? _span;
  String? _parsedText;
  TextStyle? _parsedStyle;
  List<Color>? _parsedPalette;

  @override
  Widget build(BuildContext context) {
    final palette = DshColors.of(context).ansi;
    if (_span == null ||
        _parsedText != widget.text ||
        _parsedStyle != widget.style ||
        !identical(_parsedPalette, palette)) {
      _span = parseAnsi(widget.text, widget.style, palette);
      _parsedText = widget.text;
      _parsedStyle = widget.style;
      _parsedPalette = palette;
    }
    return SelectableText.rich(_span!);
  }
}
