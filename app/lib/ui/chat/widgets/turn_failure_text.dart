import '../../../l10n/l10n.dart';

/// Codes DSH (0.2.1-rc.4+) answers before sending anything when the model
/// itself can't be served: the official model listing says it needs a newer
/// DSH (`CLIENT_UPGRADE_REQUIRED`), or this DSH doesn't know it
/// (`MODEL_UNSUPPORTED`), or the chosen reasoning effort is unsupported.
/// Sending unchanged can't help; choose a supported effort/model or upgrade.
const modelRefusalCodes = {'CLIENT_UPGRADE_REQUIRED', 'MODEL_UNSUPPORTED', 'UNSUPPORTED_REASONING_EFFORT'};

/// The short line on a failed turn's notice, keyed by error code; the backend's own text goes under the expandable details.
String turnFailureText(String? code) => switch (code) {
  'AUTH' || 'INVALID_CREDENTIAL' => appL10n.chatErrApiKey,
  'QUOTA' => appL10n.chatErrBalance,
  'ACCOUNT_QUOTA' => appL10n.chatErrAccountQuota,
  'RATE_LIMIT' => appL10n.chatErrRateLimit,
  'CONTEXT_WINDOW_EXCEEDED' => appL10n.chatErrContextLength,
  'SERVER' => appL10n.chatErrModelUnavailable,
  final value? when RegExp(r'^HTTP_5\d\d$').hasMatch(value) => appL10n.chatErrModelUnavailable,
  'TIMEOUT' => appL10n.chatErrModelTimeout,
  'TRANSPORT' => appL10n.chatErrModelConnection,
  'EMPTY_RESPONSE' => appL10n.chatErrModelEmpty,
  // The engine is on the phone (updated with the app) or on the remote host.
  'CLIENT_UPGRADE_REQUIRED' => appL10n.chatErrEngineOutdated,
  'MODEL_UNSUPPORTED' => appL10n.chatErrModelUnsupported,
  'UNSUPPORTED_REASONING_EFFORT' => appL10n.chatErrReasoningEffortUnsupported,
  _ => appL10n.chatErrTurn,
};
