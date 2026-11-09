// The shared make-up of the bars docked above the composer (todo, goal),
// sized to stack with the activity strip.

import 'package:flutter/material.dart';

import '../../common/expand_reveal.dart';
import '../../pets/pet_perch.dart';
import '../../theme/theme.dart';

/// A group of bars docked above the input bar: same height, font size and side margins as the thinking pill, stacked
/// upward one after another with [gap] between.
///
/// ```
/// ( ☑  3/7 · now: run tests             ▰▰▱  ˄ )   todo
/// ( ⚑  Goal  migrate login to the new API…  ⋯ )   goal
/// ( 🐋 run  flutter test test/auth          0:19 )   thinking pill
/// [ +  Message DSH…                       🎤 ]    input bar
/// ```
///
/// Both ends' glyphs sit in a [glyph]-square cell, the cell [edge] from the pill's edge:
/// the glyph's center lands exactly on the end-cap circle's center ([height] / 2 from the edge), mirrored left/right. Body text starts at
/// [textStart], aligning with the thinking pill's text left edge.
abstract final class DockMetrics {
  /// One bar's height (= the thinking pill).
  static const height = 36.0;

  /// The end-cap radius; the expanded todo card uses it too.
  static const radius = height / 2;

  /// The glyph cell at both ends.
  static const glyph = 20.0;

  /// Gap from the glyph cell to the pill's edge.
  static const edge = (height - glyph) / 2;

  /// Text left edge (= the thinking pill: 9 + whale tail 25 + 6).
  static const textStart = 40.0;

  /// Gap from glyph to text.
  static const glyphGap = textStart - edge - glyph;

  /// Gap between text and the right piece.
  static const trailingGap = 10.0;

  /// Between vertically adjacent bars (= thinking pill to input bar).
  static const gap = 6.0;

  static const shape = BorderRadius.all(Radius.circular(radius));
}

/// The bar ends' glyph cell ([DockMetrics.glyph] square, content centered).
class DockGlyph extends StatelessWidget {
  const DockGlyph({super.key, required this.child});

  /// One icon of [iconSize].
  DockGlyph.icon(IconData icon, {Key? key, required Color color})
    : this(
        key: key,
        child: Icon(icon, size: iconSize, color: color),
      );

  static const iconSize = 18.0;

  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: DockMetrics.glyph,
    child: Center(child: child),
  );
}

/// One bar's row: left glyph · text · right piece · right glyph, [DockMetrics.height] tall
/// (may grow taller with the system font size).
class DockRow extends StatelessWidget {
  const DockRow({super.key, required this.leading, required this.content, this.accessory, this.trailing});

  final Widget leading;
  final Widget content;

  /// The small piece left of the right glyph (progress sliver, status word).
  final Widget? accessory;

  /// The end glyph (expand chevron, more).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: DockMetrics.height),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: DockMetrics.edge),
        child: Row(
          children: [
            leading,
            const SizedBox(width: DockMetrics.glyphGap),
            Expanded(child: content),
            if (accessory != null) ...[const SizedBox(width: DockMetrics.trailingGap), accessory!],
            if (trailing != null) ...[
              const SizedBox(width: DockMetrics.trailingGap),
              trailing!,
            ] else
              // Text ends where a trailing glyph's slot would start.
              const SizedBox(width: DockMetrics.edge),
          ],
        ),
      ),
    );
  }
}

/// Text in a bar: title (12 / 600) + second line (12 / secondary color), the same two tiers as the thinking pill.
abstract final class DockText {
  static TextStyle title(BuildContext context, {Color? color}) {
    final theme = Theme.of(context);
    return theme.textTheme.labelMedium!.copyWith(color: color ?? theme.colorScheme.onSurface, height: 1.3);
  }

  static TextStyle detail(BuildContext context, {Color? color}) {
    final theme = Theme.of(context);
    return theme.textTheme.bodySmall!.copyWith(color: color ?? theme.colorScheme.onSurfaceVariant, height: 1.3);
  }
}

/// A thin progress bar: a 3-tall pill trough, success color on completion; glides smoothly as the value changes.
class DockProgressLine extends StatelessWidget {
  const DockProgressLine({super.key, required this.fraction, this.width = 28});

  final double fraction;
  final double width;

  static const thickness = 3.0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dsh = DshColors.of(context);
    final target = fraction.clamp(0.0, 1.0);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: target),
      duration: AppMotion.of(context, AppMotion.standard),
      curve: AppMotion.std,
      builder: (context, value, _) => Container(
        width: width,
        height: thickness,
        alignment: Alignment.centerLeft,
        decoration: ShapeDecoration(color: colors.onSurface.withValues(alpha: 0.10), shape: const StadiumBorder()),
        child: FractionallySizedBox(
          widthFactor: value,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: target >= 1 ? dsh.success : colors.primary,
              shape: const StadiumBorder(),
            ),
            child: const SizedBox(height: thickness),
          ),
        ),
      ),
    );
  }
}

/// A dock bar's position: grows when it has content (content vacates space first, then fades in, rising from behind
/// the bar below); retracts when empty, still painting the last content while retracting; the pacing syncs with the thinking pill
/// ([AppMotion.standard] / [AppMotion.std]).
class DockSlot extends StatefulWidget {
  const DockSlot({super.key, this.child});

  /// Null: nothing to show.
  final Widget? child;

  @override
  State<DockSlot> createState() => _DockSlotState();
}

class _DockSlotState extends State<DockSlot> {
  Widget? _last;

  @override
  Widget build(BuildContext context) {
    final child = widget.child;
    if (child != null) _last = child;
    final last = _last;
    if (last == null) return const SizedBox(width: double.infinity);
    return ExpandReveal(
      open: child != null,
      duration: AppMotion.standard,
      curve: AppMotion.std,
      child: Padding(
        padding: const EdgeInsets.only(bottom: DockMetrics.gap),
        // The chat page's pet may stand on the bar (not while it folds away).
        child: PetPerch(kind: PerchKind.dock, active: child != null, child: last),
      ),
    );
  }
}
