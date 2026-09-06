package com.humsukhan.humsukhan

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import org.json.JSONObject

class EnvironmentalMonitoringService : Service() {
    companion object {
        const val CHANNEL_ID = "environmental_monitoring"
        const val NOTIFICATION_ID = 4107
        private const val METHOD_CHANNEL = "com.humsukhan/environmental_monitor"
        private const val SAMPLE_RATE = 16000
        private const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
        private const val AUDIO_ENCODING = AudioFormat.ENCODING_PCM_16BIT
        private const val PCM_FLOW_TIMEOUT_MS = 5000L
    }

    private var engine: FlutterEngine? = null
    private var channel: MethodChannel? = null
    private var stopping = false
    private val mainHandler = Handler(Looper.getMainLooper())
    @Volatile private var captureRunning = false
    @Volatile private var bytesCaptured = 0L
    @Volatile private var lastPcmReadAtMs = 0L
    @Volatile private var dartPcmFlowing = false
    private var audioRecord: AudioRecord? = null
    private var captureThread: Thread? = null
    private val pcmWatchdogToken = Any()

    override fun onCreate() { super.onCreate(); createNotificationChannel() }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            EnvironmentalMonitoringState.ACTION_STOP -> stopMonitoring()
            EnvironmentalMonitoringState.ACTION_START -> startMonitoring()
            null -> if (EnvironmentalMonitoringState.get(this) == EnvironmentalMonitoringState.ACTIVE) startMonitoring() else stopSelf()
        }
        return START_STICKY
    }

    private fun startMonitoring() {
        if (EnvironmentalMonitoringState.get(this) == EnvironmentalMonitoringState.ACTIVE && engine != null && captureRunning) return
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            EnvironmentalMonitoringState.set(this, EnvironmentalMonitoringState.ERROR)
            stopSelf()
            return
        }
        EnvironmentalMonitoringState.set(this, EnvironmentalMonitoringState.STARTING)
        try {
            val notification = buildMonitoringNotification("Environmental monitoring: starting")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                ServiceCompat.startForeground(this, NOTIFICATION_ID, notification, android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            EnvironmentalMonitoringState.set(this, EnvironmentalMonitoringState.ERROR)
            cleanupAndStop()
            return
        }
        startFlutterBackgroundEngine()
    }

    private fun startFlutterBackgroundEngine() {
        if (engine != null) return
        try {
            val loader = FlutterInjector.instance().flutterLoader()
            loader.startInitialization(applicationContext)
            loader.ensureInitializationComplete(applicationContext, emptyArray())
            val flutterEngine = FlutterEngine(applicationContext)
            GeneratedPluginRegistrant.registerWith(flutterEngine)
            engine = flutterEngine
            channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            channel?.setMethodCallHandler { call, result ->
                when (call.method) {
                    "pipelineState" -> {
                        val state = call.argument<String>("state") ?: EnvironmentalMonitoringState.ERROR
                        when (state) {
                            "READY" -> {
                                if (startNativeAudioCapture()) {
                                    dartPcmFlowing = false
                                    bytesCaptured = 0L
                                    lastPcmReadAtMs = 0L
                                    EnvironmentalMonitoringState.set(this, EnvironmentalMonitoringState.STARTING)
                                    updateMonitoringNotification(EnvironmentalMonitoringState.STARTING)
                                    schedulePcmFlowWatchdog()
                                    result.success(true)
                                } else {
                                    EnvironmentalMonitoringState.set(this, EnvironmentalMonitoringState.ERROR)
                                    updateMonitoringNotification(EnvironmentalMonitoringState.ERROR)
                                    result.success(false)
                                }
                            }
                            "PCM_FLOWING" -> {
                                dartPcmFlowing = true
                                mainHandler.removeCallbacksAndMessages(pcmWatchdogToken)
                                EnvironmentalMonitoringState.set(this, EnvironmentalMonitoringState.ACTIVE)
                                updateMonitoringNotification(EnvironmentalMonitoringState.ACTIVE)
                                result.success(true)
                            }
                            else -> if (state == EnvironmentalMonitoringState.ACTIVE && !hasLiveEngine()) {
                                EnvironmentalMonitoringState.set(this, EnvironmentalMonitoringState.ERROR)
                                result.success(false)
                            } else {
                                EnvironmentalMonitoringState.set(this, state)
                                updateMonitoringNotification(state)
                                result.success(true)
                            }
                        }
                    }
                    "event" -> {
                        val type = call.argument<String>("type") ?: "Environmental sound"
                        val confidence = call.argument<Double>("confidence") ?: 0.0
                        val severity = call.argument<String>("severity") ?: "warning"
                        handleSoundEvent(type, confidence, severity)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
            val entrypoint = DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "environmentalMonitoringBackgroundMain")
            flutterEngine.dartExecutor.executeDartEntrypoint(entrypoint)
        } catch (e: Exception) {
            EnvironmentalMonitoringState.set(this, EnvironmentalMonitoringState.ERROR)
            cleanupAndStop()
        }
    }

    private fun hasLiveEngine(): Boolean = engine != null && channel != null && !stopping

    private fun schedulePcmFlowWatchdog() {
        mainHandler.removeCallbacksAndMessages(pcmWatchdogToken)
        mainHandler.postAtTime({
            if (!captureRunning || stopping || dartPcmFlowing) return@postAtTime
            val now = System.currentTimeMillis()
            val lastRead = lastPcmReadAtMs
            if (!dartPcmFlowing) {
                debugPrint("Environmental PCM watchdog failed: Dart received no PCM (bytesCaptured=$bytesCaptured lastPcmReadAtMs=$lastRead)")
                EnvironmentalMonitoringState.set(this, EnvironmentalMonitoringState.ERROR)
                updateMonitoringNotification(EnvironmentalMonitoringState.ERROR)
                stopNativeAudioCapture()
            } else if (lastRead <= 0L || now - lastRead > PCM_FLOW_TIMEOUT_MS) {
                debugPrint("Environmental PCM watchdog failed: native capture stalled (bytesCaptured=$bytesCaptured lastPcmReadAtMs=$lastRead)")
                EnvironmentalMonitoringState.set(this, EnvironmentalMonitoringState.ERROR)
                updateMonitoringNotification(EnvironmentalMonitoringState.ERROR)
                stopNativeAudioCapture()
            }
        }, pcmWatchdogToken, System.currentTimeMillis() + PCM_FLOW_TIMEOUT_MS)
    }

    private fun startNativeAudioCapture(): Boolean {
        if (captureRunning) return true
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) return false
        return try {
            val minBuffer = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_ENCODING)
            if (minBuffer <= 0) return false
            val bufferSize = maxOf(minBuffer * 2, 8192)
            val recorder = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                SAMPLE_RATE,
                CHANNEL_CONFIG,
                AUDIO_ENCODING,
                bufferSize,
            )
            if (recorder.state != AudioRecord.STATE_INITIALIZED) {
                recorder.release()
                return false
            }
            recorder.startRecording()
            if (recorder.recordingState != AudioRecord.RECORDSTATE_RECORDING) {
                recorder.release()
                return false
            }
            bytesCaptured = 0L
            lastPcmReadAtMs = 0L
            dartPcmFlowing = false
            audioRecord = recorder
            captureRunning = true
            captureThread = Thread {
                val pcm = ByteArray(bufferSize)
                try {
                    while (captureRunning && !Thread.currentThread().isInterrupted) {
                        val count = recorder.read(pcm, 0, pcm.size, AudioRecord.READ_BLOCKING)
                        if (count > 0 && captureRunning) {
                            bytesCaptured += count
                            lastPcmReadAtMs = System.currentTimeMillis()
                            val payload = pcm.copyOf(count)
                            // AudioRecord runs on a dedicated capture thread. Flutter's
                            // MethodChannel invocation must be marshalled to the main thread.
                            mainHandler.post {
                                if (captureRunning && !stopping) {
                                    channel?.invokeMethod("audioData", payload)
                                }
                            }
                        } else if (count < 0) {
                            debugPrint("Environmental native AudioRecord read error: $count")
                            break
                        }
                    }
                } catch (e: Exception) {
                    if (captureRunning) debugPrint("Environmental native audio capture error: $e")
                } finally {
                    captureRunning = false
                    mainHandler.removeCallbacksAndMessages(pcmWatchdogToken)
                    try { recorder.stop() } catch (_: Exception) {}
                    try { recorder.release() } catch (_: Exception) {}
                    if (audioRecord === recorder) audioRecord = null
                    if (!stopping && EnvironmentalMonitoringState.get(this@EnvironmentalMonitoringService) == EnvironmentalMonitoringState.STARTING) {
                        mainHandler.post {
                            if (!stopping && !dartPcmFlowing) {
                                debugPrint("Environmental native audio capture stopped before PCM reached Dart")
                                EnvironmentalMonitoringState.set(this@EnvironmentalMonitoringService, EnvironmentalMonitoringState.ERROR)
                                updateMonitoringNotification(EnvironmentalMonitoringState.ERROR)
                            }
                        }
                    }
                }
            }.also {
                it.name = "HumSukhan-EnvironmentalAudio"
                it.start()
            }
            true
        } catch (e: Exception) {
            debugPrint("Environmental native AudioRecord start error: $e")
            captureRunning = false
            mainHandler.removeCallbacksAndMessages(pcmWatchdogToken)
            try { audioRecord?.release() } catch (_: Exception) {}
            audioRecord = null
            false
        }
    }

    private fun stopNativeAudioCapture() {
        captureRunning = false
        mainHandler.removeCallbacksAndMessages(pcmWatchdogToken)
        try { audioRecord?.stop() } catch (_: Exception) {}
        try { audioRecord?.release() } catch (_: Exception) {}
        audioRecord = null
        captureThread?.interrupt()
        captureThread = null
    }

    private fun debugPrint(message: String) { android.util.Log.d("HumSukhanEnv", message) }

    private fun stopMonitoring() {
        if (stopping) return
        stopping = true
        EnvironmentalMonitoringState.set(this, EnvironmentalMonitoringState.STOPPING)
        stopNativeAudioCapture()
        try { channel?.invokeMethod("stop", null) } catch (_: Exception) {}
        mainHandler.postDelayed({ cleanupAndStop() }, 500L)
    }

    private fun cleanupAndStop() {
        mainHandler.removeCallbacksAndMessages(null)
        stopNativeAudioCapture()
        channel = null
        engine?.destroy()
        engine = null
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) stopForeground(STOP_FOREGROUND_REMOVE) else { @Suppress("DEPRECATION") stopForeground(true) }
        EnvironmentalMonitoringState.set(this, EnvironmentalMonitoringState.OFF)
        stopping = false
        stopSelf()
    }

    private fun handleSoundEvent(type: String, confidence: Double, severity: String) {
        if (EnvironmentalMonitoringState.get(this) != EnvironmentalMonitoringState.ACTIVE) return
        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(NOTIFICATION_ID, buildMonitoringNotification("$type detected • local/offline"))
        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) getSystemService(VibratorManager::class.java).defaultVibrator else { @Suppress("DEPRECATION") getSystemService(VIBRATOR_SERVICE) as Vibrator }
        val duration = if (severity == "critical") 700L else 250L
        vibrator.vibrate(VibrationEffect.createOneShot(duration, VibrationEffect.DEFAULT_AMPLITUDE))
        sendBroadcast(Intent(EnvironmentalMonitoringState.ACTION_STATE).setPackage(packageName)
            .putExtra(EnvironmentalMonitoringState.EXTRA_STATE, EnvironmentalMonitoringState.ACTIVE)
            .putExtra(EnvironmentalMonitoringState.EXTRA_EVENT, JSONObject().put("type", type).put("confidence", confidence).put("severity", severity).toString()))
    }

    private fun buildMonitoringNotification(text: String): Notification {
        val stopIntent = Intent(this, EnvironmentalMonitoringService::class.java).setAction(EnvironmentalMonitoringState.ACTION_STOP)
        val stopPendingIntent = PendingIntent.getService(this, 4108, stopIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val openIntent = Intent(this, MainActivity::class.java)
        val openPendingIntent = PendingIntent.getActivity(this, 4109, openIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentTitle("HumSukhan Environmental Monitoring")
            .setContentText(text)
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(openPendingIntent)
            .addAction(android.R.drawable.ic_media_pause, "Stop", stopPendingIntent)
            .build()
    }

    private fun updateMonitoringNotification(state: String) {
        val text = when (state) {
            EnvironmentalMonitoringState.ACTIVE -> "Environmental monitoring: Offline / Local"
            EnvironmentalMonitoringState.ERROR -> "Environmental monitoring: unavailable"
            EnvironmentalMonitoringState.STARTING -> "Environmental monitoring: starting"
            else -> "Environmental monitoring: $state"
        }
        getSystemService(NotificationManager::class.java).notify(NOTIFICATION_ID, buildMonitoringNotification(text))
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL_ID, "Environmental Monitoring", NotificationManager.IMPORTANCE_LOW)
            channel.description = "Shows when HumSukhan is actively monitoring environmental sounds."
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    override fun onTaskRemoved(rootIntent: Intent?) { super.onTaskRemoved(rootIntent) }

    override fun onDestroy() {
        mainHandler.removeCallbacksAndMessages(null)
        stopNativeAudioCapture()
        channel = null
        engine?.destroy()
        engine = null
        if (EnvironmentalMonitoringState.get(this) != EnvironmentalMonitoringState.OFF) EnvironmentalMonitoringState.set(this, EnvironmentalMonitoringState.OFF)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
