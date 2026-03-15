package com.footballtracker.android.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.Logout
import androidx.compose.material.icons.rounded.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.footballtracker.android.auth.AuthRepository
import com.footballtracker.android.data.model.UserProfile
import com.footballtracker.android.data.repository.CloudSessionSync
import com.footballtracker.android.data.repository.UserRepository
import com.footballtracker.android.ui.theme.*
import kotlinx.coroutines.launch

@Composable
fun SettingsScreen(
    userRepository: UserRepository,
    authRepository: AuthRepository,
    cloudSync: CloudSessionSync,
    onLogout: () -> Unit
) {
    val scope = rememberCoroutineScope()
    val currentUser by authRepository.currentUser.collectAsState()
    var profile by remember { mutableStateOf<UserProfile?>(null) }
    var showEditDialog by remember { mutableStateOf(false) }
    var syncStatus by remember { mutableStateOf("") }
    var isSyncing by remember { mutableStateOf(false) }

    LaunchedEffect(currentUser) {
        currentUser?.let { user ->
            profile = userRepository.getProfile(user.uid)
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(DarkBg)
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp)
    ) {
        Spacer(modifier = Modifier.height(24.dp))

        Text(
            text = "设置",
            fontSize = 28.sp,
            fontWeight = FontWeight.Bold,
            color = TextPrimary
        )

        Spacer(modifier = Modifier.height(24.dp))

        // ── User Profile Card ──
        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(containerColor = CardBg)
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(20.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                // Avatar circle with first char of nickname
                Box(
                    modifier = Modifier
                        .size(56.dp)
                        .clip(CircleShape)
                        .background(NeonBlue.copy(alpha = 0.2f)),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = profile?.nickname?.take(1) ?: "?",
                        fontSize = 24.sp,
                        fontWeight = FontWeight.Bold,
                        color = NeonBlue
                    )
                }

                Spacer(modifier = Modifier.width(16.dp))

                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = profile?.nickname ?: "加载中...",
                        fontSize = 18.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = TextPrimary
                    )
                    Spacer(modifier = Modifier.height(4.dp))
                    Text(
                        text = buildString {
                            append("${profile?.weightKg ?: "--"} kg")
                            append(" · ")
                            append("${profile?.age ?: "--"} 岁")
                        },
                        fontSize = 13.sp,
                        color = TextSecondary
                    )
                }

                IconButton(onClick = { showEditDialog = true }) {
                    Icon(Icons.Rounded.Edit, contentDescription = "编辑", tint = TextSecondary)
                }
            }
        }

        Spacer(modifier = Modifier.height(20.dp))

        // ── Cloud Sync Section ──
        Text(
            text = "数据同步",
            fontSize = 14.sp,
            fontWeight = FontWeight.Medium,
            color = TextSecondary,
            modifier = Modifier.padding(start = 4.dp, bottom = 8.dp)
        )

        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(containerColor = CardBg)
        ) {
            Column {
                SettingsItem(
                    icon = Icons.Rounded.CloudUpload,
                    title = "立即同步",
                    subtitle = if (isSyncing) "同步中..." else syncStatus.ifEmpty { "将训练数据备份到云端" },
                    iconTint = NeonBlue,
                    onClick = {
                        if (!isSyncing) {
                            isSyncing = true
                            syncStatus = ""
                            scope.launch {
                                try {
                                    val count = cloudSync.syncPendingSessions()
                                    syncStatus = if (count > 0) "已同步 $count 条记录" else "数据已是最新"
                                } catch (e: Exception) {
                                    syncStatus = "同步失败: ${e.message}"
                                }
                                isSyncing = false
                            }
                        }
                    }
                )

                Divider(color = DividerColor, modifier = Modifier.padding(horizontal = 16.dp))

                SettingsItem(
                    icon = Icons.Rounded.CloudDownload,
                    title = "恢复数据",
                    subtitle = "从云端恢复训练记录",
                    iconTint = SpeedGreen,
                    onClick = {
                        if (!isSyncing) {
                            isSyncing = true
                            syncStatus = ""
                            scope.launch {
                                try {
                                    val count = cloudSync.pullSessionsFromCloud()
                                    syncStatus = if (count > 0) "已恢复 $count 条记录" else "没有新数据"
                                } catch (e: Exception) {
                                    syncStatus = "恢复失败: ${e.message}"
                                }
                                isSyncing = false
                            }
                        }
                    }
                )
            }
        }

        Spacer(modifier = Modifier.height(20.dp))

        // ── Account Section ──
        Text(
            text = "账号",
            fontSize = 14.sp,
            fontWeight = FontWeight.Medium,
            color = TextSecondary,
            modifier = Modifier.padding(start = 4.dp, bottom = 8.dp)
        )

        Card(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(16.dp),
            colors = CardDefaults.cardColors(containerColor = CardBg)
        ) {
            SettingsItem(
                icon = Icons.AutoMirrored.Rounded.Logout,
                title = "退出登录",
                subtitle = currentUser?.phone ?: "已登录",
                iconTint = HeartRed,
                onClick = {
                    scope.launch {
                        userRepository.clearCache()
                        onLogout()
                    }
                }
            )
        }

        Spacer(modifier = Modifier.height(32.dp))
    }

    // ── Edit Profile Dialog ──
    if (showEditDialog && profile != null) {
        EditProfileDialog(
            profile = profile!!,
            onDismiss = { showEditDialog = false },
            onSave = { newNickname, newWeight, newAge ->
                scope.launch {
                    userRepository.updateProfile(
                        uid = profile!!.uid,
                        nickname = newNickname,
                        weightKg = newWeight,
                        age = newAge
                    )
                    profile = profile!!.copy(
                        nickname = newNickname,
                        weightKg = newWeight,
                        age = newAge
                    )
                    showEditDialog = false
                }
            }
        )
    }
}

