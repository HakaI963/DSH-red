// The row model between DSH ChatItems and the chat list.

import 'package:dsh_client/dsh_client.dart';

import '../../state/artifacts.dart';
import '../../state/chat_state.dart';
import 'tool_view.dart';
import 'turn_summary.dart';

/// One row of the message list, derived from the transcript by [deriveRows].
sealed class ChatRow {
  const ChatRow();

  /// Stable key (list diffing and viewport anchoring rely on it).
  String get key;

  /// Candidates for the viewport boundary anchor: rows whose content will never be merged / replaced again.
  bool get stable => false;
}

final class UserRow extends ChatRow {
  const UserRow(this.item);
  final UserChatItem item;

  /// The optimistic bubble's key once echoed: the row keeps its element, so
  /// the bubble eases from "Sending" into place instead of being swapped.
  @override
  String get key => switch (item.requestId) {
    final id? => 'p$id',
    null => item.key,
  };
  @override
  bool get stable => true;
}

/// A message just sent from this device that DSH has not echoed yet.
final class PendingRow extends ChatRow {
  const PendingRow(this.prompt);
  final PendingPrompt prompt;
  @override
  String get key => 'p${prompt.requestId}';
}

final class AssistantRow extends ChatRow {
  const AssistantRow(this.item, {this.showActions = false, this.footnote});
  final AssistantChatItem item;

  /// The turn's last assistant body message: the copy keys hang below it.
  final bool showActions;

  /// The turn ends here: the action row's right end carries the turn footnote (elapsed time, steps…).
  final TurnTrace? footnote;
  @override
  String get key => item.key;
  @override
  bool get stable => !item.streaming && item.seq != null;
}

final class ToolCallRow extends ChatRow {
  const ToolCallRow(this.item, {this.card = ToolCardPlacement.inline});
  final ToolChatItem item;

  /// When a call carries a native card, where the card is drawn; calls without one are always inline.
  /// A card left exposed after collapsing reuses this call's stable key: the same element turns from "tool row + card"
  /// into "card only" without replaying its entrance as new content.
  final ToolCardPlacement card;
  @override
  String get key => item.key;
}

/// Runs of ≥ [toolGroupThreshold] consecutive tool calls are merged into one group.
final class ToolGroupRow extends ChatRow {
  const ToolGroupRow(this.tools, {this.live = false});
  final List<ToolChatItem> tools;
  final bool live;
  @override
  String get key => 'g${tools.first.key}';
}

final class NoticeRowData extends ChatRow {
  const NoticeRowData(this.item);
  final NoticeChatItem item;
  @override
  String get key => item.key;
  @override
  bool get stable => true;
}

/// Approvals not attached to any visible tool row (the asker gave no callId, or the tool row hasn't appeared yet).
final class ApprovalRow extends ChatRow {
  const ApprovalRow(this.request);
  final ApprovalRequest request;
  @override
  String get key => 'ap${request.eventId}';
}

final class QuestionRow extends ChatRow {
  const QuestionRow(this.request);
  final UserQuestionRequest request;
  @override
  String get key => 'q${request.eventId}';
}

/// The change card at a turn's end: which files this turn changed, each with +/− counts.
final class ChangeCardRow extends ChatRow {
  const ChangeCardRow(this.files, {required this.anchor});
  final List<FileChange> files;

  /// The callId (stable key) of this turn's first file-changing tool.
  final String anchor;
  @override
  String get key => 'chg$anchor';
}

/// The artifact card at a turn's end: files this turn delivered (`present`) or generated (see
/// `state/artifacts.dart`). Follows the change card, staying outside the whole-turn collapse.
final class ArtifactCardRow extends ChatRow {
  const ArtifactCardRow(this.group);
  final TurnArtifacts group;
  @override
  String get key => 'art${group.endSeq}';
}

