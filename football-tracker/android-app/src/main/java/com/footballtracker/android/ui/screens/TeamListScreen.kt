package com.footballtracker.android.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowForwardIos
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.footballtracker.android.network.ApiClient
import com.footballtracker.android.network.CreateTeamRequest
import com.footballtracker.android.network.JoinTeamRequest
import com.footballtracker.android.network.TeamResponse
import com.footballtracker.android.ui.theme.*
import kotlinx.coroutines.launch

@Composable
fun TeamListScreen(
    onNavigateTeamDetail: (String) -> Unit,
    onBack: () -> Unit
) {
    val scope = rememberCoroutineScope()
    var teams by remember { mutableStateOf<List<TeamResponse>>(emptyList()) }
    var showCreateDialog by remember { mutableStateOf(false) }
    var showJoinDialog by remember { mutableStateOf(false) }
    var newTeamName by remember { mutableStateOf("") }
    var inviteCode by remember { mutableStateOf("") }
    var isLoading by remember { mutableStateOf(true) }

    LaunchedEffect(Unit) {
        try {
            teams = ApiClient.api.getTeams().teams
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
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text("我的球队", fontSize = 28.sp, fontWeight = FontWeight.Bold, color = TextPrimary)
                Row {
                    IconButton(onClick = { showCreateDialog = true }) {
                        Icon(Icons.Rounded.Add, contentDescription = "创建", tint = NeonBlue)
                    }
                }
            }
        }

        // Content
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            // Buttons row
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Button(
                    onClick = { showCreateDialog = true },
                    modifier = Modifier.weight(1f),
                    colors = ButtonDefaults.buttonColors(containerColor = NeonBlue),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Text("创建球队", color = DarkBg, fontWeight = FontWeight.SemiBold)
                }
                OutlinedButton(
                    onClick = { showJoinDialog = true },
                    modifier = Modifier.weight(1f),
                    shape = RoundedCornerShape(12.dp),
                    colors = ButtonDefaults.outlinedButtonColors(contentColor = NeonBlue)
                ) {
                    Text("加入球队")
                }
            }

            Spacer(modifier = Modifier.height(8.dp))

            if (teams.isEmpty() && !isLoading) {
                Box(
                    modifier = Modifier.fillMaxWidth().padding(vertical = 40.dp),
                    contentAlignment = Alignment.Center
                ) {
                    Text("还没有球队", fontSize = 16.sp, color = TextSecondary)
                }
            } else {
                teams.forEach { team ->
                    Card(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { onNavigateTeamDetail(team.id) },
                        shape = RoundedCornerShape(12.dp),
                        colors = CardDefaults.cardColors(containerColor = CardBg),
                        elevation = CardDefaults.cardElevation(0.dp)
                    ) {
                        Row(
                            modifier = Modifier.padding(16.dp).fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column {
                                Text(team.name, fontSize = 16.sp, fontWeight = FontWeight.SemiBold, color = TextPrimary)
                                Spacer(modifier = Modifier.height(4.dp))
                                Text("邀请码: ${team.inviteCode}", fontSize = 12.sp, color = TextSecondary)
                            }
                            Icon(
                                Icons.AutoMirrored.Rounded.ArrowForwardIos,
                                contentDescription = null,
                                tint = TextSecondary,
                                modifier = Modifier.size(16.dp)
                            )
                        }
                    }
                }
            }
        }
    }

    // Create dialog
    if (showCreateDialog) {
        AlertDialog(
            onDismissRequest = { showCreateDialog = false },
            containerColor = CardBg,
            title = { Text("创建球队", color = TextPrimary) },
            text = {
                OutlinedTextField(
                    value = newTeamName,
                    onValueChange = { newTeamName = it },
                    label = { Text("球队名称") },
                    singleLine = true,
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = NeonBlue,
                        cursorColor = NeonBlue,
                        focusedTextColor = TextPrimary,
                        unfocusedTextColor = TextPrimary
                    )
                )
            },
            confirmButton = {
                TextButton(onClick = {
                    scope.launch {
                        try {
                            val team = ApiClient.api.createTeam(CreateTeamRequest(newTeamName))
                            teams = teams + team
                            newTeamName = ""
                            showCreateDialog = false
                        } catch (_: Exception) {}
                    }
                }) { Text("创建", color = NeonBlue) }
            },
            dismissButton = {
                TextButton(onClick = { showCreateDialog = false; newTeamName = "" }) {
                    Text("取消", color = TextSecondary)
                }
            }
        )
    }

    // Join dialog
    if (showJoinDialog) {
        AlertDialog(
            onDismissRequest = { showJoinDialog = false },
            containerColor = CardBg,
            title = { Text("加入球队", color = TextPrimary) },
            text = {
                OutlinedTextField(
                    value = inviteCode,
                    onValueChange = { inviteCode = it },
                    label = { Text("邀请码") },
                    singleLine = true,
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = NeonBlue,
                        cursorColor = NeonBlue,
                        focusedTextColor = TextPrimary,
                        unfocusedTextColor = TextPrimary
                    )
                )
            },
            confirmButton = {
                TextButton(onClick = {
                    scope.launch {
                        try {
                            val team = ApiClient.api.joinTeamByCode(JoinTeamRequest(inviteCode))
                            teams = teams + team
                            inviteCode = ""
                            showJoinDialog = false
                        } catch (_: Exception) {}
                    }
                }) { Text("加入", color = NeonBlue) }
            },
            dismissButton = {
                TextButton(onClick = { showJoinDialog = false; inviteCode = "" }) {
                    Text("取消", color = TextSecondary)
                }
            }
        )
    }
}
