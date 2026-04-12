package com.footballtracker.android.ui.screens

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.TrendingUp
import androidx.compose.material.icons.rounded.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.footballtracker.android.data.db.SessionEntity
import com.footballtracker.android.network.ApiClient
import com.footballtracker.android.network.MatchResponse
import com.footballtracker.android.ui.theme.*
import java.util.*

private val AccentGreen = Color(0xFF16C784)
private val CardGlass = Brush.linearGradient(
    listOf(Color.White.copy(alpha = 0.10f), Color.White.copy(alpha = 0.05f))
)
private val CardBorder = Color.White.copy(alpha = 0.10f)

@Suppress("UNUSED_PARAMETER")
@Composable
fun HomeScreen(
    sessions: List<SessionEntity>,
    onSessionClick: (String) -> Unit,
    onNavigateCreateMatch: () -> Unit,
    onNavigateMatchDetail: (String) -> Unit
) {
    var activeTab by remember { mutableStateOf("week") }

    val todaySessions = remember(sessions) {
        val cal = Calendar.getInstance()
        val today = cal.get(Calendar.DAY_OF_YEAR)
        val thisYear = cal.get(Calendar.YEAR)
        sessions.filter { entity ->
            val eCal = Calendar.getInstance().apply { timeInMillis = entity.startTime }
            eCal.get(Calendar.DAY_OF_YEAR) == today && eCal.get(Calendar.YEAR) == thisYear
        }
    }

    val thisWeekSessions = remember(sessions) {
        val cal = Calendar.getInstance()
        val thisWeek = cal.get(Calendar.WEEK_OF_YEAR)
        val thisYear = cal.get(Calendar.YEAR)
        sessions.filter { entity ->
            val eCal = Calendar.getInstance().apply { timeInMillis = entity.startTime }
            eCal.get(Calendar.WEEK_OF_YEAR) == thisWeek && eCal.get(Calendar.YEAR) == thisYear
        }
    }

    val displaySessions = if (activeTab == "today") todaySessions else thisWeekSessions

    // Computed metrics
    val matchCount = displaySessions.size
    val totalCalories = displaySessions.sumOf { it.caloriesBurned }.toInt()
    val totalDistKm = displaySessions.sumOf { it.totalDistanceMeters } / 1000.0
    val totalSprints = displaySessions.sumOf { it.sprintCount }
    val totalDurationMin = displaySessions.sumOf { (it.endTime - it.startTime) / 60_000 }
    val maxHR = if (displaySessions.isNotEmpty()) displaySessions.maxOf { it.maxHeartRate } else 0
    val avgHR = if (displaySessions.isNotEmpty()) displaySessions.map { it.avgHeartRate }.average().toInt() else 0
    val maxSpeed = if (displaySessions.isNotEmpty()) displaySessions.maxOf { it.maxSpeedKmh } else 0.0
    val avgSpeed = if (displaySessions.isNotEmpty()) displaySessions.map { it.avgSpeedKmh }.average() else 0.0

    // Upcoming matches
    var upcomingMatches by remember { mutableStateOf<List<MatchResponse>>(emptyList()) }
    LaunchedEffect(Unit) {
        try {
            upcomingMatches = ApiClient.api.getMatches().matches
        } catch (_: Exception) {}
    }

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .background(DarkBg),
        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 0.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // ── Header ──
        item {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 16.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.Top
            ) {
                Column {
                    Text(
                        "FootyTrack",
                        fontSize = 30.sp,
                        fontWeight = FontWeight.Bold,
                        color = TextPrimary
                    )
                    Spacer(Modifier.height(4.dp))
                    Text(
                        "Push Your Limits Every Day",
                        fontSize = 14.sp,
                        color = TextSecondary
                    )
                }
                OutlinedButton(
                    onClick = { /* Watch connect */ },
                    shape = RoundedCornerShape(12.dp),
                    border = ButtonDefaults.outlinedButtonBorder(enabled = true).copy(
                        brush = Brush.linearGradient(
                            listOf(AccentGreen.copy(alpha = 0.3f), AccentGreen.copy(alpha = 0.3f))
                        )
                    ),
                    colors = ButtonDefaults.outlinedButtonColors(
                        containerColor = AccentGreen.copy(alpha = 0.15f)
                    ),
                    contentPadding = PaddingValues(horizontal = 12.dp, vertical = 6.dp)
                ) {
                    Icon(
                        Icons.Rounded.Watch,
                        contentDescription = null,
                        tint = AccentGreen,
                        modifier = Modifier.size(18.dp)
                    )
                    Spacer(Modifier.width(6.dp))
                    Text("Connect", fontSize = 13.sp, fontWeight = FontWeight.Medium, color = AccentGreen)
                }
            }
        }

        // ── Tab Toggle ──
        item {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .background(Color.Black.copy(alpha = 0.3f))
                    .padding(4.dp)
            ) {
                Row(modifier = Modifier.fillMaxWidth()) {
                    TabButton("Today", activeTab == "today", Modifier.weight(1f)) { activeTab = "today" }
                    TabButton("This Week", activeTab == "week", Modifier.weight(1f)) { activeTab = "week" }
                }
            }
        }

        // ── Summary Card ──
        item {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(16.dp))
                    .background(
                        Brush.linearGradient(
                            listOf(AccentGreen.copy(alpha = 0.20f), AccentGreen.copy(alpha = 0.05f))
                        )
                    )
                    .border(1.dp, AccentGreen.copy(alpha = 0.30f), RoundedCornerShape(16.dp))
                    .padding(24.dp)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Column {
                        Text(
                            if (activeTab == "today") "Matches Today" else "Weekly Matches",
                            fontSize = 13.sp,
                            color = TextSecondary
                        )
                        Spacer(Modifier.height(8.dp))
                        Text(
                            "$matchCount",
                            fontSize = 48.sp,
                            fontWeight = FontWeight.Bold,
                            color = AccentGreen
                        )
                        Spacer(Modifier.height(4.dp))
                        Text(
                            if (activeTab == "today") {
                                val completed = todaySessions.count { it.endTime > it.startTime }
                                "$completed completed"
                            } else {
                                "$matchCount sessions this week"
                            },
                            fontSize = 13.sp,
                            color = Color.White.copy(alpha = 0.7f)
                        )
                    }
                    Box(
                        modifier = Modifier
                            .size(72.dp)
                            .clip(RoundedCornerShape(16.dp))
                            .background(AccentGreen.copy(alpha = 0.20f)),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            Icons.Rounded.CalendarMonth,
                            contentDescription = null,
                            tint = AccentGreen,
                            modifier = Modifier.size(40.dp)
                        )
                    }
                }
            }
        }

        // ── Core Metrics Grid ──
        item {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text("Core Metrics", fontSize = 18.sp, fontWeight = FontWeight.Bold, color = TextPrimary)

                val metrics = listOf(
                    MetricData("Matches", "$matchCount", null, Icons.Rounded.FitnessCenter),
                    MetricData("Calories", "%,d".format(totalCalories), "kcal", Icons.Rounded.LocalFireDepartment),
                    MetricData("Distance", "%.1f".format(totalDistKm), "km", Icons.Rounded.Place),
                    MetricData("Sprints", "$totalSprints", null, Icons.Rounded.FlashOn),
                    MetricData("Duration", "%,d".format(totalDurationMin), "min", Icons.Rounded.Timer),
                    MetricData("Max HR", "$maxHR", "bpm", Icons.Rounded.Favorite),
                    MetricData("Avg HR", "$avgHR", "bpm", Icons.Rounded.FavoriteBorder),
                    MetricData("Max Speed", "%.1f".format(maxSpeed), "km/h", Icons.AutoMirrored.Rounded.TrendingUp),
                    MetricData("Avg Speed", "%.1f".format(avgSpeed), "km/h", Icons.Rounded.Speed),
                )

                // 3x3 grid
                for (row in 0 until 3) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        for (col in 0 until 3) {
                            val m = metrics[row * 3 + col]
                            MetricCard(m, Modifier.weight(1f))
                        }
                    }
                }
            }
        }

        // ── Movement Heatmap ──
        item {
            GlassCard {
                Text("Movement Heatmap", fontSize = 18.sp, fontWeight = FontWeight.Bold, color = TextPrimary)
                Spacer(Modifier.height(16.dp))
                FootballFieldHeatmap(
                    modifier = Modifier
                        .fillMaxWidth()
                        .aspectRatio(2f / 3f)
                )
                Spacer(Modifier.height(12.dp))
                // Legend
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("Movement Density", fontSize = 11.sp, color = TextSecondary)
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        Text("Low", fontSize = 11.sp, color = Color.Gray)
                        listOf(0.20f, 0.40f, 0.60f, 0.80f, 1.0f).forEach { alpha ->
                            Box(
                                modifier = Modifier
                                    .size(16.dp)
                                    .clip(RoundedCornerShape(4.dp))
                                    .background(AccentGreen.copy(alpha = alpha))
                            )
                        }
                        Text("High", fontSize = 11.sp, color = Color.Gray)
                    }
                }
            }
        }

        // ── Heart Rate Chart ──
        item {
            GlassCard {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("Heart Rate", fontSize = 18.sp, fontWeight = FontWeight.Bold, color = TextPrimary)
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        Icon(Icons.Rounded.Favorite, null, tint = AccentGreen, modifier = Modifier.size(16.dp))
                        Text(
                            if (avgHR > 0) "$avgHR avg bpm" else "-- avg bpm",
                            fontSize = 13.sp,
                            color = TextSecondary
                        )
                    }
                }
                Spacer(Modifier.height(16.dp))
                HeartRateChart(
                    sessions = displaySessions,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(180.dp)
                )
            }
        }

        // ── Speed Distribution Chart ──
        item {
            GlassCard {
                Text("Speed Distribution", fontSize = 18.sp, fontWeight = FontWeight.Bold, color = TextPrimary)
                Spacer(Modifier.height(16.dp))
                SpeedDistributionChart(
                    sessions = displaySessions,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(180.dp)
                )
            }
        }

        // ── Weekly Performance Trend ──
        item {
            GlassCard {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("Weekly Performance Trend", fontSize = 18.sp, fontWeight = FontWeight.Bold, color = TextPrimary)
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        Icon(Icons.AutoMirrored.Rounded.TrendingUp, null, tint = AccentGreen, modifier = Modifier.size(16.dp))
                        Text("+18%", fontSize = 13.sp, color = AccentGreen)
                    }
                }
                Spacer(Modifier.height(16.dp))
                WeeklyTrendChart(
                    sessions = sessions,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(180.dp)
                )
            }
        }

        // Bottom spacer for nav bar
        item { Spacer(Modifier.height(80.dp)) }
    }
}

