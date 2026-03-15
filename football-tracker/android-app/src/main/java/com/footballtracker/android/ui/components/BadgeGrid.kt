package com.footballtracker.android.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.*
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.footballtracker.android.network.BadgeResponse
import com.footballtracker.android.network.UserBadgeResponse
import com.footballtracker.android.ui.theme.*

@Composable
fun BadgeGrid(
    allBadges: List<BadgeResponse>,
    earnedBadges: List<UserBadgeResponse>
) {
    val earnedIds = earnedBadges.map { it.badge.id }.toSet()

    // 4 columns
    val rows = allBadges.chunked(4)
    Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
        rows.forEach { rowBadges ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceEvenly
            ) {
                rowBadges.forEach { badge ->
                    val isEarned = badge.id in earnedIds
                    BadgeItem(badge = badge, isEarned = isEarned)
                }
                // Fill empty slots
                repeat(4 - rowBadges.size) {
                    Spacer(modifier = Modifier.width(60.dp))
                }
            }
        }
    }
}

@Composable
private fun BadgeItem(badge: BadgeResponse, isEarned: Boolean) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier.width(60.dp)
    ) {
        Box(
            modifier = Modifier
                .size(52.dp)
                .clip(CircleShape)
                .background(if (isEarned) NeonBlue.copy(alpha = 0.2f) else CardBgLight)
                .then(
                    if (isEarned) Modifier.border(2.dp, NeonBlue, CircleShape)
                    else Modifier
                ),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = badgeIcon(badge.iconName),
                contentDescription = badge.name,
                tint = if (isEarned) NeonBlue else TextSecondary.copy(alpha = 0.5f),
                modifier = Modifier.size(24.dp)
            )
        }
        Spacer(modifier = Modifier.height(4.dp))
        Text(
            text = badge.name,
            fontSize = 10.sp,
            color = if (isEarned) TextPrimary else TextSecondary.copy(alpha = 0.5f),
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            textAlign = TextAlign.Center
        )
    }
}

private fun badgeIcon(iconName: String): ImageVector {
    return when (iconName) {
        "first_match" -> Icons.Rounded.SportsSoccer
        "iron_man" -> Icons.Rounded.FitnessCenter
        "century_legend" -> Icons.Rounded.Star
        "speed_star" -> Icons.Rounded.Bolt
        "marathon_runner" -> Icons.Rounded.DirectionsRun
        "calorie_burner" -> Icons.Rounded.LocalFireDepartment
        "perfect_month" -> Icons.Rounded.CalendarMonth
        "sprint_king" -> Icons.Rounded.Speed
        else -> Icons.Rounded.EmojiEvents
    }
}
