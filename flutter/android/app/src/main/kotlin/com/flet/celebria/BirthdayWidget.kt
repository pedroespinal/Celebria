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

        /** Called from MainActivity (Flutter) each time the app opens. */
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
                val cur = db.query(
                    "contacts", arrayOf("name", "day", "month", "year"),
                    null, null, null, null, null
                )

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
                        val nameLabel = "🎂 $name" + (if (age != null) " ($age)" else "")
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
                    val bday = Calendar.getInstance().also {
                        it.set(todayYear + offset, month - 1, day, 0, 0, 0)
                        it.set(Calendar.MILLISECOND, 0)
                    }
                    val diff = ((bday.timeInMillis - todayClean.timeInMillis) / 86_400_000L).toInt()
                    if (diff >= 0) return Pair(diff, todayYear + offset)
                } catch (_: Exception) { /* Feb 29 in non-leap year */ }
            }
            return Pair(Int.MAX_VALUE, todayYear + 1)
        }
    }
}
