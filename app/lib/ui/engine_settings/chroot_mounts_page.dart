// "Mounts": what the chroot shows the engine of the phone. Each mount can be
// turned off, mounted read-only, mounted read-write, or "ask each time" (the
// person decides before the engine starts). Custom mounts are added here.
//
// The list is written to prefs; the launcher reads the same JSON when it
// builds the mount script (see ChrootRuntime in the Kotlin runtime).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../state/chroot_mounts.dart';
import '../common/app_dialog.dart';
import '../common/brief_notice.dart';
import '../settings/settings_widgets.dart';
import '../shell/page_frame.dart';
import '../theme/app_icons.dart';

class ChrootMountsPage extends ConsumerWidget {
  const ChrootMountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final mounts = ref.watch(chrootMountsProvider);
    final controller = ref.read(chrootMountsProvider.notifier);
    return AppPage.list(
      title: l10n.chrootMountsTitle,
      children: [
        SettingsSection(
          footer: Text(l10n.chrootMountsHint),
          children: [
            for (final mount in mounts)
              SettingsTile(
                key: ValueKey('mount-${mount.id}'),
                icon: AppIcons.folder,
                title: mount.label,
                subtitle: '${mount.source} → ${mount.target} · ${_mode(l10n, mount.access)}',
                trailing: Switch(
                  value: mount.enabled,
                  onChanged: (v) => controller.setEnabled(mount.id, v),
                ),
                onTap: () => _edit(context, ref, mount),
              ),
          ],
        ),
        SettingsSection(
          children: [
            SettingsTile(
              key: const ValueKey('mount-add'),
              icon: AppIcons.newFolder,
              title: l10n.chrootMountsAdd,
              onTap: () => _add(context, ref),
            ),
          ],
        ),
      ],
    );
  }

  String _mode(L10n l10n, MountAccess access) => switch (access) {
    MountAccess.readOnly => l10n.chrootMountsReadOnly,
    MountAccess.readWrite => l10n.chrootMountsReadWrite,
    MountAccess.ask => l10n.chrootMountsAsk,
  };

  Future<void> _edit(BuildContext context, WidgetRef ref, ChrootMount mount) async {
    final l10n = context.l10n;
    final controller = ref.read(chrootMountsProvider.notifier);
    final choice = await showAppDialog<MountAccess>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(mount.label),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final mode in MountAccess.values)
              RadioListTile<MountAccess>(
                value: mode,
                groupValue: mount.access,
                title: Text(_mode(l10n, mode)),
                onChanged: (v) => Navigator.of(dialog).pop(v),
              ),
            if (!mount.builtin)
              TextButton(
                onPressed: () => Navigator.of(dialog).pop(),
                child: Text(l10n.chrootMountsRemove),
              ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    await controller.setAccess(mount.id, choice);
    if (!mount.builtin && choice == MountAccess.readOnly && context.mounted) {
      // Removing asks once more; the mode sheet is the way in.
    }
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final name = TextEditingController();
    final source = TextEditingController();
    final target = TextEditingController();
    final added = await showAppDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l10n.chrootMountsAdd),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: InputDecoration(labelText: l10n.chrootMountsName)),
            TextField(controller: source, decoration: InputDecoration(labelText: l10n.chrootMountsSource)),
            TextField(controller: target, decoration: InputDecoration(labelText: l10n.chrootMountsTarget)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog), child: Text(l10n.commonCancel)),
          FilledButton(onPressed: () => Navigator.pop(dialog, true), child: Text(l10n.commonSave)),
        ],
      ),
    );
    if (added != true) return;
    final label = name.text.trim();
    final from = source.text.trim();
    final to = target.text.trim();
    if (label.isEmpty || from.isEmpty || to.isEmpty) return;
    await ref.read(chrootMountsProvider.notifier).addCustom(label: label, source: from, target: to);
    if (context.mounted) showBriefNotice(context, l10n.chrootMountsSaved);
  }
}
