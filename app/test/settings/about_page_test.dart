import 'package:dsh_app/l10n/l10n.dart';
import 'package:dsh_app/state/star_prompt.dart';
import 'package:dsh_app/state/update_state.dart';
import 'package:dsh_app/ui/settings/about_page.dart';
import 'package:dsh_app/ui/theme/theme.dart';
import 'package:dsh_app/update/version.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_fonts.dart';

class _FixedUpdate extends AppUpdateController {
  @override
  AppUpdateState build() => const AppUpdateState(current: AppVersion(1, 0, 2, build: 42));
}

class _StarStore implements StarPromptStore {
  final writes = <StarPromptRecord>[];

  @override
  Future<StarPromptRecord?> read() async => const StarPromptRecord();

  @override
  Future<void> write(StarPromptRecord record) async => writes.add(record);
}

void main() {
  late List<Uri> opened;
  late _StarStore store;
  late Future<bool> Function(Uri) opener;

  setUp(() {
    opened = [];
    store = _StarStore();
    opener = (uri) async {
      opened.add(uri);
      return true;
    };
  });

  tearDown(() => AppLocale.use(AppLocale.zhCN));

  Future<void> pump(
    WidgetTester tester, {
    Locale locale = AppLocale.zhCN,
    Brightness brightness = Brightness.light,
    double scale = 1,
  }) async {
    AppLocale.use(locale);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appUpdateProvider.overrideWith(_FixedUpdate.new),
          starLinkOpenerProvider.overrideWithValue((uri) => opener(uri)),
          starPromptStoreProvider.overrideWithValue(store),
          starPromptGateProvider.overrideWithValue(false),
        ],
        child: MaterialApp(
          theme: withTestFonts(buildLightTheme()),
          darkTheme: withTestFonts(buildDarkTheme()),
          themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
          locale: locale,
          supportedLocales: AppLocale.supported,
          localizationsDelegates: L10n.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const AboutPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String key) async {
    final row = find.byKey(ValueKey(key));
    await tester.ensureVisible(row);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
  }

  for (final locale in AppLocale.supported) {
    for (final brightness in Brightness.values) {
      testWidgets('the about page fits 360dp at 1.3x in $locale $brightness', (tester) async {
        await pump(tester, locale: locale, brightness: brightness, scale: 1.3);
        final english = locale == AppLocale.en;
        expect(find.text('1.0.2 (42)'), findsOneWidget);
        expect(find.byKey(const ValueKey('settings-star')), findsOneWidget);
        final disclaimer = find.text(
          english ? 'Built on DeepSeek Harness · Unofficial DeepSeek app' : '基于 DeepSeek Harness 构建 · 非 DeepSeek 官方应用',
        );
        await tester.ensureVisible(disclaimer);
        await tester.pumpAndSettle();
        expect(disclaimer.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('the separate project star still opens the repository', (tester) async {
    await pump(tester);
    await tap(tester, 'settings-star');
    expect(opened.map((uri) => uri.toString()), ['https://github.com/HakaI963/DSH-red']);
    expect(store.writes.last.finished, isTrue);
  });
}
