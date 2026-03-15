package com.footballtracker.android.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.SportsSoccer
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.footballtracker.android.ui.theme.*

@Composable
fun OnboardingScreen(
    onComplete: (nickname: String, weightKg: Double, age: Int) -> Unit
) {
    var nickname by remember { mutableStateOf("") }
    var weight by remember { mutableStateOf("70") }
    var age by remember { mutableStateOf("25") }
    var isLoading by remember { mutableStateOf(false) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(DarkBg)
            .padding(horizontal = 32.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Spacer(modifier = Modifier.height(80.dp))

        Icon(
            imageVector = Icons.Rounded.SportsSoccer,
            contentDescription = null,
            modifier = Modifier.size(64.dp),
            tint = NeonBlue
        )

        Spacer(modifier = Modifier.height(16.dp))

        Text(
            text = "完善个人信息",
            fontSize = 28.sp,
            fontWeight = FontWeight.Bold,
            color = TextPrimary
        )

        Spacer(modifier = Modifier.height(8.dp))

        Text(
            text = "帮助我们更准确地计算卡路里和运动数据",
            fontSize = 14.sp,
            color = TextSecondary
        )

        Spacer(modifier = Modifier.height(40.dp))

        // Nickname
        OutlinedTextField(
            value = nickname,
            onValueChange = { nickname = it.take(20) },
            modifier = Modifier.fillMaxWidth(),
            label = { Text("昵称", color = TextSecondary) },
            placeholder = { Text("输入你的昵称", color = TextSecondary.copy(alpha = 0.5f)) },
            singleLine = true,
            colors = outlinedFieldColors(),
            shape = RoundedCornerShape(12.dp)
        )

        Spacer(modifier = Modifier.height(16.dp))

        // Weight and Age in a row
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            OutlinedTextField(
                value = weight,
                onValueChange = { weight = it.filter { c -> c.isDigit() || c == '.' }.take(5) },
                modifier = Modifier.weight(1f),
                label = { Text("体重 (kg)", color = TextSecondary) },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                singleLine = true,
                colors = outlinedFieldColors(),
                shape = RoundedCornerShape(12.dp)
            )

            OutlinedTextField(
                value = age,
                onValueChange = { age = it.filter { c -> c.isDigit() }.take(3) },
                modifier = Modifier.weight(1f),
                label = { Text("年龄", color = TextSecondary) },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                singleLine = true,
                colors = outlinedFieldColors(),
                shape = RoundedCornerShape(12.dp)
            )
        }

        Spacer(modifier = Modifier.height(40.dp))

        // Submit button
        Button(
            onClick = {
                isLoading = true
                val w = weight.toDoubleOrNull() ?: 70.0
                val a = age.toIntOrNull() ?: 25
                onComplete(nickname, w, a)
            },
            modifier = Modifier
                .fillMaxWidth()
                .height(52.dp),
            enabled = nickname.isNotBlank() && !isLoading,
            shape = RoundedCornerShape(12.dp),
            colors = ButtonDefaults.buttonColors(containerColor = Color.Transparent),
            contentPadding = PaddingValues()
        ) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(
                        brush = if (nickname.isNotBlank() && !isLoading)
                            Brush.horizontalGradient(listOf(NeonBlue, NeonPurple))
                        else
                            Brush.horizontalGradient(listOf(Color.Gray, Color.Gray)),
                        shape = RoundedCornerShape(12.dp)
                    ),
                contentAlignment = Alignment.Center
            ) {
                if (isLoading) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(24.dp),
                        color = Color.White,
                        strokeWidth = 2.dp
                    )
                } else {
                    Text(
                        text = "开始踢球 ⚽",
                        fontSize = 16.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = Color.White
                    )
                }
            }
        }
    }
}

@Composable
private fun outlinedFieldColors() = OutlinedTextFieldDefaults.colors(
    focusedTextColor = TextPrimary,
    unfocusedTextColor = TextPrimary,
    cursorColor = NeonBlue,
    focusedBorderColor = NeonBlue,
    unfocusedBorderColor = DividerColor,
    focusedContainerColor = CardBg,
    unfocusedContainerColor = CardBg,
    focusedLabelColor = NeonBlue,
    unfocusedLabelColor = TextSecondary
)
