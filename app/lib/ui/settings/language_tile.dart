import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../state/locale_state.dart';
import '../theme/app_icons.dart';
import 'settings_widgets.dart';

/// Settings → Appearance: Language (System / English). Language names are
/// written in their own language, the way system pickers show them.
class LanguageSettingsTile extends ConsumerWidget {
  const LanguageSettingsTile({super.key, this.tint = 0});

  final int tint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final language = ref.watch(appLanguageProvider);
    return SettingsSegmentTile<AppLanguage>(
      key: const ValueKey('settings-language'),
      icon: AppIcons.translate,
      tint: tint,
      spot: Spots.language,
      segments: [
        PillSegment(AppLanguage.system, l10n.localeSystem),
        PillSegment(AppLanguage.en, l10n.localeEn),
      ],
      selected: language,
      onChanged: (v) => unawaited(ref.read(appLanguageProvider.notifier).set(v)),
    );
  }
}
