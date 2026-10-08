import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

const String androidWidgetName = 'GreeterWidget';

/// Keys shared with GreeterWidget.kt.
abstract final class WidgetKeys {
  static const name = 'name';
  static const focus = 'focus';
  static const avatarPath = 'avatarPath';
  static const greetingStyle = 'greetingStyle';
  static const greetings = 'greetings';
  static const birthday = 'birthday';
  static const specialDays = 'specialDays';
  static const specialQuoteHiddenDay = 'specialQuoteHiddenDay';
  static const autoNight = 'autoNight';
  static const countdownName = 'countdownName';
  static const borderOn = 'borderOn';
  static const borderWidth = 'borderWidth';
  static const borderStyle = 'borderStyle';
  static const borderCustomStart = 'borderCustomStart';
  static const borderCustomEnd = 'borderCustomEnd';
  static const borderColors = 'borderColors';
  static const countdownDate = 'countdownDate';
  static const nightTheme = 'nightTheme';
  static const focusDay = 'focusDay';
  static const showFocus = 'showFocus';
  static const quotes = 'quotes';
  static const customQuotes = 'customQuotes';
  static const onlyMyQuotes = 'onlyMyQuotes';
  static const calendarHolidays = 'calendarHolidays';
  static const calendarGreetings = 'calendarGreetings';
  static const notifyOn = 'notifyOn';
  static const notifyMinutes = 'notifyMinutes';
  static const quoteShuffle = 'quoteShuffle';
  static const cardColor = 'cardColor';
  static const cardOpacity = 'cardOpacity';
  static const textColor = 'cardTextColor';
  static const accentColor = 'cardAccentColor';
}

/// Hours at which the greeting (and quote) changes. Must match GreeterWidget.kt.
const int morningStartHour = 5;
const int afternoonStartHour = 12;
const int eveningStartHour = 17;

/// The automatic night theme runs from this hour until [morningStartHour].
/// Must match GreeterWidget.kt.
const int nightStartHour = 19;

bool isNightTime(DateTime time) =>
    time.hour >= nightStartHour || time.hour < morningStartHour;

String greetingFor(DateTime time) {
  final hour = time.hour;
  if (hour >= morningStartHour && hour < afternoonStartHour) {
    return 'Good morning';
  }
  if (hour >= afternoonStartHour && hour < eveningStartHour) {
    return 'Good afternoon';
  }
  return 'Good evening';
}

/// The day a focus belongs to, as yyyy-mm-dd. A day starts with the morning
/// greeting, so the focus resets at 5:00 rather than midnight.
/// Must match GreeterWidget.kt.
DateTime focusDate(DateTime now) {
  final shifted = now.subtract(const Duration(hours: morningStartHour));
  return DateTime(shifted.year, shifted.month, shifted.day);
}

String focusDayKey(DateTime now) {
  final d = focusDate(now);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}

/// "Wed, 8 Oct". Must match GreeterWidget.kt.
String shortDate(DateTime now) {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final d = focusDate(now);
  return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]}';
}

/// Whether the widget shows "Today's focus" until the user changes it.
/// Must match GreeterWidget.kt.
const bool defaultShowFocus = false;

const String focusLabel = "Today's focus";
const String focusPrompt = "Tap to set today's focus";

/// Opens the app at the focus box when the widget's focus area is tapped.
final Uri focusLaunchUri = Uri.parse('greeter://focus');

enum GreetingStyle {
  pidgin('pidgin'),
  english('english');

  const GreetingStyle(this.storedValue);

  /// Default must match GreeterWidget.kt.
  static const defaultStyle = GreetingStyle.pidgin;

  final String storedValue;

  static GreetingStyle fromStored(String? value) => GreetingStyle.values
      .firstWhere((s) => s.storedValue == value, orElse: () => defaultStyle);
}

/// 0 for morning, 1 for afternoon, 2 for evening (including the small hours).
/// Must match GreeterWidget.kt.
int periodOf(DateTime time) {
  final hour = time.hour;
  if (hour >= morningStartHour && hour < afternoonStartHour) return 0;
  if (hour >= afternoonStartHour && hour < eveningStartHour) return 1;
  return 2;
}

