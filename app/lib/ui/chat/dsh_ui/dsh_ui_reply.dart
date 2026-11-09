// Portions derived from DS Bot (https://github.com/Fei2411/DeepSeek-Bot), Apache-2.0, Copyright 2026 Fei2411 and the DS Bot contributors. See THIRD_PARTY_NOTICES.md.
// Modified: the `validateOptions` selection rules translated to Dart; the
// answer travels as a readable user message built only from visible labels
// (an `[dsh-ui reply]` line plus `选择：…`/`Select: …` in the UI language),
// and the card's state is derived from the
// message order instead of being stored.

import 'package:dsh_client/dsh_client.dart';

import '../../../l10n/l10n.dart';
import 'dsh_ui_model.dart';

/// Marker for the first line of a reply message. When the user taps a view's
/// button, the message the app sends starts with it.
const dshUiReplyMarker = '[dsh-ui reply]';

enum DshUiReplyKind {
  /// `Select: Option A` (multi-selects joined with `、`).
  choice,

  /// `Confirm` / `Confirm: Start`.
  confirm,

  /// `Cancel` / `Cancel: Let me think it over`.
  cancel,

  /// The first line has the marker; the second line is unrecognized (hand-edited or a future format).
  other,
}

/// One `[dsh-ui reply]` message.
final class DshUiReply {
  const DshUiReply({required this.kind, this.title, this.value, this.freetext});

  /// Choice: [labels] joined with `、`; [freetext] is what the user typed into "Other".
  factory DshUiReply.choice(List<String> labels, {String? title, String? freetext}) {
    final chosen = labels.map(_flat).whereType<String>().join(_join);
    return DshUiReply(
      kind: DshUiReplyKind.choice,
      title: _flat(title),
      value: chosen.isEmpty ? null : chosen,
      freetext: _flat(freetext),
    );
  }

  /// Confirm / cancel. [label] is the button's text; when it equals the default "Confirm"/"Cancel" it isn't repeated.
  factory DshUiReply.confirm(bool confirmed, {String? label, String? title}) {
    final kind = confirmed ? DshUiReplyKind.confirm : DshUiReplyKind.cancel;
    final fallback = confirmed ? DshUiConfirm.defaultConfirm : DshUiConfirm.defaultCancel;
    final flat = _flat(label);
    return DshUiReply(kind: kind, title: _flat(title), value: flat == null || flat == fallback ? null : flat);
  }

  final DshUiReplyKind kind;

  /// The view's title (root node `title`), used to tell which card was answered.
  final String? title;

  /// Choice: the selected labels; confirm / cancel: the button's text (null when it is the default);
  /// other: the second line verbatim.
  final String? value;

  /// Choice: the sentence the user typed in "Other" (null when they typed none).
  final String? freetext;

  /// The full text that goes out. Built only from what the user can see; no hidden values.
  String get text {
    final head = title == null ? dshUiReplyMarker : '$dshUiReplyMarker $title';
    final body = switch (kind) {
      DshUiReplyKind.choice => [
        if (value != null && value!.isNotEmpty) appL10n.viewUiReplyChoice(value!),
        if (freetext != null && freetext!.isNotEmpty) appL10n.viewUiReplyOther(freetext!),
      ].join('\n'),
      DshUiReplyKind.confirm => value == null ? appL10n.commonConfirm : appL10n.viewUiReplyConfirm(value!),
      DshUiReplyKind.cancel => value == null ? appL10n.commonCancel : appL10n.viewUiReplyCancel(value!),
      DshUiReplyKind.other => value ?? '',
    };
    return body.isEmpty ? head : '$head\n$body';
  }

  /// The small chip on the user's bubble: "Selected: Option A", "Confirmed: Start", "Cancelled".
  String get chipLabel => switch (kind) {
    DshUiReplyKind.choice => switch ((value, freetext)) {
      (final chosen?, final typed?) when chosen.isNotEmpty && typed.isNotEmpty =>
        '${appL10n.viewUiChosen(chosen)} · ${appL10n.viewUiChosenOther(typed)}',
      (_, final typed?) when typed.isNotEmpty => appL10n.viewUiChosenOther(typed),
      _ => appL10n.viewUiChosen(value ?? ''),
    },
    DshUiReplyKind.confirm => value == null ? appL10n.viewUiConfirmed : appL10n.viewUiConfirmedValue(value!),
    DshUiReplyKind.cancel => value == null ? appL10n.commonCancelled : appL10n.viewUiCancelledValue(value!),
    DshUiReplyKind.other => value == null || value!.isEmpty ? appL10n.viewUiReplied : value!,
  };

