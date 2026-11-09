import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/l10n.dart';
import '../ui/theme/accent.dart';

/// Where the color scheme comes from.
enum AccentSource {
  /// One of the six presets ([AppearanceSettings.presetId]).
  preset,

  /// The color the user picked ([AppearanceSettings.customColor]), through the contrast guard.
  custom,

  /// The system's wallpaper accent (Android 12+).
  wallpaper,
}

/// The color-scheme part of Appearance settings. The appearance mode (light / dark / follow system) is still
/// `themeMode` in `settings_state.dart`; only its UI moved to the Appearance page.
class AppearanceSettings {
  const AppearanceSettings({
    this.source = AccentSource.preset,
    this.presetId = 'mist',
    this.customColor = defaultCustom,
    this.loaded = false,
  });

  final AccentSource source;

  /// The preset chosen last; used when switching back from custom / wallpaper.
  final String presetId;

  /// The custom color (ARGB), raw, before the guard.
  final int customColor;
  final bool loaded;

  /// The custom color's initial value: a grey-toned moss green (hue 140°) that clashes with none
  /// of the six presets on first open.
  static const defaultCustom = 0xFF5F7A55;

  AppearanceSettings copyWith({AccentSource? source, String? presetId, int? customColor, bool? loaded}) =>
      AppearanceSettings(
        source: source ?? this.source,
        presetId: presetId ?? this.presetId,
        customColor: customColor ?? this.customColor,
        loaded: loaded ?? this.loaded,
      );
}

class AppearanceController extends Notifier<AppearanceSettings> {
  static const _sourceKey = 'appearance.accent_source';
  static const _presetKey = 'appearance.preset';
  static const _customKey = 'appearance.custom_color';

  /// The current scheme's light-mode primary (ARGB), read by native notifications as the accent
  /// (`ThemeAccent` in `DynamicColorPlugin.kt`).
  static const notifyColorKey = 'appearance.notify_color';

  late Future<void> _loaded;

  @override
  AppearanceSettings build() {
    _loaded = _load();
    return const AppearanceSettings();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final source = AccentSource.values.asNameMap()[prefs.getString(_sourceKey)] ?? AccentSource.preset;
      state = AppearanceSettings(
        source: source,
        presetId: AppAccent.preset(prefs.getString(_presetKey)).id,
        customColor: prefs.getInt(_customKey) ?? AppearanceSettings.defaultCustom,
        loaded: true,
      );
    } catch (_) {
      // No preferences backend (tests): the default palette.
      state = state.copyWith(loaded: true);
    }
  }

  /// Writes wait for the read: a value changed right after launch is not overwritten by a late load.
  Future<void> _save(AppearanceSettings next, Future<void> Function(SharedPreferences prefs) write) async {
    await _loaded;
    state = next.copyWith(loaded: true);
    try {
      await write(await SharedPreferences.getInstance());
    } catch (_) {
      // Kept for this run only.
    }
  }

  Future<void> selectPreset(String id) => _save(state.copyWith(source: AccentSource.preset, presetId: id), (p) async {
    await p.setString(_sourceKey, AccentSource.preset.name);
    await p.setString(_presetKey, id);
  });

  /// Selects custom; with [color] given, also changes it (hue bar, suggested colors).
  Future<void> selectCustom([int? color]) =>
      _save(state.copyWith(source: AccentSource.custom, customColor: color), (p) async {
        await p.setString(_sourceKey, AccentSource.custom.name);
        if (color != null) await p.setInt(_customKey, color);
      });

  Future<void> selectWallpaper() => _save(
    state.copyWith(source: AccentSource.wallpaper),
    (p) => p.setString(_sourceKey, AccentSource.wallpaper.name),
  );

  /// Turns off wallpaper following: back to the last preset.
  Future<void> leaveWallpaper() => selectPreset(state.presetId);
}

final appearanceProvider = NotifierProvider<AppearanceController, AppearanceSettings>(AppearanceController.new);

/// The system's wallpaper accents (Android 12+ `system_accent1_*`). Null on older versions or
/// when unreadable; the Appearance page then hides the "Use wallpaper colors" row entirely.
class DynamicColorChannel {
  const DynamicColorChannel([this._methods = const MethodChannel('dsh/dynamic_color')]);

  final MethodChannel _methods;

  /// The wallpaper accent (accent1's middle tone); null when unsupported.
  Future<Color?> wallpaperAccent() async {
    try {
      final palette = await _methods.invokeMapMethod<String, Object?>('palette');
      final value = palette?['accent'] ?? palette?['accentLight'];
      return value is int ? Color(value) : null;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}

final dynamicColorChannelProvider = Provider<DynamicColorChannel>((ref) => const DynamicColorChannel());

/// The wallpaper accent; re-read when the app returns to the foreground (the user may have just changed the wallpaper).
final wallpaperAccentProvider = FutureProvider<Color?>((ref) {
  final listener = AppLifecycleListener(onResume: ref.invalidateSelf);
  ref.onDispose(listener.dispose);
  return ref.watch(dynamicColorChannelProvider).wallpaperAccent();
});

/// The scheme in effect. Until the wallpaper accent is read (or if it can't be), the last preset stands in.
final accentProvider = Provider<AppAccent>((ref) {
  final s = ref.watch(appearanceProvider);
  final preset = AppAccent.preset(s.presetId);
  final accent = switch (s.source) {
    AccentSource.preset => preset,
    AccentSource.custom => AppAccent.derive(Color(s.customColor)),
    AccentSource.wallpaper => switch (ref.watch(wallpaperAccentProvider).value) {
      final c? => AppAccent.derive(c, id: AppAccent.wallpaperId, label: appL10n.stateWallpaper),
      null => preset,
    },
  };
  if (s.loaded) unawaited(_publishNotifyColor(accent));
  return accent;
});

int? _published;

/// Native notifications read this to tint the small icon; written only when it changes.
Future<void> _publishNotifyColor(AppAccent accent) async {
  final argb = accent.seed.toARGB32();
  if (_published == argb) return;
  _published = argb;
  try {
    await (await SharedPreferences.getInstance()).setInt(AppearanceController.notifyColorKey, argb);
  } catch (_) {
    // Tests: no backend.
  }
}
