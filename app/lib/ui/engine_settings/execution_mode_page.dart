// "Execution mode": how the engine process runs on this phone.
//
// DSH red runs the engine in a real chroot on the phone's filesystem
// (/data/local/DSH-red/chroot): the bundled Ubuntu userland, the phone's own
// userspace bind mounted into it, and `chroot` starting it as root. No PRoot,
// no ptrace — and it needs a rooted phone (Magisk).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../features/feature_widgets.dart';
import '../settings/settings_widgets.dart';
import '../shell/page_frame.dart';
import '../theme/app_icons.dart';

/// The mode, in list order; the pref value is this name.
const executionModes = ['chroot'];

String executionModeLabel(L10n l10n, String mode) => switch (mode) {
  'chroot' => l10n.executionModeChroot,
  _ => l10n.executionModeChroot,
};

class ExecutionModeSettingsPage extends ConsumerWidget {
  const ExecutionModeSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return AppPage.list(
      title: l10n.executionModeTitle,
      children: [
        SettingsSection(
          children: [
            SettingsTile(
              key: const ValueKey('execution-mode-chroot'),
              icon: AppIcons.command,
              title: executionModeLabel(l10n, 'chroot'),
              subtitle: l10n.executionModeChrootNote,
            ),
          ],
        ),
        FeatureNote(l10n.executionModeShizukuNote),
      ],
    );
  }
}
