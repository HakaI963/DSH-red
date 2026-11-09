// What the live stream says about a running turn that the transcript does not
// keep, i.e. how fast tokens are flowing right now (for the whale-tail
// indicator) and whether the context is being compacted. The token estimate
// follows DeepSeek's published rule of thumb (1 Chinese character ≈ 0.6
// token, 1 English character ≈ 0.3 token).

import 'dart:async';
import 'dart:math' as math;

import 'package:dsh_client/dsh_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notify_state.dart' show appForegroundProvider;

/// Token estimate for streaming text: CJK (incl. Japanese/Korean) chars × 0.6, other non-space chars × 0.3.
///
/// The factors are empirical values from DeepSeek's docs; whitespace isn't counted (tokenizers fold most
/// indentation and spaces into neighboring tokens). Used for speed only, never for billing.
double estimateTokens(String text) {
  var cjk = 0;
  var other = 0;
  for (final rune in text.runes) {
    if (rune <= 0x20 || rune == 0x3000) continue;
    if ((rune >= 0x3400 && rune <= 0x9FFF) ||
        (rune >= 0xF900 && rune <= 0xFAFF) ||
        (rune >= 0x3040 && rune <= 0x30FF) ||
        (rune >= 0xAC00 && rune <= 0xD7A3) ||
        (rune >= 0x20000 && rune <= 0x3FFFF)) {
      cjk++;
    } else {
      other++;
    }
  }
  return cjk * 0.6 + other * 0.3;
}

/// Output speed over a sliding window (tokens/sec).
///
/// Each delta arrives stamped with when it was produced; speed = tokens in the window ÷ window length. While
/// the window is still filling (the first [window] of an output) actual elapsed time is used, but never less than
/// [minSpan], so the first chunk isn't divided by a few milliseconds. After the last chunk, silence past
/// [stallAfter] counts as stopped (waiting on a tool or your approval); speed is then 0.
class TokenRateMeter {
  TokenRateMeter({
    this.window = const Duration(milliseconds: 2500),
    this.minSpan = const Duration(milliseconds: 500),
    this.stallAfter = const Duration(milliseconds: 1200),
  });

  final Duration window;
  final Duration minSpan;
  final Duration stallAfter;

  final _samples = <({DateTime at, double tokens})>[];

  /// When this stretch of continuous output began (restarts after a [stallAfter] gap).
  DateTime? _burstStart;

  /// When the last chunk arrived; null if none.
  DateTime? get lastAt => _samples.isEmpty ? null : _samples.last.at;

  void add(DateTime at, double tokens) {
    if (tokens <= 0) return;
    final last = lastAt;
    if (last == null || at.difference(last) > stallAfter) _burstStart = at;
    // Out-of-order times (clock estimate moved) keep the list sorted enough:
    // a sample is never placed before the newest one.
    final when = last != null && at.isBefore(last) ? last : at;
    _samples.add((at: when, tokens: tokens));
  }

  void clear() {
    _samples.clear();
    _burstStart = null;
  }

  /// Speed at [now]; 0 when stopped or with no data.
  double rateAt(DateTime now) {
    final last = lastAt;
    if (last == null || now.difference(last) > stallAfter) return 0;
    final from = now.subtract(window);
    _samples.removeWhere((s) => s.at.isBefore(from));
    if (_samples.isEmpty) return 0;
    final start = _burstStart != null && _burstStart!.isAfter(from) ? _burstStart! : from;
    final span = now.difference(start);
    final seconds = (span < minSpan ? minSpan : span).inMicroseconds / 1e6;
    final tokens = _samples.fold<double>(0, (sum, s) => sum + s.tokens);
    return tokens / seconds;
  }
}

