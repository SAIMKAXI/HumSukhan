package com.humsukhan.humsukhan

import android.content.Context

/**
 * The few labels Android shows outside the Flutter screens: the monitoring
 * notification and the Quick Settings tile. They follow HumSukhan's own
 * language setting (SettingsProvider's appLanguage, which shared_preferences
 * keeps in FlutterSharedPreferences), not the phone's language.
 */
class NativeStrings(context: Context) {
    private val urdu = context
        .getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        .getString("flutter.appLanguage", "en") == "ur"

    val monitoringTitle get() = if (urdu) "HumSukhan ماحولیاتی نگرانی" else "HumSukhan Environmental Monitoring"
    val monitoringActive get() = if (urdu) "ماحولیاتی نگرانی: فون پر ہی، آف لائن" else "Environmental monitoring: Offline / Local"
    val monitoringStarting get() = if (urdu) "ماحولیاتی نگرانی: شروع ہو رہی ہے" else "Environmental monitoring: starting"
    val stop get() = if (urdu) "بند کریں" else "Stop"
    val channelName get() = if (urdu) "ماحولیاتی نگرانی" else "Environmental Monitoring"
    val channelDescription get() = if (urdu) {
        "دکھاتا ہے کہ HumSukhan ماحولیاتی آوازوں کی نگرانی کر رہا ہے۔"
    } else {
        "Shows when HumSukhan is actively monitoring environmental sounds."
    }
    val tileLabel get() = if (urdu) "ماحولیاتی نگرانی" else "Environmental Monitoring"
}
