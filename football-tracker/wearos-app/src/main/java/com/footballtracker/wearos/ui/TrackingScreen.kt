package com.footballtracker.wearos.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.wear.compose.material.*

/**
 * Main tracking screen shown during a football session on Wear OS.
 * Displays elapsed time, distance, heart rate, and current speed.
 */
@Composable
fun TrackingScreen(
    elapsedSeconds: Long,
    distanceMeters: Double,
    heartRate: Int,
    speedMs: Double,
    isTracking: Boolean,
    onStartStop: () -> Unit
) {
    val timeStr = formatTime(elapsedSeconds)
    val distKm = "%.1f".format(distanceMeters / 1000.0)
    val speedKmh = "%.1f".format(speedMs * 3.6)

    Scaffold(
        timeText = { TimeText() }
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black)
                .padding(8.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            // Title
            Text(
                text = if (isTracking) "⚽ 踢球中" else "⚽ 准备开始",
                fontSize = 14.sp,
                color = Color.White,
                fontWeight = FontWeight.Bold
            )

            Spacer(modifier = Modifier.height(4.dp))

            if (isTracking) {
                // Timer
                Text(
                    text = "⏱ $timeStr",
                    fontSize = 20.sp,
                    color = Color(0xFF4FC3F7),
                    fontWeight = FontWeight.Bold
                )

                Spacer(modifier = Modifier.height(4.dp))

                // Distance
                Text(
                    text = "\uD83C\uDFC3 $distKm km",
                    fontSize = 16.sp,
                    color = Color(0xFF81C784)
                )

                // Heart rate
                Text(
                    text = "❤\uFE0F $heartRate bpm",
                    fontSize = 16.sp,
                    color = Color(0xFFE57373)
                )

                // Speed
                Text(
                    text = "⚡ $speedKmh km/h",
                    fontSize = 16.sp,
                    color = Color(0xFFFFB74D)
                )
            }

            Spacer(modifier = Modifier.height(8.dp))

            // Start/Stop button
            Button(
                onClick = onStartStop,
                colors = ButtonDefaults.buttonColors(
                    backgroundColor = if (isTracking) Color(0xFFE53935) else Color(0xFF43A047)
                ),
                modifier = Modifier.size(width = 100.dp, height = 36.dp)
            ) {
                Text(
                    text = if (isTracking) "结束记录" else "开始记录",
                    fontSize = 12.sp,
                    textAlign = TextAlign.Center
                )
            }
        }
    }
}

private fun formatTime(totalSeconds: Long): String {
    val minutes = totalSeconds / 60
    val seconds = totalSeconds % 60
    return "%d:%02d".format(minutes, seconds)
}
