package com.proffictech.greeter

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
import android.media.ExifInterface
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.text.StaticLayout
import android.text.TextPaint
import android.text.TextUtils
import android.util.Log
import android.util.SizeF
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.TimeZone

class GreeterWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val now = Calendar.getInstance()
        val name = widgetData.getString("name", null)?.takeIf { it.isNotBlank() }
        // Default must match GreetingStyle in lib/widget_store.dart.
        val style = widgetData.getString("greetingStyle", null) ?: "pidgin"
        val special = specialDayFor(context, widgetData, now)
        val greeting = when {
            name == null -> "Open GREETER to set your name"
            special != null -> special.optString(style).ifBlank { special.optString("english") }
            else -> greetingFor(now, widgetData.getString("greetings", null), style)
        }
        val nameCaps = name?.uppercase()
        val quote = shownQuote(context, widgetData, now)?.let { "\"$it\"" }
        // Default must match defaultShowFocus in lib/widget_store.dart.
        val showFocus = widgetData.getBoolean("showFocus", false)
        val focus = widgetData.getString("focus", null)
            ?.takeIf { it.isNotBlank() && widgetData.getString("focusDay", null) == focusDayKey(now) }
        val date = shortDate(now)
        val countdownName = widgetData.getString("countdownName", null)?.takeIf { it.isNotBlank() }
        val countdown = countdownName?.let { eventName ->
            countdownStatus(widgetData.getString("countdownDate", null), now)?.let { eventName to it }
        }

        // Defaults must match WidgetAppearance.defaults in lib/widget_store.dart.
        val night = nightTheme(widgetData, now)
        fun look(key: String, default: Int) =
            if (night != null && night.has(key)) night.optInt(key) else widgetData.getInt(key, default)
        val cardColor = opaque(look("cardColor", 0xE3F4EE))
        val opacityPercent = look("cardOpacity", 100).coerceIn(0, 100)
        val textColor = opaque(look("cardTextColor", 0x0F2A24))
        val accentColor = opaque(look("cardAccentColor", 0x1E7A5A))
        val dividerColor = (textColor and 0x00FFFFFF) or 0x40000000

        val focusVisibility = if (showFocus) View.VISIBLE else View.GONE
        val fadedTextColor = (textColor and 0x00FFFFFF) or 0x99000000.toInt()
        val font = loadFont(context, OUTFIT_REGULAR)
        val nameFont = loadFont(context, OUTFIT_SEMIBOLD)

        val border = cardBorder(widgetData, accentColor)
        val avatar = avatarBitmap(context, widgetData.getString("avatarPath", null), accentColor)
        val density = context.resources.displayMetrics.density
        val avatarSpacePx = ((AVATAR_SIZE_DP + AVATAR_MARGIN_DP) * density).toInt()

        for (widgetId in appWidgetIds) {
            val widthPx = textWidthPx(context, appWidgetManager.getAppWidgetOptions(widgetId))
            val headerWidthPx = (widthPx - avatarSpacePx).coerceAtLeast(1)
            fun text(value: String, sizeSp: Float, color: Int, maxLines: Int) =
                textBitmap(context, font, value, sizeSp, color, maxLines, widthPx)

            // Everything is drawn up front so the card's height is known for the border.
            val greetingBitmap = textBitmap(context, font, greeting, 20f, textColor, 2, headerWidthPx)
            val nameBitmap = nameCaps?.let {
                val nameSp = sizeToFitOneLine(context, nameFont, it, 26f, 16f, headerWidthPx)
                textBitmap(context, nameFont, it, nameSp, textColor, 2, headerWidthPx)
            }
            val quoteBitmap = quote?.let {
                textBitmap(context, font, it, 17f, accentColor, 3, widthPx, italic = true)
            }
            val countdownBitmap = countdown?.let { (eventName, status) ->
                labelRowBitmap(
                    context, font, eventName, status, 16f, textColor, accentColor, widthPx,
                    trailingFont = nameFont,
                )
            }
            val focusLabelBitmap = if (showFocus) {
                labelRowBitmap(context, font, FOCUS_LABEL, date, 13f, accentColor, fadedTextColor, widthPx)
            } else {
                null
            }
            val focusBitmap = if (showFocus) {
                text(focus ?: FOCUS_PROMPT, 17f, if (focus != null) textColor else fadedTextColor, 2)
            } else {
                null
            }

            val views = RemoteViews(context.packageName, R.layout.greeter_widget).apply {
                if (border != null) {
                    // Sizes and margins below mirror greeter_widget.xml.
                    fun dp(value: Int) = (value * density).toInt()
                    val sectionGap = dp(14) + dp(1) + dp(10)
                    val headerHeight = maxOf(greetingBitmap.height + (nameBitmap?.height ?: 0), dp(AVATAR_SIZE_DP))
                    val cardHeight = dp(12) * 2 + headerHeight +
                        (quoteBitmap?.let { dp(6) + it.height } ?: 0) +
                        (countdownBitmap?.let { sectionGap + it.height } ?: 0) +
                        (if (focusLabelBitmap != null && focusBitmap != null) {
                            sectionGap + focusLabelBitmap.height + dp(2) + focusBitmap.height
                        } else {
                            0
                        })
                    val cardWidth = widthPx + dp(CARD_HORIZONTAL_PADDING_DP)
                    setImageViewBitmap(
                        R.id.widget_background,
                        cardBackgroundBitmap(context, cardWidth, cardHeight, cardColor, opacityPercent, border),
                    )
                    // Launchers keep a view's tint and alpha from earlier updates, which would paint
                    // over the border. A transparent tint changes nothing.
                    setInt(R.id.widget_background, "setColorFilter", Color.TRANSPARENT)
                    setInt(R.id.widget_background, "setImageAlpha", 255)
                } else {
                    // Back to the plain tinted shape, in case a border bitmap was set before.
                    setImageViewResource(R.id.widget_background, R.drawable.widget_background)
                    setInt(R.id.widget_background, "setColorFilter", cardColor)
                    setInt(R.id.widget_background, "setImageAlpha", opacityPercent * 255 / 100)
                }

                setImageViewBitmap(R.id.widget_avatar, avatar)

                setImageViewBitmap(R.id.widget_greeting, greetingBitmap)
                setContentDescription(R.id.widget_greeting, greeting)

                if (nameBitmap != null) {
                    setImageViewBitmap(R.id.widget_name, nameBitmap)
                    setContentDescription(R.id.widget_name, name)
                }
                setViewVisibility(R.id.widget_name, if (nameBitmap != null) View.VISIBLE else View.GONE)

                if (quote != null && quoteBitmap != null) {
                    setImageViewBitmap(R.id.widget_quote, quoteBitmap)
                    setContentDescription(R.id.widget_quote, "$quote. Tap for another quote.")
                    setOnClickPendingIntent(R.id.widget_quote, nextQuoteIntent(context))
                }
                setViewVisibility(R.id.widget_quote, if (quote != null) View.VISIBLE else View.GONE)

                val countdownVisibility = if (countdown != null) View.VISIBLE else View.GONE
                setInt(R.id.widget_countdown_divider, "setBackgroundColor", dividerColor)
                setViewVisibility(R.id.widget_countdown_divider, countdownVisibility)
                setViewVisibility(R.id.widget_countdown, countdownVisibility)
                if (countdown != null && countdownBitmap != null) {
                    val (eventName, status) = countdown
                    setImageViewBitmap(R.id.widget_countdown, countdownBitmap)
                    setContentDescription(R.id.widget_countdown, "$eventName, $status")
                }

                setInt(R.id.widget_divider, "setBackgroundColor", dividerColor)
                setViewVisibility(R.id.widget_divider, focusVisibility)
                setViewVisibility(R.id.widget_focus_label, focusVisibility)
                setViewVisibility(R.id.widget_focus, focusVisibility)
                if (focusLabelBitmap != null && focusBitmap != null) {
                    setImageViewBitmap(R.id.widget_focus_label, focusLabelBitmap)
                    setContentDescription(R.id.widget_focus_label, "$FOCUS_LABEL, $date")
                    setImageViewBitmap(R.id.widget_focus, focusBitmap)
                    setContentDescription(R.id.widget_focus, focus ?: FOCUS_PROMPT)
                    val openFocus = HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse(FOCUS_LAUNCH_URI),
                    )
                    setOnClickPendingIntent(R.id.widget_focus_label, openFocus)
                    setOnClickPendingIntent(R.id.widget_focus, openFocus)
                }

                setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    /** The text is drawn to fit the widget's width, so it has to be redrawn after a resize. */
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        onUpdate(context, appWidgetManager, intArrayOf(appWidgetId))
    }

    /**
     * The greeting and quote the widget shows at [now], as a notification's title and text.
     * Null until the user has set their name.
     */
    internal fun greetingMessage(
        context: Context,
        prefs: SharedPreferences,
        now: Calendar,
    ): Pair<String, String?>? {
        val name = prefs.getString("name", null)?.takeIf { it.isNotBlank() } ?: return null
        // Default must match GreetingStyle in lib/widget_store.dart.
        val style = prefs.getString("greetingStyle", null) ?: "pidgin"
        val special = specialDayFor(context, prefs, now)
        val greeting = if (special != null) {
            special.optString(style).ifBlank { special.optString("english") }
        } else {
            greetingFor(now, prefs.getString("greetings", null), style)
        }
        return "$greeting $name" to shownQuote(context, prefs, now)
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_NEXT_QUOTE) {
            showNextQuote(context)
            return
        }
        super.onReceive(context, intent)
    }

    /** Moves on to a different quote right on the home screen, without opening the app. */
    private fun showNextQuote(context: Context) {
        val prefs = HomeWidgetPlugin.getData(context)
        val now = Calendar.getInstance()
        if (specialQuoteShowing(context, prefs, now)) {
            // Leave the special day's quote for the normal ones.
            prefs.edit().putString("specialQuoteHiddenDay", focusDayKey(now)).commit()
        } else {
            val shown = currentQuote(prefs, now)
            val start = prefs.getInt("quoteShuffle", 0)
            var next = start + 1
            while (next < start + 20 && currentQuote(prefs, now, next) == shown) next++
            prefs.edit().putInt("quoteShuffle", next).commit()
        }

        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, GreeterWidget::class.java))
        onUpdate(context, manager, ids)
    }

    private fun nextQuoteIntent(context: Context): PendingIntent {
        val intent = Intent(context, GreeterWidget::class.java).setAction(ACTION_NEXT_QUOTE)
        return PendingIntent.getBroadcast(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    // Special days and the night theme are saved by the app; see lib/special_days.dart and
    // lib/widget_store.dart.

    /**
     * Today's birthday or holiday entry, if any, then a holiday from the phone's calendar when
     * that's switched on. Days start at 5:00, like the greeting. Must match specialDayFor() in
     * lib/special_days.dart.
     */
    private fun specialDayFor(context: Context, prefs: SharedPreferences, now: Calendar): JSONObject? {
        val day = focusDate(now)
        val today = SimpleDateFormat("MM-dd", Locale.US).format(day.time)
        val builtIn = jsonObjects(prefs.getString("specialDays", null)).firstOrNull { it.optString("date") == today }
        if (builtIn != null || !prefs.getBoolean("calendarHolidays", false)) return builtIn
        return CalendarHolidays.titleOn(context, day)?.let { calendarHoliday(prefs, it) }
    }

    /** A calendar holiday's greeting and quote. Must match calendarHoliday() in lib/special_days.dart. */
    private fun calendarHoliday(prefs: SharedPreferences, title: String): JSONObject {
        val name = title.replace(Regex("""\s*\(.*?\)"""), "").trim()
        val lower = name.lowercase(Locale.ROOT)
        jsonObjects(prefs.getString("calendarGreetings", null))
            .firstOrNull { it.optString("date").let { key -> key.isNotEmpty() && lower.contains(key) } }
            ?.let { return it }
        val happy = if (lower.startsWith("happy ")) name else "Happy $name"
        return JSONObject()
            .put("pidgin", "$happy o,")
            .put("english", "$happy,")
            .put("quote", CALENDAR_HOLIDAY_QUOTE)
    }

    private fun jsonObjects(raw: String?): List<JSONObject> {
        if (raw == null) return emptyList()
        return try {
            val array = JSONArray(raw)
            (0 until array.length()).map { array.getJSONObject(it) }
        } catch (e: JSONException) {
            emptyList()
        }
    }

    private fun specialQuoteShowing(context: Context, prefs: SharedPreferences, now: Calendar): Boolean =
        specialDayFor(context, prefs, now) != null &&
            prefs.getString("specialQuoteHiddenDay", null) != focusDayKey(now)

    /** A special day's quote until it's tapped away, otherwise one of the normal quotes. */
    private fun shownQuote(context: Context, prefs: SharedPreferences, now: Calendar): String? =
        if (specialQuoteShowing(context, prefs, now)) {
            specialDayFor(context, prefs, now)?.optString("quote")?.takeIf { it.isNotBlank() }
                ?: currentQuote(prefs, now)
        } else {
            currentQuote(prefs, now)
        }

    /** The night colors when the automatic night theme is on and it's night, otherwise null. */
    private fun nightTheme(prefs: SharedPreferences, now: Calendar): JSONObject? {
        if (!prefs.getBoolean("autoNight", false)) return null
        val hour = now.get(Calendar.HOUR_OF_DAY)
        if (hour in MORNING_START until NIGHT_START) return null
        return try {
            JSONObject(prefs.getString("nightTheme", null) ?: return null)
        } catch (e: JSONException) {
            null
        }
    }

    private fun currentQuote(
        prefs: SharedPreferences,
        now: Calendar,
        shuffle: Int = prefs.getInt("quoteShuffle", 0),
    ): String? {
        val quotes = parseQuotes(prefs.getString("quotes", null))
        if (quotes.isEmpty()) return null
        return quotes[quoteIndex(quoteSlot(now), shuffle, quotes.size)]
    }

    private fun opaque(rgb: Int): Int = rgb or 0xFF000000.toInt()

    private fun parseQuotes(raw: String?): List<String> {
        if (raw == null) return emptyList()
        return try {
            val array = JSONArray(raw)
            (0 until array.length()).mapNotNull { array.optString(it).takeIf(String::isNotBlank) }
        } catch (e: JSONException) {
            emptyList()
        }
    }

    // Widgets can't use custom fonts in TextViews, so text is drawn into bitmaps in Outfit.

    private fun loadFont(context: Context, asset: String): Typeface = synchronized(fonts) {
        fonts.getOrPut(asset) {
            try {
                Typeface.createFromAsset(context.assets, asset)
            } catch (e: RuntimeException) {
                Log.w(TAG, "Could not load $asset", e)
                Typeface.DEFAULT
            }
        }
    }

    /**
     * The widest width the launcher reports, less the card's horizontal padding (see
     * greeter_widget.xml). If that's wider than the real widget, the ImageView scales the text down
     * slightly instead of cutting it off.
     */
    @Suppress("DEPRECATION")
    private fun textWidthPx(context: Context, options: Bundle?): Int {
        val sizes = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            options?.getParcelableArrayList<SizeF>(AppWidgetManager.OPTION_APPWIDGET_SIZES)
        } else {
            null
        }
        val widthDp = sizes?.maxOfOrNull { it.width.toInt() }?.takeIf { it > 0 }
            ?: options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, 0)?.takeIf { it > 0 }
            ?: FALLBACK_WIDTH_DP
        val density = context.resources.displayMetrics.density
        return ((widthDp - CARD_HORIZONTAL_PADDING_DP) * density).toInt().coerceIn(1, MAX_BITMAP_PX)
    }

    private class CardBorder(val widthDp: Int, val colors: IntArray)

    /**
     * The gradient border, or null when it's off. Defaults must match CardBorder.defaults in
     * lib/card_border.dart. The accent style is worked out here so it follows the night theme.
     */
    private fun cardBorder(prefs: SharedPreferences, accent: Int): CardBorder? {
        if (!prefs.getBoolean("borderOn", false)) return null
        val widthDp = prefs.getInt("borderWidth", 2).coerceIn(1, 6)
        if (prefs.getString("borderStyle", null) == "accent") {
            return CardBorder(widthDp, intArrayOf(accent, shine(accent), accent))
        }
        val colors = try {
            val array = JSONArray(prefs.getString("borderColors", null) ?: return null)
            IntArray(array.length()) { opaque(array.getInt(it)) }
        } catch (e: JSONException) {
            return null
        }
        return if (colors.size >= 2) CardBorder(widthDp, colors) else null
    }

    /** [color] mixed 60% of the way to white. Must match shine() in lib/card_border.dart. */
    private fun shine(color: Int): Int {
        fun mix(channel: Int) = (channel + (255 - channel) * 0.6f).toInt()
        val r = (color shr 16) and 0xFF
        val g = (color shr 8) and 0xFF
        val b = color and 0xFF
        return (0xFF shl 24) or (mix(r) shl 16) or (mix(g) shl 8) or mix(b)
    }

    /**
     * The card's rounded background with the gradient border on top, drawn at the card's size so
     * the border isn't stretched. Mirrors GradientBorderPainter in lib/card_border.dart.
     */
    private fun cardBackgroundBitmap(
        context: Context,
        widthPx: Int,
        heightPx: Int,
        cardColor: Int,
        opacityPercent: Int,
        border: CardBorder,
    ): Bitmap {
        val density = context.resources.displayMetrics.density
        val w = widthPx.coerceIn(1, MAX_BITMAP_PX)
        val h = heightPx.coerceIn(1, MAX_BITMAP_PX)
        val bitmap = Bitmap.createBitmap(context.resources.displayMetrics, w, h, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val radius = CARD_RADIUS_DP * density
        val rect = RectF(0f, 0f, w.toFloat(), h.toFloat())

        val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = (cardColor and 0x00FFFFFF) or ((opacityPercent * 255 / 100) shl 24)
        }
        canvas.drawRoundRect(rect, radius, radius, fill)

        val strokePx = border.widthDp * density
        val half = strokePx / 2f
        val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = strokePx
            shader = LinearGradient(0f, 0f, w.toFloat(), h.toFloat(), border.colors, null, Shader.TileMode.CLAMP)
        }
        canvas.drawRoundRect(
            RectF(half, half, w - half, h - half),
            radius - half,
            radius - half,
            stroke,
        )
        return bitmap
    }

    /** The profile photo cropped to a circle, or a person placeholder when none is set. */
    private fun avatarBitmap(context: Context, path: String?, accent: Int): Bitmap {
        val sizePx = (AVATAR_SIZE_DP * context.resources.displayMetrics.density).toInt()
        val size = sizePx.toFloat()
        val radius = size / 2f
        val out = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(out)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)

        val photo = path?.let { loadPhoto(it, sizePx) }
        if (photo != null) {
            canvas.drawCircle(radius, radius, radius, paint)
            paint.xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_IN)
            val side = minOf(photo.width, photo.height)
            val left = (photo.width - side) / 2
            val top = (photo.height - side) / 2
            canvas.drawBitmap(photo, Rect(left, top, left + side, top + side), RectF(0f, 0f, size, size), paint)
            return out
        }

        paint.color = (accent and 0x00FFFFFF) or 0x33000000
        canvas.drawCircle(radius, radius, radius, paint)
        paint.color = accent
        canvas.drawCircle(radius, size * 0.38f, size * 0.17f, paint)
        val body = Path().apply { addOval(RectF(size * 0.18f, size * 0.62f, size * 0.82f, size * 1.1f), Path.Direction.CW) }
        val circle = Path().apply { addCircle(radius, radius, radius, Path.Direction.CW) }
        body.op(circle, Path.Op.INTERSECT)
        canvas.drawPath(body, paint)
        return out
    }

    /** Decodes [path] at roughly [targetPx], upright according to its EXIF orientation. */
    private fun loadPhoto(path: String, targetPx: Int): Bitmap? {
        if (!File(path).exists()) return null
        return try {
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeFile(path, bounds)
            var sample = 1
            while (minOf(bounds.outWidth, bounds.outHeight) / (sample * 2) >= targetPx) sample *= 2
            val bitmap = BitmapFactory.decodeFile(path, BitmapFactory.Options().apply { inSampleSize = sample })
                ?: return null
            val rotation = when (
                ExifInterface(path).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)
            ) {
                ExifInterface.ORIENTATION_ROTATE_90 -> 90f
                ExifInterface.ORIENTATION_ROTATE_180 -> 180f
                ExifInterface.ORIENTATION_ROTATE_270 -> 270f
                else -> 0f
            }
            if (rotation == 0f) {
                bitmap
            } else {
                val matrix = Matrix().apply { postRotate(rotation) }
                Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
            }
        } catch (e: Exception) {
            Log.w(TAG, "Could not load the profile picture", e)
            null
        }
    }

    /** Shrinks from [maxSp] towards [minSp] until [text] fits on one line; long text then wraps. */
    private fun sizeToFitOneLine(
        context: Context,
        font: Typeface,
        text: String,
        maxSp: Float,
        minSp: Float,
        widthPx: Int,
    ): Float {
        val metrics = context.resources.displayMetrics
        val paint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply { typeface = font }
        var sizeSp = maxSp
        while (sizeSp > minSp) {
            paint.textSize = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, sizeSp, metrics)
            if (paint.measureText(text) <= widthPx) break
            sizeSp -= 1f
        }
        return sizeSp
    }

    private fun textBitmap(
        context: Context,
        font: Typeface,
        text: String,
        sizeSp: Float,
        color: Int,
        maxLines: Int,
        widthPx: Int,
        italic: Boolean = false,
    ): Bitmap {
        val metrics = context.resources.displayMetrics
        val paint = TextPaint(Paint.ANTI_ALIAS_FLAG or Paint.SUBPIXEL_TEXT_FLAG).apply {
            typeface = font
            textSize = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, sizeSp, metrics)
            this.color = color
            // Outfit has no italic face, so slant it; the slant leans past the line's end.
            if (italic) textSkewX = ITALIC_SKEW
        }
        val slantPx = if (italic) (paint.textSize * -ITALIC_SKEW).toInt() + 1 else 0
        val layoutWidth = (widthPx - slantPx).coerceAtLeast(1)
        val layout = StaticLayout.Builder.obtain(text, 0, text.length, paint, layoutWidth)
            .setMaxLines(maxLines)
            .setEllipsize(TextUtils.TruncateAt.END)
            .setIncludePad(true)
            .build()
        val bitmap = Bitmap.createBitmap(
            metrics,
            widthPx,
            layout.height.coerceIn(1, MAX_BITMAP_PX),
            Bitmap.Config.ARGB_8888,
        )
        layout.draw(Canvas(bitmap))
        return bitmap
    }

    /**
     * [label] on the left and [trailing] on the right of one line. The label is shortened with
     * "…" if both don't fit.
     */
    private fun labelRowBitmap(
        context: Context,
        font: Typeface,
        label: String,
        trailing: String,
        sizeSp: Float,
        labelColor: Int,
        trailingColor: Int,
        widthPx: Int,
        trailingFont: Typeface = font,
    ): Bitmap {
        val metrics = context.resources.displayMetrics
        val textSize = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, sizeSp, metrics)
        val labelPaint = TextPaint(Paint.ANTI_ALIAS_FLAG or Paint.SUBPIXEL_TEXT_FLAG).apply {
            typeface = font
            this.textSize = textSize
            color = labelColor
        }
        val trailingPaint = TextPaint(labelPaint).apply {
            typeface = trailingFont
            color = trailingColor
        }
        val trailingWidth = trailingPaint.measureText(trailing)
        val gap = 12 * metrics.density
        val shownLabel = TextUtils.ellipsize(
            label,
            labelPaint,
            (widthPx - trailingWidth - gap).coerceAtLeast(0f),
            TextUtils.TruncateAt.END,
        ).toString()

        val fm = labelPaint.fontMetricsInt
        val bitmap = Bitmap.createBitmap(metrics, widthPx, (fm.bottom - fm.top).coerceAtLeast(1), Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val baseline = -fm.top.toFloat()
        canvas.drawText(shownLabel, 0f, baseline, labelPaint)
        canvas.drawText(trailing, widthPx - trailingWidth, baseline, trailingPaint)
        return bitmap
    }

    /** "12 days to go", "Tomorrow" or "Today!"; null once passed. Must match lib/countdown.dart. */
    private fun countdownStatus(eventDate: String?, now: Calendar): String? {
        val parts = eventDate?.split("-")?.mapNotNull { it.toIntOrNull() }
        if (parts == null || parts.size != 3) return null
        val today = focusDate(now)
        fun epochDay(year: Int, month: Int, day: Int) =
            Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply {
                clear()
                set(year, month, day)
            }.timeInMillis / 86_400_000L
        val days = epochDay(parts[0], parts[1] - 1, parts[2]) -
            epochDay(today.get(Calendar.YEAR), today.get(Calendar.MONTH), today.get(Calendar.DAY_OF_MONTH))
        return when {
            days < 0 -> null
            days == 0L -> "Today!"
            days == 1L -> "Tomorrow"
            else -> "$days days to go"
        }
    }

    // The hour boundaries, dates and quote selection below must match lib/widget_store.dart.

    /** The day a focus belongs to; a day starts with the morning greeting, not at midnight. */
    private fun focusDate(now: Calendar): Calendar =
        (now.clone() as Calendar).apply { add(Calendar.HOUR_OF_DAY, -MORNING_START) }

    private fun focusDayKey(now: Calendar): String =
        SimpleDateFormat("yyyy-MM-dd", Locale.US).format(focusDate(now).time)

    private fun shortDate(now: Calendar): String =
        SimpleDateFormat("EEE, d MMM", Locale.ENGLISH).format(focusDate(now).time)

    private fun periodOf(hour: Int): Int = when (hour) {
        in MORNING_START until AFTERNOON_START -> 0
        in AFTERNOON_START until EVENING_START -> 1
        else -> 2
    }

    /**
     * Picks from the lists the app saves (see lib/greetings.dart), the same way the app does, so
     * the greeting holds for the whole morning, afternoon or evening.
     */
    private fun greetingFor(now: Calendar, greetingsJson: String?, style: String): String {
        val period = periodOf(now.get(Calendar.HOUR_OF_DAY))
        val options = try {
            val lists = JSONObject(greetingsJson ?: "{}").optJSONArray(style)?.optJSONArray(period)
            if (lists == null) emptyList() else (0 until lists.length()).map { lists.getString(it) }
        } catch (e: JSONException) {
            emptyList()
        }
        if (options.isEmpty()) {
            return when (period) {
                0 -> "Good morning,"
                1 -> "Good afternoon,"
                else -> "Good evening,"
            }
        }
        return options[quoteIndex(quoteSlot(now), GREETING_SEED, options.size)]
    }

    private fun quoteSlot(now: Calendar): Long {
        val shifted = (now.clone() as Calendar).apply { add(Calendar.HOUR_OF_DAY, -MORNING_START) }
        val utcDay = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply {
            clear()
            set(shifted.get(Calendar.YEAR), shifted.get(Calendar.MONTH), shifted.get(Calendar.DAY_OF_MONTH))
        }
        val day = utcDay.timeInMillis / 86_400_000L
        return day * 3 + periodOf(now.get(Calendar.HOUR_OF_DAY))
    }

    private fun quoteIndex(slot: Long, shuffle: Int, count: Int): Int {
        val hash = (((slot + shuffle) * 2_654_435_761L) % 4_294_967_296L) shr 16
        return (hash % count).toInt()
    }

    private companion object {
        const val TAG = "GreeterWidget"
        const val MORNING_START = 5
        const val AFTERNOON_START = 12
        const val EVENING_START = 17
        const val NIGHT_START = 19

        const val GREETING_SEED = 7919
        const val CALENDAR_HOLIDAY_QUOTE = "Enjoy today well well, and remember the people wey you love."
        const val ACTION_NEXT_QUOTE = "com.proffictech.greeter.action.NEXT_QUOTE"
        const val ITALIC_SKEW = -0.22f
        const val FOCUS_LABEL = "Today's focus"
        const val FOCUS_PROMPT = "Tap to set today's focus"
        const val FOCUS_LAUNCH_URI = "greeter://focus"
        const val OUTFIT_REGULAR = "flutter_assets/assets/fonts/Outfit-Regular.ttf"
        const val OUTFIT_SEMIBOLD = "flutter_assets/assets/fonts/Outfit-SemiBold.ttf"
        const val CARD_HORIZONTAL_PADDING_DP = 40
        const val CARD_RADIUS_DP = 28
        const val AVATAR_SIZE_DP = 48
        const val AVATAR_MARGIN_DP = 12
        const val FALLBACK_WIDTH_DP = 300
        const val MAX_BITMAP_PX = 2048

        val fonts = HashMap<String, Typeface>()
    }
}
