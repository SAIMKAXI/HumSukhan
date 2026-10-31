package com.humsukhan.humsukhan

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

/**
 * Owns the microphone for environmental monitoring, as a foreground service
 * so it keeps listening while the app is closed.
 *
 * Start-up order, each step gated on the one before:
 *  1. foreground notification, state STARTING;
 *  2. a headless Flutter engine runs `environmentalMonitoringBackgroundMain`,
 *     which loads the sound model and answers READY;
 *  3. only then is the microphone opened, and PCM streamed to Dart;
 *  4. Dart confirms it is receiving audio (PCM_FLOWING), and only then is the
 *     state ACTIVE.
 *
 * Detection, history, notifications and vibration all happen in Dart; this
 * class captures audio and keeps the lifecycle honest. Every failure tears the
 * whole service down and reports ERROR with a code, so a half-running monitor
 * can never sit behind a notification claiming it is listening.
 */
class EnvironmentalMonitoringService : Service() {
    companion object {
        const val CHANNEL_ID = "environmental_monitoring"
        const val NOTIFICATION_ID = 4107
        private const val METHOD_CHANNEL = "com.humsukhan/environmental_monitor"
        private const val DART_ENTRYPOINT = "environmentalMonitoringBackgroundMain"
        private const val SAMPLE_RATE = 16000
        private const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
        private const val AUDIO_ENCODING = AudioFormat.ENCODING_PCM_16BIT

        /** From the start request to Dart confirming audio. */
        private const val START_TIMEOUT_MS = 15000L

        /** Longest gap in microphone audio before monitoring is declared lost. */
        private const val STALL_TIMEOUT_MS = 5000L
        private const val STALL_CHECK_INTERVAL_MS = 2000L

        /** How long Dart gets to free the sound model before its engine is destroyed. */
        private const val ENGINE_RELEASE_TIMEOUT_MS = 1000L
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var engine: FlutterEngine? = null
    private var channel: MethodChannel? = null

    /** Between start() and teardown(). Main thread only. */
    private var running = false

    @Volatile private var capturing = false
    @Volatile private var lastPcmAtMs = 0L
    private var audioRecord: AudioRecord? = null
    private var captureThread: Thread? = null

    private val startTimeout = Runnable {
        if (running && EnvironmentalMonitoringState.get(this) != EnvironmentalMonitoringState.ACTIVE) {
            log("Environmental monitoring did not confirm audio in time")
            fail(EnvironmentalMonitoringState.ERROR_SERVICE)
        }
    }

    private val stallCheck = object : Runnable {
        override fun run() {
            if (!running) return
            if (!capturing || System.currentTimeMillis() - lastPcmAtMs > STALL_TIMEOUT_MS) {
                log("Environmental microphone audio stopped arriving")
                fail(EnvironmentalMonitoringState.ERROR_CAPTURE)
                return
            }
            mainHandler.postDelayed(this, STALL_CHECK_INTERVAL_MS)
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            EnvironmentalMonitoringState.ACTION_START -> start()
            EnvironmentalMonitoringState.ACTION_STOP -> {
                stop()
                return START_NOT_STICKY
            }
            // A sticky restart after the system killed the process: resume
            // only if the user had monitoring on.
            else -> if (EnvironmentalMonitoringState.isWanted(this)) start() else {
                stopSelf()
                return START_NOT_STICKY
            }
        }
        return START_STICKY
    }

    private fun start() {
        if (running) return
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            fail(EnvironmentalMonitoringState.ERROR_MIC_PERMISSION)
            return
        }
        running = true
        EnvironmentalMonitoringState.set(this, EnvironmentalMonitoringState.STARTING)
        try {
            val notification = buildNotification(EnvironmentalMonitoringState.STARTING)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                ServiceCompat.startForeground(this, NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE)
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            log("Environmental foreground service refused: $e")
            fail(EnvironmentalMonitoringState.ERROR_SERVICE)
            return
        }
        mainHandler.postDelayed(startTimeout, START_TIMEOUT_MS)
        if (!startEngine()) fail(EnvironmentalMonitoringState.ERROR_SERVICE)
    }

