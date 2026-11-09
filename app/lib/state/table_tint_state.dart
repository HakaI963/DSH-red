import 'dart:async';
import 'dart:ui' show Color;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether tables get background tint.
///
/// Only affects pipe tables in reply bodies: code blocks, quotes and the rest of the text are untouched.
enum TableTint {
  /// A light header, the body follows the text. Default, and how it looked before this setting existed.
  follow,

  /// Light header, every other row a shade tinted; the whole table reads like one card, easy to scan when long.
  fill,

  /// No tint on header or body: only grid lines and text remain.
  none,
}

/// The two fills each of the three levels wants.
///
/// [header] is never null: passing null to `TableStyle.headerBackground` falls back to the theme color,
/// so "no tint" must give explicit transparency. A null [stripe] draws no alternating rows.
({Color header, Color? stripe}) tableTintFills(
  TableTint tint, {
  required Color headerColor,
  required Color stripeColor,
}) => switch (tint) {
  TableTint.follow => (header: headerColor, stripe: null),
  TableTint.fill => (header: headerColor, stripe: stripeColor),
  TableTint.none => (header: transparentFill, stripe: null),
};

/// Explicit transparency rather than `Colors.transparent`: the state layer doesn't import Flutter's
/// material package, so this file still runs in pure Dart tests.
const transparentFill = Color(0x00000000);

/// Table tint is stored on the phone; the settings page writes and the render layer reads through the same provider.
class TableTintController extends Notifier<TableTint> {
  static const key = 'chat.table_tint';

  @override
  TableTint build() {
    unawaited(_read());
    return TableTint.follow;
  }

  Future<void> _read() async {
    final TableTint? stored;
    try {
      final prefs = await SharedPreferences.getInstance();
      stored = TableTint.values.asNameMap()[prefs.getString(key)];
    } catch (_) {
      // Pure Dart tests have no SharedPreferences: stay on the default level.
      return;
    }
    if (stored != null && stored != state) state = stored;
  }

  Future<void> set(TableTint tint) async {
    if (tint == state) return;
    state = tint;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, tint.name);
    } catch (_) {
      // If it can't be stored it holds for this session only; the settings page isn't interrupted.
    }
  }
}

final tableTintProvider = NotifierProvider<TableTintController, TableTint>(TableTintController.new);