/// One number per morning/afternoon/evening, so the quote stays put within a
/// part of the day. Must match GreeterWidget.kt.
int quoteSlot(DateTime now) {
  final shifted = now.subtract(const Duration(hours: morningStartHour));
  final day =
      DateTime.utc(
        shifted.year,
        shifted.month,
        shifted.day,
      ).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;
  return day * 3 + periodOf(now);
}

/// Scrambles the slot so consecutive slots land on unrelated quotes.
/// Must match GreeterWidget.kt.
int quoteIndex(int slot, int shuffle, int count) {
  // High bits of a multiplicative hash; the low bits barely change.
  final hash = (((slot + shuffle) * 2654435761) % 4294967296) >> 16;
  return hash % count;
}

String? currentQuote(List<String> quotes, int shuffle, DateTime now) {
  if (quotes.isEmpty) return null;
  return quotes[quoteIndex(quoteSlot(now), shuffle, quotes.length)];
}

/// The next two weeks of changeovers, so the widget flips on time even when
/// the app isn't opened.
List<DateTime> upcomingGreetingChanges(DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  return [
    for (var day = 0; day < 14; day++)
      for (final hour in [
        morningStartHour,
        afternoonStartHour,
        eveningStartHour,
        nightStartHour,
      ])
        DateTime(today.year, today.month, today.day + day, hour),
  ].where((time) => time.isAfter(now)).toList();
}

Future<void> refreshWidget() async {
  await HomeWidget.updateWidget(androidName: androidWidgetName);
  await HomeWidget.scheduleWidgetUpdates(
    upcomingGreetingChanges(DateTime.now()),
    androidName: androidWidgetName,
  );
}

/// Stored as 0xRRGGBB so it fits in a 32-bit Android int.
int colorToRgb(Color color) => color.toARGB32() & 0xFFFFFF;
Color rgbToColor(int rgb) => Color(0xFF000000 | rgb);

const List<Color> cardColorChoices = [
  Color(0xFFE3F4EE),
  Color(0xFFFFFFFF),
  Color(0xFFFFF4E0),
  Color(0xFFE3EEFA),
  Color(0xFFEFE6F7),
  Color(0xFF1E1E1E),
  Color(0xFF000000),
  Color(0xFF0F2A24),
];

const List<Color> textColorChoices = [
  Color(0xFF0F2A24),
  Color(0xFF111111),
  Color(0xFFFFFFFF),
  Color(0xFF1A2A5E),
  Color(0xFF3B1A55),
  Color(0xFF4A2C1A),
];

const List<Color> accentColorChoices = [
  Color(0xFF1E7A5A),
  Color(0xFF00796B),
  Color(0xFF1565C0),
  Color(0xFF6A1B9A),
  Color(0xFFC62828),
  Color(0xFFEF6C00),
  Color(0xFFFFD54F),
  Color(0xFFA5D6A7),
];

class WidgetAppearance {
  const WidgetAppearance({
    required this.cardColor,
    required this.opacityPercent,
    required this.textColor,
    required this.accentColor,
  });

  /// Defaults must match GreeterWidget.kt.
  static const defaults = WidgetAppearance(
    cardColor: Color(0xFFE3F4EE),
    opacityPercent: 100,
    textColor: Color(0xFF0F2A24),
    accentColor: Color(0xFF1E7A5A),
  );

  final Color cardColor;
  final int opacityPercent;
  final Color textColor;
  final Color accentColor;

  /// Whether both would draw the widget identically.
  bool looksLike(WidgetAppearance other) =>
      colorToRgb(cardColor) == colorToRgb(other.cardColor) &&
      opacityPercent == other.opacityPercent &&
      colorToRgb(textColor) == colorToRgb(other.textColor) &&
      colorToRgb(accentColor) == colorToRgb(other.accentColor);

  WidgetAppearance copyWith({
    Color? cardColor,
    int? opacityPercent,
    Color? textColor,
    Color? accentColor,
  }) {
    return WidgetAppearance(
      cardColor: cardColor ?? this.cardColor,
      opacityPercent: opacityPercent ?? this.opacityPercent,
      textColor: textColor ?? this.textColor,
      accentColor: accentColor ?? this.accentColor,
    );
  }

