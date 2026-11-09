// Tapping the expanded reasoning body collapses it too — the same as
// tapping the header again: back to the three-line live window (思考中)
// or the inline preview (turn over). Links and 「翻译」 stay tappable.
//
// The body selects text on its own (SelectionArea), and that layer's tap
// wins the pointer before the outer wrapper, so the widget nests the
// selection **outside** the collapse gesture (see _CollapsibleReasoningBody
// in thinking_pill.dart). These tests drive real taps, not the callbacks.

import 'dart:ui' as ui;

import 'package:dsh_app/links/app_links.dart';
import 'package:dsh_app/links/page_links.dart';
import 'package:dsh_app/state/cot_translation_state.dart';
import 'package:dsh_app/state/sessions_state.dart';
import 'package:dsh_app/ui/chat/render/markdown_body.dart';
import 'package:dsh_app/ui/chat/widgets/thinking_pill.dart';
import 'package:dsh_client/dsh_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

const _reasoning = '第一段思考:先确认按钮在请求期间是否禁用。\n\n第二段:再补一个连点测试。';
const _preview = '第一段思考:先确认按钮在请求期间是否禁用。';

const _english = 'The user wants double taps on the login button to send one request.';
const _translated = '用户希望连点登录按钮时只发出一次请求。';
const _limits = CotTranslationLimits(
  maxTextChars: 4000,
  provider: 'bing',
  targetLanguage: 'auto',
  availableProviders: ['bing', 'google'],
);

Widget _app(ThinkingPill pill) => testApp(
  Scaffold(
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Align(alignment: Alignment.topLeft, child: pill),
      ),
    ),
  ),
);

Finder get _body => find.byType(MarkdownBody);
Finder get _ticker => find.byType(ThinkingTicker);

Future<void> _expand(WidgetTester tester, {bool active = false}) async {
  await tester.tap(find.text(active ? '思考中' : '思考'));
  await pumpFrames(tester, 6);
}

/// Centre of a run of [label] text in the body (measured on its layout box, not guessed).
Offset _labelCenter(WidgetTester tester, String label) {
  final paragraph = tester.renderObject<RenderParagraph>(
    find.descendant(
      of: _body,
      matching: find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains(label)),
    ),
  );
  final text = paragraph.text.toPlainText();
  final start = text.indexOf(label);
  final box = paragraph
      .getBoxesForSelection(TextSelection(baseOffset: start, extentOffset: start + label.length))
      .first;
  return paragraph.localToGlobal(Offset((box.left + box.right) / 2, (box.top + box.bottom) / 2));
}