    private fun stop() {
        EnvironmentalMonitoringState.setWanted(this, false)
        if (running) {
            EnvironmentalMonitoringState.set(this, EnvironmentalMonitoringState.STOPPING)
            teardown()
        }
        if (EnvironmentalMonitoringState.get(this) != EnvironmentalMonitoringState.ERROR) {
            EnvironmentalMonitoringState.set(this, EnvironmentalMonitoringState.OFF)
        }
        stopSelf()
    }

    private fun fail(code: String) {
        EnvironmentalMonitoringState.setWanted(this, false)
        teardown()
        EnvironmentalMonitoringState.set(this, EnvironmentalMonitoringState.ERROR, code)
        stopSelf()
    }

    /** Releases everything this service holds. Safe to call more than once. */
    private fun teardown() {
        running = false
        mainHandler.removeCallbacks(startTimeout)
        mainHandler.removeCallbacks(stallCheck)
        stopCapture()
        releaseEngine()
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
    }

    /**
     * The model lives in native memory the Dart isolate does not free when the
     * engine is destroyed, so Dart is asked to release it first. The
     * microphone is already closed; only the engine waits.
     */
    private fun releaseEngine() {
        val oldEngine = engine ?: return
        val oldChannel = channel
        engine = null
        channel = null
        var destroyed = false
        val destroy = {
            if (!destroyed) {
                destroyed = true
                oldChannel?.setMethodCallHandler(null)
                oldEngine.destroy()
            }
        }
        if (oldChannel == null) {
            destroy()
            return
        }
        try {
            oldChannel.invokeMethod("stop", null, object : MethodChannel.Result {
                override fun success(result: Any?) = destroy()
                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) = destroy()
                override fun notImplemented() = destroy()
            })
        } catch (_: Exception) {
            destroy()
            return
        }
        mainHandler.postDelayed({ destroy() }, ENGINE_RELEASE_TIMEOUT_MS)
    }

    private fun startEngine(): Boolean = try {
        val loader = FlutterInjector.instance().flutterLoader()
        loader.startInitialization(applicationContext)
        loader.ensureInitializationComplete(applicationContext, emptyArray())
        val flutterEngine = FlutterEngine(applicationContext)
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        engine = flutterEngine
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).also {
            it.setMethodCallHandler { call, result ->
                when (call.method) {
                    "pipelineState" -> {
                        onPipelineState(call.argument<String>("state"), call.argument<String>("error"))
                        result.success(true)
                    }
                    "event" -> {
                        val event = call.argument<String>("event")
                        if (running && event != null) EnvironmentalMonitoringState.broadcastAlert(this, event)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        }
        flutterEngine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint(loader.findAppBundlePath(), DART_ENTRYPOINT),
        )
        true
    } catch (e: Exception) {
        log("Environmental Flutter engine could not start: $e")
        false
    }

    /**
     * Failures are posted rather than handled inline: they destroy the engine,
     * which must not happen inside one of its own method calls.
     */
    private fun onPipelineState(state: String?, error: String?) {
        if (!running) return
        when (state) {
            "READY" -> if (!startCapture()) {
                mainHandler.post { if (running) fail(EnvironmentalMonitoringState.ERROR_CAPTURE) }
            }
            "PCM_FLOWING" -> if (capturing) {
                mainHandler.removeCallbacks(startTimeout)
                EnvironmentalMonitoringState.setWanted(this, true)
                EnvironmentalMonitoringState.set(this, EnvironmentalMonitoringState.ACTIVE)
                updateNotification(EnvironmentalMonitoringState.ACTIVE)
                mainHandler.removeCallbacks(stallCheck)
                mainHandler.postDelayed(stallCheck, STALL_CHECK_INTERVAL_MS)
            }
            "ERROR" -> mainHandler.post {
                if (running) fail(error ?: EnvironmentalMonitoringState.ERROR_SERVICE)
            }
        }
    }

    private fun startCapture(): Boolean {
        if (capturing) return true
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) return false
        val minBuffer = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_ENCODING)
        if (minBuffer <= 0) return false
        val bufferSize = maxOf(minBuffer * 2, 8192)
        val recorder = try {
            AudioRecord(MediaRecorder.AudioSource.MIC, SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_ENCODING, bufferSize)
        } catch (e: Exception) {
            log("Environmental AudioRecord could not be created: $e")
            return false
        }
        try {
            if (recorder.state != AudioRecord.STATE_INITIALIZED) throw IllegalStateException("AudioRecord not initialized")
            recorder.startRecording()
            if (recorder.recordingState != AudioRecord.RECORDSTATE_RECORDING) throw IllegalStateException("AudioRecord not recording")
        } catch (e: Exception) {
            log("Environmental AudioRecord could not start: $e")
            try { recorder.release() } catch (_: Exception) {}
            return false
        }

        audioRecord = recorder
        lastPcmAtMs = System.currentTimeMillis()
        capturing = true
        captureThread = Thread {
            val pcm = ByteArray(bufferSize)
            try {
                while (capturing) {
                    val count = recorder.read(pcm, 0, pcm.size)
                    if (count < 0) {
                        log("Environmental AudioRecord read error: $count")
                        break
                    }
                    if (count == 0 || !capturing) continue
                    lastPcmAtMs = System.currentTimeMillis()
                    val payload = pcm.copyOf(count)
                    // Flutter channels must be called on the main thread.
                    mainHandler.post { if (capturing) channel?.invokeMethod("audioData", payload) }
                }
            } catch (e: Exception) {
                log("Environmental audio capture failed: $e")
            } finally {
                try { recorder.release() } catch (_: Exception) {}
                if (capturing) {
                    // The loop ended without being asked to.
                    mainHandler.post { if (running) fail(EnvironmentalMonitoringState.ERROR_CAPTURE) }
                }
            }
        }.also {
            it.name = "HumSukhan-EnvironmentalAudio"
            it.start()
        }
        return true
    }

    /** Stopping the recorder unblocks the capture thread, which then releases it. */
    private fun stopCapture() {
        capturing = false
        val recorder = audioRecord
        audioRecord = null
        try { recorder?.stop() } catch (_: Exception) {}
        captureThread?.interrupt()
        captureThread = null
    }

    private fun buildNotification(state: String): Notification {
        val strings = NativeStrings(this)
        val text = when (state) {
            EnvironmentalMonitoringState.ACTIVE -> strings.monitoringActive
            else -> strings.monitoringStarting
        }
        val stopIntent = Intent(this, EnvironmentalMonitoringService::class.java).setAction(EnvironmentalMonitoringState.ACTION_STOP)
        val stopPendingIntent = PendingIntent.getService(this, 4108, stopIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val openIntent = Intent(this, MainActivity::class.java)
        val openPendingIntent = PendingIntent.getActivity(this, 4109, openIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentTitle(strings.monitoringTitle)
            .setContentText(text)
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(openPendingIntent)
            .addAction(android.R.drawable.ic_media_pause, strings.stop, stopPendingIntent)
            .build()
    }

    private fun updateNotification(state: String) {
        getSystemService(NotificationManager::class.java).notify(NOTIFICATION_ID, buildNotification(state))
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val strings = NativeStrings(this)
            val channel = NotificationChannel(CHANNEL_ID, strings.channelName, NotificationManager.IMPORTANCE_LOW)
            channel.description = strings.channelDescription
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    private fun log(message: String) {
        android.util.Log.d("HumSukhanEnv", message)
    }

    override fun onDestroy() {
        if (running) {
            teardown()
            EnvironmentalMonitoringState.set(this, EnvironmentalMonitoringState.OFF)
        }
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
