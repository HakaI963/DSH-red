// The app-side API for native plugin views (docs/design/native-plugins-views.md
// §9). A plugin view is drawn by the dsh-ui renderer with the plugin profile;
// this file is what the slots (tool cards, panels, the composer strip) use.

import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../../../plugins/native/native_icons.dart' show nativeIcon;
import '../../chat/dsh_ui/dsh_ui_blocks.dart';
import '../../chat/dsh_ui/dsh_ui_model.dart';
import '../../chat/dsh_ui/dsh_ui_plugin.dart';
import '../../chat/dsh_ui/dsh_ui_plugin_styles.dart';
import '../../chat/dsh_ui/dsh_ui_plugin_controls.dart';
import '../../chat/dsh_ui/dsh_ui_plugin_controls_state.dart';
import '../../chat/dsh_ui/dsh_ui_style.dart';
import '../../chat/dsh_ui/dsh_ui_widgets.dart' show DshUiNodeView;
import '../../chat/media/media_viewer.dart' show openGalleryPictures;
import '../../chat/widgets/stream_row.dart';
import '../../common/expand_reveal.dart';
import '../../theme/app_icons.dart';
import '../../theme/theme.dart';

export '../../chat/dsh_ui/dsh_ui_bind.dart' show pluginBindingText, resolvePluginBinding, resolvePluginBindings;
export '../../chat/dsh_ui/dsh_ui_blocks.dart' show PluginImages;
export '../../chat/dsh_ui/dsh_ui_model.dart'
    show DshUiInvalid, DshUiIssue, DshUiParse, DshUiParsed, DshUiView, dshUiPluginComponents;
export '../../chat/dsh_ui/dsh_ui_plugin.dart';

/// A plugin view: v1 retains its original rendering; v2 includes the fixed
/// host attribution boundary. [PluginFrame] supplies the outer plugin name.
/// [view] and [data] are decoded JSON. An invalid root draws one error line.
class PluginView extends StatefulWidget {
  const PluginView({
    super.key,
    required this.view,
    this.data,
    this.onAction,
    this.clock,
    this.budget = PluginViewBudget.panel,
    this.imageResolver,
    this.showTitle = true,
    this.animate = false,
  });

  final Object? view;
  final Object? data;

  /// null: read-only (`actions`, `confirm` hidden, `options` read-only, `list` rows untappable).
  final PluginActionHandler? onAction;

  /// Uses the host clock at the real tap, before any local request queue.
  final DateTime Function()? clock;
  final PluginViewBudget budget;

  /// Defaults are taken from the enclosing [PluginImages].
  final PluginImageResolver? imageResolver;

  /// Draws the view's own `title` (can be turned off when the panel already has a title bar).
  final bool showTitle;

  /// Chart growth animation (only right after content arrives).
  final bool animate;

  @override
  State<PluginView> createState() => _PluginViewState();
}

class _PluginViewState extends State<PluginView> {
  late final PluginDraftController _drafts = PluginDraftController(
    data: widget.data,
    clock: () => widget.clock?.call() ?? DateTime.now(),
  )..addListener(_changed);

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(PluginView old) {
    super.didUpdateWidget(old);
    _drafts.syncRemote(widget.data);
    _drafts.setHandler(widget.budget == PluginViewBudget.panel ? widget.onAction : null);
  }

  @override
  void dispose() {
    _drafts.removeListener(_changed);
    _drafts.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A palette change rebuilds this view: one that asked for
    // `accent: "app"` is parsed again with the new accent (the cache knows).
    Theme.of(context);
    _drafts.setHandler(widget.budget == PluginViewBudget.panel ? widget.onAction : null);
    final parsed = parsePluginView(widget.view, data: _drafts.data, budget: widget.budget);
    if (parsed is DshUiInvalid) {
      _drafts.syncInputs(const []);
      return const PluginViewError();
    }
    final view = (parsed as DshUiParsed).view;
    _drafts.syncInputs(view.nodes.whereType<DshUiInput>());
    final body = PluginViewBody(
      view: view,
      budget: widget.budget,
      onAction: view.version >= 2 ? (_drafts.enabled ? _drafts.invoke : null) : widget.onAction,
      imageResolver: widget.imageResolver,
      showTitle: widget.showTitle,
      animate: widget.animate,
    );
    return view.version >= 2 ? PluginControlsScope(controller: _drafts, child: body) : body;
  }
}

/// The already-parsed view (the tool card parsed it once inside `ToolView`; use this directly).
class PluginViewBody extends StatelessWidget {
  const PluginViewBody({
    super.key,
    required this.view,
    this.budget = PluginViewBudget.panel,
    this.onAction,
    this.imageResolver,
    this.showTitle = true,
    this.animate = false,
  });

  final DshUiView view;
  final PluginViewBudget budget;
  final PluginActionHandler? onAction;
  final PluginImageResolver? imageResolver;
  final bool showTitle;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Widget content;
    if (budget == PluginViewBudget.strip) {
      content = DshUiStripLine(view: view);
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showTitle && view.title != null) ...[
            Semantics(
              header: true,
              child: Text(
                view.title!,
                style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurface),
              ),
            ),
            const SizedBox(height: 12),
          ],
          DshUiNodeView(node: view.root),
        ],
      );
    }
    return DshUiPluginScope(
      onAction: onAction,
      imageResolver: imageResolver ?? PluginImages.maybeOf(context)?.resolver,
      animate: animate,
      child: DshUiPictureViewer(
        open: openGalleryPictures,
        child: view.version == 2
            ? DshUiPluginStyles(view: view, compact: budget == PluginViewBudget.strip, child: content)
            : content,
      ),
    );
  }
}