// ── Tab Button ──
@Composable
private fun TabButton(label: String, selected: Boolean, modifier: Modifier, onClick: () -> Unit) {
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(10.dp))
            .background(if (selected) AccentGreen else Color.Transparent)
            .clickable(onClick = onClick)
            .padding(vertical = 10.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(
            label,
            fontSize = 14.sp,
            fontWeight = FontWeight.Medium,
            color = if (selected) Color.White else TextSecondary
        )
    }
}

// ── Metric data ──
private data class MetricData(
    val label: String,
    val value: String,
    val unit: String?,
    val icon: ImageVector
)

// ── Metric Card ──
@Composable
private fun MetricCard(metric: MetricData, modifier: Modifier = Modifier) {
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(14.dp))
            .background(CardGlass)
            .border(1.dp, CardBorder, RoundedCornerShape(14.dp))
            .padding(12.dp)
    ) {
        Column {
            Box(
                modifier = Modifier
                    .size(32.dp)
                    .clip(RoundedCornerShape(8.dp))
                    .background(AccentGreen.copy(alpha = 0.20f)),
                contentAlignment = Alignment.Center
            ) {
                Icon(metric.icon, null, tint = AccentGreen, modifier = Modifier.size(16.dp))
            }
            Spacer(Modifier.height(8.dp))
            Row(verticalAlignment = Alignment.Bottom) {
                Text(metric.value, fontSize = 18.sp, fontWeight = FontWeight.Bold, color = TextPrimary)
                if (metric.unit != null) {
                    Spacer(Modifier.width(3.dp))
                    Text(
                        metric.unit,
                        fontSize = 10.sp,
                        color = TextSecondary,
                        modifier = Modifier.padding(bottom = 2.dp)
                    )
                }
            }
            Spacer(Modifier.height(2.dp))
            Text(metric.label, fontSize = 10.sp, color = TextSecondary)
        }
    }
}

