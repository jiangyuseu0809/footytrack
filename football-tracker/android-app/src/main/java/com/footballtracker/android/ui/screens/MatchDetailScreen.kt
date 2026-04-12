package com.footballtracker.android.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.footballtracker.android.network.*
import com.footballtracker.android.ui.theme.*
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.*

private fun teamColorFromName(name: String): Color = when (name.trim().lowercase()) {
    "red" -> Color(0xFFEF4444)
    "blue" -> Color(0xFF3B82F6)
    "green" -> Color(0xFF22C55E)
    "orange" -> Color(0xFFF97316)
    "yellow" -> Color(0xFFFACC15)
    "white" -> Color.White
    else -> Color.Gray
}

private fun teamColorLabel(name: String): String = when (name.trim().lowercase()) {
    "red" -> "红"
    "blue" -> "蓝"
    "green" -> "绿"
    "orange" -> "橙"
    "yellow" -> "黄"
    "white" -> "白"
    else -> name
}

@Composable
fun MatchDetailScreen(
    matchId: String,
    currentUid: String?,
    onBack: () -> Unit
) {
    val scope = rememberCoroutineScope()

    var detail by remember { mutableStateOf<MatchDetailResponse?>(null) }
    var isLoading by remember { mutableStateOf(true) }
    var isActionLoading by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var rankings by remember { mutableStateOf<MatchRankingsResponse?>(null) }
    var summaryText by remember { mutableStateOf<String?>(null) }
    var isSummaryLoading by remember { mutableStateOf(false) }
    var showDeleteConfirm by remember { mutableStateOf(false) }
    var showColorPicker by remember { mutableStateOf(false) }

    val match = detail?.match
    val registrations = detail?.registrations ?: emptyList()
    val isRegistered = detail?.isRegistered ?: false
    val isCreator = match?.creatorUid == currentUid

    val matchDate = match?.let { Date(it.matchDate) }
    val isMatchEnded = matchDate?.let {
        Date().after(Date(it.time + 3 * 3600 * 1000))
    } ?: false

    fun matchStatusInfo(): Pair<String, Color> {
        val md = matchDate ?: return "即将开赛" to Color(0xFFFACC15)
        val now = Date()
        return when {
            now.before(md) -> "即将开赛" to Color(0xFFFACC15)
            now.before(Date(md.time + 3 * 3600 * 1000)) -> "比赛中" to Color(0xFF22C55E)
            else -> "比赛结束" to Color(0xFF6B7280)
        }
    }

    fun loadDetail() {
        scope.launch {
            try {
                detail = ApiClient.api.getMatchDetail(matchId)
            } catch (e: Exception) {
                errorMessage = e.message
            }
            isLoading = false
        }
    }

    fun register(groupColor: String) {
        isActionLoading = true
        errorMessage = null
        scope.launch {
            try {
                ApiClient.api.registerForMatch(matchId, RegisterMatchBody(groupColor))
                detail = ApiClient.api.getMatchDetail(matchId)
            } catch (e: Exception) {
                errorMessage = e.message
            }
            isActionLoading = false
        }
    }

    fun cancelRegistration() {
        isActionLoading = true
        errorMessage = null
        scope.launch {
            try {
                ApiClient.api.cancelMatchRegistration(matchId)
                detail = ApiClient.api.getMatchDetail(matchId)
            } catch (e: Exception) {
                errorMessage = e.message
            }
            isActionLoading = false
        }
    }

    fun deleteMatch() {
        isActionLoading = true
        errorMessage = null
        scope.launch {
            try {
                ApiClient.api.deleteMatch(matchId)
                onBack()
            } catch (e: Exception) {
                errorMessage = e.message
            }
            isActionLoading = false
        }
    }

    LaunchedEffect(matchId) {
        loadDetail()
    }

    // Load rankings and summary for ended matches
    LaunchedEffect(isMatchEnded) {
        if (isMatchEnded) {
            try {
                rankings = ApiClient.api.getMatchRankings(matchId)
            } catch (_: Exception) {}

            isSummaryLoading = true
            try {
                val resp = ApiClient.api.getMatchSummary(matchId)
                summaryText = resp.summary
            } catch (_: Exception) {
                summaryText = "无法生成比赛总结"
            }
            isSummaryLoading = false
        }
    }

    // Delete confirmation dialog
    if (showDeleteConfirm) {
        AlertDialog(
            onDismissRequest = { showDeleteConfirm = false },
            containerColor = CardBg,
            title = { Text("确认删除", color = TextPrimary) },
            text = { Text("删除后无法恢复，所有报名信息将被清除。", color = TextSecondary) },
            confirmButton = {
                TextButton(onClick = {
                    showDeleteConfirm = false
                    deleteMatch()
                }) { Text("删除", color = HeartRed) }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteConfirm = false }) {
                    Text("取消", color = TextSecondary)
                }
            }
        )
    }

    // Color picker dialog
    if (showColorPicker && match != null) {
        val colors = match.groupColors.split(",").map { it.trim() }
        AlertDialog(
            onDismissRequest = { showColorPicker = false },
            containerColor = CardBg,
            title = { Text("选择队服颜色", color = TextPrimary) },
            text = {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    colors.forEach { colorName ->
                        val count = registrations.count { it.groupColor == colorName }
                        Surface(
                            onClick = {
                                showColorPicker = false
                                register(colorName)
                            },
                            shape = RoundedCornerShape(12.dp),
                            color = CardBgLight
                        ) {
                            Row(
                                modifier = Modifier.fillMaxWidth().padding(16.dp),
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                Box(
                                    modifier = Modifier
                                        .size(24.dp)
                                        .clip(CircleShape)
                                        .background(teamColorFromName(colorName))
                                )
                                Spacer(modifier = Modifier.width(12.dp))
                                Text(
                                    "${teamColorLabel(colorName)}队",
                                    fontSize = 15.sp,
                                    fontWeight = FontWeight.Medium,
                                    color = TextPrimary
                                )
                                Spacer(modifier = Modifier.weight(1f))
                                Text("${count}人已报名", fontSize = 12.sp, color = TextSecondary)
                            }
                        }
                    }
                }
            },
            confirmButton = {},
            dismissButton = {
                TextButton(onClick = { showColorPicker = false }) {
                    Text("取消", color = TextSecondary)
                }
            }
        )
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(DarkBg)
    ) {
        // Top bar
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 4.dp, vertical = 8.dp)
        ) {
            IconButton(onClick = onBack) {
                Icon(Icons.AutoMirrored.Filled.ArrowBack, "返回", tint = TextPrimary)
            }
            Text("比赛详情", fontSize = 20.sp, fontWeight = FontWeight.Bold, color = TextPrimary)
        }

        when {
            isLoading -> {
                Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(color = NeonBlue)
                }
            }
            match == null -> {
                Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Icon(Icons.Rounded.Warning, null, tint = TextSecondary, modifier = Modifier.size(48.dp))
                        Spacer(modifier = Modifier.height(8.dp))
                        Text("加载失败", color = TextSecondary)
                    }
                }
            }
            else -> {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .verticalScroll(rememberScrollState())
                        .padding(horizontal = 16.dp),
                    verticalArrangement = Arrangement.spacedBy(16.dp)
                ) {
                    // ── Match Info Card ──
                    MatchInfoCard(match, matchStatusInfo())

                    // ── Registration Section ──
                    RegistrationSection(match, registrations)

                    // ── Rankings (only after match ends) ──
                    if (isMatchEnded && rankings != null) {
                        RankingsSection(rankings!!)
                    }

                    // ── AI Summary (only after match ends) ──
                    if (isMatchEnded) {
                        SummarySection(summaryText, isSummaryLoading)
                    }

                    // ── Error ──
                    errorMessage?.let {
                        Text(it, fontSize = 13.sp, color = HeartRed)
                    }

                    // ── Actions ──
                    if (!isCreator) {
                        if (isRegistered) {
                            Button(
                                onClick = { cancelRegistration() },
                                enabled = !isActionLoading,
                                modifier = Modifier.fillMaxWidth().height(48.dp),
                                shape = RoundedCornerShape(12.dp),
                                colors = ButtonDefaults.buttonColors(containerColor = HeartRed)
                            ) {
                                if (isActionLoading) {
                                    CircularProgressIndicator(Modifier.size(18.dp), color = Color.White, strokeWidth = 2.dp)
                                    Spacer(Modifier.width(8.dp))
                                }
                                Text("取消报名", fontWeight = FontWeight.SemiBold, color = Color.White)
                            }
                        } else {
                            Button(
                                onClick = {
                                    val colors = match.groupColors.split(",").map { it.trim() }
                                    if (colors.size >= 2) {
                                        showColorPicker = true
                                    } else {
                                        register(colors.firstOrNull() ?: "")
                                    }
                                },
                                enabled = !isActionLoading,
                                modifier = Modifier.fillMaxWidth().height(48.dp),
                                shape = RoundedCornerShape(12.dp),
                                colors = ButtonDefaults.buttonColors(
                                    containerColor = Color.Transparent
                                )
                            ) {
                                Box(
                                    modifier = Modifier
                                        .fillMaxSize()
                                        .background(
                                            Brush.horizontalGradient(
                                                listOf(Color(0xFF3B82F6), Color(0xFF4F46E5))
                                            ),
                                            shape = RoundedCornerShape(12.dp)
                                        ),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Row(verticalAlignment = Alignment.CenterVertically) {
                                        if (isActionLoading) {
                                            CircularProgressIndicator(Modifier.size(18.dp), color = Color.White, strokeWidth = 2.dp)
                                            Spacer(Modifier.width(8.dp))
                                        }
                                        Text("立即报名", fontWeight = FontWeight.SemiBold, color = Color.White)
                                    }
                                }
                            }
                        }
                    }

                    if (isCreator) {
                        OutlinedButton(
                            onClick = { showDeleteConfirm = true },
                            modifier = Modifier.fillMaxWidth().height(48.dp),
                            shape = RoundedCornerShape(12.dp),
                            border = ButtonDefaults.outlinedButtonBorder(enabled = true),
                            colors = ButtonDefaults.outlinedButtonColors(
                                contentColor = HeartRed
                            )
                        ) {
                            Text("删除比赛", fontWeight = FontWeight.SemiBold)
                        }
                    }

                    Spacer(modifier = Modifier.height(32.dp))
                }
            }
        }
    }
}

