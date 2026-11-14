import 'dart:async';

import 'package:dsh_app/runtime/runtime_bridge.dart';
import 'package:dsh_app/runtime/runtime_state.dart';
import 'package:dsh_app/state/connection_state.dart';
import 'package:dsh_app/state/settings_state.dart';
import 'package:dsh_client/dsh_client.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/ready_mux.dart';
import 'support/wait.dart';

class _Runtime extends LocalRuntimeController {
  @override
  LocalRuntimeState build() => _running('first');

  static LocalRuntimeState _running(String token) => LocalRuntimeState(
    loaded: true,
    status: RuntimeStatus.fromMap({'phase': 'running', 'baseUrl': 'http://127.0.0.1:9', 'token': token}),
  );

  void replace(String token) => state = _running(token);
}

/// A runtime that records the restart the connection path asks for.
class _RestartableRuntime extends _Runtime {
  int starts = 0;

  @override
  Future<void> stop() async {
    // The engine is gone: the phase leaves "running", so the wait ends.
    state = LocalRuntimeState(
      loaded: true,
      status: RuntimeStatus.fromMap({'phase': 'installed'}),
    );
  }

  @override
  Future<void> start() async {
    starts++;
  }
}

/// A native side that answers "the engine serves on another endpoint".
class _Bridge extends RuntimeBridge {
  _Bridge({this.changed = true}) : super(methods: const MethodChannel('dsh/runtime-test'));

  /// What `refreshEndpoint` reports: true when the endpoint changed.
  final bool changed;
  int refreshes = 0;

  @override
  Future<bool> refreshEngineEndpoint() async {
    refreshes++;
    return changed;
  }
}

class _Settings extends SettingsController {
  @override
  AppSettings build() => const AppSettings(loaded: true);
}

class _Client extends DshClient {
  _Client() : super(DshConnection(Uri.parse('http://127.0.0.1:9')));
  final _readyMux = ReadyMux();
  @override
  DshMux get mux => _readyMux;
  bool closed = false;

  @override
  Future<void> close() async {
    closed = true;
    await super.close();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a replaced build closes its late client', () async {
    final pending = <Completer<DshClient>>[];
    final c = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith(_Settings.new),
        localRuntimeProvider.overrideWith(_Runtime.new),
        networkKicksProvider.overrideWithValue(const Stream.empty()),
        localClientConnectorProvider.overrideWithValue(({required baseUri, required token}) {
          final done = Completer<DshClient>();
          pending.add(done);
          return done.future;
        }),
      ],
    );
    addTearDown(c.dispose);
    final sub = c.listen(localConnectionProvider, (_, _) {});
    addTearDown(sub.close);
    await Future<void>.delayed(Duration.zero);
    (c.read(localRuntimeProvider.notifier) as _Runtime).replace('second');
    await Future<void>.delayed(Duration.zero);
    expect(pending, hasLength(2));
    final old = _Client();
    pending.first.complete(old);
    await Future<void>.delayed(Duration.zero);
    expect(old.closed, isTrue);
    final current = _Client();
    pending.last.complete(current);
    await until(c, localConnectionProvider, (s) => s.value != null, what: '新本机连接');
    expect(c.read(localConnectionProvider).value!.client, same(current));
    expect(current.closed, isFalse);
  });

  test('network kick restarts a failed local connection', () async {
    var attempts = 0;
    final kicks = StreamController<void>.broadcast(sync: true);
    addTearDown(kicks.close);
    final c = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        settingsProvider.overrideWith(_Settings.new),
        localRuntimeProvider.overrideWith(_Runtime.new),
        runtimeBridgeProvider.overrideWithValue(_Bridge()),
        networkKicksProvider.overrideWithValue(kicks.stream),
        localClientConnectorProvider.overrideWithValue(({required baseUri, required token}) async {
          attempts++;
          if (attempts == 1) throw const DshTransportException('offline');
          return _Client();
        }),
      ],
    );
    addTearDown(c.dispose);
    final sub = c.listen(localConnectionProvider, (_, _) {});
    addTearDown(sub.close);
    await until(c, localConnectionProvider, (s) => s.hasError, what: '本机连接失败');
    kicks.add(null);
    await until(c, localConnectionProvider, (s) => s.value != null, what: '网络恢复后连接');
    expect(attempts, 2);
  });

  test('a refused login asks the engine again for its endpoint', () async {
    // The engine may serve with another token or another port than the one the
    // app used: the engine's own log is the truth, so the app asks it again.
    final bridge = _Bridge();
    final c = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        settingsProvider.overrideWith(_Settings.new),
        localRuntimeProvider.overrideWith(_Runtime.new),
        runtimeBridgeProvider.overrideWithValue(bridge),
        networkKicksProvider.overrideWithValue(const Stream.empty()),
        localClientConnectorProvider.overrideWithValue(({required baseUri, required token}) async {
          throw const DshHttpException(401, 'launch token rejected');
        }),
      ],
    );
    addTearDown(c.dispose);
    final sub = c.listen(localConnectionProvider, (_, _) {});
    addTearDown(sub.close);
    await until(c, localConnectionProvider, (s) => s.hasError, what: '本机连接失败');
    expect(bridge.refreshes, greaterThanOrEqualTo(1));
  });

  test('an engine that refuses every login is restarted once', () async {
    // The engine answers but does not serve: a fresh process gets a fresh
    // token and a fresh port, and the app reconnects to it.
    final runtime = _RestartableRuntime();
    final bridge = _Bridge(changed: false);
    final c = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        settingsProvider.overrideWith(_Settings.new),
        localRuntimeProvider.overrideWith(() => runtime),
        runtimeBridgeProvider.overrideWithValue(bridge),
        networkKicksProvider.overrideWithValue(const Stream.empty()),
        localClientConnectorProvider.overrideWithValue(({required baseUri, required token}) async {
          throw const DshHttpException(401, 'launch token rejected');
        }),
      ],
    );
    addTearDown(c.dispose);
    final sub = c.listen(localConnectionProvider, (_, _) {});
    addTearDown(sub.close);
    await until(c, localConnectionProvider, (s) => s.hasError, what: '本机连接失败');
    expect(bridge.refreshes, greaterThanOrEqualTo(1));
    expect(runtime.starts, 1);
  });
}
