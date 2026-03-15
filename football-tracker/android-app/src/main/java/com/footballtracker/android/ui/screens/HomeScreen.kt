package com.footballtracker.android.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.DirectionsRun
import androidx.compose.material.icons.rounded.Favorite
import androidx.compose.material.icons.rounded.SportsSoccer
import androidx.compose.material.icons.rounded.Timer
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.footballtracker.android.data.db.SessionEntity
import com.footballtracker.android.ui.components.SlackBadge
import com.footballtracker.android.ui.theme.*
import java.text.SimpleDateFormat
import java.util.*

@Composable
fun HomeScreen(
    sessions: List<SessionEntity>,
    onSessionClick: (String) -> Unit
) {
    val currentMonth = remember {
        val cal = Calendar.getInstance()
        "${cal.get(Calendar.YEAR)}年${cal.get(Calendar.MONTH) + 1}月"
    }

    val currentMonthSessions = remember(sessions) {
        val cal = Calendar.getInstance()
        val thisYear = cal.get(Calendar.YEAR)
        val thisMonth = cal.get(Calendar.MONTH)
        sessions.filter { entity ->
            val eCal = Calendar.getInstance().apply { timeInMillis = entity.startTime }
            eCal.get(Calendar.YEAR) == thisYear && eCal.get(Calendar.MONTH) == thisMonth
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(DarkBg)
    ) {
        // Gradient header
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    Brush.verticalGradient(
                        listOf(
                            NeonBlue.copy(alpha = 0.15f),
                            DarkBg
                        )
                    )
                )
                .padding(top = 16.dp, start = 20.dp, end = 20.dp, bottom = 4.dp)
        ) {
            Column {
                Text(
                    text = "野球记",
                    fontSize = 28.sp,
                    fontWeight = FontWeight.Bold,
                    color = TextPrimary
                )
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = currentMonth,
                    fontSize = 14.sp,
                    color = TextSecondary
                )
            }
        }

        if (sessions.isEmpty()) {
            // Empty state
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(32.dp),
                contentAlignment = Alignment.Center
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Box(
                        modifier = Modifier
                            .size(80.dp)
                            .clip(CircleShape)
                            .background(NeonBlue.copy(alpha = 0.1f)),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            Icons.Rounded.SportsSoccer,
                            contentDescription = null,
                            tint = NeonBlue.copy(alpha = 0.6f),
                            modifier = Modifier.size(40.dp)
                        )
                    }
                    Spacer(modifier = Modifier.height(20.dp))
                    Text("还没有记录", fontSize = 18.sp, fontWeight = FontWeight.SemiBold, color = TextPrimary)
                    Spacer(modifier = Modifier.height(8.dp))
                    Text("在手表上开始记录踢球数据", fontSize = 14.sp, color = TextSecondary)
                }
            }
        } else {
            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                // Monthly summary card
                if (currentMonthSessions.isNotEmpty()) {
                    item {
                        MonthlySummaryCard(currentMonthSessions)
                        Spacer(modifier = Modifier.height(8.dp))
                    }
                }

                // Grouped sessions
                val grouped = sessions.groupBy { entity ->
                    val cal = Calendar.getInstance().apply { timeInMillis = entity.startTime }
                    "${cal.get(Calendar.YEAR)}年${cal.get(Calendar.MONTH) + 1}月"
                }
                grouped.forEach { (month, monthSessions) ->
                    item {
                        Text(
                            text = month,
                            fontSize = 13.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = TextSecondary,
                            modifier = Modifier.padding(vertical = 8.dp, horizontal = 4.dp)
                        )
                    }
                    items(monthSessions) { session ->
                        SessionListItem(session, onSessionClick)
                    }
                }

                item { Spacer(modifier = Modifier.height(80.dp)) }
            }
        }
    }
}

