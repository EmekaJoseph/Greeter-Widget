import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

import 'widget_store.dart';

/// A day with its own greeting and quote. They're handed to the widget by
/// [saveSpecialDaysForWidget], so this is the only place to edit them.
class SpecialDay {
  const SpecialDay({
    required this.date,
    required this.pidgin,
    required this.english,
    required this.quote,
  });

  /// "MM-dd", e.g. "12-25". For [calendarGreetings], the name to look for.
  final String date;

  /// Greetings end with a comma because the name follows on the next line.
  final String pidgin;
  final String english;
  final String quote;

  String greeting(GreetingStyle style) =>
      style == GreetingStyle.pidgin ? pidgin : english;

  Map<String, String> toJson() => {
    'date': date,
    'pidgin': pidgin,
    'english': english,
    'quote': quote,
  };
}

/// Days that fall on the same date every year, in date order.
const List<SpecialDay> holidays = [
  SpecialDay(
    date: '01-01',
    pidgin: 'Happy New Year o,',
    english: 'Happy New Year,',
    quote: 'New year, new chance. This year go better pass last year.',
  ),
  SpecialDay(
    date: '02-14',
    pidgin: 'Happy Val o,',
    english: "Happy Valentine's Day,",
    quote: 'Love na beautiful thing. Show am to the people wey matter to you.',
  ),
  SpecialDay(
    date: '05-01',
    pidgin: "Happy Workers' Day o,",
    english: "Happy Workers' Day,",
    quote: 'Your hard work dey count. Rest small today, you don try.',
  ),
  SpecialDay(
    date: '05-27',
    pidgin: "Happy Children's Day o,",
    english: "Happy Children's Day,",
    quote: 'Every adult na child before. No forget the child inside you.',
  ),
  SpecialDay(
    date: '06-12',
    pidgin: 'Happy Democracy Day o,',
    english: 'Happy Democracy Day,',
    quote: 'Our voice na our power. Make we use am well for Naija.',
  ),
  SpecialDay(
    date: '10-01',
    pidgin: 'Happy Independence Day o,',
    english: 'Happy Independence Day,',
    quote: 'Naija go better. Na we go build am, one step at a time.',
  ),
  SpecialDay(
    date: '12-25',
    pidgin: 'Merry Christmas o,',
    english: 'Merry Christmas,',
    quote: 'Make love, peace and joy full your house this Christmas.',
  ),
  SpecialDay(
    date: '12-26',
    pidgin: 'Happy Boxing Day o,',
    english: 'Happy Boxing Day,',
    quote: 'Christmas never finish! Enjoy am with family and friends.',
  ),
  SpecialDay(
    date: '12-31',
    pidgin: 'Last day of the year o,',
    english: "Happy New Year's Eve,",
    quote: 'Thank God for this year. The new one go better.',
  ),
];

