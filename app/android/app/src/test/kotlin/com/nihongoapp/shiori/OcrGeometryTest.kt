package com.nihongoapp.shiori

import com.nihongoapp.shiori.OcrGeometry.Box
import com.nihongoapp.shiori.OcrGeometry.Element
import com.nihongoapp.shiori.OcrGeometry.Line
import com.nihongoapp.shiori.OcrGeometry.Symbol
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** Pieces and turns of the ML Kit channel. Words are from the synthetic test pages. */
class OcrGeometryTest {
    /** An element of [text] whose glyphs are 10 px wide from [left], on a 20 px high line at y 100. */
    private fun element(text: String, left: Double, c: Double = 0.8): Element {
        val symbols = text.mapIndexed { i, ch ->
            Symbol(ch.toString(), Box(left + 10 * i, 100.0, left + 10 * i + 10, 120.0), c)
        }
        return Element(text, Box(left, 100.0, left + 10 * text.length, 120.0), c, symbols)
    }

    private fun line(vararg elements: Element, angle: Double = 0.0, c: Double = 0.7): Line {
        val text = elements.joinToString(" ") { it.text }
        return Line(text, Box.union(elements.mapNotNull { it.box }), c, angle, elements.toList())
    }

    @Test
    fun `a line that needs no cut comes back as it is`() {
        val l = line(element("강,", 0.0), element("개천", 25.0))
        val pieces = OcrGeometry.segments(l)
        assertEquals(1, pieces.size)
        assertEquals("강, 개천", pieces[0].text)
        assertEquals(0.7, pieces[0].confidence!!, 1e-9)
        assertEquals(l.box, pieces[0].box)
    }

    @Test
    fun `a wide gap between elements starts a new piece`() {
        // Gap 30 px > 1.1 x 20 px line height: two table columns joined by ML Kit.
        val l = line(element("痛い", 0.0, c = 0.6), element("いたい", 50.0, c = 0.9))
        val pieces = OcrGeometry.segments(l)
        assertEquals(listOf("痛い", "いたい"), pieces.map { it.text })
        assertEquals(Box(0.0, 100.0, 20.0, 120.0), pieces[0].box)
        assertEquals(Box(50.0, 100.0, 80.0, 120.0), pieces[1].box)
        assertEquals(0.6, pieces[0].confidence!!, 1e-9)
        assertEquals(0.9, pieces[1].confidence!!, 1e-9)
    }

    @Test
    fun `a star glued inside an element is a piece of its own`() {
        val pieces = OcrGeometry.segments(line(element("乗り換える*のりかえる", 0.0)))
        assertEquals(listOf("乗り換える", "*", "のりかえる"), pieces.map { it.text })
        assertEquals(50.0, pieces[1].box.left, 1e-9)
        assertEquals(60.0, pieces[1].box.right, 1e-9)
        assertEquals(60.0, pieces[2].box.left, 1e-9)
    }

    @Test
    fun `pieces keep the line's top and bottom`() {
        val tall = Element("★", Box(100.0, 95.0, 110.0, 125.0), 0.3, listOf(Symbol("★", Box(100.0, 104.0, 110.0, 116.0), 0.3)))
        val l = Line("川 ★", Box(0.0, 95.0, 110.0, 125.0), 0.5, 0.0, listOf(element("川", 0.0), tall))
        val pieces = OcrGeometry.segments(l)
        assertEquals(listOf("川", "★"), pieces.map { it.text })
        assertTrue(pieces.all { it.box.top == 95.0 && it.box.bottom == 125.0 })
    }

    @Test
    fun `glyphs without boxes are dropped and a line without a box has no pieces`() {
        val noBoxes = Element("ゆび", Box(0.0, 100.0, 20.0, 120.0), 0.5, listOf(Symbol("ゆ", null, 0.5)))
        assertEquals(listOf("ゆび"), OcrGeometry.segments(line(noBoxes)).map { it.text })
        assertEquals(emptyList<OcrGeometry.Piece>(), OcrGeometry.segments(Line("x", null, 0.5, 0.0, emptyList())))
    }

    @Test
    fun `a glyph without a box inside an element is left out of a cut line and counted`() {
        val partly = Element(
            "ゆび",
            Box(0.0, 100.0, 20.0, 120.0),
            0.5,
            listOf(Symbol("ゆ", null, 0.5), Symbol("び", Box(10.0, 100.0, 20.0, 120.0), 0.5)),
        )
        val cut = line(partly, element("명", 60.0))
        assertEquals(listOf("び", "명"), OcrGeometry.segments(cut).map { it.text })
        assertEquals(1, OcrGeometry.glyphsWithoutBox(cut))
        // A line that needs no cut keeps its whole text: nothing lost.
        assertEquals(0, OcrGeometry.glyphsWithoutBox(line(partly)))
    }

