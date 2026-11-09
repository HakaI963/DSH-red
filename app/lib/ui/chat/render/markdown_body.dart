// Portions derived from PiPilot (https://github.com/CikeSeven/pi_pilot), MIT, Copyright (c) 2026 CikeSeven. See THIRD_PARTY_NOTICES.md.

import 'dart:async';

import 'package:dsh_client/dsh_client.dart' show DshRemoteException;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/l10n.dart';
import '../../../links/page_links.dart' show openReplyPageLink;
import '../../../state/artifacts.dart';
import '../../../state/table_tint_state.dart';
import '../../../state/workspace_state.dart';
import '../../common/edge_fade.dart';
import '../../common/streaming_cursor.dart';
import '../../theme/app_icons.dart';
import '../../plugins/native/native_taps.dart' show openConfirmedLink;
import '../../theme/theme.dart';
import '../artifact_preview.dart';
import '../dsh_ui/dsh_ui.dart';
import 'code_block.dart';
import 'markdown_blocks.dart';
import 'markdown_image.dart';
import 'markdown_math.dart';
import 'math_syntax.dart';
import 'stream_repair.dart';
import 'table_syntax.dart';

/// The streaming cursor's placeholder (a private-use-area code point). Appended to the body's end and turned into the
/// cursor by [InlinePattern] — so the cursor rides along with the last stretch of text instead of dropping orphaned below the body.
const _cursorSentinel = '\uE000';

/// Kept outside `<details>`: the HTML models commonly write elsewhere renders per gpt_markdown's default
/// table (`<br>` breaks, `<sub>` / `<sup>`, `<kbd>`, `<u>`, `<mark>`…);
/// unrecognized tags show verbatim; `<details>` becomes a collapsible block.
final Map<String, HtmlTag?> _htmlTags = {
  'details': const HtmlTag.block(MarkdownDisclosure.build),
  'summary': const HtmlTag.block(),
};

/// Markdown rendering for assistant bodies.
///
/// - Body type shares its source with the user bubble ([AppType.chatBody]); streaming and final never jump in size;
/// - Fenced code goes to [CodeBlock] (Mist highlighting + copy);
/// - Inline code is a tiny well painted under the text (gpt_markdown 1.4's chip); wrappable and selectable;
/// - Math: `$…$` / `\(…\)` inline, `$$…$$` / `\[…\]` block ([MarkdownMath]);
///   prices (`$5 and $10`) are not math ([normalizeMath]);
/// - Images: workspace files, web URLs, `data:` all render ([MarkdownImage]);
/// - while [streaming], patch the still-growing tail ([repairStreamingMarkdown]) and
///   put a breathing cursor at the last span's end.
class MarkdownBody extends StatefulWidget {
  const MarkdownBody({
    super.key,
    required this.text,
    this.streaming = false,
    this.reveal = false,
    this.selectable = true,
    this.secondary = false,
    this.repairBareViews = false,
  });

  final String text;
  final bool streaming;

  /// The fluid tier's streamed reply: gpt_markdown paces the text itself, fades in
  /// the newest words, and only rebuilds the part that can still change, so an update
  /// costs the same however long the reply is. No cursor and no tail repair: it holds
  /// back half-written markup on its own. Keep it on after [streaming] ends, for the
  /// life of this body: the tree stays and nothing moves when the reply finishes.
  final bool reveal;
  final bool selectable;

  /// Secondary typography (the thinking process): one size smaller, secondary text color, headings stay unobtrusive.
  final bool secondary;

  /// Assistant replies: when the model writes `dsh-ui` JSON bare into the body, treat it as a view too
  /// (see [fenceBareDshUiViews]). Other Markdown (docs, explainer pages) doesn't get this.
  final bool repairBareViews;

  /// Max width of a single table column; longer cells wrap inside their column rather than stretching the whole table out.
  static const _maxColumnWidth = 260.0;

