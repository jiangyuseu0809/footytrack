package com.footballtracker.android.ui.screens

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.ContentCopy
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.footballtracker.android.network.ApiClient
import com.footballtracker.android.network.TeamDetailResponse
import com.footballtracker.android.network.TeamMemberResponse
import com.footballtracker.android.ui.theme.*

@Composable
fun TeamDetailScreen(
    teamId: String,
    onBack: () -> Unit
) {
    val context = LocalContext.current
    var detail by remember { mutableStateOf<TeamDetailResponse?>(null) }
    var isLoading by remember { mutableStateOf(true) }

    LaunchedEffect(teamId) {
        try {
            detail = ApiClient.api.getTeamDetail(teamId)
        } catch (_: Exception) {}
        isLoading = false
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
                text = detail?.team?.name ?: "球队详情",
                fontSize = 28.sp,
                fontWeight = FontWeight.Bold,
                color = TextPrimary
            )
        }

        if (isLoading) {
            Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator(color = NeonBlue)
            }
        } else {
            detail?.let { d ->
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .verticalScroll(rememberScrollState())
                        .padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    // Invite code card
                    Card(
                        shape = RoundedCornerShape(16.dp),
                        colors = CardDefaults.cardColors(containerColor = CardBg),
                        elevation = CardDefaults.cardElevation(0.dp)
                    ) {
                        Row(
                            modifier = Modifier.padding(16.dp).fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column {
                                Text("邀请码", fontSize = 12.sp, color = TextSecondary)
                                Spacer(modifier = Modifier.height(4.dp))
                                Text(
                                    d.team.inviteCode,
                                    fontSize = 24.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = NeonBlue,
                                    letterSpacing = 4.sp
                                )
                            }
                            IconButton(onClick = {
                                val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                                clipboard.setPrimaryClip(ClipData.newPlainText("invite_code", d.team.inviteCode))
                            }) {
                                Icon(Icons.Rounded.ContentCopy, contentDescription = "复制", tint = NeonBlue)
                            }
                        }
                    }

                    // Leaderboard
                    Card(
                        shape = RoundedCornerShape(16.dp),
                        colors = CardDefaults.cardColors(containerColor = CardBg),
                        elevation = CardDefaults.cardElevation(0.dp)
                    ) {
                        Column(modifier = Modifier.padding(16.dp)) {
                            Text("排行榜", fontSize = 16.sp, fontWeight = FontWeight.SemiBold, color = TextPrimary)
                            Spacer(modifier = Modifier.height(12.dp))

                            d.members.forEachIndexed { index, member ->
                                MemberRow(rank = index + 1, member = member)
                                if (index < d.members.size - 1) {
                                    Spacer(modifier = Modifier.height(8.dp))
                                }
                            }
                        }
                    }

                    Spacer(modifier = Modifier.height(80.dp))
                }
            }
        }
    }
}

@Composable
private fun MemberRow(rank: Int, member: TeamMemberResponse) {
    val rankColor = when (rank) {
        1 -> Color(0xFFFFD700)
        2 -> Color(0xFFC0C0C0)
        3 -> Color(0xFFCD7F32)
        else -> TextSecondary
    }
    val medal = when (rank) {
        1 -> "🥇"
        2 -> "🥈"
        3 -> "🥉"
        else -> null
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(10.dp))
            .background(CardBgLight)
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        // Rank badge
        Box(
            modifier = Modifier
                .size(32.dp)
                .clip(CircleShape)
                .background(rankColor.copy(alpha = 0.2f)),
            contentAlignment = Alignment.Center
        ) {
            if (medal != null) {
                Text(medal, fontSize = 16.sp)
            } else {
                Text("$rank", fontSize = 14.sp, fontWeight = FontWeight.Bold, color = TextSecondary)
            }
        }

        // Name + stats
        Column(modifier = Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    member.nickname.ifEmpty { "球员" },
                    fontSize = 15.sp,
                    fontWeight = FontWeight.Medium,
                    color = TextPrimary
                )
                if (member.role == "owner") {
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        "队长",
                        fontSize = 10.sp,
                        color = CalorieOrange,
                        modifier = Modifier
                            .clip(RoundedCornerShape(4.dp))
                            .background(CalorieOrange.copy(alpha = 0.2f))
                            .padding(horizontal = 6.dp, vertical = 2.dp)
                    )
                }
            }
            val distKm = "%.1f".format(member.totalDistanceMeters / 1000.0)
            Text("${member.sessionCount} 场 · $distKm km", fontSize = 12.sp, color = TextSecondary)
        }

        // Session count
        Text(
            "${member.sessionCount} 场",
            fontSize = 15.sp,
            fontWeight = FontWeight.Bold,
            color = NeonBlue
        )
    }
}
