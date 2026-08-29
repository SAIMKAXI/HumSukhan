package com.humsukhan.humsukhan

import android.content.Context
import android.content.pm.PackageManager
import android.hardware.camera2.CameraManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.humsukhan.flashlight"
    private var cameraManager: CameraManager? = null
    private var cameraId: String? = null
    private var isTorchOn = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Initialize camera manager for flashlight
        try {
            cameraManager = getSystemService(Context.CAMERA_SERVICE) as? CameraManager
            cameraId = cameraManager?.cameraIdList?.firstOrNull()
        } catch (e: Exception) {
            e.printStackTrace()
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "turnOn" -> {
                        turnOnTorch()
                        result.success(true)
                    }
                    "turnOff" -> {
                        turnOffTorch()
                        result.success(true)
                    }
                    "isAvailable" -> {
                        val hasFlash = packageManager
                            .hasSystemFeature(PackageManager.FEATURE_CAMERA_FLASH)
                        result.success(hasFlash)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun turnOnTorch() {
        try {
            if (cameraId != null && !isTorchOn) {
                cameraManager?.setTorchMode(cameraId!!, true)
                isTorchOn = true
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun turnOffTorch() {
        try {
            if (cameraId != null && isTorchOn) {
                cameraManager?.setTorchMode(cameraId!!, false)
                isTorchOn = false
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onDestroy() {
        turnOffTorch()
        super.onDestroy()
    }
}
