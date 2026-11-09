// The words and numbers of the run-information layers
// (live activity, turn footnote, trajectory rows), derived from DSH turn
// traces. Timing semantics follow the official trajectory view (TTFT from
// step start to first token; work in progress has no invented end).

import 'package:dsh_client/dsh_client.dart';

import '../../l10n/l10n.dart';
import '../../state/chat_state.dart';
import '../../state/usage_state.dart';
import '../common/tool_glyph.dart';
import 'activity_copy.dart';
import 'tool_view.dart';
import 'turn_summary.dart';

// -----------------------------------------------------------------------------
// Durations and amounts

/// Static spans: `0.3s`, `4.2s`, `47s`, `1m 05s`, `1h 02m`.
String formatSpan(Duration d) {
  final ms = d.inMilliseconds;
  if (ms < 0) return appL10n.activitySpanZero;
  if (ms < 100) return appL10n.activitySpanTiny;
  if (ms < 10000) {
    final text = (ms / 1000).toStringAsFixed(1);
    return appL10n.activitySpanSecondsText(text.endsWith('.0') ? text.substring(0, text.length - 2) : text);
  }
  final seconds = (ms / 1000).round();
  if (seconds < 60) return appL10n.activitySpanSeconds(seconds);
  if (seconds < 3600) {
    return appL10n.activitySpanMinutesSeconds(seconds ~/ 60, (seconds % 60).toString().padLeft(2, '0'));
  }
  final minutes = seconds ~/ 60;
  return appL10n.activitySpanHoursMinutes(minutes ~/ 60, (minutes % 60).toString().padLeft(2, '0'));
}

