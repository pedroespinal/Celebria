package com.flet.celebria

import android.app.AlarmManager
import android.app.AlertDialog
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import java.io.File

/**
 * On top of the default Flet/Flutter activity, this checks whether push
 * notifications (and, on Android 12+, exact alarms) are actually usable and
 * — if the user or the system has them disabled — shows a native popup
 * offering a one-tap shortcut to the relevant system settings screen.
 *
 * This runs natively (not through Flet/Python) because the Python side has
 * no channel to query real Android permission state, and because native
 * AlertDialog is not subject to the Flet/Flutter dialog-timing issues
 * documented for the birthday popup.
 */
class MainActivity : FlutterActivity() {

    private var promptedThisSession = false

    override fun onResume() {
        super.onResume()
        if (promptedThisSession) return
        promptedThisSession = true
        // Delay so Flutter's own POST_NOTIFICATIONS system prompt (triggered
        // a moment later from Dart on first launch, now deferred to after
        // the first frame — see main.dart) gets a chance to resolve first —
        // otherwise both dialogs could appear stacked on top of each other
        // on a fresh install.
        Handler(Looper.getMainLooper()).postDelayed({ checkNotificationsAndPrompt() }, 5000)
    }

    private fun checkNotificationsAndPrompt() {
        if (isFinishing || isDestroyed) return
        val notifEnabled = NotificationManagerCompat.from(this).areNotificationsEnabled()
        val exactAllowed = canScheduleExactAlarms()
        if (notifEnabled && exactAllowed) return

        val prefs = getSharedPreferences("celebria_prefs", Context.MODE_PRIVATE)
        val lastShown = prefs.getLong(PREF_LAST_SHOWN, 0L)
        val now = System.currentTimeMillis()
        if (now - lastShown < COOLDOWN_MS) return

        val lang = readLang()
        val es = lang != "en"

        val title = if (es) "🔔 Activa las notificaciones" else "🔔 Enable notifications"
        val message = buildString {
            if (!notifEnabled) {
                append(
                    if (es)
                        "Las notificaciones de Celebria están desactivadas. No podrás recibir avisos de cumpleaños hasta que las actives."
                    else
                        "Celebria's notifications are turned off. You won't receive birthday reminders until you enable them."
                )
            }
            if (!exactAllowed) {
                if (isNotEmpty()) append("\n\n")
                append(
                    if (es)
                        "Además, permite las 'alarmas y recordatorios' para que los avisos lleguen a la hora exacta."
                    else
                        "Also allow 'alarms & reminders' so reminders arrive at the exact time."
                )
            }
        }
        val positiveLabel = if (es) "Abrir configuración" else "Open settings"
        val negativeLabel = if (es) "Después" else "Later"

        try {
            AlertDialog.Builder(this)
                .setTitle(title)
                .setMessage(message)
                .setCancelable(true)
                .setPositiveButton(positiveLabel) { _, _ ->
                    if (!notifEnabled) openNotificationSettings() else openExactAlarmSettings()
                }
                .setNegativeButton(negativeLabel, null)
                .show()
        } catch (_: Exception) {
            // Activity not in a valid state to show a dialog — skip silently.
        }

        prefs.edit().putLong(PREF_LAST_SHOWN, now).apply()
    }

    private fun canScheduleExactAlarms(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            am.canScheduleExactAlarms()
        } else true
    }

    private fun openNotificationSettings() {
        try {
            val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                    .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            } else {
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                    .setData(Uri.parse("package:$packageName"))
            }
            startActivity(intent)
        } catch (_: Exception) {
        }
    }

    private fun openExactAlarmSettings() {
        try {
            val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
                .setData(Uri.parse("package:$packageName"))
            startActivity(intent)
        } catch (_: Exception) {
            openNotificationSettings()
        }
    }

    /** Reads the `lang` setting straight from the app's SQLite DB (same file NotificationHelper/BirthdayWidget use). */
    private fun readLang(): String {
        val dbFile = listOf(
            File(getDir("app_flutter", Context.MODE_PRIVATE), "celebria.db"),
            File(filesDir, "celebria.db"),
            File(filesDir.parentFile ?: filesDir, "app_flutter/celebria.db"),
        ).firstOrNull { it.exists() } ?: return "es"

        return try {
            val db = SQLiteDatabase.openDatabase(dbFile.absolutePath, null, SQLiteDatabase.OPEN_READONLY)
            val cur = db.query("settings", arrayOf("value"), "key=?", arrayOf("lang"), null, null, null)
            val lang = if (cur.moveToFirst()) cur.getString(0) ?: "es" else "es"
            cur.close()
            db.close()
            lang
        } catch (_: Exception) {
            "es"
        }
    }

    companion object {
        private const val PREF_LAST_SHOWN = "notif_prompt_last_shown"
        private const val COOLDOWN_MS = 12 * 60 * 60 * 1000L // 12h — avoid nagging every resume
    }
}
