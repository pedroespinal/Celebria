package com.flet.celebria

import android.app.AlarmManager
import android.app.AlertDialog
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Environment
import android.provider.MediaStore
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
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

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        alive = true
        super.onCreate(savedInstanceState)
    }

    override fun onDestroy() {
        alive = false
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Dart calls this after every reschedule (contact added/edited/
        // deleted, language changed) so the home-screen widget is redrawn
        // immediately instead of waiting for its 30-min update period.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.flet.celebria/widget")
            .setMethodCallHandler { call, result ->
                if (call.method == "refresh") {
                    try { BirthdayWidget.updateAllWidgets(applicationContext) } catch (_: Exception) {}
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }

        // Weekly auto-backup (BackupService.dart): writes a JSON file into the
        // public Downloads/Celebria folder so it survives an uninstall.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.flet.celebria/backup")
            .setMethodCallHandler { call, result ->
                if (call.method != "saveToDownloads") {
                    result.notImplemented(); return@setMethodCallHandler
                }
                val name = call.argument<String>("name") ?: "Celebria_auto_backup.json"
                val content = call.argument<String>("content") ?: ""
                Thread {
                    val where = try { saveToDownloads(name, content) } catch (_: Exception) { null }
                    runOnUiThread { result.success(where) }
                }.start()
            }
    }

    /** Returns a human-readable location, or null on failure. */
    private fun saveToDownloads(name: String, content: String): String? {
        val bytes = content.toByteArray(Charsets.UTF_8)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // MediaStore: no storage permission needed. Overwrite our own
            // previous file instead of piling up "name (1).json" copies.
            val resolver = contentResolver
            val collection = MediaStore.Downloads.EXTERNAL_CONTENT_URI
            val relPath = Environment.DIRECTORY_DOWNLOADS + "/Celebria/"
            var uri: Uri? = null
            resolver.query(
                collection, arrayOf(MediaStore.MediaColumns._ID),
                "${MediaStore.MediaColumns.DISPLAY_NAME}=? AND ${MediaStore.MediaColumns.RELATIVE_PATH}=?",
                arrayOf(name, relPath), null
            )?.use { c ->
                if (c.moveToFirst()) uri = android.content.ContentUris.withAppendedId(collection, c.getLong(0))
            }
            if (uri == null) {
                val values = ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, name)
                    put(MediaStore.MediaColumns.MIME_TYPE, "application/json")
                    put(MediaStore.MediaColumns.RELATIVE_PATH, relPath)
                }
                uri = resolver.insert(collection, values) ?: return null
            }
            resolver.openOutputStream(uri!!, "wt")?.use { it.write(bytes) } ?: return null
            return relPath + name
        }
        // Android 7–9: app-specific Downloads folder (no permission needed).
        val dir = File(getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS), "Celebria")
        dir.mkdirs()
        val f = File(dir, name)
        f.writeBytes(bytes)
        return f.absolutePath
    }

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
        /** True while the UI is running; BootReceiver then skips its headless
         *  engine because the app itself is already rescheduling. */
        @Volatile var alive = false
        private const val PREF_LAST_SHOWN = "notif_prompt_last_shown"
        private const val COOLDOWN_MS = 12 * 60 * 60 * 1000L // 12h — avoid nagging every resume
    }
}
