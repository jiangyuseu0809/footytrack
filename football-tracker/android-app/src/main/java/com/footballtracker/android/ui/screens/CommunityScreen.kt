package com.footballtracker.android.ui.screens

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandVertically
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.footballtracker.android.ui.theme.*

private val AccentGreen = Color(0xFF16C784)
private val AccentGreenDark = Color(0xFF12A86D)
private val CardGlass = Brush.linearGradient(
    listOf(Color.White.copy(alpha = 0.10f), Color.White.copy(alpha = 0.05f))
)
private val CardBorderColor = Color.White.copy(alpha = 0.10f)

// ── Data models ──
private data class CommunityData(
    val id: Int,
    val name: String,
    val description: String,
    val memberCount: Int,
    val isJoined: Boolean,
    val avatar: String,
    val color: Color
)

private data class MemberData(
    val id: Int,
    val name: String,
    val avatar: String,
    val distance: Float,
    val calories: Int,
    val matches: Int,
    val speed: Float
)

private data class ActivityData(
    val id: Int,
    val user: String,
    val action: String,
    val value: String,
    val timestamp: String,
    val type: String // "achievement", "milestone", "join"
)

private val initialCommunities = listOf(
    CommunityData(1, "Elite Strikers", "Top performing forwards competing weekly", 24, true, "ES", AccentGreen),
    CommunityData(2, "London League", "Local players in the London area", 156, true, "LL", Color(0xFF3B82F6)),
    CommunityData(3, "Weekend Warriors", "Casual players who love the weekend matches", 89, true, "WW", Color(0xFFF59E0B)),
    CommunityData(4, "Speed Demons", "For players who prioritize pace and sprinting", 67, false, "SD", Color(0xFFEF4444)),
    CommunityData(5, "Data Driven FC", "Analytics-focused football enthusiasts", 132, false, "DD", Color(0xFF8B5CF6)),
)

private val communityMembers = listOf(
    MemberData(1, "Marcus Silva", "MS", 124.5f, 18750, 15, 28.9f),
    MemberData(2, "Emma Rodriguez", "ER", 118.3f, 17240, 14, 27.4f),
    MemberData(3, "James Chen", "JC", 112.7f, 16890, 13, 26.8f),
    MemberData(4, "You", "YU", 108.2f, 15960, 12, 28.4f),
    MemberData(5, "Sarah Johnson", "SJ", 102.8f, 15120, 12, 25.9f),
    MemberData(6, "David Kim", "DK", 98.5f, 14580, 11, 27.1f),
    MemberData(7, "Lisa Martinez", "LM", 94.2f, 13920, 10, 26.3f),
    MemberData(8, "Alex Turner", "AT", 89.6f, 13240, 10, 25.5f),
)

private val activityFeed = listOf(
    ActivityData(1, "Marcus Silva", "reached", "500km milestone", "2h ago", "milestone"),
    ActivityData(2, "Emma Rodriguez", "achieved", "Hat Trick Hero badge", "5h ago", "achievement"),
    ActivityData(3, "Alex Turner", "joined", "Elite Strikers", "8h ago", "join"),
    ActivityData(4, "Sarah Johnson", "reached", "50,000 calories burned", "1d ago", "milestone"),
    ActivityData(5, "James Chen", "achieved", "Speed Demon badge", "1d ago", "achievement"),
)

private enum class RankDimension(val label: String) {
    Distance("Distance"), Calories("Calories"), Matches("Matches"), Speed("Speed")
}

