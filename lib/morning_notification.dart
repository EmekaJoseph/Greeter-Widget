import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:home_widget/home_widget.dart';

import 'widget_store.dart';

/// Talks to MainActivity.kt; the notification itself is built in
/// MorningNotification.kt from the widget's data.
const _channel = MethodChannel('greeter/notifications');

/// The daily greeting notification: whether it's on, and when it arrives.
class NotificationSettings {
  const NotificationSettings({this.on = false, this.time = defaultTime});

  /// Defaults must match MorningNotification.kt.
  static const defaultTime = TimeOfDay(hour: 7, minute: 0);

  final bool on;
  final TimeOfDay time;

  NotificationSettings copyWith({bool? on, TimeOfDay? time}) =>
      NotificationSettings(on: on ?? this.on, time: time ?? this.time);

  static Future<NotificationSettings> load() async {
    final on = await HomeWidget.getWidgetData<bool>(WidgetKeys.notifyOn);
    final minutes = await HomeWidget.getWidgetData<int>(
      WidgetKeys.notifyMinutes,
    );
    return NotificationSettings(
      on: on ?? false,
      time: minutes == null
          ? defaultTime
          : TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
  }

  /// Saves these settings and sets or cancels the daily alarm to match.
  Future<void> save() async {
    await HomeWidget.saveWidgetData<bool>(WidgetKeys.notifyOn, on);
    await HomeWidget.saveWidgetData<int>(
      WidgetKeys.notifyMinutes,
      time.hour * 60 + time.minute,
    );
    await rescheduleNotification();
  }
}

/// Asks for permission to notify if needed. False if the user said no or has
/// turned GREETER's notifications off in system settings.
Future<bool> requestNotificationPermission() async =>
    await _channel.invokeMethod<bool>('requestPermission') ?? false;

/// Sets the next alarm from the saved settings. Alarms are cleared when the app
/// is force-stopped, so this also runs each time the app opens.
Future<void> rescheduleNotification() => _channel.invokeMethod('reschedule');

Future<void> openNotificationSettings() =>
    _channel.invokeMethod('openSettings');
