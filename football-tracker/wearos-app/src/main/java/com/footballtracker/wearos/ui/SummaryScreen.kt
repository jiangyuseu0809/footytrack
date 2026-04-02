package com.footballtracker.wearos.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.wear.compose.material.*

/**
 * Summary screen shown after a football session ends.
 * Displays key stats and prompts user to check phone for details.
 */
@Composable
fun SummaryScreen(
    durationSeconds: Long,
    distanceMeters: Double,
    calories: Double,
    slackIndex: Int,
    onDismiss: () -> Unit
) {
    val timeStr = "%d:%02d".format(durationSeconds / 60, durationSeconds % 60)
    val distKm = "%.1f".format(distanceMeters / 1000.0)

    Scaffold(
        timeText = { TimeText() }
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black)
                .padding(12.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Text(
                text = "✅ 已完成",
                fontSize = 16.sp,
                color = Color(0xFF66BB6A),
                fontWeight = FontWeight.Bold
            )

            Spacer(modifier = Modifier.height(8.dp))

            StatRow("时长", timeStr)
            StatRow("距离", "${distKm}km")
            StatRow("卡路里", "${calories.toInt()}")
            StatRow("摸鱼", "${slackIndex}%")

            Spacer(modifier = Modifier.height(8.dp))

            Text(
                text = "详情请看小程序",
                fontSize = 11.sp,
                color = Color.Gray,
                textAlign = TextAlign.Center
            )

            Spacer(modifier = Modifier.height(6.dp))

            CompactChip(
                onClick = onDismiss,
                label = { Text("完成", fontSize = 12.sp) },
                colors = ChipDefaults.chipColors(
                    backgroundColor = Color(0xFF424242)
                )
            )
        }
    }
}

@Composable
private fun StatRow(label: String, value: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 2.dp),
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Text(text = label, fontSize = 13.sp, color = Color.LightGray)
        Text(text = value, fontSize = 13.sp, color = Color.White, fontWeight = FontWeight.Medium)
    }
}