@Composable
fun CommunityScreen() {
    var expandedCommunityId by remember { mutableStateOf<Int?>(null) }
    var rankDimension by remember { mutableStateOf(RankDimension.Distance) }
    var timeFilter by remember { mutableStateOf("weekly") }
    var communities by remember { mutableStateOf(initialCommunities) }

    val myCommunities = communities.filter { it.isJoined }
    val suggestedCommunities = communities.filter { !it.isJoined }

    val sortedMembers = remember(rankDimension) {
        communityMembers.sortedByDescending { m ->
            when (rankDimension) {
                RankDimension.Distance -> m.distance
                RankDimension.Calories -> m.calories.toFloat()
                RankDimension.Matches -> m.matches.toFloat()
                RankDimension.Speed -> m.speed
            }
        }
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
                Text("Communities", fontSize = 30.sp, fontWeight = FontWeight.Bold, color = TextPrimary)
                Spacer(Modifier.height(4.dp))
                Text("Connect and compete with others", fontSize = 14.sp, color = TextSecondary)
            }
        }

        // ── Create Community Button ──
        item {
            Button(
                onClick = { /* create community */ },
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(16.dp),
                colors = ButtonDefaults.buttonColors(containerColor = Color.Transparent),
                contentPadding = PaddingValues(16.dp)
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(16.dp))
                        .background(
                            Brush.horizontalGradient(listOf(AccentGreen, AccentGreenDark))
                        )
                        .padding(16.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Icon(Icons.Rounded.Add, null, tint = Color.White, modifier = Modifier.size(24.dp))
                        Text("Create New Community", fontWeight = FontWeight.Bold, color = Color.White, fontSize = 16.sp)
                    }
                }
            }
        }

        // ── My Communities ──
        item {
            Text("My Communities", fontSize = 18.sp, fontWeight = FontWeight.Bold, color = TextPrimary)
        }

        itemsIndexed(myCommunities, key = { _, c -> c.id }) { _, community ->
            CommunityCard(
                community = community,
                isExpanded = expandedCommunityId == community.id,
                onToggle = {
                    expandedCommunityId = if (expandedCommunityId == community.id) null else community.id
                },
                rankDimension = rankDimension,
                onRankDimensionChange = { rankDimension = it },
                timeFilter = timeFilter,
                onTimeFilterChange = { timeFilter = it },
                sortedMembers = sortedMembers,
                onLeave = {
                    communities = communities.map { c ->
                        if (c.id == community.id) c.copy(isJoined = false) else c
                    }
                    expandedCommunityId = null
                }
            )
        }

        // ── Suggested Communities ──
        if (suggestedCommunities.isNotEmpty()) {
            item {
                Spacer(Modifier.height(4.dp))
                Text("Suggested Communities", fontSize = 18.sp, fontWeight = FontWeight.Bold, color = TextPrimary)
            }

            itemsIndexed(suggestedCommunities, key = { _, c -> c.id }) { _, community ->
                SuggestedCommunityCard(
                    community = community,
                    onJoin = {
                        communities = communities.map { c ->
                            if (c.id == community.id) c.copy(isJoined = true) else c
                        }
                    }
                )
            }
        }

        item { Spacer(Modifier.height(80.dp)) }
    }
}

