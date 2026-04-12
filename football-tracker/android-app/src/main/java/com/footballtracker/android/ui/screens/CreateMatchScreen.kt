package com.footballtracker.android.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
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
import com.footballtracker.android.network.ApiClient
import com.footballtracker.android.network.CreateMatchRequest
import com.footballtracker.android.ui.theme.*
import kotlinx.coroutines.launch
import java.text.SimpleDateFormat
import java.util.*

private enum class TeamColor(val label: String, val color: Color, val key: String) {
    Red("红", Color(0xFFEF4444), "red"),
    Blue("蓝", Color(0xFF3B82F6), "blue"),
    Green("绿", Color(0xFF22C55E), "green"),
    Orange("橙", Color(0xFFF97316), "orange"),
    Yellow("黄", Color(0xFFFACC15), "yellow"),
    White("白", Color.White, "white")
}

private enum class Weekday(val label: String, val shortLabel: String, val calendarDay: Int) {
    Monday("周一", "一", Calendar.MONDAY),
    Tuesday("周二", "二", Calendar.TUESDAY),
    Wednesday("周三", "三", Calendar.WEDNESDAY),
    Thursday("周四", "四", Calendar.THURSDAY),
    Friday("周五", "五", Calendar.FRIDAY),
    Saturday("周六", "六", Calendar.SATURDAY),
    Sunday("周日", "日", Calendar.SUNDAY)
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CreateMatchScreen(
    onBack: () -> Unit,
    onMatchCreated: (String) -> Unit
) {
    val scope = rememberCoroutineScope()

    var selectedWeekdays by remember { mutableStateOf(setOf<Weekday>()) }
    var matchHour by remember { mutableIntStateOf(20) }
    var matchMinute by remember { mutableIntStateOf(0) }
    var location by remember { mutableStateOf("") }
    var groupCount by remember { mutableIntStateOf(2) }
    var playersPerGroup by remember { mutableIntStateOf(11) }
    var groupColors by remember { mutableStateOf(listOf<TeamColor>()) }

    var isCreating by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var showTimePicker by remember { mutableStateOf(false) }

    val isFormValid = location.isNotBlank() && selectedWeekdays.isNotEmpty()
    val totalPlayers = groupCount * playersPerGroup

    // Compute nearest match date
    val nearestDateText = remember(selectedWeekdays, matchHour, matchMinute) {
        if (selectedWeekdays.isEmpty()) return@remember null
        val cal = Calendar.getInstance()
        val today = cal.get(Calendar.DAY_OF_WEEK)
        val dates = selectedWeekdays.map { wd ->
            val diff = (wd.calendarDay - today + 7) % 7
            Calendar.getInstance().apply {
                add(Calendar.DAY_OF_YEAR, if (diff == 0) 0 else diff)
                set(Calendar.HOUR_OF_DAY, matchHour)
                set(Calendar.MINUTE, matchMinute)
            }
        }
        val nearest = dates.minByOrNull { it.timeInMillis }
        nearest?.let {
            val fmt = SimpleDateFormat("M月d日 EEEE HH:mm", Locale.CHINESE)
            fmt.format(it.time)
        }
    }

    fun createMatch() {
        if (!isFormValid || isCreating) return
        isCreating = true
        errorMessage = null

        // Find the nearest date
        val cal = Calendar.getInstance()
        val today = cal.get(Calendar.DAY_OF_WEEK)
        val dates = selectedWeekdays.map { wd ->
            val diff = (wd.calendarDay - today + 7) % 7
            Calendar.getInstance().apply {
                add(Calendar.DAY_OF_YEAR, if (diff == 0) 0 else diff)
                set(Calendar.HOUR_OF_DAY, matchHour)
                set(Calendar.MINUTE, matchMinute)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
        }
        val nearest = dates.minByOrNull { it.timeInMillis } ?: return

        val weekdayLabels = selectedWeekdays.sortedBy { it.ordinal }.joinToString("、") { it.label }
        val timeStr = String.format("%02d:%02d", matchHour, matchMinute)
        val title = "$weekdayLabels $timeStr 足球"
        val colorsStr = if (groupColors.isNotEmpty()) {
            groupColors.joinToString(",") { it.key }
        } else {
            TeamColor.entries.take(groupCount).joinToString(",") { it.key }
        }

        scope.launch {
            try {
                val response = ApiClient.api.createMatch(
                    CreateMatchRequest(
                        title = title,
                        matchDate = nearest.timeInMillis,
                        location = location.trim(),
                        groups = groupCount,
                        playersPerGroup = playersPerGroup,
                        groupColors = colorsStr
                    )
                )
                onMatchCreated(response.id)
            } catch (e: Exception) {
                errorMessage = e.message ?: "创建失败"
            }
            isCreating = false
        }
    }

    // Time picker dialog
    if (showTimePicker) {
        val timePickerState = rememberTimePickerState(
            initialHour = matchHour,
            initialMinute = matchMinute,
            is24Hour = true
        )
        AlertDialog(
            onDismissRequest = { showTimePicker = false },
            containerColor = CardBg,
            title = { Text("选择时间", color = TextPrimary) },
            text = {
                TimePicker(
                    state = timePickerState,
                    colors = TimePickerDefaults.colors(
                        clockDialColor = CardBgLight,
                        selectorColor = NeonBlue,
                        clockDialSelectedContentColor = Color.White,
                        clockDialUnselectedContentColor = TextSecondary,
                        timeSelectorSelectedContainerColor = NeonBlue.copy(alpha = 0.2f),
                        timeSelectorUnselectedContainerColor = CardBgLight,
                        timeSelectorSelectedContentColor = NeonBlue,
                        timeSelectorUnselectedContentColor = TextSecondary
                    )
                )
            },
            confirmButton = {
                TextButton(onClick = {
                    matchHour = timePickerState.hour
                    matchMinute = timePickerState.minute
                    showTimePicker = false
                }) { Text("确定", color = NeonBlue) }
            },
            dismissButton = {
                TextButton(onClick = { showTimePicker = false }) {
                    Text("取消", color = TextSecondary)
                }
            }
        )
    }

    Box(modifier = Modifier.fillMaxSize().background(DarkBg)) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
        ) {
            // Top bar
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .fillMaxWidth()
                    .background(
                        Brush.verticalGradient(
                            listOf(NeonBlue.copy(alpha = 0.12f), DarkBg)
                        )
                    )
                    .padding(horizontal = 4.dp, vertical = 8.dp)
            ) {
                IconButton(onClick = onBack) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, "返回", tint = TextPrimary)
                }
                Text("发起比赛", fontSize = 20.sp, fontWeight = FontWeight.Bold, color = TextPrimary)
            }

            Column(
                modifier = Modifier.padding(horizontal = 16.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                // ── Weekday Selection ──
                SectionCard(title = "比赛日") {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        Weekday.entries.forEach { day ->
                            val selected = day in selectedWeekdays
                            Box(
                                modifier = Modifier
                                    .weight(1f)
                                    .clip(RoundedCornerShape(10.dp))
                                    .background(
                                        if (selected) NeonBlue.copy(alpha = 0.2f) else CardBgLight
                                    )
                                    .border(
                                        width = if (selected) 1.5.dp else 0.dp,
                                        color = if (selected) NeonBlue else Color.Transparent,
                                        shape = RoundedCornerShape(10.dp)
                                    )
                                    .clickable {
                                        selectedWeekdays = if (selected) {
                                            selectedWeekdays - day
                                        } else {
                                            selectedWeekdays + day
                                        }
                                    }
                                    .padding(vertical = 12.dp),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    day.shortLabel,
                                    fontSize = 14.sp,
                                    fontWeight = if (selected) FontWeight.Bold else FontWeight.Medium,
                                    color = if (selected) NeonBlue else TextSecondary
                                )
                            }
                        }
                    }
                }

                // ── Time Selection ──
                SectionCard(title = "开球时间") {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(12.dp))
                            .background(CardBgLight)
                            .clickable { showTimePicker = true }
                            .padding(16.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Rounded.Schedule, null, tint = NeonBlue, modifier = Modifier.size(20.dp))
                            Spacer(modifier = Modifier.width(10.dp))
                            Text(
                                String.format("%02d:%02d", matchHour, matchMinute),
                                fontSize = 18.sp,
                                fontWeight = FontWeight.Bold,
                                color = TextPrimary
                            )
                        }
                        Icon(Icons.Rounded.ChevronRight, null, tint = TextSecondary, modifier = Modifier.size(18.dp))
                    }
                }

                // ── Location ──
                SectionCard(title = "场地") {
                    OutlinedTextField(
                        value = location,
                        onValueChange = { location = it.take(50) },
                        placeholder = { Text("输入场地名称", color = TextSecondary) },
                        leadingIcon = {
                            Icon(Icons.Rounded.LocationOn, null, tint = NeonBlue, modifier = Modifier.size(20.dp))
                        },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth(),
                        colors = OutlinedTextFieldDefaults.colors(
                            focusedTextColor = TextPrimary,
                            unfocusedTextColor = TextPrimary,
                            cursorColor = NeonBlue,
                            focusedBorderColor = NeonBlue,
                            unfocusedBorderColor = DividerColor,
                            focusedContainerColor = CardBgLight,
                            unfocusedContainerColor = CardBgLight
                        ),
                        shape = RoundedCornerShape(12.dp)
                    )
                }

                // ── Group Settings ──
                SectionCard(title = "分组设置") {
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        // Group count
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text("队伍数", fontSize = 14.sp, color = TextSecondary)
                            StepperRow(
                                value = groupCount,
                                range = 2..6,
                                onValueChange = {
                                    groupCount = it
                                    if (groupColors.size > it) {
                                        groupColors = groupColors.take(it)
                                    }
                                }
                            )
                        }

                        // Players per group
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text("每队人数", fontSize = 14.sp, color = TextSecondary)
                            StepperRow(
                                value = playersPerGroup,
                                range = 3..15,
                                onValueChange = { playersPerGroup = it }
                            )
                        }

                        // Group colors
                        Text("队服颜色", fontSize = 14.sp, color = TextSecondary)
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .horizontalScroll(rememberScrollState()),
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            TeamColor.entries.forEach { tc ->
                                val isSelected = tc in groupColors
                                val canSelect = groupColors.size < groupCount || isSelected
                                Box(
                                    modifier = Modifier
                                        .size(40.dp)
                                        .clip(CircleShape)
                                        .background(tc.color.copy(alpha = if (canSelect) 1f else 0.3f))
                                        .then(
                                            if (isSelected) Modifier.border(2.dp, Color.White, CircleShape)
                                            else Modifier
                                        )
                                        .clickable(enabled = canSelect) {
                                            groupColors = if (isSelected) {
                                                groupColors - tc
                                            } else if (groupColors.size < groupCount) {
                                                groupColors + tc
                                            } else groupColors
                                        },
                                    contentAlignment = Alignment.Center
                                ) {
                                    if (isSelected) {
                                        Icon(
                                            Icons.Rounded.Check,
                                            null,
                                            tint = if (tc == TeamColor.White || tc == TeamColor.Yellow) Color.Black else Color.White,
                                            modifier = Modifier.size(18.dp)
                                        )
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Summary Card ──
                if (nearestDateText != null) {
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
                                            Color(0xFF16803B).copy(alpha = 0.8f),
                                            Color(0xFF166534).copy(alpha = 0.8f)
                                        )
                                    )
                                )
                                .padding(16.dp)
                        ) {
                            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                Text("比赛预览", fontSize = 13.sp, color = Color.White.copy(alpha = 0.7f))
                                Text(nearestDateText, fontSize = 16.sp, fontWeight = FontWeight.Bold, color = Color.White)
                                if (location.isNotBlank()) {
                                    Row(verticalAlignment = Alignment.CenterVertically) {
                                        Icon(Icons.Rounded.LocationOn, null, tint = Color.White.copy(alpha = 0.8f), modifier = Modifier.size(14.dp))
                                        Spacer(modifier = Modifier.width(4.dp))
                                        Text(location, fontSize = 13.sp, color = Color.White.copy(alpha = 0.85f))
                                    }
                                }
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Icon(Icons.Rounded.Group, null, tint = Color.White.copy(alpha = 0.8f), modifier = Modifier.size(14.dp))
                                    Spacer(modifier = Modifier.width(4.dp))
                                    Text("${groupCount}队 x ${playersPerGroup}人 = ${totalPlayers}人", fontSize = 13.sp, color = Color.White.copy(alpha = 0.85f))
                                }
                                if (groupColors.isNotEmpty()) {
                                    Row(
                                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                                        verticalAlignment = Alignment.CenterVertically
                                    ) {
                                        groupColors.forEach { tc ->
                                            Row(verticalAlignment = Alignment.CenterVertically) {
                                                Box(
                                                    modifier = Modifier
                                                        .size(10.dp)
                                                        .clip(CircleShape)
                                                        .background(tc.color)
                                                )
                                                Spacer(modifier = Modifier.width(3.dp))
                                                Text(tc.label, fontSize = 12.sp, color = Color.White.copy(alpha = 0.8f))
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Error ──
                errorMessage?.let {
                    Text(it, fontSize = 13.sp, color = HeartRed)
                }

                // ── Create Button ──
                Button(
                    onClick = { createMatch() },
                    enabled = isFormValid && !isCreating,
                    modifier = Modifier.fillMaxWidth().height(50.dp),
                    shape = RoundedCornerShape(14.dp),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = NeonBlue,
                        disabledContainerColor = NeonBlue.copy(alpha = 0.3f)
                    )
                ) {
                    if (isCreating) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(20.dp),
                            color = Color.White,
                            strokeWidth = 2.dp
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                    }
                    Text(
                        "创建比赛",
                        fontSize = 16.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = Color.White
                    )
                }

                Spacer(modifier = Modifier.height(32.dp))
            }
        }

        // Loading overlay
        if (isCreating) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color.Black.copy(alpha = 0.3f)),
                contentAlignment = Alignment.Center
            ) {
                CircularProgressIndicator(color = NeonBlue)
            }
        }
    }
}

