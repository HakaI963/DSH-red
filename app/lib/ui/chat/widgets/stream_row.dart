// The one anatomy every "process" row of a turn shares (thinking, tool calls,
// tool groups, the folded turn, slash commands, notices), so they line up on
// the same two columns as the answer text.

import 'package:flutter/material.dart';

import '../../common/bleed.dart';
import '../../theme/app_icons.dart';
import '../../theme/theme.dart';

/// Process-row geometry: **left 24 glyph column + 8 gap + text column**, aligned with the body's left edge.
///
/// ```
/// |▣ run · flutter test            ◌|   ← glyph hugs the body's left edge, the row tail hugs the right
/// |│ (expanded content starts at 32)   |   ← hairline at the glyph midline x=12
/// ```
///
/// Press highlight overflows [bleed] past each side (see [Bleed]); the content itself is not indented.
abstract final class StreamRow {
  /// The glyph column's width (tool icon blocks, the thinking glyph, status icons all center inside it).
  static const lead = 24.0;

  /// Between glyph and text.
  static const gap = 8.0;

  /// Where the text column starts; expanded content begins here.
  static const indent = lead + gap;

  /// Single line's minimum height (24 glyph + 4 top and bottom).
  static const minHeight = 32.0;

  /// How far the press highlight spills outside the body text.
  static const bleed = 8.0;

  /// Row labels (verb, summary): secondary color, size 14 — process sits a notch quieter than answers.
  static TextStyle? label(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium
          ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.3);

  /// Inline detail (commands, paths, previews): tertiary color, size 13.
  static TextStyle? detail(BuildContext context) =>
      Theme.of(context).textTheme.bodySmall
          ?.copyWith(fontSize: 13, color: DshColors.of(context).textTertiary, height: 1.3);
}

/// One process row's shell: at least 32 tall, 4 top/bottom, press highlight spilling 8 each side.
class StreamRowFrame extends StatelessWidget {
  const StreamRowFrame({super.key, required this.child, this.onTap, this.onLongPress});

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: StreamRow.minHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: StreamRow.bleed, vertical: 4),
        child: child,
      ),
    );
    return Bleed(
      horizontal: StreamRow.bleed,
      child: onTap == null && onLongPress == null
          ? content
          : InkWell(onTap: onTap, onLongPress: onLongPress, customBorder: Squircle.border(AppShape.sm), child: content),
    );
  }
}

/// One cell of the glyph column: 24×24, child centered.
class StreamLead extends StatelessWidget {
  const StreamLead({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: StreamRow.lead,
    child: Center(child: child),
  );
}

/// The row-tail expand chevron: pointing down when folded, up when expanded, turning on the same curve as the collapse.
class StreamChevron extends StatelessWidget {
  const StreamChevron({super.key, required this.open});

  final bool open;

  @override
  Widget build(BuildContext context) => AnimatedRotation(
    turns: open ? 0.5 : 0,
    duration: AppMotion.of(context, AppMotion.collapse),
    curve: AppMotion.collapseCurve,
    child: Icon(AppIcons.expand, size: 16, color: DshColors.of(context).textTertiary),
  );
}

/// Expanded content: a 1px hairline at left on the glyph column's midline (x = 12), content starting at the text column.
///
/// Says "these belong to the row above" (full thinking text, each call inside a tool group, a collapsed turn).
class StreamThread extends StatelessWidget {
  const StreamThread({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.outlineVariant;
    return CustomPaint(
      painter: _RailPainter(color.withValues(alpha: 0.8)),
      child: Padding(
        padding: const EdgeInsets.only(left: StreamRow.indent),
        child: child,
      ),
    );
  }
}

class _RailPainter extends CustomPainter {
  _RailPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.height <= 8) return;
    const x = StreamRow.lead / 2;
    canvas.drawLine(
      const Offset(x, 4),
      Offset(x, size.height - 4),
      Paint()
        ..color = color
        ..strokeWidth = 1
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RailPainter old) => old.color != color;
}

/// The interpunct between verb and summary (3dp, vertically centered, 6 on each side).
class StreamDot extends StatelessWidget {
  const StreamDot({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6),
    child: SizedBox.square(
      dimension: 3,
      child: DecoratedBox(
        decoration: BoxDecoration(color: DshColors.of(context).textTertiary, shape: BoxShape.circle),
      ),
    ),
  );
}