/// Broken root node: a single line "Plugin UI error".
class PluginViewError extends StatelessWidget {
  const PluginViewError({super.key});

  static const height = 32.0;

  @override
  Widget build(BuildContext context) {
    final dsh = DshColors.of(context);
    return SizedBox(
      height: height,
      child: Row(
        children: [
          Icon(AppIcons.info, size: 16, color: dsh.textTertiary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.plugViewInvalid,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: dsh.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}

/// The signed frame: a glass card (radius 20, padding 16) with a top row of plugin icon + plugin name
/// (secondary color); [trailing] sits at that row's end. Every plugin UI is wrapped in it, so nothing can impersonate system
/// UI (`native-plugins-views.md` §7, `native-plugins.md` §3.7).
///
/// [icon] is a ui.json icon name; by default it draws the plugin name's first letter. With [surface] false,
/// only the signature row and the content paint (use it when already inside a card or sheet).
class PluginFrame extends StatelessWidget {
  const PluginFrame({
    super.key,
    required this.pluginName,
    this.icon,
    this.trailing,
    this.surface = true,
    required this.child,
  });

  final String pluginName;
  final String? icon;
  final Widget? trailing;
  final bool surface;
  final Widget child;

  /// The signature row's height (= the icon's cell).
  static const headerHeight = 24.0;
  static const markSize = 20.0;

  @override
  Widget build(BuildContext context) {
    final dsh = DshColors.of(context);
    final header = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: headerHeight),
      child: Row(
        children: [
          PluginMark(name: pluginName, icon: icon),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              pluginName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: dsh.textTertiary),
            ),
          ),
          if (trailing case final t?) ...[const SizedBox(width: 8), t],
        ],
      ),
    );
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        header,
        const SizedBox(height: 12),
        DshUiSourceName(name: pluginName, child: child),
      ],
    );
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: context.l10n.plugViewFrom(pluginName),
      child: surface
          ? GlassSurface(
              tier: GlassTier.card,
              borderRadius: AppShape.radiusLg,
              padding: const EdgeInsets.all(DshUiMetrics.cardPadding),
              child: content,
            )
          : content,
    );
  }
}

/// The plugin's small mark (20 × 20): known icon names ([nativeIcon]: ui.json names plus
/// coin, speaker, etc.) draw the icon, otherwise the name's first letter.
class PluginMark extends StatelessWidget {
  const PluginMark({super.key, required this.name, this.icon});

  final String name;
  final String? icon;

  @override
  Widget build(BuildContext context) {
    final dsh = DshColors.of(context);
    final glyph = nativeIcon(icon);
    const size = PluginFrame.markSize;
    if (glyph != null) {
      return SizedBox.square(
        dimension: size,
        child: Icon(glyph, size: 16, color: dsh.textTertiary),
      );
    }
    final initial = name.trim().isEmpty ? '·' : name.trim().characters.first.toUpperCase();
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: ShapeDecoration(color: context.dshUiWell, shape: Squircle.border(6)),
          child: Center(
            child: Text(
              initial,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The tool card (`native-plugins-views.md` §8): the tool row's expansion area. Renderable, it is a card on the same
/// system as the model cards (read-only); arguments and results ([fallback]) tuck under "Details" below the card, folded by default;
/// unrenderable, it reads "Plugin UI error" with [fallback] directly below.
///
/// With [details] false, only the card paints (the one left exposed after a turn folds).
class PluginToolCard extends StatelessWidget {
  const PluginToolCard({super.key, required this.parse, required this.fallback, this.details = true});

  final DshUiParse parse;
  final Widget fallback;
  final bool details;

  @override
  Widget build(BuildContext context) {
    return switch (parse) {
      DshUiParsed(:final view) when !details => _ToolCardSurface(view: view),
      DshUiParsed(:final view) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _ToolCardSurface(view: view),
          const SizedBox(height: 4),
          _ToolCardDetails(child: fallback),
        ],
      ),
      DshUiInvalid() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [const PluginViewError(), const SizedBox(height: 4), fallback],
      ),
    };
  }
}

class _ToolCardSurface extends StatelessWidget {
  const _ToolCardSurface({required this.view});

  final DshUiView view;

  @override
  Widget build(BuildContext context) => GlassSurface(
    tier: GlassTier.card,
    borderRadius: AppShape.radiusLg,
    padding: const EdgeInsets.all(DshUiMetrics.cardPadding),
    child: PluginViewBody(view: view, budget: PluginViewBudget.toolCard),
  );
}

/// "Details" under the card: one row; tapping opens arguments and result.
class _ToolCardDetails extends StatefulWidget {
  const _ToolCardDetails({required this.child});

  final Widget child;

  @override
  State<_ToolCardDetails> createState() => _ToolCardDetailsState();
}

class _ToolCardDetailsState extends State<_ToolCardDetails> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    void toggle() => setState(() => _open = !_open);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          expanded: _open,
          child: StreamRowFrame(
            onTap: toggle,
            child: Row(
              children: [
                Text(context.l10n.commonDetails, style: StreamRow.detail(context)),
                const SizedBox(width: 4),
                StreamChevron(open: _open),
              ],
            ),
          ),
        ),
        ExpandReveal(
          open: _open,
          child: Padding(padding: const EdgeInsets.only(top: 4), child: widget.child),
        ),
      ],
    );
  }
}
