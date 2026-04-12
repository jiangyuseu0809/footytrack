package com.footballtracker.android.ui.screens

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandVertically
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
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
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.drawText
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.rememberTextMeasurer
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.footballtracker.android.data.db.SessionEntity
import com.footballtracker.android.ui.theme.*
import java.text.SimpleDateFormat
import java.util.*
import kotlin.math.max
import kotlin.math.min

private val AccentGreen = Color(0xFF16C784)
private val CardGlass = Brush.linearGradient(
    listOf(Color.White.copy(alpha = 0.10f), Color.White.copy(alpha = 0.05f))
)
private val CardBorderColor = Color.White.copy(alpha = 0.10f)

private val dateFilterOptions = listOf("All Time", "This Week", "This Month")
private val typeFilterOptions = listOf("All Matches", "Competitive", "Friendly", "Training")

@Suppress("UNUSED_PARAMETER")
@Composable
fun StatsScreen(
    sessions: List<SessionEntity>,
    onBack: () -> Unit
) {
    var expandedSessionId by remember { mutableStateOf<String?>(null) }
    var dateFilter by remember { mutableIntStateOf(0) }
    var typeFilter by remember { mutableIntStateOf(0) }

    val filteredSessions = remember(sessions, dateFilter) {
        when (dateFilter) {
            1 -> { // This Week
                val cal = Calendar.getInstance()
                val week = cal.get(Calendar.WEEK_OF_YEAR)
                val year = cal.get(Calendar.YEAR)
                sessions.filter { s ->
                    val c = Calendar.getInstance().apply { timeInMillis = s.startTime }
                    c.get(Calendar.WEEK_OF_YEAR) == week && c.get(Calendar.YEAR) == year
                }
            }
            2 -> { // This Month
                val cal = Calendar.getInstance()
                val month = cal.get(Calendar.MONTH)
                val year = cal.get(Calendar.YEAR)
                sessions.filter { s ->
                    val c = Calendar.getInstance().apply { timeInMillis = s.startTime }
                    c.get(Calendar.MONTH) == month && c.get(Calendar.YEAR) == year
                }
            }
            else -> sessions
        }.sortedByDescending { it.startTime }
    }

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .background(DarkBg),
        contentPadding = PaddingValues(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        // ── Header ──
        item {
            Column(modifier = Modifier.padding(top = 16.dp)) {
                Text(
                    "Match History",
                    fontSize = 30.sp,
                    fontWeight = FontWeight.Bold,
                    color = TextPrimary
                )
                Spacer(Modifier.height(4.dp))
                Text(
                    "Review your past performances",
                    fontSize = 14.sp,
                    color = TextSecondary
                )
            }
        }

        // ── Filter Section ──
        item {
            GlassCard {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    // Date Range
                    FilterDropdown(
                        label = "Date Range",
                        options = dateFilterOptions,
                        selectedIndex = dateFilter,
                        onSelect = { dateFilter = it },
                        modifier = Modifier.weight(1f)
                    )
                    // Match Type
                    FilterDropdown(
                        label = "Match Type",
                        options = typeFilterOptions,
                        selectedIndex = typeFilter,
                        onSelect = { typeFilter = it },
                        modifier = Modifier.weight(1f)
                    )
                }
            }
        }

        // ── Recent Matches header ──
        item {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text("Recent Matches", fontSize = 18.sp, fontWeight = FontWeight.Bold, color = TextPrimary)
                Text("${filteredSessions.size} matches", fontSize = 13.sp, color = TextSecondary)
            }
        }

        // ── Match Cards ──
        itemsIndexed(filteredSessions, key = { _, s -> s.id }) { _, session ->
            MatchHistoryCard(
                session = session,
                isExpanded = expandedSessionId == session.id,
                onToggle = {
                    expandedSessionId = if (expandedSessionId == session.id) null else session.id
                }
            )
        }

        item { Spacer(Modifier.height(80.dp)) }
    }
}

