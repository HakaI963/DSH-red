// First run, step 2 of 3 on this phone: Choose appearance, while the runtime unpacks
// (docs/design/onboarding-parallel-setup.md).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../performance/performance_state.dart';
import '../settings/appearance/appearance_page.dart' show PalettePicker, ThemeModePicker;
import '../settings/settings_widgets.dart';
import '../theme/app_icons.dart';
import 'onboarding_scaffold.dart';

/// Light or dark and one of the six palettes, the same pickers as Settings › Theme;
/// on a low-end phone, also whether to stay in Lite mode (on by default there).
///
/// ```
///   ▣  Choose appearance
///      You can change this anytime in Settings
///   ╭──────────────────────────────────╮
///   │  [Light]    [Dark]    [System]          │
///   │   ●   ●   ●   ●   ●   ●          │
///   ╰──────────────────────────────────╯
///   ╭──────────────────────────────────╮   low-end phones only
///   │  Lite mode                     (●)  │
///   ╰──────────────────────────────────╯
///   (               Continue               )
/// ```
///
/// Every choice applies at once, so the page is its own preview, and
/// "Continue" with nothing touched keeps the defaults: no separate "Skip".
class AppearanceStepPage extends ConsumerWidget {
  const AppearanceStepPage({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // What the phone is, not how warm it is now: a hot phone eases off by
    // itself and comes back, there is nothing for the person to confirm.
    final lowEnd = ref.watch(performanceProvider.select((s) => s.available && s.loaded && s.tier == DeviceTier.low));
    final mode = ref.watch(performancePrefsProvider.select((p) => p.mode));
    return OnboardingScaffold(
      children: [
        const Spacer(),
        OnboardingHeader(
          icon: AppIcons.theme,
          title: l10n.setupAppearanceTitle,
          message: l10n.setupAppearanceMessage,
        ),
        const SizedBox(height: 28),
        SettingsSection(
          key: const ValueKey('setup-appearance-card'),
          margin: EdgeInsets.zero,
          children: [
            const ThemeModePicker(),
            // The page's column measures intrinsic heights; the palette's
            // own layout can't answer, so it gets its height here.
            SizedBox(height: PalettePicker.heightFor(context), child: const PalettePicker(custom: false)),
          ],
        ),
        if (lowEnd) ...[
          const SizedBox(height: 12),
          SettingsSection(
            margin: EdgeInsets.zero,
            children: [
              SettingsSwitchTile(
                key: const ValueKey('setup-light-mode'),
                title: l10n.setupLightMode,
                subtitle: l10n.performanceLightHint,
                // Auto on a low-end phone is light.
                value: mode != PerformanceMode.full,
                onChanged: (on) => unawaited(
                  ref.read(performancePrefsProvider.notifier).setMode(on ? PerformanceMode.light : PerformanceMode.full),
                ),
              ),
            ],
          ),
        ],
        const Spacer(flex: 2),
        const SizedBox(height: 24),
        FilledButton(onPressed: onDone, child: Text(l10n.commonContinue)),
      ],
    );
  }
}