void main() {
  setUpAll(loadTestFonts);

  testWidgets('tapping the open body folds back to the live window while thinking', (tester) async {
    await tester.pumpWidget(_app(const ThinkingPill(reasoning: _reasoning, active: true)));
    await pumpFrames(tester, 4);
    expect(_ticker, findsOneWidget);

    await _expand(tester, active: true);
    expect(_body, findsOneWidget);
    expect(_ticker, findsNothing);

    await tester.tapAt(tester.getCenter(_body));
    await pumpFrames(tester, 8);
    expect(_ticker, findsOneWidget);
    expect(_body, findsNothing);
  });

  testWidgets('tapping the open body after the turn returns to the inline preview', (tester) async {
    await tester.pumpWidget(_app(const ThinkingPill(reasoning: _reasoning)));
    await pumpFrames(tester, 2);
    expect(find.text(_preview), findsOneWidget);

    await _expand(tester);
    expect(_body, findsOneWidget);
    expect(_ticker, findsNothing);

    await tester.tapAt(tester.getCenter(_body));
    await pumpFrames(tester, 8);
    expect(_body, findsNothing);
    expect(find.text(_preview), findsOneWidget);
  });

  testWidgets('the header still toggles the body on its own', (tester) async {
    await tester.pumpWidget(_app(const ThinkingPill(reasoning: _reasoning)));
    await pumpFrames(tester, 2);

    await _expand(tester);
    expect(_body, findsOneWidget);

    // Tap the header again: collapsed.
    await tester.tap(find.text('思考'));
    await pumpFrames(tester, 8);
    expect(_body, findsNothing);
    expect(find.text(_preview), findsOneWidget);

    // It opens again.
    await _expand(tester);
    expect(_body, findsOneWidget);
  });

  testWidgets('a link in the open body opens its page and does not fold the body', (tester) async {
    final links = AppLinks();
    final router = LinkRouter(links.links, grace: Duration.zero);
    final opened = <String>[];
    addTearDown(() {
      router.dispose();
      links.dispose();
    });
    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: SafeArea(
            child: Stack(
              children: [
                const LinkHost(),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: ThinkingPill(reasoning: '先看看[打开手机操控](dshgo://open/phone)再决定。\n\n第二段。'),
                ),
              ],
            ),
          ),
        ),
        overrides: [
          linkRouterProvider.overrideWithValue(router),
          pageLinkResolverProvider.overrideWithValue((id, _) {
            opened.add(id);
            return Scaffold(body: Text('page $id'));
          }),
        ],
      ),
    );
    await pumpFrames(tester, 2);
    await _expand(tester);

    await tester.tapAt(_labelCenter(tester, '打开手机操控'));
    await tester.pumpAndSettle();
    expect(opened, ['phone']);
    expect(find.text('page phone'), findsOneWidget);

    // The link took this tap: back up, and the reasoning body is still expanded.
    Navigator.of(tester.element(find.text('page phone'))).pop();
    await tester.pumpAndSettle();
    expect(_body, findsOneWidget);
    expect(_ticker, findsNothing);
  });

  testWidgets('the translate chip toggles in place and does not fold the body', (tester) async {
    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ThinkingPill(reasoning: _english),
            ),
          ),
        ),
        overrides: [
          currentSessionProvider.overrideWith(() => FixedSession('s1')),
          cotTranslationProvider.overrideWith((ref) async => _limits),
          reasoningTranslatorProvider.overrideWithValue((text, {required limits, sessionId}) async => _translated),
        ],
      ),
    );
    await pumpFrames(tester, 2);
    await _expand(tester);
    expect(find.text('翻译'), findsOneWidget);

    await tester.tap(find.text('翻译'));
    await pumpFrames(tester, 4);
    expect(find.text(_translated), findsOneWidget);
    // The toolbar sits outside the collapse gesture: switching the translation does not fold the body.
    expect(_body, findsOneWidget);
    expect(_ticker, findsNothing);

    await tester.tap(find.text('查看原文'));
    await pumpFrames(tester, 2);
    expect(find.textContaining('double taps'), findsOneWidget);
    expect(_body, findsOneWidget);
  });

  testWidgets('the open body advertises a collapse action; the header keeps its expanded flag', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_app(const ThinkingPill(reasoning: '只有一段思考。')));
    await pumpFrames(tester, 2);

    final collapsed = tester.getSemantics(find.text('思考')).getSemanticsData();
    expect(collapsed.flagsCollection.isExpanded, ui.Tristate.isFalse);

    await _expand(tester);
    final header = tester.getSemantics(find.text('思考')).getSemanticsData();
    expect(header.flagsCollection.isButton, isTrue);
    expect(header.flagsCollection.isExpanded, ui.Tristate.isTrue);

    final bodySemantics = find.byWidgetPredicate((w) => w is Semantics && w.properties.hint == '收起');
    expect(bodySemantics, findsOneWidget);
    final data = tester.getSemantics(bodySemantics).getSemanticsData();
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.hasAction(SemanticsAction.tap), isTrue);
    expect(data.hint, '收起');
    handle.dispose();
  });

  testWidgets('dragging the open body scrolls the list instead of folding', (tester) async {
    await tester.pumpWidget(
      testApp(
        Scaffold(
          body: ListView(
            children: [
              const ThinkingPill(reasoning: _reasoning),
              for (var i = 0; i < 20; i++) SizedBox(height: 100, child: Text('row $i')),
            ],
          ),
        ),
      ),
    );
    await pumpFrames(tester, 2);
    await _expand(tester);
    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable).first);
    expect(scrollable.position.pixels, 0);

    // Drag from a point surely on the body's text (the finder's render box is
    // not validated: the MarkdownBody finder lands on the wrapper, never hit-tested).
    await tester.dragFrom(tester.getTopLeft(_body) + const Offset(120, 12), const Offset(0, -40));
    await pumpFrames(tester, 8);
    expect(scrollable.position.pixels, greaterThan(0));
    // A drag must not read as a tap: the body stays expanded.
    expect(_body, findsOneWidget);
    expect(_ticker, findsNothing);
  });
}
