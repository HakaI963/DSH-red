import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../pets/pet_signals.dart' show petTakesWhaleProvider;
import '../common/expand_reveal.dart';
import '../common/fade_in.dart';
import '../theme/app_icons.dart';
import '../theme/theme.dart';
import 'empty_actions.dart';
import 'widgets/whale_tail.dart';

/// One suggestion: a tinted line icon + title + one-line description; tapping fills [prompt] into the input bar.
class ChatSuggestion {
  const ChatSuggestion(this.icon, String label, String prompt, {this._detail, this.tint = SuggestionTint.blue})
    : _label = label,
      _prompt = prompt,
      _defaultIndex = null;

  const ChatSuggestion._default(this.icon, this._defaultIndex, this.tint) : _label = null, _prompt = null, _detail = null;

  final IconData icon;
  final SuggestionTint tint;
  final String? _label;
  final String? _prompt;
  final String? _detail;
  final int? _defaultIndex;

  String get label =>
      _label ??
      switch (_defaultIndex) {
        0 => appL10n.viewSuggestWorkspace,
        1 => appL10n.viewSuggestWordCount,
        2 => appL10n.viewSuggestNode,
        _ => appL10n.viewSuggestGit,
      };

  /// One line under the title: what the suggestion will do.
  String? get detail => _defaultIndex == null
      ? _detail
      : switch (_defaultIndex) {
          0 => appL10n.viewSuggestWorkspaceHint,
          1 => appL10n.viewSuggestWordCountHint,
          2 => appL10n.viewSuggestNodeHint,
          _ => appL10n.viewSuggestGitHint,
        };

  String get prompt =>
      _prompt ??
      switch (_defaultIndex) {
        0 => appL10n.viewSuggestWorkspacePrompt,
        1 => appL10n.viewSuggestWordCountPrompt,
        2 => appL10n.viewSuggestNodePrompt,
        _ => appL10n.viewSuggestGitPrompt,
      };
}

const defaultSuggestions = <ChatSuggestion>[
  ChatSuggestion._default(AppIcons.folderOpen, 0, SuggestionTint.teal),
  ChatSuggestion._default(AppIcons.code, 1, SuggestionTint.violet),
  ChatSuggestion._default(AppIcons.terminal, 2, SuggestionTint.amber),
  ChatSuggestion._default(AppIcons.tip, 3, SuggestionTint.blue),
];

/// Tips about using DSH Go, one at a time under the suggestions. Each names
/// a gesture or entry the app really has (see the handlers it describes).
List<String> defaultTips() => [
  appL10n.viewTipSteer,
  appL10n.viewTipMidRun,
  appL10n.viewTipSlash,
  appL10n.viewTipMention,
  appL10n.viewTipReplyMenu,
  appL10n.viewTipEditResend,
  appL10n.viewTipQuote,
  appL10n.viewTipTitleDetails,
  appL10n.viewTipContextRing,
  appL10n.viewTipDrawerMenu,
  appL10n.viewTipSearch,
  appL10n.viewTipSettingsSearch,
  appL10n.viewTipModelHere,
  appL10n.viewTipQuickPanel,
  appL10n.viewTipFolderNewChat,
  appL10n.viewTipSwitchHost,
  appL10n.viewTipPasteImage,
  appL10n.viewTipLauncher,
  appL10n.viewTipPetBubble,
  appL10n.viewTipPetPlay,
  appL10n.viewTipActivityStrip,
  appL10n.viewTipImageZoom,
  appL10n.viewTipQueuedRecall,
  appL10n.viewTipKeyboard,
  appL10n.viewTipShareIn,
  appL10n.viewTipShareSelect,
  appL10n.viewTipChartDrag,
  appL10n.viewTipCopyPath,
  appL10n.viewTipCompanion,
  appL10n.viewTipAnswerInline,
  appL10n.viewTipWallpaper,
];

/// Source of the current time (fixed in tests so the greeting is reproducible).
@visibleForTesting
DateTime Function() chatClock = DateTime.now;