    @Test
    fun `missing glyph confidences fall back to the line confidence`() {
        val e1 = Element("値段", Box(0.0, 100.0, 20.0, 120.0), null, listOf(Symbol("値", Box(0.0, 100.0, 10.0, 120.0), null)))
        val e2 = element("ねだん", 60.0)
        val pieces = OcrGeometry.segments(Line("値段 ねだん", Box(0.0, 100.0, 90.0, 120.0), 0.42, 0.0, listOf(e1, e2)))
        assertEquals(0.42, pieces[0].confidence!!, 1e-9)
    }

    @Test
    fun `text turns come from the median line angle plus the rotation handed in`() {
        val sideways = List(5) { line(element("ほし", 0.0), element("명", 30.0), angle = -90.0 + it) }
        assertEquals(1, OcrGeometry.textTurns(sideways, 0))
        // EXIF 90 handed to ML Kit: the angle is in the bitmap frame, the boxes already upright.
        assertEquals(0, OcrGeometry.textTurns(sideways, 90))
        val upsideDown = List(3) { line(element("ふく 동", 0.0), angle = 178.0) }
        assertEquals(2, OcrGeometry.textTurns(upsideDown, 0))
        val left = List(3) { line(element("のんびり", 0.0), angle = 91.0) }
        assertEquals(3, OcrGeometry.textTurns(left, 0))
    }

    @Test
    fun `no turn when the angles are unclear or the lines are too short`() {
        val skewed = List(3) { line(element("ゆうひ", 0.0), angle = 45.0) }
        assertEquals(0, OcrGeometry.textTurns(skewed, 0))
        val short = List(3) { line(element("★", 0.0), angle = -90.0) }
        assertEquals(0, OcrGeometry.textTurns(short, 0))
        assertEquals(0, OcrGeometry.textTurns(emptyList(), 0))
    }

    @Test
    fun `a quarter turn moves every box and swaps the frame`() {
        val l = line(element("川", 10.0))
        val (turned, w, h) = OcrGeometry.turned(listOf(l), 1, width = 400.0, height = 300.0)
        assertEquals(300.0, w, 1e-9)
        assertEquals(400.0, h, 1e-9)
        // [l, t, r, b] -> [H - b, l, H - t, r]
        assertEquals(Box(180.0, 10.0, 200.0, 20.0), turned[0].box)
        assertEquals(Box(180.0, 10.0, 200.0, 20.0), turned[0].elements[0].symbols[0].box)
        val (back, w4, h4) = OcrGeometry.turned(listOf(l), 4, 400.0, 300.0)
        assertEquals(l, back[0])
        assertEquals(400.0 to 300.0, w4 to h4)
    }

    @Test
    fun `turning then cutting reads a sideways row left to right`() {
        // Text running up the image (a photo turned a quarter counter-clockwise, no EXIF):
        // ML Kit says -90°, one clockwise turn brings it upright, then the reading cell is cut
        // off the headword.
        val up = listOf(
            Symbol("痛", Box(100.0, 70.0, 120.0, 80.0), 0.8),
            Symbol("い", Box(100.0, 60.0, 120.0, 70.0), 0.8),
            Symbol("い", Box(100.0, 20.0, 120.0, 30.0), 0.9),
            Symbol("た", Box(100.0, 10.0, 120.0, 20.0), 0.9),
            Symbol("い", Box(100.0, 0.0, 120.0, 10.0), 0.9),
        )
        val e1 = Element("痛い", Box(100.0, 60.0, 120.0, 80.0), 0.8, up.take(2))
        val e2 = Element("いたい", Box(100.0, 0.0, 120.0, 30.0), 0.9, up.drop(2))
        val l = Line("痛い いたい", Box(100.0, 0.0, 120.0, 80.0), 0.85, -90.0, listOf(e1, e2))
        assertEquals(1, OcrGeometry.textTurns(listOf(l), 0))
        val (upright, w, _) = OcrGeometry.turned(listOf(l), 1, 300.0, 400.0)
        val pieces = OcrGeometry.segments(upright[0])
        assertEquals(listOf("痛い", "いたい"), pieces.map { it.text })
        assertTrue(pieces[0].box.right < pieces[1].box.left)
        assertTrue(pieces.all { it.box.right <= w })
    }
}