@Composable
private fun MonthlySummaryCard(sessions: List<SessionEntity>) {
    val totalDist = sessions.sumOf { it.totalDistanceMeters } / 1000.0
    val totalCalories = sessions.sumOf { it.caloriesBurned }.toInt()
    val totalSessions = sessions.size

    Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = Color.Transparent),
        elevation = CardDefaults.cardElevation(0.dp)
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    Brush.horizontalGradient(
                        listOf(
                            NeonBlue.copy(alpha = 0.18f),
                            NeonPurple.copy(alpha = 0.18f)
                        )
                    )
                )
                .padding(20.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceEvenly
            ) {
                SummaryItem(value = "%.1f".format(totalDist), unit = "km", label = "总距离", color = NeonBlue)
                SummaryItem(value = "$totalSessions", unit = "场", label = "总场次", color = NeonPurple)
                SummaryItem(value = "$totalCalories", unit = "kcal", label = "卡路里", color = CalorieOrange)
            }
        }
    }
}

@Composable
private fun SummaryItem(value: String, unit: String, label: String, color: Color) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Row(verticalAlignment = Alignment.Bottom) {
            Text(
                text = value,
                fontSize = 26.sp,
                fontWeight = FontWeight.Bold,
                color = color
            )
            Spacer(modifier = Modifier.width(2.dp))
            Text(
                text = unit,
                fontSize = 12.sp,
                fontWeight = FontWeight.Medium,
                color = color.copy(alpha = 0.7f),
                modifier = Modifier.padding(bottom = 3.dp)
            )
        }
        Spacer(modifier = Modifier.height(2.dp))
        Text(text = label, fontSize = 12.sp, color = TextSecondary)
    }
}

@Composable
private fun SessionListItem(
    session: SessionEntity,
    onClick: (String) -> Unit
) {
    val dateFormat = SimpleDateFormat("MM/dd EEE HH:mm", Locale.CHINESE)
    val dateStr = dateFormat.format(Date(session.startTime))
    val durationMin = (session.endTime - session.startTime) / 60_000
    val distKm = "%.1f".format(session.totalDistanceMeters / 1000.0)

    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onClick(session.id) },
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(containerColor = CardBg),
        elevation = CardDefaults.cardElevation(0.dp)
    ) {
        Row(modifier = Modifier.fillMaxWidth().height(IntrinsicSize.Min)) {
            // Left neon accent bar
            Box(
                modifier = Modifier
                    .width(4.dp)
                    .fillMaxHeight()
                    .clip(RoundedCornerShape(topStart = 12.dp, bottomStart = 12.dp))
                    .background(NeonGradientV)
            )

            Row(
                modifier = Modifier
                    .padding(14.dp)
                    .fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Column {
                    Text(
                        text = dateStr,
                        fontSize = 15.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = TextPrimary
                    )
                    Spacer(modifier = Modifier.height(6.dp))
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(12.dp)
                    ) {
                        // Distance
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(
                                Icons.AutoMirrored.Rounded.DirectionsRun,
                                contentDescription = null,
                                tint = NeonBlue,
                                modifier = Modifier.size(14.dp)
                            )
                            Spacer(modifier = Modifier.width(3.dp))
                            Text(
                                text = "${distKm}km",
                                fontSize = 12.sp,
                                color = NeonBlue
                            )
                        }
                        // Duration
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(
                                Icons.Rounded.Timer,
                                contentDescription = null,
                                tint = TextSecondary,
                                modifier = Modifier.size(14.dp)
                            )
                            Spacer(modifier = Modifier.width(3.dp))
                            Text(
                                text = "${durationMin}分钟",
                                fontSize = 12.sp,
                                color = TextSecondary
                            )
                        }
                        // Heart rate
                        if (session.avgHeartRate > 0) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Icon(
                                    Icons.Rounded.Favorite,
                                    contentDescription = null,
                                    tint = HeartRed,
                                    modifier = Modifier.size(14.dp)
                                )
                                Spacer(modifier = Modifier.width(3.dp))
                                Text(
                                    text = "${session.avgHeartRate}",
                                    fontSize = 12.sp,
                                    color = HeartRed.copy(alpha = 0.8f)
                                )
                            }
                        }
                    }
                }
                SlackBadge(session.slackIndex, session.slackLabel)
            }
        }
    }
}
