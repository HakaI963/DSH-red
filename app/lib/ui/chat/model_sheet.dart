// Portions derived from PiPilot (https://github.com/CikeSeven/pi_pilot), MIT, Copyright (c) 2026 CikeSeven. See THIRD_PARTY_NOTICES.md.
// Local changes: a glass bottom sheet fed by `session/modelCatalog`, with a
// channel filter, model cards and a capsule effort selector.

import 'dart:async';
import 'dart:math' as math;

import 'package:dsh_client/dsh_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../state/models_state.dart';
import '../../state/settings_state.dart';
import '../common/app_sheet.dart';
import '../common/empty_view.dart';
import '../common/pressable.dart';
import '../common/segmented_pill.dart';
import '../common/sheet_title_bar.dart';
import '../common/smooth_size.dart';
import '../common/read_list_status.dart';
import '../common/ui_trace.dart';
import '../onboarding/api_key_page.dart';
import '../providers/provider_form_page.dart';
import '../providers/providers_page.dart';
import '../theme/app_icons.dart';
import '../theme/theme.dart';

/// Short model name: drop the "DeepSeek-" prefix, hyphens become spaces, words capitalize.
/// `DeepSeek-V4-Pro` → `V4 Pro`.
String shortModelName(String raw) {
  final stripped = raw.replaceFirst(RegExp(r'^deepseek[-_ ]?', caseSensitive: false), '');
  final words = stripped
      .split(RegExp(r'[-_ ]+'))
      .where((w) => w.isNotEmpty)
      .map((w) => w.length == 1 ? w.toUpperCase() : w[0].toUpperCase() + w.substring(1))
      .join(' ');
  return words.isEmpty ? raw : words;
}

/// The model short name on the chip; "Select a model" when nothing is chosen.
String modelShortName(ModelSelection? selection, ModelCatalog? catalog) {
  if (selection == null) return appL10n.viewModelSelect;
  return shortModelName(findModel(catalog, selection)?.name ?? selection.model);
}

/// Human-friendly thinking-depth names. Protocol words (off/low/high/max) are not shown to people directly.
String effortLabel(String id, [String? fallback]) => switch (id) {
  'off' || 'none' => appL10n.viewModelThinkingOff,
  'minimal' => appL10n.viewModelThinkingMinimal,
  'low' => appL10n.viewModelThinkingLow,
  'medium' => appL10n.viewModelThinkingMedium,
  'high' => appL10n.viewModelThinkingHigh,
  'xhigh' => appL10n.viewModelThinkingXhigh,
  'max' => appL10n.viewModelThinkingMax,
  _ => fallback ?? id,
};

/// The model in a phone's open composer: a plain pill beside the +, the same weight as
/// it, saying what this message goes out with and a tap from changing it.
class ComposerModelPill extends ConsumerWidget {
  const ComposerModelPill({super.key, required this.selection, required this.onSelected});

