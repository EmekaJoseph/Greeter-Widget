package com.proffictech.greeter

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import es.antonborri.home_widget.HomeWidgetPlugin
import java.util.Calendar

/**
 * The daily greeting notification. Its text is worked out when it fires, from the same data and
 * rules as the widget, so it always matches what the widget shows.
 *
 * Settings are saved by the app; see lib/morning_notification.dart.
 */
object MorningNotification {
    private const val CHANNEL_ID = "morning_greeting"
    private const val NOTIFICATION_ID = 1
    const val ACTION_SHOW = "com.proffictech.greeter.action.SHOW_MORNING_NOTIFICATION"

    // Defaults must match NotificationSettings in lib/morning_notification.dart.
    private const val DEFAULT_MINUTES = 7 * 60

    private fun isOn(context: Context): Boolean =
        HomeWidgetPlugin.getData(context).getBoolean("notifyOn", false)

    private fun minutesOfDay(context: Context): Int =
        HomeWidgetPlugin.getData(context).getInt("notifyMinutes", DEFAULT_MINUTES)

    /** Sets the alarm for the next notification, or cancels it when notifications are off. */
    fun reschedule(context: Context) {
        val alarms = context.getSystemService(AlarmManager::class.java)
        val pending = alarmIntent(context)
        if (!isOn(context)) {
            alarms.cancel(pending)
            return
        }
        val minutes = minutesOfDay(context)
        val next = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, minutes / 60)
            set(Calendar.MINUTE, minutes % 60)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            if (!after(Calendar.getInstance())) add(Calendar.DAY_OF_YEAR, 1)
        }
        // Inexact so no special alarm permission is needed; it may arrive a few minutes late.
        alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next.timeInMillis, pending)
    }

    fun show(context: Context) {
        val manager = context.getSystemService(NotificationManager::class.java)
        if (!manager.areNotificationsEnabled()) return
        val prefs = HomeWidgetPlugin.getData(context)
        val (title, quote) = GreeterWidget().greetingMessage(prefs, Calendar.getInstance()) ?: return

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "Morning greeting",
                    NotificationManager.IMPORTANCE_DEFAULT,
                ).apply { description = "Your greeting and quote for the day" },
            )
        }

        val open = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        builder
            .setSmallIcon(R.drawable.ic_launcher_monochrome)
            // Default must match WidgetAppearance.defaults in lib/widget_store.dart.
            .setColor(prefs.getInt("cardAccentColor", 0x1E7A5A) or 0xFF000000.toInt())
            .setContentTitle(title)
            .setContentIntent(open)
            .setAutoCancel(true)
        if (quote != null) {
            builder.setContentText(quote).setStyle(Notification.BigTextStyle().bigText(quote))
        }
        manager.notify(NOTIFICATION_ID, builder.build())
    }

    private fun alarmIntent(context: Context): PendingIntent = PendingIntent.getBroadcast(
        context,
        0,
        Intent(context, MorningNotificationReceiver::class.java).setAction(ACTION_SHOW),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
}

/** Shows the notification when its alarm goes off, and sets the alarm again after a reboot. */
class MorningNotificationReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == MorningNotification.ACTION_SHOW) MorningNotification.show(context)
        // Alarms are cleared on reboot and only fire once, so set the next one every time.
        MorningNotification.reschedule(context)
    }
}
