package com.footballtracker.wearos.sync

import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.WearableListenerService
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * Listens for auth token sent from the Android phone app via the Wearable Data Layer.
 * The phone app sends the JWT token after login so the watch can upload directly to the server.
 */
class WatchAuthReceiver : WearableListenerService() {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    override fun onDataChanged(dataEvents: DataEventBuffer) {
        for (event in dataEvents) {
            if (event.type == DataEvent.TYPE_CHANGED) {
                val path = event.dataItem.uri.path ?: continue
                if (path == "/auth_token") {
                    val dataMap = DataMapItem.fromDataItem(event.dataItem).dataMap
                    val token = dataMap.getString("token", "")
                    val uid = dataMap.getString("uid", "")

                    val serverSync = ServerSync(applicationContext)
                    if (token.isNotEmpty()) {
                        serverSync.token = token
                        serverSync.uid = uid

                        // Flush any queued sessions
                        scope.launch {
                            val synced = serverSync.flushQueue()
                            if (synced > 0) {
                                android.util.Log.d("WatchAuthReceiver", "Flushed $synced queued sessions")
                            }
                        }
                    } else {
                        // Logout — clear token
                        serverSync.token = null
                        serverSync.uid = null
                    }
                }
            }
        }
    }
}
