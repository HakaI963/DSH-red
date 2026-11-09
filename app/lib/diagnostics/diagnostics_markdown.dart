// The diagnostics snapshot as one compact Markdown file. The app writes it
// inside the engine's rootfs (`$DSH_HOME/dsh-app/diagnostics.md`) so the
// agent there can read it by itself when the person reports a problem.

import 'dart:convert';

import '../state/app_info.dart';
import 'diagnostics_bundle.dart';
import 'redact.dart';

/// Most lines kept from each log tail (the model reads this file, not a zip).
const diagnosticsEngineLines = 80;
const diagnosticsFailureLines = 60;
const diagnosticsErrorLines = 10;
const diagnosticsSystemImeEvents = 12;

/// Hard cap: a diagnostics file that costs more context than this is no
/// longer worth reading. The zip export stays available for everything else.
const diagnosticsMarkdownBytes = 16 * 1024;

/// Renders [s]. Pure: tests build a snapshot and compare, secrets go through
/// [redactDiagnostics] on the way out. The UTF-8 budget includes the notice.
String diagnosticsMarkdown(DiagnosticsSnapshot s, {int maxBytes = diagnosticsMarkdownBytes}) {
  final b = StringBuffer()
    ..writeln('# DSH Go Local Diagnostics')
    ..writeln()
    ..writeln('> Environment snapshot the app writes inside the engine, for troubleshooting; secrets redacted. Generated at: ${_time(s.at)}.')
    ..writeln();
  _systemIme(b, s);
  _environment(b, s);
  _connection(b, s);
  _phone(b, s);
  _performance(b, s);
  _errors(b, s);
  _log(b, 'Engine log (tail)', s.engineLog, diagnosticsEngineLines);
  _log(b, 'Log around the failure (tail)', s.failureLog, diagnosticsFailureLines);
  final text = redactDiagnostics(b.toString());
  final bytes = utf8.encode(text);
  if (bytes.length <= maxBytes) return text;
  const notice = '\n…(diagnostics file too long, truncated; use the export bundle in Settings → Diagnostics for the full content)\n';
  final noticeBytes = utf8.encode(notice);
  final contentBudget = maxBytes - noticeBytes.length;
  if (contentBudget < 0) return _utf8Prefix(noticeBytes, maxBytes);
  return '${_utf8Prefix(bytes, contentBudget)}$notice';
}

String _utf8Prefix(List<int> bytes, int budget) {
  var end = budget;
  // Both callers pass a budget below the encoded length. Back up to the
  // start of a scalar when the cut would keep only some of its bytes.
  while (end > 0 && (bytes[end] & 0xc0) == 0x80) {
    end--;
  }
  return utf8.decode(bytes.sublist(0, end));
}

void _systemIme(StringBuffer b, DiagnosticsSnapshot s) {
  final evidence = s.systemIme;
  if (evidence == null) return;
  final at = DateTime.fromMillisecondsSinceEpoch(evidence.capturedAt, isUtc: true);
  b
    ..writeln('## System IME evidence (manual, privilegedIme)')
    ..writeln('- capturedAt: ${at.toIso8601String()} · code: ${evidence.code} · events: ${evidence.events.length}')
    ..writeln('- Fixed events only; preceding 120 seconds, maximum 64. Retained capture, not live monitoring.')
    ..writeln('- Requests do not prove keyboard visibility. fromUser=null means unknown, not false.');
  if (evidence.events.isEmpty) {
    b.writeln('- No usable events: empty/failed capture is NOT evidence that the system behaved normally.');
  } else {
    final recent = evidence.events.reversed.take(diagnosticsSystemImeEvents).toList().reversed;
    b.writeln('- Most recent ${recent.length} events (ZIP contains the full bounded capture):');
    for (final event in recent) {
      b.writeln('  - ${event.timestamp} ${event.event} fromUser=${event.fromUser} reason=${event.reason} origin=${event.origin}');
    }
  }
  b.writeln();
}

