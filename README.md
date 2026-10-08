# GREETER

An Android home screen widget that greets you by name. It shows a greeting for the time of day, a short motivational quote, today's date, and optionally your focus for the day and a countdown to an upcoming event. Greetings come in Nigerian Pidgin or English.

Built with Flutter. The widget itself is drawn natively in Kotlin, so it keeps updating even when the app isn't open.

## Features

### The widget
- **Time-of-day greetings.** The greeting changes for morning (from 5:00), afternoon (from 12:00) and evening (from 17:00). One is picked from a list for each part of the day and stays the same until the next one.
- **Pidgin or English.** For example, *"How body this morning,"* or *"Rise and shine,"*. Pidgin is the default.
- **Quotes.** About 50 short motivational quotes, mostly in Pidgin. A new one appears with each part of the day. Tap the quote on the widget to see another.
- **Your own quotes.** Add your own lines, like a Bible verse, a family saying or a goal, in **My quotes**. They're mixed in with the built-in quotes, or you can choose to show only yours.
- **Special days.** Your birthday, New Year's Day (1 Jan), Independence Day (1 Oct) and Christmas (25 Dec) get their own greeting and quote. If your birthday falls on a holiday, the birthday greeting wins.
- **Today's focus (optional).** Write one thing you want to get done today. It resets every morning at 5:00. Tap the focus area on the widget to edit it in the app.
- **Countdown (optional).** Name an event and pick a date, e.g. *"Lagos trip · 12 days to go"*. It shows *Tomorrow* and *Today!* as the day gets close, and disappears once the day has passed.
- **Profile picture.** Choose a photo from your gallery to show in a circle next to your name.
- **Resizable.** The default size is 4×2 cells. You can resize it in both directions and the text adjusts to fit.

### Appearance
- **Theme presets:** Mint (default), Night, Sand, Ocean, Lavender, Paper and Glass.
- **Custom colors:** background, background opacity, text, and accent (used for the quote and labels), all set with a full color picker.
- **Automatic night theme:** switch to the Night look from 19:00 until 5:00.
- **Gradient border:** a thin shiny edge in Gold, Silver, Rainbow, or two custom colors, with adjustable width.
- **Outfit font** on both the widget and the app.

### The app
- Asks for your name on first launch.
- Shows a live preview of the widget that updates as you change settings.
- **Share quote** turns the current quote into an image card (1080 px wide, 4:5) in your theme's colors and opens the share sheet, ready for WhatsApp, Instagram and so on.
- **Add widget to home screen** puts the widget on your home screen from inside the app, on launchers that support it.

## Getting started

### Requirements
- Flutter 3.44 or later (Dart 3.12)
- Android SDK and JDK 17+ (the copies bundled with Android Studio work)
- An Android phone or emulator

### Run in debug mode
```sh
flutter pub get
flutter run
```

Then long-press your home screen, open **Widgets**, and add **GREETER**. You can also use the **Add widget to home screen** button in the app.

### Run the tests
```sh
flutter analyze
flutter test
```

## Building a release APK

Release builds are signed with the keystore described in `android/key.properties`. That file holds the passwords, so it's git-ignored and you have to create it on each machine:

```properties
storePassword=<store password>
keyPassword=<key password>
keyAlias=greeter
storeFile=C:/Users/<you>/keys/greeter-release.jks
```

Then build:

```sh
flutter build apk --release
```

The APK is saved to `build/app/outputs/flutter-apk/app-release.apk`. To get smaller APKs, one per phone processor type, run:

```sh
flutter build apk --release --split-per-abi
```

If `key.properties` is missing, the release build falls back to the debug key. That's fine for testing, but those APKs can't be installed over a release-signed copy.

> **Keep the keystore and its passwords safe.** Every update to the app has to be signed with the same key. If you lose it, you can't publish updates under the same app ID (`com.proffictech.greeter`).

## Project structure

```
lib/
  main.dart           App UI: setup, home page with live preview, settings
  widget_store.dart   Shared storage keys, day-part timing, themes and colors
  greetings.dart      Greeting lists (Pidgin and English)
  quotes.dart         Built-in quotes and storage for the user's own
  my_quotes.dart      "My quotes" page
  special_days.dart   Birthday and holiday greetings
  countdown.dart      Countdown event storage and "days to go" logic
  card_border.dart    Gradient border styles and painter
  avatar.dart         Profile picture picking and storage
  share_card.dart     "Share quote" image card
android/app/src/main/
  kotlin/com/proffictech/greeter/GreeterWidget.kt   Native widget renderer
  res/layout/greeter_widget.xml                     Widget layout
  res/xml/greeter_widget_info.xml                   Widget size and update settings
assets/fonts/         Outfit font (SIL Open Font License, see OFL.txt)
tool/make_icon.py     Generates the PNG launcher icons for Android 7 and older
test/                 Unit and widget tests
```

### How the app and widget work together
The Flutter app saves your settings, the greetings, the quotes and the special days into shared storage using [`home_widget`](https://pub.dev/packages/home_widget). The Kotlin widget reads them and draws the card. Because the widget does this work itself, it changes greetings on time without the app running. The app also schedules updates for the next two weeks of greeting changes.

Some logic is written twice, once in Dart for the in-app preview and once in Kotlin for the widget: the day-part hours, quote selection, date formats and countdown maths. Comments marked **"Must match GreeterWidget.kt"** point out these places. If you change one side, change the other.

### Editing content
- **Greetings:** edit `lib/greetings.dart`. End each one with a comma, because the name follows on the next line.
- **Quotes:** edit `lib/quotes.dart`. Keep each quote under about 110 characters or it gets cut off on the widget.
- **Holidays:** edit the `holidays` list in `lib/special_days.dart`.

## Built with
- [Flutter](https://flutter.dev)
- [home_widget](https://pub.dev/packages/home_widget): shares data with the Android widget
- [flex_color_picker](https://pub.dev/packages/flex_color_picker): color selection
- [image_picker](https://pub.dev/packages/image_picker) and [path_provider](https://pub.dev/packages/path_provider): profile picture
- [share_plus](https://pub.dev/packages/share_plus): sharing quote cards
- [Outfit](https://fonts.google.com/specimen/Outfit) font