  final ModelSelection? selection;
  final ValueChanged<ModelSelection> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final catalog = ref.watch(currentModelCatalogProvider);
    final effective = selection ?? catalog?.defaultSelection;
    final effort = effective?.reasoningEffort;
    final name = modelShortName(effective, catalog);
    void open() => showModelSheet(context, current: effective, onSelected: onSelected);
    return Semantics(
      button: true,
      label: [
        l10n.viewModelLabel(name),
        if (effort != null) l10n.viewModelEffortLabel(effortLabel(effort)),
      ].join(l10n.viewListSeparator),
      excludeSemantics: true,
      onTap: open,
      child: InkResponse(
        key: const ValueKey('composer-model'),
        onTap: open,
        highlightShape: BoxShape.rectangle,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: ShapeDecoration(color: colors.onSurface.withValues(alpha: 0.06), shape: const StadiumBorder()),
          // As wide as its words: the row's free space stays between it and the keys.
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Text(
              effort == null ? name : '$name ${effortLabel(effort)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                fontSize: 12.5,
                color: colors.onSurface,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The model chip at the header's right: "✦ V4 Pro · High ⌄". Widths glide and text crossfades on model change.
///
/// When space runs short it yields in order: first drop "· High" (screen readers still say it), then truncate the model name,
/// finally keep only ✦ and ⌄. The width offered is measured by the header ([ChatHeader]); the chip doesn't guess screen width: its
/// minimum intrinsic width is "full name without depth", its maximum is "name plus depth".
class ModelChip extends ConsumerWidget {
  const ModelChip({super.key, required this.selection, required this.onSelected, this.grouped = false});

  /// The currently effective choice; shows the catalogue default when null.
  final ModelSelection? selection;
  final ValueChanged<ModelSelection> onSelected;
  final bool grouped;

  // The chevron's glyph carries ~4 of its own air on the right: 12 + 0 on
  // the left reads the same as 8 + 4 on the right.
  static const _padStart = 12.0;
  static const _padEnd = 8.0;
  static const _chevron = 16.0;

  /// The narrowest the chip gets: the chevron, no words.
  static const compactWidth = _padStart + _chevron + _padEnd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final catalog = ref.watch(currentModelCatalogProvider);
    final effective = selection ?? catalog?.defaultSelection;
    final effort = effective?.reasoningEffort;
    final label = modelShortName(effective, catalog);
    final quick = AppMotion.of(context, AppMotion.quick);
    final em = MediaQuery.textScalerOf(context).scale(13);
    final style = theme.textTheme.labelMedium?.copyWith(fontSize: 13);
    void open() => showModelSheet(context, current: effective, onSelected: onSelected);
    return GlassSurface(
      tier: GlassTier.chrome,
      stadium: true,
      grouped: grouped,
      onTap: open,
      child: Semantics(
        label: [
          l10n.viewModelLabel(label),
          if (effort != null) l10n.viewModelEffortLabel(effortLabel(effort)),
        ].join(l10n.viewListSeparator),
        button: true,
        onTap: open,
        excludeSemantics: true,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(_padStart, 0, _padEnd, 0),
            child: SmoothSize(
              duration: AppMotion.of(context, AppMotion.standard),
              curve: AppMotion.std,
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: AnimatedSwitcher(
                      duration: quick,
                      layoutBuilder: (current, previous) =>
                          Stack(alignment: Alignment.centerLeft, children: [...previous, ?current]),
                      child: _ChipLabel(
                        key: ValueKey('$label\u0000$effort'),
                        gap: 5,
                        // About two letters and an ellipsis; a long name
                        // stops at ten characters' width.
                        minTextWidth: em * 2.5,
                        maxTextWidth: em * 10,
                        children: [
                          if (effort != null)
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(text: label),
                                  TextSpan(
                                    text: ' · ${effortLabel(effort)}',
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: style,
                            ),
                          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
                        ],
                      ),
                    ),
                  ),
                  Icon(AppIcons.expand, size: _chevron, color: theme.colorScheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The chip's words: the first of [children] that fits whole (the name with
/// its depth, then the name alone). The last one shortens with an ellipsis
/// when nothing fits, and the words go altogether, with the [gap] in front of
/// them, once less than [minTextWidth] would show. Never wider than
/// [maxTextWidth].
///
/// Its min intrinsic width is the last child whole, its max intrinsic width
/// the first: what the header weighs the title against.
class _ChipLabel extends MultiChildRenderObjectWidget {
  const _ChipLabel({
    super.key,
    required this.gap,
    required this.minTextWidth,
    required this.maxTextWidth,
    required super.children,
  });

  final double gap;
  final double minTextWidth;
  final double maxTextWidth;

  @override
  MultiChildRenderObjectElement createElement() => _ChipLabelElement(this);

  @override
  _RenderChipLabel createRenderObject(BuildContext context) => _RenderChipLabel(gap, minTextWidth, maxTextWidth);

  @override
  void updateRenderObject(BuildContext context, _RenderChipLabel renderObject) {
    renderObject
      ..gap = gap
      ..minTextWidth = minTextWidth
      ..maxTextWidth = maxTextWidth;
  }
}

/// Only the shown words are on stage (finders, like [IndexedStack]'s).
class _ChipLabelElement extends MultiChildRenderObjectElement {
  _ChipLabelElement(super.widget);

  @override
  void debugVisitOnstageChildren(ElementVisitor visitor) {
    final shown = (renderObject as _RenderChipLabel).shown;
    for (final child in children) {
      if (shown != null && identical(child.renderObject, shown)) visitor(child);
    }
  }
}

class _ChipLabelParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderChipLabel extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _ChipLabelParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _ChipLabelParentData> {
  _RenderChipLabel(this._gap, this._minTextWidth, this._maxTextWidth);

  /// Rounding between the header's arithmetic and the text's own width.
  static const _slack = 0.5;

  double _gap;
  set gap(double value) {
    if (value == _gap) return;
    _gap = value;
    markNeedsLayout();
  }

  double _minTextWidth;
  set minTextWidth(double value) {
    if (value == _minTextWidth) return;
    _minTextWidth = value;
    markNeedsLayout();
  }

  double _maxTextWidth;
  set maxTextWidth(double value) {
    if (value == _maxTextWidth) return;
    _maxTextWidth = value;
    markNeedsLayout();
  }

  /// The child on screen after the last layout; null when the words are gone.
  RenderBox? shown;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _ChipLabelParentData) {
      child.parentData = _ChipLabelParentData();
    }
  }

  double _whole(RenderBox child) => math.min(child.getMaxIntrinsicWidth(double.infinity), _maxTextWidth);

  /// Which child [maxWidth] shows, and how wide its text may run.
  (RenderBox, double)? _pick(double maxWidth) {
    final room = math.min(maxWidth - _gap, _maxTextWidth);
    if (room < _minTextWidth) return null;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      final whole = _whole(child);
      if (whole <= room + _slack) return (child, whole);
      if (child == lastChild) return (child, room);
    }
    return null;
  }

  @override
  double computeMinIntrinsicWidth(double height) => lastChild == null ? 0 : _gap + _whole(lastChild!);

  @override
  double computeMaxIntrinsicWidth(double height) => firstChild == null ? 0 : _gap + _whole(firstChild!);

  @override
  double computeMinIntrinsicHeight(double width) => lastChild?.getMinIntrinsicHeight(double.infinity) ?? 0;

  @override
  double computeMaxIntrinsicHeight(double width) => lastChild?.getMaxIntrinsicHeight(double.infinity) ?? 0;

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final pick = _pick(constraints.maxWidth);
    if (pick == null) return constraints.smallest;
    final (child, width) = pick;
    final text = child.getDryLayout(BoxConstraints(maxWidth: width));
    return constraints.constrain(Size(_gap + text.width, text.height));
  }

  @override
  void performLayout() {
    final pick = _pick(constraints.maxWidth);
    shown = pick?.$1;
    if (pick == null) {
      size = constraints.smallest;
      return;
    }
    final (child, width) = pick;
    child.layout(BoxConstraints(maxWidth: width), parentUsesSize: true);
    (child.parentData! as _ChipLabelParentData).offset = Offset(_gap, 0);
    size = constraints.constrain(Size(_gap + child.size.width, child.size.height));
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) => shown?.getDistanceToActualBaseline(baseline);

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = shown;
    if (child == null) return;
    final childOffset = (child.parentData! as _ChipLabelParentData).offset + offset;
    context.paintChild(child, childOffset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final child = shown;
    if (child == null) return false;
    final offset = (child.parentData! as _ChipLabelParentData).offset;
    return result.addWithPaintOffset(
      offset: offset,
      position: position,
      hitTest: (result, transformed) => child.hitTest(result, position: transformed),
    );
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (shown case final child?) visitor(child);
  }
}

/// The model sheet: tapping a model card applies it at once (depth carried over or defaulted); picking a thinking depth applies
/// at once too, and the sheet closes itself after the slider settles.
Future<void> showModelSheet(
  BuildContext context, {
  required ModelSelection? current,
  required ValueChanged<ModelSelection> onSelected,
  bool confirmSelection = false,
}) {
  return showAppSheet<void>(
    context,
    isScrollControlled: true,
    builder: (context) => _ModelSheet(current: current, onSelected: onSelected, confirmSelection: confirmSelection),
  );
}

/// ```
///                    ───
///   Select a model                               (×)
///
///   ((  DeepSeek  )   OpenRouter            )    when more than one channel
///
///   ╭─────────────────╮  ╭─────────────────╮
///   │ V4 Pro       (✓)│  │ V41 Flash    ( )│
///   │ Stronger reasoning & coding │  │ Faster, cheaper      │
///   ╰─────────────────╯  ╰─────────────────╯
///
///   Thinking depth
///   (( No thinking )  Low     ( High )     Max   )
/// ```
///
/// The channel strip only filters; it never changes the current choice. It opens on the channel of the current model.
class _ModelSheet extends ConsumerStatefulWidget {
  const _ModelSheet({required this.current, required this.onSelected, required this.confirmSelection});

  final ModelSelection? current;
  final ValueChanged<ModelSelection> onSelected;
  final bool confirmSelection;

  @override
  ConsumerState<_ModelSheet> createState() => _ModelSheetState();
}

class _ModelSheetState extends ConsumerState<_ModelSheet> {
  late ModelSelection? _selection = widget.current;
  late final Object _scope = ref.read(modelSelectionScopeProvider);

  bool get _active => identical(_scope, ref.read(modelSelectionScopeProvider));

  /// The channel being browsed; null follows the selected model's.
  String? _channel;

  /// Closes the sheet once the effort thumb has landed.
  Timer? _close;

  @override
  void dispose() {
    _close?.cancel();
    super.dispose();
  }

  void _pickModel(ModelInfo model) {
    final view = ref.read(modelListViewProvider);
    if (!_active || view.readOnly) return;
    final available = findModel(view.value, ModelSelection(provider: model.provider, model: model.id));
    if (available == null || !identical(available, model)) return;
    final keep = _selection?.reasoningEffort;
    final supported = model.efforts.any((e) => e.id == keep);
    final next = ModelSelection(
      provider: model.provider,
      model: model.id,
      reasoningEffort: supported ? keep : startingEffort(model),
    );
    setState(() {
      _selection = next;
      _channel = model.provider;
    });
    if (!widget.confirmSelection) widget.onSelected(next);
  }

  void _pickEffort(String effort) {
    final view = ref.read(modelListViewProvider);
    if (!_active || view.readOnly) return;
    final current = _selection;
    if (current == null) return;
    final available = findModel(view.value, current);
    if (available == null || !available.efforts.any((entry) => entry.id == effort)) return;
    final next = ModelSelection(provider: current.provider, model: current.model, reasoningEffort: effort);
    setState(() => _selection = next);
    if (widget.confirmSelection) return;
    widget.onSelected(next);
    _close?.cancel();
    final settle = AppMotion.reduced(context) ? Duration.zero : AppMotion.standard + const Duration(milliseconds: 120);
    _close = Timer(settle, () {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final catalogAsync = ref.watch(modelCatalogProvider);
    final view = ref.watch(modelListViewProvider);
    final catalog = view.value;
    final active = identical(_scope, ref.watch(modelSelectionScopeProvider));

    final Widget body;
    var picking = false;
    if (catalog == null) {
      body = catalogAsync.isLoading
          ? const _Loading()
          : catalogAsync.hasError
          ? EmptyView(
              padding: _emptyPadding,
              icon: AppIcons.offline,
              title: l10n.viewModelLoadFailed,
              action: FilledButton.tonal(
                onPressed: () => ref.invalidate(modelCatalogProvider),
                child: Text(l10n.commonRetry),
              ),
            )
          : EmptyView(
              padding: _emptyPadding,
              icon: AppIcons.disconnected,
              title: l10n.viewModelDisconnected,
              message: l10n.viewModelConnectHint,
            );
    } else {
      final groups = [
        for (final group in catalog.groups)
          if (group.models.isNotEmpty) group,
      ];
      if (groups.isEmpty) {
        body = _EmptyCatalog(
          // A failing provider counts: something is set up, just not working.
          configured: ref.watch(settingsProvider.select((s) => s.hasModelAccess)) || catalog.failures.isNotEmpty,
          failure: catalog.failures.isEmpty ? null : catalog.failures.first.message,
        );
      } else {
        picking = true;
        body = _picker(groups, findModel(catalog, _selection), readOnly: view.readOnly || !active);
      }
    }

    final sheet = SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            SheetTitleBar(catalog == null ? l10n.viewModelSelect : readListHeading(l10n.viewModelSelect, view.status)),
            body,
            if (picking && widget.confirmSelection && !isValidModelSelection(catalog, _selection))
              Padding(
                padding: const EdgeInsets.fromLTRB(SheetTitleBar.inset, 16, SheetTitleBar.inset, 0),
                child: Text(l10n.engineNewChatDefaultsSelectionUnavailable),
              ),
            if (picking && widget.confirmSelection)
              Padding(
                padding: const EdgeInsets.fromLTRB(SheetTitleBar.inset, 20, SheetTitleBar.inset, 0),
                child: FilledButton(
                  onPressed: !active || view.readOnly || !isValidModelSelection(catalog, _selection)
                      ? null
                      : () {
                          final currentView = ref.read(modelListViewProvider);
                          if (!_active ||
                              currentView.readOnly ||
                              !isValidModelSelection(currentView.value, _selection)) {
                            return;
                          }
                          widget.onSelected(_selection!);
                          Navigator.of(context).pop();
                        },
                  child: Text(l10n.commonSave),
                ),
              ),
            // "Manage models ›": Settings › Models, over the sheet (back returns here).
            if (picking) ...[const SizedBox(height: 12), const ManageModelsLink()],
          ],
        ),
      ),
    );
    return UiTrace(scope: 'models', child: sheet);
  }

  Widget _picker(List<ProviderGroup> groups, ModelInfo? selected, {required bool readOnly}) {
    final shownId = _channel ?? selected?.provider;
    final shown = groups.firstWhere((g) => g.id == shownId, orElse: () => groups.first);
    final efforts = selected?.efforts ?? const <ReasoningEffort>[];
    final quick = AppMotion.of(context, AppMotion.quick);
    const inset = SheetTitleBar.inset;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (groups.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 16),
            child: _ChannelBar(groups: groups, shown: shown.id, onChanged: (id) => setState(() => _channel = id)),
          )
        else
          SheetSectionLabel(shown.name),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: inset),
          child: SmoothSize(
            duration: AppMotion.of(context, AppMotion.standard),
            curve: AppMotion.std,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: quick,
              switchInCurve: AppMotion.enter,
              switchOutCurve: AppMotion.exit,
              layoutBuilder: (current, previous) =>
                  Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
              child: _ModelGrid(
                key: ValueKey(shown.id),
                models: shown.models,
                selected: selected,
                onPick: readOnly ? null : _pickModel,
              ),
            ),
          ),
        ),
        // Fades out first, then the height folds away (and the reverse on the
        // way in), so nothing below jumps.
        SmoothSize(
          duration: AppMotion.of(context, AppMotion.collapse),
          curve: AppMotion.collapseCurve,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: quick,
            layoutBuilder: (current, previous) =>
                Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
            child: efforts.length < 2
                ? const SizedBox(key: ValueKey('none'), width: double.infinity)
                : Column(
                    key: const ValueKey('effort'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 16),
                      SheetSectionLabel(appL10n.viewModelEffort),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: inset),
                        child: SegmentedPill<String>(
                          height: 40,
                          segments: [for (final e in efforts) PillSegment(e.id, effortLabel(e.id, e.name))],
                          selected: _selection?.reasoningEffort ?? selected?.defaultEffort ?? efforts.first.id,
                          onChanged: readOnly
                              ? null
                              : (effort) {
                                  if (identical(
                                    findModel(ref.read(modelListViewProvider).value, _selection),
                                    selected,
                                  )) {
                                    _pickEffort(effort);
                                  }
                                },
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

/// The "Manage models ›" at the bottom of the picker: a centred text key going to Settings › Models.
class ManageModelsLink extends StatelessWidget {
  const ManageModelsLink({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: TextButton(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ProvidersPage())),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.nearbyManageModels),
            const SizedBox(width: 2),
            const Icon(AppIcons.disclosure, size: 14),
          ],
        ),
      ),
    );
  }
}

