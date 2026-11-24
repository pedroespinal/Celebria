package com.flet.celebria

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.widget.RemoteViews
import java.io.File
import java.util.Calendar

class BirthdayWidget : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        appWidgetIds.forEach { updateWidget(context, appWidgetManager, it) }
    }

    companion object {

        /** Called from MainActivity's "com.flet.celebria/widget" channel after every reschedule. */
        fun updateAllWidgets(context: Context) {
            val manager = AppWidgetManager.getInstance(context) ?: return
            val ids = manager.getAppWidgetIds(
                android.content.ComponentName(context, BirthdayWidget::class.java)
            )
            ids.forEach { updateWidget(context, manager, it) }
        }

        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            widgetId: Int
        ) {
            val views = RemoteViews(context.packageName, R.layout.birthday_widget)

            // Tap opens Celebria
            val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            val pi = PendingIntent.getActivity(
                context, 0, launch ?: Intent(),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pi)

            val info = queryNextBirthday(context)
            if (info != null) {
                views.setTextViewText(R.id.widget_name,  info.name)
                views.setTextViewText(R.id.widget_date,  info.dateStr)
                views.setTextViewText(R.id.widget_days,  info.daysStr)
            } else {
                views.setTextViewText(R.id.widget_name,  "—")
                views.setTextViewText(R.id.widget_date,  "")
                views.setTextViewText(R.id.widget_days,  "")
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }

        // ── Data ──────────────────────────────────────────────────────────────

        private data class BirthdayInfo(
            val name: String,
            val dateStr: String,
            val daysStr: String
        )

        // Try the two possible DB locations that path_provider / serious_python use
        private fun findDbFile(context: Context): File? =
            listOf(
                File(context.getDir("app_flutter", Context.MODE_PRIVATE), "celebria.db"),
                File(context.filesDir, "celebria.db"),
                File(context.filesDir.parentFile ?: context.filesDir, "app_flutter/celebria.db"),
            ).firstOrNull { it.exists() }

        private fun queryNextBirthday(context: Context): BirthdayInfo? {
            val dbFile = findDbFile(context) ?: return null
            return try {
                val db = SQLiteDatabase.openDatabase(
                    dbFile.absolutePath, null, SQLiteDatabase.OPEN_READONLY
                )

                // Read UI language
                val langCur = db.query(
                    "settings", arrayOf("value"), "key=?", arrayOf("lang"),
                    null, null, null
                )
                val lang = if (langCur.moveToFirst()) langCur.getString(0) ?: "es" else "es"
                langCur.close()

                // Scan contacts
                // "kind" exists from v1.10 on (added by AppDb.onOpen); fall back
                // to the old columns if the app hasn't been opened since updating.
                val cur = try {
                    db.query("contacts", arrayOf("name", "day", "month", "year", "kind"),
                        null, null, null, null, null)
                } catch (_: Exception) {
                    db.query("contacts", arrayOf("name", "day", "month", "year"),
                        null, null, null, null, null)
                }

                val today   = Calendar.getInstance()
                var minDays = Int.MAX_VALUE
                var result: BirthdayInfo? = null

                while (cur.moveToNext()) {
                    val name      = cur.getString(0) ?: continue
                    val day       = cur.getInt(1)
                    val month     = cur.getInt(2)
                    val birthYear = cur.getInt(3)
                    if (day == 0 || month == 0 || name.isEmpty()) continue

                    val (days, nextYear) = daysUntil(today, day, month)
                    if (days < minDays) {
                        minDays = days

                        val age = if (birthYear > 0) nextYear - birthYear else null
                        val kind = (if (cur.columnCount > 4) cur.getString(4) else null) ?: "birthday"
                        val icon = when (kind) { "anniversary" -> "💍"; "other" -> "⭐"; else -> "🎂" }
                        val ageLabel = when {
                            age == null || age <= 0 -> ""
                            kind == "birthday" -> if (lang == "es") "\nCumple $age años" else "\nTurns $age"
                            kind == "anniversary" -> if (lang == "es") "\n$age años juntos" else "\n$age years together"
                            else -> if (lang == "es") "\n$age años" else "\n$age years"
                        }
                        val nameLabel = "$icon $name$ageLabel"
                        val dateLabel = String.format("%02d/%02d", day, month)
                        val daysLabel = when (days) {
                            0    -> if (lang == "es") "¡Hoy! 🎉"       else "Today! 🎉"
                            1    -> if (lang == "es") "Mañana"          else "Tomorrow"
                            else -> if (lang == "es") "En $days días"   else "In $days days"
                        }
                        result = BirthdayInfo(nameLabel, dateLabel, daysLabel)
                    }
                }
                cur.close()
                db.close()
                result
            } catch (_: Exception) { null }
        }


        /** Returns (daysUntilNextOccurrence, yearOfNextOccurrence). */
        private fun daysUntil(today: Calendar, day: Int, month: Int): Pair<Int, Int> {
            val todayYear = today.get(Calendar.YEAR)
            val todayClean = Calendar.getInstance().also {
                it.set(todayYear, today.get(Calendar.MONTH), today.get(Calendar.DAY_OF_MONTH), 0, 0, 0)
                it.set(Calendar.MILLISECOND, 0)
            }
            for (offset in 0..1) {
                try {
                    // Same rule as Dart's birthdayInYear(): a day that doesn't
                    // exist that year (Feb 29 in a common year) is clamped to
                    // the month's last day. Calendar is lenient and would
                    // otherwise silently roll Feb 29 over to Mar 1.
                    val bday = Calendar.getInstance().also {
                        it.clear()
                        it.set(todayYear + offset, month - 1, 1, 0, 0, 0)
                        val last = it.getActualMaximum(Calendar.DAY_OF_MONTH)
                        it.set(Calendar.DAY_OF_MONTH, if (day > last) last else day)
                    }
                    // Math.round, not truncation: across a DST change the gap
                    // between two local midnights is 23h or 25h.
                    val diff = Math.round((bday.timeInMillis - todayClean.timeInMillis) / 86_400_000.0).toInt()
                    if (diff >= 0) return Pair(diff, todayYear + offset)
                } catch (_: Exception) { }
            }
            return Pair(Int.MAX_VALUE, todayYear + 1)
        }
    }
}
