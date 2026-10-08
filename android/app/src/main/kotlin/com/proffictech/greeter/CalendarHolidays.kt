package com.proffictech.greeter

import android.Manifest
import android.content.ContentUris
import android.content.Context
import android.content.pm.PackageManager
import android.provider.CalendarContract
import android.util.Log
import java.util.Calendar
import java.util.TimeZone

/**
 * Reads public holidays from the phone's calendars, such as Google's "Holidays in Nigeria", so
 * days whose dates move each year (Easter, Eid, ...) arrive on the right day.
 */
object CalendarHolidays {
    private const val TAG = "CalendarHolidays"

    /** Holiday calendars are owned by e.g. "en.ng#holiday@group.v.calendar.google.com" (Google) or "ng.en_us#holiday@calendar.transsion.com" (TECNO, Infinix, itel). */
    private const val SELECTION =
        "${CalendarContract.Instances.ALL_DAY} = 1 AND (" +
            "${CalendarContract.Instances.OWNER_ACCOUNT} LIKE '%#holiday@%' OR " +
            "${CalendarContract.Instances.CALENDAR_DISPLAY_NAME} LIKE 'Holidays%')"

    fun hasPermission(context: Context): Boolean =
        context.checkSelfPermission(Manifest.permission.READ_CALENDAR) == PackageManager.PERMISSION_GRANTED

    /** The title of a holiday on [day] (only its date is used), or null if there's none. */
    fun titleOn(context: Context, day: Calendar): String? {
        if (!hasPermission(context)) return null
        // All-day events start at midnight UTC on their date.
        val start = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply {
            clear()
            set(day.get(Calendar.YEAR), day.get(Calendar.MONTH), day.get(Calendar.DAY_OF_MONTH))
        }.timeInMillis
        val uri = CalendarContract.Instances.CONTENT_URI.buildUpon().also {
            ContentUris.appendId(it, start)
            ContentUris.appendId(it, start + DAY_MS - 1)
        }.build()
        return try {
            context.contentResolver.query(
                uri,
                arrayOf(CalendarContract.Instances.TITLE, CalendarContract.Instances.BEGIN),
                SELECTION,
                null,
                "${CalendarContract.Instances.TITLE} ASC",
            )?.use { cursor ->
                while (cursor.moveToNext()) {
                    // The range also catches the day before, which ends at our midnight.
                    val title = cursor.getString(0)
                    if (cursor.getLong(1) == start && !title.isNullOrBlank()) return@use title
                }
                null
            }
        } catch (e: SecurityException) {
            Log.w(TAG, "Calendar permission was revoked", e)
            null
        }
    }

    private const val DAY_MS = 86_400_000L
}
