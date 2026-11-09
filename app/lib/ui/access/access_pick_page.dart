// First run, "What should DSH Go do for you?": what DSH Go should do, by feature
// (docs: lib/state/access_state.dart). Nothing is picked to begin with; Skip
// leaves everything as it is.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../state/access_state.dart';
import '../../state/phone_state.dart';
import '../common/risk_notice.dart';
import '../onboarding/onboarding_scaffold.dart';
import '../phone/phone_disclosure_sheet.dart';
import '../settings/settings_widgets.dart';
import '../theme/app_icons.dart';
import '../theme/theme.dart';
import 'access_widgets.dart';
import 'phone_mode_sheet.dart';

/// ```
///   ▣  What should DSH Go do for you?
///      Enable the picked ones
///   ╭──────────────────────────────────╮
///   │ ▢ Read & write phone files    ☐  │
///   │   needs file access permission    │
///   │ ▢ Desk pet & overlay window  ☐  │
///   │ ▢ Phone control               ☐  │
///   │ ▢ Keep running in background ☐  │
///   │ ▢ Voice input                 ☐  │
///   │   needs microphone permission     │
///   │   offline STT, ~241 MB model      │
///   ╰──────────────────────────────────╯
///   (          Enable selected         )
///                 Skip
/// ```
///
/// Picking Phone control shows its disclosure and then asks how it confirms
/// (ask at key steps / fully automatic), and read/write-phone-files what AI may then do, right
/// there, the way their switches in settings do; declining either leaves the
/// box empty.
class AccessPickPage extends ConsumerStatefulWidget {
  const AccessPickPage({super.key, required this.onPicked, required this.onSkip});

  /// The features, and Phone control's confirmation mode when it is among them.
  final void Function(Set<AccessFeature> features, PhoneConfirmMode? phoneMode) onPicked;
  final VoidCallback onSkip;

  @override
  ConsumerState<AccessPickPage> createState() => _AccessPickPageState();
}

class _AccessPickPageState extends ConsumerState<AccessPickPage> {
  final _picked = <AccessFeature>{};
  bool _asking = false;

  /// Phone control's confirmation mode, chosen right after its disclosure.
  PhoneConfirmMode? _phoneMode;

  Future<void> _toggle(AccessFeature feature) async {
    if (_asking) return;
    if (_picked.contains(feature)) {
      if (feature == AccessFeature.phone) _phoneMode = null;
      return setState(() => _picked.remove(feature));
    }
    _asking = true;
    try {
      final bool ok;
      if (feature == AccessFeature.phone) {
        ok = await _phoneDisclosure() && await _chooseMode();
      } else if (feature == AccessFeature.files) {
        ok = await confirmRisk(context, RiskNotices.phoneFilesFirstRun);
      } else {
        ok = true;
      }
      if (ok && mounted) setState(() => _picked.add(feature));
    } finally {
      _asking = false;
    }
  }

  Future<bool> _phoneDisclosure() async {
    if (ref.read(phoneProvider).disclosureAccepted) return true;
    if (!await showPhoneDisclosure(context)) return false;
    await ref.read(phoneProvider.notifier).acceptDisclosure();
    return true;
  }

  /// Ask at key steps / fully automatic, every time Phone control is picked: closed without
  /// one, the box stays empty.
  Future<bool> _chooseMode() async {
    if (!mounted) return false;
    final mode = await showPhoneModeSheet(context);
    if (mode == null) return false;
    _phoneMode = mode;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = DshColors.of(context);
    final metered = ref.watch(accessReadingsProvider.select((r) => r.value?.metered == true));
    return OnboardingScaffold(
      children: [
        const Spacer(),
        OnboardingHeader(icon: AppIcons.systemAccess, title: l10n.accessPickTitle, message: l10n.accessPickMessage),
        const SizedBox(height: 28),
        SettingsSection(
          key: const ValueKey('access-pick-card'),
          margin: EdgeInsets.zero,
          children: [
            for (final feature in AccessFeature.values)
              AccessFeatureRow(
                feature: feature,
                selected: _picked.contains(feature),
                onTap: () => unawaited(_toggle(feature)),
                lines: feature == AccessFeature.voice
                    ? [
                        (text: l10n.accessFeatureVoiceNeeds, color: null),
                        (text: l10n.accessVoiceModel(voiceModelApproxMb), color: null),
                        if (metered) (text: l10n.accessVoiceMetered, color: colors.warning),
                      ]
                    : const [],
              ),
          ],
        ),
        const Spacer(flex: 2),
        const SizedBox(height: 24),
        AccessActions(
          primary: l10n.accessPickConfirm,
          onPrimary: _picked.isEmpty
              ? null
              : () => widget.onPicked({..._picked}, _picked.contains(AccessFeature.phone) ? _phoneMode : null),
          secondary: [(l10n.accessSkip, widget.onSkip)],
        ),
      ],
    );
  }
}