  static Future<WidgetAppearance> load() async {
    Future<Color?> color(String key) async {
      final rgb = await HomeWidget.getWidgetData<int>(key);
      return rgb == null ? null : rgbToColor(rgb);
    }

    return WidgetAppearance(
      cardColor: await color(WidgetKeys.cardColor) ?? defaults.cardColor,
      opacityPercent:
          await HomeWidget.getWidgetData<int>(WidgetKeys.cardOpacity) ??
          defaults.opacityPercent,
      textColor: await color(WidgetKeys.textColor) ?? defaults.textColor,
      accentColor: await color(WidgetKeys.accentColor) ?? defaults.accentColor,
    );
  }

  Future<void> save() async {
    await HomeWidget.saveWidgetData<int>(
      WidgetKeys.cardColor,
      colorToRgb(cardColor),
    );
    await HomeWidget.saveWidgetData<int>(
      WidgetKeys.cardOpacity,
      opacityPercent,
    );
    await HomeWidget.saveWidgetData<int>(
      WidgetKeys.textColor,
      colorToRgb(textColor),
    );
    await HomeWidget.saveWidgetData<int>(
      WidgetKeys.accentColor,
      colorToRgb(accentColor),
    );
  }
}

/// The Night theme, also used by the automatic night theme.
const WidgetAppearance nightLook = WidgetAppearance(
  cardColor: Color(0xFF14181B),
  opacityPercent: 90,
  textColor: Color(0xFFF2F4F3),
  accentColor: Color(0xFF7FD8B4),
);

/// The look the widget shows at [now].
WidgetAppearance effectiveLook(
  WidgetAppearance chosen,
  DateTime now, {
  required bool autoNight,
}) => autoNight && isNightTime(now) ? nightLook : chosen;

/// Hands the night look to the widget as
/// {"cardColor": rgb, "cardOpacity": n, "cardTextColor": rgb, "cardAccentColor": rgb}.
Future<void> saveNightThemeForWidget() {
  return HomeWidget.saveWidgetData<String>(
    WidgetKeys.nightTheme,
    jsonEncode({
      WidgetKeys.cardColor: colorToRgb(nightLook.cardColor),
      WidgetKeys.cardOpacity: nightLook.opacityPercent,
      WidgetKeys.textColor: colorToRgb(nightLook.textColor),
      WidgetKeys.accentColor: colorToRgb(nightLook.accentColor),
    }),
  );
}

class ThemePreset {
  const ThemePreset(this.name, this.look);

  final String name;
  final WidgetAppearance look;
}

const List<ThemePreset> themePresets = [
  ThemePreset('Mint', WidgetAppearance.defaults),
  ThemePreset('Night', nightLook),
  ThemePreset(
    'Sand',
    WidgetAppearance(
      cardColor: Color(0xFFF6EBDD),
      opacityPercent: 100,
      textColor: Color(0xFF3A2A1A),
      accentColor: Color(0xFFB5652B),
    ),
  ),
  ThemePreset(
    'Ocean',
    WidgetAppearance(
      cardColor: Color(0xFFE3EEFA),
      opacityPercent: 100,
      textColor: Color(0xFF0D2440),
      accentColor: Color(0xFF1565C0),
    ),
  ),
  ThemePreset(
    'Lavender',
    WidgetAppearance(
      cardColor: Color(0xFFEFE7F8),
      opacityPercent: 100,
      textColor: Color(0xFF2C1A3F),
      accentColor: Color(0xFF7B4BB5),
    ),
  ),
  ThemePreset(
    'Paper',
    WidgetAppearance(
      cardColor: Color(0xFFFFFFFF),
      opacityPercent: 100,
      textColor: Color(0xFF111111),
      accentColor: Color(0xFFC62828),
    ),
  ),
  ThemePreset(
    'Glass',
    WidgetAppearance(
      cardColor: Color(0xFF000000),
      opacityPercent: 40,
      textColor: Color(0xFFFFFFFF),
      accentColor: Color(0xFFFFD54F),
    ),
  ),
];