// ── Filter Dropdown ──
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun FilterDropdown(
    label: String,
    options: List<String>,
    selectedIndex: Int,
    onSelect: (Int) -> Unit,
    modifier: Modifier = Modifier
) {
    var expanded by remember { mutableStateOf(false) }

    Column(modifier = modifier) {
        Text(label, fontSize = 11.sp, color = TextSecondary)
        Spacer(Modifier.height(6.dp))
        ExposedDropdownMenuBox(
            expanded = expanded,
            onExpandedChange = { expanded = it }
        ) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .menuAnchor(MenuAnchorType.PrimaryNotEditable)
                    .clip(RoundedCornerShape(10.dp))
                    .background(Color.Black.copy(alpha = 0.30f))
                    .border(1.dp, CardBorderColor, RoundedCornerShape(10.dp))
                    .clickable { expanded = true }
                    .padding(horizontal = 12.dp, vertical = 10.dp)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(options[selectedIndex], fontSize = 13.sp, color = TextPrimary)
                    Icon(
                        if (expanded) Icons.Rounded.KeyboardArrowUp else Icons.Rounded.KeyboardArrowDown,
                        null,
                        tint = TextSecondary,
                        modifier = Modifier.size(18.dp)
                    )
                }
            }
            ExposedDropdownMenu(
                expanded = expanded,
                onDismissRequest = { expanded = false },
                containerColor = CardBg
            ) {
                options.forEachIndexed { index, text ->
                    DropdownMenuItem(
                        text = { Text(text, fontSize = 13.sp, color = TextPrimary) },
                        onClick = {
                            onSelect(index)
                            expanded = false
                        }
                    )
                }
            }
        }
    }
}