/// A ticking clock: `0:07`, `12:45`, `1:02:05`.
String formatClock(Duration d) {
  final total = d.isNegative ? 0 : d.inSeconds;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = (total % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}

/// Routing through the known pricing table; null when there is none (the UI
/// then shows no amount, see [knownPricing]).
TokenPricing? pricingFor(String? provider, String? model) {
  if (provider == null || model == null) return null;
  return knownPricing['$provider/$model'];
}

/// A turn's estimated cost: uncached input and cache writes at the input
/// price, cache hits at the hit price.
double estimateTraceCost(TraceUsage usage, TokenPricing pricing) =>
    ((usage.uncachedInput + usage.cacheWrite) * pricing.inputPerMillion +
        usage.cacheRead * pricing.cacheHitPerMillion +
        usage.output * pricing.outputPerMillion) /
    1e6;

/// `≈ ¥0.03`; under a cent shows `under ¥0.01`.
String formatCost(double amount, String currency) {
  final symbol = currency == 'USD' ? r'$' : '¥';
  if (amount < 0.01) return appL10n.activityCostUnderCent(symbol);
  return appL10n.activityCostApprox(symbol, amount.toStringAsFixed(2));
}

/// A turn's cost estimate; null when the model's price is unknown.
String? turnCostLabel(TurnTrace trace) {
  final model = trace.lastModel;
  final pricing = pricingFor(model.provider, model.model);
  if (pricing == null || trace.usage.isEmpty) return null;
  return formatCost(estimateTraceCost(trace.usage, pricing), pricing.currency);
}

// -----------------------------------------------------------------------------
// What a trace span is called

/// The trajectory row's text: a title ("Thinking" / "Running") and an
/// optional summary (command, path).
typedef SpanLabel = ({String title, String detail, bool detailIsCode});

/// The display view of a tool call: prefer the real item in the list (with
/// result and status); otherwise assemble one from the arguments on the spot.
ToolView viewOfSpan(TraceSpan span, [ToolChatItem? item]) {
  final callId = span.callId ?? 'span${span.seq}';
  final tool =
      item ??
      ToolChatItem(
        callId: callId,
        name: span.toolName ?? '',
        arguments: span.arguments ?? '',
        status: span.open
            ? ToolStatus.running
            : span.failed
            ? ToolStatus.failed
            : ToolStatus.succeeded,
      );
  return ToolView.of(tool);
}

SpanLabel spanLabel(TraceSpan span, [ToolChatItem? item]) {
  switch (span.kind) {
    case TraceKind.model:
      final title = span.open
          ? appL10n.activityThinking
          : span.toolCalls == 0 && span.hasText
          ? (span.interrupted ? appL10n.activityReplyInterrupted : appL10n.commonReply)
          : appL10n.activityThinking;
      final notes = [
        if (span.retries > 0) appL10n.activitySpanRetries(span.retries),
        if (!span.open && span.toolCalls > 0) appL10n.activitySpanToolCalls(span.toolCalls),
      ];
      return (title: title, detail: notes.join(' · '), detailIsCode: false);
    case TraceKind.approval:
      final view = viewOfSpan(span, item);
      return (
        title: span.open ? appL10n.commonWaitingApproval : appL10n.activityWaitingApproval,
        detail: '${view.verb} ${view.summary}'.trim(),
        detailIsCode: false,
      );
    case TraceKind.question:
      final view = viewOfSpan(span, item);
      return (
        title: span.open ? appL10n.commonWaitingAnswer : appL10n.activityWaitingAnswer,
        detail: view.summary,
        detailIsCode: false,
      );
    case TraceKind.tool:
      final view = viewOfSpan(span, item);
      return (title: view.verb, detail: view.summary, detailIsCode: view.summaryIsCode);
  }
}

/// One row of the trajectory table: a span, or a group folded from ≥ 3
/// consecutive tool calls within the same step.
sealed class TrajectoryRow {
  const TrajectoryRow();
  DateTime get start;
  DateTime? get end;
  Duration? get duration => end?.difference(start);
}

final class SpanRow extends TrajectoryRow {
  const SpanRow(this.span);
  final TraceSpan span;
  @override
  DateTime get start => span.start;
  @override
  DateTime? get end => span.end;
}

final class SpanGroupRow extends TrajectoryRow {
  SpanGroupRow(this.spans)
    : start = spans.first.start,
      end = spans.map((s) => s.end!).reduce((a, b) => a.isAfter(b) ? a : b);
  final List<TraceSpan> spans;
  @override
  final DateTime start;
  @override
  final DateTime end;
}

/// Trajectory rows: runs of ≥ [toolGroupThreshold] finished tool calls in the
/// same step fold into one group.
List<TrajectoryRow> trajectoryRows(TurnTrace trace) {
  final rows = <TrajectoryRow>[];
  var run = <TraceSpan>[];
  void flush() {
    if (run.length >= 3) {
      rows.add(SpanGroupRow(run));
    } else {
      rows.addAll(run.map(SpanRow.new));
    }
    run = <TraceSpan>[];
  }

  for (final span in trace.spans) {
    final groupable = span.kind == TraceKind.tool && !span.open;
    if (groupable && (run.isEmpty || run.first.step == span.step)) {
      run.add(span);
      continue;
    }
    flush();
    if (groupable) {
      run.add(span);
    } else {
      rows.add(SpanRow(span));
    }
  }
  flush();
  return rows;
}

/// A summary of a group of tool calls ("Ran 2 commands · Read 3 files").
String groupLabel(List<TraceSpan> spans, Map<String, ToolChatItem> tools) =>
    summarizeTools([for (final span in spans) viewOfSpan(span, tools[span.callId]).item]).label;

/// The tool calls in the list, keyed by callId.
Map<String, ToolChatItem> toolsById(List<ChatItem> items) => {
  for (final item in items)
    if (item is ToolChatItem) item.callId: item,
};

// -----------------------------------------------------------------------------
// What is happening right now

enum ActivityKind {
  /// The turn is being stopped.
  stopping,

  /// The request is out and not one word is back (or the gap between two steps).
  waiting,

  /// Reasoning is streaming.
  thinking,

  /// The reply body is streaming.
  writing,

  /// A tool is running (or the model is still writing its arguments).
  tool,

  /// Waiting for your approval.
  approval,

  /// Waiting for your answer.
  question,

  /// The service asked for a retry and we are backing off.
  retry,

  /// The context is being compacted.
  compaction,
}

/// The tool that finished just before the current model request (easter eggs watch it).
typedef AfterTool = ({String name, String? command, bool failed});

/// What the activity bar above the composer shows. Equal values mean no rebuild.
class RunActivity {
  const RunActivity({
    required this.kind,
    required this.title,
    this.detail = '',
    this.detailIsCode = false,
    this.toolName,
    this.since,
    this.skew = Duration.zero,
    this.todoDone = 0,
    this.todoTotal = 0,
    this.turnStart,
    this.narration,
    this.firstStep = false,
    this.after,
    this.toolsDone = 0,
    this.rateLimited = false,
  });

  final ActivityKind kind;
  final String title;
  final String detail;
  final bool detailIsCode;
  final String? toolName;

  /// When this began (host time); null when it isn't known.
  final DateTime? since;
  final Duration skew;
  final int todoDone;
  final int todoTotal;

  /// When this turn began (host time); the capsule's timer and copy seed both read it.
  final DateTime? turnStart;

  /// The latest `⏵ what I'm doing now` line the model wrote this turn (see [extractNarration]).
  final String? narration;

  /// The first model request of the turn (holidays, weekends, rare easter eggs only appear here).
  final bool firstStep;

  /// The tool that ended just before this model request.
  final AfterTool? after;

  /// How many tools this turn has already run to completion.
  final int toolsDone;

  /// The retry is because of rate limiting (429 / rate limit).
  final bool rateLimited;

  bool get waiting => kind == ActivityKind.approval || kind == ActivityKind.question;

  /// The model is emitting text or about to (the whale's tail may be swimming).
  bool get modelPhase => kind == ActivityKind.waiting || kind == ActivityKind.thinking || kind == ActivityKind.writing;

  @override
  bool operator ==(Object other) =>
      other is RunActivity &&
      other.kind == kind &&
      other.title == title &&
      other.detail == detail &&
      other.detailIsCode == detailIsCode &&
      other.toolName == toolName &&
      other.since == since &&
      other.skew == skew &&
      other.todoDone == todoDone &&
      other.todoTotal == todoTotal &&
      other.turnStart == turnStart &&
      other.narration == narration &&
      other.firstStep == firstStep &&
      other.after == after &&
      other.toolsDone == toolsDone &&
      other.rateLimited == rateLimited;

  @override
  int get hashCode => Object.hash(
    kind,
    title,
    detail,
    detailIsCode,
    toolName,
    since,
    skew,
    todoDone,
    todoTotal,
    turnStart,
    narration,
    firstStep,
    after,
    toolsDone,
    rateLimited,
  );
}

/// What is happening at this moment of generation: stopping > waiting for you
/// > a running tool > a streaming reply / reasoning > retry > waiting for the
/// first token.
RunActivity? runActivityOf(ChatState s) {
  if (!s.running) return null;
  if (s.stopping) {
    return RunActivity(kind: ActivityKind.stopping, title: appL10n.commonStopping);
  }
  final trace = s.runningTurn;
  final spans = trace?.spans ?? const <TraceSpan>[];
  final open = [
    for (final span in spans)
      if (span.open) span,
  ];
  final todos = s.todos ?? const <TodoItem>[];
  final done = todos.where((t) => t.status == 'completed').length;
  final models = spans.where((sp) => sp.kind == TraceKind.model).length;
  final toolsDone = spans.where((sp) => sp.kind == TraceKind.tool && !sp.open).length;

  RunActivity make(
    ActivityKind kind,
    String title, {
    String detail = '',
    bool code = false,
    String? toolName,
    DateTime? since,
    bool rateLimited = false,
  }) {
    final model = kind == ActivityKind.waiting || kind == ActivityKind.thinking || kind == ActivityKind.writing;
    return RunActivity(
      kind: kind,
      title: title,
      detail: detail,
      detailIsCode: code,
      toolName: toolName,
      since: since,
      skew: s.clockSkew,
      todoDone: done,
      todoTotal: todos.length,
      turnStart: trace?.start,
      narration: model ? narrationOf(s.items) : null,
      firstStep: models <= 1,
      after: model ? _afterTool(spans, s.items) : null,
      toolsDone: toolsDone,
      rateLimited: rateLimited,
    );
  }

  DateTime? openSince(bool Function(TraceSpan) test) {
    for (final span in open.reversed) {
      if (test(span)) return span.start;
    }
    return null;
  }

  if (s.questions.isNotEmpty) {
    final question = s.questions.first.questions.firstOrNull?.question ?? '';
    return make(
      ActivityKind.question,
      appL10n.commonWaitingAnswer,
      detail: question.trim().replaceAll(RegExp(r'\s+'), ' '),
      since: openSince((sp) => sp.kind == TraceKind.question),
    );
  }

  final asking = [
    for (final a in s.approvals)
      if (!s.autoAnswered.contains(a.eventId)) a,
  ];
  if (asking.isNotEmpty) {
    final request = asking.first;
    final tool = request.callId == null
        ? null
        : s.items.whereType<ToolChatItem>().lastWhere(
            (t) => t.callId == request.callId,
            orElse: () => ToolChatItem(
              callId: request.callId!,
              name: request.toolName,
              arguments: '',
              status: ToolStatus.awaitingApproval,
            ),
          );
    final view = tool == null ? null : ToolView.of(tool);
    return make(
      ActivityKind.approval,
      appL10n.commonWaitingApproval,
      detail: tool == null || view == null
          ? ToolGlyphs.labelFor(request.toolName)
          : '${toolVerb(tool, view)} ${view.summary}'.trim(),
      toolName: request.toolName,
      since: openSince(
        (sp) => sp.kind == TraceKind.approval && (request.callId == null || sp.callId == request.callId),
      ),
    );
  }

  final model = open.where((sp) => sp.kind == TraceKind.model).lastOrNull;

  // The newest active thing in the list: drafts and running calls are last.
  for (final item in s.items.reversed) {
    switch (item) {
      case ToolChatItem(:final status)
          when status == ToolStatus.running || status == ToolStatus.streaming || status == ToolStatus.awaitingApproval:
        final view = ToolView.of(item);
        // Calls running side by side in this turn (scan back to its prompt).
        var running = 0;
        for (final other in s.items.reversed) {
          if (other is UserChatItem) break;
          if (other is ToolChatItem && other.status == ToolStatus.running) {
            running++;
          }
        }
        final more = running > 1 ? appL10n.activityRunningItems(running) : '';
        return make(
          ActivityKind.tool,
          toolVerb(item, view),
          detail: [view.summary, more].where((p) => p.isNotEmpty).join('  '),
          code: view.summaryIsCode,
          toolName: item.name,
          since: openSince((sp) => sp.callId == item.callId) ?? openSince((sp) => sp.kind == TraceKind.model),
        );
      case AssistantChatItem(:final streaming, :final text, :final reasoning) when streaming:
        final writing = text.trim().isNotEmpty;
        final thinking = reasoning.trim().isNotEmpty;
        return make(
          writing
              ? ActivityKind.writing
              : thinking
              ? ActivityKind.thinking
              : ActivityKind.waiting,
          writing ? appL10n.activityWriting : appL10n.activityThinkingNow,
          since: model?.start,
        );
      case UserChatItem():
        break;
      default:
        continue;
    }
    break;
  }

  final retries = model?.retries ?? 0;
  if (retries > 0) {
    final limited = model!.retryFailures.any(
      // l10n:keep engine rate-limit error matching
      (f) => RegExp(r'429|rate.?limit|限流', caseSensitive: false).hasMatch(f),
    );
    return make(
      ActivityKind.retry,
      appL10n.activityRetrying,
      detail: appL10n.activityRetryAttempt(retries),
      since: model.start,
      rateLimited: limited,
    );
  }
  return make(ActivityKind.waiting, appL10n.activityThinkingNow, since: model?.start ?? trace?.start);
}

/// What the activity bar shows while the context is compacting (a manual
/// `/compact` outside a turn counts too).
RunActivity compactionActivity(ChatState s, DateTime since) {
  final todos = s.running ? s.todos ?? const <TodoItem>[] : const <TodoItem>[];
  return RunActivity(
    kind: ActivityKind.compaction,
    title: appL10n.activityCompacting,
    since: since,
    skew: s.clockSkew,
    todoDone: todos.where((t) => t.status == 'completed').length,
    todoTotal: todos.length,
    turnStart: s.runningTurn?.start ?? since,
  );
}

/// The `⏵` self-report in the turn's newest reply that has body text; if that
/// one didn't write it, there is none.
String? narrationOf(List<ChatItem> items) {
  for (final item in items.reversed) {
    if (item is UserChatItem) return null;
    if (item is AssistantChatItem && item.text.trim().isNotEmpty) {
      return extractNarration(item.text);
    }
  }
  return null;
}

/// The most recently finished span, if it was a tool (the model request followed it).
AfterTool? _afterTool(List<TraceSpan> spans, List<ChatItem> items) {
  TraceSpan? last;
  for (final span in spans) {
    final end = span.end;
    if (end == null || span.kind == TraceKind.approval) continue;
    if (last == null || !end.isBefore(last.end!)) last = span;
  }
  if (last == null || last.kind != TraceKind.tool) return null;
  ToolChatItem? item;
  for (final candidate in items.reversed) {
    if (candidate is ToolChatItem && candidate.callId == last.callId) {
      item = candidate;
      break;
    }
  }
  final view = viewOfSpan(last, item);
  return (name: last.toolName ?? '', command: view.command, failed: last.failed);
}

/// Short verbs for the activity bar: run / read / edit / write / search / find…
String toolVerb(ToolChatItem tool, ToolView view) {
  return switch (toolKindOf(tool)) {
    ToolKind.command => appL10n.activityVerbRun,
    ToolKind.edit =>
      tool.name == 'write' || view.arg('command') == 'create' ? appL10n.activityVerbWrite : appL10n.activityVerbEdit,
    ToolKind.read => tool.name == 'read_image' ? appL10n.activityVerbImage : appL10n.activityVerbRead,
    ToolKind.search => tool.name == 'glob' ? appL10n.activityVerbFind : appL10n.activityVerbSearch,
    ToolKind.web => tool.name == 'web_search' ? appL10n.activityVerbWebSearch : appL10n.activityVerbWebView,
    ToolKind.agent => tool.name == 'subagent' ? appL10n.activityVerbSubagent : view.verb,
    ToolKind.todo => appL10n.activityVerbTodo,
    ToolKind.other => view.verb,
  };
}
