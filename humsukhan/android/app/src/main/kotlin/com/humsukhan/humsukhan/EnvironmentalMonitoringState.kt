package com.humsukhan.humsukhan

import android.content.Context
import android.content.Intent
import android.os.Build

object EnvironmentalMonitoringState {
    const val OFF = "OFF"
    const val STARTING = "STARTING"
    const val ACTIVE = "ACTIVE"
    const val STOPPING = "STOPPING"
    const val ERROR = "ERROR"

    const val ACTION_START = "com.humsukhan.environmental.START"
    const val ACTION_STOP = "com.humsukhan.environmental.STOP"
    const val ACTION_STATE = "com.humsukhan.environmental.STATE"
    const val EXTRA_STATE = "state"
    const val EXTRA_EVENT = "event"

    private const val PREFS = "environmental_monitoring"
    private const val KEY_STATE = "state"

    fun get(context: Context): String =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_STATE, OFF) ?: OFF

    fun set(context: Context, state: String) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putString(KEY_STATE, state).apply()
        context.sendBroadcast(Intent(ACTION_STATE).setPackage(context.packageName).putExtra(EXTRA_STATE, state))
        EnvironmentalMonitoringTileService.requestUpdate(context)
    }

    fun requestStart(context: Context) {
        val intent = Intent(context, EnvironmentalMonitoringService::class.java).setAction(ACTION_START)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(intent)
        } else {
            context.startService(intent)
        }
    }

    fun requestStop(context: Context) {
        val intent = Intent(context, EnvironmentalMonitoringService::class.java).setAction(ACTION_STOP)
        context.startService(intent)
    }
}