  /// The chosen labels (split on `、`). When a label itself contains `、`, [selectedIn] is more accurate.
  List<String> get choices => kind == DshUiReplyKind.choice && value != null
      ? [
          for (final part in value!.split(_join))
            if (part.trim().isNotEmpty) part.trim(),
        ]
      : const [];

  /// The entries of [labels] this reply selected (in [labels]' order). Whole-segment matching,
  /// so labels containing `、` are recognized too.
  List<String> selectedIn(List<String> labels) {
    if (kind != DshUiReplyKind.choice || value == null) return const [];
    final padded = '$_join$value$_join';
    return [
      for (final label in labels)
        if (padded.contains('$_join$label$_join')) label,
    ];
  }

  @override
  bool operator ==(Object other) =>
      other is DshUiReply &&
      other.kind == kind &&
      other.title == title &&
      other.value == value &&
      other.freetext == freetext;

  @override
  int get hashCode => Object.hash(kind, title, value, freetext);

  @override
  String toString() => text;
}

const _join = '、'; // l10n:keep reply selection protocol delimiter

/// The "Other" line: the answer the user typed themselves. Recognized in both languages
/// (written in the UI language when sent).
final _otherLine = RegExp(r'^(其他|Other)\s*[：:]\s*(.*)$');

/// Newlines collapse to spaces: labels and titles must stay on one line so the second line is recognizable.
String? _flat(String? text) {
  final flat = text?.replaceAll(RegExp(r'\s*[\r\n]+\s*'), ' ').trim();
  return flat == null || flat.isEmpty ? null : flat;
}

/// Recognizes `[dsh-ui reply]` messages; returns null for anything else.
DshUiReply? parseDshUiReply(String text) {
  final lines = text.trimLeft().split(RegExp(r'\r?\n'));
  final head = lines.first.trim();
  if (!head.startsWith(dshUiReplyMarker)) return null;
  final title = _flat(head.substring(dshUiReplyMarker.length));
  final body = [
    for (final line in lines.skip(1))
      if (line.trim().isNotEmpty) line.trim(),
  ];
  if (body.isEmpty) return DshUiReply(kind: DshUiReplyKind.other, title: title);
  final first = body.first;
  // Only "Other" was filled in: still a choice; the answer is that typed sentence.
  if (_otherLine.firstMatch(first) case final other?) {
    return DshUiReply(kind: DshUiReplyKind.choice, title: title, freetext: _flat(other.group(2)));
  }
  // l10n:keep legacy reply protocol parser
  final colon = RegExp(r'^(选择|确认|取消|Select|Confirm|Cancel)\s*(?:[：:]\s*(.*))?$').firstMatch(first);
  if (colon == null) {
    return DshUiReply(kind: DshUiReplyKind.other, title: title, value: first);
  }
  final value = _flat(colon.group(2));
  final kind = switch (colon.group(1)) {
    // l10n:keep legacy reply protocol value
    '选择' || 'Select' => DshUiReplyKind.choice,
    // l10n:keep legacy reply protocol value
    '确认' || 'Confirm' => DshUiReplyKind.confirm,
    _ => DshUiReplyKind.cancel,
  };
  // "Other: …" trailing on the next line: only meaningful for choices.
  final freetext = kind == DshUiReplyKind.choice && body.length > 1
      ? _flat(_otherLine.firstMatch(body[1])?.group(2))
      : null;
  return DshUiReply(kind: kind, title: title, value: value, freetext: freetext);
}

// ───────────────────────── Interaction state ────────────────────

enum DshUiInteraction {
  /// Tappable: the last assistant message in the conversation, the turn has ended, no user message follows.
  live,

  /// The turn is still running: disabled, so a tap doesn't turn into an interjection.
  running,

