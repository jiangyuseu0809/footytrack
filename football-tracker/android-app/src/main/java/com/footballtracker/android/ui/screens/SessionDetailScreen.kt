package com.footballtracker.android.ui.screens

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.rounded.DirectionsRun
import androidx.compose.material.icons.rounded.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.footballtracker.android.data.db.SessionEntity
import com.footballtracker.android.ui.components.*
import com.footballtracker.android.ui.theme.*
import com.footballtracker.core.model.SessionStats
import com.footballtracker.core.model.TrackPoint
import java.text.SimpleDateFormat
import java.util.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SessionDetailScreen(
    session: SessionEntity,
    stats: SessionStats,
    trackPoints: List<TrackPoint>,
    onBack: () -> Unit
) {
    val dateFormat = SimpleDateFormat("yyyy年M月d日 EEE", Locale.CHINESE)
    val dateStr = dateFormat.format(Date(session.startTime))
    val timeFormat = SimpleDateFormat("HH:mm", Locale.CHINESE)
    val startStr = timeFormat.format(Date(session.startTime))
    val endStr = timeFormat.format(Date(session.endTime))
    val durationMin = (session.endTime - session.startTime) / 60_000

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(DarkBg)
            .verticalScroll(rememberScrollState())
    ) {
        // Hero area
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    Brush.verticalGradient(
                        listOf(
                            NeonPurple.copy(alpha = 0.2f),
                            NeonBlue.copy(alpha = 0.1f),
                            DarkBg
                        )
                    )
                )
                .padding(top = 8.dp)
        ) {
            Column(modifier = Modifier.fillMaxWidth()) {
                // Back button
                IconButton(
                    onClick = onBack,
                    modifier = Modifier.padding(start = 4.dp)
                ) {
                    Icon(
                        Icons.AutoMirrored.Filled.ArrowBack,
                        contentDescription = "返回",
                        tint = TextPrimary
                    )
                }

                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 24.dp)
                        .padding(bottom = 24.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    // Big distance number
                    Row(verticalAlignment = Alignment.Bottom) {
                        Text(
                            text = "%.1f".format(stats.totalDistanceMeters / 1000),
                            fontSize = 56.sp,
                            fontWeight = FontWeight.Bold,
                            color = TextPrimary
                        )
                        Spacer(modifier = Modifier.width(4.dp))
                        Text(
                            text = "km",
                            fontSize = 18.sp,
                            fontWeight = FontWeight.Medium,
                            color = TextSecondary,
                            modifier = Modifier.padding(bottom = 10.dp)
                        )
                    }

                    Spacer(modifier = Modifier.height(8.dp))

                    // Date + Duration
                    Text(
                        text = dateStr,
                        fontSize = 14.sp,
                        color = TextSecondary
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = "$startStr - $endStr · ${durationMin}分钟",
                        fontSize = 13.sp,
                        color = TextSecondary.copy(alpha = 0.7f)
                    )
                }
            }
        }

        // Stats Grid
        Column(
            modifier = Modifier.padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                StatCard(
                    label = "最高速度",
                    value = "%.1f".format(stats.maxSpeedKmh),
                    unit = "km/h",
                    color = SpeedGreen,
                    icon = Icons.Rounded.Speed,
                    modifier = Modifier.weight(1f)
                )
                StatCard(
                    label = "平均速度",
                    value = "%.1f".format(stats.avgSpeedKmh),
                    unit = "km/h",
                    color = SpeedGreenL,
                    icon = Icons.Rounded.Speed,
                    modifier = Modifier.weight(1f)
                )
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                StatCard(
                    label = "平均心率",
                    value = "${stats.avgHeartRate}",
                    unit = "bpm",
                    color = HeartRed,
                    icon = Icons.Rounded.Favorite,
                    modifier = Modifier.weight(1f)
                )
                StatCard(
                    label = "最高心率",
                    value = "${stats.maxHeartRate}",
                    unit = "bpm",
                    color = HeartRedLight,
                    icon = Icons.Rounded.Favorite,
                    modifier = Modifier.weight(1f)
                )
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                StatCard(
                    label = "卡路里",
                    value = "${stats.caloriesBurned.toInt()}",
                    unit = "kcal",
                    color = CalorieOrange,
                    icon = Icons.Rounded.LocalFireDepartment,
                    modifier = Modifier.weight(1f)
                )
                StatCard(
                    label = "冲刺次数",
                    value = "${stats.sprintCount}",
                    unit = "次",
                    color = NeonPurple,
                    icon = Icons.Rounded.FlashOn,
                    modifier = Modifier.weight(1f)
                )
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                StatCard(
                    label = "高强度距离",
                    value = "%.1f".format(stats.highIntensityDistanceMeters / 1000),
                    unit = "km",
                    color = HeartRed,
                    icon = Icons.AutoMirrored.Rounded.DirectionsRun,
                    modifier = Modifier.weight(1f)
                )
                StatCard(
                    label = "覆盖率",
                    value = "%.0f".format(stats.coveragePercent),
                    unit = "%",
                    color = NeonBlue,
                    icon = Icons.Rounded.GridOn,
                    modifier = Modifier.weight(1f)
                )
            }

            Spacer(modifier = Modifier.height(8.dp))

            // Slack Index — Semi-circle gauge
            SlackGaugeCard(stats.slackIndex, stats.slackLabel)

            Spacer(modifier = Modifier.height(8.dp))

            // Charts
            SpeedChart(
                points = trackPoints,
                modifier = Modifier.fillMaxWidth()
            )

            Spacer(modifier = Modifier.height(6.dp))

            if (trackPoints.any { it.heartRate > 0 }) {
                SpeedChart(
                    points = trackPoints,
                    showHeartRate = true,
                    modifier = Modifier.fillMaxWidth()
                )
                Spacer(modifier = Modifier.height(6.dp))
            }

            // Fatigue Analysis
            if (stats.fatigueSegments.isNotEmpty()) {
                FatigueCard(stats.fatigueSegments)
                Spacer(modifier = Modifier.height(6.dp))
            }

            // Heatmap
            HeatmapOverlay(
                grid = stats.heatmapGrid,
                modifier = Modifier.fillMaxWidth()
            )

            Spacer(modifier = Modifier.height(24.dp))
        }
    }
}