/// A normally-ended turn: thinking, tool calls and intermediate messages collapse into one summary row, and the final answer stays
/// outside (official Web's foldCompletedTurns). Expanded, its [rows] grow inside that row.
/// Stopped or failed turns are not collapsed — it must be obvious at a glance where they halted.
///
/// When a running interjection cuts a turn into pieces, each piece gets its own summary row: for a pre-interjection piece, [cut] is that
/// interjection's seq; the last piece (with the final answer and the footnote) has [cut] null.
final class TurnProcessRow extends ChatRow {
  const TurnProcessRow(this.trace, this.rows, {required this.toolCalls, required this.messages, this.cut});
  final TurnTrace trace;
  final List<ChatRow> rows;

  /// How many tool calls were folded in.
  final int toolCalls;

  /// How many folded-in assistant messages had body text.
  final int messages;

  /// Which interjection this piece ends at (the seq of that user message); null for the turn's last piece.
  final int? cut;

  /// The last piece keeps `tp<turn start>` (the list's collapse animation and expanded states identify rows by it);
  /// pre-interjection pieces also carry the interjection's seq, so pieces never cross-talk.
  @override
  String get key => switch (cut) {
    final seq? => 'tp${trace.startSeq}@$seq',
    null => 'tp${trace.startSeq}',
  };
  @override
  bool get stable => true;
}

/// An ended turn with no reply to hang the footnote on (error, stopped, tool calls only):
/// the footnote gets a row of its own.
final class TurnFootnoteRow extends ChatRow {
  const TurnFootnoteRow(this.trace);
  final TurnTrace trace;
  @override
  String get key => 'ft${trace.startSeq}';
  @override
  bool get stable => true;
}

/// A slash command's execution record (`command/run` + `command/done`, or one just sent from this device).
final class CommandNoticeRow extends ChatRow {
  const CommandNoticeRow(this.notice);
  final CommandNotice notice;
  @override
  String get key => notice.key;
  @override
  bool get stable => notice.done && notice.seq != null;
}

const toolGroupThreshold = 3;

