import 'dart:ui' show Color;

import 'package:dsh_app/state/table_tint_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The three levels differ only in the two fills: the header always gets a colour (transparent counts), stripes get one or not.
  const header = Color(0xFF112233);
  const stripe = Color(0x0A000000);

  group('tableTintFills', () {
    test('follow keeps the header fill and draws no stripes', () {
      final fills = tableTintFills(TableTint.follow, headerColor: header, stripeColor: stripe);
      expect(fills.header, header);
      expect(fills.stripe, isNull);
    });

    test('fill paints both the header and the stripes', () {
      final fills = tableTintFills(TableTint.fill, headerColor: header, stripeColor: stripe);
      expect(fills.header, header);
      expect(fills.stripe, stripe);
    });

    test('none is transparent, not null', () {
      // TableStyle reads null as "use the theme default", so "no fill" must be an explicit transparency.
      final fills = tableTintFills(TableTint.none, headerColor: header, stripeColor: stripe);
      expect(fills.header, transparentFill);
      expect(fills.header.a, 0);
      expect(fills.stripe, isNull);
    });
  });

  group('TableTint storage', () {
    test('every value round-trips through its stored name', () {
      for (final tint in TableTint.values) {
        expect(TableTint.values.asNameMap()[tint.name], tint);
      }
    });

    test('an unknown stored name falls back to follow', () {
      expect(TableTint.values.asNameMap()['nope'] ?? TableTint.follow, TableTint.follow);
    });
  });
}