  static final _themes = <String, Expando<GptMarkdownThemeData>>{};
  static final _secondaryThemes = <String, Expando<GptMarkdownThemeData>>{};

  /// Built once per ThemeData (the factory constructs a whole ThemeData internally — not cheap).
  ///
  /// The cache keys on the language + table-background combination: "follow theme" and "no background" are two
  /// themes on the same page, so changing the setting shouldn't discard and rebuild the old one.
  static GptMarkdownThemeData _themeFor(ThemeData theme, bool secondary, L10n l10n, TableTint tint) {
    final cache = (secondary ? _secondaryThemes : _themes).putIfAbsent(
      '${l10n.localeName}|${tint.name}',
      () => Expando<GptMarkdownThemeData>('markdownTheme'),
    );
    return cache[theme] ??= _buildTheme(theme, l10n, secondary: secondary, tint: tint);
  }

  static GptMarkdownThemeData _buildTheme(
    ThemeData theme,
    L10n l10n, {
    bool secondary = false,
    TableTint tint = TableTint.follow,
  }) {
    final colors = theme.colorScheme;
    final dsh = theme.extension<DshColors>()!;
    // The three table-background tiers differ only in two fills; striping sits one notch paler than the header — bands show, yet
    // doesn't fight the text.
    final tableFills = tableTintFills(
      tint,
      headerColor: dsh.codeWellHeader,
      stripeColor: colors.onSurface.withValues(alpha: theme.brightness == Brightness.dark ? 0.06 : 0.05),
    );
    final shrink = secondary ? 0.9 : 1.0;
    TextStyle heading(double size, {double height = 1.45}) => TextStyle(
      fontSize: size * shrink,
      fontWeight: FontWeight.w600,
      height: height,
      color: secondary ? colors.onSurfaceVariant : colors.onSurface,
      leadingDistribution: TextLeadingDistribution.even,
    );
    return GptMarkdownThemeData(
      brightness: theme.brightness,
      h1: heading(20, height: 1.4),
      h2: heading(18, height: 1.4),
      h3: heading(16.5),
      h4: heading(16),
      h5: heading(15),
      h6: heading(15),
      hrLineThickness: 0.5,
      hrLineColor: colors.outlineVariant,
      hrLinePadding: const EdgeInsets.symmetric(vertical: 12),
      linkColor: colors.primary,
      linkHoverColor: colors.primary,
      autoAddDividerLineAfterH1: false,
      inlineCode: InlineCodeStyle(
        fontFamily: AppType.monoFamily,
        fontFamilyFallback: AppType.monoFallback,
        fontSizeFactor: 0.875,
        color: dsh.codeWellFg,
        backgroundColor: dsh.codeWellBg,
        borderColor: dsh.codeWellBorder,
        borderWidth: 0.5,
        borderRadius: const Radius.circular(AppShape.xs),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      ),
      styleSheet: GptMarkdownStyleSheet(
        blockQuote: BlockQuoteStyle(
          barWidth: 3,
          barColor: colors.outlineVariant,
          barRadius: const Radius.circular(2),
          textStyle: TextStyle(color: colors.onSurfaceVariant),
        ),
        list: ListStyle(
          bulletColor: colors.onSurfaceVariant,
          bulletSize: 5,
          markerTextStyle: TextStyle(color: colors.onSurfaceVariant),
        ),
        // GitHub alert blocks: pale fill in the status color + a left color bar, titles in localized words.
        alert: AlertStyle(
          borderRadius: const Radius.circular(AppShape.sm),
          padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 14, 10),
          // Same block spacing as paragraphs; no extra margin.
          margin: EdgeInsets.zero,
          titleStyle: const TextStyle(fontWeight: FontWeight.w600),
          titleGap: 4,
          note: AlertStyle(title: l10n.chatAlertNote, color: dsh.info, icon: AppIcons.info),
          tip: AlertStyle(title: l10n.chatAlertTip, color: dsh.success, icon: AppIcons.tip),
          important: AlertStyle(title: l10n.chatAlertImportant, color: dsh.ansi[5], icon: AppIcons.important),
          warning: AlertStyle(title: l10n.chatAlertWarning, color: dsh.warning, icon: AppIcons.warning),
          caution: AlertStyle(title: l10n.chatAlertCaution, color: dsh.danger, icon: AppIcons.caution),
        ),
        // `<mark>`: a warm highlighter-yellow ground.
        highlight: HighlightStyle(backgroundColor: dsh.warningContainer, color: dsh.onWarningContainer),
        link: LinkStyle(
          color: colors.primary,
          hoverColor: colors.primary,
          decoration: TextDecoration.underline,
          decorationThickness: 0.6,
        ),
        hr: HrStyle(thickness: 0.5, color: colors.outlineVariant),
        // Tables: fine line grid, square corners, bold header; column widths follow content but a single column
        // never exceeds [_maxColumnWidth] (long text wraps inside the cell); when the whole table doesn't fit it scrolls horizontally.
        // Square corners: header and striped-row fills are rectangular and aren't clipped to a radius (gpt_markdown
        // 1.4.0); rounded corners would expose square color blobs at the four corners; switch back to AppShape.md once upstream fixes it.
        table: TableStyle(
          // A touch heavier than the code well's stroke: grid lines must stay visible in dark mode too.
          borderColor: colors.onSurface.withValues(alpha: theme.brightness == Brightness.dark ? 0.18 : 0.14),
          borderWidth: 0.5,
          borderRadius: Radius.zero,
          // The three background tiers differ only in these two fills (Settings → Interface → Table background).
          headerBackground: tableFills.header,
          rowStripeColor: tableFills.stripe,
          cellPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          columnWidth: const MinColumnWidth(IntrinsicColumnWidth(), FixedColumnWidth(_maxColumnWidth)),
          overflow: TableOverflow.scroll,
        ),
      ),
    );
  }

  static final _cursorPattern = InlinePattern(
    pattern: RegExp(_cursorSentinel),
    builder: (context, match, style) => _cursorSpan(style),
  );

  static InlineSpan _cursorSpan(TextStyle style) {
    final fontSize = style.fontSize ?? 16;
    final lineHeight = fontSize * (style.height ?? 1.6);
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.only(left: 2),
        // The cursor paints on its own layer: the breathing animation repaints only these 2.5px, not the whole body.
        child: RepaintBoundary(child: StreamingCursor(height: lineHeight * 0.66)),
      ),
    );
  }

  static final _streamingPatterns = [_cursorPattern];

  // Builders stay static. gpt_markdown 1.4.0's config.isSame ignores
  // onLinkTap identity; its cached spans may retain this context-only callback.
  static void _onLinkTap(BuildContext context, String url, String title) {
    if (!context.mounted) return;
    // `dshgo://open/<page>`: the guide's links to the app's own pages.
    if (openReplyPageLink(context, url)) return;
    final uri = linkToOpen(url);
    if (uri != null) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    final scope = MarkdownImageScope.maybeOf(context);
    // `[site](example.com)`: a site written without https, unless the
    // workspace really has a file by that name.
    final site = bareDomainLink(url);
    // Detached share/replay text must not borrow an unrelated active session.
    if (scope == null) {
      if (site != null) unawaited(openConfirmedLink(context, site));
      return;
    }
    final path = workspaceLinkPath(url, baseDir: scope.baseDir);
    if (path == null) return;
    if (site != null) {
      unawaited(_openFileOrSite(context, scope.sessionId, path, site));
      return;
    }
    _preview(context, scope.sessionId, path);
  }

  static void _preview(BuildContext context, String sessionId, String path) {
    Navigator.of(context).push(
      ArtifactPreviewPage.route(
        sessionId: sessionId,
        artifact: Artifact(path: path, origin: ArtifactOrigin.linked, turn: 0),
      ),
    );
  }

  /// The workspace file at [path] when there is one (a folder by that name
  /// too: its preview says so); otherwise [site], after the browser prompt.
  static Future<void> _openFileOrSite(BuildContext context, String sessionId, String path, Uri site) async {
    WorkspaceSource? source;
    try {
      source = ProviderScope.containerOf(context, listen: false).read(workspaceSourceProvider(sessionId));
    } catch (_) {
      // No provider scope above this text: nothing to look the file up in.
    }
    var file = false;
    if (source != null) {
      try {
        await source.stat(path);
        file = true;
      } on DshRemoteException catch (e) {
        file = e.code == 'workspace-file/not-regular-file';
      } catch (_) {
        // Offline or the Host failed: the site is what the link most likely meant.
      }
    }
    if (!context.mounted) return;
    if (file) {
      _preview(context, sessionId, path);
    } else {
      await openConfirmedLink(context, site);
    }
  }

  /// File endings a bare `name.ext` link reads as a file by, even where the
  /// ending is also a country's domain (`.md`, `.py`, `.rs`, `.sh`, `.pl`…).
  static const _fileEndings = {
    'md',
    'py',
    'rs',
    'sh',
    'pl',
    'pm',
    'so',
    'cc',
    'ps',
    'ml',
    'mk',
    'sv',
    'tf',
    'bz',
    'gz',
    'xz',
    'js',
    'ts',
    'go',
    'rb',
    'cs',
    'kt',
    'hs',
    'el',
    'ex',
    'fs',
    'jl',
    'db',
    'hh',
    'cp',
    'vb',
    'nb',
    'zip',
    'mov',
    'pro',
  };

  /// Endings of three letters or more that read as a website.
  static const _siteEndings = {
    'com',
    'net',
    'org',
    'edu',
    'gov',
    'mil',
    'int',
    'info',
    'biz',
    'dev',
    'app',
    'xyz',
    'top',
    'site',
    'online',
    'tech',
    'cloud',
    'page',
    'blog',
    'shop',
    'store',
    'art',
    'wiki',
    'news',
    'live',
    'life',
    'world',
    'today',
    'space',
    'website',
    'link',
    'club',
    'name',
    'mobi',
    'asia',
    'email',
    'studio',
    'design',
    'media',
    'network',
    'games',
    'chat',
    'fun',
    'icu',
    'vip',
    'ltd',
    'group',
    'global',
    'run',
    'codes',
    'tools',
    'software',
    'one',
    'plus',
    'social',
    'ink',
  };

  static final _hostLabel = RegExp(r'^[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$');

  /// `example.com`, `www.example.com/docs`, `github.io` — a link target that
  /// names a website without `https://` — as the https URL; null for
  /// anything else, a file name like `notes.md` or `main.py` included.
  @visibleForTesting
  static Uri? bareDomainLink(String url) {
    var target = url.trim();
    if (target.startsWith('<') && target.endsWith('>')) {
      target = target.substring(1, target.length - 1).trim();
    }
    if (target.isEmpty || target.contains(RegExp(r'\s'))) return null;
    final uri = Uri.tryParse(target);
    if (uri == null || uri.hasScheme || uri.hasAuthority) return null;
    // The host as written: Uri drops a leading `./`, which makes it a path.
    final end = target.indexOf(RegExp('[/?#]'));
    final host = (end < 0 ? target : target.substring(0, end)).toLowerCase();
    final labels = host.split('.');
    if (labels.length < 2 || !labels.every(_hostLabel.hasMatch)) return null;
    final ending = labels.last;
    if (!RegExp(r'^[a-z]{2,}$').hasMatch(ending) || _fileEndings.contains(ending)) return null;
    final site = ending.length == 2 || _siteEndings.contains(ending) || labels.first == 'www';
    return site ? Uri.tryParse('https://$target') : null;
  }

  /// External links open only on the web or as an email: the text is
  /// model-written (and can echo a web page), so `tel:`, `sms:`, `intent:`
  /// or another app's deep link (payments included) must not launch apps.
  @visibleForTesting
  static Uri? linkToOpen(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return null;
    return switch (uri.scheme.toLowerCase()) {
      'http' || 'https' when uri.host.isNotEmpty => uri,
      'mailto' => uri,
      _ => null,
    };
  }

  /// File links are read by the existing session preview, never launched as
  /// platform URLs. Unknown schemes and remote file authorities stay blocked.
  @visibleForTesting
  static String? workspaceLinkPath(String url, {String? baseDir}) => resolveWorkspaceLink(url, baseDir: baseDir);

  static Widget _codeBuilder(BuildContext context, String name, String code, bool closed) {
    // A closed block won't change. Handing back the same widget lets Flutter skip it,
    // or every block of the reply would rebuild on every update.
    final reveal = closed ? context.getInheritedWidgetOfExactType<_RevealStreaming>() : null;
    if (reveal != null) return reveal.blocks['$name\n$code'] ??= _buildCode(context, name, code, closed);
    return _buildCode(context, name, code, closed);
  }

  static Widget _buildCode(BuildContext context, String name, String code, bool closed) {
    final info = name.trim();
    final language = info.isEmpty ? null : info.split(RegExp(r'\s+')).first;
    // A visual reply (dsh-ui): drawn as native cards. The cursor sentinel inside an open fence means it is still
    // streaming; open without it means the reply was cut short.
    if (language == 'dsh-ui') {
      return DshUiBlock(
        source: code.replaceAll(_cursorSentinel, ''),
        streaming: !closed && (code.contains(_cursorSentinel) || _RevealStreaming.of(context)),
        closed: closed,
      );
    }
    // A display formula still streaming in ([normalizeMath]): its source,
    // muted, until the closing `$$` arrives and it can be drawn whole.
    if (language == pendingMathLanguage) {
      final style = AppType.chatBody(context);
      return MathSource(
        source: code.replaceAll(_cursorSentinel, ''),
        style: style,
        trailing: code.contains(_cursorSentinel) ? _cursorSpan(style) : null,
      );
    }
    return CodeBlock(
      code: code.replaceAll(_cursorSentinel, ''),
      // The fence info string may carry attributes (```json title="…"); take only the first token.
      language: language,
      replyActions: true,
    );
  }

  /// Headings are header nodes that screen readers can jump between one by one.
  static Widget _headingBuilder(BuildContext context, int level, Widget content, HeadingStyle style) =>
      Semantics(header: true, container: true, child: content);

  /// Task lists `- [ ]` / `- [x]`: read-only square-box icons. The package defaults to Material's
  /// [Checkbox], which demands a Material ancestor the chat list lacks — it would error and overflow.
  static Widget _checkboxBuilder(BuildContext context, bool checked, Widget content, CheckboxStyle style) {
    final colors = Theme.of(context).colorScheme;
    // TaskBox: a bullet item that opens with this box draws no bullet.
    return TaskBox(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        textBaseline: TextBaseline.alphabetic,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        children: [
          Text.rich(
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: TaskBox.gap),
                child: Icon(
                  checked ? AppIcons.checkboxOn : AppIcons.checkboxOff,
                  size: TaskBox.size,
                  color: checked ? colors.primary : colors.onSurfaceVariant,
                ),
              ),
            ),
          ),
          Flexible(child: content),
        ],
      ),
    );
  }

  /// What gpt_markdown is given for [text]: maths delimiters normalised,
  /// tables separated from the paragraph above and their headers bold and,
  /// while [streaming], the unfinished tail repaired and the cursor sentinel
  /// placed. With [repairBareViews] a bare `dsh-ui` JSON block gets its fence
  /// back first (see [fenceBareDshUiViews]).
  @visibleForTesting
  static String prepareSource(String text, {bool streaming = false, bool repairBareViews = false}) =>
      _prepareSource(text, streaming: streaming, repairBareViews: repairBareViews);

  /// Characters a second when the model is slower than this; the reveal goes faster
  /// by itself when it would fall behind. Near a comfortable reading pace, so the text
  /// flows evenly instead of catching up in bursts.
  static const _revealPace = 120.0;

  /// How long the newest words take to fade in.
  static const _revealFade = 0.24;

  /// [text] for the reveal. Only ever appended to while streaming, as the reveal needs
  /// (a rewrite far from the end would retype the message): a table's header is bolded
  /// as its delimiter row arrives, right at the end and for good, so its columns don't
  /// change when the reply finishes. Formulas are left to the library's own hold.
  static String _prepareRevealed(String text, {required bool repairBareViews}) {
    final repaired = repairBareViews ? fenceBareDshUiViews(text) : text;
    return boldTableHeaders(blankLineBeforeTables(normalizeMath(repaired)));
  }

  static String _prepareSource(
    String text, {
    bool streaming = false,
    bool repairBareViews = false,
    StreamingMarkdownRepair? repair,
  }) {
    final repaired = repairBareViews ? fenceBareDshUiViews(text) : text;
    final source = boldTableHeaders(blankLineBeforeTables(normalizeMath(repaired, streaming: streaming)));
    if (!streaming) return source;
    return _withCursor(repair?.repair(source) ?? repairStreamingMarkdown(source));
  }

  /// [text] with the cursor sentinel where the reader's eye is: at the end
  /// of the last line, except that a closing fence or a display formula's
  /// `\]` must stay alone on its line, and a table row takes it inside its
  /// last cell rather than as a new cell after the pipe.
  static String _withCursor(String text) {
    final last = text.substring(text.lastIndexOf('\n') + 1).trim();
    if (_fenceLine.hasMatch(last) || last.endsWith(r'\]')) {
      return '$text\n$_cursorSentinel';
    }
    if (last.length > 1 && last.startsWith('|') && last.endsWith('|')) {
      final pipe = text.lastIndexOf('|');
      return '${text.substring(0, pipe).trimRight()} $_cursorSentinel '
          '${text.substring(pipe)}';
    }
    return '$text$_cursorSentinel';
  }

  static final _fenceLine = RegExp(r'^(?:>\s*)*(?:`{3,}|~{3,})\s*$');

  static InlineSpan _inlineCodeBuilder(BuildContext context, String code, TextStyle style, InlineCodeStyle codeStyle) =>
      CodeTextSpan(
        text: code.replaceAll(_cursorSentinel, ''),
        codeStyle: codeStyle,
        style: style.copyWith(fontFeatures: AppType.monoFeatures),
      );

  @override
  State<MarkdownBody> createState() => _MarkdownBodyState();
}

