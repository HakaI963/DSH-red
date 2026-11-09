import 'package:dsh_app/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => AppLocale.use(AppLocale.zhCN));

  group('AppLocale.resolve', () {
    test('a fixed choice wins over the system', () {
      expect(AppLocale.resolve(AppLocale.en, const [Locale('zh', 'CN')]), AppLocale.en);
      expect(AppLocale.resolve(AppLocale.zhCN, const [Locale('en', 'US')]), AppLocale.zhCN);
    });

    test('system languages never pick Chinese', () {
      for (final l in const [
        Locale('zh'),
        Locale('zh', 'TW'),
        Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      ]) {
        expect(AppLocale.resolve(null, [l]), AppLocale.en, reason: '$l');
      }
    });

    test('every system language list resolves to English', () {
      expect(AppLocale.resolve(null, const [Locale('ja'), Locale('zh')]), AppLocale.en);
      expect(AppLocale.resolve(null, const [Locale('fr'), Locale('en')]), AppLocale.en);
      expect(AppLocale.resolve(null, const [Locale('ja')]), AppLocale.en);
      expect(AppLocale.resolve(null, const []), AppLocale.en);
    });
  });

  test('appL10n follows AppLocale.use', () {
    expect(appL10n.commonCancel, '取消');
    AppLocale.use(AppLocale.en);
    expect(appL10n.commonCancel, 'Cancel');
    expect(appL10n.commonItemCount(1), '1 item');
    expect(appL10n.commonItemCount(3), '3 items');
    expect(appL10n.monthDay(DateTime(2026, 3, 5)), 'Mar 5');
    AppLocale.use(const Locale('zh'));
    expect(AppLocale.current, AppLocale.zhCN);
    expect(appL10n.monthDay(DateTime(2026, 3, 5)), '3月5日');
  });

  testWidgets('context.l10n falls back to appL10n without the delegate', (tester) async {
    late String text;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            text = context.l10n.commonCancel;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(text, '取消');
  });
}