/// Speed → the whale tail's four levels, with hysteresis.
///
/// | Level | Meaning | Enter | Exit |
/// |---|---|---|---|
/// | 1 | no tokens streaming (awaiting first token, tools, you) | — | — |
/// | 2 | trickling | > 0 | stopped |
/// | 3 | normal speed | ≥ 30 tok/s | < 24 |
/// | 4 | flying | ≥ 75 tok/s | < 60 |
///
/// Basis for the thresholds: DeepSeek's official API mostly outputs tens to just over a hundred tokens/s
/// (V4 Flash quicker, Pro and long thinking slower); below 30 the eye sees it crawl "one word at a
/// time", above 75 whole paragraphs land at once. The exit line is 0.8× the enter line, so jitter near
/// a line doesn't flip levels back and forth; each level also dwells at least [minDwell], so it can't change several times a second.
class SpeedGauge {
  SpeedGauge({this.minDwell = const Duration(milliseconds: 900)});

  final Duration minDwell;

  static const enterAt = <int, double>{3: 30, 4: 75};
  static const exitRatio = 0.8;

  int _level = 1;
  DateTime? _changedAt;

  int get level => _level;

  /// Advances the level by [tps] and returns it; [now] only judges dwell time.
  int update(double tps, DateTime now) {
    final target = targetFor(tps, _level);
    if (target == _level) return _level;
    final changed = _changedAt;
    if (changed != null && now.difference(changed) < minDwell) return _level;
    _level = target;
    _changedAt = now;
    return _level;
  }

  void reset() {
    _level = 1;
    _changedAt = null;
  }

  /// The target level ignoring dwell time (pure function, for tests).
  static int targetFor(double tps, int current) {
    if (tps <= 0) return 1;
    var level = math.max(current, 2);
    while (level < 4 && tps >= enterAt[level + 1]!) {
      level++;
    }
    while (level > 2 && tps < enterAt[level]! * exitRatio) {
      level--;
    }
    return level;
  }
}

/// One conversation's live pulse: whale-tail level, estimated speed, whether context is compacting.
///
/// [ChatController] feeds every event to [observe]; the UI listens (it notifies only when the level
/// or compaction state changes). While tokens stream it recomputes every [tick]; once things stop and
/// level 1 returns, the timer stops itself.
class RunPulse extends ChangeNotifier {
  RunPulse({
    DateTime Function()? clock,
    this.tick = const Duration(milliseconds: 250),
    TokenRateMeter? meter,
    SpeedGauge? gauge,
  }) : _clock = clock ?? DateTime.now,
       meter = meter ?? TokenRateMeter(),
       gauge = gauge ?? SpeedGauge();

  final DateTime Function() _clock;
  final Duration tick;
  final TokenRateMeter meter;
  final SpeedGauge gauge;

  Timer? _timer;
  bool _disposed = false;
  bool _samplingEnabled = true;

  /// Per-attempt chunk sequence numbers (chunks replayed after a reconnect aren't counted twice).
  final _nextIndex = <String, int>{};

  /// Per-attempt estimated tokens, awaiting calibration from usage chunks.
  final _attemptEstimate = <String, double>{};

  /// Sliding calibration factor of usage ÷ estimate (per conversation; 1 without usage).
  double _scale = 1;

  double _tps = 0;
  DateTime? _compactingSince;

  /// Whale-tail level 1–4.
  int get level => gauge.level;

  /// Speed from the last computation (tok/s, calibrated); 0 while stopped.
  double get tokensPerSecond => _tps;

  /// When compacting context, its start time (Host clock).
  DateTime? get compactingSince => _compactingSince;

  /// [skew] is device clock minus Host clock; when known, chunks are timed where they were produced (a
  /// batch arriving after network buffering isn't read as a sprint); when unknown, at arrival.
  void observe(DshEvent event, {Duration? skew}) {
    switch (event) {
      case AssistantChunkEvent(:final attemptId, :final index, :final chunk):
        final next = _nextIndex[attemptId] ?? 0;
        if (index < next) return;
        _nextIndex[attemptId] = index + 1;
        _chunk(attemptId, chunk, event.time, skew);
      case AssistantStreamEnded(:final attemptId):
        _nextIndex.remove(attemptId);
        _attemptEstimate.remove(attemptId);
      case SessionSnapshotEvent(:final events, :final isResync):
        if (!isResync) {
          _nextIndex.clear();
          _attemptEstimate.clear();
        }
        _setCompacting(compactingAfter(events, _compactingSince, isResync));
      case SessionLogEvent():
        _setCompacting(compactingAfter([event], _compactingSince, true));
      default:
        break;
    }
  }

