package com.humsukhan.humsukhan

import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * The one authoritative environmental monitoring state, shared by the
 * service, the Quick Settings tile and the Flutter activity.
 *
 * The state lives in memory, so it lasts exactly as long as the process that
 * owns the microphone: if Android kills the process, nothing is running and
 * the next reader correctly sees OFF. Persisting it would leave a dead
 * process's STARTING behind, and the tile would refuse to work forever.
 *
 * Only the user's intent is persisted, so a sticky restart after the system
 * kills the service knows whether to resume.
 */
object EnvironmentalMonitoringState {
    const val OFF = "OFF"
    const val STARTING = "STARTING"
    const val ACTIVE = "ACTIVE"
    const val STOPPING = "STOPPING"
    const val ERROR = "ERROR"

    // Failure codes understood by MonitoringFailure on the Dart side.
    const val ERROR_MIC_PERMISSION = "MIC_PERMISSION"
    const val ERROR_SERVICE = "SERVICE"
    const val ERROR_CAPTURE = "CAPTURE"

    const val ACTION_START = "com.humsukhan.environmental.START"
    const val ACTION_STOP = "com.humsukhan.environmental.STOP"
    const val ACTION_STATE = "com.humsukhan.environmental.STATE"
    const val EXTRA_STATE = "state"
    const val EXTRA_ERROR = "error"
    const val EXTRA_EVENT = "event"

    private const val PREFS = "environmental_monitoring"
    private const val KEY_WANTED = "wanted"

    @Volatile private var current = OFF
    @Volatile private var lastError: String? = null

    fun get(@Suppress("UNUSED_PARAMETER") context: Context): String = current

    /** The failure code while the state is ERROR, otherwise null. */
    fun error(): String? = lastError

    fun set(context: Context, state: String, error: String? = null) {
        current = state
        lastError = if (state == ERROR) (error ?: ERROR_SERVICE) else null
        context.sendBroadcast(
            Intent(ACTION_STATE).setPackage(context.packageName)
                .putExtra(EXTRA_STATE, state)
                .putExtra(EXTRA_ERROR, lastError),
        )
        EnvironmentalMonitoringTileService.requestUpdate(context)
    }

    /** Tells an open app about an alert the service has already announced. */
    fun broadcastAlert(context: Context, eventJson: String) {
        context.sendBroadcast(
            Intent(ACTION_STATE).setPackage(context.packageName)
                .putExtra(EXTRA_STATE, current)
                .putExtra(EXTRA_EVENT, eventJson),
        )
    }

    fun isWanted(context: Context): Boolean =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getBoolean(KEY_WANTED, false)

    fun setWanted(context: Context, wanted: Boolean) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putBoolean(KEY_WANTED, wanted).apply()
    }

    /**
     * Shows STARTING immediately, so neither the tile nor the app can issue a
     * second request while the service is still coming up. Returns false, and
     * reports the failure, if Android refuses to start the service.
     */
    fun requestStart(context: Context): Boolean {
        set(context, STARTING)
        val intent = Intent(context, EnvironmentalMonitoringService::class.java).setAction(ACTION_START)
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) context.startForegroundService(intent) else context.startService(intent)
            true
        } catch (e: Exception) {
            android.util.Log.w("HumSukhanEnv", "Environmental service could not start: $e")
            set(context, ERROR, ERROR_SERVICE)
            false
        }
    }

    fun requestStop(context: Context) {
        setWanted(context, false)
        val intent = Intent(context, EnvironmentalMonitoringService::class.java).setAction(ACTION_STOP)
        try {
            context.startService(intent)
        } catch (e: Exception) {
            // Not running and not allowed to start: there is nothing to stop.
            android.util.Log.w("HumSukhanEnv", "Environmental service stop request failed: $e")
            if (current != ERROR) set(context, OFF)
        }
    }
}
