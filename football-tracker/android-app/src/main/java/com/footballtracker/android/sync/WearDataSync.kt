package com.footballtracker.android.sync

import com.footballtracker.android.FootballTrackerApp
import com.footballtracker.core.model.TrackPoint
import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.WearableListenerService
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * Receives synced session data from the Wear OS watch via Data Layer API.
 */
class WearDataSync : WearableListenerService() {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    override fun onDataChanged(dataEvents: DataEventBuffer) {
        val container = (application as FootballTrackerApp).appContainer
        val repo = container.sessionRepo
        val authRepo = container.authRepository
        val cloudSync = container.cloudSync

        for (event in dataEvents) {
            if (event.type != DataEvent.TYPE_CHANGED) continue
            val path = event.dataItem.uri.path ?: continue
            if (!path.startsWith("/football_session/")) continue

            val dataMap = DataMapItem.fromDataItem(event.dataItem).dataMap

            val sessionId = dataMap.getString("session_id") ?: continue
            val startTime = dataMap.getLong("start_time")
            val endTime = dataMap.getLong("end_time")

            val latitudes = dataMap.getFloatArray("latitudes")?.map { it.toDouble() }?.toDoubleArray() ?: continue
            val longitudes = dataMap.getFloatArray("longitudes")?.map { it.toDouble() }?.toDoubleArray() ?: continue
            val timestamps = dataMap.getLongArray("timestamps") ?: continue
            val speeds = dataMap.getFloatArray("speeds") ?: continue
            val accuracies = dataMap.getFloatArray("accuracies") ?: continue

            val hrTimestamps = dataMap.getLongArray("hr_timestamps") ?: longArrayOf()
            val hrValues = dataMap.getIntegerArrayList("hr_values") ?: arrayListOf()

            // Reconstruct track points, merging HR data by closest timestamp
            val trackPoints = latitudes.indices.map { i: Int ->
                val ts = timestamps[i]
                val closestHr = findClosestHr(ts, hrTimestamps, hrValues)
                TrackPoint(
                    timestamp = ts,
                    latitude = latitudes[i],
                    longitude = longitudes[i],
                    speed = speeds[i].toDouble(),
                    heartRate = closestHr,
                    accuracy = accuracies[i]
                )
            }

            val uid = authRepo.currentUser.value?.uid

            scope.launch {
                // Save to local Room DB
                repo.saveSession(sessionId, startTime, endTime, trackPoints, ownerUid = uid)

                // Upload to cloud server if logged in
                if (uid != null) {
                    try {
                        val saved = repo.getSessionDao().getSession(sessionId)
                        if (saved != null) {
                            cloudSync.uploadSession(saved)
                        }
                    } catch (_: Exception) {
                        // Cloud upload failed silently; will retry on next sync
                    }
                }
            }
        }
    }

    private fun findClosestHr(
        targetTs: Long,
        hrTimestamps: LongArray,
        hrValues: ArrayList<Int>
    ): Int {
        if (hrTimestamps.isEmpty()) return 0
        var bestIdx = 0
        var bestDiff = Long.MAX_VALUE
        for (i in hrTimestamps.indices) {
            val diff = kotlin.math.abs(hrTimestamps[i] - targetTs)
            if (diff < bestDiff) {
                bestDiff = diff
                bestIdx = i
            }
        }
        // Only use HR if within 5 seconds
        return if (bestDiff < 5000) hrValues.getOrElse(bestIdx) { 0 } else 0
    }
}