  /// The next user message is a `[dsh-ui reply]`: the choice is highlighted, read-only.
  answered,

  /// An ordinary message follows (or the model already said something else): read-only, no answer marked.
  expired,
}

/// The interaction state of the views in one assistant message. Not stored separately; derived from message order.
final class DshUiState {
  const DshUiState(this.interaction, {this.reply});

  static const live = DshUiState(DshUiInteraction.live);
  static const running = DshUiState(DshUiInteraction.running);
  static const expired = DshUiState(DshUiInteraction.expired);

  final DshUiInteraction interaction;

  /// The reply, when [DshUiInteraction.answered].
  final DshUiReply? reply;

  bool get canAnswer => interaction == DshUiInteraction.live;

  @override
  bool operator ==(Object other) => other is DshUiState && other.interaction == interaction && other.reply == reply;

  @override
  int get hashCode => Object.hash(interaction, reply);

  @override
  String toString() => 'DshUiState(${interaction.name}, $reply)';
}

/// Derives the state of the views in assistant message [messageId] from the four [DshUiInteraction] cases.
///
/// [items] is the conversation's messages (`ChatState.items`); [running] is whether the turn is still
/// running (`ChatState.running`); [pending] is the text of messages already sent but not yet in the
/// record (the `text`s of `ChatState.pending`, in send order): right after a button tap, before the
/// server echoes it back, the card already counts as answered.
DshUiState dshUiStateFor({
  required List<ChatItem> items,
  required String messageId,
  required bool running,
  List<String> pending = const [],
}) {
  final index = items.indexWhere((item) => item is AssistantChatItem && item.id == messageId);
  if (index < 0) return DshUiState.expired;
  var laterReply = false;
  for (var i = index + 1; i < items.length; i++) {
    final item = items[i];
    if (item is UserChatItem) return _after(item.text);
    if (item is AssistantChatItem && item.text.trim().isNotEmpty) {
      laterReply = true;
    }
  }
  if (pending.isNotEmpty) return _after(pending.first);
  if (laterReply) return DshUiState.expired;
  final message = items[index] as AssistantChatItem;
  if (running || message.streaming) return DshUiState.running;
  return DshUiState.live;
}

DshUiState _after(String userText) {
  final reply = parseDshUiReply(userText);
  return reply == null ? DshUiState.expired : DshUiState(DshUiInteraction.answered, reply: reply);
}

/// Whether [reply] answers [view], and with what. Returns null when the titles disagree (both present
/// and different) or the answer isn't found in the view: that card draws as expired.
DshUiAnswer? dshUiAnswerFor(DshUiView view, DshUiReply reply) {
  final title = reply.title;
  if (title != null && view.title != null && title != view.title) return null;
  switch (reply.kind) {
    case DshUiReplyKind.choice:
      for (final node in view.answerNodes) {
        if (node is! DshUiOptions) continue;
        final picked = reply.selectedIn(node.labels);
        // The typed sentence only means something for option cards with freetext enabled.
        final typed = node.freetext ? reply.freetext : null;
        if (picked.isEmpty && (typed == null || typed.isEmpty)) continue;
        // Single choice keeps only one (following DS Bot's selection rules).
        return DshUiAnswer(
          nodePath: node.path,
          selected: node.multi ? picked : picked.take(1).toList(),
          freetext: typed,
        );
      }
      return null;
    case DshUiReplyKind.confirm:
    case DshUiReplyKind.cancel:
      for (final node in view.answerNodes) {
        if (node is DshUiConfirm) {
          return DshUiAnswer(nodePath: node.path, confirmed: reply.kind == DshUiReplyKind.confirm);
        }
      }
      return null;
    case DshUiReplyKind.other:
      return null;
  }
}

/// What to highlight in an answered view.
final class DshUiAnswer {
  const DshUiAnswer({required this.nodePath, this.selected = const [], this.freetext, this.confirmed});

  /// The answered component (`view.children[1]`).
  final String nodePath;

  /// The labels chosen in `options`.
  final List<String> selected;

  /// The sentence typed into `options`' "Other" (null when nothing was typed).
  final String? freetext;

  /// `confirm`: true confirmed, false cancelled; null for anything but confirm.
  final bool? confirmed;
}
