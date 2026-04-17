package com.footballtracker.wearos.sync

import android.content.Context
import android.content.Intent
import android.util.Log
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService

/**
 * Listens for start/stop commands from the paired phone via MessageClient.
 * When the phone sends "/start_tracking", the watch auto-starts GPS + HR.
 * When the phone sends "/stop_tracking", the watch auto-stops and syncs data back.
 */
class PhoneCommandReceiver : WearableListenerService() {

    companion object {
        const val TAG = "PhoneCommandReceiver"
        const val PATH_START = "/start_tracking"
        const val PATH_STOP = "/stop_tracking"

        // Broadcast actions for MainActivity to receive
        const val ACTION_REMOTE_START = "com.footballtracker.wearos.REMOTE_START"
        const val ACTION_REMOTE_STOP = "com.footballtracker.wearos.REMOTE_STOP"
    }

    override fun onMessageReceived(messageEvent: MessageEvent) {
        Log.d(TAG, "Message received: ${messageEvent.path}")

        when (messageEvent.path) {
            PATH_START -> {
                // Notify MainActivity to start tracking
                val intent = Intent(ACTION_REMOTE_START)
                intent.setPackage(packageName)
                sendBroadcast(intent)
                Log.d(TAG, "Sent REMOTE_START broadcast")
            }
            PATH_STOP -> {
                // Notify MainActivity to stop tracking
                val intent = Intent(ACTION_REMOTE_STOP)
                intent.setPackage(packageName)
                sendBroadcast(intent)
                Log.d(TAG, "Sent REMOTE_STOP broadcast")
            }
        }
    }
}
