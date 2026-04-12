package com.footballtracker.android.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.Chat
import androidx.compose.material.icons.automirrored.rounded.ExitToApp
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
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.footballtracker.android.data.db.SessionEntity
import com.footballtracker.android.data.repository.CloudSessionSync
import com.footballtracker.android.data.repository.UserRepository
import com.footballtracker.android.auth.AuthRepository
import com.footballtracker.android.data.model.UserProfile
import com.footballtracker.android.ui.theme.*
import kotlinx.coroutines.launch
import kotlin.math.max
import kotlin.math.min

private val AccentGreen = Color(0xFF16C784)
private val AccentGreenDark = Color(0xFF12A86D)
private val CardGlass = Brush.linearGradient(
    listOf(Color.White.copy(alpha = 0.10f), Color.White.copy(alpha = 0.05f))
)
private val CardBorderColor = Color.White.copy(alpha = 0.10f)

@Suppress("UNUSED_PARAMETER")
@Composable
fun ProfileScreen(
    sessions: List<SessionEntity>,
    userRepository: UserRepository,
    authRepository: AuthRepository,
    cloudSync: CloudSessionSync,
    onNavigateTeams: () -> Unit,
    onNavigateTeamDetail: (String) -> Unit,
    onLogout: () -> Unit
) {
    val scope = rememberCoroutineScope()
    val currentUser by authRepository.currentUser.collectAsState()

    var profile by remember { mutableStateOf<UserProfile?>(null) }
    var isEditingName by remember { mutableStateOf(false) }
    var editedName by remember { mutableStateOf("") }
    var showEditDialog by remember { mutableStateOf(false) }

    // Toggle states
    var notificationsEnabled by remember { mutableStateOf(true) }
    var darkMode by remember { mutableStateOf(true) }
    var cloudSyncEnabled by remember { mutableStateOf(true) }
    var deviceConnected by remember { mutableStateOf(true) }

    // Computed stats
    val totalMatches = sessions.size
    val totalDistanceKm = sessions.sumOf { it.totalDistanceMeters } / 1000.0
    val totalGoals = sessions.sumOf { it.sprintCount / 3 }
    val totalTrophies = sessions.count { performanceScoreProfile(it) >= 8.0 }

    // Performance score
    val perfScore = if (sessions.isNotEmpty()) {
        sessions.map { performanceScoreProfile(it) }.average().let { (it * 10).toInt() }
    } else 0

    LaunchedEffect(currentUser) {
        currentUser?.let { user ->
            profile = userRepository.getProfile(user.uid)
            profile?.let { editedName = it.nickname }
        }
    }

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .background(DarkBg),
        contentPadding = PaddingValues(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        // ── Header ──
        item {
            Column(modifier = Modifier.padding(top = 16.dp)) {
                Text("Profile", fontSize = 30.sp, fontWeight = FontWeight.Bold, color = TextPrimary)
                Spacer(Modifier.height(4.dp))
                Text("Manage your account and settings", fontSize = 14.sp, color = TextSecondary)
            }
        }

        // ── User Info Card ──
        item {
            GlassCard {
                Column(modifier = Modifier.padding(24.dp)) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.Top
                    ) {
                        // Avatar
                        Box(contentAlignment = Alignment.BottomEnd) {
                            Box(
                                modifier = Modifier
                                    .size(80.dp)
                                    .clip(CircleShape)
                                    .background(
                                        Brush.linearGradient(listOf(AccentGreen, AccentGreenDark))
                                    ),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    (profile?.nickname?.take(2) ?: "FT").uppercase(),
                                    fontSize = 28.sp,
                                    fontWeight = FontWeight.Bold,
                                    color = Color.White
                                )
                            }
                            Box(
                                modifier = Modifier
                                    .size(28.dp)
                                    .clip(CircleShape)
                                    .background(AccentGreen)
                                    .border(2.dp, DarkBg, CircleShape),
                                contentAlignment = Alignment.Center
                            ) {
                                Icon(Icons.Rounded.CameraAlt, null, tint = Color.White, modifier = Modifier.size(14.dp))
                            }
                        }

                        Spacer(Modifier.width(16.dp))

                        // User info
                        Column(modifier = Modifier.weight(1f)) {
                            if (isEditingName) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    OutlinedTextField(
                                        value = editedName,
                                        onValueChange = { editedName = it.take(20) },
                                        modifier = Modifier.weight(1f).height(48.dp),
                                        singleLine = true,
                                        textStyle = androidx.compose.ui.text.TextStyle(
                                            fontSize = 18.sp,
                                            fontWeight = FontWeight.Bold,
                                            color = TextPrimary
                                        ),
                                        colors = OutlinedTextFieldDefaults.colors(
                                            focusedBorderColor = AccentGreen,
                                            unfocusedBorderColor = AccentGreen.copy(alpha = 0.50f),
                                            cursorColor = AccentGreen,
                                            focusedTextColor = TextPrimary,
                                            unfocusedTextColor = TextPrimary
                                        )
                                    )
                                    Spacer(Modifier.width(8.dp))
                                    Box(
                                        modifier = Modifier
                                            .size(32.dp)
                                            .clip(RoundedCornerShape(8.dp))
                                            .background(AccentGreen)
                                            .clickable {
                                                isEditingName = false
                                                profile?.let { p ->
                                                    scope.launch {
                                                        userRepository.updateProfile(
                                                            uid = p.uid,
                                                            nickname = editedName,
                                                            weightKg = p.weightKg,
                                                            age = p.age
                                                        )
                                                        profile = p.copy(nickname = editedName)
                                                    }
                                                }
                                            },
                                        contentAlignment = Alignment.Center
                                    ) {
                                        Icon(Icons.Rounded.Check, null, tint = Color.White, modifier = Modifier.size(16.dp))
                                    }
                                }
                            } else {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Text(
                                        profile?.nickname ?: "Player",
                                        fontSize = 22.sp,
                                        fontWeight = FontWeight.Bold,
                                        color = TextPrimary
                                    )
                                    Spacer(Modifier.width(8.dp))
                                    Box(
                                        modifier = Modifier
                                            .size(28.dp)
                                            .clip(RoundedCornerShape(8.dp))
                                            .background(Color.White.copy(alpha = 0.10f))
                                            .clickable {
                                                editedName = profile?.nickname ?: ""
                                                isEditingName = true
                                            },
                                        contentAlignment = Alignment.Center
                                    ) {
                                        Icon(Icons.Rounded.Edit, null, tint = TextSecondary, modifier = Modifier.size(14.dp))
                                    }
                                }
                            }
                            Spacer(Modifier.height(4.dp))
                            Text("Forward • #10", fontSize = 13.sp, color = TextSecondary)
                            Spacer(Modifier.height(2.dp))
                            Text(
                                currentUser?.username ?: currentUser?.phone ?: "",
                                fontSize = 12.sp,
                                color = Color.Gray
                            )
                        }
                    }

                    Spacer(Modifier.height(24.dp))

                    // Quick Stats 2x2
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        QuickStatCard("Total Matches", "$totalMatches", null, Icons.Rounded.FitnessCenter, Modifier.weight(1f))
                        QuickStatCard("Total Goals", "$totalGoals", null, Icons.Rounded.GpsFixed, Modifier.weight(1f))
                    }
                    Spacer(Modifier.height(12.dp))
                    Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        QuickStatCard("Total Distance", "%,.0f".format(totalDistanceKm), "km", Icons.Rounded.Place, Modifier.weight(1f))
                        QuickStatCard("Trophies", "$totalTrophies", null, Icons.Rounded.EmojiEvents, Modifier.weight(1f))
                    }
                }
            }
        }

        // ── Settings Section ──
        item {
            Text("Settings", fontSize = 18.sp, fontWeight = FontWeight.Bold, color = TextPrimary)
        }
        item {
            GlassCard {
                // Edit Profile
                SettingsRow(
                    icon = Icons.Rounded.Person,
                    title = "Edit Profile",
                    onClick = { showEditDialog = true }
                )
                HorizontalDivider(thickness = 1.dp, color = CardBorderColor)

                // Send Feedback
                SettingsRow(
                    icon = Icons.AutoMirrored.Rounded.Chat,
                    title = "Send Feedback",
                    onClick = { /* TODO */ }
                )
                HorizontalDivider(thickness = 1.dp, color = CardBorderColor)

                // Notifications
                SettingsToggleRow(
                    icon = Icons.Rounded.Notifications,
                    title = "Notifications",
                    subtitle = "Push notifications and alerts",
                    checked = notificationsEnabled,
                    onCheckedChange = { notificationsEnabled = it }
                )
            }
        }

        // ── Features Section ──
        item {
            Text("Features", fontSize = 18.sp, fontWeight = FontWeight.Bold, color = TextPrimary)
        }
        item {
            GlassCard {
                // Dark Mode
                SettingsToggleRow(
                    icon = if (darkMode) Icons.Rounded.DarkMode else Icons.Rounded.LightMode,
                    title = "Dark Mode",
                    subtitle = "Toggle theme appearance",
                    checked = darkMode,
                    onCheckedChange = { darkMode = it }
                )
                HorizontalDivider(thickness = 1.dp, color = CardBorderColor)

                // Cloud Sync
                SettingsToggleRow(
                    icon = Icons.Rounded.Cloud,
                    title = "Cloud Sync",
                    subtitle = "Auto backup to cloud",
                    checked = cloudSyncEnabled,
                    onCheckedChange = { cloudSyncEnabled = it }
                )
                HorizontalDivider(thickness = 1.dp, color = CardBorderColor)

                // Device Connection
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Box(
                        modifier = Modifier
                            .size(40.dp)
                            .clip(RoundedCornerShape(10.dp))
                            .background(Color.White.copy(alpha = 0.10f)),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(Icons.Rounded.Watch, null, tint = AccentGreen, modifier = Modifier.size(20.dp))
                    }
                    Spacer(Modifier.width(12.dp))
                    Column(modifier = Modifier.weight(1f)) {
                        Text("Device Connection", fontSize = 14.sp, fontWeight = FontWeight.Medium, color = TextPrimary)
                        Text(
                            if (deviceConnected) "Connected to Apple Watch" else "No device connected",
                            fontSize = 12.sp,
                            color = TextSecondary
                        )
                    }
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        Box(
                            modifier = Modifier
                                .size(8.dp)
                                .clip(CircleShape)
                                .background(if (deviceConnected) AccentGreen else Color.Gray)
                        )
                        Text(
                            if (deviceConnected) "Active" else "Inactive",
                            fontSize = 12.sp,
                            fontWeight = FontWeight.Medium,
                            color = if (deviceConnected) AccentGreen else Color.Gray
                        )
                    }
                }
            }
        }

        // ── Performance Summary ──
        item {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(16.dp))
                    .background(
                        Brush.horizontalGradient(
                            listOf(AccentGreen.copy(alpha = 0.20f), AccentGreen.copy(alpha = 0.05f))
                        )
                    )
                    .border(1.dp, AccentGreen.copy(alpha = 0.30f), RoundedCornerShape(16.dp))
                    .padding(20.dp)
            ) {
                Column {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column {
                            Text("Performance Score", fontSize = 13.sp, color = TextSecondary)
                            Spacer(Modifier.height(4.dp))
                            Text(
                                "$perfScore",
                                fontSize = 32.sp,
                                fontWeight = FontWeight.Bold,
                                color = AccentGreen
                            )
                        }
                        Box(
                            modifier = Modifier
                                .size(64.dp)
                                .clip(CircleShape)
                                .background(AccentGreen.copy(alpha = 0.20f)),
                            contentAlignment = Alignment.Center
                        ) {
                            Icon(Icons.Rounded.EmojiEvents, null, tint = AccentGreen, modifier = Modifier.size(32.dp))
                        }
                    }
                    Spacer(Modifier.height(8.dp))
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        Text("Global Rank:", fontSize = 13.sp, color = Color.White.copy(alpha = 0.7f))
                        Text("#4", fontSize = 13.sp, fontWeight = FontWeight.Bold, color = AccentGreen)
                        Text("•", fontSize = 13.sp, color = Color.Gray)
                        Text("Top 0.1%", fontSize = 13.sp, color = AccentGreen)
                    }
                }
            }
        }

        // ── Other Section ──
        item {
            Text("Other", fontSize = 18.sp, fontWeight = FontWeight.Bold, color = TextPrimary)
        }
        item {
            GlassCard {
                // About
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { /* about */ }
                        .padding(16.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Box(
                        modifier = Modifier
                            .size(40.dp)
                            .clip(RoundedCornerShape(10.dp))
                            .background(Color.White.copy(alpha = 0.10f)),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(Icons.Rounded.Info, null, tint = TextSecondary, modifier = Modifier.size(20.dp))
                    }
                    Spacer(Modifier.width(12.dp))
                    Column(modifier = Modifier.weight(1f)) {
                        Text("About FootyTrack", fontSize = 14.sp, fontWeight = FontWeight.Medium, color = TextPrimary)
                        Text("Version 2.4.1", fontSize = 12.sp, color = TextSecondary)
                    }
                    Icon(Icons.Rounded.ChevronRight, null, tint = TextSecondary, modifier = Modifier.size(20.dp))
                }

                HorizontalDivider(thickness = 1.dp, color = CardBorderColor)

                // Privacy
                SettingsRow(
                    icon = Icons.Rounded.Info,
                    title = "Privacy Policy",
                    iconTint = TextSecondary,
                    onClick = { /* privacy */ }
                )
            }
        }

        // ── Sign Out Button ──
        item {
            OutlinedButton(
                onClick = {
                    scope.launch {
                        userRepository.clearCache()
                        onLogout()
                    }
                },
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(16.dp),
                border = ButtonDefaults.outlinedButtonBorder(enabled = true).copy(
                    brush = Brush.linearGradient(
                        listOf(Color(0xFFEF4444).copy(alpha = 0.30f), Color(0xFFEF4444).copy(alpha = 0.30f))
                    )
                ),
                colors = ButtonDefaults.outlinedButtonColors(
                    containerColor = Color(0xFFEF4444).copy(alpha = 0.10f)
                ),
                contentPadding = PaddingValues(vertical = 16.dp)
            ) {
                Icon(Icons.AutoMirrored.Rounded.ExitToApp, null, tint = Color(0xFFEF4444), modifier = Modifier.size(20.dp))
                Spacer(Modifier.width(8.dp))
                Text("Sign Out", color = Color(0xFFEF4444), fontWeight = FontWeight.Medium, fontSize = 14.sp)
            }
        }

        // ── Footer ──
        item {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 8.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text("FootyTrack © 2026", fontSize = 12.sp, color = Color.Gray)
                Spacer(Modifier.height(4.dp))
                Text("Made for athletes who track every step", fontSize = 12.sp, color = Color.Gray)
            }
        }

        item { Spacer(Modifier.height(80.dp)) }
    }

    // Edit Profile Dialog
    if (showEditDialog && profile != null) {
        EditProfileDialog(
            profile = profile!!,
            onDismiss = { showEditDialog = false },
            onSave = { nickname, weight, age ->
                scope.launch {
                    userRepository.updateProfile(
                        uid = profile!!.uid,
                        nickname = nickname,
                        weightKg = weight,
                        age = age
                    )
                    profile = profile!!.copy(nickname = nickname, weightKg = weight, age = age)
                    editedName = nickname
                    showEditDialog = false
                }
            }
        )
    }
}

