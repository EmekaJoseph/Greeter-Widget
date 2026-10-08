import 'package:home_widget/home_widget.dart';

import 'widget_store.dart';

/// An event the widget counts down to, e.g. "Lagos trip" on 12 Dec.
class Countdown {
  const Countdown({required this.name, required this.date});

  final String name;

  /// The event's day; the time of day is ignored.
  final DateTime date;

  static const maxNameLength = 30;

  static Future<Countdown?> load() async {
    final name = await HomeWidget.getWidgetData<String>(
      WidgetKeys.countdownName,
    );
    final date = await HomeWidget.getWidgetData<String>(
      WidgetKeys.countdownDate,
    );
    if (name == null || name.isEmpty || date == null) return null;
    final parsed = DateTime.tryParse(date);
    return parsed == null ? null : Countdown(name: name, date: parsed);
  }

  Future<void> save() async {
    await HomeWidget.saveWidgetData<String>(WidgetKeys.countdownName, name);
    await HomeWidget.saveWidgetData<String>(
      WidgetKeys.countdownDate,
      dateKey(date),
    );
  }

  static Future<void> clear() async {
    await HomeWidget.saveWidgetData<String>(WidgetKeys.countdownName, null);
    await HomeWidget.saveWidgetData<String>(WidgetKeys.countdownDate, null);
  }
}

/// yyyy-mm-dd, the format GreeterWidget.kt reads.
String dateKey(DateTime date) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)}';
}

/// Whole days from today to [event]. Days start at 5:00 like the greeting, so
/// the count ticks down with the morning update. Must match GreeterWidget.kt.
int daysUntil(DateTime event, DateTime now) {
  final today = focusDate(now);
  final from = DateTime.utc(today.year, today.month, today.day);
  final to = DateTime.utc(event.year, event.month, event.day);
  return to.difference(from).inDays;
}

/// "12 days to go", "Tomorrow" or "Today!"; null once the day has passed.
/// Must match GreeterWidget.kt.
String? countdownStatus(DateTime event, DateTime now) {
  final days = daysUntil(event, now);
  if (days < 0) return null;
  if (days == 0) return 'Today!';
  if (days == 1) return 'Tomorrow';
  return '$days days to go';
}
