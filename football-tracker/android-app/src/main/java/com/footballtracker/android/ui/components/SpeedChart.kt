package com.footballtracker.android.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.*
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.footballtracker.android.ui.theme.*
import com.footballtracker.core.model.TrackPoint
import com.footballtracker.core.util.GeoUtils

@Composable
fun SpeedChart(
    points: List<TrackPoint>,
    modifier: Modifier = Modifier,
    showHeartRate: Boolean = false
) {
    if (points.isEmpty()) return

    val startTime = points.first().timestamp
    val values = if (showHeartRate) {
        points.map { (it.timestamp - startTime) / 1000.0 to it.heartRate.toDouble() }
    } else {
        points.map { (it.timestamp - startTime) / 1000.0 to GeoUtils.msToKmh(it.speed) }
    }

    val maxTime = values.maxOf { it.first }.coerceAtLeast(1.0)
    val maxVal = values.maxOf { it.second }.coerceAtLeast(1.0)

    val gradientColors = if (showHeartRate) {
        listOf(HeartRed, HeartRedLight)
    } else {
        listOf(NeonBlue, NeonPurple)
    }
    val fillAlpha = 0.15f

    Card(
        modifier = modifier,
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.cardColors(containerColor = CardBg),
        elevation = CardDefaults.cardElevation(defaultElevation = 0.dp)
    ) {
        Column(modifier = Modifier.padding(16.dp)) {
            Text(
                text = if (showHeartRate) "心率曲线 (bpm)" else "速度曲线 (km/h)",
                fontSize = 14.sp,
                fontWeight = FontWeight.SemiBold,
                color = TextPrimary
            )
            Spacer(modifier = Modifier.height(12.dp))

            Canvas(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(180.dp)
            ) {
                val w = size.width
                val h = size.height

                // Dashed grid lines
                val gridColor = DividerColor.copy(alpha = 0.4f)
                val gridLines = 4
                for (i in 0..gridLines) {
                    val y = h * i / gridLines
                    val dashWidth = 6f
                    val gapWidth = 4f
                    var x = 0f
                    while (x < w) {
                        drawLine(
                            color = gridColor,
                            start = Offset(x, y),
                            end = Offset((x + dashWidth).coerceAtMost(w), y),
                            strokeWidth = 1f
                        )
                        x += dashWidth + gapWidth
                    }
                }

                // Speed zone backgrounds (speed chart only)
                if (!showHeartRate) {
                    val zones = listOf(
                        0.0 to 6.0 to SpeedGreen.copy(alpha = 0.06f),
                        6.0 to 12.0 to SlackYellow.copy(alpha = 0.06f),
                        12.0 to 18.0 to CalorieOrange.copy(alpha = 0.06f),
                        18.0 to maxVal to HeartRed.copy(alpha = 0.06f)
                    )
                    for ((range, color) in zones) {
                        val (low, high) = range
                        val y1 = h - (high / maxVal * h).toFloat()
                        val y2 = h - (low / maxVal * h).toFloat()
                        drawRect(
                            color = color,
                            topLeft = Offset(0f, y1.coerceAtLeast(0f)),
                            size = Size(w, (y2 - y1).coerceAtLeast(0f))
                        )
                    }
                }

                // Build path from data
                val step = (values.size / (w / 2).toInt()).coerceAtLeast(1)
                val path = Path()
                val fillPath = Path()
                var first = true

                for (i in values.indices step step) {
                    val (time, value) = values[i]
                    val x = (time / maxTime * w).toFloat()
                    val y = h - (value / maxVal * h).toFloat()

                    if (first) {
                        path.moveTo(x, y)
                        fillPath.moveTo(x, h)
                        fillPath.lineTo(x, y)
                        first = false
                    } else {
                        path.lineTo(x, y)
                        fillPath.lineTo(x, y)
                    }
                }

                // Close fill path
                val lastX = (values.last().first / maxTime * w).toFloat()
                fillPath.lineTo(lastX, h)
                fillPath.close()

                // Draw gradient fill under curve
                drawPath(
                    path = fillPath,
                    brush = Brush.verticalGradient(
                        colors = listOf(
                            gradientColors[0].copy(alpha = fillAlpha),
                            Color.Transparent
                        )
                    )
                )

                // Draw gradient line
                drawPath(
                    path = path,
                    brush = Brush.horizontalGradient(gradientColors),
                    style = Stroke(width = 2.5f, cap = StrokeCap.Round, join = StrokeJoin.Round)
                )
            }

            Spacer(modifier = Modifier.height(6.dp))

            // Axis labels
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween
            ) {
                Text("0 min", fontSize = 10.sp, color = TextSecondary)
                Text(
                    "${(maxTime / 60).toInt()} min",
                    fontSize = 10.sp,
                    color = TextSecondary
                )
            }
        }
    }
}
