// The live "what is happening now" pill above the composer while a turn runs
// (layer 1 of the run information): live status, the model's `⏵` narration,
// rotating copy and easter eggs (see activity_copy.dart), and the turn clock.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../../state/chat_state.dart';
import '../../../state/run_pulse.dart';
import '../../pets/pet_perch.dart';
import '../../theme/theme.dart';
import '../activity_copy.dart';
import '../run_info.dart';
import 'live_clock.dart';
import 'whale_tail.dart';

/// While generating, a glass pill above the input bar: whale tail (swim speed = output speed) + what it's doing
/// now + a self-narration or whimsical line + this turn's elapsed time; with a todo, the right end shows progress. Tap for this
/// turn's trajectory; long-press for a few seconds and it swaps to this step's duration and estimated speed.
///
/// ```
/// ( 🐋 run  flutter test test/auth           0:19 │ Progress 3/5 ▰▰▰▱▱ )
/// ( 🐋 thinking  brain's practically smoking         0:07 )
/// ```
///
/// Subscribes only to [runActivityOf]'s result (equal values don't rebuild) and [RunPulse] (notifies only on
/// gear changes, compaction start/end); the ticking seconds and rotating copy rebuild just the text span.
class ActivityStripSlot extends ConsumerStatefulWidget {
  const ActivityStripSlot({super.key, required this.sessionId, this.onTap, this.todoProgress = true});

  final String sessionId;
  final VoidCallback? onTap;

  /// See [ActivityStrip.todoProgress].
  final bool todoProgress;

  @override
  ConsumerState<ActivityStripSlot> createState() => _ActivityStripSlotState();
}

/// On appearance the pill rises from behind the input bar and sinks back on dismissal: the slot's height animates along (the
/// list's bottom padding follows), and the pill itself always paints whole — never clipped or faded. The lower half peeking
/// past the slot is covered by the later-painted input bar; through its frosted glass you only see a blur, so it never
/// clashes with the message text behind it, and there's no hard clipped edge.
class _ActivityStripSlotState extends ConsumerState<ActivityStripSlot> with SingleTickerProviderStateMixin {
  late final AnimationController _rise = AnimationController(vsync: this, duration: AppMotion.standard)
    ..addStatusListener(_onStatus);
  // Sinking decelerates too (not the rise played backwards), in step with
  // the reply actions and new rows that grow while it sinks.
  late final CurvedAnimation _height = CurvedAnimation(
    parent: _rise,
    curve: AppMotion.std,
    reverseCurve: AppMotion.std.flipped,
  );

