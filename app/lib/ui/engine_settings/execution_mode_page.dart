// "Execution mode": how this phone's engine launches — inside PRoot
// (non-root), Direct as root, or Shizuku (not paired yet: until it is, the
// engine runs through the Direct path). One choice list over
// `runtimeBridge.setDirectEngine`, keeping the gating of DirectEngineSettings
// (lib/ui/settings/direct_engine_settings.dart): a change only goes through
// while the engine is stopped and applies on the next start. The pick is
// mirrored in prefs (lib/state/agent_reconnect_state.dart) so the page can
// tell Shizuku from a plain Direct launch.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/l10n.dart';
import '../../runtime/runtime_bridge.dart';
import '../../runtime/runtime_state.dart';
import '../../state/agent_reconnect_state.dart';
import '../common/brief_notice.dart';
import '../features/feature_widgets.dart';
import '../settings/settings_widgets.dart';
import '../shell/page_frame.dart';
import '../theme/app_icons.dart';
import '../theme/theme.dart';

/// The three modes, in list order; the pref values are these names.
const executionModes = ['proot', 'direct', 'shizuku'];

String executionModeLabel(L10n l10n, String mode) => switch (mode) {
  'proot' => l10n.executionModeProot,
  'direct' => l10n.executionModeDirect,
  _ => l10n.executionModeShizuku,
};

/// What is current: the runtime answers for Direct and PRoot; Shizuku rides
/// on Direct, so it only reads back while Direct is on and the app was told
/// so. Until the native status arrives, the saved pick stands.
String currentExecutionMode({required RuntimeStatus status, required bool loaded, String? pref}) {
  if (!loaded) return pref ?? 'proot';
  if (!status.directEngineEnabled) return 'proot';
  return pref == 'shizuku' ? 'shizuku' : 'direct';
}

class ExecutionModeSettingsPage extends ConsumerStatefulWidget {
  const ExecutionModeSettingsPage({super.key});

  @override
  ConsumerState<ExecutionModeSettingsPage> createState() => _ExecutionModeSettingsPageState();
}

class _ExecutionModeSettingsPageState extends ConsumerState<ExecutionModeSettingsPage> {
  String? _pref;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPref());
  }

  Future<void> _loadPref() async {
    final raw = (await SharedPreferences.getInstance()).getString(executionModePrefKey);
    if (mounted) setState(() => _pref = raw);
  }

  Future<void> _choose(String mode) async {
    setState(() => _saving = true);
    try {
      await ref.read(runtimeBridgeProvider).setDirectEngine(mode != 'proot');
      // Only a change the runtime took is remembered.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(executionModePrefKey, mode);
      if (mounted) setState(() => _pref = mode);
    } catch (_) {
      if (mounted) showBriefNotice(context, context.l10n.executionModeChangeFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = DshColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    final runtime = ref.watch(localRuntimeProvider);
    final status = runtime.status;
    // The gating and the warning words of DirectEngineSettings: a change
    // only goes through once the engine is stopped, and only with a runtime
    // that has the Direct path.
    final stopped = !status.phase.isBusy && status.phase != RuntimePhase.running;
    final enabled =
        runtime.loaded && stopped && !_saving && (status.directEngineAvailable || status.directEngineEnabled);
    // Safe mode launches compatibly by design; after Direct failed to launch,
    // native reports the switch off until the user turns it on again (a new try).
    final fallback = status.directEngineFallbackReason;
    final directFailed = fallback == 'directFailed';
    final runtimeNeedsCompatible = fallback != null && fallback != 'safeRecovery' && !directFailed;
    final hint = !status.directEngineAvailable
        ? l10n.phoneDirectNeedsRuntime
        : directFailed && !status.directEngineEnabled
        ? l10n.phoneDirectFailedHint
        : runtimeNeedsCompatible
        ? l10n.phoneDirectCompatibleHint
        : !stopped
        ? l10n.phoneDirectStopFirst
        : status.inSafeMode
        ? l10n.phoneDirectSafeHint
        : l10n.phoneDirectHint;
    final current = currentExecutionMode(status: status, loaded: runtime.loaded, pref: _pref);

    return AppPage.list(
      title: l10n.executionModeTitle,
      subtitle: Text(l10n.executionModeNote),
      children: [
        SettingsSection(
          footer: FeatureNote(hint),
          children: [
            for (final mode in executionModes)
              Semantics(
                selected: mode == current,
                child: SettingsTile(
                  key: ValueKey('execution-mode-$mode'),
                  title: executionModeLabel(l10n, mode),
                  subtitle: mode == 'shizuku' ? l10n.executionModeShizukuNote : null,
                  onTap: enabled && mode != current ? () => unawaited(_choose(mode)) : null,
                  trailing: Icon(
                    mode == current ? AppIcons.radioOn : AppIcons.radioOff,
                    size: 22,
                    color: mode == current ? scheme.primary : colors.textTertiary,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
