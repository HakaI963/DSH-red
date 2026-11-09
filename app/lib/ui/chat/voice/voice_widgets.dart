// Pieces of the composer while listening: the live level bars and the cancel
// key that takes the + key's place.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/l10n.dart';
import '../../theme/app_icons.dart';
import '../../theme/theme.dart';

/// The volume meter while dictating: 5 round-capped vertical bars, the newest level entering from the right. Max 24,
/// shorter than the 36 round keys beside it; it occupies the 36-tall slot left of the send key.
class VoiceWaveform extends StatefulWidget {
  const VoiceWaveform({super.key, required this.level, this.active = true});

  final ValueListenable<double> level;

  /// False while transcribing: the bars rest flat.
  final bool active;

  static const bars = 5;
  static const barWidth = 3.0;
  static const gap = 3.5;
  static const minHeight = 4.0;
  static const maxHeight = 24.0;
  static const width = bars * barWidth + (bars - 1) * gap + 8;

  @override
  State<VoiceWaveform> createState() => _VoiceWaveformState();
}

class _VoiceWaveformState extends State<VoiceWaveform> {
  final List<double> _history = List.filled(VoiceWaveform.bars, 0, growable: true);

  @override
  void initState() {
    super.initState();
    widget.level.addListener(_onLevel);
  }

  @override
  void didUpdateWidget(VoiceWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.level != widget.level) {
      oldWidget.level.removeListener(_onLevel);
      widget.level.addListener(_onLevel);
    }
  }

  @override
  void dispose() {
    widget.level.removeListener(_onLevel);
    super.dispose();
  }

  void _onLevel() {
    setState(() {
      _history
        ..removeAt(0)
        ..add(widget.level.value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final color = colors.onSurface.withValues(alpha: widget.active ? 0.6 : 0.25);
    final duration = AppMotion.of(context, AppMotion.press);
    return Semantics(
      label: widget.active ? l10n.chatListening : l10n.chatTranscribing,
      child: SizedBox(
        width: VoiceWaveform.width,
        height: 36,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < VoiceWaveform.bars; i++) ...[
              if (i > 0) const SizedBox(width: VoiceWaveform.gap),
              AnimatedContainer(
                duration: duration,
                curve: AppMotion.std,
                width: VoiceWaveform.barWidth,
                height: widget.active
                    ? VoiceWaveform.minHeight + _history[i] * (VoiceWaveform.maxHeight - VoiceWaveform.minHeight)
                    : VoiceWaveform.minHeight,
                decoration: ShapeDecoration(color: color, shape: const StadiumBorder()),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The ✕ that replaces the + key while dictating: same 36 circle, same tinted ground, mirroring the stop key on the right.
class VoiceCancelKey extends StatelessWidget {
  const VoiceCancelKey({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: l10n.chatCancelVoiceInput,
      child: InkResponse(
        onTap: () {
          HapticFeedback.selectionClick();
          onPressed();
        },
        radius: 22,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: scheme.onSurface.withValues(alpha: 0.06), shape: BoxShape.circle),
          child: Icon(AppIcons.close, size: 22, color: scheme.onSurface),
        ),
      ),
    );
  }
}
