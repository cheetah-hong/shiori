package com.nihongoapp.shiori

import com.nihongoapp.shiori.StarPixels.Cell
import com.nihongoapp.shiori.StarPixels.Color
import com.nihongoapp.shiori.StarPixels.PixelRect
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** Red-pixel shares and cell placement of the ★ check, on made-up pixel arrays. */
class StarPixelsTest {
    private val color = Color(minRed = 120, minRedLead = 45)

    private fun argb(r: Int, g: Int, b: Int) = (0xFF shl 24) or (r shl 16) or (g shl 8) or b

    private val beige = argb(245, 230, 200)
    private val red = argb(220, 40, 50)

    @Test
    fun `a beige band has no red pixels`() {
        assertEquals(0.0, StarPixels.redShare(IntArray(200) { beige }, color), 0.0)
    }

    @Test
    fun `k red dots give k over the area`() {
        val pixels = IntArray(500) { beige }
        for (i in listOf(3, 77, 140, 499)) pixels[i] = red
        assertEquals(4.0 / 500, StarPixels.redShare(pixels, color), 1e-12)
    }

    @Test
    fun `red needs R over 120 and a lead of more than 45 over G and B`() {
        assertTrue(StarPixels.isRed(argb(121, 75, 75), color)) // lead 46
        assertFalse(StarPixels.isRed(argb(120, 60, 60), color)) // R not over 120
        assertFalse(StarPixels.isRed(argb(200, 160, 100), color)) // lead 40: orange-beige
        assertFalse(StarPixels.isRed(argb(121, 76, 70), color)) // lead 45 exactly
        assertFalse(StarPixels.isRed(argb(30, 30, 30), color)) // black ink
    }

    @Test
    fun `the alpha byte does not matter`() {
        val translucent = (0x40 shl 24) or (220 shl 16) or (40 shl 8) or 50
        assertTrue(StarPixels.isRed(translucent, color))
    }

    @Test
    fun `an empty rectangle has share 0`() {
        assertEquals(0.0, StarPixels.redShare(IntArray(0), color), 0.0)
    }

    // A stored bitmap 40 x 20 px. The cell is u 0.1..0.4, v 0.2..0.6 on the upright page,
    // which is the stored bitmap turned clockwise quarterTurns times.
    private val cell = Cell(x = 0.1, y = 0.2, w = 0.3, h = 0.4)

    @Test
    fun `upright photo - the cell scales to pixels`() {
        assertEquals(PixelRect(4, 4, 16, 12), StarPixels.toPixels(cell, 0, 40, 20))
    }

    @Test
    fun `one clockwise turn - the cell comes from the left edge of the stored bitmap`() {
        // Upright frame 20 x 40: stored (sx, sy) shows at (20 - sy, sx).
        assertEquals(PixelRect(8, 12, 24, 18), StarPixels.toPixels(cell, 1, 40, 20))
    }

    @Test
    fun `two turns - the cell is mirrored on both axes`() {
        assertEquals(PixelRect(24, 8, 36, 16), StarPixels.toPixels(cell, 2, 40, 20))
    }

    @Test
    fun `three turns - one counter-clockwise turn`() {
        // Upright frame 20 x 40: stored (sx, sy) shows at (sy, 40 - sx).
        assertEquals(PixelRect(16, 2, 32, 8), StarPixels.toPixels(cell, 3, 40, 20))
    }

    @Test
    fun `turns count modulo four, also negative`() {
        assertEquals(StarPixels.toPixels(cell, 1, 40, 20), StarPixels.toPixels(cell, 5, 40, 20))
        assertEquals(StarPixels.toPixels(cell, 3, 40, 20), StarPixels.toPixels(cell, -1, 40, 20))
    }

    @Test
    fun `a single red pixel is found in its cell after every turn`() {
        // Stored 4 x 2 frame with one red pixel at (3, 0); its upright place per turn.
        val stored = IntArray(8) { beige }.also { it[3] = red }
        val upright = mapOf(
            0 to Cell(0.75, 0.0, 0.25, 0.5), // 4 x 2: (3, 0)
            1 to Cell(0.5, 0.75, 0.5, 0.25), // 2 x 4: (2 - 0 - 1, 3) = (1, 3)
            2 to Cell(0.0, 0.5, 0.25, 0.5), // 4 x 2: (0, 1)
            3 to Cell(0.0, 0.0, 0.5, 0.25), // 2 x 4: (0, 4 - 3 - 1) = (0, 0)
        )
        for ((turns, c) in upright) {
            val r = StarPixels.toPixels(c, turns, 4, 2)
            assertEquals("turns $turns", 1, r.width * r.height)
            assertEquals("turns $turns", red, stored[r.top * 4 + r.left])
        }
    }

    @Test
    fun `a cell over the edge is cut at the frame`() {
        val over = Cell(x = -0.1, y = 0.9, w = 0.3, h = 0.4)
        assertEquals(PixelRect(0, 18, 8, 20), StarPixels.toPixels(over, 0, 40, 20))
    }

    @Test
    fun `a cell entirely off the page is empty`() {
        assertTrue(StarPixels.toPixels(Cell(1.2, 0.1, 0.1, 0.1), 0, 40, 20).isEmpty)
    }

    @Test
    fun `zero or negative width or height gives an empty rectangle`() {
        assertTrue(StarPixels.toPixels(Cell(0.1, 0.1, 0.0, 0.1), 0, 40, 20).isEmpty)
        assertTrue(StarPixels.toPixels(Cell(0.1, 0.1, 0.1, -0.1), 1, 40, 20).isEmpty)
    }
}