/// Channel filter: one full-width [SegmentedPill] when it fits; when channels overflow the width, a row
/// of side-scrolling pills (ends flush with the content, sliding out to the sheet's edge while scrolling).
class _ChannelBar extends StatelessWidget {
  const _ChannelBar({required this.groups, required this.shown, required this.onChanged});

  final List<ProviderGroup> groups;
  final String shown;
  final ValueChanged<String> onChanged;

  static const height = 40.0;

  @override
  Widget build(BuildContext context) {
    const inset = SheetTitleBar.inset;
    return LayoutBuilder(
      builder: (context, constraints) {
        final room = constraints.maxWidth - 2 * inset;
        final natural = SegmentedPill.naturalWidth(context, [for (final g in groups) g.name]);
        if (natural <= room) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: inset),
            child: SegmentedPill<String>(
              height: height,
              segments: [for (final g in groups) PillSegment(g.id, g.name)],
              selected: shown,
              onChanged: onChanged,
            ),
          );
        }
        final style = SegmentedPill.labelStyle(context);
        final rowHeight = MediaQuery.textScalerOf(context).scale(height);
        return SizedBox(
          height: rowHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: inset),
            itemCount: groups.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) => _ChannelChip(
              label: groups[i].name,
              selected: groups[i].id == shown,
              style: style,
              onTap: () => onChanged(groups[i].id),
            ),
          ),
        );
      },
    );
  }
}

