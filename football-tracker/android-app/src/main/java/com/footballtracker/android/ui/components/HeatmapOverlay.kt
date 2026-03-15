package com.footballtracker.android.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.footballtracker.android.ui.theme.*

@Composable
fun HeatmapOverlay(
    grid: List<List<Double>>,
    modifier: Modifier = Modifier
) {
    if (grid.isEmpty()) return

    val rows = grid.size
    val cols = grid[0].size

    Card(
        modifier = modifier,
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(containerColor = CardBg),
        elevation = CardDefaults.cardElevation(defaultElevation = 0.dp)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = "热力图",
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                color = TextPrimary
            )
            Spacer(modifier = Modifier.height(12.dp))

            Canvas(
                modifier = Modifier
                    .fillMaxWidth()
                    .aspectRatio(cols.toFloat() / rows)
            ) {
                val cellW = size.width / cols
                val cellH = size.height / rows

                // Field outline (dashed white rectangle)
                val dashEffect = PathEffect.dashPathEffect(floatArrayOf(10f, 6f), 0f)
                drawRoundRect(
                    color = Color.White.copy(alpha = 0.25f),
                    topLeft = Offset(2f, 2f),
                    size = Size(size.width - 4f, size.height - 4f),
                    cornerRadius = CornerRadius(8f, 8f),
                    style = Stroke(width = 1.5f, pathEffect = dashEffect)
                )

                // Center line
                drawLine(
                    color = Color.White.copy(alpha = 0.12f),
                    start = Offset(size.width / 2, 2f),
                    end = Offset(size.width / 2, size.height - 2f),
                    strokeWidth = 1f,
                    pathEffect = dashEffect
                )

                // Heatmap cells
                for (r in 0 until rows) {
                    for (c in 0 until cols) {
                        val intensity = grid[r][c]
                        if (intensity > 0.01) {
                            val color = heatColor(intensity)
                            drawRect(
                                color = color,
                                topLeft = Offset(c * cellW, (rows - 1 - r) * cellH),
                                size = Size(cellW, cellH)
                            )
                        }
                    }
                }
            }

            Spacer(modifier = Modifier.height(12.dp))

            // Color legend bar
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text("冷", fontSize = 10.sp, color = TextSecondary)
                Spacer(modifier = Modifier.width(6.dp))
                Canvas(
                    modifier = Modifier
                        .weight(1f)
                        .height(10.dp)
                ) {
                    drawRoundRect(
                        brush = Brush.horizontalGradient(
                            listOf(
                                NeonBlue.copy(alpha = 0.5f),
                                SpeedGreen.copy(alpha = 0.7f),
                                SlackYellow.copy(alpha = 0.8f),
                                HeartRed.copy(alpha = 0.9f)
                            )
                        ),
                        cornerRadius = CornerRadius(5f, 5f)
                    )
                }
                Spacer(modifier = Modifier.width(6.dp))
                Text("热", fontSize = 10.sp, color = TextSecondary)
            }
        }
    }
}

private fun heatColor(intensity: Double): Color {
    val i = intensity.coerceIn(0.0, 1.0)
    return when {
        i < 0.25 -> {
            val t = (i / 0.25).toFloat()
            Color(0f, t * 0.8f, 1f, 0.5f + t * 0.1f)
        }
        i < 0.5 -> {
            val t = ((i - 0.25) / 0.25).toFloat()
            Color(t * 0.2f, 0.84f, 1f - t * 0.55f, 0.6f + t * 0.1f)
        }
        i < 0.75 -> {
            val t = ((i - 0.5) / 0.25).toFloat()
            Color(1f * t + 0.2f * (1 - t), 0.84f - t * 0.2f, 0.45f * (1 - t), 0.7f + t * 0.1f)
        }
        else -> {
            val t = ((i - 0.75) / 0.25).toFloat()
            Color(1f, 0.64f - t * 0.36f, 0f, 0.8f + t * 0.15f)
        }
    }
}