@Composable
private fun MatchInfoCard(match: MatchResponse, statusInfo: Pair<String, Color>) {
    val dateFormat = SimpleDateFormat("M月d日 EEEE HH:mm", Locale.CHINESE)
    val dateText = dateFormat.format(Date(match.matchDate))
    val colors = match.groupColors.split(",").map { it.trim() }
    val totalPlayers = match.groups * match.playersPerGroup

    Card(
        shape = RoundedCornerShape(18.dp),
        colors = CardDefaults.cardColors(containerColor = Color.Transparent),
        elevation = CardDefaults.cardElevation(0.dp)
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    Brush.linearGradient(
                        listOf(Color(0xFF16803B), Color(0xFF166534))
                    )
                )
                .padding(16.dp)
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text(match.title, fontSize = 18.sp, fontWeight = FontWeight.Bold, color = Color.White)
                    Box(
                        modifier = Modifier
                            .clip(RoundedCornerShape(6.dp))
                            .background(statusInfo.second)
                            .padding(horizontal = 8.dp, vertical = 3.dp)
                    ) {
                        Text(statusInfo.first, fontSize = 11.sp, fontWeight = FontWeight.Bold, color = Color.Black)
                    }
                }

                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Rounded.CalendarToday, null, tint = Color.White.copy(alpha = 0.85f), modifier = Modifier.size(14.dp))
                        Spacer(Modifier.width(6.dp))
                        Text(dateText, fontSize = 14.sp, color = Color.White.copy(alpha = 0.85f))
                    }
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Rounded.LocationOn, null, tint = Color.White.copy(alpha = 0.85f), modifier = Modifier.size(14.dp))
                        Spacer(Modifier.width(6.dp))
                        Text(match.location, fontSize = 14.sp, color = Color.White.copy(alpha = 0.85f))
                    }
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Rounded.Group, null, tint = Color.White.copy(alpha = 0.85f), modifier = Modifier.size(14.dp))
                        Spacer(Modifier.width(6.dp))
                        Text("${match.groups} 组 x ${match.playersPerGroup} 人 = ${totalPlayers} 人", fontSize = 14.sp, color = Color.White.copy(alpha = 0.85f))
                    }
                    if (colors.isNotEmpty()) {
                        Row(
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            colors.forEach { colorName ->
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Box(
                                        modifier = Modifier
                                            .size(12.dp)
                                            .clip(CircleShape)
                                            .background(teamColorFromName(colorName))
                                    )
                                    Spacer(Modifier.width(3.dp))
                                    Text(teamColorLabel(colorName), fontSize = 12.sp, color = Color.White.copy(alpha = 0.8f))
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun RegistrationSection(match: MatchResponse, registrations: List<MatchRegistrationResponse>) {
    val total = match.groups * match.playersPerGroup
    val colors = match.groupColors.split(",").map { it.trim() }

    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text("报名列表", fontSize = 18.sp, fontWeight = FontWeight.SemiBold, color = TextPrimary)
            Text("${registrations.size}/$total", fontSize = 14.sp, fontWeight = FontWeight.Medium, color = TextSecondary)
        }

        if (registrations.isEmpty()) {
            Card(
                shape = RoundedCornerShape(12.dp),
                colors = CardDefaults.cardColors(containerColor = CardBg)
            ) {
                Text(
                    "暂无人报名",
                    fontSize = 14.sp,
                    color = TextSecondary,
                    modifier = Modifier.fillMaxWidth().padding(vertical = 20.dp, horizontal = 16.dp)
                )
            }
        } else {
            // Group registrations by color
            val grouped = colors.mapNotNull { color ->
                val players = registrations.filter { it.groupColor == color }
                if (players.isNotEmpty()) color to players else null
            }
            val ungrouped = registrations.filter { reg -> colors.none { it == reg.groupColor } }

            if (grouped.size > 1 || ungrouped.isNotEmpty()) {
                // Show grouped
                grouped.forEach { (color, players) ->
                    GroupCard(color, players, match.creatorUid)
                }
                if (ungrouped.isNotEmpty()) {
                    GroupCard("未分组", ungrouped, match.creatorUid)
                }
            } else {
                // Flat list
                Card(
                    shape = RoundedCornerShape(12.dp),
                    colors = CardDefaults.cardColors(containerColor = CardBg)
                ) {
                    Column {
                        registrations.forEachIndexed { index, reg ->
                            PlayerRow(reg, index, match.creatorUid)
                            if (index < registrations.size - 1) {
                                HorizontalDivider(color = Color.White.copy(alpha = 0.06f))
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun GroupCard(color: String, players: List<MatchRegistrationResponse>, creatorUid: String) {
    Card(
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(containerColor = CardBg),
        border = CardDefaults.outlinedCardBorder().copy(
            brush = Brush.linearGradient(listOf(teamColorFromName(color).copy(alpha = 0.3f), teamColorFromName(color).copy(alpha = 0.3f)))
        )
    ) {
        Column {
            Row(
                modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Box(
                    modifier = Modifier
                        .size(14.dp)
                        .clip(CircleShape)
                        .background(teamColorFromName(color))
                )
                Text(
                    "${teamColorLabel(color)}队",
                    fontSize = 14.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = TextPrimary
                )
                Text("(${players.size}人)", fontSize = 12.sp, color = TextSecondary)
            }
            players.forEachIndexed { index, reg ->
                PlayerRow(reg, index, creatorUid)
                if (index < players.size - 1) {
                    HorizontalDivider(color = Color.White.copy(alpha = 0.06f))
                }
            }
        }
    }
}

@Composable
private fun PlayerRow(reg: MatchRegistrationResponse, index: Int, creatorUid: String) {
    val dateFormat = SimpleDateFormat("MM-dd HH:mm", Locale.CHINESE)
    val regTime = dateFormat.format(Date(reg.registeredAt))

    Row(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .size(36.dp)
                .clip(CircleShape)
                .background(CardBgLight),
            contentAlignment = Alignment.Center
        ) {
            Text(
                if (reg.userUid == creatorUid) "\uD83D\uDC51" else "\u26BD\uFE0F",
                fontSize = 16.sp
            )
        }
        Spacer(Modifier.width(10.dp))
        Column {
            Text(
                reg.nickname.ifEmpty { "球员" },
                fontSize = 14.sp,
                fontWeight = FontWeight.Medium,
                color = TextPrimary
            )
            Text("报名于 $regTime", fontSize = 11.sp, color = TextSecondary)
        }
        Spacer(Modifier.weight(1f))
        Text("#${index + 1}", fontSize = 12.sp, fontWeight = FontWeight.SemiBold, color = TextSecondary)
    }
}

@Composable
private fun RankingsSection(rankings: MatchRankingsResponse) {
    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        RankingCard(
            title = "热量排行",
            icon = Icons.Rounded.LocalFireDepartment,
            gradientColors = listOf(Color(0xFFF97316), Color(0xFFEF4444)),
            items = rankings.caloriesRanking,
            unit = "kcal",
            formatter = { "%.0f".format(it) }
        )
        RankingCard(
            title = "跑动排行",
            icon = Icons.AutoMirrored.Rounded.DirectionsRun,
            gradientColors = listOf(Color(0xFFA855F7), Color(0xFFEC4899)),
            items = rankings.distanceRanking,
            unit = "km",
            formatter = { "%.1f".format(it / 1000.0) }
        )
    }
}

@Composable
private fun RankingCard(
    title: String,
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    gradientColors: List<Color>,
    items: List<PlayerRankItem>,
    unit: String,
    formatter: (Double) -> String
) {
    Card(
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(containerColor = CardBg)
    ) {
        Column {
            Row(
                modifier = Modifier.padding(horizontal = 12.dp, vertical = 12.dp),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Icon(icon, null, tint = gradientColors.first(), modifier = Modifier.size(18.dp))
                Text(
                    title,
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold,
                    color = gradientColors.first()
                )
            }

            if (items.isEmpty()) {
                Text(
                    "暂无数据",
                    fontSize = 12.sp,
                    color = TextSecondary,
                    modifier = Modifier.fillMaxWidth().padding(vertical = 12.dp, horizontal = 12.dp)
                )
            } else {
                items.take(10).forEachIndexed { index, item ->
                    Row(
                        modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 8.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        // Rank badge
                        Box(
                            modifier = Modifier
                                .size(28.dp)
                                .clip(CircleShape)
                                .background(rankColor(index + 1).copy(alpha = 0.2f)),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                when (index) {
                                    0 -> "\uD83E\uDD47"
                                    1 -> "\uD83E\uDD48"
                                    2 -> "\uD83E\uDD49"
                                    else -> "${index + 1}"
                                },
                                fontSize = if (index < 3) 14.sp else 11.sp,
                                fontWeight = FontWeight.Bold,
                                color = if (index >= 3) TextSecondary else Color.Unspecified
                            )
                        }
                        Spacer(Modifier.width(10.dp))
                        Text(
                            item.nickname.ifEmpty { "球员" },
                            fontSize = 14.sp,
                            color = TextPrimary,
                            modifier = Modifier.weight(1f),
                            maxLines = 1
                        )
                        if (item.groupColor.isNotEmpty()) {
                            Box(
                                modifier = Modifier
                                    .size(8.dp)
                                    .clip(CircleShape)
                                    .background(teamColorFromName(item.groupColor))
                            )
                            Spacer(Modifier.width(8.dp))
                        }
                        Text(
                            "${formatter(item.value)} $unit",
                            fontSize = 14.sp,
                            fontWeight = FontWeight.SemiBold,
                            color = TextPrimary
                        )
                    }
                    if (index < minOf(items.size, 10) - 1) {
                        HorizontalDivider(color = Color.White.copy(alpha = 0.06f))
                    }
                }
            }
            Spacer(Modifier.height(8.dp))
        }
    }
}

private fun rankColor(rank: Int): Color = when (rank) {
    1 -> Color(0xFFFFD700)
    2 -> Color(0xFFC0C0C0)
    3 -> Color(0xFFCD7F32)
    else -> Color(0xFF8B949E)
}

@Composable
private fun SummarySection(summaryText: String?, isLoading: Boolean) {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Icon(Icons.Rounded.AutoAwesome, null, tint = Color(0xFFA855F7), modifier = Modifier.size(18.dp))
            Text(
                "AI 比赛总结",
                fontSize = 14.sp,
                fontWeight = FontWeight.Bold,
                color = Color(0xFFA855F7)
            )
        }

        if (isLoading) {
            Card(
                shape = RoundedCornerShape(12.dp),
                colors = CardDefaults.cardColors(containerColor = CardBg)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth().padding(vertical = 20.dp),
                    horizontalArrangement = Arrangement.Center,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    CircularProgressIndicator(modifier = Modifier.size(16.dp), color = Color(0xFFA855F7), strokeWidth = 2.dp)
                    Spacer(Modifier.width(8.dp))
                    Text("正在生成比赛总结...", fontSize = 13.sp, color = TextSecondary)
                }
            }
        } else if (summaryText != null) {
            Card(
                shape = RoundedCornerShape(12.dp),
                colors = CardDefaults.cardColors(containerColor = Color.Transparent)
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(
                            Brush.linearGradient(
                                listOf(
                                    Color(0xFFA855F7).copy(alpha = 0.08f),
                                    Color(0xFF3B82F6).copy(alpha = 0.08f)
                                )
                            )
                        )
                        .padding(16.dp)
                ) {
                    Text(
                        summaryText,
                        fontSize = 14.sp,
                        color = TextPrimary,
                        lineHeight = 22.sp
                    )
                }
            }
        }
    }
}
