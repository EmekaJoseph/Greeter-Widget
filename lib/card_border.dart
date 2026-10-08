import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import 'widget_store.dart';

/// Gradient styles for the card's border. Each has a bright stop for shine.
enum BorderStyleOption {
  gold('Gold', [
    Color(0xFFB8860B),
    Color(0xFFFFD700),
    Color(0xFFFFF8DC),
    Color(0xFFDAA520),
    Color(0xFFB8860B),
  ]),
  silver('Silver', [
    Color(0xFF8E9196),
    Color(0xFFE8E8E8),
    Color(0xFFFFFFFF),
    Color(0xFFB0B3B8),
    Color(0xFF8E9196),
  ]),
  rainbow('Rainbow', [
    Color(0xFFFF5F6D),
    Color(0xFFFFC371),
    Color(0xFF47E891),
    Color(0xFF3FA9F5),
    Color(0xFFA66CFF),
  ]),
  ocean('Ocean', [Color(0xFF00C6FF), Color(0xFFA0F0FF), Color(0xFF0072FF)]),
  sunset('Sunset', [Color(0xFFFF512F), Color(0xFFFFD1A1), Color(0xFFDD2476)]),

  /// Follows the card's accent colour, including the automatic night theme.
  accent('Accent', []),
  custom('Custom', []);

  const BorderStyleOption(this.label, this.presetColors);

  final String label;
  final List<Color> presetColors;

  static BorderStyleOption fromName(String? name) => values.firstWhere(
    (s) => s.name == name,
    orElse: () => CardBorder.defaults.style,
  );
}

/// [color] mixed 60% of the way to white. Must match shine() in GreeterWidget.kt.
Color shine(Color color) => Color.lerp(color, Colors.white, 0.6)!;

class CardBorder {
  const CardBorder({
    required this.enabled,
    required this.widthDp,
    required this.style,
    required this.customStart,
    required this.customEnd,
  });

  /// Defaults must match GreeterWidget.kt.
  static const defaults = CardBorder(
    enabled: false,
    widthDp: 2,
    style: BorderStyleOption.gold,
    customStart: Color(0xFFFF5F6D),
    customEnd: Color(0xFF3FA9F5),
  );

  static const minWidthDp = 1;
  static const maxWidthDp = 6;

  final bool enabled;
  final int widthDp;
  final BorderStyleOption style;
  final Color customStart;
  final Color customEnd;

  /// The gradient's colours, top-left to bottom-right.
  List<Color> colors(Color accent) => switch (style) {
    BorderStyleOption.accent => [accent, shine(accent), accent],
    BorderStyleOption.custom => [customStart, shine(customStart), customEnd],
    _ => style.presetColors,
  };

  CardBorder copyWith({
    bool? enabled,
    int? widthDp,
    BorderStyleOption? style,
    Color? customStart,
    Color? customEnd,
  }) => CardBorder(
    enabled: enabled ?? this.enabled,
    widthDp: widthDp ?? this.widthDp,
    style: style ?? this.style,
    customStart: customStart ?? this.customStart,
    customEnd: customEnd ?? this.customEnd,
  );

  static Future<CardBorder> load() async {
    Future<Color?> color(String key) async {
      final rgb = await HomeWidget.getWidgetData<int>(key);
      return rgb == null ? null : rgbToColor(rgb);
    }

    return CardBorder(
      enabled:
          await HomeWidget.getWidgetData<bool>(WidgetKeys.borderOn) ??
          defaults.enabled,
      widthDp:
          await HomeWidget.getWidgetData<int>(WidgetKeys.borderWidth) ??
          defaults.widthDp,
      style: BorderStyleOption.fromName(
        await HomeWidget.getWidgetData<String>(WidgetKeys.borderStyle),
      ),
      customStart:
          await color(WidgetKeys.borderCustomStart) ?? defaults.customStart,
      customEnd: await color(WidgetKeys.borderCustomEnd) ?? defaults.customEnd,
    );
  }

  /// The widget reads borderOn, borderWidth and borderStyle, and the gradient
  /// from borderColors (a JSON list of 0xRRGGBB), except for the accent style,
  /// which it works out itself so it follows the night theme.
  Future<void> save(Color accent) async {
    await HomeWidget.saveWidgetData<bool>(WidgetKeys.borderOn, enabled);
    await HomeWidget.saveWidgetData<int>(WidgetKeys.borderWidth, widthDp);
    await HomeWidget.saveWidgetData<String>(WidgetKeys.borderStyle, style.name);
    await HomeWidget.saveWidgetData<int>(
      WidgetKeys.borderCustomStart,
      colorToRgb(customStart),
    );
    await HomeWidget.saveWidgetData<int>(
      WidgetKeys.borderCustomEnd,
      colorToRgb(customEnd),
    );
    await HomeWidget.saveWidgetData<String>(
      WidgetKeys.borderColors,
      jsonEncode([for (final c in colors(accent)) colorToRgb(c)]),
    );
  }
}

/// Paints the gradient border over the card in the app's preview.
/// Mirrors cardBackgroundBitmap() in GreeterWidget.kt.
class GradientBorderPainter extends CustomPainter {
  const GradientBorderPainter({
    required this.colors,
    required this.widthDp,
    required this.radius,
  });

  final List<Color> colors;
  final int widthDp;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final half = widthDp / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = widthDp.toDouble()
      ..shader = LinearGradient(
        colors: colors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.deflate(half),
        Radius.circular(radius - half),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(GradientBorderPainter old) =>
      old.widthDp != widthDp || old.radius != radius || old.colors != colors;
}
