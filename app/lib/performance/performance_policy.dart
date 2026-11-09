/// A default profile, not a benchmark score. Android owns the classification.
enum DeviceTier { low, medium, high }

enum PerformanceMode { auto, full, light }

class PerformanceSnapshot {
  const PerformanceSnapshot({
    this.sequence = -1,
    this.device = const {},
    this.thermal = const {},
    this.loaded = false,
    this.available = false,
  });

  factory PerformanceSnapshot.fromMap(Map<Object?, Object?> raw) {
    Map<String, Object?> section(Object? value) => value is Map
        ? {
            for (final entry in value.entries)
              if (entry.key is String) entry.key as String: entry.value,
          }
        : const {};
    return PerformanceSnapshot(
      sequence: (raw['sequence'] as num?)?.toInt() ?? 0,
      device: section(raw['device']),
      thermal: section(raw['thermal']),
      loaded: raw['device'] is Map,
      available: true,
    );
  }

  final int sequence;
  final Map<String, Object?> device;
  final Map<String, Object?> thermal;
  final bool loaded;
  final bool available;

  DeviceTier get tier => DeviceTier.values.asNameMap()[device['tier']] ?? DeviceTier.medium;
  bool get thermalLightweight => thermal['lightweight'] == true;

  Map<String, Object?> toMap() => {'available': available, 'loaded': loaded, 'device': device, 'thermal': thermal};
}

/// Screen refresh rate (Settings → Performance). Some systems pin third-party apps to 60 Hz by
/// default; once an app declares it manages its own refresh rate, the system shows the switch as an
/// "In-app setting" — so the user must really get a choice, including "System" to hand the decision back.
enum RefreshRateMode {
  /// Use the screen's fastest refresh rate for animation, scrolling and streaming output; hand back when still.
  auto,

  /// Always use the highest refresh rate.
  max,

  /// Declare no preference; the system's own refresh-rate setting decides entirely.
  system,
}

/// Null per-feature values mean "use the current profile". Defaults are never persisted.
class PerformancePrefs {
  const PerformancePrefs({
    this.mode = PerformanceMode.auto,
    this.blur,
    this.animations,
    this.fluid,
    this.refreshRate = RefreshRateMode.auto,
    this.loaded = false,
  });

  final PerformanceMode mode;
  final bool? blur;
  final bool? animations;

  /// Fluid motion (see `AppMotion.fluid`).
  final bool? fluid;
  final RefreshRateMode refreshRate;
  final bool loaded;

  PerformancePrefs copyWith({
    PerformanceMode? mode,
    bool? blur,
    bool? animations,
    bool? fluid,
    RefreshRateMode? refreshRate,
    bool? loaded,
    bool resetEffects = false,
  }) => PerformancePrefs(
    mode: mode ?? this.mode,
    blur: resetEffects ? null : blur ?? this.blur,
    animations: resetEffects ? null : animations ?? this.animations,
    fluid: resetEffects ? null : fluid ?? this.fluid,
    refreshRate: refreshRate ?? this.refreshRate,
    loaded: loaded ?? this.loaded,
  );
}

class PerformanceDefaults {
  const PerformanceDefaults({
    required this.lightweight,
    required this.blur,
    required this.reduceMotion,
    required this.fluidMotion,
    required this.petEnabled,
    required this.autoStartLocal,
    required this.recommendRemote,
  });

  factory PerformanceDefaults.resolve(PerformanceSnapshot snapshot, PerformancePrefs prefs) {
    final light =
        snapshot.thermalLightweight ||
        switch (prefs.mode) {
          PerformanceMode.auto => snapshot.tier == DeviceTier.low,
          PerformanceMode.full => false,
          PerformanceMode.light => true,
        };
    final reduceMotion = !(prefs.animations ?? !light);
    return PerformanceDefaults(
      lightweight: light,
      blur: prefs.blur ?? !light,
      reduceMotion: reduceMotion,
      fluidMotion: !reduceMotion && (prefs.fluid ?? !light),
      petEnabled: !light,
      autoStartLocal: !light,
      recommendRemote: light || snapshot.tier == DeviceTier.low,
    );
  }

  final bool lightweight;
  final bool blur;
  final bool reduceMotion;

  /// Fluid tier: motion isn't off, and the user chose it or the current tier defaults it on (off by default on low-end phones or when hot).
  final bool fluidMotion;
  final bool petEnabled;
  final bool autoStartLocal;
  final bool recommendRemote;

  /// Reserved for 7b. No tier opts into extra background residency by default.
  bool get keepEngineInBackground => false;

  Map<String, Object?> toMap() => {
    'lightweight': lightweight,
    'blur': blur,
    'reduceMotion': reduceMotion,
    'fluidMotion': fluidMotion,
    'petEnabledDefault': petEnabled,
    'autoStartLocalDefault': autoStartLocal,
    'recommendRemote': recommendRemote,
    'keepEngineInBackgroundDefault': keepEngineInBackground,
  };
}
