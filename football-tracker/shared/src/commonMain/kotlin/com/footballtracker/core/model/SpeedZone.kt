package com.footballtracker.core.model

/**
 * Speed zones for football movement analysis.
 * Thresholds based on common football analytics standards.
 */
enum class SpeedZone(val label: String, val minKmh: Double, val maxKmh: Double) {
    STANDING("静止", 0.0, 0.5),
    WALKING("步行", 0.5, 6.0),
    JOGGING("慢跑", 6.0, 12.0),
    RUNNING("跑动", 12.0, 18.0),
    HIGH_SPEED("高速跑", 18.0, 24.0),
    SPRINTING("冲刺", 24.0, Double.MAX_VALUE);

    companion object {
        fun fromSpeedKmh(speedKmh: Double): SpeedZone =
            entries.first { speedKmh >= it.minKmh && speedKmh < it.maxKmh }

        fun fromSpeedMs(speedMs: Double): SpeedZone =
            fromSpeedKmh(speedMs * 3.6)
    }
}
