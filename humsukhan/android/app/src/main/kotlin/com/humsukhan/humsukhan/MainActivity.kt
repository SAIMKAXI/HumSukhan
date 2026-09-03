package com.humsukhan.humsukhan

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        const val EXTRA_REQUEST_ENVIRONMENTAL_PERMISSION = "request_environmental_permission"
        private const val ENV_CHANNEL = "com.humsukhan/environmental_monitor"
        private const val ENV_EVENTS = "com.humsukhan/environmental_monitor/events"
        private const val ENV_PERMISSION_REQUEST = 8401
    }

    private val FLASH_CHANNEL = "com.humsukhan.flashlight"
    private var cameraManager: CameraManager? = null
    private var cameraId: String? = null
    private var isTorchOn = false
    private var eventSink: EventChannel.EventSink? = null
    private var receiverRegistered = false

    private val environmentalReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action != EnvironmentalMonitoringState.ACTION_STATE) return
            val payload = mutableMapOf<String, Any?>()
            payload["state"] = intent.getStringExtra(EnvironmentalMonitoringState.EXTRA_STATE)
            payload["event"] = intent.getStringExtra(EnvironmentalMonitoringState.EXTRA_EVENT)
            runOnUiThread { eventSink?.success(payload) }
        }
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        maybeRequestEnvironmentalPermission(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        maybeRequestEnvironmentalPermission(intent)
    }

    private fun maybeRequestEnvironmentalPermission(intent: Intent?) {
        if (intent?.getBooleanExtra(EXTRA_REQUEST_ENVIRONMENTAL_PERMISSION, false) == true) {
            if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
                requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), ENV_PERMISSION_REQUEST)
            } else {
                EnvironmentalMonitoringState.requestStart(this)
            }
            intent.removeExtra(EXTRA_REQUEST_ENVIRONMENTAL_PERMISSION)
        }
    }

    private fun registerEnvironmentalReceiver() {
        if (receiverRegistered) return
        val filter = IntentFilter(EnvironmentalMonitoringState.ACTION_STATE)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(environmentalReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                @Suppress("DEPRECATION")
                registerReceiver(environmentalReceiver, filter)
            }
            receiverRegistered = true
        } catch (e: Exception) {
            receiverRegistered = false
            e.printStackTrace()
        }
    }

    private fun unregisterEnvironmentalReceiver() {
        if (!receiverRegistered) return
        try {
            unregisterReceiver(environmentalReceiver)
        } catch (e: IllegalArgumentException) {
            e.printStackTrace()
        } finally {
            receiverRegistered = false
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == ENV_PERMISSION_REQUEST) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                EnvironmentalMonitoringState.requestStart(this)
            } else {
                EnvironmentalMonitoringState.set(this, EnvironmentalMonitoringState.ERROR)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        try {
            cameraManager = getSystemService(Context.CAMERA_SERVICE) as? CameraManager
            cameraId = findTorchCameraId(cameraManager)
        } catch (e: Exception) {
            e.printStackTrace()
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FLASH_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "turnOn" -> { turnOnTorch(); result.success(true) }
                    "turnOff" -> { turnOffTorch(); result.success(true) }
                    "isAvailable" -> result.success(cameraId != null)
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ENV_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getState" -> result.success(EnvironmentalMonitoringState.get(this))
                    "start" -> {
                        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
                            result.error("MIC_PERMISSION", "Microphone permission is required", null)
                        } else {
                            EnvironmentalMonitoringState.requestStart(this)
                            result.success(true)
                        }
                    }
                    "stop" -> {
                        EnvironmentalMonitoringState.requestStop(this)
                        result.success(true)
                    }
                    "isSupported" -> result.success(true)
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, ENV_EVENTS)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    registerEnvironmentalReceiver()
                    eventSink?.success(mapOf("state" to EnvironmentalMonitoringState.get(this@MainActivity)))
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    unregisterEnvironmentalReceiver()
                }
            })
    }

    private fun findTorchCameraId(manager: CameraManager?): String? {
        if (manager == null) return null
        for (id in manager.cameraIdList) {
            try {
                val characteristics = manager.getCameraCharacteristics(id)
                val flashAvailable = characteristics.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
                val lensFacing = characteristics.get(CameraCharacteristics.LENS_FACING)
                if (flashAvailable && lensFacing != CameraCharacteristics.LENS_FACING_FRONT) {
                    return id
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        // Some devices expose only a front-facing flash-capable camera. Prefer
        // it over reporting a false "available" state when no rear torch exists.
        for (id in manager.cameraIdList) {
            try {
                val characteristics = manager.getCameraCharacteristics(id)
                if (characteristics.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true) {
                    return id
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
        return null
    }

    private fun turnOnTorch() {
        try {
            if (cameraId != null && !isTorchOn) {
                cameraManager?.setTorchMode(cameraId!!, true)
                isTorchOn = true
            }
        } catch (e: Exception) { e.printStackTrace() }
    }

    private fun turnOffTorch() {
        try {
            if (cameraId != null && isTorchOn) {
                cameraManager?.setTorchMode(cameraId!!, false)
                isTorchOn = false
            }
        } catch (e: Exception) { e.printStackTrace() }
    }

    override fun onDestroy() {
        unregisterEnvironmentalReceiver()
        turnOffTorch()
        super.onDestroy()
    }
}
