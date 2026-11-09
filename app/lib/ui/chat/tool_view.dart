import 'dart:convert';

import 'package:dsh_client/dsh_client.dart';

import '../../l10n/l10n.dart';
import '../common/tool_glyph.dart';
import 'dsh_ui/dsh_ui_model.dart' show DshUiParse, DshUiParsed;
import 'dsh_ui/dsh_ui_plugin.dart';
import '../../state/sessions_state.dart' show localWorkspaceDir;
import 'render/code_block.dart' show languageForPath;
import 'render/diff_view.dart';

/// A plugin tool's native card (`dsh-go/view` in the result meta, see
/// `docs/design/native-plugins-views.md` §8): null = none;
/// `DshUiInvalid` = present but unrenderable. Read only on successful calls; parsing is cached per meta object.
DshUiParse? toolCardParse(ToolChatItem item) {
  if (item.status != ToolStatus.succeeded) return null;
  final meta = item.meta;
  if (meta is! Map || !meta.containsKey(toolCardViewKey)) return null;
  return parsePluginView(meta[toolCardViewKey], budget: PluginViewBudget.toolCard);
}

/// Generated image / video (`dsh-go/media` in the result meta, see
/// `docs/design/media-generation.md` §2.5): null = none. Read in any state (video
/// answers with a "generating" card first; failures carry the reason too); parsing cached per meta object.
MediaMeta? toolMedia(ToolChatItem item) {
  final meta = item.meta;
  if (meta is! Map || !meta.containsKey(mediaMetaKey)) return null;
  final cached = _media[meta];
  if (cached != null) return cached.$1;
  final parsed = MediaMeta.fromToolMeta(meta);
  _media[meta] = (parsed,);
  return parsed;
}

final _media = Expando<(MediaMeta?,)>('media');

/// This call carries a renderable native card (a plugin card or a generated-media card).
bool hasToolCard(ToolChatItem item) => toolCardParse(item) is DshUiParsed || toolMedia(item) != null;

/// Where the card draws for tool calls with native cards (`ToolCallRow.card`).
enum ToolCardPlacement {
  /// In the tool row: the card is expanded by default; arguments and result collapse under "Details" below the card.
  inline,

  /// The card itself left in the message stream after a whole turn folds up (no tool row).
  cardOnly,

  /// The row folded into the process: the card is already outside, so this is just an ordinary tool row.
  rowOnly,
}

/// With no sandbox backend on the local device, DSH rejects the first bash under the default `workspace-write` preset, and
/// the model then retries with `danger-full-access`, triggering approval. This failure is not the user's fault,
/// so the tool row shows it as a neutral "authorization needed", not a red error.
const _sandboxUnavailableMarker = 'no sandbox backend is usable';

/// The display view of one tool call: verb, summary, command, diff, read window…
///
/// All computed fresh from [ToolChatItem], but diffs (LCS) aren't cheap, so it is lazy and reused by the tool row's
/// State per input identity ([matches]).
class ToolView {
  ToolView._(this.item) : args = _decode(item.arguments);

  factory ToolView.of(ToolChatItem item, [ToolView? previous]) =>
      previous != null && previous.matches(item) ? previous : ToolView._(item);

  final ToolChatItem item;
  final _locale = AppLocale.current;

  /// The parsed arguments; null while streaming (incomplete JSON).
  final Map<String, Object?>? args;

  String get name => item.name;

  /// Reused while the input is unchanged (result chunks and meta come from event objects with stable identity).
  bool matches(ToolChatItem other) => _locale == AppLocale.current && sameInput(item, other);

  static bool sameInput(ToolChatItem item, ToolChatItem other) =>
      other.callId == item.callId &&
      other.name == item.name &&
      other.status == item.status &&
      other.arguments == item.arguments &&
      identical(other.resultParts, item.resultParts) &&
      identical(other.meta, item.meta) &&
      other.failure == item.failure &&
      other.pendingApproval?.eventId == item.pendingApproval?.eventId;

