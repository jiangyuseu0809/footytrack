package com.footballtracker.core.analysis

import com.footballtracker.core.model.TrackPoint

/**
 * Generates a 2D density grid for heatmap visualization.
 * Maps GPS points onto a normalized grid relative to the playing field bounds.
 */
object HeatmapGenerator {

    data class HeatmapData(
        val grid: List<List<Double>>,  // rows x cols, normalized 0.0-1.0
        val rows: Int,
        val cols: Int,
        val minLat: Double,
        val maxLat: Double,
        val minLon: Double,
        val maxLon: Double
    )

    /**
     * Generate a heatmap grid from track points.
     *
     * @param points GPS track points
     * @param rows Number of grid rows (default 50 for a football field ~100m)
     * @param cols Number of grid columns (default 30 for ~60m width)
     * @param smoothing Whether to apply Gaussian-like smoothing
     */
    fun generate(
        points: List<TrackPoint>,
        rows: Int = 50,
        cols: Int = 30,
        smoothing: Boolean = true
    ): HeatmapData {
        if (points.isEmpty()) {
            return HeatmapData(
                grid = List(rows) { List(cols) { 0.0 } },
                rows = rows, cols = cols,
                minLat = 0.0, maxLat = 0.0, minLon = 0.0, maxLon = 0.0
            )
        }

        val minLat = points.minOf { it.latitude }
        val maxLat = points.maxOf { it.latitude }
        val minLon = points.minOf { it.longitude }
        val maxLon = points.maxOf { it.longitude }

        val latRange = maxLat - minLat
        val lonRange = maxLon - minLon

        // Build raw count grid
        val rawGrid = Array(rows) { IntArray(cols) }

        if (latRange > 0 && lonRange > 0) {
            for (p in points) {
                val r = ((p.latitude - minLat) / latRange * (rows - 1)).toInt().coerceIn(0, rows - 1)
                val c = ((p.longitude - minLon) / lonRange * (cols - 1)).toInt().coerceIn(0, cols - 1)
                rawGrid[r][c]++
            }
        }

        // Optional smoothing (simple 3x3 averaging)
        val smoothed = if (smoothing) smooth(rawGrid, rows, cols) else {
            Array(rows) { r -> DoubleArray(cols) { c -> rawGrid[r][c].toDouble() } }
        }

        // Normalize to 0.0-1.0
        val maxVal = smoothed.maxOf { it.max() }
        val normalized = if (maxVal > 0) {
            List(rows) { r -> List(cols) { c -> smoothed[r][c] / maxVal } }
        } else {
            List(rows) { List(cols) { 0.0 } }
        }

        return HeatmapData(
            grid = normalized,
            rows = rows, cols = cols,
            minLat = minLat, maxLat = maxLat,
            minLon = minLon, maxLon = maxLon
        )
    }

    private fun smooth(grid: Array<IntArray>, rows: Int, cols: Int): Array<DoubleArray> {
        val result = Array(rows) { DoubleArray(cols) }
        for (r in 0 until rows) {
            for (c in 0 until cols) {
                var sum = 0.0
                var count = 0
                for (dr in -1..1) {
                    for (dc in -1..1) {
                        val nr = r + dr
                        val nc = c + dc
                        if (nr in 0 until rows && nc in 0 until cols) {
                            sum += grid[nr][nc]
                            count++
                        }
                    }
                }
                result[r][c] = sum / count
            }
        }
        return result
    }
}
