import 'dart:convert';

import 'package:home_widget/home_widget.dart';

import 'widget_store.dart';

/// A day with its own greeting and quote. They're handed to the widget by
/// [saveSpecialDaysForWidget], so this is the only place to edit them.
class SpecialDay {
  const SpecialDay({
    required this.monthDay,
    required this.pidgin,
    required this.english,
    required this.quote,
  });

  /// "MM-dd", e.g. "12-25".
  final String monthDay;

  /// Greetings end with a comma because the name follows on the next line.
  final String pidgin;
  final String english;
  final String quote;

  String greeting(GreetingStyle style) =>
      style == GreetingStyle.pidgin ? pidgin : english;

  Map<String, String> toJson() => {
    'date': monthDay,
    'pidgin': pidgin,
    'english': english,
    'quote': quote,
  };
}

const List<SpecialDay> holidays = [
  SpecialDay(
    monthDay: '01-01',
    pidgin: 'Happy New Year o,',
    english: 'Happy New Year,',
    quote: 'New year, new chance. This year go better pass last year.',
  ),
  SpecialDay(
    monthDay: '10-01',
    pidgin: 'Happy Independence Day o,',
    english: 'Happy Independence Day,',
    quote: 'Naija go better. Na we go build am, one step at a time.',
  ),
  SpecialDay(
    monthDay: '12-25',
    pidgin: 'Merry Christmas o,',
    english: 'Merry Christmas,',
    quote: 'Make love, peace and joy full your house this Christmas.',
  ),
];

SpecialDay birthdayOn(String monthDay) => SpecialDay(
  monthDay: monthDay,
  pidgin: 'Happy birthday o,',
  english: 'Happy birthday,',
  quote: 'Another year don land. God go continue to bless you!',
);

/// The birthday comes first, so it wins if it falls on a holiday.
List<SpecialDay> specialDays(String? birthday) => [
  if (birthday != null) birthdayOn(birthday),
  ...holidays,
];

/// Special days start at 5:00 like the greeting, not at midnight.
/// Must match GreeterWidget.kt.
String monthDayKey(DateTime date) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(date.month)}-${two(date.day)}';
}

/// "MM-dd" as "14 March".
String longMonthDay(String monthDay) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  final month = int.parse(monthDay.substring(0, 2));
  final day = int.parse(monthDay.substring(3));
  return '$day ${months[month - 1]}';
}

SpecialDay? specialDayFor(DateTime now, String? birthday) {
  final today = monthDayKey(focusDate(now));
  for (final day in specialDays(birthday)) {
    if (day.monthDay == today) return day;
  }
  return null;
}

Future<void> saveSpecialDaysForWidget(String? birthday) {
  return HomeWidget.saveWidgetData<String>(
    WidgetKeys.specialDays,
    jsonEncode([for (final day in specialDays(birthday)) day.toJson()]),
  );
}