  static Map<String, Object?>? _decode(String raw) {
    if (raw.trim().isEmpty) return null;
    try {
      final value = jsonDecode(raw);
      return value is Map<String, Object?> ? value : null;
    } on FormatException {
      return null;
    }
  }

  /// Reads a string argument; while the JSON is still streaming, scrapes as much as possible from the partial text.
  String? arg(String key) {
    final value = args?[key];
    if (value is String) return value;
    if (args != null) return null;
    final match = RegExp('"${RegExp.escape(key)}"\\s*:\\s*"((?:[^"\\\\]|\\\\.)*)').firstMatch(item.arguments);
    if (match == null) return null;
    return _unescape(match.group(1)!);
  }

  static String _unescape(String s) => s.replaceAllMapped(RegExp(r'\\(u[0-9a-fA-F]{4}|.)'), (m) {
    final e = m.group(1)!;
    return switch (e[0]) {
      'n' => '\n',
      't' => '\t',
      'r' => '',
      'u' when e.length == 5 => String.fromCharCode(int.parse(e.substring(1), radix: 16)),
      _ => e,
    };
  });

  bool get isTerminal => const {'bash', 'pwsh', 'job_output'}.contains(name);

  bool get isActive => switch (item.status) {
    ToolStatus.streaming || ToolStatus.running || ToolStatus.awaitingApproval => true,
    _ => false,
  };

  /// The first bash hit a "no usable sandbox" rejection (see [_sandboxUnavailableMarker]).
  late final bool sandboxBlocked =
      item.status == ToolStatus.failed &&
      ((item.resultText.contains(_sandboxUnavailableMarker)) ||
          (item.failure?.reason?.contains(_sandboxUnavailableMarker) ?? false));

  /// The tool row's verb ("run", "read"…).
  String get verb {
    if (name == 'str_replace_editor') {
      return switch (arg('command')) {
        'view' => appL10n.activityToolRead,
        'create' => appL10n.activityToolWrite,
        _ => appL10n.commonEdit,
      };
    }
    if (name.isEmpty) return appL10n.activityToolCall;
    return ToolGlyphs.labelFor(name);
  }

  /// read / write / edit / str_replace_editor: details list just the path, not the spread-out arguments.
  bool get isFileTool => const {'read', 'write', 'edit', 'str_replace_editor', 'read_image'}.contains(name);

  /// The file path of file-family tools.
  String? get path => arg('file_path') ?? arg('path');

  /// The full command of bash / pwsh.
  String? get command => isTerminal ? arg('command') : null;

  /// Whether the summary is a command / path / pattern (set in monospace).
  bool get summaryIsCode => switch (name) {
    'bash' ||
    'pwsh' ||
    'read' ||
    'write' ||
    'edit' ||
    'str_replace_editor' ||
    'read_image' ||
    'grep' ||
    'glob' ||
    'job_output' ||
    'job_kill' => true,
    _ => false,
  };

  /// A one-line summary (Text elides it itself when shown inline).
  String get summary => _summary();

  /// The plugin tool's native card, see [toolCardParse].
  /// Read through the parse cache each time: it starts over when the
  /// person's palette changes (a card that asked for `accent: "app"`).
  DshUiParse? get pluginView => toolCardParse(item);

  /// Generated media, see [toolMedia].
  late final MediaMeta? media = toolMedia(item);

  /// The native card's title: the folded row's summary uses it (null when the card can't render or wrote no title).
  String? get pluginTitle => switch (pluginView) {
    DshUiParsed(:final view) => view.title,
    _ => null,
  };