/// The greeting: by local time.
String greetingFor(DateTime now) {
  final h = now.hour;
  if (h >= 5 && h < 11) return appL10n.viewGreetingMorning;
  if (h >= 11 && h < 13) return appL10n.viewGreetingNoon;
  if (h >= 13 && h < 18) return appL10n.viewGreetingAfternoon;
  if (h >= 18 && h < 23) return appL10n.viewGreetingEvening;
  return appL10n.viewGreetingNight;
}

/// The new chat's empty state: centred slightly high, a faint whale tail + a time-of-day greeting + a short subtitle,
/// then tiers of controls below (empty_actions.dart):
///
/// - at most one primary action, appearing only when this screen itself has a way out (engine unreachable: "Reconnect");
/// - quiet pills of one spec: the workspace pill and this chat's options (folder, preset, permissions);
/// - a 2×2 grid of suggestion cards: tinted small icon + title + one-line description;
/// - a tips line at the very bottom, tap to cycle to the next tip.
///
/// The input bar is the real star of this screen; these are just quiet starting points handed over gently.
///
/// ```
///                 ⌒)
///               Good afternoon
///           What shall we do today?
///         ( ▢ In "dsh-app" ⌄ )         ← when disconnected this becomes a tinted "Reconnect"
///      ( ⚒ Standard mode ⌄ ) ( ⛨ Full access ⌄ )
///
///   ┌ ▣ Tour the workspace ┐ ┌ ▣ Write a tiny script ┐
///   └ list files & folders ┘ └ count words, run it  ┘
///   ┌ ▣ New project    ┐ ┌ ▣ Git explained  ┐
///   └ Node.js + TS   ┘ └ rebase & merge ┘
///    💡 Type @ to reference files in the workspace…   3/12 ›
/// ```
///
/// Left/right sit 12 from the screen like the header and input bar; on wide screens it matches the input bar's width, centred; on first
/// appearance it fades in top to bottom. With the engine unreachable, suggestions, options and tips all fold away, leaving only "Reconnect".
class ChatEmptyState extends StatelessWidget {
  const ChatEmptyState({
    super.key,
    required this.connected,
    required this.onSuggestion,
    this.connecting = false,
    this.starting = false,
    this.tidying = false,
    this.onReconnect,
    this.idle,
    this.now,
    this.suggestions = defaultSuggestions,
    this.workspace,
    this.onWorkspace,
    this.options,
    this.tips,
    this.tipStart,
  });

  final bool connected;
  final bool connecting;

  /// The on-device engine is booting.
  final bool starting;

  /// Booting includes the one-time tidy of plugin files (RuntimeStatus.tidyingFiles).
  final bool tidying;

  /// The engine could not be reached: the one primary pill, "Reconnect",
  /// where the workspace chip goes; the suggestions fold away.
  final VoidCallback? onReconnect;

  /// The local device is down and won't come up by itself (not installed, or stopped
  /// with "start automatically when the app opens" off): the subtitle says so and the one primary
  /// pill fixes it ("Install the runtime" / "Start the engine").
  final ChatIdleAction? idle;
  final ValueChanged<ChatSuggestion> onSuggestion;

  /// The workspace the new conversation starts in (null: the default).
  final String? workspace;

  /// Switches [workspace].
  final VoidCallback? onWorkspace;

  /// The new conversation's options (folder, preset, permissions), one row of
  /// quiet chips under the workspace chip. Shown only while connected.
  final Widget? options;

  /// The tip line's tips; null = [defaultTips], empty = no tip line.
  final List<String>? tips;

  /// The first tip shown (tests); defaults to a random one.
  final int? tipStart;

  /// Injected by tests; defaults to the current time.
  final DateTime? now;
  final List<ChatSuggestion> suggestions;

  /// Same side margin and width cap as the header pills and the composer.
  static const sideMargin = AppSpace.floatInset;
  static const maxWidth = AppSpace.floatingWidth;

  /// Subtitle → the pill or chip under it.
  static const slotGap = 12.0;

  /// The workspace chip → the options row.
  static const optionsGap = 8.0;