// ── Community Card (My Communities) ──
@Composable
private fun CommunityCard(
    community: CommunityData,
    isExpanded: Boolean,
    onToggle: () -> Unit,
    rankDimension: RankDimension,
    onRankDimensionChange: (RankDimension) -> Unit,
    timeFilter: String,
    onTimeFilterChange: (String) -> Unit,
    sortedMembers: List<MemberData>,
    onLeave: () -> Unit
) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(CardGlass)
            .border(1.dp, CardBorderColor, RoundedCornerShape(16.dp))
    ) {
        Column {
            // Preview
            Row(
                modifier = Modifier
                    .clickable(onClick = onToggle)
                    .padding(16.dp)
                    .fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Avatar
                Box(
                    modifier = Modifier
                        .size(56.dp)
                        .clip(RoundedCornerShape(12.dp))
                        .background(community.color.copy(alpha = 0.20f)),
                    contentAlignment = Alignment.Center
                ) {
                    Text(community.avatar, fontSize = 16.sp, fontWeight = FontWeight.Bold, color = community.color)
                }
                Spacer(Modifier.width(12.dp))

                Column(modifier = Modifier.weight(1f)) {
                    Text(community.name, fontSize = 16.sp, fontWeight = FontWeight.Bold, color = TextPrimary)
                    Text(community.description, fontSize = 13.sp, color = TextSecondary, maxLines = 1, overflow = TextOverflow.Ellipsis)
                    Spacer(Modifier.height(4.dp))
                    Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                        Icon(Icons.Rounded.Group, null, tint = Color.Gray, modifier = Modifier.size(14.dp))
                        Text("${community.memberCount} members", fontSize = 11.sp, color = TextSecondary)
                    }
                }

                Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Box(
                        modifier = Modifier
                            .size(36.dp)
                            .clip(RoundedCornerShape(10.dp))
                            .background(AccentGreen.copy(alpha = 0.20f))
                            .clickable { /* invite */ },
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(Icons.Rounded.PersonAdd, null, tint = AccentGreen, modifier = Modifier.size(18.dp))
                    }
                    Icon(
                        if (isExpanded) Icons.Rounded.KeyboardArrowUp else Icons.Rounded.KeyboardArrowDown,
                        null,
                        tint = if (isExpanded) AccentGreen else TextSecondary,
                        modifier = Modifier.size(20.dp)
                    )
                }
            }

            // Expanded detail
            AnimatedVisibility(visible = isExpanded, enter = expandVertically(), exit = shrinkVertically()) {
                Column {
                    HorizontalDivider(thickness = 1.dp, color = CardBorderColor)
                    Column(
                        modifier = Modifier.padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(16.dp)
                    ) {
                        // Ranking dimension selector
                        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            Text("Leaderboard By", fontSize = 13.sp, fontWeight = FontWeight.Bold, color = TextPrimary)
                            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                RankDimension.entries.forEach { dim ->
                                    val selected = dim == rankDimension
                                    Box(
                                        modifier = Modifier
                                            .weight(1f)
                                            .clip(RoundedCornerShape(10.dp))
                                            .background(if (selected) AccentGreen else Color.Black.copy(alpha = 0.30f))
                                            .clickable { onRankDimensionChange(dim) }
                                            .padding(vertical = 8.dp),
                                        contentAlignment = Alignment.Center
                                    ) {
                                        Text(
                                            dim.label,
                                            fontSize = 11.sp,
                                            fontWeight = FontWeight.Medium,
                                            color = if (selected) Color.White else TextSecondary
                                        )
                                    }
                                }
                            }
                        }

                        // Time filter
                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            listOf("daily" to "Daily", "weekly" to "Weekly").forEach { (key, label) ->
                                val selected = timeFilter == key
                                Box(
                                    modifier = Modifier
                                        .weight(1f)
                                        .clip(RoundedCornerShape(10.dp))
                                        .then(
                                            if (selected)
                                                Modifier
                                                    .background(AccentGreen.copy(alpha = 0.20f))
                                                    .border(1.dp, AccentGreen.copy(alpha = 0.50f), RoundedCornerShape(10.dp))
                                            else
                                                Modifier.background(Color.Black.copy(alpha = 0.30f))
                                        )
                                        .clickable { onTimeFilterChange(key) }
                                        .padding(vertical = 10.dp),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Text(
                                        label,
                                        fontSize = 13.sp,
                                        fontWeight = FontWeight.Medium,
                                        color = if (selected) AccentGreen else TextSecondary
                                    )
                                }
                            }
                        }

                        // Top 3 podium
                        TopPerformersPodium(sortedMembers, rankDimension)

                        // Full rankings (4th+)
                        if (sortedMembers.size > 3) {
                            FullRankingsList(sortedMembers.drop(3), startRank = 4, rankDimension = rankDimension)
                        }

                        // Activity feed
                        ActivityFeedSection()

                        // Leave button
                        OutlinedButton(
                            onClick = onLeave,
                            modifier = Modifier.fillMaxWidth(),
                            shape = RoundedCornerShape(12.dp),
                            border = ButtonDefaults.outlinedButtonBorder(enabled = true).copy(
                                brush = Brush.linearGradient(listOf(Color(0xFFEF4444).copy(alpha = 0.30f), Color(0xFFEF4444).copy(alpha = 0.30f)))
                            ),
                            colors = ButtonDefaults.outlinedButtonColors(
                                containerColor = Color(0xFFEF4444).copy(alpha = 0.10f)
                            )
                        ) {
                            Text("Leave Community", color = Color(0xFFEF4444), fontWeight = FontWeight.Medium, fontSize = 13.sp)
                        }
                    }
                }
            }
        }
    }
}

// ── Top 3 Podium ──
@Composable
private fun TopPerformersPodium(members: List<MemberData>, dimension: RankDimension) {
    if (members.size < 3) return

    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text("Top Performers", fontSize = 13.sp, fontWeight = FontWeight.Bold, color = TextPrimary)

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.Bottom
        ) {
            // 2nd place
            PodiumColumn(members[1], 2, dimension, Modifier.weight(1f))
            // 1st place
            PodiumColumn(members[0], 1, dimension, Modifier.weight(1f))
            // 3rd place
            PodiumColumn(members[2], 3, dimension, Modifier.weight(1f))
        }
    }
}