void _environment(StringBuffer b, DiagnosticsSnapshot s) {
  final st = s.status;
  final app = s.native.app;
  final device = s.native.device;
  final manifest = s.native.manifest;
  b
    ..writeln('## Environment')
    ..writeln('- App: ${_join([AppInfo.version, app['versionName'], app['versionCode']?.toString()])}')
    ..writeln('- Device: ${_join([device['manufacturer'], device['brand'], device['model'], _android(device)], mono: true)}')
    ..writeln('- Device resources: ${_join([_mb(device['memoryMb'], 'RAM'), _mb(device['freeStorageMb'], 'free storage')])}')
    ..writeln('- ABI: ${st.abi ?? '—'}');
  final display = device['display'];
  if (display is Map) {
    final d = {for (final e in display.entries) '${e.key}': e.value};
    b.writeln(
      '- Display: ${_join([if (d['widthPx'] != null && d['heightPx'] != null) '${d['widthPx']}×${d['heightPx']}', if (d['densityDpi'] != null) '${d['densityDpi']}dpi', if (d['density'] != null) '${d['density']}×', if (d['fontScale'] != null) 'font scale ${d['fontScale']}'])}',
    );
  }
  if (manifest.isNotEmpty) {
    b.writeln(
      '- Bundled runtime: ${_join([manifest['runtimeVersion'], manifest['dshVersion'], manifest['nodeVersion']], mono: true)}',
    );
  }
  b
    ..writeln(
      '- Runtime state: ${st.phase.name} · mode ${st.mode.name}'
      '${st.safeState.name != 'off' ? ' · safe mode ${st.safeState.name}${st.safeReason == null ? '' : ' (${st.safeReason})'}' : ''}'
      '${st.strikes > 0 ? ' · consecutive failures ${st.strikes}' : ''}',
    )
    ..writeln(
      '- Versions: bundled ${_short(st.bundledVersion)} · installed ${_short(st.installedVersion)} · DSH ${st.dshVersion ?? '—'} · Node ${st.nodeVersion ?? '—'}',
    )
    ..writeln(
      '- Launch mode: ${st.currentExecutionMode ?? st.launchSelectedMode ?? (st.directEngineEnabled ? 'direct (not observed)' : 'proot')}'
      '${st.launchFailureReason == null ? '' : ' · last failure ${st.launchFailureReason}'}'
      '${st.directEngineFallbackReason == null ? '' : ' · fallback ${st.directEngineFallbackReason}'}',
    )
    ..writeln('- Engine URL: ${st.baseUrl ?? '—'} (token not reported)');
  if (st.error case final error? when error.isNotEmpty) b.writeln('- Last error: $error');
  if (st.networkBlocked) b.writeln('- Network blocked by system since ${_time(st.networkBlockedAt ?? s.at)}');
  b
    ..writeln()
    ..writeln('## Settings')
    ..writeln(
      '- API Key: ${s.settings.hasApiKey ? 'set' : 'not set'} · custom providers ${s.settings.customProviderIds.length}'
      ' · theme ${s.settings.themeMode.name} · chat text scale ${s.settings.chatTextScale}',
    )
    ..writeln(
      '- auto-start local engine ${s.settings.autoStartLocal} · auto-approve commands ${s.settings.autoApproveCommands}'
      ' · phone storage ${s.settings.phoneStorage} · fold completed turns ${s.settings.foldCompletedTurns}'
      ' · visual replies ${s.settings.visualReplies}',
    )
    ..writeln();
}

void _connection(StringBuffer b, DiagnosticsSnapshot s) {
  b.writeln('## Connection');
  final entries = s.connection.entries
      .where((e) => e.key != 'history' && e.value != null && '${e.value}'.isNotEmpty)
      .toList();
  if (entries.isEmpty) {
    b.writeln('- No observed connections');
  } else {
    for (final e in entries) {
      b.writeln('- ${e.key}: ${e.value}');
    }
  }
  final history = s.connection['history'];
  if (history is Map && history['events'] is List) {
    b.writeln('- Observed connection history (${history['dropped']} events dropped; not the full timeline across observation gaps):');
    for (final event in (history['events'] as List).whereType<Map>()) {
      final fields = [
        '#${event['sequence']}',
        'at=${event['observedAtEpochMs']}',
        '+${event['elapsedMs']}ms',
        '${event['phase']}',
        if (event['step'] != null) '${event['step']}',
        'attempt=${event['attempt']}',
        if (event['transport'] != null) 'transport=${event['transport']}',
        if (event['fallbackReason'] != null) 'fallback=${event['fallbackReason']}',
        if (event['errorKind'] != null) 'error=${event['errorKind']}',
        if (event['retryable'] != null) 'retryable=${event['retryable']}',
        if (event['reasonCode'] != null) 'reason=${event['reasonCode']}',
      ];
      b.writeln('- ${fields.join(' · ')}');
    }
  }
  b.writeln();
}

void _phone(StringBuffer b, DiagnosticsSnapshot s) {
  b.writeln('## Phone control (local)');
  final phone = s.phone;
  if (!phone.ready) {
    b.writeln('- Phone state unavailable');
  } else {
    b
      ..writeln('- Phone control enabled: ${phone.enabled} · bridge listening: ${phone.bridgeListening}')
      ..writeln('- Accessibility enabled: ${phone.a11y.enabled} · service connected: ${phone.a11y.serviceConnected}');
  }
  _backgroundInputProbe(b, s.native.device['backgroundInputProbe']);
  b.writeln();
}

