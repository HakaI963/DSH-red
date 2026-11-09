// Portions derived from PiPilot (https://github.com/CikeSeven/pi_pilot), MIT, Copyright (c) 2026 CikeSeven. See THIRD_PARTY_NOTICES.md.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../common/overscroll_forwarder.dart';
import '../../common/edge_fade.dart';
import '../../theme/theme.dart';

enum DiffLineKind { hunk, add, del, context, meta }

class DiffLine {
  const DiffLine(this.kind, this.text);
  final DiffLineKind kind;
  final String text;
}

/// Whether the text looks like a unified diff (an @@ hunk header, or +/- lines mixed after a ---/+++ file header).
bool looksLikeUnifiedDiff(String text) {
  if (text.contains(RegExp(r'^@@ -\d', multiLine: true))) return true;
  if (!text.contains(RegExp(r'^(---|\+\+\+) ', multiLine: true))) return false;
  var add = 0;
  var del = 0;
  for (final line in text.split('\n')) {
    if (line.startsWith('+') && !line.startsWith('+++')) add++;
    if (line.startsWith('-') && !line.startsWith('---')) del++;
  }
  return add + del >= 1;
}

List<DiffLine> parseUnifiedDiff(String text) {
  final lines = <DiffLine>[];
  for (final raw in text.split('\n')) {
    final kind = raw.startsWith('@@')
        ? DiffLineKind.hunk
        : raw.startsWith('+++') || raw.startsWith('---') || raw.startsWith('diff ') || raw.startsWith('index ')
        ? DiffLineKind.meta
        : raw.startsWith('+')
        ? DiffLineKind.add
        : raw.startsWith('-')
        ? DiffLineKind.del
        : DiffLineKind.context;
    lines.add(DiffLine(kind, raw));
  }
  while (lines.isNotEmpty && lines.last.kind == DiffLineKind.context && lines.last.text.isEmpty) {
    lines.removeLast();
  }
  return lines;
}

/// Line-level LCS diff (the old/new text fallback). Beyond scale it degrades to a whole-block replace.
List<DiffLine> computeLineDiff(String oldText, String newText) {
  final a = oldText.isEmpty ? <String>[] : oldText.split('\n');
  final b = newText.isEmpty ? <String>[] : newText.split('\n');
  if (a.length * b.length > 400 * 400) {
    return [
      for (final line in a) DiffLine(DiffLineKind.del, '-$line'),
      for (final line in b) DiffLine(DiffLineKind.add, '+$line'),
    ];
  }
  final dp = List.generate(a.length + 1, (_) => List<int>.filled(b.length + 1, 0));
  for (var i = a.length - 1; i >= 0; i--) {
    for (var j = b.length - 1; j >= 0; j--) {
      dp[i][j] = a[i] == b[j] ? dp[i + 1][j + 1] + 1 : math.max(dp[i + 1][j], dp[i][j + 1]);
    }
  }
  final lines = <DiffLine>[];
  var i = 0;
  var j = 0;
  while (i < a.length && j < b.length) {
    if (a[i] == b[j]) {
      lines.add(DiffLine(DiffLineKind.context, ' ${a[i]}'));
      i++;
      j++;
    } else if (dp[i + 1][j] >= dp[i][j + 1]) {
      lines.add(DiffLine(DiffLineKind.del, '-${a[i]}'));
      i++;
    } else {
      lines.add(DiffLine(DiffLineKind.add, '+${b[j]}'));
      j++;
    }
  }
  while (i < a.length) {
    lines.add(DiffLine(DiffLineKind.del, '-${a[i]}'));
    i++;
  }
  while (j < b.length) {
    lines.add(DiffLine(DiffLineKind.add, '+${b[j]}'));
    j++;
  }
  return lines;
}

/// Added / removed line counts (the `+18 −4` at a tool row's tail).
({int added, int removed}) diffStats(List<DiffLine> lines) {
  var added = 0;
  var removed = 0;
  for (final line in lines) {
    if (line.kind == DiffLineKind.add) added++;
    if (line.kind == DiffLineKind.del) removed++;
  }
  return (added: added, removed: removed);
}

/// The colored diff: added/removed lines tinted whole, @@ hunk headers a sheer bottom, horizontal scrolling.
class DiffView extends StatelessWidget {
  const DiffView({super.key, this.diffText, this.lines, this.maxHeight, this.embedded = false})
    : assert(diffText != null || lines != null);

  final String? diffText;
  final List<DiffLine>? lines;
  final double? maxHeight;

  /// Embedded in a tool row's details: no frame (the outer layer already has the well bottom).
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final dsh = DshColors.of(context);
    final colors = Theme.of(context).colorScheme;
    final parsed = lines ?? parseUnifiedDiff(diffText!);
    final style = AppType.mono(size: 12, height: 1.5);

    Widget row(DiffLine line) {
      final (bg, fg) = switch (line.kind) {
        DiffLineKind.add => (dsh.diffAddBg, dsh.diffAddFg),
        DiffLineKind.del => (dsh.diffDelBg, dsh.diffDelFg),
        DiffLineKind.hunk => (dsh.codeWellHeader, dsh.diffHunkFg),
        DiffLineKind.meta => (null, colors.onSurfaceVariant),
        DiffLineKind.context => (null, dsh.codeWellFg),
      };
      return Container(
        color: bg,
        // 12: aligned with the small title ("Changes") left edge in tool details.
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(line.text.isEmpty ? ' ' : line.text, style: style.copyWith(color: fg), softWrap: false),
      );
    }

    Widget body = LayoutBuilder(
      builder: (context, constraints) => HorizontalEdgeFade(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: IntrinsicWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: embedded ? 4 : 8),
                  for (final line in parsed) row(line),
                  SizedBox(height: embedded ? 12 : 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (maxHeight != null) {
      body = ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight!),
        child: OverscrollForwarder(child: SingleChildScrollView(child: body)),
      );
    }
    if (embedded) return body;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: dsh.codeWellBg,
          shape: RoundedSuperellipseBorder(
            borderRadius: AppShape.radiusMd,
            side: BorderSide(color: dsh.codeWellBorder, width: 0.5),
          ),
        ),
        child: Squircle.clip(radius: AppShape.md, child: body),
      ),
    );
  }
}