/// Days read from the user's calendar, since their dates move each year. A
/// holiday whose name contains [SpecialDay.date] gets that greeting and quote;
/// earlier entries are checked first. Must match GreeterWidget.kt.
const List<SpecialDay> calendarGreetings = [
  SpecialDay(
    date: 'ash wednesday',
    pidgin: 'Blessed Ash Wednesday o,',
    english: 'Blessed Ash Wednesday,',
    quote: 'Lent don start. Make this season draw you closer to God.',
  ),
  SpecialDay(
    date: 'ramadan',
    pidgin: 'Ramadan Kareem o,',
    english: 'Ramadan Kareem,',
    quote: 'Make this Ramadan bring you peace, patience and plenty blessings.',
  ),
  SpecialDay(
    date: 'fitr',
    pidgin: 'Eid Mubarak o,',
    english: 'Eid Mubarak,',
    quote:
        'Make Allah accept your prayers and bless your house. Barka da Sallah!',
  ),
  SpecialDay(
    date: 'kabir',
    pidgin: 'Eid Mubarak o,',
    english: 'Eid Mubarak,',
    quote:
        'Make Allah accept your sacrifice and bless your house. Barka da Sallah!',
  ),
  SpecialDay(
    date: 'adha',
    pidgin: 'Eid Mubarak o,',
    english: 'Eid Mubarak,',
    quote:
        'Make Allah accept your sacrifice and bless your house. Barka da Sallah!',
  ),
  SpecialDay(
    date: 'holy saturday',
    pidgin: 'Blessed Holy Saturday o,',
    english: 'Blessed Holy Saturday,',
    quote: 'Hold on small. Sunday dey come!',
  ),
  SpecialDay(
    date: 'good friday',
    pidgin: 'Blessed Good Friday o,',
    english: 'Blessed Good Friday,',
    quote: 'Na love make Jesus carry that cross. Remember am today.',
  ),
  SpecialDay(
    date: 'easter monday',
    pidgin: 'Happy Easter Monday o,',
    english: 'Happy Easter Monday,',
    quote: 'Easter still dey! Rest well and enjoy am with your people.',
  ),
  SpecialDay(
    date: 'easter',
    pidgin: 'Happy Easter o,',
    english: 'Happy Easter,',
    quote: 'He don rise! Make new life and new hope full your house.',
  ),
  SpecialDay(
    date: 'mother',
    pidgin: 'Happy Mothering Sunday o,',
    english: 'Happy Mothering Sunday,',
    quote: 'Celebrate the mothers wey carry us. Call your mama today!',
  ),
  SpecialDay(
    date: 'father',
    pidgin: "Happy Father's Day o,",
    english: "Happy Father's Day,",
    quote: 'Celebrate the fathers wey dey stand for us. Call your papa today!',
  ),
];

SpecialDay birthdayOn(String monthDay) => SpecialDay(
  date: monthDay,
  pidgin: 'Happy birthday o,',
  english: 'Happy birthday,',
  quote: 'Another year don land. God go continue to bless you!',
);

/// The birthday comes first, so it wins if it falls on a holiday.
List<SpecialDay> specialDays(String? birthday) => [
  if (birthday != null) birthdayOn(birthday),
  ...holidays,
];

/// Shown with a holiday from the user's calendar. Must match GreeterWidget.kt.
const String calendarHolidayQuote =
    'Enjoy today well well, and remember the people wey you love.';

/// A holiday found in the user's calendar, e.g. "Eid al-Fitr (tentative)".
/// Must match calendarHoliday() in GreeterWidget.kt.
SpecialDay calendarHoliday(String title) {
  final name = title.replaceAll(RegExp(r'\s*\(.*?\)'), '').trim();
  final lower = name.toLowerCase();
  for (final day in calendarGreetings) {
    if (lower.contains(day.date)) return day;
  }
  final happy = name.toLowerCase().startsWith('happy ') ? name : 'Happy $name';
  return SpecialDay(
    date: '',
    pidgin: '$happy o,',
    english: '$happy,',
    quote: calendarHolidayQuote,
  );
}

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

/// Today's special day, if any. Built-in days win over [calendarTitle], the
/// title of a holiday in the user's calendar today. Must match GreeterWidget.kt.
SpecialDay? specialDayFor(
  DateTime now,
  String? birthday, {
  String? calendarTitle,
}) {
  final today = monthDayKey(focusDate(now));
  for (final day in specialDays(birthday)) {
    if (day.date == today) return day;
  }
  return calendarTitle == null ? null : calendarHoliday(calendarTitle);
}

Future<void> saveSpecialDaysForWidget(String? birthday) {
  return HomeWidget.saveWidgetData<String>(
    WidgetKeys.specialDays,
    jsonEncode([for (final day in specialDays(birthday)) day.toJson()]),
  );
}

Future<void> saveCalendarGreetingsForWidget() {
  return HomeWidget.saveWidgetData<String>(
    WidgetKeys.calendarGreetings,
    jsonEncode([for (final day in calendarGreetings) day.toJson()]),
  );
}

/// Talks to MainActivity.kt. The widget reads the calendar itself, in
/// CalendarHolidays.kt.
const _calendar = MethodChannel('greeter/calendar');

/// Asks for calendar access if needed. False if the user said no.
Future<bool> requestCalendarPermission() async =>
    await _calendar.invokeMethod<bool>('requestPermission') ?? false;

/// The title of a holiday in the user's calendar today, if any.
Future<String?> calendarHolidayToday() =>
    _calendar.invokeMethod<String>('holidayToday');
