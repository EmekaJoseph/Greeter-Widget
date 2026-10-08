import 'dart:convert';

import 'package:home_widget/home_widget.dart';

import 'widget_store.dart';

/// Greetings shown above the name, one list per morning, afternoon and
/// evening. One is picked at random each part of the day. They're handed to the
/// widget by [saveGreetingsForWidget], so this is the only place to edit them.
/// Each ends with a comma because the name follows on the next line.
const Map<GreetingStyle, List<List<String>>> greetings = {
  GreetingStyle.pidgin: [
    [
      'Good morning o,',
      'How body this morning,',
      'E don dawn o,',
      'Rise and shine o,',
    ],
    [
      'How your afternoon dey,',
      'Good afternoon o,',
      'How today dey go,',
      'How far this afternoon,',
    ],
    [
      'Good evening o,',
      'How your day go,',
      'How today take go,',
      'Thank God for today,',
    ],
  ],
  GreetingStyle.english: [
    [
      'Good morning,',
      'Morning,',
      'Rise and shine,',
      'Hello, early bird,',
      'Top of the morning,',
      'Fresh start today,',
    ],
    [
      'Good afternoon,',
      'Afternoon,',
      'Hello there,',
      "Hope your day's going well,",
      'Keep it going,',
      'Halfway there,',
    ],
    [
      'Good evening,',
      'Evening,',
      'Hope you had a good day,',
      'Time to unwind,',
      'Well done today,',
    ],
  ],
};

/// Keeps the greeting from following the quote: both are picked from the same
/// slot, so the greeting uses a fixed offset. Must match GreeterWidget.kt.
const int greetingSeed = 7919;

/// The greeting for [time]. It stays the same for the whole morning, afternoon
/// or evening. Must match GreeterWidget.kt.
String greetingLine(DateTime time, GreetingStyle style) {
  final options = greetings[style]![periodOf(time)];
  return options[quoteIndex(quoteSlot(time), greetingSeed, options.length)];
}

/// Stored as {"pidgin": [[morning...], [afternoon...], [evening...]], ...}.
Future<void> saveGreetingsForWidget() {
  return HomeWidget.saveWidgetData<String>(
    WidgetKeys.greetings,
    jsonEncode({
      for (final entry in greetings.entries) entry.key.storedValue: entry.value,
    }),
  );
}