// ── Quick Stat Card ──
@Composable
private fun QuickStatCard(label: String, value: String, unit: String?, icon: ImageVector, modifier: Modifier) {
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(12.dp))
            .background(Color.Black.copy(alpha = 0.30f))
            .padding(12.dp)
    ) {
        Column {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Box(
                    modifier = Modifier
                        .size(28.dp)
                        .clip(RoundedCornerShape(8.dp))
                        .background(AccentGreen.copy(alpha = 0.20f)),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(icon, null, tint = AccentGreen, modifier = Modifier.size(14.dp))
                }
                Text(label, fontSize = 11.sp, color = TextSecondary)
            }
            Spacer(Modifier.height(6.dp))
            Row(verticalAlignment = Alignment.Bottom) {
                Text(value, fontSize = 20.sp, fontWeight = FontWeight.Bold, color = TextPrimary)
                if (unit != null) {
                    Spacer(Modifier.width(3.dp))
                    Text(unit, fontSize = 11.sp, color = TextSecondary, modifier = Modifier.padding(bottom = 2.dp))
                }
            }
        }
    }
}

// ── Settings Row (clickable with chevron) ──
@Composable
private fun SettingsRow(
    icon: ImageVector,
    title: String,
    iconTint: Color = AccentGreen,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .size(40.dp)
                .clip(RoundedCornerShape(10.dp))
                .background(Color.White.copy(alpha = 0.10f)),
            contentAlignment = Alignment.Center
        ) {
            Icon(icon, null, tint = iconTint, modifier = Modifier.size(20.dp))
        }
        Spacer(Modifier.width(12.dp))
        Text(title, fontSize = 14.sp, fontWeight = FontWeight.Medium, color = TextPrimary, modifier = Modifier.weight(1f))
        Icon(Icons.Rounded.ChevronRight, null, tint = TextSecondary, modifier = Modifier.size(20.dp))
    }
}

