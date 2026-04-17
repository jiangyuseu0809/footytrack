package com.footballtracker.android.sync

import android.content.Context
import android.util.Log
import com.google.android.gms.wearable.MessageClient
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.Wearable
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.tasks.await

/**
 * Controls the Wear OS watch from the phone.
 * Sends start/stop commands and listens for status updates.
 */
class WatchController(private val context: Context) {

    companion object {
        private const val TAG = "WatchController"
        const val PATH_START = "/start_tracking"
        const val PATH_STOP = "/stop_tracking"
    }

    enum class WatchStatus {
        DISCONNECTED, CONNECTED, TRACKING, STOPPED
    }

    private val messageClient: MessageClient = Wearable.getMessageClient(context)
    private val nodeClient = Wearable.getNodeClient(context)

    private val _watchStatus = MutableStateFlow(WatchStatus.DISCONNECTED)
    val watchStatus: StateFlow<WatchStatus> = _watchStatus.asStateFlow()

    private val _connectedWatchName = MutableStateFlow<String?>(null)
    val connectedWatchName: StateFlow<String?> = _connectedWatchName.asStateFlow()

    private val messageListener = MessageClient.OnMessageReceivedListener { event ->
        handleMessage(event)
    }

    fun startListening() {
        messageClient.addListener(messageListener)
        checkConnection()
    }

    fun stopListening() {
        messageClient.removeListener(messageListener)
    }

    private fun checkConnection() {
        nodeClient.connectedNodes.addOnSuccessListener { nodes ->
            if (nodes.isNotEmpty()) {
                _watchStatus.value = WatchStatus.CONNECTED
                _connectedWatchName.value = nodes.first().displayName
                Log.d(TAG, "Watch connected: ${nodes.first().displayName}")
            } else {
                _watchStatus.value = WatchStatus.DISCONNECTED
                _connectedWatchName.value = null
            }
        }
    }

    suspend fun sendStartTracking(): Boolean {
        return sendMessage(PATH_START)
    }

    suspend fun sendStopTracking(): Boolean {
        return sendMessage(PATH_STOP)
    }

    private suspend fun sendMessage(path: String): Boolean {
        return try {
            val nodes = nodeClient.connectedNodes.await()
            if (nodes.isEmpty()) {
                Log.w(TAG, "No connected watch found")
                _watchStatus.value = WatchStatus.DISCONNECTED
                return false
            }
            for (node in nodes) {
                messageClient.sendMessage(node.id, path, byteArrayOf()).await()
                Log.d(TAG, "Sent $path to ${node.displayName}")
            }
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to send message: $path", e)
            false
        }
    }

    private fun handleMessage(event: MessageEvent) {
        Log.d(TAG, "Received message: ${event.path}")
        when (event.path) {
            "/tracking_started" -> _watchStatus.value = WatchStatus.TRACKING
            "/tracking_stopped" -> _watchStatus.value = WatchStatus.STOPPED
        }
    }

    suspend fun refreshConnection() {
        try {
            val nodes = nodeClient.connectedNodes.await()
            if (nodes.isNotEmpty()) {
                _watchStatus.value = if (_watchStatus.value == WatchStatus.TRACKING) {
                    WatchStatus.TRACKING
                } else {
                    WatchStatus.CONNECTED
                }
                _connectedWatchName.value = nodes.first().displayName
            } else {
                _watchStatus.value = WatchStatus.DISCONNECTED
                _connectedWatchName.value = null
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to check connection", e)
            _watchStatus.value = WatchStatus.DISCONNECTED
        }
    }
}
