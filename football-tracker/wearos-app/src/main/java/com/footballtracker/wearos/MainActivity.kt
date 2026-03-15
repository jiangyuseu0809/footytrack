package com.footballtracker.wearos

import android.Manifest
import android.content.Intent
import android.os.Bundle
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
import com.footballtracker.wearos.tracking.GpsTracker
import com.footballtracker.wearos.tracking.HeartRateTracker
import com.footballtracker.wearos.ui.SummaryScreen
import com.footballtracker.wearos.ui.TrackingScreen
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.util.UUID

class MainActivity : ComponentActivity() {

    private lateinit var heartRateTracker: HeartRateTracker
    private lateinit var dataLayerSync: DataLayerSync

    private val requiredPermissions = arrayOf(
        Manifest.permission.ACCESS_FINE_LOCATION,
        Manifest.permission.BODY_SENSORS,
        Manifest.permission.ACTIVITY_RECOGNITION
    )

    private val permissionLauncher = registerForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { /* permissions granted or denied — UI handles state */ }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        heartRateTracker = HeartRateTracker(this)
        dataLayerSync = DataLayerSync(this)

        permissionLauncher.launch(requiredPermissions)

        setContent {
            FootballTrackerWearApp()
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

        // Timer effect
        LaunchedEffect(isTracking) {
            if (isTracking) {
                while (true) {
                    delay(1000)
                    elapsedSeconds++
                }
            }
        }

        // Collect GPS and HR flows
        LaunchedEffect(isTracking) {
            if (isTracking) {
                // In a real app, bind to GpsTracker service and collect flows
                // Here we show the architecture
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
                    if (isTracking) {
                        // Stop tracking
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
                        summaryDuration = (endTime - sessionStartTime) / 1000
                        summaryDistance = DistanceCalculator.totalDistance(points)
                        summaryCalories = CalorieEstimator.estimateCalories(points)
                        summarySlack = SlackDetector.analyze(points).index

                        // Sync to phone
                        lifecycleScope.launch {
                            dataLayerSync.syncSession(
                                sessionId = UUID.randomUUID().toString(),
                                startTime = sessionStartTime,
                                endTime = endTime,
                                trackPoints = points,
                                heartRateData = heartRateTracker.heartRateHistory.value
                            )
                        }

                        showSummary = true
                    } else {
                        // Start tracking
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
                    }
                }
            )
        }
    }
}