// ── Match History Card ──
@Composable
private fun MatchHistoryCard(
    session: SessionEntity,
    isExpanded: Boolean,
    onToggle: () -> Unit
) {
    val dateFmt = SimpleDateFormat("MMM d, yyyy", Locale.ENGLISH)
    val timeFmt = SimpleDateFormat("HH:mm", Locale.ENGLISH)
    val dateStr = dateFmt.format(Date(session.startTime))
    val timeStr = timeFmt.format(Date(session.startTime))
    val durationMin = ((session.endTime - session.startTime) / 60_000).toInt()
    val distKm = session.totalDistanceMeters / 1000.0

    // Determine result based on performance score
    val perfScore = performanceScore(session)
    val result = when {
        perfScore >= 8.0 -> "W"
        perfScore >= 7.0 -> "D"
        else -> "L"
    }
    val resultColor = when (result) {
        "W" -> AccentGreen
        "D" -> Color(0xFFEAB308)
        else -> Color(0xFFEF4444)
    }

    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(CardGlass)
            .border(1.dp, CardBorderColor, RoundedCornerShape(16.dp))
    ) {
        Column {
            // ── Preview Section ──
            Column(
                modifier = Modifier
                    .clickable(onClick = onToggle)
                    .padding(16.dp)
            ) {
                // Top row: result badge + info + score
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.Top
                ) {
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.weight(1f)
                    ) {
                        // Result badge
                        Box(
                            modifier = Modifier
                                .size(48.dp)
                                .clip(RoundedCornerShape(12.dp))
                                .background(resultColor.copy(alpha = 0.20f)),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                result,
                                fontSize = 18.sp,
                                fontWeight = FontWeight.Bold,
                                color = resultColor
                            )
                        }

                        Column {
                            Text(
                                "Session #${session.id.takeLast(4)}",
                                fontSize = 16.sp,
                                fontWeight = FontWeight.Bold,
                                color = TextPrimary
                            )
                            Spacer(Modifier.height(2.dp))
                            Row(
                                horizontalArrangement = Arrangement.spacedBy(6.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Icon(Icons.Rounded.CalendarToday, null, tint = TextSecondary, modifier = Modifier.size(12.dp))
                                Text(dateStr, fontSize = 11.sp, color = TextSecondary)
                                Text("•", fontSize = 11.sp, color = TextSecondary)
                                Text(timeStr, fontSize = 11.sp, color = TextSecondary)
                            }
                        }
                    }

                    Column(horizontalAlignment = Alignment.End) {
                        Text(
                            "%.1f".format(perfScore),
                            fontSize = 24.sp,
                            fontWeight = FontWeight.Bold,
                            color = TextPrimary
                        )
                        Icon(
                            if (isExpanded) Icons.Rounded.KeyboardArrowUp else Icons.Rounded.KeyboardArrowDown,
                            null,
                            tint = if (isExpanded) AccentGreen else TextSecondary,
                            modifier = Modifier.size(16.dp)
                        )
                    }
                }

                Spacer(Modifier.height(12.dp))

                // Quick Stats row
                HorizontalDivider(thickness = 1.dp, color = CardBorderColor)
                Spacer(Modifier.height(12.dp))
                Box(modifier = Modifier.fillMaxWidth()) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        QuickStatItem(Icons.Rounded.Timer, "${durationMin}'", "Duration", Modifier.weight(1f))
                        QuickStatItem(Icons.Rounded.Place, "%.1f".format(distKm), "km", Modifier.weight(1f))
                        QuickStatItem(Icons.Rounded.LocalFireDepartment, "${session.caloriesBurned.toInt()}", "kcal", Modifier.weight(1f))
                        QuickStatItem(Icons.Rounded.FavoriteBorder, "${session.avgHeartRate}", "avg bpm", Modifier.weight(1f))
                    }
                }
            }

            // ── Expanded Detail ──
            AnimatedVisibility(
                visible = isExpanded,
                enter = expandVertically(),
                exit = shrinkVertically()
            ) {
                Column {
                    HorizontalDivider(thickness = 1.dp, color = CardBorderColor)
                    Column(
                        modifier = Modifier.padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(16.dp)
                    ) {
                    // Performance Metrics 3x3
                    PerformanceMetricsGrid(session)

                    // Movement Heatmap
                    MiniHeatmapSection()

                    // Match Timeline
                    TimelineSection(session)

                    // Heart Rate Chart
                    HeartRateSection(session)

                    // Speed Chart
                    SpeedSection(session)
                    }
                }
            }
        }
    }
}

@Composable
private fun QuickStatItem(icon: ImageVector, value: String, label: String, modifier: Modifier) {
    Column(
        modifier = modifier
            .clip(RoundedCornerShape(10.dp))
            .background(Color.Black.copy(alpha = 0.20f))
            .padding(vertical = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Icon(icon, null, tint = AccentGreen, modifier = Modifier.size(14.dp))
        Spacer(Modifier.height(4.dp))
        Text(value, fontSize = 13.sp, fontWeight = FontWeight.Bold, color = TextPrimary)
        Text(label, fontSize = 10.sp, color = TextSecondary)
    }
}

// ── Performance Metrics Grid ──
@Composable
private fun PerformanceMetricsGrid(session: SessionEntity) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text("Performance Metrics", fontSize = 13.sp, fontWeight = FontWeight.Bold, color = TextPrimary)

        data class PerfMetric(val icon: ImageVector, val value: String, val label: String)

        val metrics = listOf(
            PerfMetric(Icons.Rounded.EmojiEvents, "${session.sprintCount / 3}", "Goals"),
            PerfMetric(Icons.Rounded.Handshake, "${session.sprintCount / 5}", "Assists"),
            PerfMetric(Icons.Rounded.FlashOn, "${session.sprintCount}", "Sprints"),
            PerfMetric(Icons.AutoMirrored.Rounded.TrendingUp, "%.1f".format(session.maxSpeedKmh), "Max km/h"),
            PerfMetric(Icons.Rounded.Speed, "%.1f".format(session.avgSpeedKmh), "Avg km/h"),
            PerfMetric(Icons.Rounded.GpsFixed, "%.0f%%".format(session.coveragePercent * 100), "Coverage"),
            PerfMetric(Icons.Rounded.Favorite, "${session.maxHeartRate}", "Max BPM"),
            PerfMetric(Icons.Rounded.FavoriteBorder, "${session.avgHeartRate}", "Avg BPM"),
            PerfMetric(Icons.Rounded.FitnessCenter, "${session.caloriesBurned.toInt()}", "Calories"),
        )

        for (row in 0 until 3) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                for (col in 0 until 3) {
                    val m = metrics[row * 3 + col]
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .clip(RoundedCornerShape(10.dp))
                            .background(Color.Black.copy(alpha = 0.30f))
                            .padding(12.dp)
                    ) {
                        Column {
                            Icon(m.icon, null, tint = AccentGreen, modifier = Modifier.size(16.dp))
                            Spacer(Modifier.height(4.dp))
                            Text(m.value, fontSize = 18.sp, fontWeight = FontWeight.Bold, color = TextPrimary)
                            Text(m.label, fontSize = 10.sp, color = TextSecondary)
                        }
                    }
                }
            }
        }
    }
}