// ── Glass Card Container ──
@Composable
private fun GlassCard(content: @Composable ColumnScope.() -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(CardGlass)
            .border(1.dp, CardBorder, RoundedCornerShape(16.dp))
            .padding(20.dp)
    ) {
        Column(content = content)
    }
}

// ── Football Field Heatmap ──
@Composable
private fun FootballFieldHeatmap(modifier: Modifier = Modifier) {
    val fieldBg = Brush.verticalGradient(
        listOf(Color(0xFF0A3D0A).copy(alpha = 0.40f), Color(0xFF072307).copy(alpha = 0.40f))
    )

    Box(
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .background(fieldBg)
            .border(2.dp, Color.White.copy(alpha = 0.20f), RoundedCornerShape(12.dp))
    ) {
        // Field lines
        Canvas(modifier = Modifier.fillMaxSize()) {
            val w = size.width
            val h = size.height
            val lineColor = Color.White.copy(alpha = 0.30f)
            val lineStroke = Stroke(width = 2f)

            // Center line
            drawLine(lineColor, Offset(0f, h / 2), Offset(w, h / 2), strokeWidth = 2f)

            // Center circle
            drawCircle(
                color = lineColor,
                radius = w * 0.12f,
                center = Offset(w / 2, h / 2),
                style = lineStroke
            )

            // Top penalty box
            val penaltyW = w * 0.75f
            val penaltyH = h * 0.25f
            drawRect(
                color = lineColor,
                topLeft = Offset((w - penaltyW) / 2, 0f),
                size = Size(penaltyW, penaltyH),
                style = lineStroke
            )

            // Bottom penalty box
            drawRect(
                color = lineColor,
                topLeft = Offset((w - penaltyW) / 2, h - penaltyH),
                size = Size(penaltyW, penaltyH),
                style = lineStroke
            )

            // Top goal box
            val goalW = w * 0.5f
            val goalH = h * 0.12f
            drawRect(
                color = lineColor,
                topLeft = Offset((w - goalW) / 2, 0f),
                size = Size(goalW, goalH),
                style = lineStroke
            )

            // Bottom goal box
            drawRect(
                color = lineColor,
                topLeft = Offset((w - goalW) / 2, h - goalH),
                size = Size(goalW, goalH),
                style = lineStroke
            )
        }

        // Heatmap glow spots
        HeatmapSpot(
            modifier = Modifier
                .align(Alignment.TopCenter)
                .offset(y = 80.dp)
                .size(80.dp),
            alpha = 0.40f
        )
        HeatmapSpot(
            modifier = Modifier
                .align(Alignment.CenterStart)
                .offset(x = 30.dp, y = (-40).dp)
                .size(64.dp),
            alpha = 0.30f
        )
        HeatmapSpot(
            modifier = Modifier
                .align(Alignment.CenterEnd)
                .offset(x = (-30).dp, y = (-40).dp)
                .size(64.dp),
            alpha = 0.30f
        )
        HeatmapSpot(
            modifier = Modifier
                .align(Alignment.Center)
                .size(96.dp),
            alpha = 0.50f
        )
        HeatmapSpot(
            modifier = Modifier
                .align(Alignment.Center)
                .offset(x = (-30).dp, y = 40.dp)
                .size(56.dp),
            alpha = 0.25f
        )
        HeatmapSpot(
            modifier = Modifier
                .align(Alignment.Center)
                .offset(x = 30.dp, y = 30.dp)
                .size(56.dp),
            alpha = 0.25f
        )
        HeatmapSpot(
            modifier = Modifier
                .align(Alignment.TopCenter)
                .offset(y = 40.dp)
                .size(48.dp),
            alpha = 0.20f
        )
    }
}

