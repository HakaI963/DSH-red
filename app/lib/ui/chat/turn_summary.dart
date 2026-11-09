// Tool-group summaries and per-turn file changes.

import 'package:dsh_client/dsh_client.dart';

import '../../l10n/l10n.dart';
import 'render/diff_view.dart';
import 'tool_view.dart';

/// Which category a tool falls into in the summary.
enum ToolKind { command, edit, read, search, web, agent, todo, other }

ToolKind toolKindOf(ToolChatItem tool) {
  switch (tool.name) {
    case 'bash' || 'pwsh':
      return ToolKind.command;
    case 'write' || 'edit':
      return ToolKind.edit;
    case 'str_replace_editor':
      return _cachedView(tool).arg('command') == 'view' ? ToolKind.read : ToolKind.edit;
    case 'read' || 'read_image':
      return ToolKind.read;
    case 'grep' || 'glob':
      return ToolKind.search;
    case 'web_fetch' || 'web_search':
      return ToolKind.web;
    case 'subagent' || 'subagent_fork' || 'send_message' || 'interrupt_agent' || 'workflow' || 'ralph':
      return ToolKind.agent;
    case 'todo_write':
      return ToolKind.todo;
    default:
      return ToolKind.other;
  }
}

/// Counts for a run of consecutive tool calls (files deduped by path).
class ToolSummary {
  const ToolSummary({
    this.commands = 0,
    this.editedFiles = 0,
    this.readFiles = 0,
    this.searches = 0,
    this.web = 0,
    this.agents = 0,
    this.todos = 0,
    this.other = 0,
    this.failed = 0,
    this.total = 0,
  });

  final int commands;
  final int editedFiles;
  final int readFiles;
  final int searches;
  final int web;
  final int agents;
  final int todos;
  final int other;

  /// Calls that truly failed (excluding the Android "no sandbox" first rejection).
  final int failed;
  final int total;

  /// "ran 3 commands · changed 2 files · read 4 files" (failure counts don't live here).
  List<String> get segments => [
    if (commands > 0) appL10n.activitySummaryCommands(commands),
    if (editedFiles > 0) appL10n.activitySummaryEditedFiles(editedFiles),
    if (readFiles > 0) appL10n.activitySummaryReadFiles(readFiles),
    if (searches > 0) appL10n.activitySummarySearches(searches),
    if (web > 0) appL10n.activitySummaryWeb(web),
    if (agents > 0) appL10n.activitySummarySubagents(agents),
    if (todos > 0) appL10n.activitySummaryTodo,
    if (other > 0) appL10n.activitySummaryOther(other),
  ];

  String get label {
    final parts = segments;
    return parts.isEmpty ? appL10n.activitySummaryTotal(total) : parts.join(' · ');
  }
}

/// Count a run of tool calls into a [ToolSummary].
///
/// - File tools dedupe by path (reading one file thrice counts as "read 1 file"); calls whose path is still streaming count individually;
///   failed / refused / cancelled file calls don't count as "changed" or "read";
/// - the bash stopped by the sandbox that retried with authorization doesn't count (it and the retry are one command);
/// - streaming / running calls count normally: the summary describes "what this group is doing".
ToolSummary summarizeTools(Iterable<ToolChatItem> tools) {
  var commands = 0, searches = 0, web = 0, agents = 0, todos = 0, other = 0;
  var failed = 0, total = 0;
  final edited = <String>{};
  final read = <String>{};
  for (final tool in tools) {
    total++;
    final view = _cachedView(tool);
    if (view.sandboxBlocked) continue;
    if (tool.status == ToolStatus.failed) failed++;
    final fileKey = _normalisePath(view.path) ?? '#${tool.callId}';
    // "changed / read" claims it happened: a failed, refused or abandoned file
    // call shows up in the failure count (or nowhere), not as a file.
    final happened = switch (tool.status) {
      ToolStatus.failed || ToolStatus.denied || ToolStatus.cancelled => false,
      _ => true,
    };
    switch (toolKindOf(tool)) {
      case ToolKind.command:
        commands++;
      case ToolKind.edit:
        if (happened) edited.add(fileKey);
      case ToolKind.read:
        if (happened) read.add(fileKey);
      case ToolKind.search:
        searches++;
      case ToolKind.web:
        web++;
      case ToolKind.agent:
        agents++;
      case ToolKind.todo:
        todos++;
      case ToolKind.other:
        other++;
    }
  }
  return ToolSummary(
    commands: commands,
    editedFiles: edited.length,
    readFiles: read.length,
    searches: searches,
    web: web,
    agents: agents,
    todos: todos,
    other: other,
    failed: failed,
    total: total,
  );
}

