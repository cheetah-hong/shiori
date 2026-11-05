package com.nihongoapp.shiori

import kotlin.math.ceil
import kotlin.math.floor

/**
 * Pure pixel arithmetic of the ★ check (`measureStars`), free of Android types so it runs in JVM
 * unit tests: which pixels of the stored bitmap a cell on the upright page covers, and how many of
 * them are red.
 */
object StarPixels {
    /** Rounding slack, so a cell edge at 24.000000000000004 px stays at 24. */
    private const val EDGE_SLACK = 1e-6

    /** A red pixel has `R > minRed` and `R - max(G, B) > minRedLead`. */
    data class Color(val minRed: Int, val minRedLead: Int)

    /** A box on the upright page, normalized to 0..1 (origin top-left), as the Dart side sends it. */
    data class Cell(val x: Double, val y: Double, val w: Double, val h: Double)

    /** Pixel rectangle in the stored bitmap; [right] and [bottom] are exclusive. */
    data class PixelRect(val left: Int, val top: Int, val right: Int, val bottom: Int) {
        val width get() = right - left
        val height get() = bottom - top
        val isEmpty get() = width <= 0 || height <= 0
    }

    fun isRed(argb: Int, color: Color): Boolean {
        val r = (argb shr 16) and 0xFF
        val g = (argb shr 8) and 0xFF
        val b = argb and 0xFF
        return r > color.minRed && r - maxOf(g, b) > color.minRedLead
    }

    /** Share of red pixels in [pixels] (ARGB); 0 for no pixels. */
    fun redShare(pixels: IntArray, color: Color): Double {
        if (pixels.isEmpty()) return 0.0
        return pixels.count { isRed(it, color) }.toDouble() / pixels.size
    }

    /**
     * ARGB values of [rect] from a bitmap's raw bytes ([rgba]: ARGB_8888 memory order R, G, B, A;
     * [rowBytes] per row), as stored: no conversion to sRGB (`Bitmap.getPixels` converts a Display P3
     * photo, which lifts the beige band over the red test).
     */
    fun argbOf(rgba: ByteArray, rowBytes: Int, rect: PixelRect): IntArray {
        if (rect.isEmpty) return IntArray(0)
        val out = IntArray(rect.width * rect.height)
        var i = 0
        for (y in rect.top until rect.bottom) {
            var o = y * rowBytes + rect.left * 4
            for (x in rect.left until rect.right) {
                val r = rgba[o].toInt() and 0xFF
                val g = rgba[o + 1].toInt() and 0xFF
                val b = rgba[o + 2].toInt() and 0xFF
                val a = rgba[o + 3].toInt() and 0xFF
                out[i++] = (a shl 24) or (r shl 16) or (g shl 8) or b
                o += 4
            }
        }
        return out
    }

    /**
     * The pixels of the stored bitmap ([width] x [height]) under [cell], where the upright page is
     * the stored bitmap turned clockwise [quarterTurns] times (EXIF rotation plus the channel's own
     * turn). Cut at the frame; empty when nothing is left.
     */
    fun toPixels(cell: Cell, quarterTurns: Int, width: Int, height: Int): PixelRect {
        if (cell.w <= 0.0 || cell.h <= 0.0) return PixelRect(0, 0, 0, 0)
        val u0 = cell.x
        val u1 = cell.x + cell.w
        val v0 = cell.y
        val v1 = cell.y + cell.h
        // Undo the turns: normalized x and y ranges on the stored bitmap.
        val (xs, ys) = when (((quarterTurns % 4) + 4) % 4) {
            1 -> (v0 to v1) to (1 - u1 to 1 - u0)
            2 -> (1 - u1 to 1 - u0) to (1 - v1 to 1 - v0)
            3 -> (1 - v1 to 1 - v0) to (u0 to u1)
            else -> (u0 to u1) to (v0 to v1)
        }
        val left = edge(xs.first, width, floor = true)
        val right = edge(xs.second, width, floor = false)
        val top = edge(ys.first, height, floor = true)
        val bottom = edge(ys.second, height, floor = false)
        if (right <= left || bottom <= top) return PixelRect(0, 0, 0, 0)
        return PixelRect(left, top, right, bottom)
    }

    private fun edge(share: Double, size: Int, floor: Boolean): Int {
        val px = share * size
        val v = if (floor) floor(px + EDGE_SLACK) else ceil(px - EDGE_SLACK)
        return v.toInt().coerceIn(0, size)
    }
}