  String _summary() {
    String oneLine(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ');
    switch (name) {
      case 'bash' || 'pwsh':
        return oneLine(arg('command') ?? arg('description') ?? '');
      // present: `files: [{path, description?}]` (the declared deliverables).
      case 'present' when args?['files'] is List:
        return [
          for (final file in args!['files'] as List)
            if (file is Map && file['path'] is String) (file['path'] as String).split('/').last,
        ].join(appL10n.activityToolListSeparator);
      case 'read' || 'write' || 'edit' || 'read_image' || 'str_replace_editor' || 'present':
        final p = path;
        return p == null ? '' : displayPath(p);
      case 'grep':
        final pattern = arg('pattern') ?? '';
        final where = arg('path');
        return where == null || where.isEmpty ? pattern : '$pattern · ${displayPath(where)}';
      case 'glob':
        return arg('pattern') ?? '';
      case 'web_fetch':
        return (arg('url') ?? '').replaceFirst(RegExp(r'^https?://'), '');
      case 'web_search':
        return arg('query') ?? '';
      case 'todo_write':
        final todos = args?['todos'];
        return todos is List ? appL10n.commonItemCount(todos.length) : '';
      case 'job_output' || 'job_kill':
        return arg('job_id') ?? arg('id') ?? '';
      case 'ask_user_question':
        final questions = args?['questions'];
        if (questions is List && questions.isNotEmpty) {
          final first = questions.first;
          if (first is Map && first['question'] is String) {
            return oneLine(first['question'] as String);
          }
        }
        return '';
      case 'subagent' || 'send_message' || 'workflow' || 'ralph':
        return oneLine(arg('description') ?? arg('prompt') ?? '');
      case 'skill':
        return arg('name') ?? arg('skill') ?? '';
    }
    for (final key in const [
      'command',
      'file_path',
      'path',
      'pattern',
      'query',
      'url',
      'description',
      'prompt',
      'name',
    ]) {
      final value = arg(key);
      if (value != null && value.trim().isNotEmpty) return oneLine(value);
    }
    final map = args;
    if (map != null) {
      for (final value in map.values) {
        if (value is String && value.trim().isNotEmpty) return oneLine(value);
      }
    }
    return '';
  }

  /// A readable form of the arguments (the expanded area's "Arguments" slot).
  late final String prettyArguments = _pretty();

  String _pretty() {
    final map = args;
    if (map == null) return item.arguments;
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  /// Durable image blocks are authoritative; never guess images from result text.
  late final List<ImageAttachment> images = item.status == ToolStatus.succeeded
      ? item.resultParts.whereType<ImagePart>().map((part) => part.attachment).toList(growable: false)
      : const [];

  /// Legacy path-only image reads use the Host file API, not the phone filesystem.
  String? get imagePath {
    if (item.status != ToolStatus.succeeded || images.isNotEmpty || name != 'read_image') return null;
    final meta = item.meta;
    return meta is Map && meta['path'] is String ? meta['path'] as String : path;
  }

  bool get hasImages => images.isNotEmpty || imagePath != null;

  /// The result text (as-is, ANSI included).
  String get resultText => item.resultText;

  /// The failure reason (the result text first, else failure.reason).
  String? get failureText {
    if (item.status != ToolStatus.failed) return null;
    final text = item.resultText.trim();
    if (text.isNotEmpty) return text;
    return item.failure?.reason ?? item.failure?.code;
  }

  // ---------------------------------------------------------------------------
  // Structured results: edit / write diffs, read's line-number window

  /// The line-level diff for edit / write / str_replace_editor; null when there's no usable information.
  late final List<DiffLine>? diff = _diff();

  /// The old → new text blocks of this edit (in file order): first the hunks DSH
  /// computed in the result meta (with 3 lines of context), else the old/new in the arguments. null = not this kind of edit.
  late final List<({String? oldText, String newText})>? changeBlocks = _changeBlocks();

  List<({String? oldText, String newText})>? _changeBlocks() {
    final fromMeta = _diffsFromMeta(item.meta);
    if (fromMeta != null) return fromMeta;
    if (name == 'edit') {
      final from = arg('old_string');
      final to = arg('new_string');
      if (from != null && to != null) return [(oldText: from, newText: to)];
    }
    if (name == 'str_replace_editor' && arg('command') == 'str_replace') {
      final from = arg('old_str');
      final to = arg('new_str');
      if (from != null && to != null) return [(oldText: from, newText: to)];
    }
    return null;
  }

  /// Line-level diff of each block in [changeBlocks], computed once (shared by the details and this turn's change card).
  /// On a pure insertion DSH writes `oldText` as null.
  late final List<List<DiffLine>>? blockDiffs = changeBlocks == null
      ? null
      : [for (final block in changeBlocks!) computeLineDiff(block.oldText ?? '', block.newText)];

  List<DiffLine>? _diff() {
    final blocks = blockDiffs;
    if (blocks != null && blocks.isNotEmpty) return _merge(blocks);
    if (looksLikeUnifiedDiff(item.resultText)) {
      return parseUnifiedDiff(item.resultText);
    }
    return null;
  }

  static List<DiffLine> _merge(List<List<DiffLine>> blocks) {
    if (blocks.length == 1) return blocks.single;
    return [
      for (var i = 0; i < blocks.length; i++) ...[
        DiffLine(DiffLineKind.hunk, appL10n.activityDiffBlockMarker(i + 1, blocks.length)),
        ...blocks[i],
      ],
    ];
  }

  static List<({String? oldText, String newText})>? _diffsFromMeta(Object? meta) {
    if (meta is! Map) return null;
    final diffs = meta['diffs'];
    if (diffs is! List || diffs.isEmpty) return null;
    final out = <({String? oldText, String newText})>[];
    for (final d in diffs) {
      if (d is! Map) continue;
      final newText = d['newText'];
      if (newText is! String) continue;
      final oldText = d['oldText'];
      out.add((oldText: oldText is String ? oldText : null, newText: newText));
    }
    return out.isEmpty ? null : out;
  }

  /// The content newly written to a file (write create, or str_replace_editor create).
  String? get writtenContent {
    if (name == 'write') return arg('content');
    if (name == 'str_replace_editor' && arg('command') == 'create') {
      return arg('file_text');
    }
    return null;
  }

  late final ({int added, int removed})? diffCounts = _counts();

  ({int added, int removed})? _counts() {
    if (item.status != ToolStatus.succeeded) return null;
    final lines = diff;
    if (lines != null) return diffStats(lines);
    final content = writtenContent;
    if (content != null && content.isNotEmpty) {
      return (added: '\n'.allMatches(content.trimRight()).length + 1, removed: 0);
    }
    return null;
  }

  /// read's line-number window: meta first, else parse `N: text` lines out of the result text.
  late final ({String code, int firstLine, String? language})? readWindow = _read();

  ({String code, int firstLine, String? language})? _read() {
    if (name != 'read' || item.status != ToolStatus.succeeded) return null;
    final meta = item.meta;
    final p = path;
    String? language = p == null ? null : languageForPath(p);
    if (meta is Map && meta['lines'] is List) {
      final lines = <String>[];
      int? first;
      for (final line in meta['lines'] as List) {
        if (line is! Map) continue;
        final number = line['number'];
        final text = line['text'];
        if (number is! int || text is! String) continue;
        first ??= number;
        lines.add(text);
      }
      if (meta['lang'] is String) language ??= meta['lang'] as String;
      if (first != null) {
        return (code: lines.join('\n'), firstLine: first, language: language);
      }
    }
    final numbered = RegExp(r'^(\d+): ?(.*)$');
    final lines = <String>[];
    int? first;
    for (final raw in item.resultText.split('\n')) {
      final m = numbered.firstMatch(raw);
      if (m == null) {
        if (first != null) break;
        continue;
      }
      first ??= int.parse(m.group(1)!);
      lines.add(m.group(2)!);
    }
    if (first == null) return null;
    return (code: lines.join('\n'), firstLine: first, language: language);
  }
}

/// Paths inside the workspace lose the workspace prefix; everything else stays as-is.
String displayPath(String path) {
  const prefix = '$localWorkspaceDir/';
  if (path.startsWith(prefix)) return path.substring(prefix.length);
  if (path == localWorkspaceDir) return '.';
  return path;
}