// -----------------------------------------------------------------------------
// Change card

/// One change: added/removed / context lines, and its start line in the file (when known).
///
/// DSH's diff meta carries no line numbers, so numbering relies on an earlier `read` window in the same turn or a full
/// file write to align: the old text counts only when it appears **uniquely** in known content; otherwise no numbering.
class DiffHunk {
  const DiffHunk({required this.lines, required this.edit, this.oldStart, this.newStart});

  /// Only add / del / context.
  final List<DiffLine> lines;

  /// Which edit this belongs to (1-based), shared by all hunks of one edit.
  final int edit;

  /// Start line in the old file; null = unknown (or pure addition).
  final int? oldStart;

  /// Start line in the new file; null = unknown.
  final int? newStart;

  bool get numbered => newStart != null;

  int get oldCount => lines.where((l) => l.kind != DiffLineKind.add).length;
  int get newCount => lines.where((l) => l.kind != DiffLineKind.del).length;
}

/// One file touched in a turn: multiple edits merged into one diff.
class FileChange {
  const FileChange({
    required this.path,
    required this.created,
    required this.added,
    required this.removed,
    required this.lines,
    required this.edits,
    this.hunks = const [],
    this.lastCallId,
  });

  /// The raw path from the tool arguments (copy-path uses it).
  final String path;

  /// Whether the first touch this turn created it (write create / str_replace_editor create).
  final bool created;
  final int added;
  final int removed;

  /// The merged line-level diff; one hunk-header line separates successive edits.
  final List<DiffLine> lines;

  /// How many edits succeeded.
  final int edits;

  /// The same changes split per hunk (with line numbers you can draw the gutter and assemble a patch).
  final List<DiffHunk> hunks;

  /// The last tool call that changed it (finds which turn did it).
  final String? lastCallId;

  /// A unified-diff patch (for copying). Hunks with unknown line numbers are written at line 1;
  /// `patch` will locate them by context.
  String get patch {
    final shown = shownPath;
    final out = StringBuffer()
      ..writeln(created ? '--- /dev/null' : '--- a/$shown')
      ..writeln('+++ b/$shown');
    for (final hunk in hunks) {
      final oldCount = hunk.oldCount;
      final newCount = hunk.newCount;
      final oldStart = oldCount == 0 ? 0 : (hunk.oldStart ?? 1);
      final newStart = newCount == 0 ? 0 : (hunk.newStart ?? 1);
      out.writeln('@@ -$oldStart,$oldCount +$newStart,$newCount @@');
      for (final line in hunk.lines) {
        out.writeln(line.text.isEmpty ? ' ' : line.text);
      }
    }
    return out.toString();
  }

  /// Inside the workspace, strip the `/root/workspace/` prefix.
  String get shownPath => displayPath(path);

  String get fileName {
    final shown = shownPath;
    final slash = shown.lastIndexOf('/');
    return slash < 0 ? shown : shown.substring(slash + 1);
  }

  /// The containing directory (empty string for files at the workspace root).
  String get directory {
    final shown = shownPath;
    final slash = shown.lastIndexOf('/');
    return slash <= 0 ? '' : shown.substring(0, slash);
  }
}

/// One turn's changes (between two user messages).
class TurnChanges {
  const TurnChanges({required this.afterKey, required this.files});

  /// Key of this turn's last transcript item: the change card attaches after it.
  final String afterKey;
  final List<FileChange> files;

  int get added => files.fold(0, (sum, f) => sum + f.added);
  int get removed => files.fold(0, (sum, f) => sum + f.removed);
}

/// Which files a run of tool calls changed, in order of first edit.
///
/// Counts only **successful** write / edit / str_replace_editor (create, str_replace, insert);
/// diffs prefer the hunks DSH computed in the result meta (`meta.diffs`), else the arguments'
/// old/new text; a newly created file counts as a full addition. Writes via bash `sed -i`, redirection, etc.
/// are invisible here and not included.
List<FileChange> fileChangesOf(Iterable<ToolChatItem> tools) {
  final list = tools.where((tool) => tool.status == ToolStatus.succeeded).toList();
  if (list.isEmpty) return const [];
  // The chat list re-derives its rows every streaming frame and the
  // transcript rebuilds its items on every event; finished calls keep the
  // same inputs, so compare those, not the item objects.
  final key =
      '${AppLocale.current.languageCode}|'
      '${list.first.callId}|${list.last.callId}|${list.length}';
  final hit = _changeCache[key];
  if (hit != null && _sameTools(hit.tools, list)) return hit.changes;
  final changes = _computeChanges(list);
  _changeCache.remove(key);
  _changeCache[key] = (tools: List.of(list), changes: changes);
  if (_changeCache.length > _maxCachedTurns) {
    _changeCache.remove(_changeCache.keys.first);
  }
  return changes;
}