@Composable
private fun PodiumColumn(member: MemberData, rank: Int, dimension: RankDimension, modifier: Modifier) {
    val podiumColor = when (rank) {
        1 -> Color(0xFFFBBF24) // gold
        2 -> Color(0xFF9CA3AF) // silver
        else -> Color(0xFFF97316) // bronze
    }
    val pedH = when (rank) { 1 -> 96.dp; 2 -> 64.dp; else -> 48.dp }

    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        // Card top
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(topStart = 12.dp, topEnd = 12.dp))
                .background(
                    Brush.verticalGradient(
                        listOf(podiumColor.copy(alpha = 0.30f), podiumColor.copy(alpha = 0.15f))
                    )
                )
                .border(
                    2.dp,
                    podiumColor.copy(alpha = 0.50f),
                    RoundedCornerShape(topStart = 12.dp, topEnd = 12.dp)
                )
                .padding(12.dp),
            contentAlignment = Alignment.Center
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Icon(
                    if (rank == 1) Icons.Rounded.Stars else Icons.Rounded.MilitaryTech,
                    null,
                    tint = podiumColor,
                    modifier = Modifier.size(if (rank == 1) 28.dp else 24.dp)
                )
                Spacer(Modifier.height(6.dp))
                Box(
                    modifier = Modifier
                        .size(if (rank == 1) 56.dp else 48.dp)
                        .clip(CircleShape)
                        .background(
                            Brush.linearGradient(listOf(podiumColor, podiumColor.copy(alpha = 0.7f)))
                        ),
                    contentAlignment = Alignment.Center
                ) {
                    Text(member.avatar, fontWeight = FontWeight.Bold, color = Color.White, fontSize = if (rank == 1) 16.sp else 14.sp)
                }
                Spacer(Modifier.height(6.dp))
                Text(
                    member.name.split(" ").first(),
                    fontSize = if (rank == 1) 13.sp else 11.sp,
                    fontWeight = FontWeight.Bold,
                    color = TextPrimary,
                    maxLines = 1
                )
                Text(
                    getRankValue(member, dimension),
                    fontSize = 11.sp,
                    color = TextSecondary
                )
            }
        }
        // Pedestal
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(pedH)
                .clip(RoundedCornerShape(bottomStart = 12.dp, bottomEnd = 12.dp))
                .background(podiumColor.copy(alpha = 0.20f)),
            contentAlignment = Alignment.Center
        ) {
            Text(
                "$rank",
                fontSize = if (rank == 1) 28.sp else 24.sp,
                fontWeight = FontWeight.Bold,
                color = podiumColor
            )
        }
    }
}

// ── Full Rankings List ──
@Composable
private fun FullRankingsList(members: List<MemberData>, startRank: Int, rankDimension: RankDimension) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text("Full Rankings", fontSize = 13.sp, fontWeight = FontWeight.Bold, color = TextPrimary)

        members.forEachIndexed { index, member ->
            val rank = startRank + index
            val isYou = member.name == "You"

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(12.dp))
                    .then(
                        if (isYou)
                            Modifier
                                .background(AccentGreen.copy(alpha = 0.20f))
                                .border(1.dp, AccentGreen.copy(alpha = 0.30f), RoundedCornerShape(12.dp))
                        else
                            Modifier.background(Color.Black.copy(alpha = 0.20f))
                    )
                    .padding(12.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    "#$rank",
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Bold,
                    color = TextSecondary,
                    modifier = Modifier.width(32.dp)
                )
                Box(
                    modifier = Modifier
                        .size(40.dp)
                        .clip(CircleShape)
                        .background(
                            if (isYou) AccentGreen
                            else Brush.linearGradient(listOf(Color(0xFF4B5563), Color(0xFF374151))).let {
                                // Solid fallback
                                Color(0xFF4B5563)
                            }
                        ),
                    contentAlignment = Alignment.Center
                ) {
                    Text(member.avatar, fontWeight = FontWeight.Bold, color = Color.White, fontSize = 12.sp)
                }
                Spacer(Modifier.width(12.dp))
                Text(
                    member.name,
                    fontSize = 13.sp,
                    fontWeight = FontWeight.Medium,
                    color = if (isYou) AccentGreen else TextPrimary,
                    modifier = Modifier.weight(1f)
                )
                val dimIcon = when (rankDimension) {
                    RankDimension.Distance -> Icons.Rounded.Place
                    RankDimension.Calories -> Icons.Rounded.LocalFireDepartment
                    RankDimension.Matches -> Icons.Rounded.FitnessCenter
                    RankDimension.Speed -> Icons.Rounded.FlashOn
                }
                Icon(dimIcon, null, tint = AccentGreen, modifier = Modifier.size(14.dp))
                Spacer(Modifier.width(6.dp))
                Text(getRankValue(member, rankDimension), fontSize = 13.sp, fontWeight = FontWeight.Bold, color = TextPrimary)
            }
        }
    }
}

