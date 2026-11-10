// The person's reconnect choice, mirrored in prefs so the engine's own
// instructions (AGENTS.md, written by Kotlin) can state it, and so the page
// can open with the last saved numbers when the host doesn't carry them.
//
// The live values live in the engine: the `retryPolicy` field of every `llm-*`
// namespace that serves one (see AgentReconnectPage).

import 'package:shared_preferences/shared_preferences.dart';

/// `off`, or `<retries>:<first seconds>:<max seconds>`.
const agentReconnectPrefKey = 'agent_reconnect';

/// `proot`, `direct` or `shizuku`.
const executionModePrefKey = 'execution_mode';

/// The engine's default retryable classes (the `retryPolicy` schema's own
/// default; kept in sync with the pinned runtime).
const agentReconnectRetryableCodes = ['EMPTY_RESPONSE', 'RATE_LIMIT', 'SERVER', 'TIMEOUT', 'TRANSPORT'];

/// `retryPolicy` for one `llm-*` namespace; null means "stop on the first
/// failure" (the engine's union accepts null).
Map<String, Object?>? agentReconnectPolicy({
  required bool enabled,
  required int retries,
  required int firstSeconds,
  required int maxSeconds,
}) {
  if (!enabled) return null;
  return {
    'mode': 'normal',
    'maxRetries': retries.clamp(1, 10),
    'retryableCodes': agentReconnectRetryableCodes,
    'backoff': {
      'initialDelayMs': firstSeconds.clamp(1, 300) * 1000,
      'maxDelayMs': maxSeconds.clamp(5, 600) * 1000,
      'jitterRatio': 0.1,
    },
  };
}

/// The saved mirror: (enabled, retries, first, max); null when unset.
({bool enabled, int retries, int firstSeconds, int maxSeconds})? agentReconnectFromPref(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  if (raw == 'off') return (enabled: false, retries: 3, firstSeconds: 2, maxSeconds: 30);
  final parts = raw.split(':').map(int.tryParse).toList();
  if (parts.length != 3 || parts.any((p) => p == null)) return null;
  return (enabled: true, retries: parts[0]!, firstSeconds: parts[1]!, maxSeconds: parts[2]!);
}

String agentReconnectToPref({required bool enabled, required int retries, required int firstSeconds, required int maxSeconds}) =>
    enabled ? '$retries:$firstSeconds:$maxSeconds' : 'off';

/// The engine's live `retryPolicy` value read back into the page's numbers.
({bool enabled, int retries, int firstSeconds, int maxSeconds})? agentReconnectFromPolicy(Object? policy) {
  if (policy is! Map || policy['mode'] != 'normal') return null;
  final backoff = policy['backoff'];
  if (backoff is! Map) return null;
  final retries = policy['maxRetries'];
  final initial = backoff['initialDelayMs'];
  final max = backoff['maxDelayMs'];
  if (retries is! num || initial is! num || max is! num) return null;
  return (
    enabled: true,
    retries: retries.round().clamp(1, 10),
    firstSeconds: (initial / 1000).round().clamp(1, 300),
    maxSeconds: (max / 1000).round().clamp(5, 600),
  );
}

Future<void> saveAgentReconnectPref(
  ({bool enabled, int retries, int firstSeconds, int maxSeconds}) v,
) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    agentReconnectPrefKey,
    agentReconnectToPref(
      enabled: v.enabled,
      retries: v.retries,
      firstSeconds: v.firstSeconds,
      maxSeconds: v.maxSeconds,
    ),
  );
}