// ── Mini Heatmap Section ──
@Composable
private fun MiniHeatmapSection() {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text("Movement Heatmap", fontSize = 13.sp, fontWeight = FontWeight.Bold, color = TextPrimary)

        Box(
            modifier = Modifier
                .fillMaxWidth()
                .aspectRatio(2f / 3f)
                .clip(RoundedCornerShape(12.dp))
                .background(
                    Brush.verticalGradient(
                        listOf(Color(0xFF0A3D0A).copy(alpha = 0.40f), Color(0xFF072307).copy(alpha = 0.40f))
                    )
                )
                .border(2.dp, Color.White.copy(alpha = 0.20f), RoundedCornerShape(12.dp))
        ) {
            // Field lines
            Canvas(modifier = Modifier.fillMaxSize()) {
                val w = size.width
                val h = size.height
                val lineColor = Color.White.copy(alpha = 0.30f)
                val lineStroke = Stroke(width = 2f)

                drawLine(lineColor, Offset(0f, h / 2), Offset(w, h / 2), strokeWidth = 2f)
                drawCircle(lineColor, radius = w * 0.10f, center = Offset(w / 2, h / 2), style = lineStroke)

                val penaltyW = w * 0.75f
                val penaltyH = h * 0.25f
                drawRect(lineColor, Offset((w - penaltyW) / 2, 0f), Size(penaltyW, penaltyH), style = lineStroke)
                drawRect(lineColor, Offset((w - penaltyW) / 2, h - penaltyH), Size(penaltyW, penaltyH), style = lineStroke)
            }

            // Glow spots
            Box(Modifier.align(Alignment.TopCenter).offset(y = 60.dp).size(64.dp).clip(CircleShape).background(AccentGreen.copy(alpha = 0.40f)).blur(20.dp))
            Box(Modifier.align(Alignment.CenterStart).offset(x = 20.dp, y = (-30).dp).size(48.dp).clip(CircleShape).background(AccentGreen.copy(alpha = 0.30f)).blur(16.dp))
            Box(Modifier.align(Alignment.CenterEnd).offset(x = (-20).dp, y = (-30).dp).size(48.dp).clip(CircleShape).background(AccentGreen.copy(alpha = 0.30f)).blur(16.dp))
            Box(Modifier.align(Alignment.Center).size(80.dp).clip(CircleShape).background(AccentGreen.copy(alpha = 0.50f)).blur(24.dp))
            Box(Modifier.align(Alignment.Center).offset(x = (-20).dp, y = 40.dp).size(40.dp).clip(CircleShape).background(AccentGreen.copy(alpha = 0.25f)).blur(16.dp))
            Box(Modifier.align(Alignment.Center).offset(x = 20.dp, y = 35.dp).size(40.dp).clip(CircleShape).background(AccentGreen.copy(alpha = 0.25f)).blur(16.dp))
        }
    }
}