  /// The pill or chips → the suggestions.
  static const suggestionsGap = 28.0;

  /// The suggestions → the tip line.
  static const tipGap = 6.0;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final dsh = DshColors.of(context);
    final retry = connected ? null : onReconnect;
    final idle = connected || retry != null ? null : this.idle;
    final subtitle = connected
        ? l10n.viewEmptySubtitle
        : retry != null
        ? l10n.commonEngineUnreachable
        : idle != null
        ? idle.message
        : starting
        ? (tidying ? l10n.phoneEngineTidyingFilesEllipsis : l10n.viewEmptyStarting)
        : connecting
        ? l10n.viewEmptyConnecting
        : l10n.viewEmptyDisconnected;

    var order = 0;
    Widget enter(Widget child) => FadeSlideIn(index: order++, child: child);
    final tipList = tips ?? defaultTips();

    // One slot under the subtitle: the primary pill or the workspace chip,
    // the same height, swapped in place.
    final Widget? slot = retry != null
        ? EmptyPrimaryPill(key: const ValueKey('reconnect'), label: l10n.viewEmptyReconnect, onTap: retry)
        : idle != null
        ? EmptyPrimaryPill(key: ValueKey(idle.label), label: idle.label, onTap: idle.onTap)
        : workspace != null && connected
        ? ConstrainedBox(
            key: const ValueKey('workspace'),
            constraints: const BoxConstraints(maxWidth: 280),
            child: QuietChip(
              icon: AppIcons.workspace,
              label: l10n.viewEmptyWorkspace(workspace!),
              trailing: onWorkspace == null ? null : AppIcons.expand,
              onTap: onWorkspace,
              onTapHint: l10n.viewEmptySwitchWorkspace,
            ),
          )
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: sideMargin),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The pet stands on the composer below: one mascot a screen,
              // so the still whale tail fades while the pet is drawn. Its
              // room stays, so nothing moves when the pet comes and goes.
              enter(
                Consumer(
                  builder: (context, ref, child) => AnimatedOpacity(
                    opacity: ref.watch(petTakesWhaleProvider) ? 0 : 1,
                    duration: AppMotion.of(context, AppMotion.standard),
                    curve: AppMotion.std,
                    child: child,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Center(
                      child: WhaleTail(
                        still: true,
                        height: 40,
                        color: whaleColorFor(theme.brightness).withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ),
              ),
              enter(
                Text(
                  greetingFor(now ?? chatClock()),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displaySmall?.copyWith(color: theme.colorScheme.onSurface),
                ),
              ),
              const SizedBox(height: 4),
              enter(
                AnimatedSwitcher(
                  duration: AppMotion.of(context, AppMotion.quick),
                  child: Text(
                    subtitle,
                    key: ValueKey(subtitle),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(color: dsh.textTertiary),
                  ),
                ),
              ),
              if (slot != null) ...[
                const SizedBox(height: slotGap),
                enter(
                  Center(
                    child: AnimatedSwitcher(duration: AppMotion.of(context, AppMotion.quick), child: slot),
                  ),
                ),
              ],
              if (connected && options != null) ...[
                const SizedBox(height: optionsGap),
                enter(Center(child: options!)),
              ],
              if (suggestions.isNotEmpty || tipList.isNotEmpty)
                ExpandReveal(
                  open: retry == null && idle == null,
                  child: Padding(
                    padding: const EdgeInsets.only(top: suggestionsGap),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (suggestions.isNotEmpty)
                          SuggestionCards(
                            suggestions: suggestions,
                            enabled: connected,
                            onSuggestion: onSuggestion,
                            firstIndex: order,
                          ),
                        if (connected && tipList.isNotEmpty) ...[
                          const SizedBox(height: tipGap),
                          FadeSlideIn(
                            index: order + suggestions.length,
                            child: TipLine(tips: tipList, start: tipStart),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// [ChatEmptyState.idle]: what the subtitle says and the pill under it.
class ChatIdleAction {
  const ChatIdleAction({required this.message, required this.label, required this.onTap});

  final String message;
  final String label;
  final VoidCallback onTap;
}
