package com.proffictech.greeter

import android.Manifest
import android.app.NotificationManager
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar

class MainActivity : FlutterActivity() {
    /** Replies waiting on a permission dialog, by request code. */
    private val pendingPermissions = HashMap<Int, MethodChannel.Result>()

    // Channel and method names must match lib/morning_notification.dart and lib/special_days.dart.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "greeter/notifications")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestPermission" -> requestPermission(result)
                    "reschedule" -> {
                        MorningNotification.reschedule(this)
                        result.success(null)
                    }
                    "openSettings" -> {
                        startActivity(
                            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName),
                        )
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "greeter/calendar")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "requestPermission" -> {
                        if (CalendarHolidays.hasPermission(this)) {
                            result.success(true)
                        } else {
                            askFor(Manifest.permission.READ_CALENDAR, CALENDAR_REQUEST, result)
                        }
                    }
                    // A day starts at 5:00, like the greeting; see focusDate() in GreeterWidget.kt.
                    "holidayToday" -> result.success(
                        CalendarHolidays.titleOn(
                            this,
                            Calendar.getInstance().apply { add(Calendar.HOUR_OF_DAY, -5) },
                        ),
                    )
                    else -> result.notImplemented()
                }
            }
    }

    private fun askFor(permission: String, requestCode: Int, result: MethodChannel.Result) {
        pendingPermissions.remove(requestCode)?.success(false)
        pendingPermissions[requestCode] = result
        requestPermissions(arrayOf(permission), requestCode)
    }

    /** Replies true once notifications are allowed, asking on Android 13+ if needed. */
    private fun requestPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
        ) {
            result.success(notificationsEnabled())
            return
        }
        askFor(Manifest.permission.POST_NOTIFICATIONS, NOTIFICATION_REQUEST, result)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        val result = pendingPermissions.remove(requestCode) ?: return
        val granted = grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED
        result.success(if (requestCode == NOTIFICATION_REQUEST) granted && notificationsEnabled() else granted)
    }

    /** False when the user has blocked GREETER's notifications in system settings. */
    private fun notificationsEnabled(): Boolean =
        getSystemService(NotificationManager::class.java).areNotificationsEnabled()

    private companion object {
        const val NOTIFICATION_REQUEST = 7101
        const val CALENDAR_REQUEST = 7102
    }
}