// ── Timeline Section ──
@Composable
private fun TimelineSection(session: SessionEntity) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text("Match Timeline", fontSize = 13.sp, fontWeight = FontWeight.Bold, color = TextPrimary)

        val durationMin = ((session.endTime - session.startTime) / 60_000).toInt()
        val halfTime = durationMin / 2

        data class TimelineEvent(val minute: Int, val event: String, val type: String)

        val events = listOf(
            TimelineEvent(0, "Kickoff", "start"),
            TimelineEvent(halfTime, "Half Time", "halftime"),
            TimelineEvent(durationMin, "Full Time", "end")
        )

        Box(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(12.dp))
                .background(Color.Black.copy(alpha = 0.30f))
                .padding(16.dp)
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                events.forEach { evt ->
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        Text(
                            "${evt.minute}'",
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Medium,
                            color = TextSecondary,
                            modifier = Modifier.width(36.dp)
                        )
                        Box(
                            modifier = Modifier
                                .size(8.dp)
                                .clip(CircleShape)
                                .background(
                                    when (evt.type) {
                                        "start", "end" -> Color.Gray
                                        "halftime" -> Color(0xFFEAB308)
                                        "goal" -> AccentGreen
                                        "assist" -> Color(0xFF3B82F6)
                                        else -> Color.Gray
                                    }
                                )
                        )
                        Text(evt.event, fontSize = 13.sp, color = TextPrimary)
                    }
                }
            }
        }
    }
}

// ── Heart Rate Section ──
@Composable
private fun HeartRateSection(session: SessionEntity) {
    val textMeasurer = rememberTextMeasurer()
    val axisStyle = TextStyle(color = Color.Gray, fontSize = 10.sp)

    // Simulated HR data from session
    val hrData = remember(session) {
        val base = session.avgHeartRate.toFloat().coerceAtLeast(70f)
        val maxHr = session.maxHeartRate.toFloat().coerceAtLeast(base + 20f)
        listOf(
            base * 0.55f,
            base * 0.85f,
            base * 1.08f,
            maxHr * 0.92f,
            base * 1.02f,
            maxHr * 0.98f,
            base * 0.62f
        )
    }
    val timeLabels = listOf("0", "15", "30", "45", "60", "75", "90")

    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text("Heart Rate", fontSize = 13.sp, fontWeight = FontWeight.Bold, color = TextPrimary)

        Box(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(12.dp))
                .background(Color.Black.copy(alpha = 0.30f))
                .padding(12.dp)
        ) {
            Canvas(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(140.dp)
            ) {
                val leftPad = 36f
                val bottomPad = 24f
                val chartW = size.width - leftPad
                val chartH = size.height - bottomPad
                val minVal = 60f
                val maxVal = 180f
                val range = maxVal - minVal

                val gridColor = Color.White.copy(alpha = 0.08f)
                val dashEffect = PathEffect.dashPathEffect(floatArrayOf(6f, 4f))
                for (i in 0..3) {
                    val y = chartH * (1 - i / 3f)
                    drawLine(gridColor, Offset(leftPad, y), Offset(size.width, y), pathEffect = dashEffect)
                    drawText(textMeasurer, "${(minVal + range * i / 3).toInt()}", Offset(0f, y - 6f), style = axisStyle)
                }

                for (i in timeLabels.indices) {
                    val x = leftPad + chartW * i / (timeLabels.size - 1)
                    drawText(textMeasurer, timeLabels[i], Offset(x - 6f, chartH + 4f), style = axisStyle)
                }

                if (hrData.size < 2) return@Canvas

                val points = hrData.mapIndexed { index, value ->
                    val x = leftPad + chartW * index / (hrData.size - 1)
                    val y = chartH * (1 - (value - minVal) / range)
                    Offset(x, y.coerceIn(0f, chartH))
                }

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
                        startY = 0f, endY = chartH
                    )
                )

                val linePath = Path().apply {
                    moveTo(points.first().x, points.first().y)
                    for (i in 1 until points.size) lineTo(points[i].x, points[i].y)
                }
                drawPath(linePath, AccentGreen, style = Stroke(width = 2f, cap = StrokeCap.Round))
            }
        }
    }
}