  void _chunk(String attempt, StreamChunk chunk, DateTime time, Duration? skew) {
    final text = switch (chunk) {
      TextDeltaChunk(:final text) => text,
      ReasoningDeltaChunk(:final text) => text,
      ToolCallDeltaChunk(:final argumentsDelta) => argumentsDelta,
      _ => null,
    };
    if (chunk is UsageChunk) {
      _calibrate(_attemptEstimate[attempt], chunk.usage.outputTokens);
      return;
    }
    if (text == null || text.isEmpty) return;
    final tokens = estimateTokens(text);
    if (tokens <= 0) return;
    _attemptEstimate[attempt] = (_attemptEstimate[attempt] ?? 0) + tokens;
    final now = _clock();
    final local = skew == null ? now : time.add(skew);
    meter.add(local.isAfter(now) ? now : local, tokens);
    _update();
    _ensureTimer();
  }

  /// Drifts toward real usage when the estimate is far off (trusts only long enough stretches).
  void _calibrate(double? estimated, int actual) {
    if (estimated == null || estimated < 40 || actual <= 0) return;
    final ratio = (actual / estimated).clamp(0.4, 2.5);
    _scale = _scale * 0.5 + ratio * 0.5;
  }

  void _update() {
    final now = _clock();
    _tps = meter.rateAt(now) * _scale;
    final before = gauge.level;
    if (gauge.update(_tps, now) != before) _notify();
    if (gauge.level == 1 && meter.lastAt == null) _stopTimer();
  }

  /// One timer tick (tests call it directly).
  @visibleForTesting
  void tickNow() {
    _update();
    final last = meter.lastAt;
    final idle = gauge.level == 1 && (last == null || _clock().difference(last) > meter.stallAfter);
    if (idle) {
      meter.clear();
      _stopTimer();
    }
  }

  /// Pause only the display clock; event ingestion and usage calibration remain
  /// live. On resume, discard a stale rate before scheduling another tick.
  void setSamplingEnabled(bool enabled) {
    if (_disposed || enabled == _samplingEnabled) return;
    _samplingEnabled = enabled;
    if (!enabled) {
      _stopTimer();
      return;
    }
    tickNow();
    if (meter.lastAt != null) _ensureTimer();
  }

  void _ensureTimer() {
    if (_timer != null || _disposed || !_samplingEnabled) return;
    _timer = Timer.periodic(tick, (_) => tickNow());
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _setCompacting(DateTime? since) {
    if (since == _compactingSince) return;
    _compactingSince = since;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _stopTimer();
    super.dispose();
  }
}

/// Whether context is still compacting after reading [events]: after the last `compaction/start` there is
/// neither `compaction/end` nor `turn/end` (a bracket left open by a crash is closed by the next
/// finished turn). [merge] false recounts from scratch (new snapshot), else it continues from [current].
@visibleForTesting
DateTime? compactingAfter(Iterable<SessionLogEvent> events, DateTime? current, bool merge) {
  var since = merge ? current : null;
  for (final event in events) {
    switch (event.type) {
      case 'compaction/start':
        since = event.time;
      case 'compaction/end' || 'turn/end':
        since = null;
    }
  }
  return since;
}

/// One [RunPulse] per conversation; [ChatController] feeds it, the activity bar reads it.
final runPulseProvider = Provider.autoDispose.family<RunPulse, String>((ref, sessionId) {
  final pulse = RunPulse();
  ref.listen(appForegroundProvider, (_, foreground) {
    pulse.setSamplingEnabled(foreground);
  }, fireImmediately: true);
  ref.onDispose(pulse.dispose);
  return pulse;
});
