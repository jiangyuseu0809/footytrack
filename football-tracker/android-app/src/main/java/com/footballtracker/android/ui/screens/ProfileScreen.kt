package com.footballtracker.android.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowForwardIos
import androidx.compose.material.icons.rounded.Group
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.footballtracker.android.data.db.SessionEntity
import com.footballtracker.android.network.ApiClient
import com.footballtracker.android.network.EarnedBadgesResponse
import com.footballtracker.android.network.TeamResponse
import com.footballtracker.android.ui.components.BadgeGrid
import com.footballtracker.android.ui.components.SlackBadge
import com.footballtracker.android.ui.theme.*
import kotlinx.coroutines.launch

@Composable
fun ProfileScreen(
    sessions: List<SessionEntity>,
    onSessionClick: (String) -> Unit,
    onNavigateTeams: () -> Unit,
    onNavigateTeamDetail: (String) -> Unit
) {
    val scope = rememberCoroutineScope()
    var teams by remember { mutableStateOf<List<TeamResponse>>(emptyList()) }
    var badgesResponse by remember { mutableStateOf<EarnedBadgesResponse?>(null) }

    LaunchedEffect(Unit) {
        try {
            val teamsResp = ApiClient.api.getTeams()
            teams = teamsResp.teams
        } catch (_: Exception) {}
        try {
            badgesResponse = ApiClient.api.getEarnedBadges()
        } catch (_: Exception) {}
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(DarkBg)
    ) {
        // Header
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    Brush.verticalGradient(
                        listOf(NeonBlue.copy(alpha = 0.15f), DarkBg)
                    )
                )
                .padding(top = 16.dp, start = 20.dp, end = 20.dp, bottom = 4.dp)
        ) {
            Text(
                text = "我的",
                fontSize = 28.sp,
                fontWeight = FontWeight.Bold,
                color = TextPrimary
            )
        }

        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            // Recent sessions
            Card(
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(containerColor = CardBg),
                elevation = CardDefaults.cardElevation(0.dp)
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text("最近比赛", fontSize = 16.sp, fontWeight = FontWeight.SemiBold, color = TextPrimary)
                        Text("${sessions.size} 场", fontSize = 14.sp, color = NeonBlue)
                    }
                    Spacer(modifier = Modifier.height(12.dp))

                    if (sessions.isEmpty()) {
                        Text(
                            "暂无比赛记录",
                            fontSize = 14.sp,
                            color = TextSecondary,
                            modifier = Modifier.fillMaxWidth().padding(vertical = 20.dp),
                        )
                    } else {
                        sessions.take(3).forEach { session ->
                            val dateFormat = java.text.SimpleDateFormat("MM/dd EEE HH:mm", java.util.Locale.CHINESE)
                            val dateStr = dateFormat.format(java.util.Date(session.startTime))
                            val distKm = "%.1f".format(session.totalDistanceMeters / 1000.0)
                            val durationMin = (session.endTime - session.startTime) / 60_000

                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clip(RoundedCornerShape(10.dp))
                                    .background(CardBgLight)
                                    .clickable { onSessionClick(session.id) }
                                    .padding(12.dp),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Column {
                                    Text(dateStr, fontSize = 14.sp, fontWeight = FontWeight.Medium, color = TextPrimary)
                                    Spacer(modifier = Modifier.height(4.dp))
                                    Text("${distKm}km · ${durationMin}分钟", fontSize = 12.sp, color = TextSecondary)
                                }
                                SlackBadge(session.slackIndex, session.slackLabel)
                            }
                            Spacer(modifier = Modifier.height(8.dp))
                        }
                    }
                }
            }

            // Teams
            Card(
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(containerColor = CardBg),
                elevation = CardDefaults.cardElevation(0.dp)
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text("我的球队", fontSize = 16.sp, fontWeight = FontWeight.SemiBold, color = TextPrimary)
                        Row(
                            modifier = Modifier.clickable { onNavigateTeams() },
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text("管理", fontSize = 14.sp, color = NeonBlue)
                            Spacer(modifier = Modifier.width(4.dp))
                            Icon(
                                Icons.AutoMirrored.Rounded.ArrowForwardIos,
                                contentDescription = null,
                                tint = NeonBlue,
                                modifier = Modifier.size(12.dp)
                            )
                        }
                    }
                    Spacer(modifier = Modifier.height(12.dp))

                    if (teams.isEmpty()) {
                        Text(
                            "还没有加入球队",
                            fontSize = 14.sp,
                            color = TextSecondary,
                            modifier = Modifier.fillMaxWidth().padding(vertical = 20.dp),
                        )
                    } else {
                        teams.forEach { team ->
                            Row(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clip(RoundedCornerShape(10.dp))
                                    .background(CardBgLight)
                                    .clickable { onNavigateTeamDetail(team.id) }
                                    .padding(12.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Icon(Icons.Rounded.Group, contentDescription = null, tint = NeonBlue)
                                Spacer(modifier = Modifier.width(12.dp))
                                Text(team.name, color = TextPrimary, fontSize = 15.sp)
                                Spacer(modifier = Modifier.weight(1f))
                                Icon(
                                    Icons.AutoMirrored.Rounded.ArrowForwardIos,
                                    contentDescription = null,
                                    tint = TextSecondary,
                                    modifier = Modifier.size(14.dp)
                                )
                            }
                            Spacer(modifier = Modifier.height(8.dp))
                        }
                    }
                }
            }

            // Badge wall
            Card(
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.cardColors(containerColor = CardBg),
                elevation = CardDefaults.cardElevation(0.dp)
            ) {
                Column(modifier = Modifier.padding(16.dp)) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text("勋章墙", fontSize = 16.sp, fontWeight = FontWeight.SemiBold, color = TextPrimary)
                        badgesResponse?.let { resp ->
                            Text("${resp.earnedBadges.size}/${resp.allBadges.size}", fontSize = 14.sp, color = NeonBlue)
                        }
                    }
                    Spacer(modifier = Modifier.height(12.dp))

                    badgesResponse?.let { resp ->
                        BadgeGrid(
                            allBadges = resp.allBadges,
                            earnedBadges = resp.earnedBadges
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(80.dp))
        }
    }
}
