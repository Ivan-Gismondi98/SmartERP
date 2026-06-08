// ============================================================
//  SMARTERP · theme.dart — tema condiviso dell'app.
// ============================================================
import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const Color seed = Color(0xFF0D47A1);

  static ThemeData light([Color? brandSeed]) => ThemeData(
        useMaterial3: true,
        colorSchemeSeed: brandSeed ?? seed,
        brightness: Brightness.light,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      );

  static ThemeData dark([Color? brandSeed]) => ThemeData(
        useMaterial3: true,
        colorSchemeSeed: brandSeed ?? seed,
        brightness: Brightness.dark,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      );

  /// Converte "#RRGGBB" in Color (null se non valido).
  static Color? hexToColor(String? hex) {
    if (hex == null) return null;
    var h = hex.trim().replaceAll('#', '');
    if (h.length == 6) h = 'FF$h';
    if (h.length != 8) return null;
    final v = int.tryParse(h, radix: 16);
    return v == null ? null : Color(v);
  }
}
