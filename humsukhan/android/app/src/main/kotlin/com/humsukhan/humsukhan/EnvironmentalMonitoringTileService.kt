package com.humsukhan.humsukhan

import android.Manifest
import android.app.PendingIntent
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.drawable.Icon
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService

class EnvironmentalMonitoringTileService : TileService() {
    override fun onStartListening() {
        super.onStartListening()
        syncTile()
    }

    override fun onClick() {
        super.onClick()
        val monitoringState = EnvironmentalMonitoringState.get(this)
        if (monitoringState == EnvironmentalMonitoringState.ACTIVE ||
            monitoringState == EnvironmentalMonitoringState.STARTING) {
            EnvironmentalMonitoringState.requestStop(this)
            syncTile()
            return
        }

        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            val intent = Intent(this, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                .putExtra(MainActivity.EXTRA_REQUEST_ENVIRONMENTAL_PERMISSION, true)
            val pending = PendingIntent.getActivity(
                this, 4201, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startActivityAndCollapse(pending)
            } else {
                @Suppress("DEPRECATION") startActivityAndCollapse(intent)
            }
            return
        }

        EnvironmentalMonitoringState.requestStart(this)
        syncTile()
    }

    override fun onTileAdded() {
        super.onTileAdded()
        syncTile()
    }

    private fun syncTile() {
        val monitoringState = EnvironmentalMonitoringState.get(this)
        qsTile?.apply {
            label = "Environmental"
            this.state = if (monitoringState == EnvironmentalMonitoringState.ACTIVE ||
                monitoringState == EnvironmentalMonitoringState.STARTING) {
                Tile.STATE_ACTIVE
            } else {
                Tile.STATE_INACTIVE
            }
            icon = Icon.createWithResource(this@EnvironmentalMonitoringTileService, android.R.drawable.ic_btn_speak_now)
            updateTile()
        }
    }

    companion object {
        fun requestUpdate(context: android.content.Context) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                TileService.requestListeningState(
                    context,
                    ComponentName(context, EnvironmentalMonitoringTileService::class.java)
                )
            }
        }
    }
}