@Composable
private fun HeatmapSpot(modifier: Modifier, alpha: Float) {
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(50))
            .background(AccentGreen.copy(alpha = alpha))
            .blur(24.dp)
    )
}

// ── Heart Rate Area Chart ──
@Composable
private fun HeartRateChart(sessions: List<SessionEntity>, modifier: Modifier = Modifier) {
    val textMeasurer = rememberTextMeasurer()
    val axisStyle = TextStyle(color = Color.Gray, fontSize = 11.sp)
    // Sample heart rate data points - use real data if available, otherwise placeholder
    val dataPoints = remember(sessions) {
        if (sessions.isEmpty()) {
            listOf(72f, 95f, 128f, 145f, 162f, 158f, 171f, 165f, 142f, 88f)
        } else {
            // Aggregate HR from sessions
            val hrs = sessions.flatMap { s ->
                listOf(s.avgHeartRate.toFloat(), s.maxHeartRate.toFloat())
            }.filter { it > 0 }
            if (hrs.isEmpty()) listOf(72f, 95f, 128f, 145f, 162f, 158f, 171f, 165f, 142f, 88f)
            else hrs
        }
    }
    val timeLabels = remember(dataPoints) {
        dataPoints.indices.map { "${it * 10}" }
    }

    Canvas(modifier = modifier) {
        val leftPad = 40f
        val bottomPad = 30f
        val chartW = size.width - leftPad
        val chartH = size.height - bottomPad
        val minVal = 60f
        val maxVal = 180f
        val range = maxVal - minVal

        // Grid lines
        val gridColor = Color.White.copy(alpha = 0.08f)
        val dashEffect = PathEffect.dashPathEffect(floatArrayOf(6f, 4f))
        for (i in 0..3) {
            val y = chartH * (1 - i / 3f)
            drawLine(gridColor, Offset(leftPad, y), Offset(size.width, y), pathEffect = dashEffect)
            val label = "${(minVal + range * i / 3).toInt()}"
            drawText(textMeasurer, label, Offset(0f, y - 8f), style = axisStyle)
        }

        // X-axis labels
        if (dataPoints.size > 1) {
            val step = if (dataPoints.size <= 5) 1 else dataPoints.size / 5
            for (i in dataPoints.indices step step) {
                val x = leftPad + chartW * i / (dataPoints.size - 1)
                if (i < timeLabels.size) {
                    drawText(textMeasurer, timeLabels[i], Offset(x - 8f, chartH + 4f), style = axisStyle)
                }
            }
        }
        // "Minutes" label
        drawText(textMeasurer, "Minutes", Offset(size.width / 2 - 20f, size.height - 14f), style = axisStyle)

        if (dataPoints.size < 2) return@Canvas

        // Build path
        val points = dataPoints.mapIndexed { index, value ->
            val x = leftPad + chartW * index / (dataPoints.size - 1)
            val y = chartH * (1 - (value - minVal) / range)
            Offset(x, y.coerceIn(0f, chartH))
        }

        // Fill area
        val fillPath = Path().apply {
            moveTo(points.first().x, chartH)
            points.forEach { lineTo(it.x, it.y) }
            lineTo(points.last().x, chartH)
            close()
        }
        drawPath(
            fillPath,
            Brush.verticalGradient(
                listOf(AccentGreen.copy(alpha = 0.30f), AccentGreen.copy(alpha = 0f)),
                startY = 0f,
                endY = chartH
            )
        )

        // Line
        val linePath = Path().apply {
            moveTo(points.first().x, points.first().y)
            for (i in 1 until points.size) {
                lineTo(points[i].x, points[i].y)
            }
        }
        drawPath(linePath, AccentGreen, style = Stroke(width = 3f, cap = StrokeCap.Round))
    }
}