@Composable
private fun SectionCard(
    title: String,
    content: @Composable ColumnScope.() -> Unit
) {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Text(title, fontSize = 16.sp, fontWeight = FontWeight.SemiBold, color = TextPrimary)
        Card(
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(containerColor = CardBg),
            elevation = CardDefaults.cardElevation(0.dp)
        ) {
            Column(modifier = Modifier.padding(16.dp), content = content)
        }
    }
}

@Composable
private fun StepperRow(
    value: Int,
    range: IntRange,
    onValueChange: (Int) -> Unit
) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        IconButton(
            onClick = { if (value > range.first) onValueChange(value - 1) },
            enabled = value > range.first,
            modifier = Modifier.size(32.dp)
        ) {
            Icon(
                Icons.Rounded.Remove,
                null,
                tint = if (value > range.first) TextPrimary else TextSecondary.copy(alpha = 0.3f),
                modifier = Modifier.size(18.dp)
            )
        }
        Text(
            "$value",
            fontSize = 18.sp,
            fontWeight = FontWeight.Bold,
            color = NeonBlue,
            modifier = Modifier.padding(horizontal = 16.dp)
        )
        IconButton(
            onClick = { if (value < range.last) onValueChange(value + 1) },
            enabled = value < range.last,
            modifier = Modifier.size(32.dp)
        ) {
            Icon(
                Icons.Rounded.Add,
                null,
                tint = if (value < range.last) TextPrimary else TextSecondary.copy(alpha = 0.3f),
                modifier = Modifier.size(18.dp)
            )
        }
    }
}