@Composable
private fun SettingsItem(
    icon: ImageVector,
    title: String,
    subtitle: String,
    iconTint: Color,
    onClick: () -> Unit
) {
    Surface(
        onClick = onClick,
        color = Color.Transparent
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 14.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .clip(RoundedCornerShape(8.dp))
                    .background(iconTint.copy(alpha = 0.15f)),
                contentAlignment = Alignment.Center
            ) {
                Icon(
                    imageVector = icon,
                    contentDescription = null,
                    modifier = Modifier.size(20.dp),
                    tint = iconTint
                )
            }

            Spacer(modifier = Modifier.width(12.dp))

            Column(modifier = Modifier.weight(1f)) {
                Text(text = title, fontSize = 15.sp, color = TextPrimary)
                Text(text = subtitle, fontSize = 12.sp, color = TextSecondary)
            }

            Icon(
                imageVector = Icons.Rounded.ChevronRight,
                contentDescription = null,
                tint = TextSecondary,
                modifier = Modifier.size(20.dp)
            )
        }
    }
}

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
        textContentColor = TextPrimary,
        title = { Text("编辑资料") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                OutlinedTextField(
                    value = nickname,
                    onValueChange = { nickname = it.take(20) },
                    label = { Text("昵称", color = TextSecondary) },
                    singleLine = true,
                    colors = dialogFieldColors()
                )
                OutlinedTextField(
                    value = weight,
                    onValueChange = { weight = it.filter { c -> c.isDigit() || c == '.' }.take(5) },
                    label = { Text("体重 (kg)", color = TextSecondary) },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                    singleLine = true,
                    colors = dialogFieldColors()
                )
                OutlinedTextField(
                    value = age,
                    onValueChange = { age = it.filter { c -> c.isDigit() }.take(3) },
                    label = { Text("年龄", color = TextSecondary) },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    singleLine = true,
                    colors = dialogFieldColors()
                )
            }
        },
        confirmButton = {
            TextButton(onClick = {
                onSave(
                    nickname,
                    weight.toDoubleOrNull() ?: profile.weightKg,
                    age.toIntOrNull() ?: profile.age
                )
            }) {
                Text("保存", color = NeonBlue)
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("取消", color = TextSecondary)
            }
        }
    )
}

@Composable
private fun dialogFieldColors() = OutlinedTextFieldDefaults.colors(
    focusedTextColor = TextPrimary,
    unfocusedTextColor = TextPrimary,
    cursorColor = NeonBlue,
    focusedBorderColor = NeonBlue,
    unfocusedBorderColor = DividerColor,
    focusedLabelColor = NeonBlue,
    unfocusedLabelColor = TextSecondary
)
