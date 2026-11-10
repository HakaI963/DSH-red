// "Agent reconnect" against the fake Host: the switch reveals the steppers,
// 保存 writes one retry policy into every `llm-*` namespace that carries the
// field and mirrors the choice in prefs; an off draft falls back to the
// engine's default (nothing to write) and is still remembered.

import 'package:dsh_app/ui/engine_settings/agent_reconnect_page.dart';
import 'package:dsh_client/dsh_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support.dart';

void main() {
  late FakeSettingsHost host;

  Future<void> open(WidgetTester tester, {Map<String, Object?> values = const {}}) async {
    SharedPreferences.setMockInitialValues(values);
    host = FakeSettingsHost();
    await pumpPage(
      tester,
      const AgentReconnectSettingsPage(),
      overrides: engineOverrides(DshClient.withCarrier(host)),
      height: 1100,
    );
  }

  testWidgets('on writes the policy to every llm namespace and saves the draft', (tester) async {
    await open(tester);
    expect(find.text('失败模型调用自动重试'), findsOneWidget);
    expect(find.text('重试次数'), findsNothing, reason: 'the steppers only show when the switch is on');

    await tester.tap(find.text('失败模型调用自动重试'));
    await settle(tester);
    expect(find.text('重试次数'), findsOneWidget);
    expect(find.text('3 次重试'), findsOneWidget);

    await tester.tap(find.text('保存'));
    await flush(tester);
    final ops = {
      for (final m in host.mutates())
        m['ns']! as String: (m['ops']! as List).single! as Map<String, Object?>,
    };
    expect(ops.keys.toSet(), {'llm-deepseek', 'llm-deepseek-account', 'llm-pi-ai'});
    for (final op in ops.values) {
      expect(op['op'], 'set');
      expect(op['path'], ['retryPolicy']);
      expect(op['value'], {
        'mode': 'normal',
        'maxRetries': 3,
        'retryableCodes': ['EMPTY_RESPONSE', 'RATE_LIMIT', 'SERVER', 'TIMEOUT', 'TRANSPORT'],
        'backoff': {'initialDelayMs': 2000, 'maxDelayMs': 30000, 'jitterRatio': 0.1},
      });
    }
    expect((await SharedPreferences.getInstance()).getString('agent_reconnect'), '3:2:30');
  });

  testWidgets('off restores the engine default and the draft is remembered', (tester) async {
    await open(tester, values: {'agent_reconnect': '5:10:60'});
    // No live policy on this Host: the saved draft shows through.
    expect(find.text('5 次重试'), findsOneWidget);

    await tester.tap(find.text('失败模型调用自动重试'));
    await settle(tester);
    await tester.tap(find.text('保存'));
    await flush(tester);
    // The engine default is "stop at once": nothing to unset, nothing sent.
    expect(host.mutates(), isEmpty);
    expect((await SharedPreferences.getInstance()).getString('agent_reconnect'), 'off');
  });
}
