package com.footballtracker.wearos

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.*
import androidx.lifecycle.lifecycleScope
import com.footballtracker.core.analysis.CalorieEstimator
import com.footballtracker.core.analysis.DistanceCalculator
import com.footballtracker.core.analysis.SlackDetector
import com.footballtracker.core.model.TrackPoint
import com.footballtracker.wearos.sync.DataLayerSync
import com.footballtracker.wearos.sync.PhoneCommandReceiver
import com.footballtracker.wearos.sync.ServerSync
import com.footballtracker.wearos.tracking.GpsTracker
import com.footballtracker.wearos.tracking.HeartRateTracker
import com.footballtracker.wearos.ui.SummaryScreen
import com.footballtracker.wearos.ui.TrackingScreen
import com.google.android.gms.wearable.MessageClient
import com.google.android.gms.wearable.Wearable
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import java.util.UUID

class MainActivity : ComponentActivity() {

    companion object {
        private const val TAG = "WearMainActivity"
    }

    private lateinit var heartRateTracker: HeartRateTracker
    private lateinit var serverSync: ServerSync
    private lateinit var dataLayerSync: DataLayerSync
    private lateinit var messageClient: MessageClient

    // Mutable state accessible from broadcast receiver
    private var remoteStartRequested = mutableStateOf(false)
    private var remoteStopRequested = mutableStateOf(false)

    private val requiredPermissions = arrayOf(
        Manifest.permission.ACCESS_FINE_LOCATION,
        Manifest.permission.BODY_SENSORS,
        Manifest.permission.ACTIVITY_RECOGNITION
    )

    private val permissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { /* permissions granted or denied — UI handles state */ }

    // Receiver for phone remote commands
    private val commandReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                PhoneCommandReceiver.ACTION_REMOTE_START -> {
                    Log.d(TAG, "Remote start received from phone")
                    remoteStartRequested.value = true
                }
                PhoneCommandReceiver.ACTION_REMOTE_STOP -> {
                    Log.d(TAG, "Remote stop received from phone")
                    remoteStopRequested.value = true
                }
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        heartRateTracker = HeartRateTracker(this)
        serverSync = ServerSync(this)
        dataLayerSync = DataLayerSync(this)
        messageClient = Wearable.getMessageClient(this)

        permissionLauncher.launch(requiredPermissions)

        // Register for remote commands
        val filter = IntentFilter().apply {
            addAction(PhoneCommandReceiver.ACTION_REMOTE_START)
            addAction(PhoneCommandReceiver.ACTION_REMOTE_STOP)
        }
        registerReceiver(commandReceiver, filter, RECEIVER_NOT_EXPORTED)

        setContent {
            FootballTrackerWearApp()
        }
    }

    override fun onDestroy() {
        unregisterReceiver(commandReceiver)
        super.onDestroy()
    }

    /**
     * Send a status message back to the phone (tracking_started / tracking_stopped / session_synced).
     */
    private fun notifyPhone(path: String) {
        lifecycleScope.launch {
            try {
                val nodes = Wearable.getNodeClient(this@MainActivity)
                    .connectedNodes
                    .await()
                for (node in nodes) {
                    messageClient.sendMessage(node.id, path, byteArrayOf())
                    Log.d(TAG, "Sent $path to phone node ${node.id}")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to notify phone: $path", e)
            }
        }
    }

    @Composable
    private fun FootballTrackerWearApp() {
        var isTracking by remember { mutableStateOf(false) }
        var showSummary by remember { mutableStateOf(false) }
        var elapsedSeconds by remember { mutableLongStateOf(0L) }
        var distance by remember { mutableDoubleStateOf(0.0) }
        var heartRate by remember { mutableIntStateOf(0) }
        var speed by remember { mutableDoubleStateOf(0.0) }
        var sessionStartTime by remember { mutableLongStateOf(0L) }
        var collectedPoints by remember { mutableStateOf<List<TrackPoint>>(emptyList()) }

        // Summary data
        var summaryDuration by remember { mutableLongStateOf(0L) }
        var summaryDistance by remember { mutableDoubleStateOf(0.0) }
        var summaryCalories by remember { mutableDoubleStateOf(0.0) }
        var summarySlack by remember { mutableIntStateOf(0) }

        // Start tracking action
        fun startTracking() {
            if (isTracking) return
            sessionStartTime = System.currentTimeMillis()
            elapsedSeconds = 0
            isTracking = true

            Intent(this@MainActivity, GpsTracker::class.java).also {
                it.action = GpsTracker.ACTION_START
                startForegroundService(it)
            }
            lifecycleScope.launch {
                heartRateTracker.startMonitoring()
            }
            notifyPhone("/tracking_started")
        }

        // Stop tracking action
        fun stopTracking() {
            if (!isTracking) return
            isTracking = false
            val endTime = System.currentTimeMillis()

            // Stop services
            Intent(this@MainActivity, GpsTracker::class.java).also {
                it.action = GpsTracker.ACTION_STOP
                startService(it)
            }
            lifecycleScope.launch {
                heartRateTracker.stopMonitoring()
            }

            // Calculate summary
            val points = collectedPoints
            val hrData = heartRateTracker.heartRateHistory.value
            summaryDuration = (endTime - sessionStartTime) / 1000
            summaryDistance = DistanceCalculator.totalDistance(points)
            summaryCalories = CalorieEstimator.estimateCalories(points)
            summarySlack = SlackDetector.analyze(points).index

            val sessionId = UUID.randomUUID().toString()

            // Sync to phone via DataLayer
            lifecycleScope.launch {
                try {
                    dataLayerSync.syncSession(
                        sessionId = sessionId,
                        startTime = sessionStartTime,
                        endTime = endTime,
                        trackPoints = points,
                        heartRateData = hrData
                    )
                    Log.d(TAG, "Session synced to phone via DataLayer")
                } catch (e: Exception) {
                    Log.e(TAG, "DataLayer sync failed", e)
                }
            }

            // Also sync directly to server
            lifecycleScope.launch {
                serverSync.syncSession(
                    sessionId = sessionId,
                    startTime = sessionStartTime,
                    endTime = endTime,
                    trackPoints = points,
                    heartRateData = hrData
                )
            }

            notifyPhone("/tracking_stopped")
            showSummary = true
        }

        // Handle remote commands from phone
        val startReq by remoteStartRequested
        val stopReq by remoteStopRequested

        LaunchedEffect(startReq) {
            if (startReq) {
                remoteStartRequested.value = false
                startTracking()
            }
        }

        LaunchedEffect(stopReq) {
            if (stopReq) {
                remoteStopRequested.value = false
                stopTracking()
            }
        }

        // Timer effect
        LaunchedEffect(isTracking) {
            if (isTracking) {
                while (true) {
                    delay(1000)
                    elapsedSeconds++
                }
            }
        }

        if (showSummary) {
            SummaryScreen(
                durationSeconds = summaryDuration,
                distanceMeters = summaryDistance,
                calories = summaryCalories,
                slackIndex = summarySlack,
                onDismiss = {
                    showSummary = false
                    elapsedSeconds = 0
                    distance = 0.0
                }
            )
        } else {
            TrackingScreen(
                elapsedSeconds = elapsedSeconds,
                distanceMeters = distance,
                heartRate = heartRate,
                speedMs = speed,
                isTracking = isTracking,
                onStartStop = {
                    if (isTracking) stopTracking() else startTracking()
                }
            )
        }
    }
}