class _MarkdownBodyState extends State<MarkdownBody> {
  StreamingMarkdownRepair? _repair;

  // Preparation depends only on text and streaming, not theme, text scale or
  // selection. Keep one result for this mounted body; unrelated stream rows
  // can rebuild its parent without rescanning the unchanged Markdown.
  late String _source = _prepare();

  String _prepare() {
    if (widget.reveal) {
      return MarkdownBody._prepareRevealed(widget.text, repairBareViews: widget.repairBareViews);
    }
    _repair = widget.streaming ? (_repair ?? StreamingMarkdownRepair()) : null;
    return MarkdownBody._prepareSource(
      widget.text,
      streaming: widget.streaming,
      repairBareViews: widget.repairBareViews,
      repair: _repair,
    );
  }

  /// Whether this tree contains a ProviderScope. Walks up only once when dependencies change — the body rebuilds
  /// every 32ms while streaming, so no need to run the InheritedWidget lookup each time.
  ///
  /// ProviderScope sits at the app root and never vanishes once installed, so caching until the next
  /// didChangeDependencies is safe.
  bool _scoped = true;

  /// Finished code blocks of a revealed reply: see [_RevealStreaming.blocks].
  final _blocks = <String, Widget>{};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scoped = _hasProviderScope(context);
  }

  @override
  void didUpdateWidget(MarkdownBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.streaming != widget.streaming ||
        oldWidget.reveal != widget.reveal ||
        oldWidget.repairBareViews != widget.repairBareViews) {
      _source = _prepare();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final body = widget.secondary
        ? AppType.chatBody(context, scale: 0.9, color: theme.colorScheme.onSurfaceVariant)
        : AppType.chatBody(context, color: theme.colorScheme.onSurface);
    final source = _source;

    // The table background is a user setting; only the theme tracks it. The body widget itself stays one instance,
    // so toggling the setting doesn't make gpt_markdown reparse everything.
    final text = GptMarkdown(
      source,
      style: body,
      followLinkColor: false,
      htmlTags: _htmlTags,
      // The tail is repaired here (and open formulas shown as source), so
      // the package must not complete open `\(` / `\[` on its own.
      isStreaming: widget.reveal && widget.streaming,
      animation: widget.reveal ? GptMarkdownAnimation.fade : GptMarkdownAnimation.none,
      blockAnimation: widget.reveal ? GptMarkdownBlockAnimation.fadeIn : GptMarkdownBlockAnimation.none,
      charactersPerSecond: MarkdownBody._revealPace,
      revealFadeSeconds: MarkdownBody._revealFade,
      inlinePatterns: widget.streaming && !widget.reveal ? MarkdownBody._streamingPatterns : null,
      onLinkTap: (url, title) => MarkdownBody._onLinkTap(context, url, title),
      codeBuilder: MarkdownBody._codeBuilder,
      inlineCodeBuilder: MarkdownBody._inlineCodeBuilder,
      checkboxBuilder: MarkdownBody._checkboxBuilder,
      headingBuilder: MarkdownBody._headingBuilder,
      inlineLatexBuilder: MarkdownMath.inline,
      blockLatexBuilder: MarkdownMath.block,
      imageBuilder: markdownImageBuilder,
      orderedListBuilder: MarkdownLists.ordered,
      unOrderedListBuilder: MarkdownLists.unordered,
    );

    Widget withTint(TableTint tint) =>
        GptMarkdownTheme(gptThemeData: MarkdownBody._themeFor(theme, widget.secondary, l10n, tint), child: text);

    // Goldens and geometry tests don't wrap a ProviderScope: then it paints at the default tier.
    Widget markdown = _scoped
        ? Consumer(builder: (context, ref, _) => withTint(ref.watch(tableTintProvider)))
        : withTint(TableTint.follow);
    // When tables or block math don't fit horizontally, edge fade-outs hint that more can be panned.
    markdown = ScrollConfiguration(behavior: const EdgeFadeScrollBehavior(), child: markdown);
    if (widget.reveal) markdown = _RevealStreaming(streaming: widget.streaming, blocks: _blocks, child: markdown);
    if (widget.selectable) markdown = SelectionArea(child: markdown);
    return MarkdownGalleryScope(child: markdown);
  }
}

/// Whether the current subtree has a ProviderScope; without one, paint the default table background.
bool _hasProviderScope(BuildContext context) {
  try {
    ProviderScope.containerOf(context, listen: false);
    return true;
  } on StateError {
    return false;
  }
}

/// Whether the reveal's reply is still streaming, for the builders below it: with no
/// cursor in the source, an open fence can't tell "still arriving" from "cut short".
class _RevealStreaming extends InheritedWidget {
  const _RevealStreaming({required this.streaming, required this.blocks, required super.child});

  final bool streaming;

  /// Finished code blocks by name and content.
  final Map<String, Widget> blocks;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_RevealStreaming>()?.streaming ?? false;

  @override
  bool updateShouldNotify(_RevealStreaming oldWidget) => streaming != oldWidget.streaming;
}
