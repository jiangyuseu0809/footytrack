package com.footballtracker.android.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.rounded.DirectionsRun
import androidx.compose.material.icons.automirrored.rounded.TrendingUp
import androidx.compose.material.icons.rounded.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.footballtracker.android.data.db.SessionEntity
import com.footballtracker.android.ui.components.StatCard
import com.footballtracker.android.ui.theme.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StatsScreen(
    sessions: List<SessionEntity>,
    onBack: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(DarkBg)
    ) {
        // Top bar area
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    Brush.verticalGradient(
                        listOf(NeonPurple.copy(alpha = 0.12f), DarkBg)
                    )
                )
                .padding(top = 8.dp)
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.padding(horizontal = 4.dp, vertical = 8.dp)
            ) {
                IconButton(onClick = onBack) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, "返回", tint = TextPrimary)
                }
                Text(
                    text = "统计",
                    fontSize = 20.sp,
                    fontWeight = FontWeight.Bold,
                    color = TextPrimary
                )
            }
        }

        if (sessions.isEmpty()) {
            Box(
                modifier = Modifier.fillMaxSize(),
                contentAlignment = Alignment.Center
            ) {
                Text("暂无数据", fontSize = 16.sp, color = TextSecondary)
            }
        } else {
            val totalSessions = sessions.size
            val totalDistance = sessions.sumOf { it.totalDistanceMeters }
            val totalTime = sessions.sumOf { it.endTime - it.startTime } / 1000
            val avgSlack = sessions.map { it.slackIndex }.average().toInt()
            val totalCalories = sessions.sumOf { it.caloriesBurned }
            val maxSpeed = sessions.maxOf { it.maxSpeedKmh }
            val avgDistance = totalDistance / totalSessions

            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 16.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                // Overview gradient card
                Card(
                    shape = RoundedCornerShape(16.dp),
                    colors = CardDefaults.cardColors(containerColor = Color.Transparent),
                    elevation = CardDefaults.cardElevation(0.dp),
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(
                                Brush.horizontalGradient(
                                    listOf(
                                        NeonBlue.copy(alpha = 0.15f),
                                        NeonPurple.copy(alpha = 0.15f)
                                    )
                                )
                            )
                            .padding(24.dp)
                    ) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
                            Text("总览", fontSize = 13.sp, color = TextSecondary)
                            Spacer(modifier = Modifier.height(12.dp))
                            Row(
                                modifier = Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceEvenly
                            ) {
                                OverviewItem("%.1f".format(totalDistance / 1000), "km", NeonBlue)
                                OverviewItem("$totalSessions", "场", NeonPurple)
                                OverviewItem("${totalTime / 3600}", "小时", SpeedGreen)
                            }
                        }
                    }
                }

                Spacer(modifier = Modifier.height(4.dp))

                // Detail stat cards
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    StatCard(
                        label = "总距离",
                        value = "%.1f".format(totalDistance / 1000),
                        unit = "km",
                        color = NeonBlue,
                        icon = Icons.AutoMirrored.Rounded.DirectionsRun,
                        modifier = Modifier.weight(1f)
                    )
                    StatCard(
                        label = "总卡路里",
                        value = "${totalCalories.toInt()}",
                        unit = "kcal",
                        color = CalorieOrange,
                        icon = Icons.Rounded.LocalFireDepartment,
                        modifier = Modifier.weight(1f)
                    )
                }

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    StatCard(
                        label = "场均距离",
                        value = "%.1f".format(avgDistance / 1000),
                        unit = "km",
                        color = SpeedGreen,
                        icon = Icons.AutoMirrored.Rounded.TrendingUp,
                        modifier = Modifier.weight(1f)
                    )
                    StatCard(
                        label = "最高速度",
                        value = "%.1f".format(maxSpeed),
                        unit = "km/h",
                        color = SpeedGreen,
                        icon = Icons.Rounded.Speed,
                        modifier = Modifier.weight(1f)
                    )
                }

                // Slack index
                val slackColor = when (avgSlack) {
                    in 0..30 -> SlackGreen
                    in 31..60 -> SlackYellow
                    else -> SlackRed
                }
                StatCard(
                    label = "平均摸鱼指数",
                    value = "$avgSlack",
                    unit = "/100",
                    color = slackColor,
                    modifier = Modifier.fillMaxWidth()
                )

                Spacer(modifier = Modifier.height(80.dp))
            }
        }
    }
}

@Composable
private fun OverviewItem(value: String, unit: String, color: Color) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Row(verticalAlignment = Alignment.Bottom) {
            Text(
                text = value,
                fontSize = 28.sp,
                fontWeight = FontWeight.Bold,
                color = color
            )
            Spacer(modifier = Modifier.width(2.dp))
            Text(
                text = unit,
                fontSize = 12.sp,
                color = color.copy(alpha = 0.7f),
                modifier = Modifier.padding(bottom = 4.dp)
            )
        }
    }
}