final _changeCache = <String, ({List<ToolChatItem> tools, List<FileChange> changes})>{};
const _maxCachedTurns = 200;

bool _sameTools(List<ToolChatItem> a, List<ToolChatItem> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (!ToolView.sameInput(a[i], b[i])) return false;
  }
  return true;
}

List<FileChange> _computeChanges(List<ToolChatItem> tools) {
  final byPath = <String, _FileAccumulator>{};
  // What the turn has seen of each file (read windows, whole writes), kept
  // in step with its own edits, to give hunks real line numbers.
  final known = <String, _KnownLines>{};
  for (final tool in tools) {
    if (tool.status != ToolStatus.succeeded) continue;
    final kind = toolKindOf(tool);
    if (kind == ToolKind.command) {
      // A shell command may have rewritten anything.
      known.clear();
      continue;
    }
    final view = _cachedView(tool);
    final path = _normalisePath(view.path);
    if (path == null) continue;
    if (kind == ToolKind.read) {
      if (view.readWindow case final window?) {
        known[path] = _KnownLines(window.firstLine, window.code.split('\n'));
      }
      continue;
    }
    if (kind != ToolKind.edit) continue;
    final change = _changeOf(view, known[path]);
    final after = view.writtenContent;
    if (after != null) {
      known[path] = _KnownLines(1, _contentLines(after));
    } else if (change != null && !change.tracked) {
      known.remove(path);
    }
    if (change == null) continue;
    byPath
        .putIfAbsent(path, () => _FileAccumulator(view.path!, created: change.created))
        .add(change.hunks, tool.callId);
  }
  return [for (final acc in byPath.values) acc.build()];
}

List<String> _contentLines(String text) {
  final body = text.endsWith('\n') ? text.substring(0, text.length - 1) : text;
  return body.split('\n');
}

/// A known contiguous stretch of file content (starting at line [start]).
class _KnownLines {
  _KnownLines(this.start, this.lines);
  final int start;
  final List<String> lines;

  /// The index where [needle] appears uniquely in known content (from [from]); null otherwise.
  int? find(List<String> needle, {int from = 0}) {
    if (needle.isEmpty || needle.length > lines.length) return null;
    int? found;
    for (var i = from; i + needle.length <= lines.length; i++) {
      var match = true;
      for (var j = 0; j < needle.length; j++) {
        if (lines[i + j] != needle[j]) {
          match = false;
          break;
        }
      }
      if (!match) continue;
      if (found != null) return null;
      found = i;
    }
    return found;
  }
}

/// Cut turns at user messages, return each turn's changes (turns without changes are not returned).
///
/// While [running], the last turn hasn't ended and gets no card.
List<TurnChanges> turnChanges(List<ChatItem> items, {bool running = false}) {
  final out = <TurnChanges>[];
  var tools = <ToolChatItem>[];
  String? lastKey;

  void close() {
    final key = lastKey;
    if (key != null && tools.isNotEmpty) {
      final files = fileChangesOf(tools);
      if (files.isNotEmpty) out.add(TurnChanges(afterKey: key, files: files));
    }
    tools = <ToolChatItem>[];
    lastKey = null;
  }

  for (final item in items) {
    if (item is UserChatItem) close();
    if (item is ToolChatItem) tools.add(item);
    lastKey = item.key;
  }
  if (!running) close();
  return out;
}

