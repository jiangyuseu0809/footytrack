package com.footballtracker.wearos.tracking

import android.content.Context
import androidx.health.services.client.HealthServices
import androidx.health.services.client.MeasureCallback
import androidx.health.services.client.data.Availability
import androidx.health.services.client.data.DataPointContainer
import androidx.health.services.client.data.DataType
import androidx.health.services.client.data.DeltaDataType
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/**
 * Collects heart rate data using Health Services API on Wear OS.
 */
class HeartRateTracker(context: Context) {

    private val healthClient = HealthServices.getClient(context)
    private val measureClient = healthClient.measureClient

    private val _heartRate = MutableStateFlow(0)
    val heartRate: StateFlow<Int> = _heartRate

    private val _heartRateHistory = MutableStateFlow<List<Pair<Long, Int>>>(emptyList())
    val heartRateHistory: StateFlow<List<Pair<Long, Int>>> = _heartRateHistory

    private val callback = object : MeasureCallback {
        override fun onAvailabilityChanged(
            dataType: DeltaDataType<*, *>,
            availability: Availability
        ) {
            // Availability changes can be logged if needed
        }

        override fun onDataReceived(data: DataPointContainer) {
            val heartRatePoints = data.getData(DataType.HEART_RATE_BPM)
            for (point in heartRatePoints) {
                val bpm = point.value.toInt()
                _heartRate.value = bpm
                _heartRateHistory.value = _heartRateHistory.value +
                        (System.currentTimeMillis() to bpm)
            }
        }
    }

    suspend fun startMonitoring() {
        measureClient.registerMeasureCallback(DataType.HEART_RATE_BPM, callback)
    }

    suspend fun stopMonitoring() {
        measureClient.unregisterMeasureCallback(DataType.HEART_RATE_BPM, callback)
    }

    fun reset() {
        _heartRate.value = 0
        _heartRateHistory.value = emptyList()
    }
}