/// Fold the transcript into list rows:
/// - assign content to the turns in [turns] by seq (`turn/start` to `turn/end`); when several turns are squeezed
///   between two user messages (auto-triggered turns, target turns, background-job callbacks) each turn closes out
///   separately; a running interjection cuts one turn into pieces, and the earlier pieces close out on their own;
/// - runs of ≥ 3 consecutive tool calls merge into a [ToolGroupRow]; calls with native cards stay out of groups,
///   splitting the run (cards default to expanded and can't hide inside a group);
/// - mark each piece's last assistant body message `showActions` (unmarked when the turn hasn't ended or an interjection
///   follows);
/// - turns that changed files get a [ChangeCardRow] after their content; turns with [artifacts]
///   then get an [ArtifactCardRow] (matched by `turn/end`);
/// - ended turns carry the turn footnote: on this turn's last reply's action row, or, if no such reply exists,
///   as a standalone [TurnFootnoteRow];
/// - with [foldTurns], every piece of a normally-ended turn folds its process into one [TurnProcessRow]:
///   the last piece keeps the final answer, pre-interjection pieces keep their last utterance (the reply's own thinking
///   is folded in too); user messages are never folded; for calls with native cards, the tool row folds in and the card
///   itself stays outside (right after the process row);
/// - slash commands are inserted by seq at the position where they ran; local ones not yet persisted go at the end;
/// - the "stopped" notice after an interrupted assistant body is dropped (the body's tail already marks it);
/// - stray approvals, question cards and un-echoed optimistic messages append in turn (while waiting they're shown by the
///   pill on the input bar, not a three-dots row in the list: it flickers between steps and makes the whole list jump);
///   approvals auto-passed by "allow everything in this conversation" no longer produce their own card.
List<ChatRow> deriveRows({
  required List<ChatItem> items,
  List<ApprovalRequest> approvals = const [],
  List<UserQuestionRequest> questions = const [],
  List<PendingPrompt> pending = const [],
  bool running = false,
  Set<String> autoAnswered = const {},
  List<CommandNotice> commands = const [],
  List<TurnTrace> turns = const [],
  bool foldTurns = false,
  List<TurnArtifacts> artifacts = const [],
}) {
  final rows = <ChatRow>[];
  final attached = <String>{};
  var tools = <ToolChatItem>[];
  var nextCommand = 0;

  // The start index, in rows, of the current piece (same turn, after the previous closing point) — null while it has no
  // content yet; the end position of this piece's content; the index of the last assistant message with body text.
  int? pieceStart;
  var pieceEnd = 0;
  int? lastText;
  // The current turn (null when not loaded in [turns]) and all its tool calls (the pieces cut by interjections
  // are counted together; the change card covers the whole turn).
  TurnTrace? turn;
  var turnTools = <ToolChatItem>[];

  void flushTools({bool live = false}) {
    if (tools.isEmpty) return;
    pieceStart ??= rows.length;
    // Calls with native cards form their own rows and split the run into segments; each segment is handled as before (≥ 3 → group).
    var run = <ToolChatItem>[];
    void flushRun({bool live = false}) {
      if (run.length >= toolGroupThreshold) {
        rows.add(ToolGroupRow(run, live: live));
      } else {
        for (final tool in run) {
          rows.add(ToolCallRow(tool));
        }
      }
      run = <ToolChatItem>[];
    }

    for (final tool in tools) {
      if (hasToolCard(tool)) {
        flushRun();
        rows.add(ToolCallRow(tool));
      } else {
        run.add(tool);
      }
    }
    flushRun(live: live);
    tools = <ToolChatItem>[];
    pieceEnd = rows.length;
  }

  // Each turn's seq span: turn/start to turn/end; those with no turn/end (still running, or the
  // Host vanished mid-way) extend to the next turn's start. [turns] is sorted by start (traceTurns' order).
  var cursor = 0;
  TurnTrace? turnAt(int seq) {
    if (turns.isEmpty) return null;
    while (cursor + 1 < turns.length && turns[cursor + 1].startSeq <= seq) {
      cursor++;
    }
    while (cursor > 0 && turns[cursor].startSeq > seq) {
      cursor--;
    }
    final trace = turns[cursor];
    if (trace.startSeq > seq) return null;
    if (trace.endSeq case final end? when seq > end) return null;
    return trace;
  }

  // Artifact cards: taken at turn/end.
  var nextArtifacts = 0;
  List<TurnArtifacts> takeArtifacts(int? beforeSeq) {
    final start = nextArtifacts;
    while (nextArtifacts < artifacts.length && (beforeSeq == null || artifacts[nextArtifacts].endSeq < beforeSeq)) {
      nextArtifacts++;
    }
    return artifacts.sublist(start, nextArtifacts);
  }

  /// Collapse the current piece's process, keeping explicitly marked answers; falls back to [reply] when nothing is marked.
  /// Returns the new index of the last exposed reply (null when everything was folded in). [cut]: which interjection ends this piece.
  int? fold(TurnTrace trace, int? reply, {int? cut}) {
    final start = pieceStart!;
    // Prefer explicit final answers: a late subagent result can produce another
    // answer in the same turn. Older hosts/models keep the positional fallback.
    final hasFinalAnswer = rows
        .getRange(start, pieceEnd)
        .whereType<AssistantRow>()
        .any((row) => row.item.isFinalAnswer && row.item.text.trim().isNotEmpty);
    var answer = hasFinalAnswer ? null : reply;
    if (answer != null) {
      for (var i = answer + 1; i < pieceEnd; i++) {
        final row = rows[i];
        if (row is ToolCallRow || row is ToolGroupRow || row is AssistantRow) {
          answer = null;
          break;
        }
      }
    }
    final end = answer ?? pieceEnd;
    final process = <ChatRow>[];
    final kept = <ChatRow>[];
    int? keptAnswer;
    var toolCalls = 0;
    var messages = 0;
    for (var i = start; i < end; i++) {
      switch (rows[i]) {
        case final ToolCallRow row when hasToolCard(row.item):
          // Native cards are for humans to see: the tool row folds in, the card stays outside.
          toolCalls++;
          process.add(ToolCallRow(row.item, card: ToolCardPlacement.rowOnly));
          kept.add(ToolCallRow(row.item, card: ToolCardPlacement.cardOnly));
        case final ToolCallRow row:
          toolCalls++;
          process.add(row);
        case final ToolGroupRow row:
          toolCalls += row.tools.length;
          process.add(row);
        case final AssistantRow row when row.item.isFinalAnswer && row.item.text.trim().isNotEmpty:
          var item = row.item;
          if (item.reasoning.trim().isNotEmpty) {
            final (thinking, reply) = _splitReasoning(item);
            process.add(AssistantRow(thinking));
            item = reply;
          }
          keptAnswer = kept.length;
          kept.add(AssistantRow(item));
        case final AssistantRow row:
          if (row.item.text.trim().isNotEmpty) messages++;
          process.add(AssistantRow(row.item));
        case final NoticeRowData row:
          process.add(row);
        case final row:
          kept.add(row);
      }
    }
    var answerRow = answer == null ? null : rows[answer] as AssistantRow;
    if (answerRow != null && answerRow.item.reasoning.trim().isNotEmpty) {
      final (thinking, reply) = _splitReasoning(answerRow.item);
      process.add(AssistantRow(thinking));
      answerRow = AssistantRow(reply);
    }
    // Just one thinking stretch (ordinary Q&A): the thinking pill is already a single row — no need for a second layer of collapse.
    if (toolCalls == 0 && messages == 0 && process.length <= 1) return reply;
    final replacement = [
      TurnProcessRow(trace, List.unmodifiable(process), toolCalls: toolCalls, messages: messages, cut: cut),
      ...kept,
      ?answerRow,
    ];
    final removed = (answer == null ? end : answer + 1) - start;
    rows.replaceRange(start, start + removed, replacement);
    pieceEnd += replacement.length - removed;
    if (answerRow != null) return start + replacement.length - 1;
    return keptAnswer == null ? null : start + 1 + keptAnswer;
  }

  /// Close out the current piece. [cut] null: the turn ends here (content that can't be attributed to a turn
  /// counts as ended too) — hang the footnote and append the artifact cards of turns that ended before
  /// [artifactsBefore] (null = everything remaining); otherwise interjection [cut] is where the turn was split, and
  /// only this piece's process is folded.
  void close({int? cut, int? artifactsBefore}) {
    flushTools();
    final last = cut == null;
    final trace = turn;
    final done = trace != null && !trace.running && trace.endSeq != null ? trace : null;
    var index = lastText;
    if (foldTurns && done != null && pieceStart != null && (done.endReason?.isCompleted ?? false)) {
      index = fold(done, index, cut: cut);
    }
    final footnote = last ? done : null;
    if (index != null) {
      final row = rows[index] as AssistantRow;
      rows[index] = AssistantRow(row.item, showActions: true, footnote: footnote);
    } else if (footnote != null && rows.isNotEmpty) {
      rows.insert(pieceEnd, TurnFootnoteRow(footnote));
      pieceEnd++;
    }
    lastText = null;
    pieceStart = null;
    if (!last) return;
    if (turnTools.isNotEmpty) {
      final files = fileChangesOf(turnTools);
      if (files.isNotEmpty) {
        final anchor = turnTools.firstWhere((t) => toolKindOf(t) == ToolKind.edit).callId;
        rows.insert(pieceEnd, ChangeCardRow(files, anchor: anchor));
      }
    }
    final groups = takeArtifacts(artifactsBefore);
    if (groups.isNotEmpty && rows.isNotEmpty) {
      var at = pieceEnd;
      if (at < rows.length && rows[at] is ChangeCardRow) at++;
      for (final group in groups) {
        rows.insert(at++, ArtifactCardRow(group));
      }
    }
    turnTools = <ToolChatItem>[];
    pieceEnd = rows.length;
  }

  /// Command rows: persisted ones are inserted before [beforeSeq] by seq; null = everything remaining.
  void emitCommands(int? beforeSeq) {
    var flushed = false;
    while (nextCommand < commands.length) {
      final command = commands[nextCommand];
      final seq = command.seq;
      if (beforeSeq != null && (seq == null || seq >= beforeSeq)) break;
      if (!flushed) {
        flushTools();
        flushed = true;
      }
      rows.add(CommandNoticeRow(command));
      nextCommand++;
    }
  }

  int? seqOf(ChatItem item) => switch (item) {
    UserChatItem(:final seq) => seq,
    AssistantChatItem(:final seq) => seq,
    ToolChatItem(:final seq) => seq,
    NoticeChatItem(:final seq) => seq,
  };

  for (var i = 0; i < items.length; i++) {
    final item = items[i];
    // Those with no seq (drafts still streaming) follow the content ahead of them.
    if (seqOf(item) case final seq?) {
      final owner = turnAt(seq);
      if (!identical(owner, turn)) {
        // A new turn began: the previous turn (or content without a turn) ends here.
        close(artifactsBefore: (turn?.endSeq ?? seq - 1) + 1);
        turn = owner;
      }
      emitCommands(seq);
    }
    switch (item) {
      case ToolChatItem():
        if (item.pendingApproval case final request?) {
          attached.add(request.eventId);
        }
        tools.add(item);
        turnTools.add(item);
      case UserChatItem():
        // A user message inside the same turn is a running interjection: the piece before it closes out separately.
        // When turns can't be attributed, a single user message is the turn boundary.
        close(cut: turn == null ? null : item.seq, artifactsBefore: item.seq);
        rows.add(UserRow(item));
        pieceEnd = rows.length;
      case AssistantChatItem():
        flushTools();
        pieceStart ??= rows.length;
        rows.add(AssistantRow(item));
        if (item.text.trim().isNotEmpty) lastText = rows.length - 1;
      case NoticeChatItem():
        flushTools();
        final previous = i > 0 ? items[i - 1] : null;
        if (item.kind == 'aborted' && previous is AssistantChatItem && previous.interrupted) {
          break;
        }
        pieceStart ??= rows.length;
        rows.add(NoticeRowData(item));
    }
    if (item is AssistantChatItem || item is NoticeChatItem) {
      pieceEnd = rows.length;
    }
  }
  if (running) {
    flushTools(live: true);
  } else {
    close();
  }
  emitCommands(null);

  final orphans = [
    for (final request in approvals)
      if (!attached.contains(request.eventId) && !autoAnswered.contains(request.eventId)) ApprovalRow(request),
  ];

  rows.addAll(orphans);
  for (final question in questions) {
    rows.add(QuestionRow(question));
  }
  for (final prompt in pending) {
    // DSH's own context for the model is nobody's message (the controller
    // leaves it out already).
    if (prompt.isEngineNote) continue;
    rows.add(PendingRow(prompt));
  }
  return rows;
}

/// Fold a reply's own thinking into the process row: split it into a thinking-only row and a body-only row.
(AssistantChatItem, AssistantChatItem) _splitReasoning(AssistantChatItem item) => (
  AssistantChatItem(
    id: '${item.id}#r',
    rowKey: '${item.key}#r',
    seq: item.seq,
    time: item.time,
    text: '',
    reasoning: item.reasoning,
    model: item.model,
  ),
  AssistantChatItem(
    id: item.id,
    rowKey: item.rowKey,
    seq: item.seq,
    time: item.time,
    text: item.text,
    reasoning: '',
    interrupted: item.interrupted,
    usage: item.usage,
    model: item.model,
    isFinalAnswer: item.isFinalAnswer,
  ),
);
