package com.footballtracker.wearos.tracking

import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.os.Looper
import com.footballtracker.core.model.TrackPoint
import com.google.android.gms.location.*
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow

/**
 * Foreground service that collects GPS data at 1Hz for football tracking.
 */
class GpsTracker : Service() {

    private val job = SupervisorJob()
    private val scope = CoroutineScope(Dispatchers.Default + job)

    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private lateinit var locationCallback: LocationCallback

    private val _trackPoints = MutableStateFlow<List<TrackPoint>>(emptyList())
    val trackPoints: StateFlow<List<TrackPoint>> = _trackPoints

    private val _currentSpeed = MutableStateFlow(0.0)
    val currentSpeed: StateFlow<Double> = _currentSpeed

    private val _totalDistance = MutableStateFlow(0.0)
    val totalDistance: StateFlow<Double> = _totalDistance

    private var lastPoint: TrackPoint? = null

    override fun onCreate() {
        super.onCreate()
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> startTracking()
            ACTION_STOP -> stopTracking()
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    @SuppressLint("MissingPermission")
    private fun startTracking() {
        val notification = Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("踢球记录中")
            .setContentText("正在记录 GPS 轨迹")
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setOngoing(true)
            .build()

        startForeground(NOTIFICATION_ID, notification)

        val locationRequest = LocationRequest.Builder(
            Priority.PRIORITY_HIGH_ACCURACY, 1000L
        ).setMinUpdateIntervalMillis(1000L).build()

        locationCallback = object : LocationCallback() {
            override fun onLocationResult(result: LocationResult) {
                for (location in result.locations) {
                    // Filter low-accuracy points
                    if (location.accuracy > 15f) continue

                    val point = TrackPoint(
                        timestamp = location.time,
                        latitude = location.latitude,
                        longitude = location.longitude,
                        speed = location.speed.toDouble(),
                        accuracy = location.accuracy
                    )

                    // Update total distance
                    lastPoint?.let { prev ->
                        val segDist = com.footballtracker.core.util.GeoUtils.haversineDistance(
                            prev.latitude, prev.longitude,
                            point.latitude, point.longitude
                        )
                        _totalDistance.value += segDist
                    }

                    _currentSpeed.value = location.speed.toDouble()
                    _trackPoints.value = _trackPoints.value + point
                    lastPoint = point
                }
            }
        }

        fusedLocationClient.requestLocationUpdates(
            locationRequest, locationCallback, Looper.getMainLooper()
        )
    }

    private fun stopTracking() {
        fusedLocationClient.removeLocationUpdates(locationCallback)
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        job.cancel()
        super.onDestroy()
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "踢球记录",
            NotificationManager.IMPORTANCE_LOW
        )
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    fun getCollectedPoints(): List<TrackPoint> = _trackPoints.value

    fun reset() {
        _trackPoints.value = emptyList()
        _totalDistance.value = 0.0
        _currentSpeed.value = 0.0
        lastPoint = null
    }

    companion object {
        const val ACTION_START = "ACTION_START_TRACKING"
        const val ACTION_STOP = "ACTION_STOP_TRACKING"
        const val CHANNEL_ID = "football_tracking"
        const val NOTIFICATION_ID = 1001
    }
}
