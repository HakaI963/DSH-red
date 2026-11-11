// "Execution mode": how the engine process runs on this phone.
//
// DSH red runs the engine in a real chroot on the phone's filesystem
// (/data/local/DSH-red/chroot): the bundled Ubuntu userland, the phone's own
// userspace bind mounted into it, and `chroot` starting it as root. No PRoot,
// no ptrace — and it needs a rooted phone (Magisk).
//
// Shizuku is the planned second way in (a shell through the Shizuku service,
// no root); it is offered and remembered here, but until that lands the engine
// still runs in the chroot.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/l10n.dart';
import '../../state/agent_reconnect_state.dart';
import '../features/feature_widgets.dart';
import '../settings/settings_widgets.dart';
import '../shell/page_frame.dart';
import '../theme/app_icons.dart';

/// The modes, in list order; the pref value is this name.
const executionModes = ['chroot', 'shizuku'];

String executionModeLabel(L10n l10n, String mode) => switch (mode) {
  'shizuku' => l10n.executionModeShizuku,
  _ => l10n.executionModeChroot,
};

class ExecutionModeSettingsPage extends ConsumerWidget {
  const ExecutionModeSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final mode = ref.watch(executionModePrefProvider).value ?? 'chroot';
    return AppPage.list(
      title: l10n.executionModeTitle,
      children: [
        SettingsSection(
          children: [
            for (final candidate in executionModes)
              SettingsTile(
                key: ValueKey('execution-mode-$candidate'),
                icon: candidate == 'chroot' ? AppIcons.command : AppIcons.terminal,
                title: executionModeLabel(l10n, candidate),
                subtitle: candidate == 'shizuku' ? l10n.executionModeShizukuNote : l10n.executionModeChrootNote,
                trailing: Icon(
                  mode == candidate ? AppIcons.radioOn : AppIcons.radioOff,
                  size: 22,
                  color: mode == candidate
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                onTap: () => _choose(context, candidate),
              ),
          ],
        ),
        FeatureNote(l10n.executionModeShizukuNote),
      ],
    );
  }

  Future<void> _choose(BuildContext context, String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(executionModePrefKey, mode);
  }
}