// ── Activity Feed ──
@Composable
private fun ActivityFeedSection() {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text("Recent Activity", fontSize = 13.sp, fontWeight = FontWeight.Bold, color = TextPrimary)

        Box(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(12.dp))
                .background(Color.Black.copy(alpha = 0.30f))
                .padding(12.dp)
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                activityFeed.forEach { activity ->
                    Row(
                        verticalAlignment = Alignment.Top,
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        val (icon, bgColor) = when (activity.type) {
                            "achievement" -> Icons.Rounded.EmojiEvents to Color(0xFFF59E0B).copy(alpha = 0.20f)
                            "milestone" -> Icons.Rounded.Flag to AccentGreen.copy(alpha = 0.20f)
                            else -> Icons.Rounded.Group to Color(0xFF3B82F6).copy(alpha = 0.20f)
                        }
                        val iconTint = when (activity.type) {
                            "achievement" -> Color(0xFFFBBF24)
                            "milestone" -> AccentGreen
                            else -> Color(0xFF60A5FA)
                        }

                        Box(
                            modifier = Modifier
                                .size(28.dp)
                                .clip(RoundedCornerShape(8.dp))
                                .background(bgColor),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(icon, null, tint = iconTint, modifier = Modifier.size(12.dp))
                        }

                        Column(modifier = Modifier.weight(1f)) {
                            // User + action + value
                            Row {
                                Text(activity.user, fontSize = 12.sp, fontWeight = FontWeight.Medium, color = TextPrimary)
                                Text(" ${activity.action} ", fontSize = 12.sp, color = TextSecondary)
                                Text(activity.value, fontSize = 12.sp, fontWeight = FontWeight.Medium, color = AccentGreen)
                            }
                            Text(activity.timestamp, fontSize = 10.sp, color = Color.Gray)
                        }
                    }
                }
            }
        }
    }
}

// ── Suggested Community Card ──
@Composable
private fun SuggestedCommunityCard(community: CommunityData, onJoin: () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(CardGlass)
            .border(1.dp, CardBorderColor, RoundedCornerShape(16.dp))
            .padding(16.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                modifier = Modifier
                    .size(56.dp)
                    .clip(RoundedCornerShape(12.dp))
                    .background(community.color.copy(alpha = 0.20f)),
                contentAlignment = Alignment.Center
            ) {
                Text(community.avatar, fontSize = 16.sp, fontWeight = FontWeight.Bold, color = community.color)
            }
            Spacer(Modifier.width(12.dp))

            Column(modifier = Modifier.weight(1f)) {
                Text(community.name, fontSize = 15.sp, fontWeight = FontWeight.Bold, color = TextPrimary)
                Text(community.description, fontSize = 12.sp, color = TextSecondary, maxLines = 2, overflow = TextOverflow.Ellipsis)
                Spacer(Modifier.height(4.dp))
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    Icon(Icons.Rounded.Group, null, tint = Color.Gray, modifier = Modifier.size(14.dp))
                    Text("${community.memberCount} members", fontSize = 11.sp, color = TextSecondary)
                }
            }
            Spacer(Modifier.width(8.dp))

            Button(
                onClick = onJoin,
                shape = RoundedCornerShape(12.dp),
                colors = ButtonDefaults.buttonColors(containerColor = AccentGreen),
                contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp)
            ) {
                Text("Join", fontWeight = FontWeight.Medium, fontSize = 13.sp, color = Color.White)
            }
        }
    }
}

// ── Utility ──
private fun getRankValue(member: MemberData, dimension: RankDimension): String {
    return when (dimension) {
        RankDimension.Distance -> "${member.distance} km"
        RankDimension.Calories -> "%,d kcal".format(member.calories)
        RankDimension.Matches -> "${member.matches} matches"
        RankDimension.Speed -> "${member.speed} km/h"
    }
}