// ── Speed Section ──
@Composable
private fun SpeedSection(session: SessionEntity) {
    val textMeasurer = rememberTextMeasurer()
    val axisStyle = TextStyle(color = Color.Gray, fontSize = 10.sp)

    // Simulated speed data per 15min period
    val speedData = remember(session) {
        val avg = session.avgSpeedKmh.toFloat().coerceAtLeast(5f)
        val maxS = session.maxSpeedKmh.toFloat().coerceAtLeast(avg + 3f)
        listOf(
            avg * 0.7f,
            avg * 1.15f,
            maxS * 0.85f,
            avg * 0.95f,
            maxS * 0.9f,
            avg * 0.65f
        )
    }
    val timeLabels = listOf("0-15", "15-30", "30-45", "45-60", "60-75", "75-90")

    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text("Speed Over Time", fontSize = 13.sp, fontWeight = FontWeight.Bold, color = TextPrimary)

        Box(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(12.dp))
                .background(Color.Black.copy(alpha = 0.30f))
                .padding(12.dp)
        ) {
            Canvas(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(140.dp)
            ) {
                val leftPad = 36f
                val bottomPad = 28f
                val chartW = size.width - leftPad
                val chartH = size.height - bottomPad
                val maxVal = (speedData.maxOrNull() ?: 20f) * 1.2f

                val gridColor = Color.White.copy(alpha = 0.08f)
                val dashEffect = PathEffect.dashPathEffect(floatArrayOf(6f, 4f))
                for (i in 0..3) {
                    val y = chartH * (1 - i / 3f)
                    drawLine(gridColor, Offset(leftPad, y), Offset(size.width, y), pathEffect = dashEffect)
                    drawText(textMeasurer, "%.0f".format(maxVal * i / 3), Offset(0f, y - 6f), style = axisStyle)
                }

                val barCount = speedData.size
                val gap = chartW * 0.08f / barCount
                val barW = (chartW - gap * (barCount + 1)) / barCount

                speedData.forEachIndexed { index, speed ->
                    val barH = chartH * speed / maxVal
                    val x = leftPad + gap + index * (barW + gap)
                    val y = chartH - barH

                    drawRoundRect(
                        AccentGreen,
                        Offset(x, y),
                        Size(barW, barH),
                        CornerRadius(6f, 6f)
                    )

                    drawText(
                        textMeasurer,
                        timeLabels[index],
                        Offset(x + barW / 2 - 14f, chartH + 4f),
                        style = axisStyle
                    )
                }
            }
        }
    }
}

// ── Glass Card ──
@Composable
private fun GlassCard(content: @Composable ColumnScope.() -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(CardGlass)
            .border(1.dp, CardBorderColor, RoundedCornerShape(16.dp))
            .padding(16.dp)
    ) {
        Column(content = content)
    }
}

// ── Utils ──
private fun performanceScore(s: SessionEntity): Double {
    val speed = min(1.0, s.maxSpeedKmh / 30.0)
    val sprint = min(1.0, s.sprintCount.toDouble() / 45.0)
    val distance = min(1.0, s.totalDistanceMeters / 9000.0)
    val discipline = max(0.0, 1.0 - s.slackIndex.toDouble() / 100.0)
    val weighted = speed * 0.3 + sprint * 0.25 + distance * 0.25 + discipline * 0.2
    return min(10.0, max(6.0, 6.0 + weighted * 4.0))
}
