package com.footballtracker.wearos.sync

import android.content.Context
import com.footballtracker.core.model.TrackPoint
import com.google.android.gms.wearable.DataClient
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable
import kotlinx.coroutines.tasks.await

/**
 * Syncs recorded session data from Wear OS watch to the paired Android phone
 * using the Wearable Data Layer API.
 */
class DataLayerSync(private val context: Context) {

    private val dataClient: DataClient = Wearable.getDataClient(context)

    /**
     * Send session data to the phone app.
     */
    suspend fun syncSession(
        sessionId: String,
        startTime: Long,
        endTime: Long,
        trackPoints: List<TrackPoint>,
        heartRateData: List<Pair<Long, Int>>
    ) {
        val putDataMapReq = PutDataMapRequest.create("/football_session/$sessionId").apply {
            dataMap.apply {
                putString("session_id", sessionId)
                putLong("start_time", startTime)
                putLong("end_time", endTime)
                putLong("sync_time", System.currentTimeMillis())

                // Serialize track points as parallel arrays for efficiency
                putFloatArray("latitudes", trackPoints.map { it.latitude.toFloat() }.toFloatArray())
                putFloatArray("longitudes", trackPoints.map { it.longitude.toFloat() }.toFloatArray())
                putLongArray("timestamps", trackPoints.map { it.timestamp }.toLongArray())
                putFloatArray("speeds", trackPoints.map { it.speed.toFloat() }.toFloatArray())
                putFloatArray("accuracies", trackPoints.map { it.accuracy }.toFloatArray())

                // Heart rate data
                putLongArray("hr_timestamps", heartRateData.map { it.first }.toLongArray())
                putIntegerArrayList("hr_values", ArrayList(heartRateData.map { it.second }))
            }
        }

        val putDataReq = putDataMapReq.asPutDataRequest().setUrgent()
        dataClient.putDataItem(putDataReq).await()
    }
}