/// One channel pill: the selected one shares [SegmentedPill]'s slider material (white in light, bright grey in
/// dark, with a touch of shadow); unselected ones take the trough color.
class _ChannelChip extends StatelessWidget {
  const _ChannelChip({required this.label, required this.selected, required this.style, required this.onTap});

  final String label;
  final bool selected;
  final TextStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final track = dark ? Colors.white.withValues(alpha: 0.07) : colors.onSurface.withValues(alpha: 0.06);
    final thumb = dark ? Colors.white.withValues(alpha: 0.2) : Colors.white;
    final quick = AppMotion.of(context, AppMotion.quick);
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: quick,
          curve: AppMotion.std,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            color: selected ? thumb : track,
            shape: const StadiumBorder(),
            shadows: selected && !dark
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 1))]
                : null,
          ),
          child: AnimatedDefaultTextStyle(
            duration: quick,
            style: style.copyWith(
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? colors.onSurface : colors.onSurfaceVariant,
            ),
            child: Text(label, maxLines: 1, softWrap: false),
          ),
        ),
      ),
    );
  }
}

/// Two equal-width model columns; same height per row, 12 apart; odd count, the last card spans the full row.
class _ModelGrid extends StatelessWidget {
  const _ModelGrid({super.key, required this.models, required this.selected, required this.onPick});