// ── Speed Distribution Bar Chart ──
@Composable
private fun SpeedDistributionChart(sessions: List<SessionEntity>, modifier: Modifier = Modifier) {
    val textMeasurer = rememberTextMeasurer()
    val axisStyle = TextStyle(color = Color.Gray, fontSize = 11.sp)

    val buckets = remember(sessions) {
        if (sessions.isEmpty()) {
            listOf(
                "0-5" to 12, "5-10" to 28, "10-15" to 45,
                "15-20" to 38, "20-25" to 22, "25+" to 8
            )
        } else {
            // Build speed buckets from session data
            val speedList = sessions.map { it.avgSpeedKmh }
            val b = IntArray(6)
            speedList.forEach { spd ->
                when {
                    spd < 5 -> b[0]++
                    spd < 10 -> b[1]++
                    spd < 15 -> b[2]++
                    spd < 20 -> b[3]++
                    spd < 25 -> b[4]++
                    else -> b[5]++
                }
            }
            listOf("0-5", "5-10", "10-15", "15-20", "20-25", "25+").zip(b.toList())
        }
    }

    val maxCount = (buckets.maxOfOrNull { it.second } ?: 1).coerceAtLeast(1)

    Canvas(modifier = modifier) {
        val leftPad = 40f
        val bottomPad = 40f
        val chartW = size.width - leftPad
        val chartH = size.height - bottomPad

        // Grid lines
        val gridColor = Color.White.copy(alpha = 0.08f)
        val dashEffect = PathEffect.dashPathEffect(floatArrayOf(6f, 4f))
        for (i in 0..4) {
            val y = chartH * (1 - i / 4f)
            drawLine(gridColor, Offset(leftPad, y), Offset(size.width, y), pathEffect = dashEffect)
            val label = "${maxCount * i / 4}"
            drawText(textMeasurer, label, Offset(0f, y - 8f), style = axisStyle)
        }

        // Bars
        val barCount = buckets.size
        val gap = chartW * 0.1f / barCount
        val barW = (chartW - gap * (barCount + 1)) / barCount

        buckets.forEachIndexed { index, (rangeLabel, count) ->
            val barH = chartH * count.toFloat() / maxCount
            val x = leftPad + gap + index * (barW + gap)
            val y = chartH - barH

            // Bar with rounded top
            drawRoundRect(
                color = AccentGreen,
                topLeft = Offset(x, y),
                size = Size(barW, barH),
                cornerRadius = CornerRadius(8f, 8f)
            )

            // X label
            drawText(
                textMeasurer,
                rangeLabel,
                Offset(x + barW / 2 - 12f, chartH + 6f),
                style = axisStyle
            )
        }

        // "km/h" label
        drawText(textMeasurer, "km/h", Offset(size.width / 2 - 12f, size.height - 12f), style = axisStyle)
    }
}

