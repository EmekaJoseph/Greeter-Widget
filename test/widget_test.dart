import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phone_widget/main.dart';
import 'package:phone_widget/card_border.dart';
import 'package:phone_widget/countdown.dart';
import 'package:phone_widget/greetings.dart';
import 'package:phone_widget/quotes.dart';
import 'package:phone_widget/share_card.dart';
import 'package:phone_widget/special_days.dart';
import 'package:phone_widget/widget_store.dart';

void main() {
  test('greeting follows the time of day', () {
    expect(greetingFor(DateTime(2026, 1, 1, 4, 59)), 'Good evening');
    expect(greetingFor(DateTime(2026, 1, 1, 5)), 'Good morning');
    expect(greetingFor(DateTime(2026, 1, 1, 11, 59)), 'Good morning');
    expect(greetingFor(DateTime(2026, 1, 1, 12)), 'Good afternoon');
    expect(greetingFor(DateTime(2026, 1, 1, 17)), 'Good evening');
  });

  test('greeting comes from the right list for the time of day', () {
    for (final style in GreetingStyle.values) {
      for (var day = 1; day <= 20; day++) {
        final morning = DateTime(2026, 1, day, 8);
        final afternoon = DateTime(2026, 1, day, 14);
        final night = DateTime(2026, 1, day, 23);
        expect(greetings[style]![0], contains(greetingLine(morning, style)));
        expect(greetings[style]![1], contains(greetingLine(afternoon, style)));
        expect(greetings[style]![2], contains(greetingLine(night, style)));
      }
    }
    expect(GreetingStyle.fromStored(null), GreetingStyle.pidgin);
    expect(GreetingStyle.fromStored('english'), GreetingStyle.english);
  });

  test('greeting holds for a whole part of the day but varies across days', () {
    const style = GreetingStyle.pidgin;
    expect(
      greetingLine(DateTime(2026, 3, 3, 5), style),
      greetingLine(DateTime(2026, 3, 3, 11, 59), style),
    );
    final mornings = {
      for (var day = 1; day <= 20; day++)
        greetingLine(DateTime(2026, 3, day, 8), style),
    };
    expect(mornings.length, greaterThan(1));
  });

  test('every greeting ends with a comma', () {
    for (final lists in greetings.values) {
      for (final list in lists) {
        expect(list, isNotEmpty);
        for (final greeting in list) {
          expect(greeting, endsWith(','));
        }
      }
    }
  });

  testWidgets('share card shows the quote', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 320,
            child: ShareQuoteCard(
              quote: 'Little by little, one travels far.',
              look: WidgetAppearance.defaults,
            ),
          ),
        ),
      ),
    );
    expect(find.text('Little by little, one travels far.'), findsOneWidget);
    expect(find.text('GREETER'), findsNothing);
  });

  test('focus day starts at 5:00, not midnight', () {
    expect(focusDayKey(DateTime(2026, 10, 8, 4, 59)), '2026-10-07');
    expect(focusDayKey(DateTime(2026, 10, 8, 5)), '2026-10-08');
    expect(focusDayKey(DateTime(2026, 1, 1, 2)), '2025-12-31');
    expect(shortDate(DateTime(2026, 10, 8, 9)), 'Thu, 8 Oct');
    expect(shortDate(DateTime(2026, 10, 8, 3)), 'Wed, 7 Oct');
  });

  test('special days: holidays, birthday first, starting at 5:00', () {
    expect(
      specialDayFor(DateTime(2026, 12, 25, 9), null)?.pidgin,
      'Merry Christmas o,',
    );
    expect(specialDayFor(DateTime(2026, 12, 26, 4), null)?.monthDay, '12-25');
    expect(specialDayFor(DateTime(2026, 12, 25, 4), null), isNull);
    expect(specialDayFor(DateTime(2026, 3, 14, 9), null), isNull);
    expect(
      specialDayFor(DateTime(2026, 3, 14, 9), '03-14')?.pidgin,
      'Happy birthday o,',
    );
    expect(
      specialDayFor(DateTime(2026, 12, 25, 9), '12-25')?.english,
      'Happy birthday,',
    );
    expect(longMonthDay('03-14'), '14 March');
    expect(monthDayKey(DateTime(2026, 1, 5)), '01-05');
  });

  test('night theme applies from 19:00 to 5:00 only when switched on', () {
    const chosen = WidgetAppearance.defaults;
    final evening = DateTime(2026, 5, 5, 20);
    final lateNight = DateTime(2026, 5, 5, 3);
    final afternoon = DateTime(2026, 5, 5, 15);
    expect(effectiveLook(chosen, evening, autoNight: true), nightLook);
    expect(effectiveLook(chosen, lateNight, autoNight: true), nightLook);
    expect(effectiveLook(chosen, afternoon, autoNight: true), chosen);
    expect(effectiveLook(chosen, evening, autoNight: false), chosen);
  });

  test('countdown counts whole days, with days starting at 5:00', () {
    final trip = DateTime(2026, 12, 12);
    expect(countdownStatus(trip, DateTime(2026, 11, 30, 9)), '12 days to go');
    expect(countdownStatus(trip, DateTime(2026, 12, 11, 9)), 'Tomorrow');
    expect(countdownStatus(trip, DateTime(2026, 12, 12, 9)), 'Today!');
    // Before 5:00 it's still the previous day.
    expect(countdownStatus(trip, DateTime(2026, 12, 12, 4)), 'Tomorrow');
    expect(countdownStatus(trip, DateTime(2026, 12, 13, 9)), isNull);
    // Across a year boundary.
    expect(
      countdownStatus(DateTime(2027, 1, 2), DateTime(2026, 12, 31, 12)),
      '2 days to go',
    );
    expect(dateKey(DateTime(2026, 3, 4)), '2026-03-04');
  });

  testWidgets('card shows the countdown until the day passes', (tester) async {
    Widget card(DateTime date) => MaterialApp(
      home: GreeterCard(
        name: 'Emeka',
        quote: null,
        focus: '',
        look: WidgetAppearance.defaults,
        countdown: Countdown(name: 'Lagos trip', date: date),
      ),
    );
    final today = focusDate(DateTime.now());

    await tester.pumpWidget(card(today.add(const Duration(days: 1))));
    expect(find.text('Lagos trip'), findsOneWidget);
    expect(find.text('Tomorrow'), findsOneWidget);

    await tester.pumpWidget(card(today.subtract(const Duration(days: 1))));
    expect(find.text('Lagos trip'), findsNothing);
  });

  test('gradient border is off by default and builds each style', () {
    const border = CardBorder.defaults;
    expect(border.enabled, isFalse);
    const accent = Color(0xFF1E7A5A);
    for (final style in BorderStyleOption.values) {
      final colors = border.copyWith(style: style).colors(accent);
      expect(colors.length, greaterThanOrEqualTo(2), reason: style.label);
    }
    expect(border.copyWith(style: BorderStyleOption.accent).colors(accent), [
      accent,
      shine(accent),
      accent,
    ]);
    final custom = border
        .copyWith(
          style: BorderStyleOption.custom,
          customStart: const Color(0xFF000000),
          customEnd: const Color(0xFF0000FF),
        )
        .colors(accent);
    expect(custom.first, const Color(0xFF000000));
    expect(custom.last, const Color(0xFF0000FF));
    // 60% of the way to white, as GreeterWidget.kt computes it.
    expect(colorToRgb(shine(const Color(0xFF000000))), 0x999999);
  });

  test('schedules only future greeting changes', () {
    final now = DateTime(2026, 1, 1, 13);
    final times = upcomingGreetingChanges(now);
    expect(times.first, DateTime(2026, 1, 1, 17));
    expect(times.every((t) => t.isAfter(now)), isTrue);
  });

  test('quote stays the same within a part of the day', () {
    expect(
      quoteSlot(DateTime(2026, 3, 2, 18)),
      quoteSlot(DateTime(2026, 3, 3, 4, 59)),
    );
    expect(
      quoteSlot(DateTime(2026, 3, 3, 5)),
      quoteSlot(DateTime(2026, 3, 3, 11, 59)),
    );
    expect(
      quoteSlot(DateTime(2026, 3, 3, 12)),
      isNot(quoteSlot(DateTime(2026, 3, 3, 11, 59))),
    );
  });

  test('quote index is in range and changes with shuffle', () {
    final slot = quoteSlot(DateTime(2026, 3, 3, 9));
    for (var shuffle = 0; shuffle < 50; shuffle++) {
      final index = quoteIndex(slot, shuffle, 15);
      expect(index, inInclusiveRange(0, 14));
    }
    expect(quoteIndex(slot, 0, 15), isNot(quoteIndex(slot, 1, 15)));
  });

  test('every quote is short enough for the widget', () {
    expect(quotes, isNotEmpty);
    for (final quote in quotes) {
      expect(quote.trim(), isNotEmpty);
      expect(quote.length, lessThanOrEqualTo(110), reason: quote);
    }
  });

  test('theme presets are distinct and Mint is the default look', () {
    expect(themePresets.first.look.looksLike(WidgetAppearance.defaults), true);
    for (var i = 0; i < themePresets.length; i++) {
      for (var j = i + 1; j < themePresets.length; j++) {
        expect(
          themePresets[i].look.looksLike(themePresets[j].look),
          isFalse,
          reason: '${themePresets[i].name} vs ${themePresets[j].name}',
        );
      }
    }
  });

  test('colors round-trip through 32-bit-safe storage', () {
    for (final color in [
      ...cardColorChoices,
      ...textColorChoices,
      ...accentColorChoices,
    ]) {
      final rgb = colorToRgb(color);
      expect(rgb, lessThanOrEqualTo(0xFFFFFF));
      expect(rgbToColor(rgb), color);
    }
  });

  testWidgets('setup submits the entered name', (tester) async {
    String? saved;
    await tester.pumpWidget(
      MaterialApp(home: SetupPage(onDone: (name) async => saved = name)),
    );

    await tester.enterText(find.byType(TextField), '  Emeka  ');
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(saved, 'Emeka');
  });

  testWidgets('card prompts for a focus, shows it, or hides the section', (
    tester,
  ) async {
    Widget card(String focus, {bool show = true}) => MaterialApp(
      home: GreeterCard(
        name: 'Emeka',
        quote: 'Small steps every day add up to big results.',
        focus: focus,
        showFocus: show,
        look: WidgetAppearance.defaults,
      ),
    );

    await tester.pumpWidget(card(''));
    expect(find.text(focusLabel), findsOneWidget);
    expect(find.text(focusPrompt), findsOneWidget);

    await tester.pumpWidget(card('Ship iOS build of the EMR app'));
    expect(find.text('Ship iOS build of the EMR app'), findsOneWidget);
    expect(find.text(focusPrompt), findsNothing);

    await tester.pumpWidget(card('Anything', show: false));
    expect(find.text(focusLabel), findsNothing);
  });
}
