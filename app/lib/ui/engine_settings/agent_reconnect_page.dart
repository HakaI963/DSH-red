// "Agent reconnect", after the engine's `retryPolicy`: whether a failed model
// call is retried. Off is the engine's own default — it stops at the first
// failure; on writes one policy into every served `llm-*` namespace that
// carries the field, and the choice is mirrored in prefs (the pure layer in
// lib/state/agent_reconnect_state.dart) so the page reopens with the last
// numbers even where the host does not serve the field.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/l10n.dart';
import '../../state/agent_reconnect_state.dart';
import '../../state/engine_settings_state.dart';
import '../common/brief_notice.dart';
import '../features/feature_widgets.dart';
import '../theme/app_icons.dart';
import 'field_row.dart';
import 'field_sheets.dart' show showNumberSheet;
import 'schema_fields.dart';
import 'schema_form.dart';

/// The page's draft: the switch and the three numbers.
typedef ReconnectDraft = ({bool enabled, int retries, int firstSeconds, int maxSeconds});

const _defaults = (enabled: false, retries: 3, firstSeconds: 2, maxSeconds: 30);

/// One stepper's bounds and default, as the sheets show them.
typedef ReconnectLimit = ({int min, int max, int def});

/// The page's draft with one part replaced.
extension on ReconnectDraft {
  ReconnectDraft edited({bool? enabled, int? retries, int? firstSeconds, int? maxSeconds}) => (
    enabled: enabled ?? this.enabled,
    retries: retries ?? this.retries,
    firstSeconds: firstSeconds ?? this.firstSeconds,
    maxSeconds: maxSeconds ?? this.maxSeconds,
  );
}

const _limits = (
  retries: (min: 1, max: 10, def: 3),
  firstSeconds: (min: 1, max: 300, def: 2),
  maxSeconds: (min: 5, max: 600, def: 30),
);

/// Served `llm-*` namespaces with a top-level `retryPolicy` field, in order.
List<String> llmRetryNamespaces(EngineSettings settings) => [
  for (final ns in settings.namespaces.keys.toList()..sort())
    if (ns.startsWith('llm') && settings.nodeOf(FieldRef(ns, const ['retryPolicy'])) != null) ns,
];

/// The first live `retryPolicy` value among them; null when none has one.
Object? liveRetryPolicy(EngineSettings settings) {
  for (final ns in llmRetryNamespaces(settings)) {
    final value = settings.valueOf(FieldRef(ns, const ['retryPolicy']));
    if (value != null) return value;
  }
  return null;
}

class AgentReconnectSettingsPage extends ConsumerStatefulWidget {
  const AgentReconnectSettingsPage({super.key});

  @override
  ConsumerState<AgentReconnectSettingsPage> createState() => _AgentReconnectSettingsPageState();
}

class _AgentReconnectSettingsPageState extends ConsumerState<AgentReconnectSettingsPage> {
  /// What the prefs said at open (the engine's live policy wins over it).
  ReconnectDraft _draft = _defaults;

  bool _edited = false;
  bool _saving = false;

  /// Namespaces the last save could not write, in words.
  Map<String, String> _failed = const {};