  final List<ModelInfo> models;
  final ModelInfo? selected;
  final ValueChanged<ModelInfo>? onPick;

  static const gap = 12.0;

  @override
  Widget build(BuildContext context) {
    Widget card(ModelInfo model) => _ModelCard(
      key: ValueKey('${model.provider}\u0000${model.id}'),
      model: model,
      selected: selected?.id == model.id && selected?.provider == model.provider,
      onTap: onPick == null ? null : () => onPick!(model),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < models.length; i += 2) ...[
          if (i > 0) const SizedBox(height: gap),
          if (i + 1 < models.length)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: card(models[i])),
                  const SizedBox(width: gap),
                  Expanded(child: card(models[i + 1])),
                ],
              ),
            )
          else
            card(models[i]),
        ],
      ],
    );
  }
}

/// One model card: short name (up to two lines) + a one-line description, with a selection circle top right. Selected, the card takes a sheer
/// tint of the main color, a hairline ring of it, and a solid check in the circle — the only solid main color on this screen.
class _ModelCard extends StatelessWidget {
  const _ModelCard({super.key, required this.model, required this.selected, required this.onTap});

  final ModelInfo model;
  final bool selected;
  final VoidCallback? onTap;

  static const radius = BorderRadius.all(Radius.circular(AppShape.lg));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dsh = DshColors.of(context);
    final dark = theme.brightness == Brightness.dark;
    final description = model.description?.trim();
    final name = shortModelName(model.name);
    final duration = AppMotion.of(context, AppMotion.quick);
    return Semantics(
      button: true,
      enabled: onTap != null,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: description == null || description.isEmpty ? name : context.l10n.viewDescribedValue(name, description),
      onTap: onTap,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: GlassSurface(
          tier: GlassTier.card,
          borderRadius: radius,
          child: AnimatedContainer(
            duration: duration,
            curve: AppMotion.std,
            padding: const EdgeInsets.all(16),
            decoration: ShapeDecoration(
              color: selected
                  ? colors.primary.withValues(alpha: dark ? 0.14 : 0.07)
                  : colors.primary.withValues(alpha: 0),
              shape: RoundedSuperellipseBorder(
                borderRadius: radius,
                side: BorderSide(
                  color: selected
                      ? colors.primary.withValues(alpha: dark ? 0.7 : 0.55)
                      : colors.primary.withValues(alpha: 0),
                  width: 1.5,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    // 14 / two lines: the row leaves the name ~109 dp on a
                    // 390 dp phone, so "GPT 5.6 Terra" at titleMedium's 16 was
                    // cut after the first words.
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(height: 1.35),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _CheckMark(selected: selected),
                  ],
                ),
                if (description != null && description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: dsh.textTertiary),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The 20 selection circle: a hairline ring when unselected; solid main color + white check when selected (a scaled fade-in).
class _CheckMark extends StatelessWidget {
  const _CheckMark({required this.selected});

  final bool selected;

  static const size = 20.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final ring = theme.brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.22)
        : colors.onSurface.withValues(alpha: 0.18);
    return SizedBox.square(
      dimension: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: ShapeDecoration(
              shape: CircleBorder(side: BorderSide(color: ring, width: 1.5)),
            ),
          ),
          AnimatedScale(
            scale: selected ? 1 : 0.5,
            duration: AppMotion.of(context, AppMotion.quick),
            curve: AppMotion.std,
            child: AnimatedOpacity(
              opacity: selected ? 1 : 0,
              duration: AppMotion.of(context, AppMotion.quick),
              child: DecoratedBox(
                decoration: ShapeDecoration(color: colors.primary, shape: const CircleBorder()),
                child: Icon(AppIcons.selected, size: 14, color: colors.onPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Room around an empty / failed catalog inside the sheet.
const _emptyPadding = EdgeInsets.fromLTRB(32, 16, 32, 8);

/// The catalogue is still coming: a quiet little spinner about as tall as a row of model cards, so nothing jumps when it arrives.
class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 120,
    child: Center(
      child: SizedBox.square(
        dimension: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          strokeCap: StrokeCap.round,
          color: DshColors.of(context).textTertiary,
        ),
      ),
    ),
  );
}

/// The catalogue is empty: DSH 0.2.1 lists no models without a usable credential. With nothing configured, guide the user to fill in a
/// DeepSeek key or add another channel; if configured yet still empty, the key most likely hasn't synced to the engine or
/// is invalid — go look under "Model channels".
class _EmptyCatalog extends StatelessWidget {
  const _EmptyCatalog({required this.configured, this.failure});

  /// A DeepSeek key or a custom provider exists.
  final bool configured;
  final String? failure;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final failure = this.failure?.trim();
    void push(Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
    if (!configured) {
      return EmptyView(
        padding: _emptyPadding,
        icon: AppIcons.apiKey,
        title: l10n.viewModelKeyRequired,
        message: l10n.viewModelProvidersHint,
        action: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton(
              onPressed: () => push(const ApiKeyPage(onboarding: false)),
              child: Text(l10n.viewModelEnterKey),
            ),
            const SizedBox(height: 4),
            TextButton(onPressed: () => push(const ProviderFormPage()), child: Text(l10n.viewModelAddProvider)),
          ],
        ),
      );
    }
    return EmptyView(
      padding: _emptyPadding,
      icon: AppIcons.noApiKey,
      title: l10n.viewModelNone,
      message: failure != null && failure.isNotEmpty ? failure : l10n.viewModelKeyHint,
      action: FilledButton(onPressed: () => push(const ProvidersPage()), child: Text(l10n.viewModelManageProviders)),
    );
  }
}
