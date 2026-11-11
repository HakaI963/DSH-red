// The mounts the chroot sets up before the engine starts: the phone's own
// userspace (storage, data, system) and whatever the person adds. Each mount
// can be off, read-only, read-write, or "ask each time" (mounted read-only
// until the person allows it for a start).
//
// The list lives in prefs; the Kotlin side reads the same JSON when it builds
// the mount script, so the app and the launcher always agree.

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How a mount is mounted.
enum MountAccess {
  readOnly,
  readWrite,
  ask;

  static MountAccess parse(String? raw) =>
      MountAccess.values.firstWhere((m) => m.name == raw, orElse: () => MountAccess.readOnly);
}

/// One mount: a host path bound into the chroot.
@immutable
class ChrootMount {
  const ChrootMount({
    required this.id,
    required this.label,
    required this.source,
    required this.target,
    this.enabled = true,
    this.access = MountAccess.readOnly,
    this.builtin = false,
  });

  final String id;

  /// What the person sees (a built-in name or the custom one they typed).
  final String label;

  /// The path on the phone.
  final String source;

  /// The path inside the chroot.
  final String target;

  final bool enabled;
  final MountAccess access;

  /// Built-ins cannot be removed, only turned off.
  final bool builtin;

  ChrootMount copyWith({String? label, bool? enabled, MountAccess? access}) => ChrootMount(
    id: id,
    label: label ?? this.label,
    source: source,
    target: target,
    enabled: enabled ?? this.enabled,
    access: access ?? this.access,
    builtin: builtin,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'source': source,
    'target': target,
    'enabled': enabled,
    'access': access.name,
    'builtin': builtin,
  };

  static ChrootMount fromJson(Map<String, Object?> json) => ChrootMount(
    id: json['id'] as String? ?? 'custom',
    label: json['label'] as String? ?? '',
    source: json['source'] as String? ?? '',
    target: json['target'] as String? ?? '',
    enabled: json['enabled'] as bool? ?? true,
    access: MountAccess.parse(json['access'] as String?),
    builtin: json['builtin'] as bool? ?? false,
  );
}

/// Prefs key (the Kotlin side reads the same file under `flutter.`).
const chrootMountsPrefKey = 'chroot_mounts';

/// The mounts the chroot starts with.
List<ChrootMount> defaultChrootMounts() => const [
  // The phone's storage is mounted when the person grants access to it
  // (Settings › Capabilities › Phone files), not by default.
  ChrootMount(
    id: 'sdcard',
    label: 'Phone storage',
    source: '/sdcard',
    target: '/sdcard',
    enabled: false,
  ),
  ChrootMount(
    id: 'storage',
    label: 'Shared storage',
    source: '/storage',
    target: '/storage',
    enabled: false,
  ),
  ChrootMount(id: 'data', label: 'App and system data', source: '/data', target: '/data', access: MountAccess.readWrite),
  ChrootMount(id: 'system', label: 'Android system', source: '/system', target: '/system'),
  ChrootMount(id: 'apex', label: 'Android apex', source: '/apex', target: '/apex'),
  ChrootMount(id: 'mntuser', label: 'User storage (old Android)', source: '/mnt/user', target: '/mnt/user'),
  ChrootMount(id: 'proc', label: 'Processes', source: 'proc', target: '/proc'),
  ChrootMount(id: 'sys', label: 'Kernel state', source: 'sysfs', target: '/sys'),
  ChrootMount(id: 'dev', label: 'Devices', source: '/dev', target: '/dev'),
  ChrootMount(id: 'tmp', label: 'Temporary files', source: 'tmpfs', target: '/tmp', access: MountAccess.readWrite),
  ChrootMount(id: 'shm', label: 'Shared memory', source: 'tmpfs', target: '/dev/shm', access: MountAccess.readWrite),
];

/// The person's mounts.
class ChrootMountsController extends Notifier<List<ChrootMount>> {
  @override
  List<ChrootMount> build() {
    final prefs = ref.watch(chrootMountsPrefsProvider);
    return prefs.value ?? defaultChrootMounts();
  }

  Future<void> _save(List<ChrootMount> mounts) async {
    state = mounts;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      chrootMountsPrefKey,
      jsonEncode([for (final m in mounts) m.toJson()]),
    );
  }

  Future<void> setEnabled(String id, bool enabled) async {
    final next = [for (final m in state) m.id == id ? m.copyWith(enabled: enabled) : m];
    await _save(next);
  }

  Future<void> setAccess(String id, MountAccess access) async {
    final next = [for (final m in state) m.id == id ? m.copyWith(access: access) : m];
    await _save(next);
  }

  Future<void> addCustom({required String label, required String source, required String target}) async {
    final id = 'custom-${DateTime.now().microsecondsSinceEpoch}';
    await _save([...state, ChrootMount(id: id, label: label, source: source, target: target)]);
  }

  /// The phone's storage follows the person's grant.
  Future<void> setStorageEnabled(bool enabled) async {
    final next = [
      for (final m in state)
        if (m.id == 'sdcard' || m.id == 'storage') m.copyWith(enabled: enabled) else m,
    ];
    await _save(next);
  }

  Future<void> remove(String id) async {
    await _save([for (final m in state) if (m.id != id) m]);
  }
}

/// The stored mounts, loaded once.
final chrootMountsPrefsProvider = FutureProvider<List<ChrootMount>>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(chrootMountsPrefKey);
  if (raw == null || raw.isEmpty) return defaultChrootMounts();
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return defaultChrootMounts();
    return [for (final item in decoded) ChrootMount.fromJson((item as Map).cast<String, Object?>())];
  } catch (_) {
    return defaultChrootMounts();
  }
});

final chrootMountsProvider = NotifierProvider<ChrootMountsController, List<ChrootMount>>(
  ChrootMountsController.new,
);