// ── Settings Toggle Row (with switch) ──
@Composable
private fun SettingsToggleRow(
    icon: ImageVector,
    title: String,
    subtitle: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .size(40.dp)
                .clip(RoundedCornerShape(10.dp))
                .background(Color.White.copy(alpha = 0.10f)),
            contentAlignment = Alignment.Center
        ) {
            Icon(icon, null, tint = AccentGreen, modifier = Modifier.size(20.dp))
        }
        Spacer(Modifier.width(12.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(title, fontSize = 14.sp, fontWeight = FontWeight.Medium, color = TextPrimary)
            Text(subtitle, fontSize = 12.sp, color = TextSecondary)
        }
        Switch(
            checked = checked,
            onCheckedChange = onCheckedChange,
            colors = SwitchDefaults.colors(
                checkedThumbColor = Color.White,
                checkedTrackColor = AccentGreen,
                uncheckedThumbColor = Color.White,
                uncheckedTrackColor = Color.Gray.copy(alpha = 0.30f),
                uncheckedBorderColor = Color.Gray.copy(alpha = 0.30f)
            )
        )
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
    ) {
        Column(content = content)
    }
}

// ── Edit Profile Dialog ──
@Composable
private fun EditProfileDialog(
    profile: UserProfile,
    onDismiss: () -> Unit,
    onSave: (nickname: String, weight: Double, age: Int) -> Unit
) {
    var nickname by remember { mutableStateOf(profile.nickname) }
    var weight by remember { mutableStateOf(profile.weightKg.toString()) }
    var age by remember { mutableStateOf(profile.age.toString()) }

    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = CardBg,
        titleContentColor = TextPrimary,
        title = { Text("Edit Profile") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                OutlinedTextField(
                    value = nickname,
                    onValueChange = { nickname = it.take(20) },
                    label = { Text("Nickname", color = TextSecondary) },
                    singleLine = true,
                    colors = editFieldColors()
                )
                OutlinedTextField(
                    value = weight,
                    onValueChange = { weight = it.filter { c -> c.isDigit() || c == '.' }.take(5) },
                    label = { Text("Weight (kg)", color = TextSecondary) },
                    singleLine = true,
                    colors = editFieldColors()
                )
                OutlinedTextField(
                    value = age,
                    onValueChange = { age = it.filter { c -> c.isDigit() }.take(3) },
                    label = { Text("Age", color = TextSecondary) },
                    singleLine = true,
                    colors = editFieldColors()
                )
            }
        },
        confirmButton = {
            TextButton(onClick = {
                onSave(nickname, weight.toDoubleOrNull() ?: profile.weightKg, age.toIntOrNull() ?: profile.age)
            }) { Text("Save", color = AccentGreen) }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Cancel", color = TextSecondary) }
        }
    )
}

@Composable
private fun editFieldColors() = OutlinedTextFieldDefaults.colors(
    focusedTextColor = TextPrimary,
    unfocusedTextColor = TextPrimary,
    cursorColor = AccentGreen,
    focusedBorderColor = AccentGreen,
    unfocusedBorderColor = DividerColor,
    focusedLabelColor = AccentGreen,
    unfocusedLabelColor = TextSecondary
)

private fun performanceScoreProfile(s: SessionEntity): Double {
    val speed = min(1.0, s.maxSpeedKmh / 30.0)
    val sprint = min(1.0, s.sprintCount.toDouble() / 45.0)
    val distance = min(1.0, s.totalDistanceMeters / 9000.0)
    val discipline = max(0.0, 1.0 - s.slackIndex.toDouble() / 100.0)
    val weighted = speed * 0.3 + sprint * 0.25 + distance * 0.25 + discipline * 0.2
    return min(10.0, max(6.0, 6.0 + weighted * 4.0))
}