  /// The engine first, the saved mirror beneath it.
  ReconnectDraft _draftFor(EngineSettings settings) =>
      _edited ? _draft : agentReconnectFromPolicy(liveRetryPolicy(settings)) ?? _draft;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPrefs());
  }

  Future<void> _loadPrefs() async {
    final raw = (await SharedPreferences.getInstance()).getString(agentReconnectPrefKey);
    final saved = agentReconnectFromPref(raw);
    if (mounted && !_edited && saved != null) setState(() => _draft = saved);
  }

  void _edit(ReconnectDraft next) => setState(() {
    _edited = true;
    _draft = next;
  });

  Future<void> _save(EngineSettings settings) async {
    final controller = ref.read(engineSettingsProvider.notifier);
    final draft = _draftFor(settings);
    final value = agentReconnectPolicy(
      enabled: draft.enabled,
      retries: draft.retries,
      firstSeconds: draft.firstSeconds,
      maxSeconds: draft.maxSeconds,
    );
    setState(() {
      _saving = true;
      _failed = const {};
    });
    final failed = <String, String>{};
    for (final ns in llmRetryNamespaces(settings)) {
      final field = FieldRef(ns, const ['retryPolicy']);
      controller.clearError(field);
      final ok = await controller.set(field, value);
      final after = ref.read(engineSettingsProvider).value;
      final error = after?.errorOf(field);
      if (error != null) {
        failed[ns] = error;
      } else if (!ok && !jsonEquals(after?.valueOf(field), value)) {
        // Refused without a word: a locked namespace or a read-only profile.
        failed[ns] = appL10n.engineFieldLocked;
      }
    }
    // The choice is the person's own: remembered even where the engine refused.
    await saveAgentReconnectPref(draft);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _failed = failed;
      _draft = draft;
    });
    if (failed.isEmpty) showBriefNotice(context, context.l10n.engineReconnectSaved);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = ref.watch(engineSettingsProvider).value;
    return EngineFormScaffold(
      title: l10n.engineReconnectTitle,
      subtitle: l10n.engineReconnectNote,
      namespaces: settings == null ? const [] : llmRetryNamespaces(settings),
      missingTitle: l10n.engineReconnectNoProvider,
      actions: (context, settings) => [
        TextButton(
          key: const ValueKey('agent-reconnect-save'),
          onPressed: _saving ? null : () => unawaited(_save(settings)),
          child: Text(l10n.commonSave),
        ),
      ],
      builder: (context, settings) {
        final draft = _draftFor(settings);
        final canWrite = !_saving && llmRetryNamespaces(settings).any(settings.canWrite);
        return [
          if (_failed.isNotEmpty)
            FeatureMessage(
              icon: AppIcons.error,
              title: l10n.commonSaveFailed,
              body: [
                for (final MapEntry(:key, :value) in _failed.entries) l10n.engineReconnectFailed('$key: $value'),
              ].join('\n'),
            ),
          ...schemaFormGroups([
            SchemaFormSection(
              children: [
                MergeSemantics(
                  child: EngineFieldRow(
                    key: const ValueKey('agent-reconnect-enabled'),
                    title: l10n.engineReconnectEnabled,
                    enabled: canWrite,
                    onTap: canWrite ? () => _edit(draft.edited(enabled: !draft.enabled)) : null,
                    trailing: Switch(
                      value: draft.enabled,
                      onChanged: canWrite ? (v) => _edit(draft.edited(enabled: v)) : null,
                    ),
                  ),
                ),
              ],
            ),
            if (draft.enabled)
              SchemaFormSection(
                children: [
                  _stepper(
                    name: 'retries',
                    title: l10n.engineReconnectRetries,
                    shown: l10n.engineReconnectRetriesValue(draft.retries),
                    value: draft.retries,
                    limit: _limits.retries,
                    unit: FieldUnit.plain,
                    canWrite: canWrite,
                    onPick: (v) => _edit(draft.edited(retries: v)),
                  ),
                  _stepper(
                    name: 'firstDelay',
                    title: l10n.engineReconnectFirstDelay,
                    shown: formatFieldNumber(draft.firstSeconds, FieldUnit.seconds, const FieldCopy()),
                    value: draft.firstSeconds,
                    limit: _limits.firstSeconds,
                    unit: FieldUnit.seconds,
                    canWrite: canWrite,
                    onPick: (v) => _edit(draft.edited(firstSeconds: v)),
                  ),
                  _stepper(
                    name: 'maxDelay',
                    title: l10n.engineReconnectMaxDelay,
                    shown: formatFieldNumber(draft.maxSeconds, FieldUnit.seconds, const FieldCopy()),
                    value: draft.maxSeconds,
                    limit: _limits.maxSeconds,
                    unit: FieldUnit.seconds,
                    canWrite: canWrite,
                    onPick: (v) => _edit(draft.edited(maxSeconds: v)),
                  ),
                ],
              ),
          ], settings: settings),
        ];
      },
    );
  }

  /// One number row: it shows the draft and edits it through the engine's
  /// own stepper sheet; nothing goes to the engine until 保存.
  Widget _stepper({
    required String name,
    required String title,
    required String shown,
    required int value,
    required ReconnectLimit limit,
    required FieldUnit unit,
    required bool canWrite,
    required void Function(int) onPick,
  }) => EngineFieldRow(
    key: ValueKey('agent-reconnect-$name'),
    title: title,
    value: shown,
    enabled: canWrite,
    onTap: canWrite
        ? () => unawaited(
            showNumberSheet(
              context,
              title: title,
              meta: SchemaMeta(min: limit.min, max: limit.max, step: 1, hasDefault: true, defaultValue: limit.def),
              unit: unit,
              current: value,
              inherited: limit.def,
              modified: value != limit.def,
              onSubmit: (v) {
                onPick(v.round());
                return Future.value(true);
              },
              onReset: () {
                onPick(limit.def);
                return Future.value(true);
              },
            ),
          )
        : null,
  );
}