/// The hunks of one edit. [tracked] = every hunk matched a position in known content
/// (known content was updated accordingly; otherwise the caller should discard this call).
({bool created, List<DiffHunk> hunks, bool tracked})? _changeOf(ToolView view, _KnownLines? known) {
  final name = view.name;
  final command = name == 'str_replace_editor' ? view.arg('command') : null;
  final meta = view.item.meta;
  final created = (name == 'write' && meta is Map && meta['operation'] == 'create') || command == 'create';
  if (!created) {
    if (view.changeBlocks case final blocks? when blocks.isNotEmpty) {
      final hunks = <DiffHunk>[];
      var tracked = known != null;
      // Within one edit later hunks sit below earlier ones: the window is
      // updated hunk by hunk, so a match is in "after" coordinates.
      var delta = 0;
      for (final (i, block) in blocks.indexed) {
        final lines = view.blockDiffs![i];
        final oldLines = block.oldText == null ? const <String>[] : block.oldText!.split('\n');
        final at = tracked ? known!.find(oldLines) : null;
        if (at == null) {
          tracked = false;
          hunks.add(DiffHunk(lines: lines, edit: 0));
          continue;
        }
        final newLines = block.newText.split('\n');
        known!.lines.replaceRange(at, at + oldLines.length, newLines);
        final newStart = known.start + at;
        hunks.add(DiffHunk(lines: lines, edit: 0, oldStart: newStart - delta, newStart: newStart));
        delta += newLines.length - oldLines.length;
      }
      // A whole-file write states the result: place each hunk's new text in
      // it (in file order), and the old side follows from the hunks above.
      final after = view.writtenContent;
      if (!tracked && after != null) {
        final known = _KnownLines(1, _contentLines(after));
        var from = 0;
        var shift = 0;
        final placed = <DiffHunk>[];
        for (final (i, block) in blocks.indexed) {
          final newLines = block.newText.split('\n');
          final oldLength = block.oldText == null ? 0 : block.oldText!.split('\n').length;
          final at = known.find(newLines, from: from);
          if (at == null) break;
          placed.add(DiffHunk(lines: hunks[i].lines, edit: 0, oldStart: at + 1 - shift, newStart: at + 1));
          from = at + newLines.length;
          shift += newLines.length - oldLength;
        }
        if (placed.length == blocks.length) {
          return (created: false, hunks: placed, tracked: false);
        }
      }
      return (created: false, hunks: hunks, tracked: tracked);
    }
    if (command == 'insert') {
      final text = view.arg('new_str');
      if (text != null) {
        final after = view.args?['insert_line'];
        final line = after is int ? after : null;
        final added = _contentLines(text);
        var tracked = false;
        if (known != null && line != null) {
          final index = line - known.start + 1;
          if (index >= 0 && index <= known.lines.length) {
            known.lines.insertAll(index, added);
            tracked = true;
          }
        }
        return (
          created: false,
          hunks: [DiffHunk(lines: _allAdded(text), edit: 0, newStart: line == null ? null : line + 1)],
          tracked: tracked,
        );
      }
    }
  }
  final content = view.writtenContent;
  if (content != null) {
    final lines = _allAdded(content);
    return (created: created, hunks: [DiffHunk(lines: lines, edit: 0, newStart: created ? 1 : null)], tracked: true);
  }
  return null;
}

List<DiffLine> _allAdded(String text) {
  if (text.isEmpty) return const [];
  final body = text.endsWith('\n') ? text.substring(0, text.length - 1) : text;
  return [for (final line in body.split('\n')) DiffLine(DiffLineKind.add, '+$line')];
}

class _FileAccumulator {
  _FileAccumulator(this.path, {required this.created});

  final String path;
  final bool created;
  final List<List<DiffHunk>> blocks = [];

  String? lastCallId;

  void add(List<DiffHunk> hunks, String callId) {
    blocks.add(hunks);
    lastCallId = callId;
  }

  FileChange build() {
    final edits = blocks.length;
    final hunks = [
      for (final (i, block) in blocks.indexed)
        for (final hunk in block)
          DiffHunk(lines: hunk.lines, edit: i + 1, oldStart: hunk.oldStart, newStart: hunk.newStart),
    ];
    List<DiffLine> flat(List<DiffHunk> block) {
      if (block.length == 1) return block.single.lines;
      return [
        for (var i = 0; i < block.length; i++) ...[
          DiffLine(DiffLineKind.hunk, appL10n.activityDiffBlockMarker(i + 1, block.length)),
          ...block[i].lines,
        ],
      ];
    }

    final lines = edits == 1
        ? flat(blocks.single)
        : [
            for (var i = 0; i < edits; i++) ...[
              DiffLine(DiffLineKind.hunk, appL10n.activityDiffEditMarker(i + 1, edits)),
              ...flat(blocks[i]),
            ],
          ];
    final stats = diffStats(lines);
    return FileChange(
      path: path,
      created: created,
      added: stats.added,
      removed: stats.removed,
      lines: lines,
      edits: edits,
      hunks: hunks,
      lastCallId: lastCallId,
    );
  }
}

String? _normalisePath(String? path) {
  if (path == null) return null;
  var p = path.trim();
  if (p.isEmpty) return null;
  while (p.startsWith('./')) {
    p = p.substring(2);
  }
  return displayPath(p);
}

// ToolView's diff is LCS, not cheap. Every persisted transcript event rebuilds all
// ToolChatItems, but the result chunks / meta / arguments are the same objects, so views are cached by callId,
// validated with [ToolView.matches], and the diff is computed once per call.
final _views = <String, ToolView>{};
const _maxCachedViews = 600;

ToolView _cachedView(ToolChatItem tool) {
  final previous = _views.remove(tool.callId);
  final view = ToolView.of(tool, previous);
  _views[tool.callId] = view;
  if (_views.length > _maxCachedViews) _views.remove(_views.keys.first);
  return view;
}
