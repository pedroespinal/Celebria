package com.flet.celebria

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

/**
 * Reschedules birthday notifications after the device restarts.
 *
 * Android clears all AlarmManager alarms on reboot, so scheduled
 * notifications would be lost without this receiver.  It launches the
 * Flutter engine in headless mode and calls the `backgroundMain` Dart
 * entry point which runs NotificationHelper.scheduleFromDB() without
 * showing any UI.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != Intent.ACTION_MY_PACKAGE_REPLACED) return

        // Keeps the process alive past onReceive() while the headless
        // engine finishes the async DB read + notification scheduling.
        val pendingResult = goAsync()
        val handler = Handler(Looper.getMainLooper())
        var finished = false

        try {
            val appContext = context.applicationContext
            val loader = FlutterInjector.instance().flutterLoader()
            loader.startInitialization(appContext)
            loader.ensureInitializationComplete(appContext, null)

            val engine = FlutterEngine(appContext)
            // Required: a manually created headless FlutterEngine does NOT
            // auto-register plugins the way FlutterActivity does. Without
            // this, sqflite/flutter_local_notifications/flutter_timezone
            // channel calls fail silently and scheduleFromDB() does nothing.
            GeneratedPluginRegistrant.registerWith(engine)

            val channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)

            fun finishOnce() {
                if (finished) return
                finished = true
                handler.removeCallbacksAndMessages(null)
                channel.setMethodCallHandler(null)
                engine.destroy()
                pendingResult.finish()
            }

            channel.setMethodCallHandler { call, result ->
                if (call.method == "bootRescheduleDone") {
                    result.success(null)
                    finishOnce()
                } else {
                    result.notImplemented()
                }
            }
            // Safety net in case Dart never calls back (e.g. an uncaught error).
            handler.postDelayed({ finishOnce() }, 20_000)

            engine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint(
                    loader.findAppBundlePath(),
                    "backgroundMain"
                )
            )
        } catch (_: Exception) {
            // Silently ignore — notifications will be rescheduled next time
            // the user opens the app.
            if (!finished) pendingResult.finish()
        }
    }

    companion object {
        private const val CHANNEL = "com.flet.celebria/boot"
    }
}