@Composable
private fun SlackGaugeCard(slackIndex: Int, label: String) {
    val gaugeColor = when (slackIndex) {
        in 0..30 -> SlackGreen
        in 31..60 -> SlackYellow
        else -> SlackRed
    }

    Card(
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(containerColor = CardBg),
        elevation = CardDefaults.cardElevation(0.dp),
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = "摸鱼指数",
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                color = TextSecondary
            )
            Spacer(modifier = Modifier.height(12.dp))

            // Semi-circle gauge
            Box(
                modifier = Modifier.size(140.dp),
                contentAlignment = Alignment.BottomCenter
            ) {
                Canvas(modifier = Modifier.fillMaxSize()) {
                    val sweepAngle = 180f
                    val strokeW = 12f
                    val arcSize = Size(size.width - strokeW, size.height * 2 - strokeW)
                    val arcOffset = Offset(strokeW / 2, strokeW / 2)

                    // Background arc
                    drawArc(
                        color = DividerColor,
                        startAngle = 180f,
                        sweepAngle = sweepAngle,
                        useCenter = false,
                        topLeft = arcOffset,
                        size = arcSize,
                        style = Stroke(width = strokeW, cap = StrokeCap.Round)
                    )

                    // Value arc
                    val valueSweep = sweepAngle * (slackIndex / 100f)
                    drawArc(
                        color = gaugeColor,
                        startAngle = 180f,
                        sweepAngle = valueSweep,
                        useCenter = false,
                        topLeft = arcOffset,
                        size = arcSize,
                        style = Stroke(width = strokeW, cap = StrokeCap.Round)
                    )
                }

                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    modifier = Modifier.padding(bottom = 8.dp)
                ) {
                    Text(
                        text = "$slackIndex",
                        fontSize = 36.sp,
                        fontWeight = FontWeight.Bold,
                        color = gaugeColor
                    )
                    Text(
                        text = label,
                        fontSize = 13.sp,
                        color = gaugeColor.copy(alpha = 0.8f)
                    )
                }
            }
        }
    }
}

@Composable
private fun FatigueCard(segments: List<com.footballtracker.core.model.FatigueSegment>) {
    Card(
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(containerColor = CardBg),
        elevation = CardDefaults.cardElevation(0.dp),
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = "疲劳分析 (每5分钟跑动距离)",
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                color = TextPrimary
            )
            Spacer(modifier = Modifier.height(12.dp))

            val maxDist = segments.maxOf { it.distanceMeters }.coerceAtLeast(1.0)

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(120.dp),
                horizontalArrangement = Arrangement.spacedBy(3.dp)
            ) {
                segments.forEach { seg ->
                    val fraction = (seg.distanceMeters / maxDist).toFloat()
                    val barColor = when {
                        fraction > 0.7 -> SpeedGreen
                        fraction > 0.4 -> SlackYellow
                        else -> HeartRed
                    }
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .fillMaxHeight()
                    ) {
                        Canvas(modifier = Modifier.fillMaxSize()) {
                            val barH = size.height * fraction
                            // Rounded bar with gradient
                            drawRoundRect(
                                color = barColor.copy(alpha = 0.8f),
                                topLeft = Offset(1f, size.height - barH),
                                size = Size(size.width - 2f, barH),
                                cornerRadius = androidx.compose.ui.geometry.CornerRadius(4f, 4f)
                            )
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(4.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text("0'", fontSize = 10.sp, color = TextSecondary)
                Text("${segments.last().endMinute}'", fontSize = 10.sp, color = TextSecondary)
            }
        }
    }
}
