package com.footballtracker.android.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.footballtracker.android.auth.AuthRepository
import com.footballtracker.android.ui.theme.*
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

@Composable
fun PhoneAuthScreen(
    authRepository: AuthRepository,
    onBack: () -> Unit,
    onAuthSuccess: (isNewUser: Boolean) -> Unit
) {
    val scope = rememberCoroutineScope()

    var phoneNumber by remember { mutableStateOf("") }
    var verificationCode by remember { mutableStateOf("") }
    var step by remember { mutableIntStateOf(0) } // 0 = phone input, 1 = code input
    var isLoading by remember { mutableStateOf(false) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var countdown by remember { mutableIntStateOf(0) }

    // Countdown timer
    LaunchedEffect(countdown) {
        if (countdown > 0) {
            delay(1000L)
            countdown--
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(DarkBg)
            .padding(horizontal = 24.dp)
    ) {
        // Top bar
        Spacer(modifier = Modifier.height(16.dp))
        IconButton(onClick = {
            if (step == 1) { step = 0; verificationCode = ""; errorMessage = null }
            else onBack()
        }) {
            Icon(Icons.AutoMirrored.Rounded.ArrowBack, contentDescription = "返回", tint = TextPrimary)
        }

        Spacer(modifier = Modifier.height(32.dp))

        if (step == 0) {
            // ── Phone number input ──
            Text(
                text = "输入手机号",
                fontSize = 28.sp,
                fontWeight = FontWeight.Bold,
                color = TextPrimary
            )
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = "我们将发送验证码到你的手机",
                fontSize = 14.sp,
                color = TextSecondary
            )
            Spacer(modifier = Modifier.height(32.dp))

            // Phone input field
            OutlinedTextField(
                value = phoneNumber,
                onValueChange = { phoneNumber = it.filter { c -> c.isDigit() || c == '+' }.take(15) },
                modifier = Modifier.fillMaxWidth(),
                placeholder = { Text("+86 手机号", color = TextSecondary) },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone),
                singleLine = true,
                colors = OutlinedTextFieldDefaults.colors(
                    focusedTextColor = TextPrimary,
                    unfocusedTextColor = TextPrimary,
                    cursorColor = NeonBlue,
                    focusedBorderColor = NeonBlue,
                    unfocusedBorderColor = DividerColor,
                    focusedContainerColor = CardBg,
                    unfocusedContainerColor = CardBg
                ),
                shape = RoundedCornerShape(12.dp)
            )

            errorMessage?.let {
                Spacer(modifier = Modifier.height(8.dp))
                Text(text = it, color = HeartRed, fontSize = 13.sp)
            }

            Spacer(modifier = Modifier.height(24.dp))

            // Send code button
            Button(
                onClick = {
                    errorMessage = null
                    val formatted = if (phoneNumber.startsWith("+")) phoneNumber else "+86$phoneNumber"
                    isLoading = true
                    scope.launch {
                        val result = authRepository.sendVerificationCode(formatted)
                        isLoading = false
                        result.onSuccess {
                            step = 1
                            countdown = 60
                        }
                        result.onFailure { e ->
                            errorMessage = e.message ?: "发送验证码失败"
                        }
                    }
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(52.dp),
                enabled = phoneNumber.length >= 11 && !isLoading,
                shape = RoundedCornerShape(12.dp),
                colors = ButtonDefaults.buttonColors(containerColor = Color.Transparent),
                contentPadding = PaddingValues()
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .background(
                            brush = if (phoneNumber.length >= 11 && !isLoading)
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
                        Text("发送验证码", fontSize = 16.sp, fontWeight = FontWeight.SemiBold, color = Color.White)
                    }
                }
            }
        } else {
            // ── Verification code input ──
            Text(
                text = "输入验证码",
                fontSize = 28.sp,
                fontWeight = FontWeight.Bold,
                color = TextPrimary
            )
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = "验证码已发送到 $phoneNumber",
                fontSize = 14.sp,
                color = TextSecondary
            )
            Spacer(modifier = Modifier.height(32.dp))

            // 6-digit code input boxes
            CodeInputField(
                code = verificationCode,
                onCodeChange = { verificationCode = it },
                onComplete = { code ->
                    isLoading = true
                    errorMessage = null
                    val formatted = if (phoneNumber.startsWith("+")) phoneNumber else "+86$phoneNumber"
                    scope.launch {
                        val (result, isNewUser) = authRepository.verifyCodeCheckNew(formatted, code)
                        isLoading = false
                        result.onSuccess { onAuthSuccess(isNewUser) }
                        result.onFailure { errorMessage = it.message ?: "验证码错误" }
                    }
                }
            )

            errorMessage?.let {
                Spacer(modifier = Modifier.height(8.dp))
                Text(text = it, color = HeartRed, fontSize = 13.sp)
            }

            Spacer(modifier = Modifier.height(24.dp))

            if (isLoading) {
                CircularProgressIndicator(
                    modifier = Modifier.align(Alignment.CenterHorizontally),
                    color = NeonBlue
                )
            }

            Spacer(modifier = Modifier.height(16.dp))

            // Resend countdown
            TextButton(
                onClick = {
                    if (countdown == 0) {
                        val formatted = if (phoneNumber.startsWith("+")) phoneNumber else "+86$phoneNumber"
                        scope.launch {
                            val result = authRepository.sendVerificationCode(formatted)
                            result.onSuccess { countdown = 60 }
                            result.onFailure { errorMessage = it.message ?: "发送失败" }
                        }
                    }
                },
                enabled = countdown == 0
            ) {
                Text(
                    text = if (countdown > 0) "重新发送 (${countdown}s)" else "重新发送验证码",
                    color = if (countdown > 0) TextSecondary else NeonBlue,
                    fontSize = 14.sp
                )
            }
        }
    }
}

@Composable
private fun CodeInputField(
    code: String,
    onCodeChange: (String) -> Unit,
    onComplete: (String) -> Unit
) {
    val focusRequester = remember { FocusRequester() }

    LaunchedEffect(Unit) {
        focusRequester.requestFocus()
    }

    Box {
        // Hidden text field for keyboard input
        BasicTextField(
            value = code,
            onValueChange = { newValue ->
                val filtered = newValue.filter { it.isDigit() }.take(6)
                onCodeChange(filtered)
                if (filtered.length == 6) onComplete(filtered)
            },
            modifier = Modifier
                .focusRequester(focusRequester)
                .fillMaxWidth()
                .height(56.dp),
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
            textStyle = TextStyle(color = Color.Transparent),
            cursorBrush = SolidColor(Color.Transparent)
        )

        // Visual code boxes
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            repeat(6) { index ->
                val char = code.getOrNull(index)
                val isFocused = code.length == index

                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(56.dp)
                        .background(CardBg, RoundedCornerShape(12.dp))
                        .border(
                            width = 2.dp,
                            color = when {
                                isFocused -> NeonBlue
                                char != null -> NeonBlue.copy(alpha = 0.5f)
                                else -> DividerColor
                            },
                            shape = RoundedCornerShape(12.dp)
                        ),
                    contentAlignment = Alignment.Center
                ) {
                    if (char != null) {
                        Text(
                            text = char.toString(),
                            fontSize = 24.sp,
                            fontWeight = FontWeight.Bold,
                            color = TextPrimary,
                            textAlign = TextAlign.Center
                        )
                    }
                }
            }
        }
    }
}