/// Last accepted native probe facts, not a fresh test or current connectivity.
/// Keep this allowlist aligned with native InputProbeDiagnostics; never print a raw map.
void _backgroundInputProbe(StringBuffer b, Object? raw) {
  const label = '- Last accepted background input probe facts (not a live self-check)';
  if (raw is! Map || raw['v'] is! int || raw['v'] != 1 || raw['observed'] is! bool) {
    b.writeln('$label: unavailable or unknown version');
    return;
  }
  final result = raw['result'];
  final outcome = raw['observed'] == false
      ? 'not run or no retained observation'
      : result == 'success'
      ? 'passed'
      : result == 'failure'
      ? 'failed'
      : 'result unknown';
  b.writeln('$label: $outcome');
  final connectionFailure = raw['connectionFailure'];
  if (connectionFailure is bool) {
    b.writeln('- Retained connection failure fact: $connectionFailure (does not indicate current connection state)');
  }
  if (raw['observed'] != true || result != 'failure') return;
  const stages = {
    'precondition', 'ui_dispatch', 'presentation_create', 'presentation_configure',
    'presentation_show', 'view_layout_wait', 'frame_commit_wait', 'target_validate',
    'input_send', 'receipt_wait', 'cleanup',
  };
  const types = {
    'none', 'SecurityException', 'IllegalStateException', 'IllegalArgumentException',
    'InvalidDisplayException', 'BadTokenException', 'TimeoutException', 'InterruptedException', 'OtherException',
  };
  final stage = raw['stage'];
  final type = raw['exceptionType'];
  final elapsed = raw['elapsedMs'];
  final details = <String>[
    if (stage is String && stages.contains(stage)) 'stage=$stage',
    if (type is String && types.contains(type)) 'type=$type',
    if (elapsed is int && elapsed >= 0 && elapsed <= 60000) 'elapsedMs=$elapsed',
  ];
  if (details.isNotEmpty) b.writeln('- Background input probe failure details: ${details.join(' · ')}');
}

void _performance(StringBuffer b, DiagnosticsSnapshot s) {
  b.writeln('## Performance');
  final p = s.performance;
  if (p.isEmpty) {
    b.writeln('- No samples');
  } else {
    for (final e in p.entries) {
      final value = e.value;
      if (value is Map) {
        b.writeln('- ${e.key}: ${value.entries.map((x) => '${x.key}=${x.value}').join(' ')}');
      } else {
        b.writeln('- ${e.key}: $value');
      }
    }
  }
  b.writeln();
}

void _errors(StringBuffer b, DiagnosticsSnapshot s) {
  if (s.appErrors.isEmpty) return;
  b.writeln('## Recent errors (caught in app)');
  for (final e in s.appErrors.reversed.take(diagnosticsErrorLines).toList().reversed) {
    b.writeln('- ${_time(e.at)} · ${e.source.name}: ${_firstLine(e.message)}');
  }
  b.writeln();
}

void _log(StringBuffer b, String title, List<String> lines, int maxLines) {
  if (lines.isEmpty) return;
  final tail = lines.length <= maxLines ? lines : lines.sublist(lines.length - maxLines);
  b
    ..writeln('## $title (${lines.length} lines, showing last ${tail.length})')
    ..writeln('```log')
    ..writeln(tail.join('\n'))
    ..writeln('```')
    ..writeln();
}

String _join(List<Object?> parts, {bool mono = false}) {
  final text = parts.where((p) => p != null && '$p'.trim().isNotEmpty).map((p) => '$p'.trim()).join(' · ');
  return mono && text.isNotEmpty ? '`$text`' : text;
}

String _android(Map<String, Object?> device) {
  final version = device['android'];
  final sdk = device['sdkInt'];
  if (version == null && sdk == null) return '';
  return version == null ? 'SDK $sdk' : 'Android $version${sdk == null ? '' : ' (SDK $sdk)'}';
}

String _mb(Object? value, String label) {
  if (value is! num) return '';
  return '$label ${value.round()} MB';
}

String _short(String? version) => version == null ? '—' : (version.length > 22 ? version.substring(0, 22) : version);

String _time(DateTime at) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${at.year}-${two(at.month)}-${two(at.day)} ${two(at.hour)}:${two(at.minute)}:${two(at.second)}';
}

String _firstLine(String text) {
  final line = text.split('\n').first.trim();
  return line.length <= 240 ? line : '${line.substring(0, 240)}…';
}