// ── Weekly Performance Trend Line Chart ──
@Composable
private fun WeeklyTrendChart(sessions: List<SessionEntity>, modifier: Modifier = Modifier) {
    val textMeasurer = rememberTextMeasurer()
    val axisStyle = TextStyle(color = Color.Gray, fontSize = 11.sp)

    val dayLabels = listOf("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")

    // Compute performance per day of the week
    val dayPerformance = remember(sessions) {
        if (sessions.isEmpty()) {
            listOf(72f, 68f, 75f, 82f, 78f, 88f, 85f)
        } else {
            val dayBuckets = Array(7) { mutableListOf<Float>() }
            sessions.forEach { s ->
                val cal = Calendar.getInstance().apply { timeInMillis = s.startTime }
                val dow = (cal.get(Calendar.DAY_OF_WEEK) + 5) % 7 // Mon=0..Sun=6
                // Performance = combo of distance + sprints capped at 100
                val perf = ((s.totalDistanceMeters / 100.0) + s.sprintCount * 2).toFloat().coerceIn(0f, 100f)
                dayBuckets[dow].add(perf)
            }
            dayBuckets.map { if (it.isEmpty()) 0f else it.average().toFloat() }
        }
    }

    Canvas(modifier = modifier) {
        val leftPad = 35f
        val bottomPad = 30f
        val chartW = size.width - leftPad
        val chartH = size.height - bottomPad

        // Grid
        val gridColor = Color.White.copy(alpha = 0.08f)
        val dashEffect = PathEffect.dashPathEffect(floatArrayOf(6f, 4f))
        for (i in 0..4) {
            val y = chartH * (1 - i / 4f)
            drawLine(gridColor, Offset(leftPad, y), Offset(size.width, y), pathEffect = dashEffect)
            drawText(textMeasurer, "${25 * i}", Offset(0f, y - 8f), style = axisStyle)
        }

        // X labels
        for (i in dayLabels.indices) {
            val x = leftPad + chartW * i / 6f
            drawText(textMeasurer, dayLabels[i], Offset(x - 10f, chartH + 6f), style = axisStyle)
        }

        // Line + dots
        val points = dayPerformance.mapIndexed { index, value ->
            val x = leftPad + chartW * index / 6f
            val y = chartH * (1 - value / 100f)
            Offset(x, y.coerceIn(0f, chartH))
        }

        if (points.size >= 2) {
            val linePath = Path().apply {
                moveTo(points.first().x, points.first().y)
                for (i in 1 until points.size) {
                    lineTo(points[i].x, points[i].y)
                }
            }
            drawPath(linePath, AccentGreen, style = Stroke(width = 3f, cap = StrokeCap.Round))

            // Dots
            points.forEach { pt ->
                drawCircle(AccentGreen, radius = 5f, center = pt)
                drawCircle(DarkBg, radius = 2.5f, center = pt)
            }
        }
    }
}