  /// The last activity shown, kept on screen while the strip sinks away.
  RunActivity? _last;
  int _lastLevel = 1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _rise.duration = AppMotion.of(context, AppMotion.standard);
  }

  @override
  void dispose() {
    _height.dispose();
    _rise.dispose();
    super.dispose();
  }

  void _onStatus(AnimationStatus status) {
    if (status != AnimationStatus.dismissed) return;
    // May fire inside build (no animations: sinking ends at once).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _rise.isDismissed) setState(() => _last = null);
    });
  }

  /// Starts rising / sinking right away, from build: its clock then counts
  /// from this frame, like the reply actions and the "Sending" line that
  /// start in didUpdateWidget, so they all move in step.
  void _drive(bool visible) {
    final status = _rise.status;
    final going = visible
        ? status != AnimationStatus.forward && status != AnimationStatus.completed
        : status != AnimationStatus.reverse && status != AnimationStatus.dismissed;
    if (!going) return;
    visible ? _rise.forward() : _rise.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final sessionId = widget.sessionId;
    final activity = ref.watch(chatProvider(sessionId).select(runActivityOf));
    final pulse = ref.watch(runPulseProvider(sessionId));
    return ListenableBuilder(
      listenable: pulse,
      builder: (context, _) {
        final compacting = pulse.compactingSince;
        final shown = compacting != null ? compactionActivity(ref.read(chatProvider(sessionId)), compacting) : activity;
        if (shown != null) {
          _last = shown;
          // The slowest gear (0) while waiting on you — it never stops.
          _lastLevel = shown.waiting || shown.kind == ActivityKind.stopping ? 0 : pulse.level;
        }
        _drive(shown != null);
        final strip = _last;
        if (strip == null) return const SizedBox(width: double.infinity);
        // The chat page's pet stands on the strip: one mascot a screen, so
        // the whale tail steps aside while it does.
        final perches = PetPerchScope.maybeOf(context);
        return AnimatedBuilder(
          animation: _height,
          builder: (context, child) => Align(alignment: Alignment.topCenter, heightFactor: _height.value, child: child),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: PetPerch(
              kind: PerchKind.strip,
              active: shown != null,
              child: ValueListenableBuilder<PerchKind?>(
                valueListenable: perches?.occupied ?? _noPet,
                builder: (context, occupied, _) => ActivityStrip(
                  activity: strip,
                  speedLevel: _lastLevel,
                  tokensPerSecond: () => pulse.tokensPerSecond,
                  onTap: shown == null ? null : widget.onTap,
                  todoProgress: widget.todoProgress,
                  whale: occupied != PerchKind.strip,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Outside a pet stage nothing ever stands on the strip.
final _noPet = ValueNotifier<PerchKind?>(null);

class ActivityStrip extends StatefulWidget {
  const ActivityStrip({
    super.key,
    required this.activity,
    this.speedLevel = 1,
    this.tokensPerSecond,
    this.onTap,
    this.whaleColor,
    this.todoProgress = true,
    this.whale = true,
  });

  final RunActivity activity;

  /// Whale-tail gears: 0 waiting on you, 1–4 see [SpeedGauge] (see [WhaleTail]).
  final int speedLevel;

  /// On long press, read the current estimated speed once.
  final double Function()? tokensPerSecond;
  final VoidCallback? onTap;

  /// The whale tail's color; default is DeepSeek blue (brightened in dark mode), warning color while waiting on you.
  final Color? whaleColor;

  /// The todo progress at the right end; disabled when the chat page already has a todo bar above — no need to say it twice.
  final bool todoProgress;

  /// The whale tail at the left end; retracts while a pet stands on the pill (the slot goes too, keeping equal side padding).
  final bool whale;

  /// How long the post-long-press stats stay up.
  static const statsFor = Duration(seconds: 4);

  @override
  State<ActivityStrip> createState() => _ActivityStripState();
}

class _ActivityStripState extends State<ActivityStrip> {
  Timer? _statsTimer;

  @override
  void dispose() {
    _statsTimer?.cancel();
    super.dispose();
  }

  void _showStats() {
    HapticFeedback.selectionClick();
    _statsTimer?.cancel();
    _statsTimer = Timer(ActivityStrip.statsFor, () {
      if (mounted) setState(() => _statsTimer = null);
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final dsh = DshColors.of(context);
    final a = widget.activity;
    final whale = widget.whaleColor ?? (a.waiting ? dsh.warning : whaleColorFor(theme.brightness));

    return Semantics(
      button: widget.onTap != null,
      label: '${a.title} ${a.detail}',
      onTapHint: l10n.chatViewTurnTrace,
      onTap: widget.onTap,
      onLongPress: _showStats,
      excludeSemantics: true,
      child: GlassSurface(
        tier: GlassTier.chrome,
        stadium: true,
        onTap: widget.onTap,
        onLongPress: _showStats,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 36),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: widget.whale ? 1 : 0),
            duration: AppMotion.of(context, AppMotion.standard),
            curve: AppMotion.std,
            builder: (context, t, _) => Padding(
              // 9 + whale: the tail's own air makes up the difference; without
              // it both ends are 14.
              padding: EdgeInsets.fromLTRB(14 - 5 * t, 6, 14, 6),
              child: Row(
                children: [
                  if (t > 0)
                    ClipRect(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        widthFactor: t,
                        child: Opacity(
                          opacity: t,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Its own layer: the whale tail moves every frame and shouldn't force the glass pill's other content to repaint.
                              RepaintBoundary(
                                child: WhaleTail(level: widget.speedLevel, color: whale, height: 20),
                              ),
                              const SizedBox(width: 6),
                            ],
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: LiveElapsed(
                      since: a.turnStart ?? a.since,
                      skew: a.skew,
                      builder: (context, elapsed) => _Line(
                        activity: a,
                        elapsed: elapsed,
                        stats: _statsTimer == null ? null : _stats(a, widget.tokensPerSecond?.call() ?? 0),
                      ),
                    ),
                  ),
                  if (widget.todoProgress && a.todoTotal > 0) ...[
                    Container(
                      width: 0.5,
                      height: 14,
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      color: theme.colorScheme.outlineVariant,
                    ),
                    TodoProgress(done: a.todoDone, total: a.todoTotal),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Those seconds of long press: how long this step has taken + the estimated output speed.
  static String _stats(RunActivity a, double tps) {
    final since = a.since;
    final step = since == null ? null : formatClock(LiveElapsed.elapsedSince(since, a.skew));
    final speed = tps >= 1 ? appL10n.chatTokensPerSecond(tps.round()) : appL10n.chatNoTokensStreaming;
    return [if (step != null) appL10n.chatCurrentStep(step), speed].join(' · ');
  }
}

/// Title + second span (tool target / self-narration / rotating copy / stats) + this turn's elapsed time.
class _Line extends StatelessWidget {
  const _Line({required this.activity, required this.elapsed, this.stats});

  final RunActivity activity;
  final Duration? elapsed;
  final String? stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dsh = DshColors.of(context);
    final a = activity;

    // Three tiers: what (title, onSurface 600) › on what (detail, secondary)
    // › colour (narration secondary, fun copy and the clock tertiary).
    final flavor = stats != null ? null : activityFlavor(a, runClock());
    final secondary = colors.onSurfaceVariant;
    final body = theme.textTheme.bodySmall?.copyWith(height: 1.3);
    final spans = <TextSpan>[
      if (stats != null)
        TextSpan(
          text: stats,
          style: body?.copyWith(color: secondary),
        )
      else ...[
        if (a.detail.isNotEmpty)
          TextSpan(
            text: a.detail,
            style: a.detailIsCode
                ? AppType.mono(size: 12, color: secondary, height: 1.3)
                : body?.copyWith(color: secondary),
          ),
        if (flavor != null)
          TextSpan(
            text: a.detail.isNotEmpty ? ' · ${flavor.text}' : flavor.text,
            style: body?.copyWith(
              color: flavor.source == FlavorSource.narration && a.detail.isEmpty ? secondary : dsh.textTertiary,
            ),
          ),
      ],
    ];
    final second = spans.map((s) => s.text).join();

    final titleStyle = theme.textTheme.labelMedium?.copyWith(
      color: a.waiting ? dsh.warning : colors.onSurface,
      height: 1.3,
    );
    final clockStyle = AppType.tabular(
      theme.textTheme.labelSmall!.copyWith(fontSize: 12, color: a.waiting ? dsh.warning : dsh.textTertiary),
    );

    return Row(
      children: [
        Expanded(
          child: AnimatedSwitcher(
            duration: AppMotion.of(context, AppMotion.quick),
            layoutBuilder: (current, previous) =>
                Stack(alignment: Alignment.centerLeft, children: [...previous, ?current]),
            child: Row(
              key: ValueKey('${a.title}\u0000$second'),
              children: [
                Text(a.title, style: titleStyle),
                if (second.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text.rich(
                      TextSpan(children: spans),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (elapsed != null) ...[const SizedBox(width: 8), Text(formatClock(elapsed!), style: clockStyle)],
      ],
    );
  }
}

/// `Progress 3/5` + a 3dp thin bar.
class TodoProgress extends StatelessWidget {
  const TodoProgress({super.key, required this.done, required this.total, this.barWidth = 30, this.showLabel = true});

  final int done;
  final int total;
  final double barWidth;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dsh = DshColors.of(context);
    final fraction = total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0);
    return Semantics(
      label: l10n.chatTodoProgress(done, total),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            showLabel ? l10n.chatProgress(done, total) : '$done/$total',
            style: AppType.tabular(theme.textTheme.labelSmall!.copyWith(fontSize: 12, color: dsh.textTertiary)),
          ),
          const SizedBox(width: 7),
          Container(
            width: barWidth,
            height: 3,
            alignment: Alignment.centerLeft,
            decoration: ShapeDecoration(color: colors.onSurface.withValues(alpha: 0.10), shape: const StadiumBorder()),
            child: FractionallySizedBox(
              widthFactor: fraction,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: fraction >= 1 ? dsh.success : colors.primary,
                  shape: const StadiumBorder(),
                ),
                child: const SizedBox(height: 3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
