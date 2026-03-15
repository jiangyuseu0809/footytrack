package com.footballtracker.android.ui.theme

import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

// ── Color Palette ──
val DarkBg         = Color(0xFF0D1117)
val CardBg         = Color(0xFF161B22)
val CardBgLight    = Color(0xFF1C2333)
val DividerColor   = Color(0xFF30363D)
val TextPrimary    = Color(0xFFFFFFFF)
val TextSecondary  = Color(0xFF8B949E)

val NeonBlue       = Color(0xFF00E676)   // Primary green (matches logo)
val NeonPurple     = Color(0xFF00BFA5)   // Secondary teal (matches logo)
val HeartRed       = Color(0xFFFF4757)
val HeartRedLight  = Color(0xFFFF6B81)
val CalorieOrange  = Color(0xFFFFA502)
val CalorieOrangeD = Color(0xFFFF6348)
val SpeedGreen     = Color(0xFF2ED573)
val SpeedGreenL    = Color(0xFF7BED9F)

val SlackGreen     = Color(0xFF2ED573)
val SlackYellow    = Color(0xFFFFA502)
val SlackRed       = Color(0xFFFF4757)

// ── Gradient Brushes ──
val NeonGradient = Brush.horizontalGradient(listOf(NeonBlue, NeonPurple))
val NeonGradientV = Brush.verticalGradient(listOf(NeonBlue, NeonPurple))
val HeartGradient = Brush.horizontalGradient(listOf(HeartRed, HeartRedLight))
val CalorieGradient = Brush.horizontalGradient(listOf(CalorieOrange, CalorieOrangeD))
val SpeedGradient = Brush.horizontalGradient(listOf(SpeedGreen, SpeedGreenL))
val DistanceGradient = Brush.horizontalGradient(listOf(NeonBlue, Color(0xFF69F0AE)))

// ── Dark Color Scheme ──
private val DarkColorScheme = darkColorScheme(
    primary = NeonBlue,
    onPrimary = Color.White,
    secondary = NeonPurple,
    onSecondary = Color.White,
    background = DarkBg,
    onBackground = TextPrimary,
    surface = CardBg,
    onSurface = TextPrimary,
    surfaceVariant = CardBgLight,
    onSurfaceVariant = TextSecondary,
    outline = DividerColor,
    error = HeartRed,
    onError = Color.White,
)

// ── Typography ──
val AppTypography = Typography(
    displayLarge = TextStyle(fontSize = 40.sp, fontWeight = FontWeight.Bold, color = TextPrimary),
    displayMedium = TextStyle(fontSize = 32.sp, fontWeight = FontWeight.Bold, color = TextPrimary),
    headlineLarge = TextStyle(fontSize = 28.sp, fontWeight = FontWeight.SemiBold, color = TextPrimary),
    headlineMedium = TextStyle(fontSize = 22.sp, fontWeight = FontWeight.SemiBold, color = TextPrimary),
    titleLarge = TextStyle(fontSize = 20.sp, fontWeight = FontWeight.Bold, color = TextPrimary),
    titleMedium = TextStyle(fontSize = 18.sp, fontWeight = FontWeight.Bold, color = TextPrimary),
    bodyLarge = TextStyle(fontSize = 16.sp, fontWeight = FontWeight.Normal, color = TextPrimary),
    bodyMedium = TextStyle(fontSize = 14.sp, fontWeight = FontWeight.Normal, color = TextPrimary),
    labelLarge = TextStyle(fontSize = 14.sp, fontWeight = FontWeight.Medium, color = TextSecondary),
    labelMedium = TextStyle(fontSize = 13.sp, fontWeight = FontWeight.Medium, color = TextSecondary),
    labelSmall = TextStyle(fontSize = 12.sp, fontWeight = FontWeight.Medium, color = TextSecondary),
)

// ── Shapes ──
val AppShapes = Shapes(
    small = androidx.compose.foundation.shape.RoundedCornerShape(8.dp),
    medium = androidx.compose.foundation.shape.RoundedCornerShape(12.dp),
    large = androidx.compose.foundation.shape.RoundedCornerShape(16.dp),
    extraLarge = androidx.compose.foundation.shape.RoundedCornerShape(24.dp),
)

@Composable
fun FootballTrackerTheme(
    content: @Composable () -> Unit
) {
    MaterialTheme(
        colorScheme = DarkColorScheme,
        typography = AppTypography,
        shapes = AppShapes,
        content = content
    )
}
